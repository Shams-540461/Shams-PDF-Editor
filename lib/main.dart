import 'package:flutter/material.dart';
import 'editor_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ShamsPdfApp());
}

class ShamsPdfApp extends StatelessWidget {
  const ShamsPdfApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Shams PDF Editor',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF126B64)),
          scaffoldBackgroundColor: const Color(0xFFF4F7F7),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF103D3B),
            foregroundColor: Colors.white,
          ),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
          ),
        ),
        home: const SyncfusionPdfEditor(),
      );
}
