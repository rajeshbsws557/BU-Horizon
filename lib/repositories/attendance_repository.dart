import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../models/models.dart';

/// The two statuses persisted by Postgres' `attendance_status` enum.
enum AttendanceMark {
  present,
  absent;

  String get wireValue => name;
}

/// The signed-in student's totals for one course offering.
@immutable
class AttendanceCourseSummary {
  final String offeringId;
  final int present;
  final int total;

  const AttendanceCourseSummary({
    required this.offeringId,
    required this.present,
    required this.total,
  });

  double get percentage => total == 0 ? 0 : present / total;
}

/// One class meeting as it appears in a student's course history.
///
/// [status] is null when the CR has created the session but has not recorded
/// this student's attendance yet. Batch totals are populated for CRs only;
/// regular students must never depend on, or be shown, another student's row.
@immutable
class AttendanceSession {
  final String id;
  final String offeringId;
  final DateTime date;
  final String? startTime;
  final String? endTime;
  final String topic;
  final AttendanceMark? status;
  final int? presentCount;
  final int? recordCount;

  const AttendanceSession({
    required this.id,
    required this.offeringId,
    required this.date,
    this.startTime,
    this.endTime,
    this.topic = '',
    this.status,
    this.presentCount,
    this.recordCount,
  });
}

/// A privacy-limited member of the selected offering's batch.
///
/// Live implementations read this from the privacy-limited
/// `get_batch_attendance_roster` RPC, not from the base profiles table.
/// [status] is null for a new/unrecorded session.
@immutable
class AttendanceRosterMember {
  final String profileId;
  final String fullName;
  final String roll;
  final String studentId;
  final String role;
  final AttendanceMark? status;

  const AttendanceRosterMember({
    required this.profileId,
    required this.fullName,
    this.roll = '',
    this.studentId = '',
    this.role = 'student',
    this.status,
  });

  String get identifier => roll.isNotEmpty ? roll : studentId;
}

/// One class meeting in an attendance export (a CSV column).
@immutable
class AttendanceExportSession {
  final String id;
  final DateTime date;
  final String? startTime;
  final String? endTime;
  final String topic;

  const AttendanceExportSession({
    required this.id,
    required this.date,
    this.startTime,
    this.endTime,
    this.topic = '',
  });
}

/// One student's row in an attendance export: identity plus their mark for each
/// exported session (null = not recorded for that session).
@immutable
class AttendanceExportStudent {
  final String profileId;
  final String fullName;
  final String roll;
  final String studentId;

  /// Mark per session id. A missing/absent entry is treated as not-recorded.
  final Map<String, AttendanceMark> marksBySession;

  const AttendanceExportStudent({
    required this.profileId,
    required this.fullName,
    required this.roll,
    required this.studentId,
    required this.marksBySession,
  });

  int presentIn(Iterable<AttendanceExportSession> sessions) => sessions
      .where((s) => marksBySession[s.id] == AttendanceMark.present)
      .length;

  int recordedIn(Iterable<AttendanceExportSession> sessions) =>
      sessions.where((s) => marksBySession.containsKey(s.id)).length;
}

/// Everything needed to write a clean per-course attendance CSV for a teacher.
///
/// When [sessions] holds a single meeting the export is a single-class report;
/// otherwise it is the full record up to the moment of export.
@immutable
class AttendanceExportData {
  final String courseCode;
  final String courseTitle;
  final String teacherName;
  final List<AttendanceExportSession> sessions;
  final List<AttendanceExportStudent> students;

  const AttendanceExportData({
    required this.courseCode,
    required this.courseTitle,
    required this.teacherName,
    required this.sessions,
    required this.students,
  });
}

/// Complete payload for the atomic `cr_save_attendance` RPC.
@immutable
class AttendanceSessionDraft {
  final String offeringId;
  final String? sessionId;

  /// When the session is being taken for a scheduled class, its id — the saved
  /// session is linked back to the schedule so it shows as "attendance taken".
  final String? scheduleId;
  final DateTime date;
  final String? startTime;
  final String? endTime;
  final String topic;
  final Map<String, AttendanceMark> records;

  AttendanceSessionDraft({
    required this.offeringId,
    required this.date,
    required Map<String, AttendanceMark> records,
    this.sessionId,
    this.scheduleId,
    this.startTime,
    this.endTime,
    this.topic = '',
  }) : records = UnmodifiableMapView(Map.of(records));
}

/// Batch-scoped attendance operations.
///
/// All reads take a course-offering ID. Student-facing reads return only the
/// signed-in student's records; row-level security is the final privacy
/// boundary. Roster and mutation methods are available to the batch CR only.
abstract interface class AttendanceRepository {
  Future<AttendanceCourseSummary> fetchCourseSummary(String offeringId);

