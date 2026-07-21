import 'package:cohort_platform/features/auth/models/user_profile.dart';
import 'package:cohort_platform/features/auth/services/current_user_session.dart';
import 'package:cohort_platform/features/coach_athlete/models/coach_athlete_invite.dart';
import 'package:cohort_platform/features/coach_athlete/models/coach_athlete_relationship.dart';
import 'package:cohort_platform/features/coach_athlete/models/coach_athlete_roster_entry.dart';
import 'package:cohort_platform/features/coach_athlete/repositories/coach_athlete_repository.dart';

class InMemoryCoachAthleteTables {
  final relationships = <CoachAthleteRelationship>[];
  final invites = <CoachAthleteInvite>[];
  final profiles = <String, UserProfile>{};
  int _relationshipCounter = 0;
  int _inviteCounter = 0;
}

class InMemoryCoachAthleteRelationshipRepository
    implements CoachAthleteRelationshipRepository {
  InMemoryCoachAthleteRelationshipRepository(this.tables);

  final InMemoryCoachAthleteTables tables;

  @override
  Future<List<CoachAthleteRelationship>> listActiveForCoach(String coachId) {
    return Future.value(
      tables.relationships
          .where(
            (relationship) =>
                relationship.coachId == coachId &&
                relationship.status == CoachAthleteRelationshipStatus.active,
          )
          .toList(),
    );
  }

  @override
  Future<CoachAthleteRelationship?> getActiveForAthlete(String athleteId) async {
    for (final relationship in tables.relationships) {
      if (relationship.athleteId == athleteId &&
          relationship.status == CoachAthleteRelationshipStatus.active) {
        return relationship;
      }
    }
    return null;
  }

  @override
  Future<bool> hasActiveRelationship({
    required String coachId,
    required String athleteId,
  }) async {
    return tables.relationships.any(
      (relationship) =>
          relationship.coachId == coachId &&
          relationship.athleteId == athleteId &&
          relationship.status == CoachAthleteRelationshipStatus.active,
    );
  }

  CoachAthleteRelationship createActiveRelationship({
    required String coachId,
    required String athleteId,
  }) {
    final relationship = CoachAthleteRelationship(
      id: 'relationship-${tables._relationshipCounter++}',
      coachId: coachId,
      athleteId: athleteId,
      status: CoachAthleteRelationshipStatus.active,
      createdAt: DateTime.now().toUtc(),
    );
    tables.relationships.add(relationship);
    return relationship;
  }
}

class InMemoryCoachAthleteInviteRepository implements CoachAthleteInviteRepository {
  InMemoryCoachAthleteInviteRepository(
    this.tables, {
    this.currentAthleteId,
    this.currentCoachId,
  });

  final InMemoryCoachAthleteTables tables;
  String? currentAthleteId;
  String? currentCoachId;

  @override
  Future<CoachAthleteInvite> createInvite(CoachAthleteInvite invite) async {
    final created = CoachAthleteInvite(
      id: 'invite-${tables._inviteCounter++}',
      coachId: invite.coachId,
      code: invite.code,
      status: CoachAthleteInviteStatus.pending,
      expiresAt: invite.expiresAt,
      createdAt: DateTime.now().toUtc(),
    );
    tables.invites.add(created);
    return created;
  }

  @override
  Future<List<CoachAthleteInvite>> listPendingForCoach(String coachId) async {
    return tables.invites
        .where(
          (invite) =>
              invite.coachId == coachId &&
              invite.status == CoachAthleteInviteStatus.pending &&
              invite.isUsable,
        )
        .toList();
  }

  @override
  Future<void> revokeInvite(String inviteId) async {
    for (var i = 0; i < tables.invites.length; i++) {
      if (tables.invites[i].id == inviteId) {
        final invite = tables.invites[i];
        tables.invites[i] = CoachAthleteInvite(
          id: invite.id,
          coachId: invite.coachId,
          code: invite.code,
          status: CoachAthleteInviteStatus.revoked,
          expiresAt: invite.expiresAt,
          createdAt: invite.createdAt,
        );
      }
    }
  }

  @override
  Future<CoachAthleteAcceptInviteResult> acceptInvite(String code) async {
    final athleteId =
        currentAthleteId ?? CurrentUserSession.maybeInstance?.athleteId;
    if (athleteId == null) {
      throw Exception('Sign in to join a coach.');
    }

    final profile = tables.profiles[athleteId];
    if (profile == null || !profile.isAthlete) {
      throw Exception('An athlete profile is required to accept an invitation.');
    }

    CoachAthleteInvite? invite;
    for (final candidate in tables.invites) {
      if (candidate.code.toUpperCase() == code.trim().toUpperCase()) {
        invite = candidate;
        break;
      }
    }

    if (invite == null) {
      throw Exception('That invitation code is not valid.');
    }
    if (invite.coachId == athleteId) {
      throw Exception('You cannot accept your own invitation.');
    }
    if (invite.status == CoachAthleteInviteStatus.revoked) {
      throw Exception('This invitation has been revoked.');
    }
    if (invite.status == CoachAthleteInviteStatus.accepted) {
      throw Exception('This invitation has already been used.');
    }
    if (invite.isExpired) {
      throw Exception('This invitation has expired.');
    }

    if (tables.relationships.any(
      (relationship) =>
          relationship.athleteId == athleteId &&
          relationship.status == CoachAthleteRelationshipStatus.active,
    )) {
      throw Exception('You are already linked to a coach.');
    }

    final index = tables.invites.indexWhere((item) => item.id == invite!.id);
    tables.invites[index] = CoachAthleteInvite(
      id: invite.id,
      coachId: invite.coachId,
      code: invite.code,
      status: CoachAthleteInviteStatus.accepted,
      expiresAt: invite.expiresAt,
      createdAt: invite.createdAt,
      acceptedAt: DateTime.now().toUtc(),
      acceptedByAthleteId: athleteId,
    );

    tables.relationships.add(
      CoachAthleteRelationship(
        id: 'relationship-${tables._relationshipCounter++}',
        coachId: invite.coachId,
        athleteId: athleteId,
        status: CoachAthleteRelationshipStatus.active,
        createdAt: DateTime.now().toUtc(),
      ),
    );

    final coachProfile = tables.profiles[invite.coachId];
    return CoachAthleteAcceptInviteResult(
      coachDisplayName: coachProfile?.displayName ?? 'Your coach',
      coachId: invite.coachId,
    );
  }
}
