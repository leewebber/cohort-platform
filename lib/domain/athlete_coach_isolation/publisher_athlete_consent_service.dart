import 'consent_models.dart';
import 'consent_store.dart';
import 'isolation_models.dart';

class PublisherProgrammePin {
  const PublisherProgrammePin({
    required this.assignmentId,
    required this.programmeVersionId,
    required this.publisherId,
    this.versionName,
    this.compositeIdentity,
    this.retired = false,
  });

  final String assignmentId;
  final String programmeVersionId;
  final String publisherId;
  final String? versionName;
  final String? compositeIdentity;
  final bool retired;
}

/// Domain consent policy. Mirrors SQL RPCs; no Supabase dependency.
class PublisherAthleteConsentService {
  PublisherAthleteConsentService({
    required this.store,
    required this.clock,
    this.knownAthletes = const {},
    this.activePublishers = const {},
    this.athleteDisplayNames = const {},
    this.pinsForAthlete,
  });

  final InMemoryConsentStore store;
  final ConsentClock clock;
  final Set<String> knownAthletes;
  final Set<String> activePublishers;
  final Map<String, String> athleteDisplayNames;
  PublisherProgrammePin? Function(String athleteId)? pinsForAthlete;

  void expirePending() {
    final now = clock.now();
    for (final row in store.invitations.values.toList()) {
      if (row.state == InvitationState.pending && !row.expiresAt.isAfter(now)) {
        store.putInvitation(
          ConsentInvitation(
            id: row.id,
            publisherId: row.publisherId,
            athleteId: row.athleteId,
            invitedBy: row.invitedBy,
            state: InvitationState.expired,
            invitedAt: row.invitedAt,
            expiresAt: row.expiresAt,
          ),
        );
        _audit(
          invitationId: row.id,
          publisherId: row.publisherId,
          athleteId: row.athleteId,
          transition: 'invitation_expired',
          previous: 'pending',
          next: 'expired',
          actorType: 'system',
        );
      }
    }
  }

  ConsentCommandResult invite({
    required IsolationActor actor,
    required String athleteId,
    Duration ttl = const Duration(days: 7),
  }) {
    expirePending();
    if (!actor.capability.membershipWrite) {
      return const ConsentCommandResult(outcome: ConsentOutcome.unauthorised);
    }
    if (!activePublishers.contains(actor.publisherId)) {
      return const ConsentCommandResult(outcome: ConsentOutcome.publisherInactive);
    }
    if (!knownAthletes.contains(athleteId) || athleteId == actor.principalId) {
      return const ConsentCommandResult(outcome: ConsentOutcome.invalidTarget);
    }
    final active = store.activeMembership(actor.publisherId, athleteId);
    if (active != null) {
      return ConsentCommandResult(
        outcome: ConsentOutcome.alreadyActive,
        membership: active,
      );
    }
    final pending = store.pendingFor(actor.publisherId, athleteId);
    if (pending != null) {
      return ConsentCommandResult(
        outcome: ConsentOutcome.alreadyPending,
        invitation: pending,
      );
    }
    final now = clock.now();
    final created = ConsentInvitation(
      id: store.nextId('invitation'),
      publisherId: actor.publisherId,
      athleteId: athleteId,
      invitedBy: actor.principalId,
      state: InvitationState.pending,
      invitedAt: now,
      expiresAt: now.add(ttl),
    );
    store.putInvitation(created);
    _audit(
      invitationId: created.id,
      publisherId: created.publisherId,
      athleteId: created.athleteId,
      transition: 'invitation_created',
      next: 'pending',
      actorType: 'publisher',
    );
    return ConsentCommandResult(
      outcome: ConsentOutcome.invited,
      invitation: created,
    );
  }

