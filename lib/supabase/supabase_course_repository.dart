import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/course_offering.dart';
import '../repositories/course_repository.dart';

/// Supabase-backed batch course catalog.
///
/// Reads are explicitly limited to the signed-in profile's batch in addition
/// to the database RLS policy. Writes use atomic RPCs because a CR edits both
/// the reusable `courses` row and their batch's `course_offerings` row.
final class SupabaseCourseRepository implements CourseRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Future<String> _requireCurrentBatchId() async {
    final uid = _client.auth.currentUser?.id;
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

  @override
  Future<List<CourseOffering>> fetchCourses() async {
    final batchId = await _requireCurrentBatchId();
    final rows = await _client
        .from('course_offerings')
        .select(
          'id, course_id, batch_id, term_number, teacher_name, '
          'courses!inner(id, code, title, credit_hours)',
        )
        .eq('batch_id', batchId)
        .isFilter('deleted_at', null)
        .order('term_number', ascending: true);

    final courses = rows.map((row) {
      final course = row['courses'] as Map<String, dynamic>;
      return CourseOffering(
        id: row['id'] as String,
        courseId: (row['course_id'] as String?) ??
            (course['id'] as String?) ??
            '',
        batchId: (row['batch_id'] as String?) ?? batchId,
        code: (course['code'] as String?) ?? '',
        title: (course['title'] as String?) ?? '',
        creditHours: (course['credit_hours'] as num?)?.toDouble(),
        termNumber: row['term_number'] as int?,
        teacherName: (row['teacher_name'] as String?) ?? '',
      );
    }).toList();
    courses.sort((a, b) {
      final term = (a.termNumber ?? 0).compareTo(b.termNumber ?? 0);
      return term != 0 ? term : a.code.compareTo(b.code);
    });
    return courses;
  }

  Map<String, dynamic> _inputParams(CourseInput input) => {
        'p_code': input.code.trim().toUpperCase(),
        'p_title': input.title.trim(),
        'p_credit_hours': input.creditHours,
        'p_term_number': input.termNumber,
        'p_teacher_name': input.teacherName.trim().isEmpty
            ? null
            : input.teacherName.trim(),
        'p_title_bn': null,
      };

  @override
  Future<void> createCourse(CourseInput input) async {
    await _client.rpc('create_batch_course', params: _inputParams(input));
  }

  @override
  Future<void> updateCourse(String offeringId, CourseInput input) async {
    await _client.rpc(
      'update_batch_course',
      params: {
        'p_offering_id': offeringId,
        ..._inputParams(input),
      },
    );
  }

  @override
  Future<void> deleteCourse(String offeringId) async {
    await _client.rpc(
      'delete_batch_course',
      params: {'p_offering_id': offeringId},
    );
  }
}
