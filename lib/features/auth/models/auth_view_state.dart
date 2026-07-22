import 'user_profile.dart';
import 'user_role.dart';

enum AuthStatus {
  initial,
  loading,
  unauthenticated,
  awaitingEmailConfirmation,
  profileRequired,
  authenticated,
  error,
}

class AuthViewState {
  const AuthViewState({
    required this.status,
    this.profile,
    this.errorMessage,
    this.pendingEmail,
    this.pendingDisplayName,
    this.pendingRoles,
  });

  final AuthStatus status;
  final UserProfile? profile;
  final String? errorMessage;
  final String? pendingEmail;
  final String? pendingDisplayName;
  final Set<UserRole>? pendingRoles;

  factory AuthViewState.initial() {
    return const AuthViewState(status: AuthStatus.initial);
  }

  AuthViewState copyWith({
    AuthStatus? status,
    UserProfile? profile,
    bool clearProfile = false,
    String? errorMessage,
    bool clearError = false,
    String? pendingEmail,
    bool clearPendingEmail = false,
    String? pendingDisplayName,
    bool clearPendingDisplayName = false,
    Set<UserRole>? pendingRoles,
    bool clearPendingRoles = false,
  }) {
    return AuthViewState(
      status: status ?? this.status,
      profile: clearProfile ? null : (profile ?? this.profile),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      pendingEmail:
          clearPendingEmail ? null : (pendingEmail ?? this.pendingEmail),
      pendingDisplayName: clearPendingDisplayName
          ? null
          : (pendingDisplayName ?? this.pendingDisplayName),
      pendingRoles:
          clearPendingRoles ? null : (pendingRoles ?? this.pendingRoles),
    );
  }
}
