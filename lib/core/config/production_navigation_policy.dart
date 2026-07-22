import '../../features/auth/models/user_profile.dart';
import '../../features/auth/services/current_user_session.dart';
import 'internal_tools_policy.dart';

/// Role-aware rules for standard production navigation.
class ProductionNavigationPolicy {
  ProductionNavigationPolicy._();

  static UserProfile _profile() => CurrentUserSession.requireInstance.profile;

  static bool showAthleteTodayExperience() => _profile().isAthlete;

  static bool showJoinCoachCard() => _profile().isAthlete;

  static bool showTrainingHistory() => _profile().isAthlete;

  static bool showAdaptationPrompt() => _profile().isAthlete;

  static bool showAthleteKnowledge() => _profile().isAthlete;

  static bool showCoachHome() => _profile().isCoach;

  static bool showCoachStudio() => _profile().isCoach;

  static bool showHelpAndFeedback() => true;

  static bool showInternalToolsEntry() => InternalToolsPolicy.enabled;

  static bool showCoachLandingMessage() =>
      _profile().isCoach && !_profile().isAthlete;
}
