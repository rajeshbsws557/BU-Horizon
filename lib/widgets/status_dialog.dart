// Developed by Rajesh Biswas (rajeshbiswas.dev)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// The visual tone of a [StatusDialog] — drives its icon, accent color and
/// haptic feedback.
enum StatusKind { success, error, warning, info }

/// A beautiful, animated result card shown as a dialog instead of a plain
/// SnackBar. Used for the important success / failure moments across the app
/// (registration, sign-in, etc.) so feedback feels polished and on-brand.
///
/// Prefer the [showSuccessDialog] / [showErrorDialog] helpers below.
class StatusDialog extends StatelessWidget {
  final StatusKind kind;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const StatusDialog({
    super.key,
    required this.kind,
    required this.title,
    required this.message,
    this.primaryLabel = 'Got it',
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  Color _accent(BuildContext context) => switch (kind) {
        StatusKind.success => context.colors.success,
        StatusKind.error => context.colors.danger,
        StatusKind.warning => context.colors.warning,
        StatusKind.info => context.colors.primary,
      };

  IconData get _icon => switch (kind) {
        StatusKind.success => Icons.check_circle_rounded,
        StatusKind.error => Icons.error_rounded,
        StatusKind.warning => Icons.warning_amber_rounded,
        StatusKind.info => Icons.info_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final accent = _accent(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutBack,
        tween: Tween(begin: 0.85, end: 1),
        builder: (context, scale, child) => Transform.scale(
          scale: scale,
          child: child,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: context.colors.border),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.18),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Accent header with the halo'd status icon.
              Container(
                padding: const EdgeInsets.only(top: 28, bottom: 20),
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      accent.withValues(alpha: 0.16),
                      accent.withValues(alpha: 0.0),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadii.lg),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accent.withValues(alpha: 0.35),
                          width: 2,
                        ),
                      ),
                      child: Icon(_icon, color: accent, size: 40),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: context.colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        if (secondaryLabel != null) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                onSecondary?.call();
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: BorderSide(color: context.colors.border),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadii.md),
                                ),
                              ),
                              child: Text(
                                secondaryLabel!,
                                style: TextStyle(
                                  color: context.colors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              onPrimary?.call();
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: accent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadii.md),
                              ),
                            ),
                            child: Text(
                              primaryLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
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

/// Shows a themed status card dialog. Returns after the user dismisses it.
Future<void> showStatusDialog(
  BuildContext context, {
  required StatusKind kind,
  required String title,
  required String message,
  String primaryLabel = 'Got it',
  VoidCallback? onPrimary,
  String? secondaryLabel,
  VoidCallback? onSecondary,
  bool barrierDismissible = true,
}) {
  switch (kind) {
    case StatusKind.success:
      HapticFeedback.mediumImpact();
    case StatusKind.error:
      HapticFeedback.heavyImpact();
    case StatusKind.warning:
    case StatusKind.info:
      HapticFeedback.lightImpact();
  }
  return showDialog<void>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (_) => StatusDialog(
      kind: kind,
      title: title,
      message: message,
      primaryLabel: primaryLabel,
      onPrimary: onPrimary,
      secondaryLabel: secondaryLabel,
      onSecondary: onSecondary,
    ),
  );
}

/// Convenience: a success result card.
Future<void> showSuccessDialog(
  BuildContext context, {
  required String title,
  required String message,
  String primaryLabel = 'Continue',
  VoidCallback? onPrimary,
}) =>
    showStatusDialog(
      context,
      kind: StatusKind.success,
      title: title,
      message: message,
      primaryLabel: primaryLabel,
      onPrimary: onPrimary,
    );

/// Convenience: an error result card.
Future<void> showErrorDialog(
  BuildContext context, {
  required String title,
  required String message,
  String primaryLabel = 'Try Again',
  VoidCallback? onPrimary,
}) =>
    showStatusDialog(
      context,
      kind: StatusKind.error,
      title: title,
      message: message,
      primaryLabel: primaryLabel,
      onPrimary: onPrimary,
    );
