// Developer Branding Watermark: Rajesh Biswas (rajeshbiswas.dev) - BU Horizon
import 'package:bu_horizon/di/di.dart';
import 'package:bu_horizon/screens/bus_schedule_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(configureDependencies);

  testWidgets('BusScheduleScreen displays categories, routes, and Where/Time filters', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BusScheduleScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify category tabs
    expect(find.text('Student'), findsOneWidget);
    expect(find.text('Teacher'), findsOneWidget);
    expect(find.text('Staff'), findsOneWidget);

    // Verify default Route 01
    expect(find.text('Route 01'), findsOneWidget);
    expect(find.text('Where to go?'), findsOneWidget);
    expect(find.text('Time Filter'), findsOneWidget);

    // Tap Where to go? picker
    await tester.tap(find.text('Where to go?'));
    await tester.pumpAndSettle();
    expect(find.text('Select Where You Want To Go'), findsOneWidget);

    // Select 'বিশ্ববিদ্যালয়' filter
    await tester.tap(find.text('বিশ্ববিদ্যালয়').last);
    await tester.pumpAndSettle();
    expect(find.text('Place: বিশ্ববিদ্যালয়'), findsOneWidget);

    // Clear filter
    await tester.tap(find.text('Clear Filter'));
    await tester.pumpAndSettle();
    expect(find.text('Where to go?'), findsOneWidget);
  });
}
