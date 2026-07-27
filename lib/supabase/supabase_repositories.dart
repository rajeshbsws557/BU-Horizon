// Live Supabase implementations of the content repositories.
//
// Row-level security does the heavy lifting: every query here runs with the
// signed-in user's JWT, so batch scoping (notices, exams, resources,
// schedules) and privacy (attendance = own rows only) are enforced by the
// database no matter what the client asks for. These classes only map rows to
// UI models.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/local_store.dart';
import '../data/university_bus_schedule_data.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import '../theme/app_theme.dart';

SupabaseClient get _client => Supabase.instance.client;

String? get _uid => _client.auth.currentUser?.id;

Future<String> _requireCurrentBatchId() async {
  final uid = _uid;
  if (uid == null) throw StateError('A signed-in account is required.');
  final row = await _client
      .from('profiles')
      .select('batch_id')
      .eq('id', uid)
      .single();
  final batchId = row['batch_id'] as String?;
  if (batchId == null || batchId.isEmpty) {
    throw StateError('Your account is not assigned to a batch yet.');
  }
  return batchId;
}

/// "2h ago" style label from an ISO timestamp.
String _relativeTime(String? iso) {
  if (iso == null) return '';
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('MMM d').format(dt);
}

/// "9:30 AM" from Postgres "09:30:00".
String _fmtTime(String? hhmmss) {
  if (hhmmss == null || hhmmss.length < 5) return '';
  final parts = hhmmss.split(':');
  final h = int.tryParse(parts[0]) ?? 0;
  final m = parts.length > 1 ? parts[1] : '00';
  final suffix = h >= 12 ? 'PM' : 'AM';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:$m $suffix';
}

String _fmtDate(String? yyyymmdd) {
  if (yyyymmdd == null) return '';
  final dt = DateTime.tryParse(yyyymmdd);
  if (dt == null) return '';
  return DateFormat('EEE, MMM d').format(dt);
}