  ConsentCommandResult accept({
    required IsolationActor athlete,
    required String invitationId,
  }) {
    expirePending();
    final row = store.invitation(invitationId);
    if (row == null || row.athleteId != athlete.principalId) {
      return const ConsentCommandResult(outcome: ConsentOutcome.unauthorised);
    }
    if (row.state == InvitationState.accepted) {
      return ConsentCommandResult(
        outcome: ConsentOutcome.alreadyActive,
        invitation: row,
        membership: store.activeMembership(row.publisherId, row.athleteId),
      );
    }
    if (row.state == InvitationState.declined) {
      return ConsentCommandResult(
        outcome: ConsentOutcome.alreadyDeclined,
        invitation: row,
      );
    }
    if (row.state == InvitationState.cancelled) {
      return ConsentCommandResult(
        outcome: ConsentOutcome.cancelled,
        invitation: row,
      );
    }
    if (row.state == InvitationState.expired) {
      return ConsentCommandResult(outcome: ConsentOutcome.expired, invitation: row);
    }
    store.putInvitation(
      ConsentInvitation(
        id: row.id,
        publisherId: row.publisherId,
        athleteId: row.athleteId,
        invitedBy: row.invitedBy,
        state: InvitationState.accepted,
        invitedAt: row.invitedAt,
        expiresAt: row.expiresAt,
      ),
    );
    final existing = store.activeMembership(row.publisherId, row.athleteId);
    if (existing != null) {
      return ConsentCommandResult(
        outcome: ConsentOutcome.alreadyActive,
        invitation: row,
        membership: existing,
      );
    }
    final membership = ConsentMembership(
      id: store.nextId('membership'),
      publisherId: row.publisherId,
      athleteId: row.athleteId,
      invitationId: row.id,
      state: MembershipState.active,
      activatedAt: clock.now(),
    );
    store.putMembership(membership);
    _audit(
      invitationId: row.id,
      membershipId: membership.id,
      publisherId: row.publisherId,
      athleteId: row.athleteId,
      transition: 'invitation_accepted',
      previous: 'pending',
      next: 'accepted',
      actorType: 'athlete',
    );
    return ConsentCommandResult(
      outcome: ConsentOutcome.accepted,
      invitation: row,
      membership: membership,
    );
  }

  ConsentCommandResult decline({
    required IsolationActor athlete,
    required String invitationId,
  }) {
    expirePending();
    final row = store.invitation(invitationId);
    if (row == null || row.athleteId != athlete.principalId) {
      return const ConsentCommandResult(outcome: ConsentOutcome.unauthorised);
    }
    if (row.state == InvitationState.declined) {
      return ConsentCommandResult(
        outcome: ConsentOutcome.alreadyDeclined,
        invitation: row,
      );
    }
    if (row.state != InvitationState.pending) {
      return ConsentCommandResult(
        outcome: row.state == InvitationState.expired
            ? ConsentOutcome.expired
            : ConsentOutcome.conflict,
        invitation: row,
      );
    }
    store.putInvitation(
      ConsentInvitation(
        id: row.id,
        publisherId: row.publisherId,
        athleteId: row.athleteId,
        invitedBy: row.invitedBy,
        state: InvitationState.declined,
        invitedAt: row.invitedAt,
        expiresAt: row.expiresAt,
      ),
    );
    _audit(
      invitationId: row.id,
      publisherId: row.publisherId,
      athleteId: row.athleteId,
      transition: 'invitation_declined',
      previous: 'pending',
      next: 'declined',
      actorType: 'athlete',
    );
    return ConsentCommandResult(outcome: ConsentOutcome.declined, invitation: row);
  }

  ConsentCommandResult cancel({
    required IsolationActor publisher,
    required String invitationId,
  }) {
    expirePending();
    final row = store.invitation(invitationId);
    if (row == null ||
        row.publisherId != publisher.publisherId ||
        !publisher.capability.membershipWrite) {
      return const ConsentCommandResult(outcome: ConsentOutcome.unauthorised);
    }
    if (row.state == InvitationState.cancelled) {
      return ConsentCommandResult(
        outcome: ConsentOutcome.alreadyCancelled,
        invitation: row,
      );
    }
    if (row.state != InvitationState.pending) {
      return ConsentCommandResult(outcome: ConsentOutcome.conflict, invitation: row);
    }
    store.putInvitation(
      ConsentInvitation(
        id: row.id,
        publisherId: row.publisherId,
        athleteId: row.athleteId,
        invitedBy: row.invitedBy,
        state: InvitationState.cancelled,
        invitedAt: row.invitedAt,
        expiresAt: row.expiresAt,
      ),
    );
    _audit(
      invitationId: row.id,
      publisherId: row.publisherId,
      athleteId: row.athleteId,
      transition: 'invitation_cancelled',
      previous: 'pending',
      next: 'cancelled',
      actorType: 'publisher',
    );
    return ConsentCommandResult(outcome: ConsentOutcome.cancelled, invitation: row);
  }

