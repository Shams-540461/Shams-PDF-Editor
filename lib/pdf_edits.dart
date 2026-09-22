import 'dart:typed_data';
import 'dart:ui';
import 'package:syncfusion_flutter_pdf/pdf.dart' as pdf;

/// Each operation serializes a fresh document; errors never mutate input bytes.
class PdfEdits {
  static Future<Uint8List> apply(
    Uint8List source,
    int pageNumber,
    void Function(pdf.PdfPage) operation, {
    String? password,
  }) async {
    final document = pdf.PdfDocument(inputBytes: source, password: password);
    try {
      if (pageNumber < 1 || pageNumber > document.pages.count) {
        throw RangeError('Page number is outside this document.');
      }
      final page = document.pages[pageNumber - 1];
      if (page.rotation != pdf.PdfPageRotateAngle.rotateAngle0) {
        throw UnsupportedError('Page rotation must be zero for content editing.');
      }
      operation(page);
      return Uint8List.fromList(await document.save());
    } finally {
      document.dispose();
    }
  }

  static void drawInk(pdf.PdfPage page, List<List<Offset>> strokes,
      Rect target, Size canvasSize, {double thickness = 2}) {
    if (canvasSize.isEmpty || target.isEmpty) {
      throw ArgumentError('Drawing dimensions must be positive.');
    }
    final scale = target.width / canvasSize.width;
    final pen = pdf.PdfPen(pdf.PdfColor(20, 40, 60), width: thickness * scale);
    Offset map(Offset point) => Offset(
      target.left + point.dx * scale,
      target.top + point.dy * target.height / canvasSize.height,
    );
    for (final stroke in strokes) {
      if (stroke.length == 1) {
        final p = map(stroke.first);
        page.graphics.drawEllipse(
          Rect.fromCircle(center: p, radius: pen.width / 2),
          brush: pdf.PdfSolidBrush(pdf.PdfColor(20, 40, 60)),
        );
      }
      for (var i = 1; i < stroke.length; i++) {
        page.graphics.drawLine(pen, map(stroke[i - 1]), map(stroke[i]));
      }
    }
  }
}
