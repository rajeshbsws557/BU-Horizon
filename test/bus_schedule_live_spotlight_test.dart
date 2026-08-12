// Developer Branding Watermark: Rajesh Biswas (rajeshbiswas.dev) - BU Horizon
//
// Widget-level proof that the "Next Departure" card is wired to the clock.
//
// The unit tests in next_departure_resolver_test.dart cover the time maths;
// these tests cover the part the user actually complained about: that the card
// on screen reflects the current time and changes as time passes, instead of
// permanently showing the first row of the printed timetable.
import 'package:bu_horizon/data/university_bus_schedule_data.dart';
import 'package:bu_horizon/di/di.dart';
import 'package:bu_horizon/screens/bus_schedule_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(configureDependencies);

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => debugNextDepartureClock = null);

  /// Keeps the viewport short enough that the lazy ListView never builds the
  /// far-down interactive map (which would fetch network tiles).
  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: BusScheduleScreen()));
    await tester.pumpAndSettle();
  }

  /// The Student / Route 01 timetable the screen shows by default. Read from
  /// the bundled data so these expectations can't drift from what renders.
  List<BusTripItem> route01Trips() => UniversityBusScheduleData
      .categories.first.routes.first.departureSections.first.trips;

  testWidgets('spotlights the first bus of the day early in the morning',
      (tester) async {
    // 6:00 AM — before any bus has left.
    debugNextDepartureClock = () => DateTime(2026, 8, 5, 6, 0);

    await pumpScreen(tester);

    expect(find.text('NEXT DEPARTURE'), findsOneWidget);
    // Route 01's first departure (8:30 AM) is genuinely next at 6 AM.
    expect(find.text(route01Trips().first.time), findsWidgets);
    // A live countdown is rendered rather than a bare timetable row.
    expect(find.textContaining('in '), findsWidgets);
    // Nothing is being mislabelled as tomorrow's bus.
    expect(find.text('Tomorrow'), findsNothing);
  });

  testWidgets('late at night it rolls over and says Tomorrow', (tester) async {
    // 11:30 PM — every Route 01 bus has gone. THIS is the reported bug: the
    // card used to still advertise the 8:30 AM bus as if it were imminent.
    debugNextDepartureClock = () => DateTime(2026, 8, 5, 23, 30);

    await pumpScreen(tester);

    expect(find.text('Tomorrow'), findsOneWidget);
    expect(find.text('NEXT DEPARTURE'), findsOneWidget);
  });

  testWidgets('shows DEPARTING NOW when the bus is due', (tester) async {
    // Exactly at the first departure time.
    final firstTrip = route01Trips().first.time; // "8:30 AM"
    debugNextDepartureClock = () => DateTime(2026, 8, 5, 8, 30);

    await pumpScreen(tester);

    expect(find.text('DEPARTING NOW'), findsOneWidget);
    expect(find.text('At the stop'), findsOneWidget);
    expect(find.text(firstTrip), findsWidgets);
  });

  testWidgets('the card re-resolves on its own as the clock moves',
      (tester) async {
    // A clock the test can advance without rebuilding the widget, so this
    // exercises the internal 1-second ticker rather than a fresh pumpWidget.
    var now = DateTime(2026, 8, 5, 6, 0);
    debugNextDepartureClock = () => now;

    await pumpScreen(tester);
    expect(find.text('Tomorrow'), findsNothing);

    // Move past the last bus of the day. No user interaction, no navigation —
    // exactly the "I left the screen open" case that used to stay frozen.
    now = DateTime(2026, 8, 5, 23, 30);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Tomorrow'), findsOneWidget);
  });

  testWidgets('the countdown ticks down while the screen sits open',
      (tester) async {
    var now = DateTime(2026, 8, 5, 8, 0); // 30 min before the 8:30 bus
    debugNextDepartureClock = () => now;

    await pumpScreen(tester);
    expect(find.text('in 30m 00s'), findsOneWidget);

    now = DateTime(2026, 8, 5, 8, 0, 10); // 10 seconds later
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('in 29m 50s'), findsOneWidget);
    expect(find.text('in 30m 00s'), findsNothing);
  });
}
