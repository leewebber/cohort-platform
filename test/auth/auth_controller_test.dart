import 'dart:async';

import 'package:cohort_platform/features/auth/controllers/auth_controller.dart';
import 'package:cohort_platform/features/auth/models/user_profile.dart';
import 'package:cohort_platform/features/auth/models/user_role.dart';
import 'package:cohort_platform/features/auth/services/auth_session_port.dart';
import 'package:cohort_platform/features/auth/services/current_user_session.dart';
import 'package:cohort_platform/features/auth/services/profile_provisioning_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/in_memory_profile_repository.dart';

class FakeAuthSessionPort implements AuthSessionPort {
  Session? session;
  User? user;
  final _controller = StreamController<AuthState>.broadcast();

  void setAuthenticated({
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

  void setSignedOut() {
    session = null;
    user = null;
    _controller.add(const AuthState(AuthChangeEvent.signedOut, null));
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
    if (password == 'wrong') {
      throw const AuthException('Invalid login credentials');
    }

    setAuthenticated(userId: 'user-123', email: email);
    return AuthResponse(session: session, user: user);
  }

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? displayName,
    Set<String>? roleNames,
  }) async {
    user = User(
      id: 'user-new',
      appMetadata: const {},
      userMetadata: {
        if (displayName != null) 'display_name': displayName,
        if (roleNames != null) 'roles': roleNames.toList(),
      },
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: email,
    );
    return AuthResponse(session: null, user: user);
  }

  @override
  Future<void> resendSignupVerification({required String email}) async {}

  @override
  Future<void> signOut() async {
    setSignedOut();
  }

  @override
  Future<void> resetPassword({required String email}) async {}
}

class ThrowingSignUpAuthPort implements AuthSessionPort {
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
  }) =>
      throw UnimplementedError();

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? displayName,
    Set<String>? roleNames,
  }) async {
    throw const AuthException('Signup failed');
  }

  @override
  Future<void> resendSignupVerification({required String email}) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> resetPassword({required String email}) async {}
}

void main() {
  late FakeAuthSessionPort authService;
  late InMemoryProfileRepository profileRepository;
  late ProfileProvisioningService profileService;

  setUp(() {
    CurrentUserSession.clear();
    authService = FakeAuthSessionPort();
    profileRepository = InMemoryProfileRepository();
    profileService = ProfileProvisioningService(
      profileRepository: profileRepository,
    );
  });

  tearDown(() {
    CurrentUserSession.clear();
  });

  group('ProfileProvisioningService', () {
    test('creates profile with selected roles', () async {
      final profile = await profileService.provisionProfile(
        userId: 'user-123',
        displayName: 'Lee',
        roles: {UserRole.coach, UserRole.athlete},
      );

      expect(profile.displayName, 'Lee');
      expect(profile.isCoach, isTrue);
      expect(profile.isAthlete, isTrue);
    });

    test('rejects empty role selection', () async {
      expect(
        () => profileService.provisionProfile(
          userId: 'user-123',
          displayName: 'Lee',
          roles: {},
        ),
        throwsArgumentError,
      );
    });
  });

  group('AuthController', () {
    test('initialize with no session is unauthenticated', () async {
      final controller = AuthController(
        authService: authService,
        profileProvisioningService: profileService,
      );

      await controller.initialize();

      expect(controller.state.status.name, 'unauthenticated');
      expect(CurrentUserSession.maybeInstance, isNull);
    });

    test('initialize with session and profile binds CurrentUserSession', () async {
      authService.setAuthenticated(userId: 'user-123', email: 'lee@example.com');
      profileRepository.profiles['user-123'] = const UserProfile(
        id: 'user-123',
        displayName: 'Lee',
        isCoach: true,
        isAthlete: true,
      );

      final controller = AuthController(
        authService: authService,
        profileProvisioningService: profileService,
      );

      await controller.initialize();

      expect(controller.state.status.name, 'authenticated');
      expect(CurrentUserSession.requireInstance.athleteId, 'user-123');
      expect(CurrentUserSession.requireInstance.coachId, 'user-123');
    });

    test('session without profile requires profile setup', () async {
      authService.setAuthenticated(userId: 'user-123', email: 'lee@example.com');

      final controller = AuthController(
        authService: authService,
        profileProvisioningService: profileService,
      );

      await controller.initialize();

      expect(controller.state.status.name, 'profileRequired');
    });

    test('signIn failure surfaces friendly error', () async {
      final controller = AuthController(
        authService: authService,
        profileProvisioningService: profileService,
      );

      await controller.signIn(email: 'lee@example.com', password: 'wrong');

      expect(controller.state.status.name, 'error');
      expect(controller.state.errorMessage, 'Email or password is incorrect.');
    });

    test('signUp with unconfirmed email enters awaiting confirmation state', () async {
      final controller = AuthController(
        authService: authService,
        profileProvisioningService: profileService,
      );

      await controller.signUp(
        email: 'alex@example.com',
        password: 'secret123',
        displayName: 'Alex',
        roles: {UserRole.athlete},
      );

      expect(controller.state.status.name, 'awaitingEmailConfirmation');
      expect(controller.state.pendingEmail, 'alex@example.com');
      expect(controller.state.pendingDisplayName, 'Alex');
      expect(controller.state.pendingRoles, {UserRole.athlete});
      expect(CurrentUserSession.maybeInstance, isNull);
    });

    test('signUp failure clears loading and surfaces error', () async {
      final controller = AuthController(
        authService: ThrowingSignUpAuthPort(),
        profileProvisioningService: profileService,
      );

      await controller.signUp(
        email: 'alex@example.com',
        password: 'secret123',
        displayName: 'Alex',
        roles: {UserRole.athlete},
      );

      expect(controller.state.status.name, 'error');
      expect(controller.state.errorMessage, isNotNull);
    });

    test('profileRequired prefills pending signup metadata', () async {
      authService.setAuthenticated(userId: 'user-new', email: 'alex@example.com');
      authService.user = User(
        id: 'user-new',
        appMetadata: const {},
        userMetadata: const {
          'display_name': 'Alex',
          'roles': ['athlete', 'coach'],
        },
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
        email: 'alex@example.com',
      );

      final controller = AuthController(
        authService: authService,
        profileProvisioningService: profileService,
      );

      await controller.initialize();

      expect(controller.state.status.name, 'profileRequired');
      expect(controller.state.pendingDisplayName, 'Alex');
      expect(controller.state.pendingRoles, {UserRole.athlete, UserRole.coach});
    });

    test('signOut clears session', () async {
      authService.setAuthenticated(userId: 'user-123', email: 'lee@example.com');
      profileRepository.profiles['user-123'] = const UserProfile(
        id: 'user-123',
        displayName: 'Lee',
        isCoach: true,
        isAthlete: true,
      );

      final controller = AuthController(
        authService: authService,
        profileProvisioningService: profileService,
      );

      await controller.initialize();
      await controller.signOut();

      expect(controller.state.status.name, 'unauthenticated');
      expect(CurrentUserSession.maybeInstance, isNull);
    });
  });
}
