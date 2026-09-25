import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/local_store.dart';
import '../di/di.dart';
import 'auth_service.dart';
import 'supabase_config.dart';

typedef _ProfileFetcher = Future<Map<String, dynamic>?> Function(String userId);
typedef _ProfileChanges = Stream<void> Function(String userId);

/// The current user's profile as shown around the app (name/id/email/dept).
@immutable
class CurrentProfile {
  final String id;
  final String fullName;
  final String email;
  final String? studentId;
  final String? departmentName;
  final String? batchId;
  final int? currentTerm;
  final String? batchStatus;
  final String role;

  /// Account lifecycle status: 'active', 'pending_verification', 'suspended',
  /// 'archived', 'deleted'. Provisional students awaiting approval are
  /// 'pending_verification'.
  final String status;

  /// True when the student registered without a @bu.ac.bd email and their
  /// identity is gated by admin/CR approval rather than the email domain.
  final bool isProvisional;

  /// The verified @bu.ac.bd address, once issued and confirmed. Null while the
  /// account is still provisional.
  final String? universityEmail;


  /// The program's academic system: 'semester' or 'yearly' (poll Q2/Q3).
  /// Drives whether the app labels a term as a "Semester" or a "Year".
  final String? academicSystem;

  /// Total number of terms in the program (e.g. 8 semesters, 4 years). Used to
  /// know when advancing the batch will graduate it instead of moving a term.
  final int? totalTerms;

  const CurrentProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.status = 'active',
    this.isProvisional = false,
    this.universityEmail,
    this.studentId,
    this.departmentName,
    this.batchId,
    this.currentTerm,
    this.batchStatus,
    this.academicSystem,
    this.totalTerms,
  });


  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  /// Singular label for one term in this program: 'Year' for yearly programs,
  /// otherwise 'Semester'. Safe default keeps older data reading as semesters.
  String get termLabel =>
      academicSystem == 'yearly' ? 'Year' : 'Semester';

  /// True when the batch is on its final term, so the next advance graduates it
  /// rather than moving to another term.
  bool get isFinalTerm =>
      totalTerms != null && currentTerm != null && currentTerm! >= totalTerms!;

  /// True when the batch has already graduated (no further advances allowed).
  bool get hasGraduated => batchStatus == 'graduated';

  /// True when the account is awaiting admin/CR approval of its identity.
  bool get isPendingVerification => status == 'pending_verification';

  /// True when the account is fully verified (has a confirmed @bu.ac.bd email
  /// and is no longer provisional).
  bool get isVerified => !isProvisional && universityEmail != null;
}



/// App-wide session state. Replaces the old `SampleData.isLoggedIn` notifier.
/// Listens to Supabase auth changes and keeps the current profile loaded so the
/// UI can react to sign-in / sign-out. Safe to construct even when Supabase is
/// not configured — it simply stays signed-out.
class SessionController extends ChangeNotifier {
  SessionController(
    this._auth, {
    @visibleForTesting
    Future<Map<String, dynamic>?> Function(String userId)? profileFetcher,
    @visibleForTesting Stream<void> Function(String userId)? profileChanges,
  }) : _profileFetcher = profileFetcher ?? _fetchProfile,
       _profileChanges = profileChanges ?? _watchProfile,
       _isAvailable =
           SupabaseConfig.isConfigured ||
           profileFetcher != null ||
           profileChanges != null {
    if (_isAvailable) {
      _sub = _auth.onAuthStateChange.listen((state) {
        if (state.session == null) {
          _clearProfile();
        } else {
          _activateUser(state.session!.user.id);
        }
      });
      final user = _auth.currentUser;
      if (user != null) _activateUser(user.id);
    }
  }

  final AuthService _auth;
  final _ProfileFetcher _profileFetcher;
  final _ProfileChanges _profileChanges;
  final bool _isAvailable;
  StreamSubscription<AuthState>? _sub;
  StreamSubscription<void>? _profileSub;
  String? _watchedProfileId;
  int _profileRequest = 0;
  bool _disposed = false;

  CurrentProfile? _profile;
  CurrentProfile? get profile => _profile;

  bool get isSignedIn => _isAvailable && _auth.isSignedIn;

