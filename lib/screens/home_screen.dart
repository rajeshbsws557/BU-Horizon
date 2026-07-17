import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/sample_data.dart';
import '../models/models.dart';
import '../navigation/app_router.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import '../widgets/theme_toggle.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _open(BuildContext context, QuickAction a) {
    if (a.route.isNotEmpty) {
      context.push(a.route);
    } else {
      showToast(context, '${a.title} opened');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
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
                          onBell: () => context.push(AppRoutes.alerts),
                        ),
                      ),
                      const SizedBox(height: 22),
                      GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isWide ? 4 : 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          mainAxisExtent: 110,
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
                      Entrance(
                        index: 8,
                        child: _UpcomingCard(
                          icon: Icons.directions_bus_rounded,
                          title: 'BU Bus Schedule · Student Route 01',
                          time: 'Next Departure: 8:30 AM (বিশ্ববিদ্যালয়)',
                          badge: 'View All',
                          onTap: () => context.push(AppRoutes.bus),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Entrance(
                        index: 9,
                        child: _UpcomingCard(
                          icon: Icons.event_note_rounded,
                          title: 'CSE 3rd Sem Class',
                          time: '10:00 AM',
                        ),
                      ),
                      const SizedBox(height: 26),
                      const Entrance(index: 10, child: _SectionTitle("Today's Class")),
                      const SizedBox(height: 12),
                      Entrance(index: 11, child: _TodayClassCard()),
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
    return ValueListenableBuilder<bool>(
      valueListenable: SampleData.isLoggedIn,
      builder: (context, isLoggedIn, _) {
        final name = isLoggedIn ? SampleData.studentName : 'Guest';
        final initials = isLoggedIn
            ? SampleData.studentName
                .trim()
                .split(RegExp(r'\s+'))
                .map((w) => w[0])
                .take(2)
                .join()
                .toUpperCase()
            : null;
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
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                child: initials != null
                    ? Text(
                        initials,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : const Icon(Icons.person_rounded,
                        color: AppColors.primary, size: 24),
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
                      '$name  👋',
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
      label: showBadge ? 'Notifications, 3 unread' : 'Notifications',
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
                      decoration: const BoxDecoration(
                        color: AppColors.danger,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(action.icon, color: action.color, size: 20),
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
          ),
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
                      color: AppColors.primary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: AppColors.primary,
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

class _TodayClassCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Today\'s class Data Structures, 9:00 AM to 10:00 AM, Room 301',
      child: Container(
        padding: const EdgeInsets.all(16),
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
                    'Data Structures',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '9:00 AM - 10:00 AM',
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'ROOM 301',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
