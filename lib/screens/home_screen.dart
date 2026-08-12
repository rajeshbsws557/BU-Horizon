import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/home_cards_cubit.dart';
import '../data/home_cards.dart';
import '../di/di.dart';
import '../models/models.dart';
import '../navigation/app_router.dart';
import '../repositories/blood_repository.dart';
import '../supabase/session_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/home_cards_customizer.dart';
import '../widgets/login_gate.dart';
import '../widgets/motion.dart';
import '../widgets/theme_toggle.dart';
import '../widgets/upcoming_section.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _open(BuildContext context, HomeCard card) {
    if (card.route.isEmpty) {
      showToast(context, '${card.title} opened');
      return;
    }
    final target = card.route;
    if (AppRoutes.membersOnly.contains(target) &&
        !requireSignIn(context, card.title)) {
      return;
    }
    // The tab destinations (Clubs / Alerts) live in the shell's branches, so
    // switch branches instead of stacking a new route. Everything else is a
    // top-level route and must be *pushed* — using `go` on those would replace
    // the whole stack, leaving nothing to pop back to (back would exit the app).
    if (_isTabRoute(target)) {
      context.go(target);
    } else {
      context.push(target);
    }
  }

  static bool _isTabRoute(String route) => const {
        AppRoutes.club,
        AppRoutes.alerts,
      }.contains(route);


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
                          onBell: () => context.push(AppRoutes.notifications),
                        ),
                      ),

                      const SizedBox(height: 16),
                      Entrance(
                        index: 1,
                        child: _LegalHelpCard(
                          onTap: () => context.push(AppRoutes.legalHelp),
                        ),
                      ),
                      const _UrgentBloodCard(),
                      const SizedBox(height: 22),
                      Entrance(
                        index: 3,
                        child: _QuickAccessHeader(
                          onCustomize: () => showHomeCardsCustomizer(context),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Only the student's pinned cards render here — two by
                      // default (Class Notices + Bus Schedule); the rest are
                      // opt-in through the customizer.
                      BlocBuilder<HomeCardsCubit, List<HomeCard>>(
                        builder: (context, cards) {
                          if (cards.isEmpty) {
                            return _NoCardsCard(
                              onCustomize: () =>
                                  showHomeCardsCustomizer(context),
                            );
                          }
                          return GridView.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
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
                            itemCount: cards.length,
                            itemBuilder: (context, i) {
                              final card = cards[i];
                              return Entrance(
                                key: ValueKey('home-card-${card.id}'),
                                index: 3 + i,
                                child: _ActionCard(
                                  card: card,
                                  onTap: () => _open(context, card),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 26),
                      // Hero + compact rows: the next departure carries a live
                      // countdown, so the section stays correct while the
                      // student is looking at it.
                      const UpcomingSection(),
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

/// Prominent double-height card giving victims of cyber-bullying and
/// harassment a direct path to request legal help.
class _LegalHelpCard extends StatelessWidget {
  final VoidCallback onTap;
  const _LegalHelpCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final danger = context.colors.danger;
    return Semantics(
      button: true,
      label: 'Report cyber-bullying and request legal help',
      child: Pressable(
        onTap: onTap,
        child: Container(
          // A fixed height clipped the body copy on narrow phones (it wraps to
          // more lines there), so grow past the design height when needed.
          constraints: const BoxConstraints(minHeight: 148),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                danger.withValues(alpha: 0.22),
                context.colors.primary.withValues(alpha: 0.10),
              ],
            ),
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: danger.withValues(alpha: 0.30)),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: danger.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Icon(Icons.shield_rounded, color: danger, size: 30),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Legal Help & Safety',
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Facing cyber-bullying or harassment? Report it confidentially '
                      'and request legal help.',
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Text(
                          'Request help',
                          style: TextStyle(
                            color: danger,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, color: danger, size: 16),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Home-screen spotlight for the currently-active urgent blood request.
///
/// Shows the oldest still-active urgent request (backed by the
/// `active_urgent_blood_requests` view, which enforces the 6-hour window). When
/// that request's window ends the card swaps to the next one, or hides when
/// none remain. Collapses to nothing while loading or when there is none, so
/// the slot below the Legal Help card takes no space unless there is something
/// urgent to show. All urgent requests still appear in the Blood Help section.
class _UrgentBloodCard extends StatefulWidget {
  const _UrgentBloodCard();

  @override
  State<_UrgentBloodCard> createState() => _UrgentBloodCardState();
}

class _UrgentBloodCardState extends State<_UrgentBloodCard> {
  BloodRequest? _request;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    // Re-fetch periodically so the card advances when the active request's 6h
    // window ends (the view drops it) and picks up newly-posted urgent requests.
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final request = await getIt<BloodRepository>().fetchActiveUrgentRequest();
      if (mounted) setState(() => _request = request);
    } catch (_) {
      // Best-effort: a failed poll leaves the last-known state untouched.
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;
    if (request == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Entrance(
        index: 2,
        child: _UrgentBloodCardBody(
          request: request,
          onTap: () => context.push(AppRoutes.blood),
        ),
      ),
    );
  }
}

/// Visual body of the urgent blood card — mirrors the urgent-need card in the
/// Blood Help screen (blood gradient, white text) so it reads as the same
/// affordance, and sits directly below the Legal Help & Safety card.
class _UrgentBloodCardBody extends StatelessWidget {
  final BloodRequest request;
  final VoidCallback onTap;
  const _UrgentBloodCardBody({required this.request, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      excludeSemantics: true,
      label:
          'Urgent blood needed. ${request.units} units of ${request.group.label} '
          'at ${request.location}. Contact ${request.contact}. Posted ${request.time}. '
          'Open Blood Help.',
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: context.colors.bloodGradient,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            boxShadow: [
              BoxShadow(
                color: context.colors.danger.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: const Icon(Icons.water_drop_rounded,
                    color: Colors.white, size: 30),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Urgent: Blood Needed',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          request.time,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${request.units} unit${request.units == 1 ? '' : 's'} '
                      '(${request.group.label}) · ${request.location}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 9),
                    const Row(
                      children: [
                        Text(
                          'Respond now',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 16),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Quick Access" section title with the entry point to the card customizer.
class _QuickAccessHeader extends StatelessWidget {
  final VoidCallback onCustomize;
  const _QuickAccessHeader({required this.onCustomize});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: _SectionTitle('Quick Access')),
        Semantics(
          button: true,
          label: 'Customize home cards',
          child: Tooltip(
            message: 'Add or reorder cards',
            child: Material(
              color: context.colors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: onCustomize,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.dashboard_customize_rounded,
                        size: 16,
                        color: context.colors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Customize',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: context.colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Shown when the student has removed every card, so the section still has an
/// obvious way back rather than silently collapsing.
class _NoCardsCard extends StatelessWidget {
  final VoidCallback onCustomize;
  const _NoCardsCard({required this.onCustomize});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'No quick cards. Add cards to your home screen.',
      child: Pressable(
        onTap: onCustomize,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: context.colors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(
              color: context.colors.primary.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: context.colors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add your cards',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Pick the shortcuts you want on your home screen.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: context.colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single pinned quick card in the home grid.
class _ActionCard extends StatelessWidget {
  final HomeCard card;
  final VoidCallback onTap;
  const _ActionCard({required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // The catalog stores AppColorToken sentinels; resolve to the live theme.
    final actionColor = context.colors.resolve(card.color);
    return Semantics(
      button: true,
      label: card.title,
      hint: card.subtitle,
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
                  color: actionColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(card.icon, color: actionColor, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                card.title,
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
                card.subtitle,
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

