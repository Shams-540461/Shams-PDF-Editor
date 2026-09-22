import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as pdf;

/// Immutable objects; PDF bytes are always rebuilt from the untouched base.
/// Moving/deleting an object never paints white over the underlying document.
class PdfObject {
  const PdfObject({required this.id, required this.page, required this.bounds,
    this.text, this.image, this.fontData, this.fontSize = 16, this.bold = false,
    this.italic = false, this.rtl = false, this.color = 0xff000000});
  final int id, page, color;
  final Rect bounds;
  final String? text;
  final Uint8List? image, fontData;
  final double fontSize;
  final bool bold, italic, rtl;
  PdfObject copy({int? id, Rect? bounds, String? text, double? fontSize,
      bool? bold, bool? italic, bool? rtl, int? color}) => PdfObject(
    id: id ?? this.id, page: page, bounds: bounds ?? this.bounds,
    text: text ?? this.text, image: image, fontData: fontData,
    fontSize: fontSize ?? this.fontSize, bold: bold ?? this.bold,
    italic: italic ?? this.italic, rtl: rtl ?? this.rtl, color: color ?? this.color);

  pdf.PdfFont get font {
    final styles = <pdf.PdfFontStyle>[
      if (bold) pdf.PdfFontStyle.bold,
      if (italic) pdf.PdfFontStyle.italic,
      if (!bold && !italic) pdf.PdfFontStyle.regular,
    ];
    return fontData == null
      ? pdf.PdfStandardFont(pdf.PdfFontFamily.helvetica, fontSize, multiStyle: styles)
      : pdf.PdfTrueTypeFont(fontData!, fontSize, multiStyle: styles);
  }
  pdf.PdfStringFormat get format => pdf.PdfStringFormat(
    textDirection: rtl ? pdf.PdfTextDirection.rightToLeft : pdf.PdfTextDirection.leftToRight,
    alignment: rtl ? pdf.PdfTextAlignment.right : pdf.PdfTextAlignment.left);

  PdfObject measured(Size pageSize) {
    if (text == null) return copy(bounds: constrain(bounds, pageSize));
    if (text!.trim().isEmpty || text!.length > 2000) {
      throw StateError('Enter 1–2000 characters.');
    }
    if (fontData == null && text!.runes.any((r) => r > 126 || (r < 32 && r != 10))) {
      throw StateError('Load a TTF font supporting this language before adding text.');
    }
    if (!fontSize.isFinite || fontSize < 6 || fontSize > 200) {
      throw StateError('Choose a size from 6 to 200 pt.');
    }
    final measured = font.measureString(text!, format: format);
    // Explicit newlines are allowed. No silent wrapping/clipping.
    final size = Size(math.max(12, measured.width + 2), math.max(12, measured.height + 2));
    if (size.width > pageSize.width || size.height > pageSize.height) {
      throw StateError('This text is larger than the page. Reduce its size or add line breaks.');
    }
    return copy(bounds: constrain(bounds.topLeft & size, pageSize));
  }

  static Rect constrain(Rect value, Size page) {
    final w = value.width.clamp(1.0, page.width).toDouble();
    final h = value.height.clamp(1.0, page.height).toDouble();
    return Rect.fromLTWH(value.left.clamp(0.0, page.width - w).toDouble(),
      value.top.clamp(0.0, page.height - h).toDouble(), w, h);
  }

  void draw(pdf.PdfPage target) {
    if (image != null) {
      target.graphics.drawImage(pdf.PdfBitmap(image!), bounds);
    } else {
      target.graphics.drawString(text!, font, bounds: bounds, format: format,
        brush: pdf.PdfSolidBrush(pdf.PdfColor((color >> 16) & 255, (color >> 8) & 255, color & 255)));
    }
  }

  Map<String, dynamic> toJson() => {'id': id, 'page': page,
    'bounds': [bounds.left, bounds.top, bounds.width, bounds.height],
    'text': text, 'image': image == null ? null : base64Encode(image!),
    'font': fontData == null ? null : base64Encode(fontData!),
    'size': fontSize, 'bold': bold, 'italic': italic, 'rtl': rtl, 'color': color};

