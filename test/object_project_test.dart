import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as pdf;
import 'package:shams_pdf_editor/object_project.dart';
import 'pdf_edits_test.dart' show sample;

String extracted(Uint8List bytes, {int? page}) {
  final doc = pdf.PdfDocument(inputBytes: bytes);
  try {
    return pdf.PdfTextExtractor(doc).extractText(startPageIndex: page,
      endPageIndex: page);
  } finally { doc.dispose(); }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const size = Size(595, 842);
  PdfObject text({int page = 1}) => PdfObject(id: 1, page: page, text: 'Movable text',
    bounds: const Rect.fromLTWH(40, 100, 100, 30), bold: true, italic: true).measured(size);

  test('new text stays extractable; moving does not duplicate it or erase original text', () async {
    final base = await sample();
    final unchanged = Uint8List.fromList(base);
    final object = text();
    final initial = await ObjectProject(base, [object]).render();
    final moved = await ObjectProject(base, [object.copy(
      bounds: object.bounds.shift(const Offset(50, 50)))]).render();
    expect(extracted(initial), contains('Movable text'));
    expect(RegExp('Movable text').allMatches(extracted(moved)).length, 1);
    expect(extracted(moved), contains('Original page one'));
    expect(extracted(moved), contains('Original page two'));
    expect(base, orderedEquals(unchanged));
    final deleted = await ObjectProject(base, []).render();
    expect(extracted(deleted), isNot(contains('Movable text')));
    expect(extracted(deleted), contains('Original page one'));
  });

  test('page targeting and editable project round trip', () async {
    final base = await sample();
    final project = ObjectProject(base, [text(page: 2)]);
    final restored = ObjectProject.decode(project.encode());
    expect(restored.objects.single.bounds, project.objects.single.bounds);
    expect(restored.objects.single.bold, true);
    expect(restored.objects.single.italic, true);
    final bytes = await restored.render();
    expect(extracted(bytes, page: 0), isNot(contains('Movable text')));
    expect(extracted(bytes, page: 1), contains('Movable text'));
    final preview = await restored.pagePreview(2);
    final doc = pdf.PdfDocument(inputBytes: preview);
    try {
      expect(doc.pages.count, 1);
      expect(pdf.PdfTextExtractor(doc).extractText(), contains('Original page two'));
      expect(pdf.PdfTextExtractor(doc).extractText(), isNot(contains('Movable text')));
    } finally { doc.dispose(); }
  });

  test('image project round trip, reposition, resize and removal', () async {
    final base = await sample();
    final image = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=');
    final object = PdfObject(id: 2, page: 1, image: image,
      bounds: const Rect.fromLTWH(50, 50, 50, 50));
    final restored = ObjectProject.decode(ObjectProject(base, [object]).encode());
    expect(restored.objects.single.image, orderedEquals(image));
    final resized = restored.objects.single.copy(bounds: const Rect.fromLTWH(100, 100, 80, 80));
    final bytes = await ObjectProject(base, [resized]).render();
    expect(extracted(bytes), contains('Original page one'));
    expect(extracted(await ObjectProject(base, []).render()), contains('Original page one'));
  });

  test('bounds clamp, overflow, invalid font sizes and unsupported scripts', () {
    expect(PdfObject.constrain(const Rect.fromLTWH(-10, 830, 100, 30), size),
      const Rect.fromLTWH(0, 812, 100, 30));
    expect(() => text().copy(fontSize: double.nan).measured(size), throwsStateError);
    expect(() => text().copy(fontSize: 201).measured(size), throwsStateError);
    expect(() => text().copy(text: 'اردو').measured(size), throwsStateError);
    expect(() => text().copy(text: 'W' * 500).measured(size), throwsStateError);
  });

  test('invalid project and rotated page reject without mutating input', () async {
    expect(() => ObjectProject.decode(Uint8List.fromList(utf8.encode('{}'))), throwsFormatException);
    final base = await sample(rotated: true);
    await expectLater(ObjectProject(base, [text()]).render(), throwsUnsupportedError);
    await expectLater(ObjectProject(base, []).pagePreview(1), throwsUnsupportedError);
  });
}
