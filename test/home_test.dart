import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shams_pdf_editor/main.dart';

void main() {
  testWidgets('empty editor fits a narrow mobile screen', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ShamsPdfApp());
    expect(find.text('Open a PDF'), findsOneWidget);
    expect(find.text('Try a sample'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
