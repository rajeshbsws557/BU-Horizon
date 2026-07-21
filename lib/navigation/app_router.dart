// Developed by Rajesh Biswas (rajeshbiswas.dev)
import 'package:go_router/go_router.dart';

import '../di/di.dart';
import '../screens/about_screen.dart';
import '../screens/alerts_screen.dart';
import '../screens/attendance_screen.dart';
import '../screens/blood_help_screen.dart';
import '../screens/bus_schedule_screen.dart';
import '../screens/class_notices_screen.dart';
import '../screens/exam_schedule_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/lost_found_screen.dart';
import '../screens/main_scaffold.dart';
import '../screens/people_search_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/register_screen.dart';
import '../screens/resources_screen.dart';
import '../screens/splash_screen.dart';
import '../supabase/session_controller.dart';
import '../supabase/supabase_config.dart';

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
  static const String exams = '/exams';
  static const String resources = '/resources';
  static const String about = '/about';
  static const String login = '/login';
  static const String register = '/register';
  static const String splash = '/splash';

  /// Members-only sections. Guests can browse everything else without an
  /// account; only these need a signed-in session (product decision: guests
  /// see the tiles but cannot enter Class Notices, Attendance, People Search,
  /// Exam Schedule or Resources — the database enforces this too, their read
  /// policies are authenticated-only). The UI shows a "sign in required"
  /// sheet before navigating here — this set also backs the router-level
  /// safety net for deep links.
  static const Set<String> membersOnly = {
    notices,
    attendance,
    search,
    exams,
    resources,
  };
}

/// Declarative router for the app.
///
/// The root [MainScaffold] owns the bottom navigation state. Sub-pages are
/// pushed on top as standard routes so the back button works naturally.
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  // Re-evaluate redirects whenever the auth session changes (sign-in/out).
  refreshListenable: getIt<SessionController>(),
  redirect: (context, state) {
    // When Supabase isn't configured (UI-only builds), skip auth gating so the
    // app remains fully navigable for design work.
    if (!SupabaseConfig.isConfigured) return null;

    final signedIn = getIt<SessionController>().isSignedIn;
    final location = state.matchedLocation;

    // Guest-first: the app opens without an account. Only members-only
    // sections require a session (normally intercepted with a "sign in
    // required" sheet before navigation — this catches deep links).
    if (!signedIn && AppRoutes.membersOnly.contains(location)) {
      return AppRoutes.login;
    }

    // Authenticated users have no reason to sit on login/register.
    final onAuthScreen =
        location == AppRoutes.login || location == AppRoutes.register;
    if (signedIn && onAuthScreen) return AppRoutes.home;

    return null;
  },
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
              builder: (_, __) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.search,
              builder: (_, __) => const PeopleSearchScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.alerts,
              builder: (_, __) => const AlertsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.about,
              builder: (_, __) => const AboutScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.profile,
              builder: (_, __) => const ProfileScreen(),
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
      path: AppRoutes.exams,
      builder: (_, __) => const ExamScheduleScreen(),
    ),
    GoRoute(
      path: AppRoutes.resources,
      builder: (_, __) => const ResourcesScreen(),
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
