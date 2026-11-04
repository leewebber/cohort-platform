import 'package:flutter/foundation.dart';
import 'auth_confirmation_redirect.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import 'auth_session_port.dart';

class AuthService implements AuthSessionPort {
  AuthService({SupabaseClient? client})
    : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  String? get _confirmationRedirect =>
      authConfirmationRedirect(isWeb: kIsWeb, platform: defaultTargetPlatform);

  @override
  Session? get currentSession => _client.auth.currentSession;

  @override
  User? get currentUser => _client.auth.currentUser;

  @override
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  @override
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? displayName,
    Set<String>? roleNames,
  }) {
    return _client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: _confirmationRedirect,
      data: {
        if (displayName != null && displayName.trim().isNotEmpty)
          'display_name': displayName.trim(),
        if (roleNames != null && roleNames.isNotEmpty)
          'roles': roleNames.toList(),
      },
    );
  }

  @override
  Future<void> resendSignupVerification({required String email}) {
    return _client.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
      emailRedirectTo: _confirmationRedirect,
    );
  }

  @override
  Future<void> signOut() {
    return _client.auth.signOut();
  }

  @override
  Future<void> resetPassword({required String email}) {
    return _client.auth.resetPasswordForEmail(email.trim());
  }
}
