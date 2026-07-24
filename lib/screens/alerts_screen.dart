import 'package:flutter/material.dart';

import '../di/di.dart';
import '../models/models.dart';
import '../repositories/notice_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';

/// Public Notices tab — university-wide notices published by the authority
/// (super admin). Readable by guests and registered students alike.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  bool _loading = true;
  List<ClassNotice> _notices = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final notices = await getIt<NoticeRepository>().fetchNotices();
      if (!mounted) return;
      setState(() {
        _notices = notices;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ResponsivePage(
        child: Column(
          children: [
            const TabHeader(
              title: 'Public Notices',
              subtitle: 'Official announcements for the whole campus',
            ),
            Expanded(
              child: RefreshIndicator(
                color: context.colors.primary,
                backgroundColor: context.colors.surfaceAlt,
                onRefresh: _load,
                child: _loading
                    ? const _SkeletonList()
                    : _notices.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 120),
                          EmptyState(
                            icon: Icons.campaign_outlined,
                            title: 'No public notices yet',
                            message:
                                'University announcements will appear here when published.',
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _notices.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => Entrance(
                          index: i,
                          child: _NoticeCard(notice: _notices[i]),
                        ),
                      ),
              ),
            ),
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
    final color = context.colors.resolve(notice.color);
    final body = notice.body.isEmpty ? notice.subtitle : notice.body;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(context: context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(notice.icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (notice.isPinned) ...[
                      Icon(
                        Icons.push_pin_rounded,
                        size: 13,
                        color: context.colors.warning,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        notice.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          color: context.colors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      notice.time,
                      style: TextStyle(
                        color: context.colors.textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.all(14),
        decoration: cardDecoration(context: context),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(
              height: 42,
              width: 42,
              radius: BorderRadius.all(Radius.circular(11)),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(height: 14, width: 150),
                  SizedBox(height: 8),
                  Skeleton(height: 12, width: 220),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
