import '../constants/programme_dev_identity.dart';
import '../../features/auth/services/current_user_session.dart';

/// Provides the current coach identity for authoring operations.
abstract interface class CurrentCoachIdentity {
  String? get coachId;
}

/// Resolves coach identity from the authenticated session, with dev fallback.
class DevCoachIdentity implements CurrentCoachIdentity {
  const DevCoachIdentity();

  @override
  String? get coachId =>
      CurrentUserSession.maybeInstance?.coachId ?? ProgrammeDevIdentity.coachId;
}
