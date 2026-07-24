// Developer Branding Watermark: Rajesh Biswas (rajeshbiswas.dev) - BU Horizon
//
// Regression guard for the "one trip -> one alarm id" invariant.
//
// The Bus Schedule screen has two "Set Alarm" entry points for the same
// physical trip: the Next-Departure spotlight card and the grouped trip-list
// rows. A past bug had the list rows build their own ad-hoc id
// ("place_time_bus") instead of the shared formula, so an alarm set from one
// place was invisible to the other (double-booking + wrong route label).
//
// These tests pin the shared formula so any future divergence fails loudly.
import 'dart:convert';

import 'package:bu_horizon/data/university_bus_schedule_data.dart';
import 'package:bu_horizon/di/di.dart';
import 'package:bu_horizon/screens/bus_schedule_screen.dart';
import 'package:bu_horizon/services/bus_alarm_service.dart';
import 'package:bu_horizon/widgets/bus_alarm_picker_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(configureDependencies);

  test('busScheduleTripId is stable and trims surrounding whitespace', () {
    // Drive identities off the bundled data so the literals here can never
    // drift byte-wise from what the screen actually renders.
    final route = UniversityBusScheduleData.categories.first.routes.first;
    final section = route.departureSections.first;
    final trip = section.trips.first;

    // Identical trip, cosmetic whitespace differences -> identical id.
    expect(
      busScheduleTripId(route.id, ' ${section.departurePlace} ', ' ${trip.time} '),
      busScheduleTripId(route.id, section.departurePlace, trip.time),
    );

    // Different trips (times) must not collide.
    final trip2 = section.trips[1];
    expect(
      busScheduleTripId(route.id, section.departurePlace, trip.time),
      isNot(busScheduleTripId(route.id, section.departurePlace, trip2.time)),
    );

    // Different routes must not collide.
    final route2 = UniversityBusScheduleData.categories.first.routes[1];
    expect(
      busScheduleTripId(route.id, section.departurePlace, trip.time),
      isNot(busScheduleTripId(route2.id, section.departurePlace, trip.time)),
    );
  });

  testWidgets(
      'list-row Set Alarm resolves the same trip id the spotlight stored',
      (WidgetTester tester) async {
    // First Student / Route 01 trip — the SAME physical departure the
    // spotlight card surfaces AND the first list row renders. Identity is
    // taken from the bundled data, not a hardcoded literal.
    final route = UniversityBusScheduleData.categories.first.routes.first;
    final section = route.departureSections.first;
    final trip = section.trips.first;

    final sharedId =
        busScheduleTripId(route.id, section.departurePlace, trip.time);

    // Seed a stored alarm under the shared id, as the spotlight "Set Alarm"
    // would have. The modal keys existing-alarm lookup purely off this id.
    final seeded = ScheduledBusAlarmInfo(
      id: sharedId,
      routeName: route.routeName,
      departurePlace: section.departurePlace,
      tripTime: trip.time,
      busName: trip.busName,
      leadMinutes: 15,
      scheduledRingTimeIso: '2026-07-24T08:15:00.000',
    );
    SharedPreferences.setMockInitialValues({
      'bu_horizon_scheduled_bus_alarms': jsonEncode([seeded.toJson()]),
    });

    // Give the modal enough vertical room to lay out (it isn't internally
    // scrollable), while keeping the viewport short enough that the lazy
    // ListView doesn't build the far-down interactive map (network tiles).
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: BusScheduleScreen()));
    await tester.pumpAndSettle();

    // Open the alarm picker from a trip-list row (last alarm button belongs to
    // the grouped schedule list, not the spotlight card).
    // The trip-list rows render alarm buttons as IconButton widgets; the
    // spotlight card uses a bespoke Pressable. Target an IconButton row so we
    // exercise the list-row path specifically, scrolling it into view first.
    final listRowAlarm = find.descendant(
      of: find.byType(IconButton),
      matching: find.byIcon(Icons.alarm_add_rounded),
    );
    expect(listRowAlarm, findsWidgets,
        reason: 'expected at least one trip-list alarm IconButton');
    await tester.ensureVisible(listRowAlarm.first);
    await tester.pumpAndSettle();
    await tester.tap(listRowAlarm.first);
    await tester.pumpAndSettle();

    // Diagnostic: confirm the modal opened at all before asserting its state.
    expect(find.byType(BusAlarmPickerModal), findsOneWidget,
        reason: 'alarm picker modal did not open from the list row');
    // Let the async existing-alarm lookup resolve.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    // If the list row builds the SAME id as the seeded (spotlight) alarm, the
    // modal recognizes it and shows the "Manage" affordances. A divergent id
    // would show the "Set" state instead -> this assertion fails.
    expect(find.text('Manage Bus Alarm'), findsOneWidget);
    expect(find.text('Cancel Alarm'), findsOneWidget);
  });
}
