// Run from the project root: dart tool/prepare_web.dart
// Downloads a matched PDF.js bundle and worker for self-hosted runtime use.
import 'dart:io';

Future<void> main() async {
  const version = '4.9.155';
  final directory = Directory('web/vendor')..createSync(recursive: true);
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
  try {
    for (final name in ['pdf.min.mjs', 'pdf.worker.min.mjs']) {
      final target = File('${directory.path}/$name');
      final request = await client.getUrl(
        Uri.parse('https://cdnjs.cloudflare.com/ajax/libs/pdf.js/$version/$name'));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Unable to fetch $name: HTTP ${response.statusCode}');
      }
      final temporary = File('${target.path}.part');
      await response.pipe(temporary.openWrite());
      if (await temporary.length() < 10000) {
        throw StateError('$name is unexpectedly small; refusing to use it.');
      }
      if (await target.exists()) await target.delete();
      await temporary.rename(target.path);
      stdout.writeln('Prepared $name ($version).');
    }
  } finally {
    client.close(force: true);
  }
}
