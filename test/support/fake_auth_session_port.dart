import 'dart:async';

import 'package:cohort_platform/features/auth/services/auth_session_port.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    setAuthenticated(userId: 'user-new', email: email);
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
