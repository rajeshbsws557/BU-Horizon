import 'package:bu_horizon/repositories/attendance_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SampleAttendanceRepository', () {
    late SampleAttendanceRepository repository;

    setUp(() => repository = SampleAttendanceRepository());

    test('returns the signed-in student summary and course sessions', () async {
      final summary = await repository.fetchCourseSummary('offering-cse-1101');
      final sessions = await repository.fetchCourseSessions(
        'offering-cse-1101',
      );

      expect(summary.present, 1);
      expect(summary.total, 2);
      expect(summary.percentage, .5);
      expect(sessions, hasLength(2));
      expect(sessions.first.date.isAfter(sessions.last.date), isTrue);
      expect(
        sessions.map((session) => session.status),
        containsAll(AttendanceMark.values),
      );
    });

    test('creates a complete session from the batch roster', () async {
      final roster = await repository.fetchSessionRoster(
        offeringId: 'offering-cse-1101',
      );
      final id = await repository.saveSession(
        AttendanceSessionDraft(
          offeringId: 'offering-cse-1101',
          date: DateTime(2026, 7, 22),
          startTime: '10:00',
          endTime: '11:00',
          topic: '  Recursion  ',
          records: {
            for (final member in roster)
              member.profileId: AttendanceMark.present,
          },
        ),
      );

      final sessions = await repository.fetchCourseSessions(
        'offering-cse-1101',
      );
      final created = sessions.singleWhere((session) => session.id == id);
      expect(created.topic, 'Recursion');
      expect(created.status, AttendanceMark.present);
      expect(created.presentCount, roster.length);
      expect(created.recordCount, roster.length);
    });

    test('updates a session and exposes saved marks to the roster', () async {
      final roster = await repository.fetchSessionRoster(
        offeringId: 'offering-cse-1101',
        sessionId: 'sample-session-1',
      );
      await repository.saveSession(
        AttendanceSessionDraft(
          offeringId: 'offering-cse-1101',
          sessionId: 'sample-session-1',
          date: DateTime(2026, 7, 21),
          topic: 'Updated topic',
          records: {
            for (final member in roster)
              member.profileId: AttendanceMark.absent,
          },
        ),
      );

      final updatedRoster = await repository.fetchSessionRoster(
        offeringId: 'offering-cse-1101',
        sessionId: 'sample-session-1',
      );
      final sessions = await repository.fetchCourseSessions(
        'offering-cse-1101',
      );
      expect(
        updatedRoster.every((member) => member.status == AttendanceMark.absent),
        isTrue,
      );
      expect(
        sessions
            .singleWhere((session) => session.id == 'sample-session-1')
            .topic,
        'Updated topic',
      );
    });

    test('deletes only the selected session', () async {
      await repository.deleteSession('sample-session-1');

      final selected = await repository.fetchCourseSessions(
        'offering-cse-1101',
      );
      final other = await repository.fetchCourseSessions('offering-cse-1102');
      expect(
        selected.map((session) => session.id),
        isNot(contains('sample-session-1')),
      );
      expect(other, isNotEmpty);
    });

    test('rejects attendance for a profile outside the batch roster', () async {
      expect(
        () => repository.saveSession(
          AttendanceSessionDraft(
            offeringId: 'offering-cse-1101',
            date: DateTime(2026, 7, 22),
            records: const {
              'student-from-another-batch': AttendanceMark.present,
            },
          ),
        ),
        throwsArgumentError,
      );
    });
  });
}
