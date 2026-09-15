import 'package:flutter/foundation.dart';

import '../repositories/notification_repository.dart';

class NotificationController extends ChangeNotifier {
  final NotificationRepository _repository;

  NotificationController(this._repository);

  int unreadCount = 0;
  bool loading = false;
  String? error;
  DateTime? lastSyncedAt;
  Future<bool>? _activeRefresh;

  Future<bool> refresh() {
    final active = _activeRefresh;
    if (active != null) return active;
    final operation = _performRefresh();
    _activeRefresh = operation;
    operation.whenComplete(() {
      if (identical(_activeRefresh, operation)) _activeRefresh = null;
    });
    return operation;
  }

  Future<bool> _performRefresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      unreadCount = await _repository.unreadCount();
      lastSyncedAt = DateTime.now();
      return true;
    } catch (_) {
      error = 'Could not refresh notifications.';
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> markRead(String id) async {
    await _repository.markRead(id);
    if (unreadCount > 0) unreadCount--;
    notifyListeners();
    await refresh();
  }

  Future<void> markAllRead() async {
    await _repository.markAllRead();
    unreadCount = 0;
    notifyListeners();
    await refresh();
  }
}
