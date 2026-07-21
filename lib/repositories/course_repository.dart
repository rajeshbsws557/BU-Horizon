import 'package:injectable/injectable.dart';

import '../models/course_offering.dart';

/// Batch-scoped course catalog shared by notices, resources and attendance.
abstract interface class CourseRepository {
  Future<List<CourseOffering>> fetchCourses();

  Future<void> createCourse(CourseInput input);

  Future<void> updateCourse(String offeringId, CourseInput input);

  Future<void> deleteCourse(String offeringId);
}

@LazySingleton(as: CourseRepository)
final class SampleCourseRepository implements CourseRepository {
  final List<CourseOffering> _courses = [
    const CourseOffering(
      id: 'offering-cse-1101',
      courseId: 'course-cse-1101',
      batchId: 'sample-batch',
      code: 'CSE-1101',
      title: 'Computer Fundamentals and Programming',
      creditHours: 3,
      termNumber: 1,
      teacherName: 'Dr. Farhana Rahman',
    ),
    const CourseOffering(
      id: 'offering-cse-1102',
      courseId: 'course-cse-1102',
      batchId: 'sample-batch',
      code: 'CSE-1102',
      title: 'Discrete Mathematics',
      creditHours: 3,
      termNumber: 1,
      teacherName: 'Md. Rakibul Islam',
    ),
    const CourseOffering(
      id: 'offering-math-1101',
      courseId: 'course-math-1101',
      batchId: 'sample-batch',
      code: 'MATH-1101',
      title: 'Differential and Integral Calculus',
      creditHours: 3,
      termNumber: 1,
      teacherName: 'Dr. Nusrat Jahan',
    ),
  ];
  int _nextId = 1;

  @override
  Future<List<CourseOffering>> fetchCourses() async =>
      List.unmodifiable(_courses);

  @override
  Future<void> createCourse(CourseInput input) async {
    final suffix = _nextId++;
    _courses.add(
      CourseOffering(
        id: 'sample-offering-$suffix',
        courseId: 'sample-course-$suffix',
        batchId: 'sample-batch',
        code: input.code,
        title: input.title,
        creditHours: input.creditHours,
        termNumber: input.termNumber,
        teacherName: input.teacherName,
      ),
    );
  }

  @override
  Future<void> updateCourse(String offeringId, CourseInput input) async {
    final index = _courses.indexWhere((course) => course.id == offeringId);
    if (index == -1) return;
    final current = _courses[index];
    _courses[index] = CourseOffering(
      id: current.id,
      courseId: current.courseId,
      batchId: current.batchId,
      code: input.code,
      title: input.title,
      creditHours: input.creditHours,
      termNumber: input.termNumber,
      teacherName: input.teacherName,
    );
  }

  @override
  Future<void> deleteCourse(String offeringId) async {
    _courses.removeWhere((course) => course.id == offeringId);
  }
}
