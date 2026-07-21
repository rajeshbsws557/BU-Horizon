import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

/// Thrown for auth problems we want to surface to the user with a clean message.
class AuthFailure implements Exception {
  final String message;
  const AuthFailure(this.message);
  @override
  String toString() => message;
}

/// Wraps Supabase Auth for the registration/login flows.
///
/// Registration sends the identity metadata (poll Q20) that the database's
/// `handle_new_user` trigger reads to populate `public.profiles`. Login accepts
/// either a university email or a Student ID (poll Q22): a Student ID is first
/// resolved to its account email through the `resolve_login_email` RPC.
class AuthService {
  SupabaseClient get _client {
    if (!SupabaseConfig.isConfigured) {
      throw const AuthFailure(
        'Supabase is not configured. Run with --dart-define=SUPABASE_URL=... '
        'and --dart-define=SUPABASE_ANON_KEY=...',
      );
    }
    return Supabase.instance.client;
  }

  GoTrueClient get _auth => _client.auth;

  Session? get currentSession => _auth.currentSession;
  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => currentSession != null;

  /// Emits on sign-in, sign-out, token refresh, etc.
  Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  /// Registers a new student. Auto-approved server-side (poll Q19); the profile
  /// row is created by the `handle_new_user` trigger from this metadata.
  Future<AuthResponse> signUp({
    required String fullName,
    required String email,
    required String password,
    required String studentId,
    String? roll,
    String? phone,
    String? facultyId,
    String? departmentId,
    String? batchId,
  }) async {
    try {
      return await _auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'student_id': studentId,
          if (roll != null && roll.isNotEmpty) 'roll': roll,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
          if (facultyId != null) 'faculty_id': facultyId,
          if (departmentId != null) 'department_id': departmentId,
          if (batchId != null) 'batch_id': batchId,
        },
      );
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  /// Signs in with an email or Student ID (poll Q22) plus password.
  Future<AuthResponse> signIn({
    required String identifier,
    required String password,
  }) async {
    final email = await _resolveEmail(identifier.trim());
    if (email == null) {
      throw const AuthFailure('No active account found for that email or Student ID.');
    }
    try {
      return await _auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  /// If the identifier already looks like an email, use it directly; otherwise
  /// resolve the Student ID to its account email via the RPC.
  Future<String?> _resolveEmail(String identifier) async {
    if (identifier.contains('@')) return identifier.toLowerCase();
    try {
      final result = await _client.rpc(
        'resolve_login_email',
        params: {'identifier': identifier},
      );
      return result as String?;
    } on PostgrestException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  /// Password recovery by email OTP / link (poll Q23).
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.resetPasswordForEmail(email.trim().toLowerCase());
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  Future<void> signOut() => _auth.signOut();
}
