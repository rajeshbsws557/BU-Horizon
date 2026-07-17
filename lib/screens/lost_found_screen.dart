import 'dart:async';

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
      create: (_) => LostFoundCubit(getIt<LostFoundRepository>()),
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
  Timer? _loadingTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _loadingTimer?.cancel();
    final completer = Completer<void>();
    setState(() => _loading = true);
    _loadingTimer = Timer(const Duration(milliseconds: 450), () {
      if (mounted) {
        setState(() => _loading = false);
      }
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  Future<void> _refresh() => _load();

  @override
  void dispose() {
    _loadingTimer?.cancel();
    super.dispose();
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
                final repository = context.read<LostFoundCubit>().repository;
                final visible = tab == 0 ? repository.lostItems : repository.foundItems;
                return RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: context.colors.surfaceAlt,
                  onRefresh: _refresh,
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
                              itemBuilder: (_, i) =>
                                  Entrance(index: i, child: _ItemCard(item: visible[i])),
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
                onPressed: () => showToast(context, 'Report form opened'),
              ),
            ),
          ),
        ],
      ),
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
  LostFoundCubit(this.repository) : super(0);

  final LostFoundRepository repository;

  void setTab(int tab) => emit(tab);

  void refresh() => emit(state);
}

class _ItemCard extends StatelessWidget {
  final LostFoundItem item;
  const _ItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final accent = item.isLost ? context.colors.warning : context.colors.success;
    return Semantics(
      label: '${item.title}. ${item.description}. Location ${item.location}. ${item.time}',
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
    );
  }
}
