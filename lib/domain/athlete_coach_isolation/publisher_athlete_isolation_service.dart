import '../content_graph/content_graph_service.dart';
import '../content_graph/content_graph_store.dart';
import 'isolation_models.dart';
import 'isolation_store.dart';

/// Publisher-scoped athlete membership. Consumes M9 graph/pins; never writes
/// published programme, manifest, or assignment pin rows.
class PublisherAthleteIsolationService {
  PublisherAthleteIsolationService({
    required this.memberships,
    required this.graphStore,
    required this.graph,
  });

  final IsolationMembershipStore memberships;
  final ContentGraphStore graphStore;
  final ContentGraphService graph;

  IsolationRosterResult inspectRoster(IsolationActor actor) {
    final gate = _authoriseRead(actor);
    if (gate != null) return gate;

    final rows = memberships.activeForPublisher(actor.publisherId).toList()
      ..sort((a, b) => a.athleteId.compareTo(b.athleteId));
    if (rows.isEmpty) {
      return const IsolationRosterResult(status: IsolationRosterStatus.empty);
    }

    final entries = <IsolationRosterEntry>[];
    var stale = false;
    for (final row in rows) {
      final entry = _project(row);
      if (entry.staleDeclaredComposite) stale = true;
      entries.add(entry);
    }
    return IsolationRosterResult(
      status: stale
          ? IsolationRosterStatus.staleManifest
          : IsolationRosterStatus.ready,
      entries: entries,
    );
  }

  IsolationActivateResult activateMembership({
    required IsolationActor actor,
    required String athleteId,
    String? pinnedAssignmentId,
    String? expectedGraphComposite,
    String? athleteDisplayName,
  }) {
    if (athleteDisplayName != null) {
      return const IsolationActivateResult(
        status: IsolationActivateStatus.invalidInput,
        failureCode: 'display_name_is_not_identity',
      );
    }
    if (!_hasToken(actor.principalId) ||
        !_hasToken(actor.publisherId) ||
        !_hasToken(athleteId)) {
      return const IsolationActivateResult(
        status: IsolationActivateStatus.invalidInput,
        failureCode: 'malformed_id',
      );
    }
    if (!actor.capability.membershipWrite ||
        !actor.capability.rosterRead) {
      return const IsolationActivateResult(
        status: IsolationActivateStatus.unauthorised,
        failureCode: 'capability_denied',
      );
    }
    final publisher = graphStore.publisher(actor.publisherId);
    if (publisher == null) {
      return const IsolationActivateResult(
        status: IsolationActivateStatus.unavailable,
        failureCode: 'publisher_missing',
      );
    }

    if (pinnedAssignmentId != null) {
      final assignment = graphStore.assignment(pinnedAssignmentId);
      if (assignment == null) {
        return const IsolationActivateResult(
          status: IsolationActivateStatus.invalidInput,
          failureCode: 'assignment_not_found',
        );
      }
      if (assignment.athleteId != athleteId) {
        return const IsolationActivateResult(
          status: IsolationActivateStatus.invalidInput,
          failureCode: 'assignment_athlete_mismatch',
        );
      }
      final version = graphStore.programmeVersion(assignment.programmeVersionId);
      if (version == null) {
        return const IsolationActivateResult(
          status: IsolationActivateStatus.invalidInput,
          failureCode: 'pinned_version_missing',
        );
      }
      final programme = graphStore.programme(version.programmeId);
      if (programme == null || programme.ownerId != actor.publisherId) {
        return const IsolationActivateResult(
          status: IsolationActivateStatus.unauthorised,
          failureCode: 'foreign_programme_pin',
        );
      }
    }

    if (expectedGraphComposite != null && pinnedAssignmentId != null) {
      final assignment = graphStore.assignment(pinnedAssignmentId)!;
      final compiled = _compositeOf(assignment.programmeVersionId);
      if (compiled != expectedGraphComposite) {
        return const IsolationActivateResult(
          status: IsolationActivateStatus.staleManifest,
          failureCode: 'composite_mismatch',
        );
      }
    }

    final existingAthlete = memberships.activeForAthlete(athleteId);
    if (existingAthlete != null &&
        existingAthlete.publisherId != actor.publisherId) {
      return const IsolationActivateResult(
        status: IsolationActivateStatus.conflict,
        failureCode: 'cross_publisher_athlete',
      );
    }

    final id = membershipIdFor(
      publisherId: actor.publisherId,
      athleteId: athleteId,
    );
    final existing = memberships.membership(id);
    if (existing != null && existing.isActive) {
      if (existing.coachPrincipalId != actor.principalId) {
        return const IsolationActivateResult(
          status: IsolationActivateStatus.conflict,
          failureCode: 'principal_mismatch',
        );
      }
      if (pinnedAssignmentId != null &&
          existing.pinnedAssignmentId != null &&
          existing.pinnedAssignmentId != pinnedAssignmentId) {
        return const IsolationActivateResult(
          status: IsolationActivateStatus.assignmentPinned,
          failureCode: 'pin_immutable',
        );
      }
      return IsolationActivateResult(
        status: IsolationActivateStatus.alreadyActive,
        membership: existing,
      );
    }

    final created = TenantAthleteMembership(
      id: id,
      publisherId: actor.publisherId,
      athleteId: athleteId,
      coachPrincipalId: actor.principalId,
      status: IsolationMembershipStatus.active,
      pinnedAssignmentId: pinnedAssignmentId,
      expectedGraphComposite: expectedGraphComposite,
    );
    memberships.put(created);
    return IsolationActivateResult(
      status: IsolationActivateStatus.activated,
      membership: created,
    );
  }

