import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../di/di.dart';
import '../navigation/app_router.dart';
import '../supabase/session_controller.dart';
import '../supabase/supabase_config.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// True when the user may enter a members-only feature.
///
/// Guests get a bottom sheet explaining that [featureName] needs an account,
/// with sign-in / register shortcuts, and `false` is returned so the caller
/// can skip navigation. UI-only builds (no Supabase keys) are never gated.
bool requireSignIn(BuildContext context, String featureName) {
  if (!SupabaseConfig.isConfigured) return true;
  if (getIt<SessionController>().isSignedIn) return true;
  showLoginRequiredSheet(context, featureName);
  return false;
}

void showLoginRequiredSheet(BuildContext context, String featureName) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 480),
    builder: (sheetContext) => _LoginRequiredSheet(
      featureName: featureName,
      onSignIn: () {
        Navigator.of(sheetContext).pop();
        context.push(AppRoutes.login);
      },
      onRegister: () {
        Navigator.of(sheetContext).pop();
        context.push(AppRoutes.register);
      },
    ),
  );
}

class _LoginRequiredSheet extends StatelessWidget {
  final String featureName;
  final VoidCallback onSignIn;
  final VoidCallback onRegister;

  const _LoginRequiredSheet({
    required this.featureName,
    required this.onSignIn,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.md),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: context.isLight ? 0.12 : 0.45),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grab handle.
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Lock badge on a soft gradient ring.
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.primary.withValues(alpha: 0.22),
                    colors.accentCyan.withValues(alpha: 0.12),
                  ],
                ),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.35),
                ),
              ),
              child: Icon(Icons.lock_person_rounded, color: colors.primary, size: 32),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '$featureName is for students',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Sign in with your university account to unlock everything '
              'made for your batch:',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const _PerkRow(
              icon: Icons.campaign_rounded,
              label: 'Class notices & exam schedules for your batch',
            ),
            const SizedBox(height: AppSpacing.sm),
            const _PerkRow(
              icon: Icons.folder_rounded,
              label: 'Study resources shared by your CR',
            ),
            const SizedBox(height: AppSpacing.sm),
            const _PerkRow(
              icon: Icons.check_circle_rounded,
              label: 'Your attendance record & people search',
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: 'Sign In',
              icon: Icons.login_rounded,
              onPressed: onSignIn,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: onRegister,
              child: Text(
                'New here? Create an account',
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Continue browsing as guest',
                style: TextStyle(
                  color: colors.textMuted,
                  fontWeight: FontWeight.w500,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PerkRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PerkRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: colors.primary, size: 18),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
