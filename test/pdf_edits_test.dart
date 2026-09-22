import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as pdf;
import 'package:shams_pdf_editor/pdf_edits.dart';

Future<Uint8List> sample({bool rotated = false}) async {
  final doc = pdf.PdfDocument();
  try {
    doc.pageSettings.margins.all = 0;
    if (rotated) {
      doc.pageSettings.rotate = pdf.PdfPageRotateAngle.rotateAngle90;
    }
    final first = doc.pages.add();
    first.graphics.drawString('Original page one',
      pdf.PdfStandardFont(pdf.PdfFontFamily.helvetica, 12),
      bounds: const Rect.fromLTWH(20, 20, 220, 30), brush: pdf.PdfBrushes.black);
    doc.pages.add().graphics.drawString('Original page two',
      pdf.PdfStandardFont(pdf.PdfFontFamily.helvetica, 12),
      bounds: const Rect.fromLTWH(20, 20, 220, 30), brush: pdf.PdfBrushes.black);
    return Uint8List.fromList(await doc.save());
  } finally { doc.dispose(); }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('saved text stays on the selected page and original bytes are unchanged', () async {
    final input = await sample();
    final original = Uint8List.fromList(input);
    final output = await PdfEdits.apply(input, 2, (page) {
      page.graphics.drawString('Added by Shams',
        pdf.PdfStandardFont(pdf.PdfFontFamily.helvetica, 14),
        bounds: const Rect.fromLTWH(40, 80, 230, 35), brush: pdf.PdfBrushes.black);
    });
    expect(input, orderedEquals(original));
    final reopened = pdf.PdfDocument(inputBytes: output);
    try {
      expect(reopened.pages.count, 2);
      final extractor = pdf.PdfTextExtractor(reopened);
      expect(extractor.extractText(startPageIndex: 0, endPageIndex: 0),
        isNot(contains('Added by Shams')));
      final pageTwo = extractor.extractText(startPageIndex: 1, endPageIndex: 1);
      expect(pageTwo, contains('Original page two'));
      expect(pageTwo, contains('Added by Shams'));
    } finally { reopened.dispose(); }
  });

  test('invalid page is rejected without modifying input', () async {
    final input = await sample();
    final before = Uint8List.fromList(input);
    await expectLater(PdfEdits.apply(input, 3, (_) {}), throwsRangeError);
    expect(input, orderedEquals(before));
  });

  test('rotated page edits are explicitly rejected', () async {
    final input = await sample(rotated: true);
    final reopened = pdf.PdfDocument(inputBytes: input);
    try {
      expect(reopened.pages[0].rotation, pdf.PdfPageRotateAngle.rotateAngle90,
        reason: 'The fixture must retain its rotation after serialization.');
    } finally {
      reopened.dispose();
    }
    await expectLater(PdfEdits.apply(input, 1, (_) {}), throwsUnsupportedError);
  });

  test('drawing plus text survive serialization and reopening', () async {
    final input = await sample();
    final output = await PdfEdits.apply(input, 1, (page) {
      PdfEdits.drawInk(page, [
        [const Offset(10, 10), const Offset(100, 80), const Offset(220, 40)],
        [const Offset(40, 90)],
      ], const Rect.fromLTWH(30, 100, 240, 120), const Size(480, 240));
    });
    final reopened = pdf.PdfDocument(inputBytes: output);
    try {
      expect(reopened.pages.count, 2);
      expect(pdf.PdfTextExtractor(reopened).extractText(), contains('Original page one'));
      expect(output, isNot(orderedEquals(input)));
    } finally { reopened.dispose(); }
  });
}
