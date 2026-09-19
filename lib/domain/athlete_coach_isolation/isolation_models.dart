/// M10 publisher-scoped athlete membership. Local Sprint 1 contract.
/// Must not be imported by production `lib/main.dart`.
library;

class IsolationCapability {
  const IsolationCapability({
    this.rosterRead = false,
    this.membershipWrite = false,
  });

  static const none = IsolationCapability();
  static const reader = IsolationCapability(rosterRead: true);
  static const publisher = IsolationCapability(
    rosterRead: true,
    membershipWrite: true,
  );

  final bool rosterRead;
  final bool membershipWrite;
}

class IsolationActor {
  const IsolationActor({
    required this.principalId,
    required this.publisherId,
    required this.capability,
  });

  final String principalId;
  final String publisherId;
  final IsolationCapability capability;
}

enum IsolationMembershipStatus { active, ended }

enum IsolationRosterStatus {
  ready,
  empty,
  unauthorised,
  unavailable,
  invalidInput,
  staleManifest,
}

enum IsolationActivateStatus {
  activated,
  alreadyActive,
  unauthorised,
  conflict,
  invalidInput,
  staleManifest,
  assignmentPinned,
  unavailable,
}

class TenantAthleteMembership {
  const TenantAthleteMembership({
    required this.id,
    required this.publisherId,
    required this.athleteId,
    required this.coachPrincipalId,
    required this.status,
    this.pinnedAssignmentId,
    this.expectedGraphComposite,
  });

  final String id;
  final String publisherId;
  final String athleteId;
  final String coachPrincipalId;
  final IsolationMembershipStatus status;
  final String? pinnedAssignmentId;
  final String? expectedGraphComposite;

  bool get isActive => status == IsolationMembershipStatus.active;
}

class IsolationRosterEntry {
  const IsolationRosterEntry({
    required this.membershipId,
    required this.athleteId,
    required this.publisherId,
    this.pinnedAssignmentId,
    this.pinnedProgrammeVersionId,
    this.graphCompositeIdentity,
    this.usedByExerciseCount = 0,
    this.staleDeclaredComposite = false,
  });

  final String membershipId;
  final String athleteId;
  final String publisherId;
  final String? pinnedAssignmentId;
  final String? pinnedProgrammeVersionId;
  final String? graphCompositeIdentity;
  final int usedByExerciseCount;
  final bool staleDeclaredComposite;
}

class IsolationRosterResult {
  const IsolationRosterResult({
    required this.status,
    this.entries = const [],
    this.failureCode,
  });

  final IsolationRosterStatus status;
  final List<IsolationRosterEntry> entries;
  final String? failureCode;
}

class IsolationActivateResult {
  const IsolationActivateResult({
    required this.status,
    this.membership,
    this.failureCode,
  });

  final IsolationActivateStatus status;
  final TenantAthleteMembership? membership;
  final String? failureCode;
}

class IsolationException implements Exception {
  const IsolationException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'IsolationException($code): $message';
}

String membershipIdFor({
  required String publisherId,
  required String athleteId,
}) {
  return 'membership.$publisherId.$athleteId';
}
