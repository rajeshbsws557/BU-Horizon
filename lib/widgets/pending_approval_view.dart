// Developed by Rajesh Biswas (rajeshbiswas.dev)
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../navigation/app_router.dart';
import '../theme/app_theme.dart';

/// A polished full-screen state shown to provisional students whose account is
/// still `pending_verification`, in place of batch-scoped content (class
/// notices, attendance, exams, resources).
///
/// It explains why the batch content is locked and points them to the way
/// forward: ask their CR to approve the account. Guests / already-active
/// students never see this — callers gate on `profile.isPendingVerification`.
class PendingApprovalView extends StatelessWidget {
  /// The feature being gated, e.g. 'class notices', 'attendance'. Used to make
  /// the copy specific.
  final String featureName;

  const PendingApprovalView({super.key, required this.featureName});

  @override
  Widget build(BuildContext context) {

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Animated, haloed hourglass badge.
                  Center(
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutBack,
                      tween: Tween(begin: 0.7, end: 1),
                      builder: (context, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: Container(
                        width: 108,
                        height: 108,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              context.colors.warning.withValues(alpha: 0.22),
                              context.colors.primary.withValues(alpha: 0.10),
                            ],
                          ),
                          border: Border.all(
                            color: context.colors.warning.withValues(alpha: 0.35),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.hourglass_top_rounded,
                          color: context.colors.warning,
                          size: 52,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Approval Pending',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Your account is waiting to be verified, so your batch '
                    '$featureName are locked for now.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: context.colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 22),
                  // "How to get access" steps.
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: context.colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'To unlock your batch content:',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _Step(
                          icon: Icons.groups_rounded,
                          color: context.colors.primary,
                          title: 'Contact your Class Representative',
                          subtitle:
                              'Ask your CR to approve your account from the '
                              'app. Once approved, your batch content will be '
                              'unlocked instantly.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  // Always reachable: this is the one screen a pending student
                  // can act from, so it must never be a dead end.
                  FilledButton.icon(
                    onPressed: () => context.push(AppRoutes.profile),
                    icon: const Icon(Icons.person_outline_rounded, size: 18),
                    label: const Text('Go to My Profile'),
                    style: FilledButton.styleFrom(
                      backgroundColor: context.colors.primary,
                      minimumSize: const Size(44, 48),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Step extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _Step({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
