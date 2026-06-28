import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:civic_reporter/main.dart';

void main() {
  testWidgets('Smoke test for civic reporter startup', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const MaterialApp(
        home: MainContainer(),
      ),
    );
    // Pump a single frame to allow layout to settle
    await tester.pump();

    // Verify that the title header exists on startup
    expect(find.text('File a Civic Report'), findsOneWidget);
  });
}
