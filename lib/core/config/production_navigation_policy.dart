import '../../features/auth/models/user_profile.dart';
import '../../features/auth/services/current_user_session.dart';
import '../access/app_role_access.dart';
import 'internal_tools_policy.dart';

/// Role-aware rules for standard production navigation.
class ProductionNavigationPolicy {
  ProductionNavigationPolicy._();

  static UserProfile _profile() => CurrentUserSession.requireInstance.profile;

  static bool showAthleteTodayExperience() =>
      AppRoleAccess.canAccessAthleteExperience;

  static bool showTrainingHistory() => AppRoleAccess.canAccessAthleteExperience;

  static bool showAdaptationPrompt() => AppRoleAccess.canAccessAthleteExperience;

  static bool showAthleteKnowledge() => AppRoleAccess.canAccessAthleteExperience;

  static bool showCoachHome() => AppRoleAccess.canAccessCoachOperations;

  static bool showCoachStudio() => AppRoleAccess.canAccessCoachOperations;

  static bool showHelpAndFeedback() => true;

  static bool showInternalToolsEntry() => InternalToolsPolicy.enabled;

  static bool showCoachLandingMessage() =>
      _profile().isCoach && !_profile().isAthlete;
}
