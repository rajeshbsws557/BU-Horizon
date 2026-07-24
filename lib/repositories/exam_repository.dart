import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';

import '../models/models.dart';

/// Input parameters for creating or updating an exam notice.
typedef ExamInput = ({
  String title,
  String type,
  DateTime? examDate,
  TimeOfDay? startTime,
  TimeOfDay? endTime,
  String? room,
  String? description,
});

/// Repository for the signed-in student's batch exam schedule.
abstract interface class ExamRepository {
  Future<List<ExamItem>> fetchExams();

  /// Returns exams scoped to a single course offering.
  Future<List<ExamItem>> fetchCourseExams(String offeringId);

  Future<void> createExam({
    required String offeringId,
    required ExamInput input,
  });

  Future<void> updateExam({
    required String examId,
    required ExamInput input,
  });

  Future<void> deleteExam(String examId);
}

@Injectable(as: ExamRepository)
final class SampleExamRepository implements ExamRepository {
  final List<ExamItem> _all = [
    const ExamItem(
      id: '1',
      offeringId: 'offering-cse-1101',
      title: 'Quiz 1 — Structured Programming',
      typeLabel: 'Quiz',
      dateLabel: 'Mon, Jul 27',
      timeLabel: '10:00 AM – 10:45 AM',
      courseCode: 'CSE-1101',
      room: '301',
    ),
    const ExamItem(
      id: '2',
      offeringId: 'offering-cse-1102',
      title: 'Midterm — Discrete Mathematics',
      typeLabel: 'Midterm',
      dateLabel: 'Sun, Aug 2',
      timeLabel: '9:30 AM – 11:00 AM',
      courseCode: 'CSE-1102',
      room: '204',
    ),
  ];
  int _nextId = 10;

  @override
  Future<List<ExamItem>> fetchExams() async => List.unmodifiable(_all);

  @override
  Future<List<ExamItem>> fetchCourseExams(String offeringId) async =>
      _all.where((exam) => exam.offeringId == offeringId).toList();

  static String _formatType(String raw) => switch (raw.toLowerCase()) {
    'midterm' => 'Midterm',
    'final' => 'Final',
    'quiz' => 'Quiz',
    _ => 'Exam',
  };

  static String _formatTime(TimeOfDay? time) {
    if (time == null) return '';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    final min = time.minute.toString().padLeft(2, '0');
    return '$hour:$min $period';
  }

  @override
  Future<void> createExam({
    required String offeringId,
    required ExamInput input,
  }) async {
    final start = _formatTime(input.startTime);
    final end = _formatTime(input.endTime);
    _all.insert(
      0,
      ExamItem(
        id: 'sample-exam-${_nextId++}',
        offeringId: offeringId,
        title: input.title.trim(),
        typeLabel: _formatType(input.type),
        dateLabel: input.examDate != null
            ? '${input.examDate!.month}/${input.examDate!.day}'
            : 'TBD',
        timeLabel: [start, end].where((s) => s.isNotEmpty).join(' – '),
        room: input.room?.trim() ?? '',
        description: input.description?.trim() ?? '',
      ),
    );
  }

  @override
  Future<void> updateExam({
    required String examId,
    required ExamInput input,
  }) async {
    final index = _all.indexWhere((exam) => exam.id == examId);
    if (index == -1) return;
    final start = _formatTime(input.startTime);
    final end = _formatTime(input.endTime);
    _all[index] = _all[index].copyWith(
      title: input.title.trim(),
      typeLabel: _formatType(input.type),
      dateLabel: input.examDate != null
          ? '${input.examDate!.month}/${input.examDate!.day}'
          : _all[index].dateLabel,
      timeLabel: [start, end].where((s) => s.isNotEmpty).join(' – '),
      room: input.room?.trim() ?? '',
      description: input.description?.trim() ?? '',
    );
  }

  @override
  Future<void> deleteExam(String examId) async {
    _all.removeWhere((exam) => exam.id == examId);
  }
}

