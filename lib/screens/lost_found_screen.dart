import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../di/di.dart';
import '../models/models.dart';
import '../repositories/lost_found_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';

class LostFoundScreen extends StatelessWidget {
  const LostFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LostFoundCubit(),
      child: const _LostFoundView(),
    );
  }
}

class _LostFoundView extends StatefulWidget {
  const _LostFoundView();

  @override
  State<_LostFoundView> createState() => _LostFoundViewState();
}

class _LostFoundViewState extends State<_LostFoundView> {
  bool _loading = true;
  List<LostFoundItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await getIt<LostFoundRepository>().fetchItems();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      showToast(context, 'Could not load lost & found items');
    }
  }

  Future<void> _openReportForm(bool isLost) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReportItemSheet(isLost: isLost),
    );
    if (created == true && mounted) {
      showToast(context, isLost ? 'Lost item reported' : 'Found item reported');
      await _load();
    }
  }

  Future<void> _openItemDetail(LostFoundItem item) async {
    final responded = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemDetailSheet(item: item),
    );
    if (responded == true && mounted) {
      showToast(context, 'Response sent — the reporter can now see your contact');
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lost & Found', style: TextStyle(color: context.colors.textPrimary)),
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: context.colors.textPrimary),
      ),
      body: Column(
        children: [
          BlocBuilder<LostFoundCubit, int>(
            builder: (context, tab) => SegmentedTabs(
              tabs: const ['Lost Items', 'Found Items'],
              selected: tab,
              onChanged: (i) => context.read<LostFoundCubit>().setTab(i),
            ),
          ),
          Expanded(
            child: BlocBuilder<LostFoundCubit, int>(
              builder: (context, tab) {
                final visible = tab == 0
                    ? _items.where((e) => e.isLost).toList()
                    : _items.where((e) => !e.isLost).toList();
                return RefreshIndicator(
                  color: context.colors.primary,
                  backgroundColor: context.colors.surfaceAlt,
                  onRefresh: _load,
                  semanticsLabel: 'Refresh lost and found items',
                  child: _loading
                      ? const _LostFoundSkeletonList()
                      : visible.isEmpty
                          ? EmptyState(
                              icon: tab == 0
                                  ? Icons.search_off_rounded
                                  : Icons.inventory_2_outlined,
                              title: tab == 0 ? 'No lost items' : 'No found items',
                              message: 'Nothing reported yet. Be the first to post one below.',
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(16),
                              itemCount: visible.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (_, i) => Entrance(
                                index: i,
                                child: _ItemCard(
                                  item: visible[i],
                                  onTap: () => _openItemDetail(visible[i]),
                                ),
                              ),
                            ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: BlocBuilder<LostFoundCubit, int>(
              builder: (context, tab) => PrimaryButton(
                label: tab == 0 ? 'Report Lost Item' : 'Report Found Item',
                icon: Icons.add_circle_outline_rounded,
                onPressed: () => _openReportForm(tab == 0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Report a lost or found item to the live backend.
class _ReportItemSheet extends StatefulWidget {
  final bool isLost;
  const _ReportItemSheet({required this.isLost});

  @override
  State<_ReportItemSheet> createState() => _ReportItemSheetState();
}

class _ReportItemSheetState extends State<_ReportItemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false) || _saving) return;
    setState(() => _saving = true);
    try {
      await getIt<LostFoundRepository>().report(
        isLost: widget.isLost,
        title: _title.text.trim(),
        description: _description.text.trim(),
        location: _location.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        showToast(context, 'Could not post the report. Try again.');
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
                    widget.isLost ? 'Report Lost Item' : 'Report Found Item',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _title,
                    decoration: const InputDecoration(
                        labelText: 'What is it? (e.g. Black wallet)'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Give the item a short name'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _description,
                    decoration:
                        const InputDecoration(labelText: 'Description'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Describe the item briefly'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _location,
                    decoration: const InputDecoration(
                        labelText: 'Where was it lost/found?'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Say where this happened'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    label: _saving ? 'Posting…' : 'Post Report',
                    icon: Icons.add_circle_outline_rounded,
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

/// Item details: others respond in-app; the reporter sees recorded responses.
class _ItemDetailSheet extends StatefulWidget {
  final LostFoundItem item;
  const _ItemDetailSheet({required this.item});

  @override
  State<_ItemDetailSheet> createState() => _ItemDetailSheetState();
}

class _ItemDetailSheetState extends State<_ItemDetailSheet> {
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
      showToast(context, 'Add a contact number so the reporter can reach you');
      return;
    }
    setState(() => _saving = true);
    try {
      await getIt<LostFoundRepository>().respond(
        widget.item.id,
        message: _message.text.trim(),
        contact: _contact.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        showToast(context, 'Could not send the response. Try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final accent = item.isLost ? context.colors.warning : context.colors.success;
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
                        color: accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(item.icon, color: accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                              color: context.colors.textPrimary,
                            ),
                          ),
                          Text(
                            '${item.location} · ${item.time}',
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
                const SizedBox(height: AppSpacing.sm),
                Text(
                  item.description,
                  style: TextStyle(
                      color: context.colors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (item.isMine)
                  _ResponsesList(itemId: item.id)
                else if (item.responded)
                  Row(
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: context.colors.success, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You already responded to this report.',
                          style: TextStyle(
                              color: context.colors.textSecondary,
                              fontSize: 13),
                        ),
                      ),
                    ],
                  )
                else ...[
                  Text(
                    item.isLost ? 'Found this item?' : 'Is this yours?',
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
                    decoration:
                        const InputDecoration(labelText: 'Message (optional)'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    label: _saving ? 'Sending…' : 'Send Response',
                    icon: Icons.reply_rounded,
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

/// The reporter's private view of who answered.
class _ResponsesList extends StatelessWidget {
  final String itemId;
  const _ResponsesList({required this.itemId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ResponseItem>>(
      future: getIt<LostFoundRepository>().fetchResponses(itemId),
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
            'No responses yet. Anyone who answers will show up here.',
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

class _LostFoundSkeletonList extends StatelessWidget {
  const _LostFoundSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, __) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(height: 46, width: 46, radius: BorderRadius.all(Radius.circular(12))),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(height: 14, width: 140),
                  SizedBox(height: 8),
                  Skeleton(height: 12, width: 180),
                  SizedBox(height: 8),
                  Skeleton(height: 12, width: 120),
                ],
              ),
            ),
            SizedBox(width: 8),
            Skeleton(height: 12, width: 54),
          ],
        ),
      ),
    );
  }
}

class LostFoundCubit extends Cubit<int> {
  LostFoundCubit() : super(0);

  void setTab(int tab) => emit(tab);
}

class _ItemCard extends StatelessWidget {
  final LostFoundItem item;
  final VoidCallback onTap;
  const _ItemCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = item.isLost ? context.colors.warning : context.colors.success;
    return Semantics(
      label: '${item.title}. ${item.description}. Location ${item.location}. ${item.time}',
      button: true,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.colors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.colors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.description,
                      style: TextStyle(color: context.colors.textSecondary, fontSize: 12.5),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.place_outlined, size: 13, color: context.colors.textMuted),
                        const SizedBox(width: 3),
                        Text(
                          item.location,
                          style: TextStyle(color: context.colors.textMuted, fontSize: 12),
                        ),
                        if (item.isMine || item.responded) ...[
                          const SizedBox(width: 8),
                          Text(
                            item.isMine ? 'Your report' : 'You responded',
                            style: TextStyle(
                              color: item.isMine
                                  ? context.colors.primary
                                  : context.colors.success,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                item.time,
                style: TextStyle(color: context.colors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
