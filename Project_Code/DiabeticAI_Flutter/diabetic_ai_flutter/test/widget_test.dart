// This test file is for the placeholder app only.
// For real DiabeticAI tests, see Project_Code/DiabeticAI_Flutter/test/

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/main.dart';

void main() {
  testWidgets('Placeholder app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PlaceholderApp());
    expect(find.text('Wrong entry point.\nRun DiabeticAI_Flutter/lib/main.dart instead.'),
        findsOneWidget);
  });
}
