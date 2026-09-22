using System.Buffers.Binary;
using System.Text;
using System.Text.RegularExpressions;
using Syncfusion.Pdf.Graphics;

namespace ShamsPdfApi;

// Uses actual local static TrueType faces, not a guessed substitute family.
// PDF subset programs are not extracted/reused. Fallback is an explicit UI mode.
public static class FontCatalog
{
    internal sealed record Face(string Path, string Family, string Name,
        string[] Names, bool Bold, bool Italic);
    private static readonly Lazy<Face[]> Faces = new(Load);
    private static string Key(string value) => new string(Regex.Replace(value, "^[A-Z]{6}\\+", "")
        .Where(char.IsLetterOrDigit).ToArray()).ToLowerInvariant();

    private static Face? Source(string name, bool bold, bool italic)
    {
        string key = Key(name);
        var matches = Faces.Value.Where(f => f.Names.Any(n => Key(n) == key)).ToArray();
        return matches.FirstOrDefault(f => f.Bold == bold && f.Italic == italic)
            ?? matches.FirstOrDefault();
    }

    public static (bool Bold, bool Italic) OriginalStyle(string name, bool bold, bool italic)
    {
        var source = Source(name, bold, italic);
        // Preserve PDF's synthetic styling too when indicated by extraction.
        return (bold || source?.Bold == true, italic || source?.Italic == true);
    }

    public static FontSource Resolve(string original, bool originalBold, bool originalItalic,
        bool bold, bool italic, string mode)
    {
        if (mode == "autoFallback")
        {
            try { return Resolve(original, originalBold, originalItalic, bold, italic, "auto"); }
            catch (EditException)
            {
                // Only font-availability failures are handled here. Layout/redaction
                // failures are never retried or ignored.
                return Resolve(original, originalBold, originalItalic, bold, italic, "helvetica");
            }
        }
        var style = (bold ? PdfFontStyle.Bold : PdfFontStyle.Regular) |
                    (italic ? PdfFontStyle.Italic : PdfFontStyle.Regular);
        if (mode != "auto")
        {
            var family = mode switch
            {
                "helvetica" => PdfFontFamily.Helvetica,
                "times" => PdfFontFamily.TimesRoman,
                "courier" => PdfFontFamily.Courier,
                _ => throw new EditException("Choose Auto, Helvetica, Times or Courier.")
            };
            return new FontSource(family.ToString(), family, style, null);
        }
        string key = Key(original);
        // Exact PDF Base-14 families only. Arial is NOT an alias for Helvetica.
        string[] helvetica = ["helvetica", "helveticabold", "helveticaoblique", "helveticaboldoblique"];
        string[] times = ["timesroman", "timesbold", "timesitalic", "timesbolditalic"];
        string[] courier = ["courier", "courierbold", "courieroblique", "courierboldoblique"];
        PdfFontFamily? standard = helvetica.Contains(key) ? PdfFontFamily.Helvetica :
            times.Contains(key) ? PdfFontFamily.TimesRoman : courier.Contains(key) ? PdfFontFamily.Courier : null;
        if (standard is not null) return new FontSource(original, standard, style, null);
        var source = Source(original, originalBold, originalItalic);
        if (source is null)
            throw new EditException($"Original font '{original}' is not available as a supported local TTF. Install that font on the service computer, or place its TTF in syncfusion_api/fonts and restart the service. You may also explicitly choose a substitute below.");
        var target = source.Bold == bold && source.Italic == italic ? source :
            Faces.Value.FirstOrDefault(f => Key(f.Family) == Key(source.Family) && f.Bold == bold && f.Italic == italic);
        if (target is null)
            throw new EditException($"The requested Bold/Italic face of '{source.Family}' is not installed. Install that face or keep its original style.");
        return new FontSource(target.Name, null, style, File.ReadAllBytes(target.Path));
    }