  factory PdfObject.fromJson(Map<String, dynamic> value) {
    final box = (value['bounds'] as List).map((e) => (e as num).toDouble()).toList();
    if (box.length != 4 || box.any((e) => !e.isFinite) || box[2] <= 0 || box[3] <= 0) {
      throw const FormatException('Invalid object bounds.');
    }
    final text = value['text'] as String?;
    final image = value['image'] == null ? null : base64Decode(value['image'] as String);
    if ((text == null) == (image == null)) throw const FormatException('Invalid object type.');
    if (image != null && image.length > 10 * 1024 * 1024) throw const FormatException('Image exceeds 10 MB.');
    return PdfObject(id: value['id'] as int, page: value['page'] as int,
      bounds: Rect.fromLTWH(box[0], box[1], box[2], box[3]), text: text, image: image,
      fontData: value['font'] == null ? null : base64Decode(value['font'] as String),
      fontSize: (value['size'] as num).toDouble(), bold: value['bold'] as bool,
      italic: value['italic'] as bool, rtl: value['rtl'] as bool, color: value['color'] as int);
  }
}

class ObjectProject {
  ObjectProject(this.base, Iterable<PdfObject> objects) : objects = List.unmodifiable(objects);
  final Uint8List base;
  final List<PdfObject> objects;

  Future<Uint8List> render({String? password}) async {
    final doc = pdf.PdfDocument(inputBytes: base, password: password);
    try {
      for (final object in objects) {
        if (object.page < 1 || object.page > doc.pages.count) throw StateError('Invalid page.');
        final page = doc.pages[object.page - 1];
        if (page.rotation != pdf.PdfPageRotateAngle.rotateAngle0) {
          throw UnsupportedError('Rotate this page to 0 degrees before arranging objects.');
        }
        final size = page.getClientSize();
        if (object.bounds.left < 0 || object.bounds.top < 0 ||
            object.bounds.right > size.width + .01 || object.bounds.bottom > size.height + .01) {
          throw StateError('An object is outside its page.');
        }
        if (object.text != null) {
          final checked = object.measured(size);
          if (checked.bounds.width > object.bounds.width + .1 ||
              checked.bounds.height > object.bounds.height + .1) {
            throw StateError('A text box is too small. Edit its text or size.');
          }
        } else {
          final bitmap = pdf.PdfBitmap(object.image!);
          if (bitmap.width <= 0 || bitmap.height <= 0 || bitmap.width * bitmap.height > 25000000) {
            throw StateError('Use an image of at most 25 megapixels.');
          }
        }
        object.draw(page);
      }
      return Uint8List.fromList(await doc.save());
    } finally { doc.dispose(); }
  }

  Uint8List encode() => Uint8List.fromList(utf8.encode(jsonEncode({
    'format': 'shams-pdf-project', 'version': 1,
    'base': base64Encode(base), 'objects': objects.map((o) => o.toJson()).toList(),
  })));

  static ObjectProject decode(Uint8List bytes) {
    if (bytes.length > 80 * 1024 * 1024) throw StateError('Project exceeds 80 MB.');
    final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    if (data['format'] != 'shams-pdf-project' || data['version'] != 1) {
      throw const FormatException('Unsupported project file.');
    }
    final base = base64Decode(data['base'] as String);
    if (base.length > 30 * 1024 * 1024 || base.length < 5 ||
        ascii.decode(base.sublist(0, 5)) != '%PDF-') throw const FormatException('Invalid base PDF.');
    final values = data['objects'] as List;
    if (values.length > 100) throw StateError('Maximum 100 objects per project.');
    final objects = values.map((v) => PdfObject.fromJson(v as Map<String, dynamic>)).toList();
    if (objects.map((o) => o.id).toSet().length != objects.length) {
      throw const FormatException('Duplicate object identifiers.');
    }
    return ObjectProject(base, objects);
  }

  /// A display-only page copy. The actual saved PDF always uses [base].
  Future<Uint8List> pagePreview(int pageNumber, {String? password}) async {
    final source = pdf.PdfDocument(inputBytes: base, password: password);
    try {
      final page = source.pages[pageNumber - 1];
      if (page.rotation != pdf.PdfPageRotateAngle.rotateAngle0) {
        throw UnsupportedError('Arrange objects supports unrotated pages only.');
      }
      for (int index = source.pages.count - 1; index >= 0; index--) {
        if (index != pageNumber - 1) source.pages.removeAt(index);
      }
      return Uint8List.fromList(await source.save());
    } finally { source.dispose(); }
  }
}
