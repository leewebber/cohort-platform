import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/auth_view_state.dart';
import '../models/user_role.dart';
import '../services/auth_session_port.dart';
import '../services/auth_service.dart';
import '../services/current_user_session.dart';
import '../services/profile_provisioning_service.dart';

class AuthController extends ChangeNotifier {
  AuthController({
    AuthSessionPort? authService,
    ProfileProvisioningService? profileProvisioningService,
  })  : _authService = authService ?? AuthService(),
        _profileProvisioningService =
            profileProvisioningService ?? ProfileProvisioningService(),
        _state = AuthViewState.initial();

  final AuthSessionPort _authService;
  final ProfileProvisioningService _profileProvisioningService;

  AuthViewState _state;
  StreamSubscription<AuthState>? _authSubscription;

  AuthViewState get state => _state;

  Future<void> initialize() async {
    _state = _state.copyWith(
      status: AuthStatus.loading,
      clearError: true,
    );
    notifyListeners();

    _authSubscription ??= _authService.authStateChanges.listen((_) {
      unawaited(_refreshFromSession());
    });

    await _refreshFromSession();
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    _state = _state.copyWith(
      status: AuthStatus.loading,
      clearError: true,
    );
    notifyListeners();

    try {
      final response = await _authService.signIn(
        email: email,
        password: password,
      );

      if (response.session == null) {
        _state = _state.copyWith(
          status: AuthStatus.awaitingEmailConfirmation,
          pendingEmail: email.trim(),
          errorMessage:
              'Check your email to confirm your account, then sign in.',
        );
        notifyListeners();
        return;
      }

      await _refreshFromSession();
    } on AuthException catch (error) {
      _state = _state.copyWith(
        status: AuthStatus.error,
        errorMessage: _friendlyAuthMessage(error.message),
      );
      notifyListeners();
    } catch (error) {
      _state = _state.copyWith(
        status: AuthStatus.error,
        errorMessage: error.toString(),
      );
      notifyListeners();
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
    required Set<UserRole> roles,
  }) async {
    _state = _state.copyWith(
      status: AuthStatus.loading,
      clearError: true,
    );
    notifyListeners();

    try {
      final response = await _authService.signUp(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        _state = _state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Account creation failed. Please try again.',
        );
        notifyListeners();
        return;
      }

      if (response.session == null) {
        _state = _state.copyWith(
          status: AuthStatus.awaitingEmailConfirmation,
          pendingEmail: email.trim(),
          errorMessage: null,
        );
        notifyListeners();
        return;
      }

      await _completeProfileProvisioning(
        userId: user.id,
        displayName: displayName,
        roles: roles,
      );
    } on AuthException catch (error) {
      _state = _state.copyWith(
        status: AuthStatus.error,
        errorMessage: _friendlyAuthMessage(error.message),
      );
      notifyListeners();
    } catch (error) {
      _state = _state.copyWith(
        status: AuthStatus.error,
        errorMessage: error.toString(),
      );
      notifyListeners();
    }
  }

  Future<void> completeProfile({
    required String displayName,
    required Set<UserRole> roles,
  }) async {
    final user = _authService.currentUser;
    if (user == null) {
      _state = _state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Sign in to continue.',
      );
      notifyListeners();
      return;
    }

    _state = _state.copyWith(
      status: AuthStatus.loading,
      clearError: true,
    );
    notifyListeners();

    await _completeProfileProvisioning(
      userId: user.id,
      displayName: displayName,
      roles: roles,
    );
  }

  Future<void> signOut() async {
    await _authService.signOut();
    CurrentUserSession.clear();
    _state = AuthViewState.initial().copyWith(
      status: AuthStatus.unauthenticated,
    );
    notifyListeners();
  }

  Future<void> requestPasswordReset({required String email}) async {
    _state = _state.copyWith(
      status: AuthStatus.loading,
      clearError: true,
    );
    notifyListeners();

    try {
      await _authService.resetPassword(email: email);
      _state = _state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Password reset email sent. Check your inbox.',
      );
      notifyListeners();
    } on AuthException catch (error) {
      _state = _state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: _friendlyAuthMessage(error.message),
      );
      notifyListeners();
    }
  }

  Future<void> _refreshFromSession() async {
    final session = _authService.currentSession;
    final user = _authService.currentUser;

    if (session == null || user == null) {
      CurrentUserSession.clear();
      _state = _state.copyWith(
        status: AuthStatus.unauthenticated,
        clearProfile: true,
        clearPendingEmail: true,
      );
      notifyListeners();
      return;
    }

    try {
      final profile = await _profileProvisioningService.loadProfile(user.id);
      if (profile == null) {
        CurrentUserSession.clear();
        _state = _state.copyWith(
          status: AuthStatus.profileRequired,
          clearProfile: true,
          clearError: true,
        );
        notifyListeners();
        return;
      }

      CurrentUserSession.bind(profile);
      _state = _state.copyWith(
        status: AuthStatus.authenticated,
        profile: profile,
        clearError: true,
        clearPendingEmail: true,
      );
      notifyListeners();
    } catch (error) {
      _state = _state.copyWith(
        status: AuthStatus.error,
        errorMessage: error.toString(),
      );
      notifyListeners();
    }
  }

  Future<void> _completeProfileProvisioning({
    required String userId,
    required String displayName,
    required Set<UserRole> roles,
  }) async {
    try {
      final profile = await _profileProvisioningService.provisionProfile(
        userId: userId,
        displayName: displayName,
        roles: roles,
      );

      CurrentUserSession.bind(profile);
      _state = _state.copyWith(
        status: AuthStatus.authenticated,
        profile: profile,
        clearError: true,
        clearPendingEmail: true,
      );
      notifyListeners();
    } catch (error) {
      _state = _state.copyWith(
        status: AuthStatus.profileRequired,
        errorMessage: error.toString(),
      );
      notifyListeners();
    }
  }

  String _friendlyAuthMessage(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('invalid login credentials')) {
      return 'Email or password is incorrect.';
    }
    if (normalized.contains('email not confirmed')) {
      return 'Confirm your email before signing in.';
    }
    if (normalized.contains('user already registered')) {
      return 'An account with this email already exists. Try signing in.';
    }
    return message;
  }

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }
}