/// Trims a text field and collapses blanks to null so optional columns stay
/// null rather than empty strings.
String? _nullIfBlank(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

final class SupabaseNoticeRepository implements NoticeRepository {
  static (NoticeCategory, IconData, Color) _style(String? category) {
    switch (category) {
      case 'exam':
        return (
          NoticeCategory.academic,
          Icons.edit_document,
          AppColorToken.warning,
        );
      case 'academic':
        return (
          NoticeCategory.academic,
          Icons.school_rounded,
          AppColorToken.primary,
        );
      case 'department':
        return (
          NoticeCategory.department,
          Icons.apartment_rounded,
          AppColorToken.accentCyan,
        );
      case 'event':
        return (
          NoticeCategory.events,
          Icons.celebration_rounded,
          AppColorToken.danger,
        );
      default: // general
        return (
          NoticeCategory.events,
          Icons.campaign_rounded,
          AppColorToken.purple,
        );
    }
  }

  static String _categoryValue(NoticeCategory category) => switch (category) {
    NoticeCategory.academic => 'academic',
    NoticeCategory.events => 'event',
    NoticeCategory.department => 'department',
  };

  static ClassNotice _fromRow(Map<String, dynamic> row) {
    final (category, icon, color) = _style(row['category'] as String?);
    final body = (row['body'] as String?) ?? '';
    return ClassNotice(
      id: (row['id'] as String?) ?? '',
      offeringId: (row['offering_id'] as String?) ?? '',
      title: (row['title'] as String?) ?? '',
      subtitle: body.split('\n').first,
      body: body,
      time: _relativeTime(
        (row['published_at'] ?? row['created_at']) as String?,
      ),
      category: category,
      icon: icon,
      color: color,
      isPinned: (row['is_pinned'] as bool?) ?? false,
    );
  }

  @override
  Future<List<ClassNotice>> fetchNotices() async {
    // Public Notices: university-scope, published. Read-through cache so guests
    // and students can still see the last-fetched notices while offline.
    final rows = await cachedRows('public_notices', () async {
      final result = await _client
          .from('notices')
          .select(
            'id, offering_id, title, body, category, scope, is_pinned, '
            'published_at, created_at',
          )
          .eq('scope', 'university')
          .isFilter('deleted_at', null)
          .eq('state', 'published')
          .order('is_pinned', ascending: false)
          .order('published_at', ascending: false)
          .limit(50);
      return result.cast<Map<String, dynamic>>();
    });
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<ClassNotice>> fetchCourseNotices(String offeringId) async {
    final rows = await cachedRows('course_notices.$offeringId', () async {
      final result = await _client
          .from('notices')
          .select(
            'id, offering_id, title, body, category, is_pinned, published_at, '
            'created_at',
          )
          .eq('offering_id', offeringId)
          .eq('state', 'published')
          .isFilter('deleted_at', null)
          .order('is_pinned', ascending: false)
          .order('published_at', ascending: false)
          .limit(100);
      return result.cast<Map<String, dynamic>>();
    });
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> createCourseNotice({
    required String offeringId,
    required String title,
    required String body,
    required NoticeCategory category,
    required bool isPinned,
  }) async {
    final batchId = await _requireCurrentBatchId();
    await _client.from('notices').insert({
      'scope': 'batch',
      'batch_id': batchId,
      'offering_id': offeringId,
      'category': _categoryValue(category),
      'title': title.trim(),
      'body': body.trim(),
      'state': 'published',
      'is_pinned': isPinned,
      'published_at': DateTime.now().toUtc().toIso8601String(),
      'created_by': _uid,
    });
  }

  @override
  Future<void> updateCourseNotice({
    required String noticeId,
    required String title,
    required String body,
    required NoticeCategory category,
    required bool isPinned,
  }) async {
    await _client
        .from('notices')
        .update({
          'category': _categoryValue(category),
          'title': title.trim(),
          'body': body.trim(),
          'is_pinned': isPinned,
        })
        .eq('id', noticeId);
  }

  @override
  Future<void> deleteCourseNotice(String noticeId) async {
    await _client
        .from('notices')
        .update({
          'state': 'archived',
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', noticeId);
  }
}

final class SupabaseAlertRepository implements AlertRepository {
  static AlertType _type(String? raw) => switch (raw) {
    'bus' => AlertType.bus,
    'exam' => AlertType.exam,
    'event' => AlertType.event,
    'library' => AlertType.library,
    'lost_found' => AlertType.lostFound,
    _ => AlertType.notice,
  };

  @override
  Future<List<AlertItem>> fetchAlerts() async {
    final rows = await _client
        .from('alerts')
        .select('type, title, subtitle, created_at')
        .order('created_at', ascending: false)
        .limit(50);
    return rows
        .map(
          (row) => AlertItem(
            title: (row['title'] as String?) ?? '',
            subtitle: (row['subtitle'] as String?) ?? '',
            time: _relativeTime(row['created_at'] as String?),
            type: _type(row['type'] as String?),
          ),
        )
        .toList();
  }
}

final class SupabaseClassScheduleRepository implements ClassScheduleRepository {
  static DateTime _date(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) throw const FormatException('Invalid schedule date');
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  @override
  Future<List<ScheduledClass>> fetchCourseSchedules(String offeringId) async {
    // Reverse-embed the linked attendance session (via class_sessions.schedule_id)
    // to know whether attendance has already been recorded for the class.
    final rows = await cachedRows('schedules.$offeringId', () async {
      final result = await _client
          .from('class_schedules')
          .select(
            'id, offering_id, schedule_date, start_time, end_time, room, note, '
            'type, class_sessions!left(id, deleted_at)',
          )
          .eq('offering_id', offeringId)
          .isFilter('deleted_at', null)
          .order('schedule_date', ascending: false)
          .order('start_time', ascending: false);
      return result.cast<Map<String, dynamic>>();
    });

    return rows.map((row) {
      final sessions = (row['class_sessions'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .where((s) => s['deleted_at'] == null);
      final sessionId = sessions.isEmpty ? null : sessions.first['id'] as String?;
      return ScheduledClass(
        id: row['id'] as String,
        offeringId: (row['offering_id'] as String?) ?? offeringId,
        date: _date(row['schedule_date']),
        startTime: row['start_time'] as String?,
        endTime: row['end_time'] as String?,
        room: row['room'] as String?,
        note: row['note'] as String?,
        type: (row['type'] as String?) ?? 'one_time',
        sessionId: sessionId,
      );
    }).toList();
  }

  Map<String, dynamic> _payload(ScheduleDraft draft) => {
    'offering_id': draft.offeringId,
    'type': draft.type,
    'schedule_date': DateFormat('yyyy-MM-dd').format(draft.date),
    'start_time': draft.startTime,
    'end_time': draft.endTime,
    'room': _nullIfBlank(draft.room),
    'note': _nullIfBlank(draft.note),
  };

  @override
  Future<void> createSchedule(ScheduleDraft draft) async {
    final batchId = await _requireCurrentBatchId();
    await _client.from('class_schedules').insert({
      'batch_id': batchId,
      'created_by': _uid,
      ..._payload(draft),
    });
  }

  @override
  Future<void> updateSchedule(String scheduleId, ScheduleDraft draft) async {
    await _client
        .from('class_schedules')
        .update(_payload(draft))
        .eq('id', scheduleId);
  }

  @override
  Future<void> deleteSchedule(String scheduleId) async {
    await _client
        .from('class_schedules')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', scheduleId);
  }
}

final class SupabaseLegalHelpRepository implements LegalHelpRepository {
  @override
  Future<void> submitReport(LegalHelpDraft draft) async {
    await _client.from('cyberbullying_reports').insert({
      // Anonymous reports (and guest submissions) carry no reporter identity.
      'reporter_id': draft.isAnonymous ? null : _uid,
      'is_anonymous': draft.isAnonymous,
      'reporter_name': draft.isAnonymous ? null : _nullIfBlank(draft.reporterName),
      'contact_email': _nullIfBlank(draft.contactEmail),
      'contact_phone': _nullIfBlank(draft.contactPhone),
      'category': draft.category.wire,
      'incident_platform': _nullIfBlank(draft.incidentPlatform),
      'incident_date': draft.incidentDate == null
          ? null
          : DateFormat('yyyy-MM-dd').format(draft.incidentDate!),
      'location': _nullIfBlank(draft.location),
      'involved_parties': _nullIfBlank(draft.involvedParties),
      'description': draft.description.trim(),
      'evidence_url': _nullIfBlank(draft.evidenceUrl),
    });
  }
}

final class SupabasePeopleRepository implements PeopleRepository {
  @override
  Future<List<Person>> search(String query) async {
    // Strip characters that would break the PostgREST or() filter syntax.
    final q = query.trim().replaceAll(RegExp(r'[,%.()]'), ' ').trim();
    var builder = _client
        .from('people_directory')
        .select('full_name, email, department_name');
    if (q.isNotEmpty) {
      builder = builder.or(
        'full_name.ilike.%$q%,email.ilike.%$q%,department_name.ilike.%$q%',
      );
    }
    final rows = await builder.order('full_name', ascending: true).limit(50);
    return rows
        .map(
          (row) => Person(
            name: (row['full_name'] as String?) ?? '',
            department: (row['department_name'] as String?) ?? '—',
            email: (row['email'] as String?) ?? '',
          ),
        )
        .toList();
  }
}

final class SupabaseAttendanceRepository implements AttendanceRepository {
  static AttendanceMark? _mark(String? value) => switch (value) {
    'present' => AttendanceMark.present,
    'absent' => AttendanceMark.absent,
    _ => null,
  };

  static DateTime _sessionDate(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) {
      throw const FormatException('Invalid class session date');
    }
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  @override
  Future<AttendanceCourseSummary> fetchCourseSummary(String offeringId) async {
    final uid = _uid;
    if (uid == null) {
      return AttendanceCourseSummary(
        offeringId: offeringId,
        present: 0,
        total: 0,
      );
    }

    final rows = await cachedRows('att_course.$offeringId.$uid', () async {
      final result = await _client
          .from('attendance_records')
          .select('status, class_sessions!inner(offering_id, deleted_at)')
          .eq('student_id', uid)
          .eq('class_sessions.offering_id', offeringId)
          .isFilter('class_sessions.deleted_at', null);
      return result.cast<Map<String, dynamic>>();
    });

    var present = 0;
    for (final row in rows) {
      if (row['status'] == 'present') present++;
    }
    return AttendanceCourseSummary(
      offeringId: offeringId,
      present: present,
      total: rows.length,
    );
  }

  @override
  Future<List<AttendanceSession>> fetchCourseSessions(String offeringId) async {
    final uid = _uid;
    if (uid == null) return const [];

    final rows = await cachedRows('att_sessions.$offeringId.$uid', () async {
      final result = await _client
          .from('class_sessions')
          .select(
            'id, offering_id, session_date, start_time, end_time, topic, '
            'attendance_records(student_id, status)',
          )
          .eq('offering_id', offeringId)
          .isFilter('deleted_at', null)
          .order('session_date', ascending: false)
          .order('start_time', ascending: false);
      return result.cast<Map<String, dynamic>>();
    });

    return rows.map((row) {
      final records = (row['attendance_records'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();
      AttendanceMark? ownStatus;
      var presentCount = 0;
      for (final record in records) {
        final status = _mark(record['status'] as String?);
        if (record['student_id'] == uid) ownStatus = status;
        if (status == AttendanceMark.present) presentCount++;
      }
      return AttendanceSession(
        id: row['id'] as String,
        offeringId: (row['offering_id'] as String?) ?? offeringId,
        date: _sessionDate(row['session_date']),
        startTime: row['start_time'] as String?,
        endTime: row['end_time'] as String?,
        topic: (row['topic'] as String?) ?? '',
        status: ownStatus,
        presentCount: presentCount,
        recordCount: records.length,
      );
    }).toList();
  }

  @override
  Future<List<AttendanceRosterMember>> fetchSessionRoster({
    required String offeringId,
    String? sessionId,
  }) async {
    final rosterRows =
        await _client.rpc(
              'get_batch_attendance_roster',
              params: {'p_offering_id': offeringId},
            )
            as List<dynamic>;

    final marks = <String, AttendanceMark>{};
    if (sessionId != null) {
      final recordRows = await _client
          .from('attendance_records')
          .select('student_id, status, class_sessions!inner(offering_id)')
          .eq('session_id', sessionId)
          .eq('class_sessions.offering_id', offeringId);
      for (final row in recordRows) {
        final status = _mark(row['status'] as String?);
        if (status != null) marks[row['student_id'] as String] = status;
      }
    }

    return rosterRows.map((raw) {
      final row = raw as Map<String, dynamic>;
      final profileId = row['profile_id'] as String;
      return AttendanceRosterMember(
        profileId: profileId,
        fullName: (row['full_name'] as String?) ?? '',
        roll: (row['roll'] as String?) ?? '',
        studentId: (row['student_id'] as String?) ?? '',
        role: (row['role'] as String?) ?? 'student',
        status: marks[profileId],
      );
    }).toList();
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
    final result = await _client.rpc(
      'cr_save_attendance',
      params: {
        'p_offering_id': draft.offeringId,
        'p_session_date': DateFormat('yyyy-MM-dd').format(draft.date),
        'p_records': [
          for (final record in draft.records.entries)
            {'student_id': record.key, 'status': record.value.wireValue},
        ],
        'p_session_id': draft.sessionId,
        'p_start_time': draft.startTime,
        'p_end_time': draft.endTime,
        'p_topic': draft.topic.trim().isEmpty ? null : draft.topic.trim(),
      },
    );
    final row = result as Map<String, dynamic>;
    final sessionId = row['session_id'] as String?;
    if (sessionId == null || sessionId.isEmpty) {
      throw StateError('Attendance RPC did not return a session ID');
    }
    // Link the freshly-recorded session back to the scheduled class so the
    // schedule shows as "attendance recorded". Best-effort: attendance is
    // already saved, so a failed link must not surface as a save failure.
    if (draft.scheduleId != null && draft.scheduleId!.isNotEmpty) {
      try {
        await _client
            .from('class_sessions')
            .update({'schedule_id': draft.scheduleId})
            .eq('id', sessionId);
      } catch (_) {}
    }
    return sessionId;
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    await _client
        .from('class_sessions')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', sessionId);
  }

  @override
  Future<AttendanceExportData> fetchExportData({
    required String offeringId,
    String? sessionId,
  }) async {
    // Course identity (code/title/teacher) for the report header.
    final offeringRow = await _client
        .from('course_offerings')
        .select('teacher_name, courses!inner(code, title)')
        .eq('id', offeringId)
        .single();
    final course = offeringRow['courses'] as Map<String, dynamic>?;
    final courseCode = (course?['code'] as String?) ?? '';
    final courseTitle = (course?['title'] as String?) ?? '';
    final teacherName = (offeringRow['teacher_name'] as String?) ?? '';

    // The privacy-limited roster is the authoritative student list; RLS confirms
    // the caller is the batch CR before this returns any rows.
    final rosterRows =
        await _client.rpc(
              'get_batch_attendance_roster',
              params: {'p_offering_id': offeringId},
            )
            as List<dynamic>;

    // Sessions (a single class when sessionId is given, else the whole course).
    var sessionQuery = _client
        .from('class_sessions')
        .select(
          'id, session_date, start_time, end_time, topic, '
          'attendance_records(student_id, status)',
        )
        .eq('offering_id', offeringId)
        .isFilter('deleted_at', null);
    if (sessionId != null) sessionQuery = sessionQuery.eq('id', sessionId);
    final sessionRows = (await sessionQuery
            .order('session_date', ascending: true)
            .order('start_time', ascending: true))
        .cast<Map<String, dynamic>>();

    final sessions = <AttendanceExportSession>[];
    // studentId -> (sessionId -> mark)
    final marks = <String, Map<String, AttendanceMark>>{};
    for (final row in sessionRows) {
      final sid = row['id'] as String;
      sessions.add(
        AttendanceExportSession(
          id: sid,
          date: _sessionDate(row['session_date']),
          startTime: row['start_time'] as String?,
          endTime: row['end_time'] as String?,
          topic: (row['topic'] as String?) ?? '',
        ),
      );
      final records =
          (row['attendance_records'] as List<dynamic>? ?? const [])
              .cast<Map<String, dynamic>>();
      for (final record in records) {
        final mark = _mark(record['status'] as String?);
        if (mark == null) continue;
        final studentId = record['student_id'] as String;
        (marks[studentId] ??= {})[sid] = mark;
      }
    }

    final students = rosterRows.map((raw) {
      final row = raw as Map<String, dynamic>;
      final profileId = row['profile_id'] as String;
      return AttendanceExportStudent(
        profileId: profileId,
        fullName: (row['full_name'] as String?) ?? '',
        roll: (row['roll'] as String?) ?? '',
        studentId: (row['student_id'] as String?) ?? '',
        marksBySession: marks[profileId] ?? const {},
      );
    }).toList();

    return AttendanceExportData(
      courseCode: courseCode,
      courseTitle: courseTitle,
      teacherName: teacherName,
      sessions: sessions,
      students: students,
    );
  }


  @override
  Future<List<CourseAttendance>> courseSummaries() async {
    final uid = _uid;
    if (uid == null) return const [];
    // RLS already restricts rows to the student's own records; the explicit
    // filter just keeps the query honest.
    final rows = await cachedRows('att_summary.$uid', () async {
      final result = await _client
          .from('attendance_records')
          .select(
            'status, class_sessions!inner(deleted_at, '
            'course_offerings!inner(courses!inner(code, title)))',
          )
          .eq('student_id', uid)
          .isFilter('class_sessions.deleted_at', null);
      return result.cast<Map<String, dynamic>>();
    });
    final byCourse = <String, ({String title, int present, int total})>{};
    for (final row in rows) {
      final session = row['class_sessions'] as Map<String, dynamic>?;
      final offering = session?['course_offerings'] as Map<String, dynamic>?;
      final course = offering?['courses'] as Map<String, dynamic>?;
      final code = (course?['code'] as String?) ?? '—';
      final title = (course?['title'] as String?) ?? '';
      final present = row['status'] == 'present' ? 1 : 0;
      final prev = byCourse[code];
      byCourse[code] = (
        title: title,
        present: (prev?.present ?? 0) + present,
        total: (prev?.total ?? 0) + 1,
      );
    }
    final result =
        byCourse.entries
            .map(
              (e) => CourseAttendance(
                courseCode: e.key,
                courseTitle: e.value.title,
                present: e.value.present,
                total: e.value.total,
              ),
            )
            .toList()
          ..sort((a, b) => a.courseCode.compareTo(b.courseCode));
    return result;
  }
}

final class SupabaseExamRepository implements ExamRepository {
  static String _typeLabel(String? raw) => switch (raw) {
    'midterm' => 'Midterm',
    'final' => 'Final',
    'quiz' => 'Quiz',
    _ => 'Exam',
  };

  static ExamItem _fromRow(Map<String, dynamic> row) {
    final offering = row['course_offerings'] as Map<String, dynamic>?;
    final course = offering?['courses'] as Map<String, dynamic>?;
    final start = _fmtTime(row['start_time'] as String?);
    final end = _fmtTime(row['end_time'] as String?);
    return ExamItem(
      id: row['id'] as String,
      offeringId: (row['offering_id'] as String?) ?? '',
      title: (row['title'] as String?) ?? '',
      typeLabel: _typeLabel(row['type'] as String?),
      dateLabel: _fmtDate(row['exam_date'] as String?),
      timeLabel: [start, end].where((s) => s.isNotEmpty).join(' – '),
      courseCode: (course?['code'] as String?) ?? '',
      room: (row['room'] as String?) ?? '',
      description: (row['description'] as String?) ?? '',
      termNumber: offering?['term_number'] as int?,
    );
  }

  @override
  Future<List<ExamItem>> fetchExams() async {
    final rows = await cachedRows('exams.${_uid ?? 'guest'}', () async {
      final result = await _client
          .from('exams')
          .select(
            'id, offering_id, type, title, description, exam_date, start_time, end_time, room, course_offerings(term_number, courses(code))',
          )
          .isFilter('deleted_at', null)
          .order('exam_date', ascending: true)
          .limit(50);
      return result.cast<Map<String, dynamic>>();
    });
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<ExamItem>> fetchCourseExams(String offeringId) async {
    final rows = await cachedRows('exams.course.$offeringId', () async {
      final result = await _client
          .from('exams')
          .select(
            'id, offering_id, type, title, description, exam_date, start_time, end_time, room, course_offerings(term_number, courses(code))',
          )
          .eq('offering_id', offeringId)
          .isFilter('deleted_at', null)
          .order('exam_date', ascending: true)
          .limit(50);
      return result.cast<Map<String, dynamic>>();
    });
    return rows.map(_fromRow).toList();
  }

  static String _typeValue(String raw) => switch (raw.toLowerCase()) {
    'midterm' => 'midterm',
    'final' => 'final',
    'quiz' => 'quiz',
    _ => 'other',
  };

  static String? _fmtTimeStr(TimeOfDay? t) {
    if (t == null) return null;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';
  }

  @override
  Future<void> createExam({
    required String offeringId,
    required ExamInput input,
  }) async {
    final batchId = await _requireCurrentBatchId();
    await _client.from('exams').insert({
      'batch_id': batchId,
      'offering_id': offeringId,
      'type': _typeValue(input.type),
      'title': input.title.trim(),
      'description': input.description?.trim().isEmpty == true
          ? null
          : input.description?.trim(),
      'exam_date': input.examDate != null
          ? DateFormat('yyyy-MM-dd').format(input.examDate!)
          : null,
      'start_time': _fmtTimeStr(input.startTime),
      'end_time': _fmtTimeStr(input.endTime),
      'room': input.room?.trim().isEmpty == true ? null : input.room?.trim(),
      'created_by': _uid,
    });
  }

  @override
  Future<void> updateExam({
    required String examId,
    required ExamInput input,
  }) async {
    await _client.from('exams').update({
      'type': _typeValue(input.type),
      'title': input.title.trim(),
      'description': input.description?.trim().isEmpty == true
          ? null
          : input.description?.trim(),
      'exam_date': input.examDate != null
          ? DateFormat('yyyy-MM-dd').format(input.examDate!)
          : null,
      'start_time': _fmtTimeStr(input.startTime),
      'end_time': _fmtTimeStr(input.endTime),
      'room': input.room?.trim().isEmpty == true ? null : input.room?.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', examId);
  }

  @override
  Future<void> deleteExam(String examId) async {
    await _client.from('exams').update({
      'deleted_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', examId);
  }
}

final class SupabaseResourceRepository implements ResourceRepository {
  static const _bucket = 'course-resources';
  static const _signedUrlLifetimeSeconds = 60 * 60;

  static ResourceKind _kind(String? raw) => switch (raw) {
    'image' => ResourceKind.image,
    'link' => ResourceKind.link,
    _ => ResourceKind.file,
  };

  static String _kindValue(ResourceKind kind) => switch (kind) {
    ResourceKind.file => 'file',
    ResourceKind.image => 'image',
    ResourceKind.link => 'link',
  };

  @override
  Future<List<ResourceItem>> fetchResources({String? offeringId}) async {
    var query = _client
        .from('resources')
        .select(
          'id, offering_id, type, title, description, external_url, file_name, '
          'storage_path, mime_type, size_bytes, created_at, '
          'course_offerings(courses(code))',
        )
        .isFilter('deleted_at', null);
    if (offeringId != null) query = query.eq('offering_id', offeringId);
    final rows = await query.order('created_at', ascending: false).limit(50);
    return rows.map((row) {
      final offering = row['course_offerings'] as Map<String, dynamic>?;
      final course = offering?['courses'] as Map<String, dynamic>?;
      final created = row['created_at'] as String?;
      final dt = created == null ? null : DateTime.tryParse(created)?.toLocal();
      return ResourceItem(
        id: row['id'] as String,
        offeringId: (row['offering_id'] as String?) ?? '',
        title: (row['title'] as String?) ?? '',
        kind: _kind(row['type'] as String?),
        description: (row['description'] as String?) ?? '',
        courseCode: (course?['code'] as String?) ?? '',
        // Private object URLs are generated only when opened so they cannot
        // expire while a course screen is left open.
        url: (row['external_url'] as String?) ?? '',
        storagePath: (row['storage_path'] as String?) ?? '',
        fileName: (row['file_name'] as String?) ?? '',
        mimeType: (row['mime_type'] as String?) ?? '',
        sizeBytes: (row['size_bytes'] as num?)?.toInt() ?? 0,
        dateLabel: dt == null ? '' : DateFormat('MMM d').format(dt),
      );
    }).toList();
  }

  @override
  Future<String> resolveResourceUrl(ResourceItem resource) async {
    if (resource.storagePath.isEmpty) return resource.url;
    return _client.storage
        .from(_bucket)
        .createSignedUrl(resource.storagePath, _signedUrlLifetimeSeconds);
  }

  @override
  Future<void> createResource({
    required String offeringId,
    required String title,
    required String description,
    required ResourceKind kind,
    required String url,
    ResourceUpload? upload,
  }) async {
    _validateTarget(kind: kind, url: url, upload: upload, isCreate: true);
    final batchId = await _requireCurrentBatchId();
    final storagePath = upload == null
        ? null
        : await _upload(
            batchId: batchId,
            offeringId: offeringId,
            upload: upload,
          );
    try {
      await _client
          .from('resources')
          .insert({
            'batch_id': batchId,
            'offering_id': offeringId,
            'type': _kindValue(kind),
            'title': title.trim(),
            'description': description.trim().isEmpty
                ? null
                : description.trim(),
            'external_url': upload == null ? url.trim() : null,
            'storage_path': storagePath,
            'file_name': upload?.fileName,
            'mime_type': upload?.mimeType,
            'size_bytes': upload?.sizeBytes,
            'created_by': _uid,
          })
          .select('id')
          .single();
    } catch (_) {
      await _removeBestEffort(storagePath);
      rethrow;
    }
  }

  @override
  Future<void> updateResource({
    required String resourceId,
    required String title,
    required String description,
    required ResourceKind kind,
    required String url,
    ResourceUpload? upload,
    bool keepExistingUpload = false,
  }) async {
    _validateTarget(
      kind: kind,
      url: url,
      upload: upload,
      keepExistingUpload: keepExistingUpload,
    );
    final current = await _client
        .from('resources')
        .select('batch_id, offering_id, type, storage_path, updated_at')
        .eq('id', resourceId)
        .single();
    final batchId = current['batch_id'] as String;
    final offeringId = current['offering_id'] as String?;
    final oldStoragePath = (current['storage_path'] as String?) ?? '';
    final expectedUpdatedAt = current['updated_at'] as String?;
    if (offeringId == null || offeringId.isEmpty) {
      throw StateError('This resource is not assigned to a course.');
    }
    if (keepExistingUpload && oldStoragePath.isEmpty) {
      throw StateError('The original uploaded file is no longer available.');
    }
    if (keepExistingUpload && _kind(current['type'] as String?) != kind) {
      throw StateError(
        'Choose a replacement file before changing the upload type.',
      );
    }

    final newStoragePath = upload == null
        ? null
        : await _upload(
            batchId: batchId,
            offeringId: offeringId,
            upload: upload,
          );
    final changes = <String, dynamic>{
      'type': _kindValue(kind),
      'title': title.trim(),
      'description': description.trim().isEmpty ? null : description.trim(),
    };
    if (!keepExistingUpload) {
      changes.addAll({
        'external_url': upload == null ? url.trim() : null,
        'storage_path': newStoragePath,
        'file_name': upload?.fileName,
        'mime_type': upload?.mimeType,
        'size_bytes': upload?.sizeBytes,
      });
    }
    try {
      var update = _client
          .from('resources')
          .update(changes)
          .eq('id', resourceId);
      update = expectedUpdatedAt == null
          ? update.isFilter('updated_at', null)
          : update.eq('updated_at', expectedUpdatedAt);
      await update.select('id').single();
    } catch (_) {
      await _removeBestEffort(newStoragePath);
      rethrow;
    }

    if (!keepExistingUpload &&
        oldStoragePath.isNotEmpty &&
        oldStoragePath != newStoragePath) {
      await _removeBestEffort(oldStoragePath);
    }
  }

  @override
  Future<void> deleteResource(String resourceId) async {
    final current = await _client
        .from('resources')
        .select('storage_path')
        .eq('id', resourceId)
        .single();
    final storagePath = current['storage_path'] as String?;
    await _client
        .from('resources')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', resourceId)
        .select('id')
        .single();
    await _removeBestEffort(storagePath);
  }

  static void _validateTarget({
    required ResourceKind kind,
    required String url,
    ResourceUpload? upload,
    bool keepExistingUpload = false,
    bool isCreate = false,
  }) {
    final targetCount = [
      url.trim().isNotEmpty,
      upload != null,
      keepExistingUpload,
    ].where((selected) => selected).length;
    if (targetCount != 1) {
      throw ArgumentError('Choose exactly one URL or uploaded file.');
    }
    if ((upload != null || keepExistingUpload) && kind == ResourceKind.link) {
      throw ArgumentError('Uploaded resources must be files or images.');
    }
    if (upload != null &&
        (upload.sizeBytes == 0 ||
            upload.sizeBytes > ResourceUpload.maxSizeBytes)) {
      throw ArgumentError('Uploads must be between 1 byte and 25 MB.');
    }
    if (isCreate && upload == null && kind != ResourceKind.link) {
      throw ArgumentError('New file and image resources must be uploaded.');
    }
  }

  Future<String> _upload({
    required String batchId,
    required String offeringId,
    required ResourceUpload upload,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('A signed-in account is required.');
    final fileName = _safeFileName(upload.fileName);
    final nonce = Random.secure().nextInt(0x7fffffff).toRadixString(16);
    final uniqueName =
        '${DateTime.now().toUtc().microsecondsSinceEpoch}-$nonce-$fileName';
    final storagePath = '$batchId/$offeringId/$uid/$uniqueName';
    await _client.storage
        .from(_bucket)
        .uploadBinary(
          storagePath,
          upload.bytes,
          fileOptions: FileOptions(
            contentType: upload.mimeType,
            cacheControl: '3600',
          ),
        );
    return storagePath;
  }

  static String _safeFileName(String raw) {
    final leaf = raw.trim().split(RegExp(r'[/\\]')).last;
    final safe = leaf.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (safe.isEmpty || safe == '.' || safe == '..') return 'resource.bin';
    return safe.length <= 120 ? safe : safe.substring(safe.length - 120);
  }

  Future<void> _removeBestEffort(String? storagePath) async {
    if (storagePath == null || storagePath.isEmpty) return;
    try {
      await _client.storage.from(_bucket).remove([storagePath]);
    } catch (_) {
      // Metadata is authoritative. A failed cleanup must not turn a successful
      // resource mutation into a misleading client failure.
    }
  }
}

final class SupabaseBusScheduleRepository implements BusScheduleRepository {
  /// Sort key so "8:30 AM" style labels order chronologically.
  static int _minutesOf(String label) {
    final match = RegExp(
      r'(\d{1,2}):(\d{2})\s*(AM|PM)',
      caseSensitive: false,
    ).firstMatch(label);
    if (match == null) return 24 * 60; // unparsable labels sink to the end
    var h = int.parse(match.group(1)!) % 12;
    if (match.group(3)!.toUpperCase() == 'PM') h += 12;
    return h * 60 + int.parse(match.group(2)!);
  }

  @override
  Future<List<UniversityBusCategory>> fetchCategories() async {
    // One request: routes with their trips embedded via the FK relationship.
    final rows = await _client
        .from('bus_routes')
        .select(
          'id, category, name, description, manager_info, sort_order, '
          'bus_trips(departure_place, depart_time, bus_name, sort_order)',
        )
        .order('sort_order', ascending: true);

    // Categories keep the app's canonical order; unknown ones append after.
    const knownOrder = ['Student', 'Teacher', 'Staff'];
    final byCategory = <String, List<UniversityBusRoute>>{};
    for (final row in rows) {
      final trips =
          ((row['bus_trips'] as List?) ?? const []).cast<Map<String, dynamic>>()
            ..sort(
              (a, b) => ((a['sort_order'] as num?) ?? 0).compareTo(
                (b['sort_order'] as num?) ?? 0,
              ),
            );

      // Group trips into departure sections, in first-seen (seed) order.
      final sections = <String, List<BusTripItem>>{};
      for (final trip in trips) {
        final place = (trip['departure_place'] as String?) ?? '';
        if (place.isEmpty) continue;
        sections
            .putIfAbsent(place, () => [])
            .add(
              BusTripItem(
                time: (trip['depart_time'] as String?) ?? '',
                busName: (trip['bus_name'] as String?) ?? '',
              ),
            );
      }
      for (final list in sections.values) {
        list.sort((a, b) => _minutesOf(a.time).compareTo(_minutesOf(b.time)));
      }

      final category = (row['category'] as String?) ?? 'Student';
      byCategory
          .putIfAbsent(category, () => [])
          .add(
            UniversityBusRoute(
              id: row['id'] as String,
              routeName: (row['name'] as String?) ?? '',
              routeDescription: row['description'] as String?,
              managerInfo: row['manager_info'] as String?,
              departureSections: [
                for (final e in sections.entries)
                  DepartureSection(departurePlace: e.key, trips: e.value),
              ],
            ),
          );
    }

    final titles = [
      ...knownOrder.where(byCategory.containsKey),
      ...byCategory.keys.where((c) => !knownOrder.contains(c)),
    ];
    return [
      for (final title in titles)
        UniversityBusCategory(title: title, routes: byCategory[title]!),
    ];
  }
}

final class SupabaseBloodRepository implements BloodRepository {
  static BloodGroup _group(String? label) => BloodGroup.values.firstWhere(
    (g) => g.label == label,
    orElse: () => BloodGroup.oPositive,
  );

  @override
  Future<List<BloodRequest>> fetchRequests() async {
    final uid = _uid;
    final rows = await _client
        .from('blood_requests')
        .select(
          'id, requester_id, blood_group, units, contact, location, note, is_urgent, created_at',
        )
        .eq('status', 'open')
        .order('created_at', ascending: false)
        .limit(50);
    // Which of these has the signed-in user already responded to? RLS only
    // returns the user's own response rows here.
    var responded = const <String>{};
    if (uid != null && rows.isNotEmpty) {
      final mine = await _client
          .from('blood_request_responses')
          .select('request_id')
          .eq('responder_id', uid);
      responded = mine.map((r) => r['request_id'] as String).toSet();
    }
    return rows.map((row) {
      final id = row['id'] as String;
      return BloodRequest(
        id: id,
        group: _group(row['blood_group'] as String?),
        location: (row['location'] as String?) ?? '',
        time: _relativeTime(row['created_at'] as String?),
        units: (row['units'] as num?)?.toInt() ?? 1,
        contact: (row['contact'] as String?) ?? '',
        note: (row['note'] as String?) ?? '',
        isUrgent: (row['is_urgent'] as bool?) ?? false,
        isMine: uid != null && row['requester_id'] == uid,
        responded: responded.contains(id),
      );
    }).toList();
  }

  @override
  Future<BloodRequest?> fetchActiveUrgentRequest() async {
    // The view already applies is_urgent + status='open' + the 6h cutoff.
    // Oldest still-active request first; take one as the current spotlight.
    final rows = await _client
        .from('active_urgent_blood_requests')
        .select('id, requester_id, blood_group, units, contact, location, note, is_urgent, created_at')
        .order('created_at', ascending: true)
        .limit(1);
    if (rows.isEmpty) return null;
    final row = rows.first;
    final uid = _uid;
    return BloodRequest(
      id: row['id'] as String,
      group: _group(row['blood_group'] as String?),
      location: (row['location'] as String?) ?? '',
      time: _relativeTime(row['created_at'] as String?),
      units: (row['units'] as num?)?.toInt() ?? 1,
      contact: (row['contact'] as String?) ?? '',
      note: (row['note'] as String?) ?? '',
      isUrgent: (row['is_urgent'] as bool?) ?? false,
      isMine: uid != null && row['requester_id'] == uid,
    );
  }

  @override
  Future<void> createRequest({
    required BloodGroup group,
    required int units,
    required String contact,
    required String location,
    String? note,
    bool isUrgent = false,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sign in required');
    await _client.from('blood_requests').insert({
      'requester_id': uid,
      'blood_group': group.label,
      'units': units,
      'contact': contact,
      'location': location,
      if (note != null && note.isNotEmpty) 'note': note,
      'is_urgent': isUrgent,
    });
  }

  @override
  Future<void> respond(
    String requestId, {
    String? message,
    String? contact,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sign in required');
    await _client.from('blood_request_responses').insert({
      'request_id': requestId,
      'responder_id': uid,
      if (message != null && message.isNotEmpty) 'message': message,
      if (contact != null && contact.isNotEmpty) 'contact': contact,
    });
  }

  @override
  Future<List<ResponseItem>> fetchResponses(String requestId) async {
    final rows = await _client
        .from('blood_request_responses')
        .select('id, responder_id, message, contact, created_at')
        .eq('request_id', requestId)
        .order('created_at', ascending: false);
    return _withResponderNames(rows);
  }

  @override
  Future<void> markFulfilled(String requestId) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sign in required');
    // RLS restricts the update to the request's owner (or a super admin).
    await _client
        .from('blood_requests')
        .update({
          'status': 'fulfilled',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', requestId);
  }
}

final class SupabaseLostFoundRepository implements LostFoundRepository {
  static IconData _iconFor(String title) {
    final t = title.toLowerCase();
    if (t.contains('wallet')) return Icons.account_balance_wallet_rounded;
    if (t.contains('watch')) return Icons.watch_rounded;
    if (t.contains('key')) return Icons.key_rounded;
    if (t.contains('card') || t.contains('id')) return Icons.badge_rounded;
    if (t.contains('bag') || t.contains('backpack')) {
      return Icons.backpack_rounded;
    }
    if (t.contains('phone')) return Icons.smartphone_rounded;
    if (t.contains('book')) return Icons.menu_book_rounded;
    if (t.contains('calculator')) return Icons.calculate_rounded;
    if (t.contains('umbrella')) return Icons.umbrella_rounded;
    if (t.contains('laptop')) return Icons.laptop_rounded;
    return Icons.inventory_2_rounded;
  }

  @override
  Future<List<LostFoundItem>> fetchItems() async {
    final uid = _uid;
    final rows = await _client
        .from('lost_found_items')
        .select(
          'id, reporter_id, type, title, description, location, created_at',
        )
        .eq('status', 'open')
        .order('created_at', ascending: false)
        .limit(50);
    var responded = const <String>{};
    if (uid != null && rows.isNotEmpty) {
      final mine = await _client
          .from('lost_found_responses')
          .select('item_id')
          .eq('responder_id', uid);
      responded = mine.map((r) => r['item_id'] as String).toSet();
    }
    return rows.map((row) {
      final id = row['id'] as String;
      final title = (row['title'] as String?) ?? '';
      return LostFoundItem(
        id: id,
        title: title,
        description: (row['description'] as String?) ?? '',
        location: (row['location'] as String?) ?? '',
        time: _relativeTime(row['created_at'] as String?),
        isLost: row['type'] == 'lost',
        icon: _iconFor(title),
        isMine: uid != null && row['reporter_id'] == uid,
        responded: responded.contains(id),
      );
    }).toList();
  }

  @override
  Future<void> report({
    required bool isLost,
    required String title,
    required String description,
    required String location,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sign in required');
    await _client.from('lost_found_items').insert({
      'reporter_id': uid,
      'type': isLost ? 'lost' : 'found',
      'title': title,
      'description': description,
      'location': location,
    });
  }

  @override
  Future<void> respond(
    String itemId, {
    String? message,
    String? contact,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sign in required');
    await _client.from('lost_found_responses').insert({
      'item_id': itemId,
      'responder_id': uid,
      if (message != null && message.isNotEmpty) 'message': message,
      if (contact != null && contact.isNotEmpty) 'contact': contact,
    });
  }

  @override
  Future<List<ResponseItem>> fetchResponses(String itemId) async {
    final rows = await _client
        .from('lost_found_responses')
        .select('id, responder_id, message, contact, created_at')
        .eq('item_id', itemId)
        .order('created_at', ascending: false);
    return _withResponderNames(rows);
  }
}

/// Resolve responder display names through the people directory (profiles
/// themselves are not readable across students).
Future<List<ResponseItem>> _withResponderNames(
  List<Map<String, dynamic>> rows,
) async {
  if (rows.isEmpty) return const [];
  final ids = rows.map((r) => r['responder_id'] as String).toSet().toList();
  var names = const <String, String>{};
  try {
    final people = await _client
        .from('people_directory')
        .select('id, full_name')
        .inFilter('id', ids);
    names = {
      for (final p in people)
        p['id'] as String: (p['full_name'] as String?) ?? '',
    };
  } catch (_) {
    // Names are cosmetic; keep responses usable even if the lookup fails.
  }
  return rows
      .map(
        (row) => ResponseItem(
          id: row['id'] as String,
          responderName: names[row['responder_id']] ?? 'A student',
          message: (row['message'] as String?) ?? '',
          contact: (row['contact'] as String?) ?? '',
          time: _relativeTime(row['created_at'] as String?),
        ),
      )
      .toList();
}
