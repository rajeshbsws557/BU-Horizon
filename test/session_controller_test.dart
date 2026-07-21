import 'dart:async';

import 'package:bu_horizon/supabase/auth_service.dart';
import 'package:bu_horizon/supabase/session_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockAuthService extends Mock implements AuthService {}

const _user = User(
  id: 'student-1',
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  email: 'student@example.com',
  createdAt: '2026-07-22T00:00:00Z',
);

Map<String, dynamic> _profileRow(String role) => {
  'id': _user.id,
  'full_name': 'Student One',
  'email': _user.email,
  'student_id': 'BU-001',
  'role': role,
  'batch_id': 'batch-1',
  'departments': {'name': 'Computer Science'},
};

void main() {
  group('SessionController profile changes', () {
    late _MockAuthService auth;
    late StreamController<AuthState> authChanges;
    late StreamController<void> profileChanges;
    User? currentUser;

    setUp(() {
      auth = _MockAuthService();
      authChanges = StreamController<AuthState>.broadcast();
      profileChanges = StreamController<void>.broadcast();
      currentUser = _user;
      when(() => auth.onAuthStateChange).thenAnswer((_) => authChanges.stream);
      when(() => auth.currentUser).thenAnswer((_) => currentUser);
      when(() => auth.isSignedIn).thenAnswer((_) => currentUser != null);
    });

    tearDown(() async {
      await authChanges.close();
      await profileChanges.close();
    });

    test(
      'reloads the current profile when its realtime event arrives',
      () async {
        var role = 'student';
        var fetchCount = 0;
        final controller = SessionController(
          auth,
          profileFetcher: (_) async {
            fetchCount++;
            return _profileRow(role);
          },
          profileChanges: (_) => profileChanges.stream,
        );
        addTearDown(controller.dispose);

        await pumpEventQueue();
        expect(controller.profile?.role, 'student');

        role = 'cr';
        profileChanges.add(null);
        await pumpEventQueue();

        expect(controller.profile?.role, 'cr');
        expect(fetchCount, 2);
      },
    );

    test('does not apply an in-flight profile after sign-out', () async {
      final pendingProfile = Completer<Map<String, dynamic>?>();
      final controller = SessionController(
        auth,
        profileFetcher: (_) => pendingProfile.future,
        profileChanges: (_) => profileChanges.stream,
      );
      addTearDown(controller.dispose);

      currentUser = null;
      authChanges.add(const AuthState(AuthChangeEvent.signedOut, null));
      await pumpEventQueue();

      pendingProfile.complete(_profileRow('cr'));
      await pumpEventQueue();

      expect(controller.profile, isNull);
      expect(controller.isSignedIn, isFalse);
    });
  });
}
