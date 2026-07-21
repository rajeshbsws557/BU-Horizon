import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/sample_data.dart';
import '../data/university_bus_schedule_data.dart';
import '../di/di.dart';
import '../models/models.dart';
import '../navigation/app_router.dart';
import '../repositories/exam_repository.dart';
import '../supabase/session_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/login_gate.dart';
import '../widgets/motion.dart';
import '../widgets/theme_toggle.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _open(BuildContext context, QuickAction a) {
    if (a.route.isEmpty) {
      showToast(context, '${a.title} opened');
      return;
    }
    // '/people' lives on the Search tab rather than a pushable route.
    final target = a.route == '/people' ? AppRoutes.search : a.route;
    if (AppRoutes.membersOnly.contains(target) &&
        !requireSignIn(context, a.title)) {
      return;
    }
    if (target == AppRoutes.search) {
      context.go(target);
    } else {
      context.push(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        color: context.colors.primary,
        backgroundColor: context.colors.surfaceAlt,
        onRefresh: () async => Future<void>.delayed(const Duration(milliseconds: 600)),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 768;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Entrance(
                        index: 0,
                        child: _GreetingHero(
                          onBell: () => context.go(AppRoutes.alerts),
                        ),
                      ),
                      const SizedBox(height: 22),
                      GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isWide ? 4 : 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          mainAxisExtent: 110 *
                              MediaQuery.textScalerOf(context)
                                  .scale(1.0)
                                  .clamp(1.0, 1.6),
                        ),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: SampleData.quickActions.length,
                        itemBuilder: (context, i) {
                          final a = SampleData.quickActions[i];
                          return Entrance(
                            index: 1 + i,
                            child: _ActionCard(
                              action: a,
                              onTap: () => _open(context, a),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 26),
                      const Entrance(index: 7, child: _SectionTitle('Upcoming')),
                      const SizedBox(height: 12),
                      const Entrance(index: 8, child: _NextBusCard()),
                      const SizedBox(height: 10),
                      Entrance(
                        index: 9,
                        child: ListenableBuilder(
                          listenable: getIt<SessionController>(),
                          builder: (context, _) =>
                              getIt<SessionController>().isSignedIn
                                  ? const _NextExamCard()
                                  : _SignInInviteCard(
                                      onSignIn: () =>
                                          context.push(AppRoutes.login),
                                    ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Frosted greeting card with a soft gradient wash and avatar.
/// Greeting text adapts to the time of day instead of always saying "morning".
class _GreetingHero extends StatelessWidget {
  final VoidCallback onBell;
  const _GreetingHero({required this.onBell});

  static String _greeting(DateTime now) {
    final h = now.hour;
    if (h < 12) return 'Good Morning,';
    if (h < 17) return 'Good Afternoon,';
    if (h < 21) return 'Good Evening,';
    return 'Good Night,';
  }

  @override
  Widget build(BuildContext context) {
    final session = getIt<SessionController>();
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final isLoggedIn = session.isSignedIn;
        final profile = session.profile;
        final name = isLoggedIn
            ? (profile?.fullName.isNotEmpty == true ? profile!.fullName : 'Student')
            : 'Guest';
        final initials = isLoggedIn ? (profile?.initials ?? '?') : null;
        return GlassCard(
          gradient: context.isLight
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE8F0FE), Color(0xFFFFFFFF)],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0x332E7DF6), Color(0x110E1524)],
                ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: context.colors.primary.withValues(alpha: 0.2),
                child: initials != null
                    ? Text(
                        initials,
                        style: TextStyle(
                          color: context.colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : Icon(Icons.person_rounded,
                        color: context.colors.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting(DateTime.now()),
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$name 👋',
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const ThemeToggleIcon(),
              const SizedBox(width: 10),
              _NotifBell(onTap: onBell, showBadge: isLoggedIn),
            ],
          ),
        );
      },
    );
  }
}

class _NotifBell extends StatelessWidget {
  final VoidCallback onTap;
  final bool showBadge;
  const _NotifBell({required this.onTap, this.showBadge = true});
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Notifications',
      child: Tooltip(
        message: 'Notifications',
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.colors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.border),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.notifications_none_rounded,
                  color: context.colors.textPrimary,
                ),
                if (showBadge)
                  Positioned(
                    top: 11,
                    right: 12,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: context.colors.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final QuickAction action;
  final VoidCallback onTap;
  const _ActionCard({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: action.title,
      hint: action.subtitle,
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.colors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: context.colors.border),
          ),
          child: Builder(builder: (context) {
            // Sample data stores AppColorToken sentinels; resolve to live theme.
            final actionColor = context.colors.resolve(action.color);
            return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: actionColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(action.icon, color: actionColor, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                action.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                action.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.colors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          );
          }),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: context.colors.textPrimary,
        ),
      );
}

