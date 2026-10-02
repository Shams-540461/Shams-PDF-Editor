import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:http/http.dart' as http;

class TextReplacement {
  const TextReplacement(this.bytes, this.fontName, this.fontSize);
  final Uint8List bytes;
  final String fontName;
  final double fontSize;
}

class OriginalTextService {
  // Supply the public HTTPS /edit URL using --dart-define=PDF_TEXT_API=...
  // Local desktop testing may explicitly use http://127.0.0.1:8765/edit.
  static const endpoint = String.fromEnvironment('PDF_TEXT_API');
  static const _timeout = Duration(seconds: 120);
  static const _maxPdfBytes = 30 * 1024 * 1024;

  static bool _isLoopback(String host) =>
      host == 'localhost' || host == '127.0.0.1' || host == '::1';

  static Uri _serviceUri() {
    final uri = Uri.tryParse(endpoint.trim());
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) {
      throw StateError(
        'Text editing is not configured in this app build. Rebuild with '
        '--dart-define=PDF_TEXT_API=https://YOUR-SERVICE/edit.',
      );
    }
    if (uri.userInfo.isNotEmpty || uri.hasFragment) {
      throw StateError('The text service URL is invalid.');
    }
    final loopback = _isLoopback(uri.host);
    final mobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (loopback && mobile) {
      throw StateError(
        'This mobile build points to localhost on the phone. Rebuild with '
        'the public HTTPS text service URL using PDF_TEXT_API.',
      );
    }
    if (kIsWeb && loopback && !_isLoopback(Uri.base.host)) {
      throw StateError(
        'This website points to a local text service. Rebuild the website '
        'with the public HTTPS text service URL.',
      );
    }
    if (uri.scheme != 'https' && !(uri.scheme == 'http' && loopback)) {
      throw StateError('The text editing service must use HTTPS.');
    }
    if (kIsWeb && Uri.base.scheme == 'https' && uri.scheme != 'https') {
      throw StateError('An HTTPS website requires an HTTPS text service.');
    }
    return uri;
  }

  static void _checkPdf(Uint8List bytes) {
    if (bytes.length > _maxPdfBytes) {
      throw StateError('Choose a PDF smaller than 30 MB.');
    }
    if (bytes.length < 5 || bytes[0] != 37 || bytes[1] != 80 ||
        bytes[2] != 68 || bytes[3] != 70 || bytes[4] != 45) {
      throw StateError('The file does not have a valid PDF header.');
    }
  }

  static Future<Map<String, dynamic>> request(
    Map<String, dynamic> body,
  ) async {
    final uri = _serviceUri();
    final client = http.Client();
    try {
      // No automatic POST retries: a timeout may occur after processing starts.
      final response = await client.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(body),
      ).timeout(_timeout);

      if (response.statusCode == 429) {
        throw StateError('The text service is busy. Wait briefly and try again.');
      }
      if (response.statusCode == 413) {
        throw StateError('The PDF is too large for the text service.');
      }
      if (response.statusCode >= 500) {
        throw StateError(
          'The text service is temporarily unavailable '
          '(HTTP ${response.statusCode}). Try again shortly. '
          'The open document has not been updated.',
        );
      }
      if (response.statusCode == 404 || response.statusCode == 405) {
        throw StateError('The text service address is incorrect. Check the /edit URL.');
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw StateError('Access to the text service was refused. Check server access settings.');
      }

      final dynamic decoded;
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        throw StateError(
          'The text service returned an unreadable response '
          '(HTTP ${response.statusCode}). Check the service URL and server logs.',
        );
      }
      if (decoded is! Map<String, dynamic>) {
        throw StateError('The text service returned an unexpected response.');
      }
      if (response.statusCode != 200 || decoded['error'] != null) {
        final error = decoded['error'];
        throw StateError(error is String && error.trim().isNotEmpty
            ? error
            : 'Text replacement failed (HTTP ${response.statusCode}).');
      }
      return decoded;
    } on TimeoutException {
      throw StateError(
        'The text service did not respond within 120 seconds. '
        'It may be starting or processing the PDF. Try again shortly. '
        'The open document has not been updated.',
      );
    } on http.ClientException {
      throw StateError(_isLoopback(uri.host)
          ? 'Cannot reach the local text service. On your computer, run '
              'start_text_service.cmd and keep it open.'
          : 'Cannot connect to the online text service. Check your connection '
              'and service availability. For web builds, also check server CORS settings.');
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> select(
    Uint8List bytes, int page, double x, double y,
  ) {
    _checkPdf(bytes);
    return request({
      'action': 'select', 'pdf': base64Encode(bytes),
      'page': page, 'x': x, 'y': y,
    });
  }

  static Future<TextReplacement> replace(
    Uint8List bytes, int page, Map<String, dynamic> selection,
    String replacement, {
    bool autoFit = true, double? fontSize, bool? bold, bool? italic,
    String fontMode = 'auto',
  }) async {
    _checkPdf(bytes);
    final result = await request({
      'action': 'replace', 'pdf': base64Encode(bytes), 'page': page,
      'id': selection['id'], 'expected': selection['text'],
      'sha256': selection['sha256'], 'replacement': replacement,
      'autoFit': autoFit, 'fontSize': fontSize,
      'bold': bold, 'italic': italic, 'fontMode': fontMode,
    });
    final encoded = result['pdf'];
    if (encoded is! String) {
      throw StateError('The service response did not contain an edited PDF.');
    }
    final Uint8List output;
    try {
      output = base64Decode(encoded);
    } on FormatException {
      throw StateError('The service returned invalid PDF data.');
    }
    _checkPdf(output);
    final name = result['fontName'];
    final size = result['fontSize'];
    return TextReplacement(output, name is String ? name : 'Unknown',
        size is num && size.isFinite ? size.toDouble() : 0);
  }
}
