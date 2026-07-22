import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class AuthSessionPort {
  Session? get currentSession;

  User? get currentUser;

  Stream<AuthState> get authStateChanges;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  });

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? displayName,
    Set<String>? roleNames,
  });

  Future<void> resendSignupVerification({required String email});

  Future<void> signOut();

  Future<void> resetPassword({required String email});
}
