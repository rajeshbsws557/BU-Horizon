import 'package:injectable/injectable.dart';

import '../models/models.dart';

/// Repository for the signed-in student's batch exam schedule.
abstract interface class ExamRepository {
  Future<List<ExamItem>> fetchExams();
}

@Injectable(as: ExamRepository)
final class SampleExamRepository implements ExamRepository {
  @override
  Future<List<ExamItem>> fetchExams() async => const [
        ExamItem(
          id: '1',
          title: 'Quiz 1 — Structured Programming',
          typeLabel: 'Quiz',
          dateLabel: 'Mon, Jul 27',
          timeLabel: '10:00 AM – 10:45 AM',
          courseCode: 'CSE-1101',
          room: '301',
        ),
        ExamItem(
          id: '2',
          title: 'Midterm — Discrete Mathematics',
          typeLabel: 'Midterm',
          dateLabel: 'Sun, Aug 2',
          timeLabel: '9:30 AM – 11:00 AM',
          courseCode: 'CSE-1102',
          room: '204',
        ),
      ];
}
