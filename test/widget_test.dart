// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:bu_horizon/data/sample_data.dart';
import 'package:bu_horizon/di/di.dart';
import 'package:bu_horizon/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(configureDependencies);

  testWidgets('App launches and shows home greeting', (WidgetTester tester) async {
    SampleData.isLoggedIn.value = true;
    await tester.pumpWidget(const BUHorizonApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 3200));
    await tester.pumpAndSettle();

    expect(find.text('Rajesh Biswas  👋'), findsOneWidget);
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
  });
}
