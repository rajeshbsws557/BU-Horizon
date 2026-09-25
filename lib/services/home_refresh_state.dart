import 'package:flutter/foundation.dart';

import '../models/models.dart';

enum HomeRefreshHealth { idle, success, partial, failure }

@immutable
class HomeRefreshSnapshot {
  final HomeRefreshHealth health;
  final int succeeded;
  final int total;
  final DateTime? attemptedAt;

  const HomeRefreshSnapshot({
    this.health = HomeRefreshHealth.idle,
    this.succeeded = 0,
    this.total = 0,
    this.attemptedAt,
  });
}

/// Shared invalidation signals used by Home and its live-data widgets.
final ValueNotifier<DateTime?> homeLastSyncedAt = ValueNotifier<DateTime?>(
  null,
);
final ValueNotifier<HomeRefreshSnapshot> homeRefreshSnapshot =
    ValueNotifier<HomeRefreshSnapshot>(const HomeRefreshSnapshot());
final ValueNotifier<BloodRequest?> homeUrgentRequest =
    ValueNotifier<BloodRequest?>(null);
final ValueNotifier<List<ExamItem>?> homeExamItems =
    ValueNotifier<List<ExamItem>?>(null);
