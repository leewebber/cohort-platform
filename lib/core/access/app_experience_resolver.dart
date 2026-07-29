import 'app_access_role.dart';
import 'founder_access_policy.dart';

/// Resolves which application shell to present.
///
/// Athlete is the default. Founder requires explicit [FounderAccessPolicy]
/// authorisation — never coach-role inference alone.
class AppExperienceResolver {
  const AppExperienceResolver();

  AppAccessRole resolve({String? email}) {
    if (FounderAccessPolicy.isAuthorisedFounder(email: email)) {
      return AppAccessRole.founder;
    }
    return AppAccessRole.athlete;
  }

  bool get isAthleteExperience =>
      resolve(email: null) == AppAccessRole.athlete;
}
