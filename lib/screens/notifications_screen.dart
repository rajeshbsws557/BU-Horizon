// Developed by Rajesh Biswas (rajeshbiswas.dev)
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/di.dart';
import '../navigation/app_router.dart';
import '../supabase/session_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// The notifications / activity hub opened from the home-screen bell.
///
/// This is the single place students go for things that need their attention.
/// Today it surfaces the CR/admin "account approvals" action (approve
/// provisional batchmates); it is intentionally structured as a list of
/// sections so future items — batch-change requests, attendance corrections,
/// announcements, etc. — can slot in without a redesign.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _session = getIt<SessionController>();
  bool _loading = true;
  int _pendingApprovals = 0;

  SupabaseClient get _client => Supabase.instance.client;

  bool get _canReview {
    final role = _session.profile?.role.toLowerCase();
    return role == 'cr' || role == 'super_admin';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    var pending = 0;
    try {
      if (_canReview) {
        final profile = _session.profile;
        final isAdmin = profile?.role == 'super_admin';
        var query = _client
            .from('profiles')
            .select('id')
            .eq('status', 'pending_verification')
            .eq('is_provisional', true);
        // CRs only see their own batch (RLS enforces this too).
        if (!isAdmin && profile?.batchId != null) {
          query = query.eq('batch_id', profile!.batchId!);
        }
        final rows = await query.count(CountOption.exact);
        pending = rows.count;
      }
    } catch (_) {
      // Best-effort — leave the count at zero if the read fails.
    }
    if (!mounted) return;
    setState(() {
      _pendingApprovals = pending;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: context.colors.primary,
          backgroundColor: context.colors.surfaceAlt,
          onRefresh: _load,
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (!_session.isSignedIn) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          EmptyState(
            icon: Icons.notifications_off_outlined,
            title: 'Sign in to see notifications',
            message:
                'Your action items and campus alerts will appear here once you '
                'sign in.',
          ),
        ],
      );
    }

    final hasActionItems = _canReview;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (hasActionItems) ...[
          _SectionLabel('Action needed'),
          const SizedBox(height: 10),
          _ActionCard(
            icon: Icons.how_to_reg_rounded,
            iconColor: context.colors.primary,
            title: 'Account Approvals',
            subtitle: _loading
                ? 'Checking for pending requests…'
                : _pendingApprovals == 0
                    ? 'No student accounts are waiting for review'
                    : '$_pendingApprovals ${_pendingApprovals == 1 ? 'student is' : 'students are'} waiting for your approval',
            count: _loading ? null : _pendingApprovals,
            onTap: () async {
              await context.push(AppRoutes.accountApprovals);
              // Refresh the count after returning — some may have been handled.
              await _load();
            },
          ),
          const SizedBox(height: 24),
        ],
        _SectionLabel('Recent'),
        const SizedBox(height: 10),
        _EmptyNotice(
          message: hasActionItems
              ? 'You\'re all caught up. New alerts will show up here.'
              : 'No new notifications. Campus alerts and updates will appear '
                  'here.',
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: context.colors.textSecondary,
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final int? count;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final showBadge = count != null && count! > 0;
    return Material(
      color: context.colors.surfaceAlt,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.colors.border),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  if (showBadge)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        constraints: const BoxConstraints(minWidth: 20),
                        decoration: BoxDecoration(
                          color: context.colors.danger,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: context.colors.surfaceAlt,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          count! > 99 ? '99+' : '$count',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: context.colors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyNotice extends StatelessWidget {
  final String message;
  const _EmptyNotice({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.notifications_none_rounded,
            color: context.colors.textMuted,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: context.colors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