  ConsentCommandResult revoke({
    required IsolationActor actor,
    required String membershipId,
  }) {
    final row = store.memberships[membershipId];
    if (row == null) {
      return const ConsentCommandResult(outcome: ConsentOutcome.invalidTarget);
    }
    final asAthlete = actor.principalId == row.athleteId;
    final asPublisher =
        actor.publisherId == row.publisherId && actor.capability.membershipWrite;
    if (!asAthlete && !asPublisher) {
      return const ConsentCommandResult(outcome: ConsentOutcome.unauthorised);
    }
    if (row.state == MembershipState.revoked) {
      return ConsentCommandResult(
        outcome: ConsentOutcome.alreadyRevoked,
        membership: row,
      );
    }
    final revoked = ConsentMembership(
      id: row.id,
      publisherId: row.publisherId,
      athleteId: row.athleteId,
      invitationId: row.invitationId,
      state: MembershipState.revoked,
      activatedAt: row.activatedAt,
      revokedAt: clock.now(),
    );
    store.putMembership(revoked);
    _audit(
      invitationId: row.invitationId,
      membershipId: row.id,
      publisherId: row.publisherId,
      athleteId: row.athleteId,
      transition: asAthlete
          ? 'membership_revoked_by_athlete'
          : 'membership_revoked_by_publisher',
      previous: 'active',
      next: 'revoked',
      actorType: asAthlete ? 'athlete' : 'publisher',
    );
    return ConsentCommandResult(
      outcome: ConsentOutcome.revoked,
      membership: revoked,
    );
  }

  List<ConsentRosterRow> inspectRoster(IsolationActor publisher) {
    expirePending();
    if (!publisher.capability.rosterRead) return const [];
    return [
      for (final membership in store.activeForPublisher(publisher.publisherId))
        _project(membership, publisher.publisherId),
    ];
  }

  ConsentRosterRow _project(ConsentMembership membership, String publisherId) {
    final pin = pinsForAthlete?.call(membership.athleteId);
    if (pin == null) {
      return ConsentRosterRow(
        membership: membership,
        assignmentVisibility: AssignmentVisibility.none,
        athleteDisplayName: athleteDisplayNames[membership.athleteId],
      );
    }
    if (pin.publisherId != publisherId) {
      return ConsentRosterRow(
        membership: membership,
        assignmentVisibility: AssignmentVisibility.foreignHidden,
        athleteDisplayName: athleteDisplayNames[membership.athleteId],
      );
    }
    return ConsentRosterRow(
      membership: membership,
      assignmentVisibility: AssignmentVisibility.own,
      athleteDisplayName: athleteDisplayNames[membership.athleteId],
      assignmentId: pin.assignmentId,
      programmeVersionId: pin.programmeVersionId,
      programmeVersionName: pin.versionName,
      graphStatus: pin.compositeIdentity == null
          ? GraphStatus.missing
          : GraphStatus.published,
      graphCompositeIdentity: pin.compositeIdentity,
    );
  }

  void _audit({
    required String publisherId,
    required String athleteId,
    required String transition,
    required String next,
    String? invitationId,
    String? membershipId,
    String? previous,
    String? actorType,
  }) {
    store.addEvent(
      ConsentAuditEvent(
        id: store.nextId('event'),
        publisherId: publisherId,
        athleteId: athleteId,
        transition: transition,
        newState: next,
        createdAt: clock.now(),
        invitationId: invitationId,
        membershipId: membershipId,
        previousState: previous,
        actorType: actorType,
      ),
    );
  }
}
