import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

@immutable
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String entityType;
  final String? entityId;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.entityType,
    required this.entityId,
    required this.isRead,
    required this.createdAt,
  });
}

@immutable
class NotificationPage {
  final List<AppNotification> items;
  final bool hasMore;

  const NotificationPage({required this.items, required this.hasMore});
}

abstract interface class NotificationRepository {
  Future<NotificationPage> fetchPage({int offset = 0, int limit = 20});
  Future<int> unreadCount();
  Future<void> markRead(String id);
  Future<void> markAllRead();
}

@Injectable(as: NotificationRepository)
final class SampleNotificationRepository implements NotificationRepository {
  @override
  Future<NotificationPage> fetchPage({int offset = 0, int limit = 20}) async =>
      const NotificationPage(items: [], hasMore: false);

  @override
  Future<int> unreadCount() async => 0;

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> markAllRead() async {}
}