  void _activateUser(String userId) {
    if (_watchedProfileId != userId) {
      // Never carry one account's profile (and therefore its role controls)
      // into another account while the replacement profile is loading.
      ++_profileRequest;
      if (_profile != null && _profile?.id != userId) {
        _profile = null;
        if (!_disposed) notifyListeners();
      }
      final oldSubscription = _profileSub;
      _profileSub = null;
      _watchedProfileId = userId;
      if (oldSubscription != null) unawaited(oldSubscription.cancel());

      try {
        _profileSub = _profileChanges(userId).listen(
          (_) {
            if (!_disposed && _auth.currentUser?.id == userId) {
              unawaited(_loadProfile(expectedUserId: userId));
            }
          },
          // A dropped realtime channel must not affect the auth session. It
          // reconnects itself, and auth events/manual refresh remain fallbacks.
          onError: (_) {},
        );
      } catch (_) {
        // Loading the profile still works if realtime is temporarily
        // unavailable.
      }
    }
    unawaited(_loadProfile(expectedUserId: userId));
  }

  Future<void> _loadProfile({String? expectedUserId}) async {
    final user = _auth.currentUser;
    if (user == null || (expectedUserId != null && expectedUserId != user.id)) {
      return;
    }
    final userId = user.id;
    final request = ++_profileRequest;
    try {
      final row = await _profileFetcher(userId);
      if (_disposed ||
          request != _profileRequest ||
          _auth.currentUser?.id != userId) {
        return;
      }

      final dept = row?['departments'] as Map<String, dynamic>?;
      final batch = row?['batches'] as Map<String, dynamic>?;
      final program = batch?['programs'] as Map<String, dynamic>?;
      _profile = row == null
          ? null
          : CurrentProfile(
              id: row['id'] as String,
              fullName: (row['full_name'] as String?) ?? '',
              email: (row['email'] as String?) ?? user.email ?? '',
              studentId: row['student_id'] as String?,
              role: (row['role'] as String?) ?? 'student',
              status: (row['status'] as String?) ?? 'active',
              isProvisional: (row['is_provisional'] as bool?) ?? false,
              universityEmail: row['university_email'] as String?,
              batchId: row['batch_id'] as String?,

              // The student's own current_term is the display value;
              // advance_batch() updates it alongside batches.current_term.
              // Fall back to the batch for profiles that predate the column.
              currentTerm:
                  (row['current_term'] as int?) ?? batch?['current_term'] as int?,
              batchStatus: batch?['status'] as String?,
              departmentName: dept?['name'] as String?,
              academicSystem: (row['academic_system'] as String?) ??
                  program?['academic_system'] as String?,
              totalTerms: program?['total_terms'] as int?,

            );
      notifyListeners();

    } catch (_) {
      // Non-fatal: keep the session but leave profile details empty.
    }
  }

  Future<void> refresh() => _loadProfile();

  void _clearProfile() {
    ++_profileRequest;
    _watchedProfileId = null;
    final profileSubscription = _profileSub;
    _profileSub = null;
    if (profileSubscription != null) {
      unawaited(profileSubscription.cancel());
    }
    _profile = null;
    if (!_disposed) notifyListeners();
  }

  static Future<Map<String, dynamic>?> _fetchProfile(String userId) {
    return Supabase.instance.client
        .from('profiles')
        .select(
          'id, full_name, email, student_id, role, status, is_provisional, university_email, batch_id, academic_system, current_term, departments(name), batches(current_term, status, programs(academic_system, total_terms))',
        )



        .eq('id', userId)
        .maybeSingle();
  }

  static Stream<void> _watchProfile(String userId) {
    final client = Supabase.instance.client;
    RealtimeChannel? channel;
    // The controller intentionally lives for exactly as long as its sole
    // subscription; cancellation removes the underlying Realtime channel.
    // ignore: close_sinks
    late final StreamController<void> changes;
    changes = StreamController<void>(
      onListen: () {
        channel = client
            .channel('own-profile:$userId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'profiles',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'id',
                value: userId,
              ),
              callback: (_) => changes.add(null),
            )
            .subscribe();
      },
      onCancel: () async {
        final currentChannel = channel;
        if (currentChannel != null) {
          await client.removeChannel(currentChannel);
        }
      },
    );
    return changes.stream;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _clearProfile();
    // Drop cached backend reads so the next account on this device never sees
    // the previous user's offline data. Settings (theme) are preserved.
    if (getIt.isRegistered<LocalStore>()) {
      unawaited(getIt<LocalStore>().clearCache());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_profileRequest;
    _sub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}
