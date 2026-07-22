import 'dart:async';

import 'package:cohort_platform/features/auth/controllers/auth_controller.dart';
import 'package:cohort_platform/features/auth/models/auth_view_state.dart';
import 'package:cohort_platform/features/auth/models/user_profile.dart';
import 'package:cohort_platform/features/auth/screens/auth_gate.dart';
import 'package:cohort_platform/features/auth/screens/login_screen.dart';
import 'package:cohort_platform/features/auth/services/auth_session_port.dart';
import 'package:cohort_platform/features/auth/services/current_user_session.dart';
import 'package:cohort_platform/features/auth/services/profile_provisioning_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/counting_profile_repository.dart';

class SignInTransitionAuthPort implements AuthSessionPort {
  SignInTransitionAuthPort();

  Session? session;
  User? user;
  int signInCallCount = 0;
  final _controller = StreamController<AuthState>.broadcast();

  void emitSignedIn({
    required String userId,
    required String email,
  }) {
    user = User(
      id: userId,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: email,
    );
    session = Session(
      accessToken: 'token',
      tokenType: 'bearer',
      user: user!,
      refreshToken: 'refresh',
    );
    _controller.add(AuthState(AuthChangeEvent.signedIn, session));
  }

  @override
  Session? get currentSession => session;

  @override
  User? get currentUser => user;

  @override
  Stream<AuthState> get authStateChanges => _controller.stream;

  @override
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    signInCallCount++;
    emitSignedIn(userId: 'user-123', email: email.trim());
    return AuthResponse(session: session, user: user);
  }

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? displayName,
    Set<String>? roleNames,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> resendSignupVerification({required String email}) async {}

  @override
  Future<void> signOut() async {
    session = null;
    user = null;
    _controller.add(const AuthState(AuthChangeEvent.signedOut, null));
  }

  @override
  Future<void> resetPassword({required String email}) async {}
}

class DelayedProfileRepository extends CountingProfileRepository {
  DelayedProfileRepository({super.seed, this.loadDelay = Duration.zero});

  final Duration loadDelay;

  @override
  Future<UserProfile?> getProfile(String userId) async {
    getProfileCallCount++;
    if (loadDelay > Duration.zero) {
      await Future<void>.delayed(loadDelay);
    }
    return profiles[userId];
  }
}

Future<AuthController> _initializedController({
  required AuthSessionPort authPort,
  required CountingProfileRepository profileRepository,
}) async {
  final controller = AuthController(
    authService: authPort,
    profileProvisioningService: ProfileProvisioningService(
      profileRepository: profileRepository,
    ),
  );
  await controller.initialize();
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(CurrentUserSession.clear);

  group('AuthController sign-in transition', () {
    test('successful sign-in becomes authenticated and clears loading', () async {
      final authPort = SignInTransitionAuthPort();
      final profiles = CountingProfileRepository(
        seed: {
          'user-123': const UserProfile(
            id: 'user-123',
            displayName: 'Alex',
            isCoach: false,
            isAthlete: true,
          ),
        },
      );
      final controller = await _initializedController(
        authPort: authPort,
        profileRepository: profiles,
      );

      await controller.signIn(email: 'alex@example.com', password: 'secret');

      expect(authPort.signInCallCount, 1);
      expect(profiles.getProfileCallCount, 1);
      expect(controller.state.status, AuthStatus.authenticated);
      expect(controller.state.profile?.displayName, 'Alex');
      expect(CurrentUserSession.requireInstance.profile.displayName, 'Alex');
    });

    test('incomplete profile routes to profileRequired and clears loading', () async {
      final authPort = SignInTransitionAuthPort();
      final profiles = CountingProfileRepository();
      final controller = await _initializedController(
        authPort: authPort,
        profileRepository: profiles,
      );

      await controller.signIn(email: 'alex@example.com', password: 'secret');

      expect(controller.state.status, AuthStatus.profileRequired);
      expect(profiles.getProfileCallCount, 1);
      expect(CurrentUserSession.maybeInstance, isNull);
    });

    test('sign-in failure clears loading and surfaces error', () async {
      final authPort = _FailingSignInAuthPort();
      final profiles = CountingProfileRepository();
      final controller = await _initializedController(
        authPort: authPort,
        profileRepository: profiles,
      );

      await controller.signIn(email: 'alex@example.com', password: 'wrong');

      expect(controller.state.status, AuthStatus.error);
      expect(controller.state.errorMessage, isNotNull);
      expect(profiles.getProfileCallCount, 0);
    });

    test('concurrent auth stream refresh does not duplicate profile load', () async {
      final authPort = SignInTransitionAuthPort();
      final profiles = DelayedProfileRepository(
        loadDelay: const Duration(milliseconds: 20),
        seed: {
          'user-123': const UserProfile(
            id: 'user-123',
            displayName: 'Alex',
            isCoach: false,
            isAthlete: true,
          ),
        },
      );
      final controller = await _initializedController(
        authPort: authPort,
        profileRepository: profiles,
      );

      await controller.signIn(email: 'alex@example.com', password: 'secret');
      await Future<void>.delayed(Duration.zero);

      expect(profiles.getProfileCallCount, 1);
      expect(controller.state.status, AuthStatus.authenticated);
    });

    test('returnToSignIn exposes login through AuthGate routing', () async {
      final authPort = SignInTransitionAuthPort();
      final profiles = CountingProfileRepository();
      final controller = await _initializedController(
        authPort: authPort,
        profileRepository: profiles,
      );

      controller.returnToSignIn();

      expect(controller.state.status, AuthStatus.unauthenticated);
    });
  });

  group('AuthGate sign-in routing', () {
    testWidgets('transitions from overlay login to home without reload', (tester) async {
      final authPort = SignInTransitionAuthPort();
      final profiles = CountingProfileRepository(
        seed: {
          'user-123': const UserProfile(
            id: 'user-123',
            displayName: 'Alex',
            isCoach: false,
            isAthlete: true,
          ),
        },
      );
      final controller = AuthController(
        authService: authPort,
        profileProvisioningService: ProfileProvisioningService(
          profileRepository: profiles,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: AuthGate(controller: controller)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      Navigator.of(tester.element(find.byType(AuthGate))).push(
        MaterialPageRoute(
          builder: (_) => LoginScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), 'alex@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'secret');
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsNothing);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Alex'), findsOneWidget);
      expect(controller.state.status, AuthStatus.authenticated);
      expect(profiles.getProfileCallCount, 1);
    });

    testWidgets('routes incomplete profile to Finish Setup', (tester) async {
      final authPort = SignInTransitionAuthPort();
      final profiles = CountingProfileRepository();
      final controller = AuthController(
        authService: authPort,
        profileProvisioningService: ProfileProvisioningService(
          profileRepository: profiles,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: AuthGate(controller: controller)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await controller.signIn(email: 'alex@example.com', password: 'secret');
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Finish setup'), findsOneWidget);
      expect(find.text('Today'), findsNothing);
      expect(controller.state.status, AuthStatus.profileRequired);
    });
  });
}

class _FailingSignInAuthPort implements AuthSessionPort {
  @override
  Session? get currentSession => null;

  @override
  User? get currentUser => null;

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    throw const AuthException('Invalid login credentials');
  }

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? displayName,
    Set<String>? roleNames,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> resendSignupVerification({required String email}) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> resetPassword({required String email}) async {}
}
