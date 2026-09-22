using System.Security.Cryptography;
using Syncfusion.Drawing;
using Syncfusion.Pdf;
using Syncfusion.Pdf.Graphics;
using Syncfusion.Pdf.Parsing;
using Syncfusion.Pdf.Redaction;

namespace ShamsPdfApi;

public sealed class EditException(string message) : Exception(message) { }
public sealed record EditRequest(string Action, string Pdf, int Page,
    float X = 0, float Y = 0, int Id = -1, string? Expected = null,
    string? Sha256 = null, string? Replacement = null,
    bool AutoFit = false, float? FontSize = null,
    bool? Bold = null, bool? Italic = null, string FontMode = "auto");
public sealed record Selection(int Id, string Text, float[] Bbox, float Size, string Sha256,
    string FontName, bool Bold, bool Italic);
public sealed record EditedPdf(string Pdf, float FontSize = 0, bool AutoFitted = false, string FontName = "");

public static class PdfTextEditor
{
    public static object Process(EditRequest request)
    {
        if (request.Action is not ("select" or "replace"))
            throw new EditException("Unknown editing action.");
        if (string.IsNullOrEmpty(request.Pdf) || request.Pdf.Length > 40 * 1024 * 1024)
            throw new EditException("Choose a PDF smaller than 30 MB.");
        byte[] bytes = Convert.FromBase64String(request.Pdf);
        if (bytes.Length < 5 || bytes.Length > 30 * 1024 * 1024 ||
            !bytes.AsSpan(0, 5).SequenceEqual("%PDF-"u8))
            throw new EditException("The input is not a supported PDF.");
        var hash = Convert.ToHexString(SHA256.HashData(bytes));
        using var document = new PdfLoadedDocument(bytes);
        if (request.Page < 1 || request.Page > document.Pages.Count)
            throw new EditException("Page number is outside this document.");
        if (document.Form is not null && document.Form.Fields.Count > 0)
            throw new EditException("Original-text replacement is disabled for PDFs with form or signature fields. Use the viewer's form tools.");
        var page = (PdfLoadedPage)document.Pages[request.Page - 1];
        if (page.Rotation != PdfPageRotateAngle.RotateAngle0)
            throw new EditException("Original-text replacement is not supported on rotated pages.");
        // Redact() processes the document, so existing redactions/annotations
        // must not accidentally be applied or affected on any page.
        foreach (PdfLoadedPage p in document.Pages)
            if (p.Annotations.Count > 0)
                throw new EditException("Use a PDF without annotations for original-text replacement in this version.");

        page.ExtractText(out TextLineCollection collection);
        var lines = collection.TextLine.ToArray();
        int index = request.Id;
        if (request.Action == "select")
        {
            if (!float.IsFinite(request.X) || !float.IsFinite(request.Y))
                throw new EditException("Invalid selection position.");
            var hits = lines.Select((line, id) => (line, id))
                .Where(item => Contains(item.line.Bounds, request.X, request.Y)).ToArray();
            if (hits.Length == 0)
                throw new EditException("No text was found at this position. Tap directly on a letter. Text inside a scanned image needs OCR.");
            if (hits.Length > 1)
                throw new EditException("More than one text line overlaps here. Choose a clear line or undo added text first.");
            index = hits[0].id;
        }
        if (index < 0 || index >= lines.Length)
            throw new EditException("Select the line again.");
        var selected = lines[index];
        var glyphs = selected.WordCollection.SelectMany(word => word.Glyphs)
            .Where(glyph => !char.IsWhiteSpace(glyph.Text)).ToArray();
        if (string.IsNullOrWhiteSpace(selected.Text) || !Ascii(selected.Text) || glyphs.Length == 0)
            throw new EditException("This version replaces plain English text only. Urdu, Arabic, scanned text and complex scripts are not supported for replacement.");
        var first = glyphs[0];
        if (!float.IsFinite(first.FontSize) || first.FontSize < 1 || first.FontSize > 200)
            throw new EditException("This line's font size is unsupported.");
        if (glyphs.Any(g => g.FontName != first.FontName ||
            Math.Abs(g.FontSize - first.FontSize) > 0.1f ||
            g.FontStyle != first.FontStyle || !g.TextColor.Equals(first.TextColor)))
            throw new EditException("This line contains mixed formatting. Choose a line with one font, size and color.");
        RectangleF bounds = selected.Bounds;
        if (!float.IsFinite(bounds.X) || !float.IsFinite(bounds.Y) ||
            !float.IsFinite(bounds.Width) || !float.IsFinite(bounds.Height) ||
            bounds.Width <= 0 || bounds.Height <= 0 || bounds.X < 0 || bounds.Y < 0 ||
            bounds.Right > page.Size.Width || bounds.Bottom > page.Size.Height)
            throw new EditException("The line has unsupported page coordinates.");
        if (lines.Where((_, id) => id != index).Any(line => Overlaps(line.Bounds, bounds)))
            throw new EditException("Another text line overlaps this area. No change was applied.");
        var originalStyle = FontCatalog.OriginalStyle(first.FontName,
            (first.FontStyle & FontStyle.Bold) != 0, (first.FontStyle & FontStyle.Italic) != 0);
        if (request.Action == "select")
            return new Selection(index, selected.Text,
                [bounds.Left, bounds.Top, bounds.Right, bounds.Bottom], first.FontSize, hash,
                first.FontName, originalStyle.Bold, originalStyle.Italic);