    private static Face[] Load()
    {
        var roots = new List<string>();
        var windowsFonts = Environment.GetFolderPath(Environment.SpecialFolder.Fonts);
        if (!string.IsNullOrEmpty(windowsFonts)) roots.Add(windowsFonts);
        if (OperatingSystem.IsWindows())
            roots.Add(System.IO.Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Microsoft", "Windows", "Fonts"));
        // Program sets a fixed service-side path; clients never supply file paths.
        if (CustomDirectory is not null) roots.Insert(0, CustomDirectory);
        var result = new List<Face>();
        foreach (var root in roots.Distinct())
        {
            if (!Directory.Exists(root)) continue;
            foreach (var path in Directory.EnumerateFiles(root, "*.ttf").Order())
            {
                try { var face = ReadFace(path); if (face is not null) result.Add(face); }
                catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or ArgumentException or OverflowException) { }
            }
        }
        return result.ToArray();
    }
    public static string? CustomDirectory { get; set; }

    internal static Face? ReadFace(string path)
    {
        if (new FileInfo(path).Length > 20 * 1024 * 1024) return null;
        var data = File.ReadAllBytes(path);
        ushort U16(int at) => BinaryPrimitives.ReadUInt16BigEndian(data.AsSpan(at, 2));
        uint U32(int at) => BinaryPrimitives.ReadUInt32BigEndian(data.AsSpan(at, 4));
        if (data.Length < 12 || U32(0) != 0x00010000) return null; // Static glyf TTF only.
        var tables = new Dictionary<string, (int Offset, int Length)>();
        int count = U16(4);
        if (12L + count * 16L > data.Length) return null;
        for (int i = 0; i < count; i++)
        {
            int at = 12 + i * 16;
            string tag = Encoding.ASCII.GetString(data, at, 4);
            uint offset = U32(at + 8), length = U32(at + 12);
            if ((ulong)offset + length > (ulong)data.Length) return null;
            tables[tag] = (checked((int)offset), checked((int)length));
        }
        if (tables.ContainsKey("fvar") || !tables.ContainsKey("glyf") ||
            !tables.TryGetValue("name", out var nt) || nt.Length < 6 ||
            !tables.TryGetValue("OS/2", out var os) || os.Length < 64) return null;
        ushort embedding = U16(os.Offset + 8);
        // Restricted, preview/print only, and bitmap-only faces aren't used for editable output.
        if ((embedding & 0x0202) != 0 || ((embedding & 4) != 0 && (embedding & 8) == 0)) return null;
        ushort flags = U16(os.Offset + 62);
        var names = new List<(int Id, string Value)>();
        int recordCount = U16(nt.Offset + 2), storage = U16(nt.Offset + 4);
        if (6L + recordCount * 12L > nt.Length) return null;
        for (int i = 0; i < recordCount; i++)
        {
            int at = nt.Offset + 6 + i * 12;
            int platform = U16(at), language = U16(at + 4), id = U16(at + 6);
            if (platform is not (0 or 3) || (platform == 3 && language != 0x0409 && language != 0)) continue;
            if (id is not (1 or 4 or 6)) continue;
            int length = U16(at + 8), offset = U16(at + 10);
            if (length % 2 != 0 || (long)storage + offset + length > nt.Length) continue;
            string value = Encoding.BigEndianUnicode.GetString(data, nt.Offset + storage + offset, length).Trim('\0');
            if (value.Length > 0) names.Add((id, value));
        }
        string? family = names.FirstOrDefault(n => n.Id == 1).Value;
        string? full = names.FirstOrDefault(n => n.Id == 4).Value;
        if (family is null || full is null) return null;
        return new Face(path, family, full, names.Select(n => n.Value).Distinct().ToArray(),
            (flags & 32) != 0, (flags & 1) != 0 || (flags & 512) != 0);
    }
}

public sealed class FontSource(string name, PdfFontFamily? family, PdfFontStyle style, byte[]? data) : IDisposable
{
    public string Name { get; } = name;
    private readonly List<MemoryStream> streams = new();
    public PdfFont Create(float size)
    {
        if (family is not null) return new PdfStandardFont(family.Value, size, style);
        var stream = new MemoryStream(data!, writable: false);
        streams.Add(stream);
        // The chosen real font face contains the Bold/Italic outlines.
        // Full embedding also honors no-subsetting flags.
        return new PdfTrueTypeFont(stream, size, true, false);
    }
    public void Dispose() { foreach (var stream in streams) stream.Dispose(); }
}
