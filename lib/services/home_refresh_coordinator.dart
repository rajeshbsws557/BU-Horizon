import '../data/university_bus_schedule_data.dart';
import '../models/models.dart';
import '../repositories/blood_repository.dart';
import '../repositories/exam_repository.dart';
import '../repositories/notice_repository.dart';
import 'bus_schedule_controller.dart';
import 'home_refresh_state.dart';
import 'notification_controller.dart';

/// Runs every Home refresh operation as one observable, testable transaction.
///
/// A failed source does not cancel the others. Successful urgent-blood and exam
/// reads are published immediately to the Home widgets, while the aggregate
/// snapshot tells the UI whether the refresh was complete, partial, or failed.
final class HomeRefreshCoordinator {
  final NotificationController notifications;
  final BusScheduleController schedule;
  final BloodRepository bloodRepository;
  final ExamRepository examRepository;
  final NoticeRepository noticeRepository;
  final DateTime Function() clock;

  HomeRefreshCoordinator({
    required this.notifications,
    required this.schedule,
    required this.bloodRepository,
    required this.examRepository,
    required this.noticeRepository,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  Future<HomeRefreshSnapshot> refresh() async {
    Future<bool> attempt<T>(
      Future<T> Function() operation, {
      void Function(T value)? onSuccess,
      bool Function(T value)? accepted,
    }) async {
      try {
        final value = await operation();
        if (accepted != null && !accepted(value)) return false;
        onSuccess?.call(value);
        return true;
      } catch (_) {
        return false;
      }
    }

    final results = await Future.wait<bool>([
      attempt<bool>(notifications.refresh, accepted: (value) => value),
      attempt<bool>(schedule.refresh, accepted: (value) => value),
      attempt<BloodRequest?>(
        bloodRepository.fetchActiveUrgentRequest,
        onSuccess: (request) => homeUrgentRequest.value = request,
      ),
      attempt<List<ExamItem>>(
        examRepository.fetchExams,
        onSuccess: (items) => homeExamItems.value = items,
      ),
      attempt<List<ClassNotice>>(noticeRepository.fetchNotices),
    ]);

    final attemptedAt = clock();
    final succeeded = results.where((value) => value).length;
    final health = succeeded == results.length
        ? HomeRefreshHealth.success
        : succeeded == 0
        ? HomeRefreshHealth.failure
        : HomeRefreshHealth.partial;
    final snapshot = HomeRefreshSnapshot(
      health: health,
      succeeded: succeeded,
      total: results.length,
      attemptedAt: attemptedAt,
    );
    homeRefreshSnapshot.value = snapshot;

    // "Last synced" means the complete live Home payload succeeded. A bundled
    // timetable is saved reference data, and a partial refresh is not a sync.
    if (snapshot.health == HomeRefreshHealth.success &&
        schedule.source == BusScheduleSource.live) {
      homeLastSyncedAt.value = attemptedAt;
    }
    return snapshot;
  }
}
