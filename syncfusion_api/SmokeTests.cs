using Syncfusion.Drawing;
using Syncfusion.Pdf;
using Syncfusion.Pdf.Graphics;
using Syncfusion.Pdf.Parsing;

namespace ShamsPdfApi;

// Run: dotnet run --no-launch-profile -- --self-test
// Generated in-memory PDFs only; never touches a user's document.
public static class SmokeTests
{
    public static void Run()
    {
        using var fixture = new PdfDocument();
        fixture.PageSettings.Margins.All = 0;
        var page = fixture.Pages.Add();
        var font = new PdfStandardFont(PdfFontFamily.Helvetica, 12);
        page.Graphics.DrawString("Original sample line", font, PdfBrushes.Black, new PointF(50, 60));
        page.Graphics.DrawString("Keep this neighboring line", font, PdfBrushes.Black, new PointF(50, 110));
        fixture.Pages.Add().Graphics.DrawString("Second page", font, PdfBrushes.Black, new PointF(50, 60));
        using var stream = new MemoryStream();
        fixture.Save(stream);
        var bytes = stream.ToArray();
        var encoded = Convert.ToBase64String(bytes);
        using var input = new PdfLoadedDocument(bytes);
        input.Pages[0].ExtractText(out TextLineCollection collection);
        var target = collection.TextLine.Single(l => l.Text.Trim() == "Original sample line");
        var select = new EditRequest("select", encoded, 1,
            target.Bounds.X + target.Bounds.Width / 2,
            target.Bounds.Y + target.Bounds.Height / 2);
        var selection = (Selection)PdfTextEditor.Process(select);
        var request = new EditRequest("replace", encoded, 1,
            Id: selection.Id, Expected: selection.Text,
            Sha256: selection.Sha256, Replacement: "New text", AutoFit: true);
        var result = (EditedPdf)PdfTextEditor.Process(request);
        using var output = new PdfLoadedDocument(Convert.FromBase64String(result.Pdf));
        string text = output.Pages[0].ExtractText();
        Check(!text.Contains("Original sample line"), "Old text was removed");
        Check(text.Contains("New text"), "Replacement is searchable");
        Check(text.Contains("Keep this neighboring line"), "Neighbor is retained");
        Check(output.Pages.Count == 2 && output.Pages[1].ExtractText().Contains("Second page"),
            "Second page is retained");
        int count = (int)Math.Ceiling(target.Bounds.Width / font.MeasureString("W").Width * 1.25f);
        string longer = new string('W', count);
        var fitted = (EditedPdf)PdfTextEditor.Process(request with { Replacement = longer, AutoFit = true });
        Check(fitted.AutoFitted && fitted.FontSize >= 6 && fitted.FontSize < 12,
            "Long text fits with a readable smaller font");
        using var fittedDoc = new PdfLoadedDocument(Convert.FromBase64String(fitted.Pdf));
        Check(fittedDoc.Pages[0].ExtractText().Contains(longer), "Fitted replacement is searchable");
        Reject(request with { Replacement = longer, AutoFit = false }, "Overflow rejected when fitting is off");
        Reject(request with { FontSize = 0 }, "Zero font size rejected");
        Reject(request with { FontSize = 201 }, "Oversized font rejected");
        Reject(request with { Sha256 = "stale" }, "Stale document rejected");
        Reject(request with { Replacement = new string('W', 200) }, "Overflow rejected");
        Reject(request with { Replacement = "اردو" }, "Unsupported replacement rejected");
        Reject(request with { Replacement = "two\nlines" }, "Multiline replacement rejected");
        Reject(select with { X = 0, Y = 0 }, "Blank area rejected");
        var deleted = (EditedPdf)PdfTextEditor.Process(request with { Replacement = "" });
        using var deletedDoc = new PdfLoadedDocument(Convert.FromBase64String(deleted.Pdf));
        Check(!deletedDoc.Pages[0].ExtractText().Contains("Original sample line"), "Deletion works");
        var styled = (EditedPdf)PdfTextEditor.Process(request with {
            Replacement = "Style", Bold = true, Italic = true, AutoFit = true });
        using var styledDoc = new PdfLoadedDocument(Convert.FromBase64String(styled.Pdf));
        styledDoc.Pages[0].ExtractText(out TextLineCollection styledLines);
        var styledGlyph = styledLines.TextLine.Single(l => l.Text.Trim() == "Style")
            .WordCollection.SelectMany(w => w.Glyphs).First();
        Check((styledGlyph.FontStyle & FontStyle.Bold) != 0 &&
            (styledGlyph.FontStyle & FontStyle.Italic) != 0, "Bold and italic controls apply");
        using (var times = FontCatalog.Resolve("ABCDEF+Times-Roman", false, false, true, false, "auto"))
            Check(times.Create(12) is PdfStandardFont && times.Name.Contains("Times"), "Auto retains Times family and strips subset prefix");
        try
        {
            using var unavailable = FontCatalog.Resolve("ShamsMissingFont_94682", false, false, false, false, "auto");
            throw new InvalidOperationException("FAIL: Missing font was silently replaced");
        }
        catch (EditException) { Console.WriteLine("PASS: Missing font fails explicitly"); }
        using (var fallback = FontCatalog.Resolve("ShamsMissingFont_94682", false, false, true, true, "autoFallback"))
            Check(fallback.Name == "Helvetica" && fallback.Create(12) is PdfStandardFont,
                "Opt-in automatic fallback tolerates missing fonts and supports styles");
        using (var exact = FontCatalog.Resolve("Times-Roman", false, false, false, false, "autoFallback"))
            Check(exact.Name.Contains("Times"), "Fallback mode prefers the available original font");
        using (var substitute = FontCatalog.Resolve("ShamsMissingFont_94682", false, false, false, false, "courier"))
            Check(substitute.Create(12) is PdfStandardFont && substitute.Name.Contains("Courier"), "Explicit substitute is available");
        string arialPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Fonts), "arial.ttf");
        if (File.Exists(arialPath))
        {
            var parsed = FontCatalog.ReadFace(arialPath);
            Check(parsed is not null && parsed.Family.Contains("Arial"), "Installed Arial metadata parsed");
            using var arial = FontCatalog.Resolve("ArialMT", false, false, false, false, "auto");
            Check(arial.Create(12) is PdfTrueTypeFont && arial.Name.Contains("Arial"), "Auto uses real Arial TTF");
        }
        else Console.WriteLine("SKIP: Installed Arial font check (arial.ttf unavailable).");
        Console.WriteLine("All Syncfusion smoke checks passed.");
    }
    private static void Check(bool condition, string label)
    {
        if (!condition) throw new InvalidOperationException("FAIL: " + label);
        Console.WriteLine("PASS: " + label);
    }
    private static void Reject(EditRequest request, string label)
    {
        try { PdfTextEditor.Process(request); }
        catch (EditException) { Console.WriteLine("PASS: " + label); return; }
        throw new InvalidOperationException("FAIL: " + label);
    }
}
