// Developer Branding Watermark: Rajesh Biswas (rajeshbiswas.dev) - BU Horizon
//
// UI guard for the two-timetable route. Every other route has a single
// timetable, so the day toggle, the day badge and the break note only appear
// here — and the existing screen tests all sit on Route 01, which never renders
// any of it.
//
// The assertions are deliberately day-agnostic: `_ServiceDaysToggle` reads the
// real clock, so the suite must pass whichever weekday it runs on.
import 'package:bu_horizon/data/university_bus_schedule_data.dart';
import 'package:bu_horizon/di/di.dart';
import 'package:bu_horizon/screens/bus_schedule_screen.dart';
import 'package:bu_horizon/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(configureDependencies);

  /// The spotlight card ticks once a second, so `pumpAndSettle` can spin. A
  /// fixed number of frames is enough for every layout here.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  /// Boots the screen at a phone width so the compact route picker is used,
  /// then selects Student → Route 07 through its bottom sheet. (The wide layout
  /// lays the routes out in a horizontal strip where Route 07 scrolls off the
  /// edge and cannot be tapped.)
  Future<void> pumpSchedule(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const BusScheduleScreen()),
    );
    await settle(tester);
  }

  Future<void> openRoute07(WidgetTester tester) async {
    await pumpSchedule(tester);

    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_CompactRoutePicker',
        description: 'compact route picker',
      ),
    );
    await settle(tester);

    // Student is the default category, so this is the student Route 07 and not
    // the unrelated teacher route of the same name.
    final route07 = find.text('Route 07');
    expect(route07, findsWidgets, reason: 'Route 07 missing from the picker');
    await tester.tap(route07.last);
    await settle(tester);
  }

  /// The toggle at the top of the route, scoped so its chips are never confused
  /// with the identically-worded day badge on each departure-section header.
  final toggle = find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString() == '_ServiceDaysToggle',
    description: 'service days toggle',
  );

  Finder toggleChip(String label) => find.descendant(
    of: toggle,
    matching: find.textContaining(label),
  );

  /// Scrolls the main schedule list until [target] has been built. The list is
  /// lazy and one weekend timetable is 13 rows tall, so the second direction's
  /// card starts well below the viewport.
  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    for (var i = 0; i < 25 && target.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView).last, const Offset(0, -400));
      await settle(tester);
    }
  }

  testWidgets('offers both timetables and marks the one that applies today',
      (tester) async {
    await openRoute07(tester);

    expect(find.text('This route runs two timetables'), findsOneWidget);
    expect(toggleChip('Sun–Thu'), findsOneWidget);
    expect(toggleChip('Fri & Sat'), findsOneWidget);

    // Exactly one option is the current one, whichever day the suite runs on.
    expect(toggleChip('· Today'), findsOneWidget);
  });

  testWidgets('weekly-holiday timetable is morning service with the break',
      (tester) async {
    await openRoute07(tester);
    await tester.tap(toggleChip('Fri & Sat'));
    await settle(tester);

    expect(find.text('9:00 AM'), findsWidgets);
    expect(find.textContaining('নামাজ ও লাঞ্চের বিরতি'), findsWidgets);
    // 1:00 PM is the break — it must not appear as a departure.
    expect(find.text('1:00 PM'), findsNothing);

    // Both directions of the selected timetable are present.
    expect(find.text('বিশ্ববিদ্যালয়'), findsWidgets);
    final rupatoli = find.text('রুপাতলী (লিলি ফিলিং স্টেশনের বিপরীত পার্শ্ব)');
    await scrollTo(tester, rupatoli);
    expect(
      rupatoli,
      findsWidgets,
      reason: 'the রুপাতলী boarding point should have its own section',
    );
  });

  testWidgets('working-day timetable is evening only and carries no break note',
      (tester) async {
    await openRoute07(tester);
    await tester.tap(toggleChip('Sun–Thu'));
    await settle(tester);

    expect(find.text('11:00 PM'), findsWidgets);
    expect(find.text('9:00 AM'), findsNothing);
    expect(find.textContaining('নামাজ ও লাঞ্চের বিরতি'), findsNothing);
  });

  testWidgets('labels each departure block with the days it runs',
      (tester) async {
    await openRoute07(tester);

    // The section header badge, distinct from the toggle chips above it.
    final badges = find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.label == 'Runs on ${ServiceDays.weekend.longLabel}',
    );
    final workdayBadges = find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.label == 'Runs on ${ServiceDays.workdays.longLabel}',
    );

    await tester.tap(toggleChip('Fri & Sat'));
    await settle(tester);
    expect(badges, findsWidgets);
    expect(workdayBadges, findsNothing);

    await tester.tap(toggleChip('Sun–Thu'));
    await settle(tester);
    expect(workdayBadges, findsWidgets);
    expect(badges, findsNothing);
  });

  testWidgets('Route 01 is untouched — no toggle, no day badge',
      (tester) async {
    await pumpSchedule(tester);

    expect(find.text('This route runs two timetables'), findsNothing);
    expect(find.textContaining('Fri & Sat'), findsNothing);
  });

  testWidgets('the Route 07 view meets the tap-target and contrast guards',
      (tester) async {
    await openRoute07(tester);
    final handle = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
}
