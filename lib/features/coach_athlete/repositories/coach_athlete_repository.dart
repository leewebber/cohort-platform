import '../models/coach_athlete_invite.dart';
import '../models/coach_athlete_relationship.dart';
import '../models/coach_athlete_roster_entry.dart';

abstract interface class CoachAthleteRelationshipRepository {
  Future<List<CoachAthleteRelationship>> listActiveForCoach(String coachId);

  Future<CoachAthleteRelationship?> getActiveForAthlete(String athleteId);

  Future<bool> hasActiveRelationship({
    required String coachId,
    required String athleteId,
  });
}

abstract interface class CoachAthleteInviteRepository {
  Future<CoachAthleteInvite> createInvite(CoachAthleteInvite invite);

  Future<List<CoachAthleteInvite>> listPendingForCoach(String coachId);

  Future<void> revokeInvite(String inviteId);

  Future<CoachAthleteAcceptInviteResult> acceptInvite(String code);
}
