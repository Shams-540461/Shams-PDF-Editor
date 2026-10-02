import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shams_pdf_editor/main.dart';
import 'package:shams_pdf_editor/editor_page.dart';

void main() {
  testWidgets('App opens the PDF editor', (WidgetTester tester) async {
    await tester.pumpWidget(const ShamsPdfApp());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'Shams PDF Editor');
    expect(app.home, isA<SyncfusionPdfEditor>());

    expect(find.byType(SyncfusionPdfEditor), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}