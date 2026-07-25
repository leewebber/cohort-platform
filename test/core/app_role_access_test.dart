import 'package:cohort_platform/core/access/app_role_access.dart';
import 'package:cohort_platform/core/config/internal_tools_policy.dart';
import 'package:cohort_platform/features/auth/models/user_profile.dart';
import 'package:cohort_platform/features/auth/services/current_user_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    CurrentUserSession.clear();
    InternalToolsPolicy.reset();
  });

  group('AppRoleAccess', () {
    test('athlete-only account cannot access coach operations', () {
      CurrentUserSession.bind(
        const UserProfile(
          id: 'athlete-1',
          displayName: 'Alex',
          isCoach: false,
          isAthlete: true,
        ),
      );

      expect(AppRoleAccess.canAccessAthleteExperience, isTrue);
      expect(AppRoleAccess.canAccessCoachOperations, isFalse);
      expect(AppRoleAccess.isAthleteOnlyAccount, isTrue);
    });

    test('coach account can access coach operations', () {
      CurrentUserSession.bind(
        const UserProfile(
          id: 'coach-1',
          displayName: 'Sam',
          isCoach: true,
          isAthlete: false,
        ),
      );

      expect(AppRoleAccess.canAccessCoachOperations, isTrue);
      expect(AppRoleAccess.canAccessAthleteExperience, isFalse);
    });

    test('founder build unlocks coach operations for athlete-only profile', () {
      InternalToolsPolicy.enableForTesting();
      CurrentUserSession.bind(
        const UserProfile(
          id: 'founder-athlete',
          displayName: 'Founder',
          isCoach: false,
          isAthlete: true,
        ),
      );

      expect(AppRoleAccess.isFounderBuild, isTrue);
      expect(AppRoleAccess.canAccessCoachOperations, isTrue);
      expect(AppRoleAccess.canAccessAthleteExperience, isTrue);
    });
  });
}
