import '../../features/auth/models/user_profile.dart';
import '../../features/auth/services/current_user_session.dart';
import '../config/internal_tools_policy.dart';
import 'founder_access_policy.dart';

/// Central role checks for athlete-safe production navigation and route guards.
///
/// Source of truth:
/// - [UserProfile.isCoach] / [UserProfile.isAthlete] on [CurrentUserSession]
/// - Founder workspace via [FounderAccessPolicy] (email allowlist / override)
/// - Engineering builds via [InternalToolsPolicy.enabled]
class AppRoleAccess {
  AppRoleAccess._();

  static UserProfile? get _profile => CurrentUserSession.maybeInstance?.profile;

  /// Engineering / founder acceptance builds (`ENABLE_INTERNAL_TOOLS`).
  static bool get isFounderBuild => InternalToolsPolicy.enabled;

  /// Authorised Founder Workspace session (allowlist or development override).
  static bool get isFounderSession => FounderAccessPolicy.isSessionFounder;

  static bool get canAccessAthleteExperience {
    final profile = _profile;
    if (profile == null) return false;
    return profile.isAthlete || isFounderBuild || isFounderSession;
  }

  static bool get canAccessCoachOperations {
    final profile = _profile;
    if (isFounderBuild || isFounderSession) return true;
    if (profile == null) return false;
    return profile.isCoach;
  }

  static bool get isAthleteOnlyAccount {
    final profile = _profile;
    if (profile == null) return false;
    return profile.isAthlete &&
        !profile.isCoach &&
        !isFounderBuild &&
        !isFounderSession;
  }
}