        if (request.Sha256 != hash || request.Expected != selected.Text)
            throw new EditException("The document changed after selection. Select the line again.");
        var replacement = request.Replacement ?? throw new EditException("Replacement text is missing.");
        if (replacement.Length > 2000 || !Ascii(replacement))
            throw new EditException("Use one line of plain English text, up to 2000 characters.");
        bool bold = request.Bold ?? originalStyle.Bold;
        bool italic = request.Italic ?? originalStyle.Italic;
        if (replacement == selected.Text && (request.FontSize is null || request.FontSize == first.FontSize) &&
            bold == originalStyle.Bold && italic == originalStyle.Italic &&
            (request.FontMode == "auto" || request.FontMode == "autoFallback"))
            return new EditedPdf(Convert.ToBase64String(bytes), first.FontSize, false, first.FontName);
        // A deletion doesn't require obtaining a replacement font.
        using var fontSource = FontCatalog.Resolve(first.FontName, originalStyle.Bold,
            originalStyle.Italic, bold, italic, replacement.Length == 0 ? "helvetica" : request.FontMode);
        float size = request.FontSize ?? first.FontSize;
        float minimumSize = Math.Min(6f, first.FontSize);
        if (!float.IsFinite(size) || size < minimumSize || size > 200)
            throw new EditException($"Choose a size between {minimumSize:0.##} and 200 pt.");
        var font = fontSource.Create(size);
        bool autoFitted = false;
        if (replacement.Length > 0)
        {
            var measured = font.MeasureString(replacement);
            if (measured.Width > bounds.Width || measured.Height > bounds.Height)
            {
                if (!request.AutoFit)
                    throw new EditException("The text does not fit. Enable Fit text to original area or choose a smaller font size.");
                float scale = Math.Min(bounds.Width / measured.Width, bounds.Height / measured.Height);
                float fittedSize = MathF.Floor(size * scale * 0.995f * 100f) / 100f;
                if (fittedSize < minimumSize)
                    throw new EditException("This text would be too small to read. Shorten it; automatic fitting stops at 6 pt (or the original size if smaller).");
                size = fittedSize;
                font = fontSource.Create(size);
                autoFitted = true;
            }
            var finalSize = font.MeasureString(replacement);
            if (finalSize.Width > bounds.Width + 0.1f || finalSize.Height > bounds.Height + 0.1f)
                throw new EditException("The text still does not fit safely. Shorten it or lower the font size.");
        }

        // This is actual removal plus replacement, not a white overlay over old text.
        // The UI explicitly warns that intersecting graphics are removed as well.
        page.AddRedaction(new PdfRedaction(bounds, Color.White));
        document.Redact();
        using var removedStream = new MemoryStream();
        document.Save(removedStream);
        using var removed = new PdfLoadedDocument(removedStream.ToArray());
        var removedPage = (PdfLoadedPage)removed.Pages[request.Page - 1];
        removedPage.ExtractText(out TextLineCollection remaining);
        var survivors = remaining.TextLine.SelectMany(l => l.WordCollection)
            .SelectMany(w => w.Glyphs).Where(g => !char.IsWhiteSpace(g.Text)).ToArray();
        if (survivors.Any(g => Overlaps(g.Bounds, bounds)))
            throw new EditException("The original text could not be removed completely. No edited file was returned.");
        // A removed neighboring line is a hard failure, not a partial success.
        var expectedOutside = lines.Where((_, id) => id != index)
            .SelectMany(l => l.WordCollection).SelectMany(w => w.Glyphs)
            .Where(g => !char.IsWhiteSpace(g.Text)).Select(GlyphIdentity).Order().ToArray();
        var actualOutside = survivors.Select(GlyphIdentity).Order().ToArray();
        if (!expectedOutside.SequenceEqual(actualOutside))
            throw new EditException("The edit affected nearby text. No edited file was returned.");
        if (replacement.Length > 0)
            removedPage.Graphics.DrawString(replacement, font,
                new PdfSolidBrush(new PdfColor(first.TextColor)),
                new PointF(bounds.X, bounds.Y));
        using var output = new MemoryStream();
        removed.Save(output);
        return new EditedPdf(Convert.ToBase64String(output.ToArray()), size, autoFitted, fontSource.Name);
    }

    private static bool Ascii(string text) => text.All(c => c >= ' ' && c <= '~');
    private static bool Contains(RectangleF r, float x, float y) =>
        x >= r.Left && x <= r.Right && y >= r.Top && y <= r.Bottom;
    private static bool Overlaps(RectangleF a, RectangleF b) =>
        a.Left < b.Right - 0.05f && a.Right > b.Left + 0.05f &&
        a.Top < b.Bottom - 0.05f && a.Bottom > b.Top + 0.05f;
    private static string GlyphIdentity(TextGlyph g) =>
        FormattableString.Invariant($"{(int)g.Text}:{Math.Round(g.Bounds.X, 1)}:{Math.Round(g.Bounds.Y, 1)}");
}
