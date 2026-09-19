/// Persistent-consent domain types. Independently testable from Supabase.
library;

enum InvitationState { pending, accepted, declined, expired, cancelled }

enum MembershipState { active, revoked }

enum ConsentOutcome {
  invited,
  alreadyPending,
  accepted,
  alreadyActive,
  declined,
  alreadyDeclined,
  cancelled,
  alreadyCancelled,
  expired,
  revoked,
  alreadyRevoked,
  unauthorised,
  invalidTarget,
  publisherInactive,
  principalInactive,
  conflict,
}

enum AssignmentVisibility { none, own, foreignHidden }

enum GraphStatus { missing, published, stale, hidden }

class ConsentInvitation {
  const ConsentInvitation({
    required this.id,
    required this.publisherId,
    required this.athleteId,
    required this.invitedBy,
    required this.state,
    required this.invitedAt,
    required this.expiresAt,
  });

  final String id;
  final String publisherId;
  final String athleteId;
  final String invitedBy;
  final InvitationState state;
  final DateTime invitedAt;
  final DateTime expiresAt;
}

class ConsentMembership {
  const ConsentMembership({
    required this.id,
    required this.publisherId,
    required this.athleteId,
    required this.invitationId,
    required this.state,
    required this.activatedAt,
    this.revokedAt,
  });

  final String id;
  final String publisherId;
  final String athleteId;
  final String invitationId;
  final MembershipState state;
  final DateTime activatedAt;
  final DateTime? revokedAt;
}

class ConsentAuditEvent {
  const ConsentAuditEvent({
    required this.id,
    required this.publisherId,
    required this.athleteId,
    required this.transition,
    required this.newState,
    required this.createdAt,
    this.invitationId,
    this.membershipId,
    this.previousState,
    this.actorType,
  });

  final String id;
  final String publisherId;
  final String athleteId;
  final String transition;
  final String newState;
  final DateTime createdAt;
  final String? invitationId;
  final String? membershipId;
  final String? previousState;
  final String? actorType;
}

class ConsentCommandResult {
  const ConsentCommandResult({
    required this.outcome,
    this.invitation,
    this.membership,
  });

  final ConsentOutcome outcome;
  final ConsentInvitation? invitation;
  final ConsentMembership? membership;
}

class ConsentRosterRow {
  const ConsentRosterRow({
    required this.membership,
    required this.assignmentVisibility,
    this.athleteDisplayName,
    this.assignmentId,
    this.programmeVersionId,
    this.programmeVersionName,
    this.graphStatus = GraphStatus.hidden,
    this.graphCompositeIdentity,
  });

  final ConsentMembership membership;
  final AssignmentVisibility assignmentVisibility;
  final String? athleteDisplayName;
  final String? assignmentId;
  final String? programmeVersionId;
  final String? programmeVersionName;
  final GraphStatus graphStatus;
  final String? graphCompositeIdentity;
}
