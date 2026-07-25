import '../../features/auth/models/user_profile.dart';
import '../../features/auth/services/current_user_session.dart';
import '../config/internal_tools_policy.dart';

/// Central role checks for athlete-safe production navigation and route guards.
///
/// Source of truth:
/// - [UserProfile.isCoach] / [UserProfile.isAthlete] on [CurrentUserSession]
/// - Founder/engineering builds via [InternalToolsPolicy.enabled]
class AppRoleAccess {
  AppRoleAccess._();

  static UserProfile? get _profile => CurrentUserSession.maybeInstance?.profile;

  /// Engineering / founder acceptance builds (`ENABLE_INTERNAL_TOOLS`).
  static bool get isFounderBuild => InternalToolsPolicy.enabled;

  static bool get canAccessAthleteExperience {
    final profile = _profile;
    if (profile == null) return false;
    return profile.isAthlete || isFounderBuild;
  }

  static bool get canAccessCoachOperations {
    final profile = _profile;
    if (profile == null) return false;
    return profile.isCoach || isFounderBuild;
  }

  static bool get isAthleteOnlyAccount {
    final profile = _profile;
    if (profile == null) return false;
    return profile.isAthlete && !profile.isCoach && !isFounderBuild;
  }
}
