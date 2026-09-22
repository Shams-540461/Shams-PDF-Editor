// Generates fresh Android and iOS shells without changing this app's Dart code.
// Example: dart tool/create_mobile.dart YOUR_REVERSE_DOMAIN
// The identifier is supplied by the owner, not copied from the SSS app.
import 'dart:io';

Future<void> main(List<String> args) async {
  if (args.length != 1 ||
      !RegExp(r'^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$').hasMatch(args.single)) {
    stderr.writeln('Provide your confirmed reverse-domain organization identifier.');
    stderr.writeln('Usage: dart tool/create_mobile.dart YOUR_REVERSE_DOMAIN');
    exitCode = 64;
    return;
  }
  if (Directory('android').existsSync() || Directory('ios').existsSync()) {
    stderr.writeln('Mobile folders already exist. Nothing was overwritten.');
    exitCode = 1;
    return;
  }
  final temporary = await Directory.systemTemp.createTemp('shams_pdf_scaffold_');
  try {
    final result = await Process.run(
      Platform.isWindows ? 'flutter.bat' : 'flutter',
      ['create', '--no-pub', '--platforms=android,ios', '--org', args.single,
       '--project-name', 'shams_pdf_editor', temporary.path],
      runInShell: Platform.isWindows,
    );
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    if (result.exitCode != 0) { exitCode = result.exitCode; return; }
    for (final name in ['android', 'ios']) {
      await _copy(Directory('${temporary.path}/$name'), Directory(name));
    }
    final manifest = File('android/app/src/main/AndroidManifest.xml');
    if (manifest.existsSync()) {
      manifest.writeAsStringSync(manifest.readAsStringSync()
        .replaceAll('android:label="shams_pdf_editor"', 'android:label="Shams PDF Editor"'));
    }
    final plist = File('ios/Runner/Info.plist');
    if (plist.existsSync()) {
      plist.writeAsStringSync(plist.readAsStringSync()
        .replaceAll('<string>Shams Pdf Editor</string>', '<string>Shams PDF Editor</string>'));
    }
    // file_picker 13.x requires iOS 14+. Sync both CocoaPods and Xcode targets.
    final pbx = File('ios/Runner.xcodeproj/project.pbxproj');
    if (pbx.existsSync()) {
      final source = pbx.readAsStringSync();
      pbx.writeAsStringSync(source.replaceAllMapped(
        RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = ([0-9.]+);'), (m) {
          final version = double.tryParse(m[1]!) ?? 14;
          return version < 14 ? 'IPHONEOS_DEPLOYMENT_TARGET = 14.0;' : m[0]!;
        }));
    }
    final podfile = File('ios/Podfile');
    if (podfile.existsSync()) {
      final source = podfile.readAsStringSync();
      podfile.writeAsStringSync(source.replaceAllMapped(
        RegExp(r"^\s*#?\s*platform :ios, '([0-9.]+)'", multiLine: true), (m) {
          final version = double.tryParse(m[1]!) ?? 14;
          return "platform :ios, '${version < 14 ? '14.0' : m[1]}'";
        }));
    }
    stdout.writeln('Mobile shells created. Run flutter pub get, then flutter run.');
    stdout.writeln('Confirm application IDs and configure release signing before Play/App Store publication.');
  } finally {
    await temporary.delete(recursive: true);
  }
}

Future<void> _copy(Directory from, Directory to) async {
  await to.create(recursive: true);
  await for (final entry in from.list(followLinks: false)) {
    final name = entry.uri.pathSegments.where((p) => p.isNotEmpty).last;
    if (entry is File) {
      await entry.copy('${to.path}/$name');
    } else if (entry is Directory) {
      await _copy(entry, Directory('${to.path}/$name'));
    }
  }
}
