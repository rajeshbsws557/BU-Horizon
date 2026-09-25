import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/university_bus_schedule_data.dart';
import '../di/di.dart';
import '../navigation/app_router.dart';
import '../repositories/exam_repository.dart';
import '../services/bus_schedule_controller.dart';
import '../services/home_refresh_state.dart';
import '../services/next_departure_resolver.dart';
import '../supabase/session_controller.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'motion.dart';

/// Overridable clock so widget tests can pin "now" instead of racing the wall
/// clock. Mirrors `debugNextDepartureClock` in the bus schedule screen.
@visibleForTesting
DateTime Function()? debugUpcomingClock;

/// The home screen's "Upcoming" block.
///
/// The most imminent item (the next student bus) gets a full-width hero with a
/// live countdown; everything else collapses into compact rows. This replaces
/// two identical grey cards where the departure time — the only thing anyone
/// actually reads — was the smallest text on screen and never updated.
class UpcomingSection extends StatefulWidget {
  /// Stagger offset for this section's entrance animations, so the three rows
  /// animate in after whatever sits above them rather than racing it. The
  /// section moved above the Quick Access grid, so the caller owns the ordering.
  final int startIndex;

  const UpcomingSection({super.key, this.startIndex = 0});

  @override
  State<UpcomingSection> createState() => _UpcomingSectionState();
}

class _UpcomingSectionState extends State<UpcomingSection> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // One-second cadence so the countdown reads like a clock and the hero rolls
    // over to the following bus on its own. Cancelled in dispose, so it cannot
    // outlive the screen.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    getIt<BusScheduleController>().ensureLoaded();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = debugUpcomingClock?.call() ?? DateTime.now();
    final session = getIt<SessionController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Entrance(
          index: widget.startIndex,
          child: _UpcomingHeader(now: now),
        ),
        const SizedBox(height: 12),
        Entrance(
          index: widget.startIndex + 1,
          child: ListenableBuilder(
            listenable: Listenable.merge([getIt<BusScheduleController>()]),
            builder: (context, _) => _NextBusHero(
              now: now,
              categories: getIt<BusScheduleController>().categories,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Entrance(
          index: widget.startIndex + 2,
          child: ListenableBuilder(
            listenable: session,
            builder: (context, _) => session.isSignedIn
                ? const _NextExamRow()
                : _SignInInviteRow(
                    onSignIn: () => context.push(AppRoutes.login),
                  ),
          ),
        ),
      ],
    );
  }
}

/// "Upcoming" plus the date it is relative to, so the countdown below has
/// context instead of floating free.
class _UpcomingHeader extends StatelessWidget {
  final DateTime now;
  const _UpcomingHeader({required this.now});

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final label =
        'Today, ${_weekdays[now.weekday - 1]} ${now.day} ${_months[now.month - 1]}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upcoming',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: context.colors.textMuted,
          ),
        ),
      ],
    );
  }
}

/// The next student-bus departure across every student route, resolved live
/// against the clock.
///
/// Uses the shared [resolveNextDeparture] instead of a private parser, so the
/// home hero, the bus screen spotlight and the alarm system all agree on which
/// bus is "next" — including the wrap-around to tomorrow after the last bus of
/// the day, which the old home-screen parser got wrong (it simply showed
/// "No more trips today").
class _NextBusHero extends StatelessWidget {
  final DateTime now;
  final List<UniversityBusCategory> categories;
  const _NextBusHero({required this.now, required this.categories});

  /// Earliest departure at or after [now] across all student routes, with the
  /// owning route attached.
  static ({UniversityBusRoute route, NextDeparture departure})? _resolve(
    DateTime now,
    List<UniversityBusCategory> categories,
  ) {
    if (categories.isEmpty) return null;
    final student = categories.firstWhere(
      (c) => c.title == 'Student',
      orElse: () => categories.first,
    );

    ({UniversityBusRoute route, NextDeparture departure})? best;
    for (final route in student.routes) {
      final next = resolveNextDeparture(route.departureSections, now: now);
      if (next == null) continue;
      if (best == null || next.departsAt.isBefore(best.departure.departsAt)) {
        best = (route: route, departure: next);
      }
    }
    return best;
  }

