import 'package:flutter/foundation.dart';

/// A course as it is offered to the signed-in student's batch.
///
/// The [id] is the `course_offerings.id`, not the reusable catalog course ID.
/// Course-scoped features (notices, resources, attendance) must use this ID.
@immutable
class CourseOffering {
  final String id;
  final String courseId;
  final String batchId;
  final String code;
  final String title;
  final double? creditHours;
  final int? termNumber;
  final String teacherName;

  const CourseOffering({
    required this.id,
    required this.courseId,
    required this.batchId,
    required this.code,
    required this.title,
    this.creditHours,
    this.termNumber,
    this.teacherName = '',
  });

  CourseOffering copyWith({
    String? id,
    String? courseId,
    String? batchId,
    String? code,
    String? title,
    double? creditHours,
    int? termNumber,
    String? teacherName,
  }) {
    return CourseOffering(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      batchId: batchId ?? this.batchId,
      code: code ?? this.code,
      title: title ?? this.title,
      creditHours: creditHours ?? this.creditHours,
      termNumber: termNumber ?? this.termNumber,
      teacherName: teacherName ?? this.teacherName,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CourseOffering &&
            other.id == id &&
            other.courseId == courseId &&
            other.batchId == batchId &&
            other.code == code &&
            other.title == title &&
            other.creditHours == creditHours &&
            other.termNumber == termNumber &&
            other.teacherName == teacherName;
  }

  @override
  int get hashCode => Object.hash(
        id,
        courseId,
        batchId,
        code,
        title,
        creditHours,
        termNumber,
        teacherName,
      );
}

/// Editable course fields accepted by the atomic batch-course RPCs.
@immutable
class CourseInput {
  final String code;
  final String title;
  final double? creditHours;
  final int? termNumber;
  final String teacherName;

  const CourseInput({
    required this.code,
    required this.title,
    this.creditHours,
    this.termNumber,
    this.teacherName = '',
  });
}
