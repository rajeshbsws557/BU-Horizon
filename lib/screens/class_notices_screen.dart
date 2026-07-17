import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/notice_bloc.dart';
import '../di/di.dart';
import '../models/models.dart';
import '../repositories/notice_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';

class ClassNoticesScreen extends StatelessWidget {
  const ClassNoticesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NoticeBloc(getIt<NoticeRepository>())..add(const NoticeTabChanged(0)),
      child: const _ClassNoticesView(),
    );
  }
}

class _ClassNoticesView extends StatefulWidget {
  const _ClassNoticesView();

  @override
  State<_ClassNoticesView> createState() => _ClassNoticesViewState();
}

class _ClassNoticesViewState extends State<_ClassNoticesView> {
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
        title: Text('Class Notices', style: TextStyle(color: context.colors.textPrimary)),
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: context.colors.textPrimary),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(Icons.filter_list_rounded, color: context.colors.textPrimary),
          ),
        ],
      ),
      body: Column(
        children: [
          BlocBuilder<NoticeBloc, NoticeState>(
            buildWhen: (previous, current) => previous.tab != current.tab,
            builder: (context, state) => SegmentedTabs(
              tabs: const ['All', 'Academic', 'Events', 'Department'],
              selected: state.tab,
              onChanged: (i) => context.read<NoticeBloc>().add(NoticeTabChanged(i)),
            ),
          ),
          Expanded(
            child: BlocBuilder<NoticeBloc, NoticeState>(
              builder: (context, state) {
                final visible = state.visibleNotices;
                return RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: context.colors.surfaceAlt,
                  onRefresh: _refresh,
                  semanticsLabel: 'Refresh class notices',
                  child: _loading
                      ? const _NoticeSkeletonList()
                      : visible.isEmpty
                          ? const EmptyState(
                              icon: Icons.campaign_outlined,
                              title: 'No notices',
                              message: 'Nothing in this category right now. Check back later.',
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(16),
                              itemCount: visible.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (_, i) =>
                                  Entrance(index: i, child: _NoticeCard(notice: visible[i])),
                            ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeSkeletonList extends StatelessWidget {
  const _NoticeSkeletonList();

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
            Skeleton(height: 42, width: 42, radius: BorderRadius.all(Radius.circular(11))),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(height: 14, width: 160),
                  SizedBox(height: 8),
                  Skeleton(height: 12, width: 210),
                ],
              ),
            ),
            SizedBox(width: 8),
            Skeleton(height: 12, width: 60),
          ],
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final ClassNotice notice;
  const _NoticeCard({required this.notice});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${notice.title}. ${notice.subtitle}. ${notice.time}',
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
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: notice.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(notice.icon, color: notice.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notice.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notice.subtitle,
                    style: TextStyle(color: context.colors.textSecondary, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              notice.time,
              style: TextStyle(color: context.colors.textMuted, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}
