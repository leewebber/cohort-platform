import 'coach_athlete_invite.dart';
import 'coach_athlete_relationship.dart';
import 'coach_athlete_roster_entry.dart';

enum CoachAthleteOperationStatus {
  success,
  notAuthenticated,
  coachRoleRequired,
  athleteRoleRequired,
  invalidInvite,
  expiredInvite,
  revokedInvite,
  usedInvite,
  selfInvite,
  alreadyLinked,
  notLinked,
  failed,
}

class CoachAthleteOperationResult<T> {
  const CoachAthleteOperationResult._({
    required this.status,
    this.value,
    this.message,
  });

  final CoachAthleteOperationStatus status;
  final T? value;
  final String? message;

  bool get isSuccess => status == CoachAthleteOperationStatus.success;

  factory CoachAthleteOperationResult.success(T value) {
    return CoachAthleteOperationResult._(
      status: CoachAthleteOperationStatus.success,
      value: value,
    );
  }

  factory CoachAthleteOperationResult.failure({
    required CoachAthleteOperationStatus status,
    String? message,
  }) {
    return CoachAthleteOperationResult._(
      status: status,
      message: message,
    );
  }
}

typedef InviteResult = CoachAthleteOperationResult<CoachAthleteInvite>;
typedef AcceptInviteResult =
    CoachAthleteOperationResult<CoachAthleteAcceptInviteResult>;
typedef RosterResult = CoachAthleteOperationResult<List<CoachAthleteRosterEntry>>;
typedef RelationshipResult = CoachAthleteOperationResult<CoachAthleteRelationship?>;
