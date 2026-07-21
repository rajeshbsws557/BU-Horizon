import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

/// A faculty option for the registration dropdown.
class FacultyOption {
  final String id;
  final String name;
  const FacultyOption({required this.id, required this.name});
}

/// A department option, tied to its faculty so the second dropdown can filter.
class DepartmentOption {
  final String id;
  final String facultyId;
  final String name;
  final String code;
  const DepartmentOption({
    required this.id,
    required this.facultyId,
    required this.name,
    required this.code,
  });
}

/// Reads the academic reference tables (readable university-wide) so the
/// registration form can offer real Faculty/Department choices (poll Q20) and
/// resolve the student's batch from department + session before sign-up.
class ReferenceDataService {
  SupabaseClient get _client {
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Supabase is not configured.');
    }
    return Supabase.instance.client;
  }

  Future<List<FacultyOption>> faculties() async {
    final rows = await _client.from('faculties').select('id, name').order('name');
    return rows
        .map((r) => FacultyOption(id: r['id'] as String, name: r['name'] as String))
        .toList();
  }

  Future<List<DepartmentOption>> departments() async {
    final rows = await _client
        .from('departments')
        .select('id, faculty_id, name, code')
        .order('name');
    return rows
        .map((r) => DepartmentOption(
              id: r['id'] as String,
              facultyId: r['faculty_id'] as String,
              name: r['name'] as String,
              code: r['code'] as String,
            ))
        .toList();
  }

  /// Resolves the batch id for a department + session (e.g. '2025-26').
  /// Returns null when no batch exists yet for that pairing.
  Future<String?> resolveBatchId({
    required String departmentId,
    required String session,
  }) async {
    final row = await _client
        .from('batches')
        .select('id, programs!inner(department_id)')
        .eq('session', session)
        .eq('programs.department_id', departmentId)
        .maybeSingle();
    return row == null ? null : row['id'] as String?;
  }
}