  /// "চিত্রা, বিআরটিসি-০৫" -> ["চিত্রা", "বিআরটিসি-০৫"]. Some evening trips
  /// list six slash-separated coaches, so the caller caps what it renders.
  @override
  Widget build(BuildContext context) {
    final found = _resolve(now, categories);
    if (found == null) return const _BusHeroFallback();

    final departure = found.departure;
    final remaining = departure.timeUntil(now);

    return _BusHeroBody(
      routeName: found.route.routeName,
      departurePlace: departure.departurePlace,
      time: departure.trip.time,
      tags: busOperatorChipLabels(departure.trip.busName),
      countdown: formatCountdown(remaining),
      // '' today, 'Tomorrow' next day, otherwise the weekday — a route that
      // only runs Fri & Sat can be several days out.
      dayLabel: formatDepartureDay(departure.daysAhead, departure.departsAt),
      // Inside the resolver's grace beat the bus is at the stop, not late.
      isBoarding: remaining.inSeconds <= 0,
    );
  }
}

/// Visual body of the hero. Split from the resolver above so the layout can be
/// read without the time maths in the way.
class _BusHeroBody extends StatelessWidget {
  final String routeName;
  final String departurePlace;
  final String time;
  final List<String> tags;
  final String countdown;
  final String dayLabel;
  final bool isBoarding;

  const _BusHeroBody({
    required this.routeName,
    required this.departurePlace,
    required this.time,
    required this.tags,
    required this.countdown,
    required this.dayLabel,
    required this.isBoarding,
  });

  /// "10:15 AM" -> ("10:15", "AM") so the meridiem can be set smaller.
  static (String, String) _splitTime(String raw) {
    final parts = raw.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return (raw.trim(), '');
    return (parts.first, parts.sublist(1).join(' '));
  }

