import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final String role;

  const CurrentProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.studentId,
    this.departmentName,
    this.batchId,
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
      _profile = row == null
          ? null
          : CurrentProfile(
              id: row['id'] as String,
              fullName: (row['full_name'] as String?) ?? '',
              email: (row['email'] as String?) ?? user.email ?? '',
              studentId: row['student_id'] as String?,
              role: (row['role'] as String?) ?? 'student',
              batchId: row['batch_id'] as String?,
              departmentName: dept?['name'] as String?,
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
          'id, full_name, email, student_id, role, batch_id, departments(name)',
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
