import 's17_occurrence_baseline.dart';

/// Athlete D-owned preparation to establish ≥2 uncompleted scheduled occurrences.
///
/// Does not mutate published programmes. When the retained Athlete D is still on
/// the one-slot catalogue lineage, preparation enrols/switches onto the published
/// multi-slot scheduling lineage through athlete-authenticated catalogue APIs
/// (executed later in B4d — never by creating a new athlete).

class S17SchedulePreparationRequest {
  const S17SchedulePreparationRequest({
    required this.athleteId,
    required this.currentLineageCode,
    required this.currentVersionId,
    required this.currentAssignmentId,
    this.targetSchedulingLineage =
        S17OccurrenceBaseline.multiSlotSchedulingLineage,
  });

  final String athleteId;
  final String currentLineageCode;
  final String currentVersionId;
  final String currentAssignmentId;
  final String targetSchedulingLineage;
}

class S17SchedulePreparationResult {
  const S17SchedulePreparationResult({
    required this.ok,
    required this.detail,
    this.assignmentId,
    this.versionId,
    this.lineageCode,
    this.packageHash,
    this.uncompletedOccurrences = 0,
    this.projectedOccurrences = 0,
    this.skippedBecauseAlreadyReady = false,
  });

  final bool ok;
  final String detail;
  final String? assignmentId;
  final String? versionId;
  final String? lineageCode;
  final String? packageHash;
  final int uncompletedOccurrences;
  final int projectedOccurrences;
  final bool skippedBecauseAlreadyReady;
}

/// Ports used by preparation — implemented by real services in Flutter entrypoint
/// and by fakes in local tests. Never looks up athletes by email/name/marker.
abstract class S17CatalogueVersionLookup {
  /// Resolves a published catalogue version id for [lineageCode] only.
  Future<S17CatalogueVersionRef?> findPublishedByLineage(String lineageCode);
}

class S17CatalogueVersionRef {
  const S17CatalogueVersionRef({
    required this.versionId,
    required this.lineageCode,
    required this.packageHash,
    required this.executableSlotCount,
  });

  final String versionId;
  final String lineageCode;
  final String packageHash;
  final int executableSlotCount;
}

abstract class S17AthleteEnrolmentPort {
  /// Enrols/switches the authenticated Athlete D onto [versionId].
  Future<S17EnrolmentOutcome> enrolOrSwitch({
    required String athleteId,
    required String versionId,
  });
}

class S17EnrolmentOutcome {
  const S17EnrolmentOutcome({
    required this.ok,
    required this.assignmentId,
    required this.versionId,
    this.detail = '',
  });

  final bool ok;
  final String assignmentId;
  final String versionId;
  final String detail;
}

abstract class S17PlanMaterialisePort {
  Future<bool> materialise({
    required String athleteId,
    required String assignmentId,
  });
}

abstract class S17ProjectionBaselinePort {
  Future<S17OccurrenceBaselineSnapshot> loadBaseline({
    required String athleteId,
    required String assignmentId,
    required String lineageCode,
    required int authoredExecutableSlotCount,
  });
}

/// Fail-closed preparation orchestrator (no athlete discovery).
class S17SchedulePreparation {
  S17SchedulePreparation({
    required S17CatalogueVersionLookup catalogue,
    required S17AthleteEnrolmentPort enrolment,
    required S17PlanMaterialisePort materialise,
    required S17ProjectionBaselinePort projection,
  }) : _catalogue = catalogue,
       _enrolment = enrolment,
       _materialise = materialise,
       _projection = projection;

  final S17CatalogueVersionLookup _catalogue;
  final S17AthleteEnrolmentPort _enrolment;
  final S17PlanMaterialisePort _materialise;
  final S17ProjectionBaselinePort _projection;

  Future<S17SchedulePreparationResult> ensureScheduleOpsBaseline(
    S17SchedulePreparationRequest request, {
    required S17OccurrenceBaselineSnapshot current,
  }) async {
    final fail = S17OccurrenceBaseline.failClosedReason(current);
    if (fail == null) {
      return S17SchedulePreparationResult(
        ok: true,
        detail: 'Baseline already has ≥2 uncompleted occurrences',
        assignmentId: request.currentAssignmentId,
        versionId: request.currentVersionId,
        lineageCode: request.currentLineageCode,
        uncompletedOccurrences: current.uncompletedOccurrenceCount,
        projectedOccurrences: current.projectedOccurrenceCount,
        skippedBecauseAlreadyReady: true,
      );
    }

    final diagnosis = S17OccurrenceBaseline.diagnose(current);
    if (!diagnosis.canPrepareViaMultiSlotEnrolment) {
      return S17SchedulePreparationResult(
        ok: false,
        detail:
            'Cannot prepare safely: ${diagnosis.cause.name} — ${diagnosis.detail}',
      );
    }

    final target = await _catalogue.findPublishedByLineage(
      request.targetSchedulingLineage,
    );
    if (target == null) {
      return S17SchedulePreparationResult(
        ok: false,
        detail:
            'REFUSED: published scheduling lineage '
            '${request.targetSchedulingLineage} not found in athlete catalogue',
      );
    }
    if (target.executableSlotCount <
        S17OccurrenceBaseline.requiredUncompletedForScheduleOps) {
      return S17SchedulePreparationResult(
        ok: false,
        detail:
            'REFUSED: target lineage ${target.lineageCode} has only '
            '${target.executableSlotCount} executable slots',
      );
    }
    if (target.versionId == request.currentVersionId) {
      return const S17SchedulePreparationResult(
        ok: false,
        detail: 'REFUSED: target version equals current one-slot version',
      );
    }

    final enrolled = await _enrolment.enrolOrSwitch(
      athleteId: request.athleteId,
      versionId: target.versionId,
    );
    if (!enrolled.ok) {
      return S17SchedulePreparationResult(
        ok: false,
        detail: 'Enrolment/switch failed: ${enrolled.detail}',
      );
    }

    final materialised = await _materialise.materialise(
      athleteId: request.athleteId,
      assignmentId: enrolled.assignmentId,
    );
    if (!materialised) {
      return S17SchedulePreparationResult(
        ok: false,
        detail: 'Materialisation failed after switch',
        assignmentId: enrolled.assignmentId,
        versionId: enrolled.versionId,
        lineageCode: target.lineageCode,
      );
    }

    final baseline = await _projection.loadBaseline(
      athleteId: request.athleteId,
      assignmentId: enrolled.assignmentId,
      lineageCode: target.lineageCode,
      authoredExecutableSlotCount: target.executableSlotCount,
    );
    final afterFail = S17OccurrenceBaseline.failClosedReason(baseline);
    if (afterFail != null) {
      return S17SchedulePreparationResult(
        ok: false,
        detail: afterFail,
        assignmentId: enrolled.assignmentId,
        versionId: enrolled.versionId,
        lineageCode: target.lineageCode,
        packageHash: target.packageHash,
        uncompletedOccurrences: baseline.uncompletedOccurrenceCount,
        projectedOccurrences: baseline.projectedOccurrenceCount,
      );
    }

    return S17SchedulePreparationResult(
      ok: true,
      detail:
          'Prepared via athlete-authenticated enrol/switch to '
          '${target.lineageCode}; uncompleted=${baseline.uncompletedOccurrenceCount}',
      assignmentId: enrolled.assignmentId,
      versionId: enrolled.versionId,
      lineageCode: target.lineageCode,
      packageHash: target.packageHash,
      uncompletedOccurrences: baseline.uncompletedOccurrenceCount,
      projectedOccurrences: baseline.projectedOccurrenceCount,
    );
  }
}