  @override
  Widget build(BuildContext context) {
    // Flips to green the moment the bus is due, so colour alone tells you
    // whether you still have time to walk over. Same rule as the bus screen.
    final accent = isBoarding ? context.colors.success : context.colors.primary;
    final (clock, meridiem) = _splitTime(time);

    return Semantics(
      button: true,
      excludeSemantics: true,
      label: isBoarding
          ? 'Bus departing now from $departurePlace, $routeName at $time. '
                'Open the bus schedule.'
          : 'Next bus in $countdown at $time from $departurePlace, $routeName'
                '${dayLabel.isEmpty ? '' : ', $dayLabel'}. Open the bus schedule.',
      child: Pressable(
        onTap: () => context.push(AppRoutes.bus),
        child: GlassCard(
          gradient: context.colors.heroGradient,
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: _StatusPill(
                      accent: accent,
                      label: isBoarding ? 'DEPARTING NOW' : 'NEXT DEPARTURE',
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CountdownPill(
                    accent: accent,
                    label: isBoarding ? 'At the stop' : 'in $countdown',
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // The time is the whole point of the card, so it gets the
                      // largest type instead of the old 12.5px caption.
                      Text.rich(
                        TextSpan(
                          text: clock,
                          children: [
                            if (meridiem.isNotEmpty)
                              TextSpan(
                                text: ' $meridiem',
                                style: const TextStyle(fontSize: 13),
                              ),
                          ],
                        ),
                        style: TextStyle(
                          fontSize: 23,
                          height: 1.05,
                          fontWeight: FontWeight.w800,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      // After the last bus of the day, say which day the next
                      // one leaves rather than implying one is still coming.
                      if (dayLabel.isNotEmpty)
                        Text(
                          dayLabel,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textMuted,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'From $departurePlace',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: context.colors.primary,
                          ),
                        ),
                        if (tags.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          _BusTags(tags: tags),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(height: 1, color: context.colors.border),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Student · $routeName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'View schedule',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: context.colors.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: context.colors.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when no trip in the timetable has a parseable time — better than an
/// empty slot or, worse, a confidently wrong departure.
class _BusHeroFallback extends StatelessWidget {
  const _BusHeroFallback();

  @override
  Widget build(BuildContext context) {
    return _UpcomingRow(
      icon: Icons.directions_bus_rounded,
      tint: context.colors.primary,
      title: 'BU Bus Schedule',
      subtitle: 'Timetable unavailable right now',
      onTap: () => context.push(AppRoutes.bus),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final Color accent;
  final String label;
  const _StatusPill({required this.accent, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, size: 15, color: accent),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownPill extends StatelessWidget {
  final Color accent;
  final String label;
  const _CountdownPill({required this.accent, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Coach names for the trip. Capped at two because the evening trips list six
/// slash-separated coaches, which would wrap the hero onto a third line.
class _BusTags extends StatelessWidget {
  final List<String> tags;
  const _BusTags({required this.tags});

  static const _maxTags = 2;

  @override
  Widget build(BuildContext context) {
    final shown = tags.take(_maxTags).toList();
    final hidden = tags.length - shown.length;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final tag in shown) _tag(context, tag),
        if (hidden > 0) _tag(context, '+$hidden'),
      ],
    );
  }

  Widget _tag(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: context.colors.textMuted.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: context.colors.textSecondary,
        ),
      ),
    );
  }
}

/// A secondary item under the hero: icon tile, title, subtitle, optional
/// trailing label. Deliberately shorter than the hero so the section reads as
/// "this first, then these".
class _UpcomingRow extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final String title;
  final String subtitle;
  final String? trailing;
  final VoidCallback? onTap;

  const _UpcomingRow({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      excludeSemantics: true,
      label: '$title. $subtitle${trailing != null ? '. $trailing' : ''}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            decoration: BoxDecoration(
              color: context.colors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: context.colors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: tint, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    trailing!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: context.colors.primary,
                    ),
                  ),
                ],
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: context.colors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The signed-in student's next exam, fetched live from their batch schedule.
class _NextExamRow extends StatefulWidget {
  const _NextExamRow();

  @override
  State<_NextExamRow> createState() => _NextExamRowState();
}

class _NextExamRowState extends State<_NextExamRow> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    homeExamItems.addListener(_itemsChanged);
    if (homeExamItems.value == null) _load();
  }

  @override
  void dispose() {
    homeExamItems.removeListener(_itemsChanged);
    super.dispose();
  }

  void _itemsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      homeExamItems.value = await getIt<ExamRepository>().fetchExams();
    } catch (_) {
      // The row falls back to a clear unavailable state below.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && homeExamItems.value == null) {
      return const _UpcomingRowSkeleton();
    }

    final exams = homeExamItems.value;
    if (exams == null) {
      return _UpcomingRow(
        icon: Icons.sync_problem_rounded,
        tint: context.colors.warning,
        title: 'Exam schedule unavailable',
        subtitle: 'Tap to open the schedule and retry',
        onTap: () => context.push(AppRoutes.exams),
      );
    }
    if (exams.isEmpty) {
      return _UpcomingRow(
        icon: Icons.edit_calendar_rounded,
        tint: context.colors.purple,
        title: 'Exam Schedule',
        subtitle: 'No exams scheduled right now',
        onTap: () => context.push(AppRoutes.exams),
      );
    }

    final next = exams.first;
    final room = next.room.isEmpty ? '' : ' · Room ${next.room}';
    return _UpcomingRow(
      icon: Icons.edit_calendar_rounded,
      tint: context.colors.purple,
      title: '${next.typeLabel} · ${next.title}',
      subtitle: '${next.dateLabel} · ${next.timeLabel}$room',
      onTap: () => context.push(AppRoutes.exams),
    );
  }
}

/// Shimmer placeholder matching the row's geometry, so the section does not
/// jump when the exam request resolves.
class _UpcomingRowSkeleton extends StatelessWidget {
  const _UpcomingRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Skeleton(height: 38, width: 38, radius: BorderRadius.circular(11)),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Skeleton(height: 11, width: 150),
                SizedBox(height: 6),
                Skeleton(height: 9, width: 96),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Guest nudge shown where the student's exam row would be.
class _SignInInviteRow extends StatelessWidget {
  final VoidCallback onSignIn;
  const _SignInInviteRow({required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    return _UpcomingRow(
      icon: Icons.lock_open_rounded,
      tint: context.colors.primary,
      title: 'Sign in to see your classes',
      subtitle: 'Notices, exams, resources and attendance for your batch',
      trailing: 'Sign in',
      onTap: onSignIn,
    );
  }
}
