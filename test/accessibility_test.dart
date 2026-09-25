// Developed by Rajesh Biswas (rajeshbiswas.dev)
//
// Release accessibility guardrails for the screens reworked in this pass.
//
// These use Flutter's own published guidelines rather than hand-rolled checks:
//  * [iOSTapTargetGuideline]    — every tap target is at least 44x44 logical px,
//                                 which is the minimum this app commits to.
//  * [labeledTapTargetGuideline] — no tap target reaches a screen reader unnamed.
//  * [textContrastGuideline]    — text meets WCAG AA against its background.
// Plus a render pass at 1.6x text scale, so a large-text user does not get
// clipped rows or overflowing layouts.
import 'package:bu_horizon/di/di.dart';
import 'package:bu_horizon/screens/about_screen.dart';
import 'package:bu_horizon/screens/alerts_screen.dart';
import 'package:bu_horizon/screens/bus_schedule_screen.dart';
import 'package:bu_horizon/screens/notifications_screen.dart';
import 'package:bu_horizon/screens/resources_screen.dart';
import 'package:bu_horizon/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(configureDependencies);

  /// Advances a few frames. Several of these screens hold looping animations
  /// (shimmer skeletons, the bus countdown), so `pumpAndSettle` never returns.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  /// Renders [screen] on a phone-sized surface with the real app theme, so the
  /// contrast check sees production colours rather than Material defaults.
  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    double textScale = 1.0,
    bool dark = false,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.dark : AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(body: screen),
      ),
    );
    await settle(tester);
  }

  /// Every screen in this list is one the release punch-list touched.
  final screens = <String, Widget Function()>{
    'Bus Schedule': () => const BusScheduleScreen(),
    'Notifications': () => const NotificationsScreen(),
    'Public Notices': () => const AlertsScreen(),
    'Resources': () => const ResourcesScreen(),
    'About': () => const AboutScreen(),
  };

  group('tap targets are at least 44x44', () {
    for (final entry in screens.entries) {
      testWidgets(entry.key, (tester) async {
        await pumpScreen(tester, entry.value());
        final handle = tester.ensureSemantics();
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        handle.dispose();
      });
    }
  });

  group('every tap target is labelled for a screen reader', () {
    for (final entry in screens.entries) {
      testWidgets(entry.key, (tester) async {
        await pumpScreen(tester, entry.value());
        final handle = tester.ensureSemantics();
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    }
  });

  group('text meets WCAG AA contrast', () {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} (light)', (tester) async {
        await pumpScreen(tester, entry.value());
        final handle = tester.ensureSemantics();
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });

      testWidgets('${entry.key} (dark)', (tester) async {
        await pumpScreen(tester, entry.value(), dark: true);
        final handle = tester.ensureSemantics();
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
  });

  group('renders without overflow at 1.6x text scale', () {
    for (final entry in screens.entries) {
      testWidgets(entry.key, (tester) async {
        await pumpScreen(tester, entry.value(), textScale: 1.6);
        // A RenderFlex/RenderBox overflow is reported as a FlutterError, so a
        // clipped row at large text fails here instead of shipping.
        expect(tester.takeException(), isNull);
      });
    }
  });
}
