import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/blood_bloc.dart';
import '../di/di.dart';
import '../models/models.dart';
import '../repositories/blood_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';

class BloodHelpScreen extends StatelessWidget {
  const BloodHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BloodBloc(getIt<BloodRepository>())..add(const BloodStarted()),
      child: const _BloodHelpView(),
    );
  }
}

class _BloodHelpView extends StatefulWidget {
  const _BloodHelpView();

  @override
  State<_BloodHelpView> createState() => _BloodHelpViewState();
}

class _BloodHelpViewState extends State<_BloodHelpView> {
  Future<void> _refresh() {
    final bloc = context.read<BloodBloc>();
    bloc.add(const BloodRefreshRequested());
    return bloc.stream.firstWhere((s) => !s.isLoading).then((_) {});
  }

  Future<void> _openRequestForm() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _RequestBloodSheet(),
    );
    if (created == true && mounted) {
      showToast(context, 'Blood request posted');
      await _refresh();
    }
  }

  Future<void> _openRequestDetail(BloodRequest request) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RequestDetailSheet(request: request),
    );
    if (!mounted || result == null) return;
    if (result == 'fulfilled') {
      showToast(context, 'Request marked as fulfilled — thank you!');
    } else if (result == 'responded') {
      showToast(context, 'Response sent — the requester can now see your contact');
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Blood Help', style: TextStyle(color: context.colors.textPrimary)),
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: context.colors.textPrimary),
      ),
      body: Column(
        children: [
          BlocBuilder<BloodBloc, BloodState>(
            buildWhen: (previous, current) => previous.tab != current.tab,
            builder: (context, state) => SegmentedTabs(
              tabs: const ['Request Blood', 'Donate Blood'],
              selected: state.tab,
              onChanged: (i) => context.read<BloodBloc>().add(BloodTabChanged(i)),
            ),
          ),
          Expanded(
            child: BlocBuilder<BloodBloc, BloodState>(
              builder: (context, state) {
                final need = state.urgentNeed;
                return RefreshIndicator(
                  color: context.colors.primary,
                  backgroundColor: context.colors.surfaceAlt,
                  onRefresh: _refresh,
                  semanticsLabel: 'Refresh blood requests',
                  child: state.isLoading
                      ? const _BloodSkeletonList()
                      : ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          children: [
                            if (need != null) ...[
                              _UrgentNeedCard(
                                need: need,
                                onTap: () => _openRequestDetail(need),
                              ),
                              const SizedBox(height: 22),
                            ],
                            Text(
                              'Recent Requests',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: context.colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (state.requests.isEmpty)
                              const EmptyState(
                                icon: Icons.water_drop_outlined,
                                title: 'No open requests',
                                message:
                                    'No one needs blood right now. Post a request below if you do.',
                              )
                            else
                              ...List.generate(
                                state.requests.length,
                                (i) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Entrance(
                                    index: i,
                                    child: _RequestRow(
                                      request: state.requests[i],
                                      onTap: () =>
                                          _openRequestDetail(state.requests[i]),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: BlocBuilder<BloodBloc, BloodState>(
              buildWhen: (previous, current) => previous.tab != current.tab,
              builder: (context, state) => PrimaryButton(
                label: state.tab == 0 ? 'Request Blood' : 'Register as Donor',
                icon: Icons.water_drop_rounded,
                onPressed: () {
                  if (state.tab == 0) {
                    _openRequestForm();
                  } else {
                    _showComingSoonSheet(context, 'Donor registration');
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UrgentNeedCard extends StatelessWidget {
  final BloodRequest need;
  final VoidCallback onTap;
  const _UrgentNeedCard({required this.need, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Urgent blood need. ${need.units} units of ${need.group.label} blood. Contact ${need.contact} at ${need.location}. Posted ${need.time}',
      button: true,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: context.colors.bloodGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: context.colors.danger.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.water_drop_rounded, color: Colors.white, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Need Blood',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${need.units} Units (${need.group.label})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Contact: ${need.contact}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12.5,
                      ),
                    ),
                    Text(
                      'Location: ${need.location}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Text(
                  need.time,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Post a new blood request to the live backend.
class _RequestBloodSheet extends StatefulWidget {
  const _RequestBloodSheet();

  @override
  State<_RequestBloodSheet> createState() => _RequestBloodSheetState();
}

class _RequestBloodSheetState extends State<_RequestBloodSheet> {
  final _formKey = GlobalKey<FormState>();
  final _contact = TextEditingController();
  final _location = TextEditingController();
  final _note = TextEditingController();
  BloodGroup _group = BloodGroup.oPositive;
  int _units = 1;
  bool _urgent = false;
  bool _saving = false;

  @override
  void dispose() {
    _contact.dispose();
    _location.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false) || _saving) return;
    setState(() => _saving = true);
    try {
      await getIt<BloodRepository>().createRequest(
        group: _group,
        units: _units,
        contact: _contact.text.trim(),
        location: _location.text.trim(),
        note: _note.text.trim(),
        isUrgent: _urgent,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        showToast(context, 'Could not post the request. Try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.all(AppSpacing.lg),
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: cardDecoration(context: context),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Request Blood',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<BloodGroup>(
                          initialValue: _group,
                          decoration: const InputDecoration(labelText: 'Blood group'),
                          items: BloodGroup.values
                              .map((g) => DropdownMenuItem(
                                  value: g, child: Text(g.label)))
                              .toList(),
                          onChanged: (g) =>
                              setState(() => _group = g ?? _group),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _units,
                          decoration: const InputDecoration(labelText: 'Units'),
                          items: List.generate(6, (i) => i + 1)
                              .map((u) =>
                                  DropdownMenuItem(value: u, child: Text('$u')))
                              .toList(),
                          onChanged: (u) => setState(() => _units = u ?? _units),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _location,
                    decoration: const InputDecoration(
                        labelText: 'Location (hospital, ward…)'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Where is the blood needed?'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _contact,
                    keyboardType: TextInputType.phone,
                    decoration:
                        const InputDecoration(labelText: 'Contact number'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'How can donors reach you?'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _note,
                    decoration:
                        const InputDecoration(labelText: 'Note (optional)'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Urgent',
                      style: TextStyle(
                          color: context.colors.textPrimary, fontSize: 14),
                    ),
                    value: _urgent,
                    onChanged: (v) => setState(() => _urgent = v),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  PrimaryButton(
                    label: _saving ? 'Posting…' : 'Post Request',
                    icon: Icons.water_drop_rounded,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Request details: responders can answer in-app; the requester sees the
/// recorded responses (RLS keeps them private to the two sides).
class _RequestDetailSheet extends StatefulWidget {
  final BloodRequest request;
  const _RequestDetailSheet({required this.request});

  @override
  State<_RequestDetailSheet> createState() => _RequestDetailSheetState();
}

class _RequestDetailSheetState extends State<_RequestDetailSheet> {
  final _message = TextEditingController();
  final _contact = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _message.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _respond() async {
    if (_saving) return;
    if (_contact.text.trim().isEmpty) {
      showToast(context, 'Add a contact number so the requester can reach you');
      return;
    }
    setState(() => _saving = true);
    try {
      await getIt<BloodRepository>().respond(
        widget.request.id,
        message: _message.text.trim(),
        contact: _contact.text.trim(),
      );
      if (mounted) Navigator.of(context).pop('responded');
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        showToast(context, 'Could not send the response. Try again.');
      }
    }
  }

  Future<void> _markFulfilled() async {
    if (_saving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogContext.colors.surface,
        title: Text(
          'Mark as fulfilled?',
          style: TextStyle(color: dialogContext.colors.textPrimary),
        ),
        content: Text(
          'Confirm that you have received the blood you needed. This closes '
          'the request and removes it from the open list.',
          style: TextStyle(color: dialogContext.colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not yet'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Blood received',
              style: TextStyle(
                color: dialogContext.colors.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await getIt<BloodRepository>().markFulfilled(widget.request.id);
      if (mounted) Navigator.of(context).pop('fulfilled');
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        showToast(context, 'Could not update the request. Try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.all(AppSpacing.lg),
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: cardDecoration(context: context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: context.colors.danger.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        request.group.label,
                        style: TextStyle(
                          color: context.colors.danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${request.units} unit${request.units == 1 ? '' : 's'} needed · ${request.location}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                              color: context.colors.textPrimary,
                            ),
                          ),
                          Text(
                            'Contact: ${request.contact} · ${request.time}',
                            style: TextStyle(
                              color: context.colors.textSecondary,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (request.note.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    request.note,
                    style: TextStyle(
                        color: context.colors.textSecondary, fontSize: 13),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                if (request.isMine) ...[
                  _ResponsesList(requestId: request.id),
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    label: _saving ? 'Updating…' : 'Mark as Fulfilled',
                    icon: Icons.check_circle_rounded,
                    onPressed: _markFulfilled,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Tap once you have received blood — this closes your request.',
                    style: TextStyle(
                      color: context.colors.textMuted,
                      fontSize: 11.5,
                    ),
                  ),
                ] else if (request.responded)
                  Row(
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: context.colors.success, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You already responded to this request.',
                          style: TextStyle(
                              color: context.colors.textSecondary,
                              fontSize: 13),
                        ),
                      ),
                    ],
                  )
                else ...[
                  Text(
                    'Respond as a donor',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _contact,
                    keyboardType: TextInputType.phone,
                    decoration:
                        const InputDecoration(labelText: 'Your contact number'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _message,
                    decoration: const InputDecoration(
                        labelText: 'Message (optional)'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    label: _saving ? 'Sending…' : 'I can donate',
                    icon: Icons.volunteer_activism_rounded,
                    onPressed: _respond,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The requester's private view of who answered.
class _ResponsesList extends StatelessWidget {
  final String requestId;
  const _ResponsesList({required this.requestId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ResponseItem>>(
      future: getIt<BloodRepository>().fetchResponses(requestId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final responses = snapshot.data!;
        if (responses.isEmpty) {
          return Text(
            'No responses yet. Donors who answer will show up here.',
            style:
                TextStyle(color: context.colors.textSecondary, fontSize: 13),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Responses (${responses.length})',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...responses.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: context.colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${r.responderName}${r.contact.isNotEmpty ? ' · ${r.contact}' : ''}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        if (r.message.isNotEmpty)
                          Text(
                            r.message,
                            style: TextStyle(
                                color: context.colors.textSecondary,
                                fontSize: 12.5),
                          ),
                        Text(
                          r.time,
                          style: TextStyle(
                              color: context.colors.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        );
      },
    );
  }
}

/// Honest "coming soon" affordance instead of a fake success toast.
void _showComingSoonSheet(BuildContext context, String featureName) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => SafeArea(
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.lg),
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: cardDecoration(context: sheetContext),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_top_rounded,
                color: sheetContext.colors.primary, size: 36),
            const SizedBox(height: AppSpacing.md),
            Text(
              '$featureName coming soon',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: sheetContext.colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'This feature is not available yet. We are working on it — check back in a future update.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: sheetContext.colors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Got it',
              icon: Icons.check_rounded,
              onPressed: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      ),
    ),
  );
}

class _BloodSkeletonList extends StatelessWidget {
  const _BloodSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.surfaceAlt,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.border),
          ),
          child: const Row(
            children: [
              Skeleton(height: 30, width: 30, radius: BorderRadius.all(Radius.circular(15))),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(height: 16, width: 120),
                    SizedBox(height: 8),
                    Skeleton(height: 12, width: 180),
                    SizedBox(height: 6),
                    Skeleton(height: 12, width: 160),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Skeleton(height: 15, width: 120),
        const SizedBox(height: 12),
        ...List.generate(
          4,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.colors.border),
              ),
              child: const Row(
                children: [
                  Skeleton(height: 42, width: 42, radius: BorderRadius.all(Radius.circular(11))),
                  SizedBox(width: 12),
                  Expanded(child: Skeleton(height: 14, width: 140)),
                  SizedBox(width: 12),
                  Skeleton(height: 12, width: 50),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RequestRow extends StatelessWidget {
  final BloodRequest request;
  final VoidCallback onTap;
  const _RequestRow({required this.request, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Blood request ${request.group.label} at ${request.location}, ${request.time}',
      button: true,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.colors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.colors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: context.colors.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Text(
                  request.group.label,
                  style: TextStyle(
                    color: context.colors.danger,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.location,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    if (request.isMine || request.responded)
                      Text(
                        request.isMine ? 'Your request' : 'You responded',
                        style: TextStyle(
                          color: request.isMine
                              ? context.colors.primary
                              : context.colors.success,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                request.time,
                style: TextStyle(color: context.colors.textMuted, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
