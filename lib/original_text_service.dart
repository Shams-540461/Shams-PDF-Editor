import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;

class TextReplacement {
  const TextReplacement(this.bytes, this.fontName, this.fontSize);
  final Uint8List bytes;
  final String fontName;
  final double fontSize;
}

class OriginalTextService {
  static const endpoint = String.fromEnvironment('PDF_TEXT_API',
      defaultValue: 'http://127.0.0.1:8765/edit');

  static Future<Map<String, dynamic>> request(Map<String, dynamic> body) async {
    final uri = Uri.parse(endpoint);
    if (kIsWeb && Uri.base.host != 'localhost' && Uri.base.host != '127.0.0.1' &&
        (uri.host == 'localhost' || uri.host == '127.0.0.1')) {
      throw StateError('Original-text editing has not been configured for this website yet.');
    }
    if (uri.scheme != 'https' &&
        !(uri.scheme == 'http' &&
          (uri.host == 'localhost' || uri.host == '127.0.0.1'))) {
      throw StateError('The text editing service must use HTTPS.');
    }
    final client = http.Client();
    try {
      final response = await client.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body)).timeout(const Duration(seconds: 60));
      final dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        throw StateError('The text service returned an unreadable response. Check that the updated Syncfusion service is running.');
      }
      if (decoded is! Map<String, dynamic>) {
        throw StateError('The text service returned an unexpected response.');
      }
      final result = decoded;
      if (response.statusCode != 200) {
        throw StateError(result['error']?.toString() ?? 'Text replacement failed.');
      }
      return result;
    } on TimeoutException {
      throw StateError('Text service timed out. No change was applied.');
    } on http.ClientException {
      throw StateError('Cannot reach the text service. Start start_text_service.cmd and keep it open.');
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> select(
      Uint8List bytes, int page, double x, double y) => request({
    'action': 'select', 'pdf': base64Encode(bytes), 'page': page, 'x': x, 'y': y,
  });

  static Future<TextReplacement> replace(Uint8List bytes, int page,
      Map<String, dynamic> selection, String replacement,
      {bool autoFit = true, double? fontSize, bool? bold, bool? italic,
      String fontMode = 'auto'}) async {
    final result = await request({
      'action': 'replace', 'pdf': base64Encode(bytes), 'page': page,
      'id': selection['id'], 'expected': selection['text'],
      'sha256': selection['sha256'], 'replacement': replacement,
      'autoFit': autoFit, 'fontSize': fontSize,
      'bold': bold, 'italic': italic, 'fontMode': fontMode,
    });
    final output = base64Decode(result['pdf'] as String);
    if (output.length < 5 || ascii.decode(output.sublist(0, 5)) != '%PDF-') {
      throw StateError('The service returned an invalid PDF.');
    }
    return TextReplacement(output, result['fontName'] as String? ?? 'Unknown',
      (result['fontSize'] as num?)?.toDouble() ?? 0);
  }
}