class _UpcomingCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String time;
  final String? badge;
  final VoidCallback? onTap;
  const _UpcomingCard({
    required this.icon,
    required this.title,
    required this.time,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$title at $time${badge != null ? ', $badge' : ''}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colors.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.colors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        time,
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: context.colors.primary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badge!,
                      style: TextStyle(
                        color: context.colors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  Icon(icon, color: context.colors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The next student-bus departure, computed live from the official BU
/// timetable (`university_bus_schedule_data.dart` — the canonical source;
/// the database does not carry the timetable yet).
class _NextBusCard extends StatelessWidget {
  const _NextBusCard();

  static DateTime? _tripTime(String raw, DateTime now) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false)
        .firstMatch(raw.trim());
    if (m == null) return null;
    var hour = int.parse(m.group(1)!) % 12;
    if (m.group(3)!.toUpperCase() == 'PM') hour += 12;
    return DateTime(now.year, now.month, now.day, hour, int.parse(m.group(2)!));
  }

  /// Earliest departure at or after [now] across all student routes.
  static ({String route, String place, String time})? _next(DateTime now) {
    final student = UniversityBusScheduleData.categories.firstWhere(
      (c) => c.title == 'Student',
      orElse: () => UniversityBusScheduleData.categories.first,
    );
    DateTime? best;
    ({String route, String place, String time})? found;
    for (final route in student.routes) {
      for (final section in route.departureSections) {
        for (final trip in section.trips) {
          final t = _tripTime(trip.time, now);
          if (t == null || t.isBefore(now)) continue;
          if (best == null || t.isBefore(best)) {
            best = t;
            found = (
              route: route.routeName,
              place: section.departurePlace,
              time: trip.time,
            );
          }
        }
      }
    }
    return found;
  }

  @override
  Widget build(BuildContext context) {
    final next = _next(DateTime.now());
    return _UpcomingCard(
      icon: Icons.directions_bus_rounded,
      title: next == null
          ? 'BU Bus Schedule'
          : 'BU Bus Schedule · Student ${next.route}',
      time: next == null
          ? 'No more trips today — service resumes in the morning'
          : 'Next Departure: ${next.time} (${next.place})',
      badge: 'View All',
      onTap: () => context.push(AppRoutes.bus),
    );
  }
}

/// The signed-in student's next exam, fetched live from their batch schedule.
class _NextExamCard extends StatelessWidget {
  const _NextExamCard();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ExamItem>>(
      future: getIt<ExamRepository>().fetchExams(),
      builder: (context, snapshot) {
        final exams = snapshot.data ?? const <ExamItem>[];
        if (exams.isEmpty) {
          return _UpcomingCard(
            icon: Icons.edit_calendar_rounded,
            title: 'Exam Schedule',
            time: snapshot.connectionState == ConnectionState.waiting
                ? 'Checking for upcoming exams…'
                : 'No exams scheduled right now',
            badge: 'Open',
            onTap: () => context.push(AppRoutes.exams),
          );
        }
        final next = exams.first;
        return _UpcomingCard(
          icon: Icons.edit_calendar_rounded,
          title: '${next.typeLabel}: ${next.title}',
          time: '${next.dateLabel} · ${next.timeLabel}',
          badge: 'View All',
          onTap: () => context.push(AppRoutes.exams),
        );
      },
    );
  }
}

/// Guest nudge shown where the student's class/exam card would be.
class _SignInInviteCard extends StatelessWidget {
  final VoidCallback onSignIn;
  const _SignInInviteCard({required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    return _UpcomingCard(
      icon: Icons.lock_open_rounded,
      title: 'Sign in to see your classes',
      time: 'Notices, exams, resources and attendance for your batch',
      badge: 'Sign In',
      onTap: onSignIn,
    );
  }
}
