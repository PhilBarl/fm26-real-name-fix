// widget_test.dart
//
// A basic smoke test that verifies the app launches and shows the
// welcome screen without crashing.

import 'package:flutter_test/flutter_test.dart';

import 'package:fm26_real_name_fix/main.dart';

void main() {
  testWidgets('App launches and shows welcome screen', (WidgetTester tester) async {
    // Build the app and render the first frame.
    await tester.pumpWidget(const FmRealNameFixApp());

    // The welcome screen should show the "Get Started" button.
    expect(find.text('Get Started'), findsOneWidget);
  });
}
