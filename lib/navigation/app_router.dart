// Developed by Rajesh Biswas (rajeshbiswas.dev)
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/about_screen.dart';
import '../screens/attendance_screen.dart';
import '../screens/blood_help_screen.dart';
import '../screens/bus_schedule_screen.dart';
import '../screens/class_notices_screen.dart';
import '../screens/login_screen.dart';
import '../screens/lost_found_screen.dart';
import '../screens/main_scaffold.dart';
import '../screens/register_screen.dart';
import '../screens/splash_screen.dart';

/// Route path constants.
abstract class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String search = '/search';
  static const String alerts = '/alerts';
  static const String profile = '/profile';
  static const String bus = '/bus';
  static const String notices = '/notices';
  static const String blood = '/blood';
  static const String lostFound = '/lost-found';
  static const String attendance = '/attendance';
  static const String about = '/about';
  static const String login = '/login';
  static const String register = '/register';
  static const String splash = '/splash';
}

/// Declarative router for the app.
///
/// The root [MainScaffold] owns the bottom navigation state. Sub-pages are
/// pushed on top as standard routes so the back button works naturally.
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (_, __) => const SplashScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => MainScaffold(
        navigationShell: navigationShell,
      ),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.search,
              builder: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.alerts,
              builder: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.about,
              builder: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.profile,
              builder: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: AppRoutes.bus,
      builder: (_, __) => const BusScheduleScreen(),
    ),
    GoRoute(
      path: AppRoutes.notices,
      builder: (_, __) => const ClassNoticesScreen(),
    ),
    GoRoute(
      path: AppRoutes.blood,
      builder: (_, __) => const BloodHelpScreen(),
    ),
    GoRoute(
      path: AppRoutes.lostFound,
      builder: (_, __) => const LostFoundScreen(),
    ),
    GoRoute(
      path: AppRoutes.attendance,
      builder: (_, __) => const AttendanceScreen(),
    ),
    GoRoute(
      path: AppRoutes.about,
      builder: (_, __) => const AboutScreen(),
    ),
    GoRoute(
      path: AppRoutes.login,
      builder: (_, __) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.register,
      builder: (_, __) => const RegisterScreen(),
    ),
  ],
);
