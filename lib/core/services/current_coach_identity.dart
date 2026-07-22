import '../../features/auth/services/current_user_session.dart';

/// Provides the current coach identity for authoring operations.
abstract interface class CurrentCoachIdentity {
  String? get coachId;
}

/// Resolves coach identity from the authenticated session only.
class AuthenticatedCoachIdentity implements CurrentCoachIdentity {
  const AuthenticatedCoachIdentity();

  @override
  String? get coachId => CurrentUserSession.maybeInstance?.coachId;
}
