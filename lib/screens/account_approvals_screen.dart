// Developed by Rajesh Biswas (rajeshbiswas.dev)
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/di.dart';
import '../supabase/session_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// A pending provisional account awaiting identity approval.
class _PendingAccount {
  final String id;
  final String fullName;
  final String? studentId;
  final String? roll;
  final String email;
  final DateTime? createdAt;

  const _PendingAccount({
    required this.id,
    required this.fullName,
    required this.email,
    this.studentId,
    this.roll,
    this.createdAt,
  });

  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

/// Lets a super admin or an active batch CR review provisional (pending
/// verification) batchmates who registered without a university email.
///
/// Reads are already gated by RLS (a CR can only see their own batch's
/// profiles; a super admin sees all), and the `review_provisional_account`
/// RPC re-checks authorization server-side, so this screen only has to present
/// the queue and call approve/reject.
class AccountApprovalsScreen extends StatefulWidget {
  const AccountApprovalsScreen({super.key});

  @override
  State<AccountApprovalsScreen> createState() => _AccountApprovalsScreenState();
}

class _AccountApprovalsScreenState extends State<AccountApprovalsScreen> {
  final _session = getIt<SessionController>();
  bool _loading = true;
  String? _error;
  List<_PendingAccount> _accounts = const [];
  final Set<String> _busyIds = {};

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = _session.profile;
      final isAdmin = profile?.role == 'super_admin';
      // CRs review only their own batch; RLS also enforces this, but scoping the
      // query keeps it tight and predictable.
      var query = _client
          .from('profiles')
          .select('id, full_name, student_id, roll, email, created_at')
          .eq('status', 'pending_verification')
          .eq('is_provisional', true);
      if (!isAdmin && profile?.batchId != null) {
        query = query.eq('batch_id', profile!.batchId!);
      }
      final rows = await query
          .order('created_at', ascending: true)
          .timeout(const Duration(seconds: 15));

      final accounts = rows
          .map<_PendingAccount>(
            (r) => _PendingAccount(
              id: r['id'] as String,
              fullName: (r['full_name'] as String?) ?? '',
              studentId: r['student_id'] as String?,
              roll: r['roll'] as String?,
              email: (r['email'] as String?) ?? '',
              createdAt: DateTime.tryParse(
                (r['created_at'] as String?) ?? '',
              ),
            ),
          )
          .toList();

      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _review(_PendingAccount account, bool approve) async {
    if (_busyIds.contains(account.id)) return;

    if (!approve) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reject account?'),
          content: Text(
            'Reject ${account.fullName}\'s registration? Their account will be '
            'archived. This should only be done if you cannot verify they are a '
            'real student in your batch.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reject', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _busyIds.add(account.id));
    try {
      await _client.rpc(
        'review_provisional_account',
        params: {'target_profile_id': account.id, 'approve': approve},
      );
      if (!mounted) return;
      setState(() {
        _accounts = _accounts.where((a) => a.id != account.id).toList();
        _busyIds.remove(account.id);
      });
      showToast(
        context,
        approve
            ? '${account.fullName} approved'
            : '${account.fullName} rejected',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyIds.remove(account.id));
      showToast(context, 'Could not update: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Approvals'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Could Not Load Requests',
            message: 'Please check your connection and pull to refresh.',
          ),
        ],
      );
    }

    if (_accounts.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          EmptyState(
            icon: Icons.verified_user_outlined,
            title: 'No Pending Accounts',
            message:
                'When a batchmate registers without a university email, their '
                'request will appear here for you to approve.',
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _accounts.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
            child: Text(
              'Review new students in your batch who registered with a personal '
              'email. Approving activates their account; they can add their '
              '@bu.ac.bd email later to become fully verified.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: context.colors.textSecondary,
              ),
            ),
          );
        }
        final account = _accounts[index - 1];
        return _AccountCard(
          account: account,
          busy: _busyIds.contains(account.id),
          onApprove: () => _review(account, true),
          onReject: () => _review(account, false),
        );
      },
    );
  }
}

class _AccountCard extends StatelessWidget {
  final _PendingAccount account;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _AccountCard({
    required this.account,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final idLine = [
      if (account.studentId != null && account.studentId!.isNotEmpty)
        'ID ${account.studentId}',
      if (account.roll != null && account.roll!.isNotEmpty)
        'Roll ${account.roll}',
    ].join('  ·  ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: context.colors.blueGradient,
                ),
                child: Center(
                  child: Text(
                    account.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.fullName.isEmpty ? 'Unnamed' : account.fullName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account.email,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: context.colors.textSecondary,
                      ),
                    ),
                    if (idLine.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        idLine,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onReject,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.danger,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: context.colors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy ? null : onApprove,
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Approve'),
                  style: FilledButton.styleFrom(
                    backgroundColor: context.colors.success,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