  Future<List<AttendanceSession>> fetchCourseSessions(String offeringId);

  Future<List<AttendanceRosterMember>> fetchSessionRoster({
    required String offeringId,
    String? sessionId,
  });

  /// Creates or updates a class session and all supplied student records in
  /// one transaction. Returns the created/updated session ID.
  Future<String> saveSession(AttendanceSessionDraft draft);

  /// Soft-deletes the class session. Reads exclude its attendance rows through
  /// the parent session's `deleted_at` filter.
  Future<void> deleteSession(String sessionId);

  /// CR-only: pulls the full attendance record for a course offering so it can
  /// be exported to CSV for the course teacher. When [sessionId] is given, only
  /// that single class is included; otherwise every recorded class is included.
  Future<AttendanceExportData> fetchExportData({
    required String offeringId,
    String? sessionId,
  });


  /// Compatibility API retained for existing home/tests while callers move
  /// to offering-based summaries.
  Future<List<CourseAttendance>> courseSummaries();
}

@Injectable(as: AttendanceRepository)
final class SampleAttendanceRepository implements AttendanceRepository {
  final List<AttendanceRosterMember> _members = const [
    AttendanceRosterMember(
      profileId: 'sample-student-current',
      fullName: 'Rajesh Biswas',
      roll: 'CSE-01',
      studentId: '2025-CSE-001',
    ),
    AttendanceRosterMember(
      profileId: 'sample-student-2',
      fullName: 'Nusrat Jahan',
      roll: 'CSE-02',
      studentId: '2025-CSE-002',
    ),
    AttendanceRosterMember(
      profileId: 'sample-student-3',
      fullName: 'Shakib Ahmed',
      roll: 'CSE-03',
      studentId: '2025-CSE-003',
    ),
  ];

  late final List<_SampleAttendanceSession> _sessions = [
    _SampleAttendanceSession(
      id: 'sample-session-1',
      offeringId: 'offering-cse-1101',
      date: DateTime(2026, 7, 20),
      startTime: '09:00',
      endTime: '10:00',
      topic: 'Functions and arrays',
      records: const {
        'sample-student-current': AttendanceMark.present,
        'sample-student-2': AttendanceMark.present,
        'sample-student-3': AttendanceMark.absent,
      },
    ),
    _SampleAttendanceSession(
      id: 'sample-session-2',
      offeringId: 'offering-cse-1101',
      date: DateTime(2026, 7, 17),
      startTime: '09:00',
      endTime: '10:00',
      topic: 'Loops',
      records: const {
        'sample-student-current': AttendanceMark.absent,
        'sample-student-2': AttendanceMark.present,
        'sample-student-3': AttendanceMark.present,
      },
    ),
    _SampleAttendanceSession(
      id: 'sample-session-3',
      offeringId: 'offering-cse-1102',
      date: DateTime(2026, 7, 19),
      startTime: '11:00',
      endTime: '12:00',
      topic: 'Relations',
      records: const {
        'sample-student-current': AttendanceMark.present,
        'sample-student-2': AttendanceMark.absent,
        'sample-student-3': AttendanceMark.present,
      },
    ),
    _SampleAttendanceSession(
      id: 'sample-session-4',
      offeringId: 'offering-math-1101',
      date: DateTime(2026, 7, 18),
      startTime: '13:00',
      endTime: '14:00',
      topic: 'Limits',
      records: const {
        'sample-student-current': AttendanceMark.present,
        'sample-student-2': AttendanceMark.present,
        'sample-student-3': AttendanceMark.present,
      },
    ),
  ];

  int _nextSessionId = 5;

  @override
  Future<AttendanceCourseSummary> fetchCourseSummary(String offeringId) async {
    final sessions = _sessions.where((s) => s.offeringId == offeringId);
    var present = 0;
    var total = 0;
    for (final session in sessions) {
      final status = session.records['sample-student-current'];
      if (status == null) continue;
      total++;
      if (status == AttendanceMark.present) present++;
    }
    return AttendanceCourseSummary(
      offeringId: offeringId,
      present: present,
      total: total,
    );
  }

