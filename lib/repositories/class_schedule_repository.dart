import 'package:injectable/injectable.dart';

/// A class the CR has scheduled for a course offering (poll: "CR publishes in
/// the class notice that tomorrow at 11:00 the DBMS class will be held").
///
/// Backed by the `class_schedules` table. Once the class happens the CR records
/// attendance, which creates a `class_sessions` row linked back via
/// `schedule_id`; [sessionId] is non-null from then on.
class ScheduledClass {
  final String id;
  final String offeringId;
  final DateTime date;
  final String? startTime; // 'HH:mm'
  final String? endTime;
  final String? room;
  final String? note;
  final String type; // one_time | rescheduled | cancelled | online
  final String? sessionId;

  const ScheduledClass({
    required this.id,
    required this.offeringId,
    required this.date,
    this.startTime,
    this.endTime,
    this.room,
    this.note,
    this.type = 'one_time',
    this.sessionId,
  });

  bool get attendanceTaken => sessionId != null && sessionId!.isNotEmpty;
  bool get isCancelled => type == 'cancelled';

  /// A scheduled class is ready for attendance once its calendar day has begun.
  bool get hasStarted {
    final now = DateTime.now();
    final startOfDay = DateTime(date.year, date.month, date.day);
    return !startOfDay.isAfter(DateTime(now.year, now.month, now.day));
  }
}

/// Input for creating or editing a scheduled class.
class ScheduleDraft {
  final String offeringId;
  final DateTime date;
  final String? startTime;
  final String? endTime;
  final String? room;
  final String? note;
  final String type;

  const ScheduleDraft({
    required this.offeringId,
    required this.date,
    this.startTime,
    this.endTime,
    this.room,
    this.note,
    this.type = 'one_time',
  });
}

/// Batch class-schedule operations. Reads are batch-scoped; writes are the
/// batch CR's (or super admin), enforced by RLS.
abstract interface class ClassScheduleRepository {
  Future<List<ScheduledClass>> fetchCourseSchedules(String offeringId);
  Future<void> createSchedule(ScheduleDraft draft);
  Future<void> updateSchedule(String scheduleId, ScheduleDraft draft);
  Future<void> deleteSchedule(String scheduleId);
}

@Injectable(as: ClassScheduleRepository)
final class SampleClassScheduleRepository implements ClassScheduleRepository {
  final List<ScheduledClass> _schedules = [];
  int _next = 1;

  @override
  Future<List<ScheduledClass>> fetchCourseSchedules(String offeringId) async {
    final list = _schedules.where((s) => s.offeringId == offeringId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return List.unmodifiable(list);
  }

  @override
  Future<void> createSchedule(ScheduleDraft draft) async {
    _schedules.add(
      ScheduledClass(
        id: 'sample-schedule-${_next++}',
        offeringId: draft.offeringId,
        date: draft.date,
        startTime: draft.startTime,
        endTime: draft.endTime,
        room: draft.room,
        note: draft.note,
        type: draft.type,
      ),
    );
  }

  @override
  Future<void> updateSchedule(String scheduleId, ScheduleDraft draft) async {
    final index = _schedules.indexWhere((s) => s.id == scheduleId);
    if (index == -1) return;
    final prev = _schedules[index];
    _schedules[index] = ScheduledClass(
      id: prev.id,
      offeringId: prev.offeringId,
      date: draft.date,
      startTime: draft.startTime,
      endTime: draft.endTime,
      room: draft.room,
      note: draft.note,
      type: draft.type,
      sessionId: prev.sessionId,
    );
  }

  @override
  Future<void> deleteSchedule(String scheduleId) async {
    _schedules.removeWhere((s) => s.id == scheduleId);
  }
}
