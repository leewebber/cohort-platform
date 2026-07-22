import 'package:cohort_platform/core/services/authenticated_identity.dart';
import 'package:cohort_platform/core/services/user_session_cache.dart';
import 'package:cohort_platform/features/auth/models/user_profile.dart';
import 'package:cohort_platform/features/auth/services/current_user_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(CurrentUserSession.clear);

  group('AuthenticatedIdentity', () {
    test('requireCoachId resolves authenticated coach UUID', () {
      CurrentUserSession.bind(
        const UserProfile(
          id: 'coach-user-uuid',
          displayName: 'Coach Lee',
          isCoach: true,
          isAthlete: false,
        ),
      );

      expect(AuthenticatedIdentity.requireCoachId(), 'coach-user-uuid');
    });

    test('requireAthleteId resolves authenticated athlete UUID', () {
      CurrentUserSession.bind(
        const UserProfile(
          id: 'athlete-user-uuid',
          displayName: 'Athlete',
          isCoach: false,
          isAthlete: true,
        ),
      );

      expect(AuthenticatedIdentity.requireAthleteId(), 'athlete-user-uuid');
    });

    test('dual-role resolves same UUID for coach and athlete', () {
      CurrentUserSession.bind(
        const UserProfile(
          id: 'dual-role-uuid',
          displayName: 'Dual Role',
          isCoach: true,
          isAthlete: true,
        ),
      );

      expect(AuthenticatedIdentity.requireCoachId(), 'dual-role-uuid');
      expect(AuthenticatedIdentity.requireAthleteId(), 'dual-role-uuid');
    });

    test('missing coach role does not return fallback', () {
      CurrentUserSession.bind(
        const UserProfile(
          id: 'athlete-only',
          displayName: 'Athlete Only',
          isCoach: false,
          isAthlete: true,
        ),
      );

      expect(
        () => AuthenticatedIdentity.requireCoachId(),
        throwsA(isA<AuthenticatedIdentityException>()),
      );
    });

    test('missing session does not return fallback', () {
      CurrentUserSession.clear();

      expect(
        () => AuthenticatedIdentity.requireCoachId(),
        throwsA(
          predicate<AuthenticatedIdentityException>(
            (error) => error.userMessage.contains('sign in again'),
          ),
        ),
      );
    });

    test('account switch changes resolved coach id', () {
      CurrentUserSession.bind(
        const UserProfile(
          id: 'coach-a',
          displayName: 'Coach A',
          isCoach: true,
          isAthlete: false,
        ),
      );
      expect(AuthenticatedIdentity.requireCoachId(), 'coach-a');

      CurrentUserSession.bind(
        const UserProfile(
          id: 'coach-b',
          displayName: 'Coach B',
          isCoach: true,
          isAthlete: false,
        ),
      );
      expect(AuthenticatedIdentity.requireCoachId(), 'coach-b');
    });

    test('sign out clears identity', () {
      CurrentUserSession.bind(
        const UserProfile(
          id: 'coach-a',
          displayName: 'Coach A',
          isCoach: true,
          isAthlete: true,
        ),
      );
      CurrentUserSession.clear();
      UserSessionCache.clearAll();

      expect(AuthenticatedIdentity.maybeCoachId(), isNull);
      expect(AuthenticatedIdentity.maybeAthleteId(), isNull);
    });
  });
}