  @override
  Future<List<AttendanceSession>> fetchCourseSessions(String offeringId) async {
    final result =
        _sessions
            .where((session) => session.offeringId == offeringId)
            .map(
              (session) => AttendanceSession(
                id: session.id,
                offeringId: session.offeringId,
                date: session.date,
                startTime: session.startTime,
                endTime: session.endTime,
                topic: session.topic,
                status: session.records['sample-student-current'],
                presentCount: session.records.values
                    .where((status) => status == AttendanceMark.present)
                    .length,
                recordCount: session.records.length,
              ),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return List.unmodifiable(result);
  }

  @override
  Future<List<AttendanceRosterMember>> fetchSessionRoster({
    required String offeringId,
    String? sessionId,
  }) async {
    _SampleAttendanceSession? session;
    if (sessionId != null) {
      for (final candidate in _sessions) {
        if (candidate.id == sessionId && candidate.offeringId == offeringId) {
          session = candidate;
          break;
        }
      }
    }
    return List.unmodifiable(
      _members.map(
        (member) => AttendanceRosterMember(
          profileId: member.profileId,
          fullName: member.fullName,
          roll: member.roll,
          studentId: member.studentId,
          role: member.role,
          status: session?.records[member.profileId],
        ),
      ),
    );
  }

  @override
  Future<String> saveSession(AttendanceSessionDraft draft) async {
    if (draft.records.isEmpty) {
      throw ArgumentError.value(
        draft.records,
        'records',
        'At least one attendance record is required',
      );
    }
    final unknownIds = draft.records.keys.where(
      (id) => !_members.any((member) => member.profileId == id),
    );
    if (unknownIds.isNotEmpty) {
      throw ArgumentError('Attendance contains a student outside the batch');
    }

    _SampleAttendanceSession? existing;
    if (draft.sessionId != null) {
      for (final session in _sessions) {
        if (session.id == draft.sessionId) {
          existing = session;
          break;
        }
      }
      if (existing == null) throw StateError('Attendance session not found');
      if (existing.offeringId != draft.offeringId) {
        throw StateError('Attendance session belongs to another course');
      }
    }

    final id = existing?.id ?? 'sample-session-${_nextSessionId++}';
    final saved = _SampleAttendanceSession(
      id: id,
      offeringId: draft.offeringId,
      date: DateTime(draft.date.year, draft.date.month, draft.date.day),
      startTime: draft.startTime,
      endTime: draft.endTime,
      topic: draft.topic.trim(),
      records: Map.of(draft.records),
    );
    if (existing == null) {
      _sessions.add(saved);
    } else {
      _sessions[_sessions.indexOf(existing)] = saved;
    }
    return id;
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    _sessions.removeWhere((session) => session.id == sessionId);
  }

  @override
  Future<AttendanceExportData> fetchExportData({
    required String offeringId,
    String? sessionId,
  }) async {
    const courses = {
      'offering-cse-1101': (
        'CSE-1101',
        'Computer Fundamentals and Programming',
      ),
      'offering-cse-1102': ('CSE-1102', 'Discrete Mathematics'),
      'offering-math-1101': ('MATH-1101', 'Differential and Integral Calculus'),
    };
    final meta = courses[offeringId] ?? ('COURSE', 'Course');

    final matching = _sessions
        .where((s) => s.offeringId == offeringId)
        .where((s) => sessionId == null || s.id == sessionId)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final sessions = matching
        .map(
          (s) => AttendanceExportSession(
            id: s.id,
            date: s.date,
            startTime: s.startTime,
            endTime: s.endTime,
            topic: s.topic,
          ),
        )
        .toList();

    final students = _members
        .map(
          (m) => AttendanceExportStudent(
            profileId: m.profileId,
            fullName: m.fullName,
            roll: m.roll,
            studentId: m.studentId,
            marksBySession: {
              for (final s in matching)
                if (s.records[m.profileId] != null)
                  s.id: s.records[m.profileId]!,
            },
          ),
        )
        .toList();

    return AttendanceExportData(
      courseCode: meta.$1,
      courseTitle: meta.$2,
      teacherName: '',
      sessions: sessions,
      students: students,
    );
  }

  @override
  Future<List<CourseAttendance>> courseSummaries() async {
    const courses = {
      'offering-cse-1101': (
        'CSE-1101',
        'Computer Fundamentals and Programming',
      ),
      'offering-cse-1102': ('CSE-1102', 'Discrete Mathematics'),
      'offering-math-1101': ('MATH-1101', 'Differential and Integral Calculus'),
    };
    final result = <CourseAttendance>[];
    for (final entry in courses.entries) {
      final summary = await fetchCourseSummary(entry.key);
      result.add(
        CourseAttendance(
          courseCode: entry.value.$1,
          courseTitle: entry.value.$2,
          present: summary.present,
          total: summary.total,
        ),
      );
    }
    return List.unmodifiable(result);
  }
}

class _SampleAttendanceSession {
  final String id;
  final String offeringId;
  final DateTime date;
  final String? startTime;
  final String? endTime;
  final String topic;
  final Map<String, AttendanceMark> records;

  const _SampleAttendanceSession({
    required this.id,
    required this.offeringId,
    required this.date,
    required this.records,
    this.startTime,
    this.endTime,
    this.topic = '',
  });
}
