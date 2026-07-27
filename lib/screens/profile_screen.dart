// Developed by Rajesh Biswas (rajeshbiswas.dev)
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/di.dart';
import '../navigation/app_router.dart';
import '../supabase/auth_service.dart';
import '../supabase/session_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/horizon_logo.dart';
import '../widgets/status_dialog.dart';
import '../widgets/theme_toggle.dart';


/// Rendered as the "Profile" tab.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = getIt<SessionController>();
    return SafeArea(
      child: ListenableBuilder(
        listenable: session,
        builder: (context, child) {
          if (!session.isSignedIn) {
            return const _LoggedOutView();
          }
          return _LoggedInView(profile: session.profile);
        },
      ),
    );
  }
}

class _LoggedInView extends StatelessWidget {
  final CurrentProfile? profile;
  const _LoggedInView({this.profile});

  /// Opens the "Add/update university email" step. Provisional students enter
  /// their newly issued @bu.ac.bd address; Supabase sends a confirmation link,
  /// and once confirmed a database trigger promotes the account to fully
  /// verified.
  Future<void> _showAddUniversityEmailSheet(BuildContext context) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            Future<void> submit() async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              setModalState(() => submitting = true);
              try {
                await getIt<AuthService>()
                    .updateUniversityEmail(controller.text.trim());
                if (!sheetContext.mounted) return;
                Navigator.pop(sheetContext);
                await showSuccessDialog(
                  context,
                  title: 'Confirm Your University Email',
                  message: 'We sent a confirmation link to '
                      '${controller.text.trim().toLowerCase()}. Open it from '
                      'your @bu.ac.bd inbox to finish verifying. Your account '
                      'becomes fully verified automatically once confirmed.',
                  primaryLabel: 'Got it',
                );
              } on AuthFailure catch (e) {
                if (sheetContext.mounted) {
                  setModalState(() => submitting = false);
                  showToast(sheetContext, e.message);
                }
              } catch (_) {
                if (sheetContext.mounted) {
                  setModalState(() => submitting = false);
                  showToast(sheetContext, 'Could not update email. Try again.');
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.mark_email_read_outlined,
                            color: context.colors.primary),
                        const SizedBox(width: 10),
                        Text(
                          'Add University Email',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your official @bu.ac.bd email now that it has been '
                      'issued. We\'ll send a confirmation link; once you confirm '
                      'it, your account is upgraded to fully verified.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: context.colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: controller,
                      keyboardType: TextInputType.emailAddress,
                      autofocus: true,
                      style: TextStyle(color: context.colors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'name@bu.ac.bd',
                        hintStyle: TextStyle(color: context.colors.textMuted),
                        filled: true,
                        fillColor: context.colors.surfaceAlt,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: context.colors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: context.colors.border),
                        ),
                      ),
                      validator: (v) {
                        final value = (v ?? '').trim().toLowerCase();
                        if (value.isEmpty) return 'Enter your university email';
                        final re = RegExp(r'^[^@\s]+@bu\.ac\.bd$');
                        if (!re.hasMatch(value)) {
                          return 'Use your @bu.ac.bd university email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    PrimaryButton(
                      label: submitting
                          ? 'Sending link...'
                          : 'Send Confirmation Link',
                      icon: Icons.send_rounded,
                      onPressed: submitting ? null : submit,
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {

    final name = profile?.fullName.isNotEmpty == true ? profile!.fullName : 'Student';
    final initials = profile?.initials ?? '?';
    final idAndEmail = [
      if (profile?.studentId != null && profile!.studentId!.isNotEmpty)
        profile!.studentId,
      if (profile?.email.isNotEmpty == true) profile!.email,
    ].join('  ·  ');
    final isCr = profile?.role.toLowerCase() == 'cr';
    final isAdmin = profile?.role.toLowerCase() == 'super_admin';
    final isProvisional = profile?.isProvisional == true;
    final isPending = profile?.isPendingVerification == true;

    final termLabel = profile?.termLabel ?? 'Semester';


    Future<void> advanceBatch(BuildContext context) async {
      final term = profile?.currentTerm ?? 1;
      if (profile?.hasGraduated == true) {
        showToast(context, 'This batch has already graduated.');
        return;
      }

      // On the final term, advancing graduates the batch instead of moving to a
      // next term (mirrors the advance_batch RPC), so the prompt must say so.
      final isFinalTerm = profile?.isFinalTerm == true;
      final title = isFinalTerm ? 'Graduate Batch?' : 'Advance Batch?';
      final message = isFinalTerm
          ? 'Your batch is on its final $termLabel ($term). Advancing will mark '
                'the batch as graduated. This affects all students in the batch.'
          : 'Are you sure you want to advance your batch to '
                '$termLabel ${term + 1}? This will affect all students in the '
                'batch.';

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                isFinalTerm ? 'Graduate' : 'Advance',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      );

      if (confirmed != true || !context.mounted) return;

      try {
        await Supabase.instance.client
            .rpc('advance_batch', params: {'target_batch': profile?.batchId});
        if (!context.mounted) return;
        showToast(
          context,
          isFinalTerm
              ? 'Batch marked as graduated!'
              : 'Batch advanced successfully!',
        );
        await getIt<SessionController>().refresh();
      } catch (_) {
        if (context.mounted) showToast(context, 'Could not advance batch');
      }
    }

    
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        const TabHeader(
          title: 'Student Profile',
          subtitle: 'Manage your campus identity and account settings.',
        ),
        const SizedBox(height: 24),
        Center(
          child: Stack(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: context.colors.blueGradient,
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.primary.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: context.colors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.colors.background, width: 3),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            name,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            idAndEmail,
            style: TextStyle(color: context.colors.textMuted, fontSize: 12),
          ),
        ),
        const SizedBox(height: 20),
        if (isProvisional || isPending)
          _ProvisionalBanner(
            isPending: isPending,
            onAddEmail: () => _showAddUniversityEmailSheet(context),
          ),
        const SizedBox(height: 8),
        const ThemeToggleRow(),
        if (isProvisional)
          _Tile(
            icon: Icons.mark_email_read_outlined,
            label: 'Add University Email',
            onTap: () => _showAddUniversityEmailSheet(context),
          ),
        if (isCr || isAdmin)
          _Tile(
            icon: Icons.how_to_reg_outlined,
            label: 'Account Approvals',
            onTap: () => context.push(AppRoutes.accountApprovals),
          ),
        _Tile(
          icon: Icons.edit_outlined,
          label: 'Edit Profile',
          onTap: () => showToast(context, 'Edit profile'),
        ),

        _Tile(
          icon: Icons.directions_bus_outlined,
          label: 'My Routes',
          onTap: () => context.push(AppRoutes.bus),
        ),
        _Tile(
          icon: Icons.fact_check_outlined,
          label: 'Attendance History',
          onTap: () => context.push(AppRoutes.attendance),
        ),
        _Tile(
          icon: Icons.settings_outlined,
          label: 'Settings',
          onTap: () => showToast(context, 'Settings'),
        ),
        _Tile(
          icon: Icons.info_outline_rounded,
          label: 'About',
          onTap: () => context.push(AppRoutes.about),
        ),
        if (isCr) ...[
          const SizedBox(height: 8),
          _Tile(
            icon: Icons.upgrade_rounded,
            label: profile?.isFinalTerm == true
                ? 'Graduate Batch'
                : 'Advance Batch $termLabel',
            onTap: () => advanceBatch(context),
            danger: true,
          ),

        ],
        const SizedBox(height: 8),
        _Tile(
          icon: Icons.logout_rounded,
          label: 'Logout',
          danger: true,
          onTap: () async {
            await getIt<SessionController>().signOut();
            if (context.mounted) {
              showToast(context, 'Logged out');
              context.go(AppRoutes.login);
            }
          },
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            'Developer: Rajesh Biswas (rajeshbiswas.dev)',
            style: TextStyle(
              color: context.colors.textMuted,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}

class _LoggedOutView extends StatelessWidget {
  const _LoggedOutView();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const HorizonLogo(size: 96),
                  const SizedBox(height: 24),
                  Text(
                    'BU Horizon',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your Campus Companion',
                    style: TextStyle(fontSize: 14, color: context.colors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  const ThemeToggleRow(),
                  const SizedBox(height: 16),
                  GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: Column(
                      children: [
                        Text(
                          'Join your campus network to sync your course schedules, track classes and bus notifications, check attendance history, and build your student profile.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: context.colors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 28),
                        PrimaryButton(
                          label: 'Sign In',
                          onPressed: () => context.push(AppRoutes.login),
                        ),
                        const SizedBox(height: 14),
                        TextButton(
                          onPressed: () => context.push(AppRoutes.register),
                          child: Text(
                            'Create an Account',
                            style: TextStyle(
                              color: context.colors.primary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Expanded(child: SizedBox(height: 24)),
                  Text(
                    'Developer: Rajesh Biswas (rajeshbiswas.dev)',
                    style: TextStyle(
                      color: context.colors.textMuted,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// A prominent card shown to provisional / pending-verification students,
/// explaining their state and offering the "add university email" shortcut.
class _ProvisionalBanner extends StatelessWidget {
  final bool isPending;
  final VoidCallback onAddEmail;
  const _ProvisionalBanner({required this.isPending, required this.onAddEmail});

  @override
  Widget build(BuildContext context) {
    final accent = isPending ? context.colors.warning : context.colors.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPending
                    ? Icons.hourglass_top_rounded
                    : Icons.mark_email_unread_outlined,
                color: accent,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isPending
                      ? 'Awaiting Approval'
                      : 'Provisional Account',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isPending
                ? 'Your account is under review by an admin or your class '
                    'representative. You can keep exploring while you wait. '
                    'Once your @bu.ac.bd email is issued, add it below to verify '
                    'instantly.'
                : 'You registered with a personal email. Add your @bu.ac.bd '
                    'university email once it is issued to become fully '
                    'verified.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: onAddEmail,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add University Email'),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _Tile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? context.colors.danger : context.colors.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.colors.border),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: danger ? context.colors.danger : context.colors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 14.5, color: color),
                  ),
                ),
                if (!danger)
                  Icon(Icons.chevron_right_rounded, color: context.colors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
