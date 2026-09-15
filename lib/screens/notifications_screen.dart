// Developed by Rajesh Biswas (rajeshbiswas.dev)
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/di.dart';
import '../navigation/app_router.dart';
import '../repositories/notification_repository.dart';
import '../services/notification_controller.dart';
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
  late final NotificationController _notificationController =
      getIt<NotificationController>();
  bool _loading = true;
  bool _loadingMore = false;
  int _pendingApprovals = 0;
  List<AppNotification> _notifications = const [];
  bool _hasMore = false;
  String? _error;
  DateTime? _lastUpdatedAt;

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
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    var pending = _pendingApprovals;
    NotificationPage? page;
    String? error;
    if (_canReview) {
      try {
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
      } catch (_) {
        // Action-item counts are best effort and must not block notifications.
      }
    }
    try {
      page = await getIt<NotificationRepository>().fetchPage();
    } catch (_) {
      error = 'Could not load your latest notifications.';
    }
    if (!mounted) return;
    setState(() {
      _pendingApprovals = pending;
      if (page != null) {
        _notifications = page.items;
        _hasMore = page.hasMore;
        _lastUpdatedAt = DateTime.now();
      }
      _error = error;
      _loading = false;
    });
    await _notificationController.refresh();
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await getIt<NotificationRepository>().fetchPage(
        offset: _notifications.length,
      );
      if (!mounted) return;
      setState(() {
        _notifications = [..._notifications, ...page.items];
        _hasMore = page.hasMore;
      });
    } catch (_) {
      if (mounted) showToast(context, 'Could not load more notifications');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _markRead(
    AppNotification notification, {
    bool navigate = true,
  }) async {
    try {
      if (!notification.isRead) {
        await _notificationController.markRead(notification.id);
        if (!mounted) return;
        setState(() {
          _notifications = [
            for (final item in _notifications)
              if (item.id == notification.id)
                AppNotification(
                  id: item.id,
                  title: item.title,
                  body: item.body,
                  entityType: item.entityType,
                  entityId: item.entityId,
                  isRead: true,
                  createdAt: item.createdAt,
                )
              else
                item,
          ];
        });
      }
    } catch (_) {
      if (mounted) {
        showToast(context, 'Could not mark this notification as read');
      }
      return;
    }
    if (!navigate) return;
    final route = _notificationRoute(notification.entityType);
    if (route == null) return;
    await context.push(route);
    if (mounted) await _load();
  }

  Future<void> _markAllRead() async {
    try {
      await _notificationController.markAllRead();
      if (!mounted) return;
      setState(() {
        _notifications = [
          for (final item in _notifications)
            AppNotification(
              id: item.id,
              title: item.title,
              body: item.body,
              entityType: item.entityType,
              entityId: item.entityId,
              isRead: true,
              createdAt: item.createdAt,
            ),
        ];
      });
    } catch (_) {
      if (mounted) {
        showToast(context, 'Could not mark all notifications as read');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ListenableBuilder(
          listenable: _notificationController,
          builder: (context, _) => Row(
            children: [
              const Text('Notifications'),
              if (_notificationController.unreadCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  constraints: const BoxConstraints(minWidth: 22),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.danger,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _notificationController.unreadCount > 99
                        ? '99+'
                        : '${_notificationController.unreadCount}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          ListenableBuilder(
            listenable: _notificationController,
            builder: (context, _) => _notificationController.unreadCount > 0
                ? IconButton(
                    tooltip: 'Mark all as read',
                    onPressed: _markAllRead,
                    icon: const Icon(Icons.done_all_rounded),
                  )
                : const SizedBox.shrink(),
          ),
        ],
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
        children: [
          const SizedBox(height: 90),
          const EmptyState(
            icon: Icons.notifications_off_outlined,
            title: 'Sign in to see notifications',
            message:
                'Keep unread campus updates, approval requests, and linked notices in one place.',
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
      );
    }

    if (!_loading && _error != null && _notifications.isEmpty) {
      return RetryStateList(
        title: 'Notifications unavailable',
        message: _error!,
        onRetry: _load,
      );
    }

    final hasActionItems = _canReview;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: LastUpdatedLabel(
            updatedAt: _lastUpdatedAt,
            emptyLabel: 'Notifications not synced yet',
          ),
        ),
        if (_error != null && _notifications.isNotEmpty) ...[
          const SizedBox(height: 10),
          DataStateBanner(
            message:
                'Could not refresh notifications. Showing the last loaded list.',
            tone: DataStateTone.warning,
            onRetry: _load,
          ),
        ],
        const SizedBox(height: 14),
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
        if (_loading)
          const _NotificationSkeletonList()
        else if (_notifications.isEmpty)
          _EmptyNotice(
            message:
                _error ??
                (hasActionItems
                    ? 'You\'re all caught up. New alerts will show up here.'
                    : 'No new notifications. Campus alerts and updates will '
                          'appear here.'),
          )
        else ...[
          for (final group in _groupNotifications(_notifications)) ...[
            _SectionLabel(group.label),
            const SizedBox(height: 8),
            for (final notification in group.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _NotificationTile(
                  notification: notification,
                  onTap: _notificationRoute(notification.entityType) == null
                      ? null
                      : () => _markRead(notification),
                  onMarkRead:
                      notification.isRead ||
                          _notificationRoute(notification.entityType) != null
                      ? null
                      : () => _markRead(notification, navigate: false),
                ),
              ),
          ],
          if (_hasMore)
            TextButton.icon(
              onPressed: _loadingMore ? null : _loadMore,
              icon: _loadingMore
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more_rounded),
              label: const Text('Load more'),
            ),
        ],
      ],
    );
  }
}

