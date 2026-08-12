// Guards the home screen's redesigned "Upcoming" section.
//
// The old section rendered two identical grey cards whose icons were dead code
// (only drawn when `badge == null`, and every caller passed a badge) and whose
// bus time was computed once at build, so it went stale while the student was
// looking at it. These tests pin the replacement: a hero with a live countdown
// that flips to "Departing now", plus compact rows underneath.
import 'package:bu_horizon/di/di.dart';
import 'package:bu_horizon/theme/app_theme.dart';
import 'package:bu_horizon/widgets/upcoming_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  setUpAll(configureDependencies);

  tearDown(() => debugUpcomingClock = null);

  /// Pins the clock so the countdown is deterministic instead of racing the
  /// wall clock the way a `DateTime.now()` based card would.
  void pinClock(DateTime at) => debugUpcomingClock = () => at;

  /// Mounts the section inside the minimum scaffolding it needs: a router (the
  /// hero and rows call `context.push`) and the app theme (every colour comes
  /// from the `AppThemeColors` extension).
  Future<void> pumpSection(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(
            body: SingleChildScrollView(child: UpcomingSection()),
          ),
        ),
        GoRoute(path: '/bus', builder: (_, __) => const SizedBox.shrink()),
        GoRoute(path: '/exams', builder: (_, __) => const SizedBox.shrink()),
        GoRoute(path: '/login', builder: (_, __) => const SizedBox.shrink()),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.darkOf(AppThemeVariant.fallback),
        routerConfig: router,
      ),
    );
    // Let the staggered Entrance animations finish. pumpAndSettle would hang
    // on the repeating shimmer in the loading skeleton.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  testWidgets('hero shows the next departure with a live countdown',
      (tester) async {
    // 6 AM: comfortably before the first student trip of the day.
    pinClock(DateTime(2026, 8, 6, 6));
    await pumpSection(tester);

    expect(find.text('NEXT DEPARTURE'), findsOneWidget);
    expect(find.text('DEPARTING NOW'), findsNothing);

    // The countdown is rendered as "in <countdown>", never a bare timetable row.
    expect(
      find.textContaining(RegExp(r'^in \d')),
      findsOneWidget,
      reason: 'the hero should count down to the next bus',
    );
  });

  testWidgets('countdown ticks down on its own', (tester) async {
    var now = DateTime(2026, 8, 6, 6);
    debugUpcomingClock = () => now;
    await pumpSection(tester);

    String countdown() => (tester.widget<Text>(
          find.textContaining(RegExp(r'^in \d')),
        ).data)!;

    final before = countdown();

    // Advance the pinned clock and let the section's 1s ticker fire. The old
    // card computed its time once in build() and never rebuilt, so this is the
    // regression that matters most.
    now = now.add(const Duration(minutes: 5));
    await tester.pump(const Duration(seconds: 1));

    expect(countdown(), isNot(before));
  });

  testWidgets('hero flips to the boarding state when the bus is due',
      (tester) async {
    // 8:30 AM is a real student departure, so at exactly that minute the bus
    // is at the stop rather than "in 0s".
    pinClock(DateTime(2026, 8, 6, 8, 30));
    await pumpSection(tester);

    expect(find.text('DEPARTING NOW'), findsOneWidget);
    expect(find.text('At the stop'), findsOneWidget);
    expect(find.text('NEXT DEPARTURE'), findsNothing);
  });

  testWidgets('after the last bus the hero rolls over and says Tomorrow',
      (tester) async {
    // 11:30 PM: every trip for today has gone.
    pinClock(DateTime(2026, 8, 6, 23, 30));
    await pumpSection(tester);

    expect(find.text('Tomorrow'), findsOneWidget);
    // The old card gave up here with "No more trips today"; the hero still
    // names the next actual departure.
    expect(find.text('NEXT DEPARTURE'), findsOneWidget);
  });

  testWidgets('guests get a sign-in row instead of an exam row',
      (tester) async {
    pinClock(DateTime(2026, 8, 6, 6));
    await pumpSection(tester);

    expect(find.text('Sign in to see your classes'), findsOneWidget);
  });

  testWidgets('header carries the date the countdown is relative to',
      (tester) async {
    pinClock(DateTime(2026, 8, 6, 6)); // A Thursday.
    await pumpSection(tester);

    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('Today, Thu 6 Aug'), findsOneWidget);
  });

  testWidgets('the dead "View All" badge is gone', (tester) async {
    pinClock(DateTime(2026, 8, 6, 6));
    await pumpSection(tester);

    // It looked like a button but was inert, and it sat on every card.
    expect(find.text('View All'), findsNothing);
  });
}
