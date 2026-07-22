import '../../features/auth/services/current_user_session.dart';

/// Typed failure when authenticated identity cannot be resolved for an operation.
class AuthenticatedIdentityException implements Exception {
  const AuthenticatedIdentityException(this.userMessage);

  final String userMessage;

  @override
  String toString() => userMessage;
}

/// Resolves coach and athlete identifiers from the active Supabase session.
///
/// Never substitutes development or debug identities.
class AuthenticatedIdentity {
  const AuthenticatedIdentity._();

  static String requireUserId() {
    final session = CurrentUserSession.maybeInstance;
    if (session == null) {
      throw const AuthenticatedIdentityException(
        'Your account roles could not be loaded. Please sign in again.',
      );
    }
    return session.userId;
  }

  static String requireCoachId() {
    final session = CurrentUserSession.maybeInstance;
    if (session == null) {
      throw const AuthenticatedIdentityException(
        'Your account roles could not be loaded. Please sign in again.',
      );
    }
    final coachId = session.coachId;
    if (coachId == null || coachId.isEmpty) {
      throw const AuthenticatedIdentityException(
        'Coach access is required to open Coach Studio.',
      );
    }
    return coachId;
  }

  static String requireAthleteId() {
    final session = CurrentUserSession.maybeInstance;
    if (session == null) {
      throw const AuthenticatedIdentityException(
        'Your account roles could not be loaded. Please sign in again.',
      );
    }
    if (!session.isAthlete) {
      throw const AuthenticatedIdentityException(
        'Athlete access is required to start training.',
      );
    }
    return session.athleteId;
  }

  static String? maybeCoachId() => CurrentUserSession.maybeInstance?.coachId;

  static String? maybeAthleteId() {
    final session = CurrentUserSession.maybeInstance;
    if (session == null || !session.isAthlete) return null;
    return session.athleteId;
  }
}