class _NotificationGroup {
  final String label;
  final List<AppNotification> items;

  const _NotificationGroup(this.label, this.items);
}

List<_NotificationGroup> _groupNotifications(List<AppNotification> items) {
  final now = DateTime.now();
  final today = <AppNotification>[];
  final yesterday = <AppNotification>[];
  final earlier = <AppNotification>[];
  for (final item in items) {
    final date = item.createdAt;
    final age = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(date.year, date.month, date.day)).inDays;
    if (age == 0) {
      today.add(item);
    } else if (age == 1) {
      yesterday.add(item);
    } else {
      earlier.add(item);
    }
  }
  return [
    if (today.isNotEmpty) _NotificationGroup('Today', today),
    if (yesterday.isNotEmpty) _NotificationGroup('Yesterday', yesterday),
    if (earlier.isNotEmpty) _NotificationGroup('Earlier', earlier),
  ];
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback? onTap;
  final VoidCallback? onMarkRead;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    final icon = switch (notification.entityType) {
      'exam' => Icons.event_note_rounded,
      'attendance' ||
      'attendance_correction_request' => Icons.fact_check_rounded,
      'bus' || 'bus_route' => Icons.directions_bus_rounded,
      'blood_request' => Icons.water_drop_rounded,
      'lost_found' || 'lost_found_item' => Icons.inventory_2_rounded,
      _ => Icons.notifications_rounded,
    };
    final age = DateTime.now().difference(notification.createdAt);
    final hasDestination = _notificationRoute(notification.entityType) != null;
    final time = age.inMinutes < 1
        ? 'Just now'
        : age.inHours < 1
        ? '${age.inMinutes}m ago'
        : age.inDays < 1
        ? '${age.inHours}h ago'
        : '${age.inDays}d ago';
    final content = Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: context.colors.primary, size: 21),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontWeight: notification.isRead
                        ? FontWeight.w600
                        : FontWeight.w800,
                  ),
                ),
                if (notification.body.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    notification.body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
                const SizedBox(height: 5),
                Text(
                  time,
                  style: TextStyle(
                    color: context.colors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (!notification.isRead)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: context.colors.primary,
                shape: BoxShape.circle,
              ),
            ),
          if (onMarkRead != null)
            TextButton(
              onPressed: onMarkRead,
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 7),
              ),
              child: const Text('Mark read'),
            )
          else
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(
                hasDestination
                    ? Icons.chevron_right_rounded
                    : Icons.info_outline_rounded,
                size: 18,
                color: context.colors.textMuted,
              ),
            ),
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      label: onTap == null
          ? '${notification.title}. Informational notification.'
          : null,
      child: Material(
        color: notification.isRead
            ? context.colors.surfaceAlt
            : context.colors.primary.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
        child: onTap == null
            ? content
            : InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(8),
                child: content,
              ),
      ),
    );
  }
}

class _NotificationSkeletonList extends StatelessWidget {
  const _NotificationSkeletonList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: cardDecoration(context: context),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(height: 22, width: 22),
                SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Skeleton(height: 14, width: 170),
                      SizedBox(height: 7),
                      Skeleton(height: 11, width: 240),
                      SizedBox(height: 7),
                      Skeleton(height: 10, width: 60),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String? _notificationRoute(String entityType) => switch (entityType) {
  'notice' => AppRoutes.notices,
  'exam' => AppRoutes.exams,
  'attendance' || 'attendance_correction_request' => AppRoutes.attendance,
  'bus' || 'bus_route' => AppRoutes.bus,
  'blood_request' => AppRoutes.blood,
  'lost_found' || 'lost_found_item' => AppRoutes.lostFound,
  _ => null,
};

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