  IsolationRosterResult? _authoriseRead(IsolationActor actor) {
    if (!_hasToken(actor.principalId) || !_hasToken(actor.publisherId)) {
      return const IsolationRosterResult(
        status: IsolationRosterStatus.invalidInput,
        failureCode: 'malformed_id',
      );
    }
    if (!actor.capability.rosterRead) {
      return const IsolationRosterResult(
        status: IsolationRosterStatus.unauthorised,
        failureCode: 'capability_denied',
      );
    }
    if (graphStore.publisher(actor.publisherId) == null) {
      return const IsolationRosterResult(
        status: IsolationRosterStatus.unavailable,
        failureCode: 'publisher_missing',
      );
    }
    return null;
  }

  IsolationRosterEntry _project(TenantAthleteMembership row) {
    String? versionId;
    String? composite;
    var usedBy = 0;
    var stale = false;
    final pinId = row.pinnedAssignmentId;
    if (pinId != null) {
      final assignment = graphStore.assignment(pinId);
      if (assignment != null) {
        versionId = assignment.programmeVersionId;
        composite = _compositeOf(versionId);
        usedBy = _exerciseCount(versionId);
        if (row.expectedGraphComposite != null &&
            row.expectedGraphComposite != composite) {
          stale = true;
        }
      }
    }
    return IsolationRosterEntry(
      membershipId: row.id,
      athleteId: row.athleteId,
      publisherId: row.publisherId,
      pinnedAssignmentId: pinId,
      pinnedProgrammeVersionId: versionId,
      graphCompositeIdentity: composite,
      usedByExerciseCount: usedBy,
      staleDeclaredComposite: stale,
    );
  }

  String? _compositeOf(String programmeVersionId) {
    return graph.compileDraft(programmeVersionId).manifest.compositeContentIdentity;
  }

  int _exerciseCount(String programmeVersionId) {
    final ids = <String>{};
    for (final placement in graphStore.placementsForVersion(programmeVersionId)) {
      for (final block in graphStore.blocksForSessionVersion(
        placement.sessionTemplateVersionId,
      )) {
        ids.addAll(block.exerciseIds);
      }
    }
    return ids.length;
  }

  bool _hasToken(String value) => value.trim().isNotEmpty;
}
