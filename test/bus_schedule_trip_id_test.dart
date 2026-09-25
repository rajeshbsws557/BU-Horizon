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

  // Route 07 runs the same clock time from the same stop on both its
  // timetables (6:00 PM on কর্মদিবস and again on the ছুটি), so the day pattern
  // is part of a trip's identity — otherwise one alarm would silently serve two
  // different buses.
  test('day-scoped trips at the same place and time do not collide', () {
    const routeId = 'student_route_07';
    const place = 'বিশ্ববিদ্যালয়';
    const time = '6:00 PM';

    final workday = busScheduleTripId(
      routeId,
      place,
      time,
      ServiceDays.workdays,
    );
    final weekend = busScheduleTripId(
      routeId,
      place,
      time,
      ServiceDays.weekend,
    );

    expect(workday, isNot(weekend));
    expect(workday, endsWith('__workdays'));
    expect(weekend, endsWith('__weekend'));
  });

  test('daily ids keep the pre-ServiceDays formula so stored alarms survive',
      () {
    // An alarm the current build persisted is keyed by this exact string. If the
    // suffix ever leaked onto daily routes, every existing alarm would orphan.
    final route = UniversityBusScheduleData.categories.first.routes.first;
    final section = route.departureSections.first;
    final trip = section.trips.first;

    expect(
      busScheduleTripId(route.id, section.departurePlace, trip.time),
      '${route.id}__${section.departurePlace}__${trip.time}',
    );
    // Omitting the parameter and passing `daily` explicitly must agree.
    expect(
      busScheduleTripId(route.id, section.departurePlace, trip.time),
      busScheduleTripId(
        route.id,
        section.departurePlace,
        trip.time,
        ServiceDays.daily,
      ),
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

    // Open the alarm picker from the trip-list row for THIS EXACT trip.
    //
    // Both entry points now render the shared `_TripAlarmButton`, which
    // exposes its `tripId`. Matching on that id is what makes this a real
    // guard: it proves the row independently derived the same id the spotlight
    // stored. Tapping "whatever alarm button is first" would instead hit the
    // spotlight's own button — a different trip once the day's early buses have
    // gone — and prove nothing.
    //
    // (The finder previously looked for an IconButton. The screen's redesign
    // replaced that with this shared widget, so the old finder matched nothing.)
    final rowAlarmButton = find.byWidgetPredicate(
      (w) =>
          w.runtimeType.toString() == '_TripAlarmButton' &&
          (w as dynamic).tripId == sharedId &&
          (w as dynamic).dense == true,
      description: 'dense _TripAlarmButton for the seeded trip',
    );
    expect(rowAlarmButton, findsWidgets,
        reason: 'no trip-list alarm button built the shared id — the list row '
            'and spotlight have diverged');

    await tester.ensureVisible(rowAlarmButton.first);
    await tester.pumpAndSettle();
    await tester.tap(rowAlarmButton.first, warnIfMissed: false);
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
