import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/blood_bloc.dart';
import '../di/di.dart';
import '../models/models.dart';
import '../navigation/app_router.dart';
import '../repositories/blood_repository.dart';
import '../supabase/session_controller.dart';
import '../supabase/supabase_config.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/login_gate.dart';
import '../widgets/motion.dart';

class BloodHelpScreen extends StatelessWidget {
  const BloodHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          BloodBloc(getIt<BloodRepository>())..add(const BloodStarted()),
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
    if (!requireSignIn(context, 'Blood requests')) return;
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
      showToast(
        context,
        'Response sent — the requester can now see your contact',
      );
    }
    await _refresh();
  }

  Future<void> _openDonorRegistration() async {
    if (!requireSignIn(context, 'Donor registration')) return;
    BloodDonorRegistration? existing;
    try {
      existing = await getIt<BloodRepository>().fetchMyDonorRegistration();
    } catch (_) {
      if (mounted) showToast(context, 'Could not load your donor registration');
      return;
    }
    if (!mounted) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DonorRegistrationSheet(existing: existing),
    );
    if (saved == true && mounted) {
      showToast(
        context,
        existing == null ? 'Donor registration saved' : 'Donor profile updated',
      );
    }
  }

  Future<void> _openDonorRegistrationFromPanel() => _openDonorRegistration();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Blood Help',
          style: TextStyle(color: context.colors.textPrimary),
        ),
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
              onChanged: (i) =>
                  context.read<BloodBloc>().add(BloodTabChanged(i)),
            ),
          ),
          Expanded(
            child: BlocBuilder<BloodBloc, BloodState>(
              builder: (context, state) {
                if (state.tab == 1) {
                  return _DonorPanel(
                    onRegister: _openDonorRegistrationFromPanel,
                  );
                }
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
          BlocBuilder<BloodBloc, BloodState>(
            buildWhen: (previous, current) => previous.tab != current.tab,
            builder: (context, state) => state.tab == 0
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: PrimaryButton(
                      label: 'Request Blood',
                      icon: Icons.water_drop_rounded,
                      onPressed: _openRequestForm,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _DonorRegistrationSheet extends StatefulWidget {
  final BloodDonorRegistration? existing;

  const _DonorRegistrationSheet({this.existing});

  @override
  State<_DonorRegistrationSheet> createState() =>
      _DonorRegistrationSheetState();
}

class _DonorPanel extends StatefulWidget {
  final Future<void> Function() onRegister;

  const _DonorPanel({required this.onRegister});

  @override
  State<_DonorPanel> createState() => _DonorPanelState();
}

class _DonorPanelState extends State<_DonorPanel> {
  BloodDonorRegistration? _registration;
  bool _loading = true;
  String? _error;
  DateTime? _lastUpdatedAt;
  late final SessionController _session = getIt<SessionController>();

  bool get _requiresSignIn =>
      SupabaseConfig.isConfigured && !_session.isSignedIn;

  @override
  void initState() {
    super.initState();
    _session.addListener(_sessionChanged);
    _load();
  }

  @override
  void dispose() {
    _session.removeListener(_sessionChanged);
    super.dispose();
  }

  void _sessionChanged() {
    if (!mounted) return;
    if (_requiresSignIn) {
      setState(() {
        _registration = null;
        _loading = false;
        _error = null;
      });
    } else {
      _load();
    }
  }

  Future<void> refresh() => _load();

  Future<void> _load() async {
    if (_requiresSignIn) {
      setState(() {
        _loading = false;
        _error = null;
        _registration = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final registration = await getIt<BloodRepository>()
          .fetchMyDonorRegistration();
      if (!mounted) return;
      setState(() {
        _registration = registration;
        _loading = false;
        _lastUpdatedAt = DateTime.now();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load your donor profile.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: const [
          Skeleton(height: 260, radius: BorderRadius.all(Radius.circular(8))),
          SizedBox(height: 14),
          Skeleton(height: 14, width: 140),
          SizedBox(height: 8),
          Skeleton(height: 12, width: 260),
        ],
      );
    }
    if (_requiresSignIn) {
      return RefreshIndicator(
        color: context.colors.primary,
        backgroundColor: context.colors.surfaceAlt,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 44),
            const EmptyState(
              icon: Icons.volunteer_activism_outlined,
              title: 'Sign in to manage your donor profile',
              message:
                  'Save your blood group and availability, then respond privately to campus blood requests.',
            ),
            Center(
              child: FilledButton.icon(
                onPressed: () => context.push(AppRoutes.login),
                icon: const Icon(Icons.login_rounded),
                label: const Text('Sign in'),
                style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
              ),
            ),
          ],
        ),
      );
    }
    if (_error != null && _registration == null) {
      return RetryStateList(
        title: 'Donor profile unavailable',
        message: _error!,
        onRetry: _load,
      );
    }

    final registration = _registration;
    return RefreshIndicator(
      color: context.colors.primary,
      backgroundColor: context.colors.surfaceAlt,
      onRefresh: _load,
      semanticsLabel: 'Refresh donor profile',
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) ...[
            DataStateBanner(
              message:
                  'Could not refresh your donor profile. Showing saved details.',
              tone: DataStateTone.warning,
              onRetry: _load,
            ),
            const SizedBox(height: 10),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: LastUpdatedLabel(
              updatedAt: _lastUpdatedAt,
              emptyLabel: 'Donor profile not synced yet',
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: context.colors.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.volunteer_activism_rounded,
                  color: context.colors.danger,
                  size: 30,
                ),
                const SizedBox(height: 12),
                Text(
                  registration == null
                      ? 'Help someone in your campus community'
                      : 'Your donor profile',
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  registration == null
                      ? 'Register your blood group and contact number. Only signed-in campus users can see an available listing, and your contact is used for in-app responses.'
                      : 'Registered means your donor profile is saved. Available means signed-in campus users may respond through the app. Your contact is not shown in a public donor directory.',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                if (registration != null) ...[
                  const SizedBox(height: 18),
                  _DonorDetailRow(
                    icon: Icons.how_to_reg_rounded,
                    label: 'Registration',
                    value: 'Registered',
                    valueColor: context.colors.primary,
                  ),
                  _DonorDetailRow(
                    icon: Icons.bloodtype_rounded,
                    label: 'Blood group',
                    value: registration.group.label,
                  ),
                  _DonorDetailRow(
                    icon: registration.available
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    label: 'Listing status',
                    value: registration.available ? 'Available' : 'Paused',
                    valueColor: registration.available
                        ? context.colors.success
                        : context.colors.textMuted,
                  ),
                  _DonorDetailRow(
                    icon: Icons.calendar_month_outlined,
                    label: 'Last donated',
                    value: registration.lastDonated == null
                        ? 'Not specified'
                        : '${registration.lastDonated!.day}/${registration.lastDonated!.month}/${registration.lastDonated!.year}',
                  ),
                ],
                const SizedBox(height: 18),
                PrimaryButton(
                  label: registration == null
                      ? 'Register as Donor'
                      : 'Edit Donor Profile',
                  icon: registration == null
                      ? Icons.add_rounded
                      : Icons.edit_rounded,
                  onPressed: () async {
                    await widget.onRegister();
                    if (mounted) await _load();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Donor safety reminder',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Keep your last donation date accurate and pause availability after donating or whenever you cannot respond. Follow local blood-bank guidance for eligibility; the app does not determine medical eligibility.',
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _DonorDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DonorDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.colors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? context.colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DonorRegistrationSheetState extends State<_DonorRegistrationSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _contact;
  late BloodGroup _group;
  late bool _available;
  DateTime? _lastDonated;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _contact = TextEditingController(text: widget.existing?.contact ?? '');
    _group = widget.existing?.group ?? BloodGroup.oPositive;
    _available = widget.existing?.available ?? true;
    _lastDonated = widget.existing?.lastDonated;
  }

  @override
  void dispose() {
    _contact.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _lastDonated ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (value != null) setState(() => _lastDonated = value);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) || _saving) return;
    setState(() => _saving = true);
    try {
      await getIt<BloodRepository>().saveDonorRegistration(
        BloodDonorRegistration(
          group: _group,
          contact: _contact.text.trim(),
          lastDonated: _lastDonated,
          available: _available,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        showToast(context, 'Could not save the donor registration');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: cardDecoration(context: context),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.existing == null
                        ? 'Register as Donor'
                        : 'Update Donor Profile',
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your profile is visible only to signed-in campus users when availability is on. Contact is shared through an in-app response flow.',
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<BloodGroup>(
                    initialValue: _group,
                    decoration: const InputDecoration(labelText: 'Blood group'),
                    items: [
                      for (final group in BloodGroup.values)
                        DropdownMenuItem(
                          value: group,
                          child: Text(group.label),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _group = value ?? _group),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _contact,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Contact number',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Enter a contact number'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: const Text('Last donated'),
                    subtitle: Text(
                      _lastDonated == null
                          ? 'Not specified'
                          : '${_lastDonated!.day}/${_lastDonated!.month}/${_lastDonated!.year}',
                    ),
                    trailing: _lastDonated == null
                        ? null
                        : IconButton(
                            tooltip: 'Clear date',
                            onPressed: () =>
                                setState(() => _lastDonated = null),
                            icon: const Icon(Icons.close_rounded),
                          ),
                    onTap: _pickDate,
                  ),
                  Text(
                    'Please keep this date accurate so you can check your own eligibility with a qualified blood bank.',
                    style: TextStyle(
                      color: context.colors.textMuted,
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Available to donate'),
                    subtitle: const Text(
                      'Your donor listing appears when availability is on.',
                    ),
                    value: _available,
                    onChanged: (value) => setState(() => _available = value),
                  ),
                  const SizedBox(height: 14),
                  PrimaryButton(
                    label: _saving ? 'Saving...' : 'Save Donor Profile',
                    icon: Icons.volunteer_activism_rounded,
                    onPressed: _saving ? null : _save,
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
              const Icon(
                Icons.water_drop_rounded,
                color: Colors.white,
                size: 30,
              ),
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
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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
                          decoration: const InputDecoration(
                            labelText: 'Blood group',
                          ),
                          items: BloodGroup.values
                              .map(
                                (g) => DropdownMenuItem(
                                  value: g,
                                  child: Text(g.label),
                                ),
                              )
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
                              .map(
                                (u) => DropdownMenuItem(
                                  value: u,
                                  child: Text('$u'),
                                ),
                              )
                              .toList(),
                          onChanged: (u) =>
                              setState(() => _units = u ?? _units),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _location,
                    decoration: const InputDecoration(
                      labelText: 'Location (hospital, ward…)',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Where is the blood needed?'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _contact,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Contact number',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'How can donors reach you?'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _note,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Urgent',
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 14,
                      ),
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
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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
                      color: context.colors.textSecondary,
                      fontSize: 13,
                    ),
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
                      Icon(
                        Icons.check_circle_rounded,
                        color: context.colors.success,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You already responded to this request.',
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 13,
                          ),
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
                    decoration: const InputDecoration(
                      labelText: 'Your contact number',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _message,
                    decoration: const InputDecoration(
                      labelText: 'Message (optional)',
                    ),
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
            style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
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
            ...responses.map(
              (r) => Padding(
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
                            fontSize: 12.5,
                          ),
                        ),
                      Text(
                        r.time,
                        style: TextStyle(
                          color: context.colors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
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
              Skeleton(
                height: 30,
                width: 30,
                radius: BorderRadius.all(Radius.circular(15)),
              ),
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
                  Skeleton(
                    height: 42,
                    width: 42,
                    radius: BorderRadius.all(Radius.circular(11)),
                  ),
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
                style: TextStyle(
                  color: context.colors.textMuted,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
