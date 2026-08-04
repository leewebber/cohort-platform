import 's17_occurrence_baseline.dart';

/// Athlete D-owned preparation to establish ≥2 uncompleted scheduled occurrences.
///
/// Fail-closed at every stage. Never silently continues on `PROG-S13-ELIG`.
/// Does not mutate published programmes. Never discovers or enumerates athletes.

/// First failing (or successful) preparation boundary for structured reports.
enum S17PreparationStage {
  alreadyReady,
  diagnosis,
  catalogueLookup,
  catalogueUnavailable,
  catalogueIneligible,
  incorrectTarget,
  existingEnrolment,
  enrolSwitch,
  enrolRejected,
  enrolMalformed,
  assignmentPostcondition,
  packageSelection,
  materialisation,
  preparedExecution,
  projectionRestore,
  reconstruction,
  uncompletedOccurrences,
  silentFallbackGuard,
  ready,
}

class S17SchedulePreparationRequest {
  const S17SchedulePreparationRequest({
    required this.athleteId,
    required this.currentLineageCode,
    required this.currentVersionId,
    required this.currentAssignmentId,
    this.targetSchedulingLineage =
        S17OccurrenceBaseline.multiSlotSchedulingLineage,
    this.resumeExistingEnrolmentOnly = false,
    this.currentIsMaterialised = false,
    this.authoredExecutableSlotCountHint = 0,
  });

  final String athleteId;
  final String currentLineageCode;
  final String currentVersionId;
  final String currentAssignmentId;
  final String targetSchedulingLineage;

  /// When true (B4d.3 resume), never enrol/switch/replaceActive — materialise
  /// the existing live S15A enrolment only.
  final bool resumeExistingEnrolmentOnly;
  final bool currentIsMaterialised;
  final int authoredExecutableSlotCountHint;
}

class S17SchedulePreparationResult {
  const S17SchedulePreparationResult({
    required this.ok,
    required this.detail,
    required this.stage,
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
  final S17PreparationStage stage;
  final String? assignmentId;
  final String? versionId;
  final String? lineageCode;
  final String? packageHash;
  final int uncompletedOccurrences;
  final int projectedOccurrences;
  final bool skippedBecauseAlreadyReady;

  /// Redacted one-line classification for PREREQ reporting (no full ids).
  String get classifiedDetail => 'PREP_FAIL stage=${stage.name} $detail';
}

class S17CatalogueVersionRef {
  const S17CatalogueVersionRef({
    required this.versionId,
    required this.lineageCode,
    required this.packageHash,
    required this.executableSlotCount,
    this.visible = true,
    this.eligible = true,
    this.ambiguous = false,
  });

  final String versionId;
  final String lineageCode;
  final String packageHash;
  final int executableSlotCount;
  final bool visible;
  final bool eligible;
  final bool ambiguous;
}

abstract class S17CatalogueVersionLookup {
  /// Resolves a published, athlete-visible catalogue version for [lineageCode].
  Future<S17CatalogueVersionRef?> findPublishedByLineage(String lineageCode);
}

class S17EnrolmentOutcome {
  const S17EnrolmentOutcome({
    required this.ok,
    this.assignmentId = '',
    this.versionId = '',
    this.lineageCode = '',
    this.detail = '',
    this.rejected = false,
    this.malformed = false,
  });

  final bool ok;
  final String assignmentId;
  final String versionId;
  final String lineageCode;
  final String detail;
  final bool rejected;
  final bool malformed;
}

abstract class S17AthleteEnrolmentPort {
  Future<S17EnrolmentOutcome> enrolOrSwitch({
    required String athleteId,
    required String versionId,
  });
}

/// Safe, redacted materialisation outcome for staging reports.
enum S17MaterialisationCallKind {
  success,
  typedRejection,
  transportOrRpcFailure,
  nullOrMalformed,
  emptyResult,
  postconditionMismatch,
}

class S17MaterialisationOutcome {
  const S17MaterialisationOutcome({
    required this.ok,
    required this.callKind,
    this.statusName = '',
    this.code = '',
    this.detail = '',
    this.attempted = true,
    this.returnedNormally = true,
  });

  final bool ok;
  final S17MaterialisationCallKind callKind;
  final String statusName;
  final String code;
  final String detail;
  final bool attempted;
  final bool returnedNormally;

  /// One-line report fragment — never includes credentials or full UUIDs.
  String get classifiedDetail {
    final codePart = code.trim().isEmpty ? 'none' : code.trim();
    final statusPart = statusName.trim().isEmpty
        ? 'unknown'
        : statusName.trim();
    return 'kind=${callKind.name} status=$statusPart code=$codePart '
        'attempted=$attempted returnedNormally=$returnedNormally $detail';
  }
}

abstract class S17PlanMaterialisePort {
  Future<S17MaterialisationOutcome> materialise({
    required String athleteId,
    required String assignmentId,
  });
}

class S17ActiveAssignmentView {
  const S17ActiveAssignmentView({
    required this.assignmentId,
    required this.versionId,
    required this.lineageCode,
    this.packageHash,
    this.isMaterialised = false,
  });

  final String assignmentId;
  final String versionId;
  final String lineageCode;
  final String? packageHash;
  final bool isMaterialised;
}

abstract class S17ActiveAssignmentPort {
  Future<S17ActiveAssignmentView?> getActive(String athleteId);
}

class S17PackageSelectionView {
  const S17PackageSelectionView({
    required this.versionId,
    required this.lineageCode,
    required this.packageHash,
  });

  final String versionId;
  final String lineageCode;
  final String packageHash;
}

abstract class S17PackageSelectionPort {
  Future<S17PackageSelectionView?> resolveForAssignment({
    required String athleteId,
    required String assignmentId,
  });
}

abstract class S17PreparedExecutionPort {
  Future<bool> isReadyForAssignment({
    required String athleteId,
    required String assignmentId,
    required String expectedVersionId,
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
    S17ActiveAssignmentPort? activeAssignment,
    S17PackageSelectionPort? packageSelection,
    S17PreparedExecutionPort? preparedExecution,
  }) : _catalogue = catalogue,
       _enrolment = enrolment,
       _materialise = materialise,
       _projection = projection,
       _activeAssignment = activeAssignment,
       _packageSelection = packageSelection,
       _preparedExecution = preparedExecution;

  final S17CatalogueVersionLookup _catalogue;
  final S17AthleteEnrolmentPort _enrolment;
  final S17PlanMaterialisePort _materialise;
  final S17ProjectionBaselinePort _projection;
  final S17ActiveAssignmentPort? _activeAssignment;
  final S17PackageSelectionPort? _packageSelection;
  final S17PreparedExecutionPort? _preparedExecution;

  Future<S17SchedulePreparationResult> ensureScheduleOpsBaseline(
    S17SchedulePreparationRequest request, {
    required S17OccurrenceBaselineSnapshot current,
  }) async {
    final targetLineage = request.targetSchedulingLineage.trim();
    if (targetLineage.isEmpty ||
        targetLineage == S17OccurrenceBaseline.oneSlotCatalogueLineage) {
      return S17SchedulePreparationResult(
        ok: false,
        stage: S17PreparationStage.incorrectTarget,
        detail:
            'REFUSED: target lineage must be the approved multi-slot programme '
            '(not ${S17OccurrenceBaseline.oneSlotCatalogueLineage})',
      );
    }

    if (request.resumeExistingEnrolmentOnly) {
      return _prepareExistingEnrolmentOnly(request, current: current);
    }

    final fail = S17OccurrenceBaseline.failClosedReason(current);
    if (fail == null) {
      if (current.lineageCode ==
          S17OccurrenceBaseline.oneSlotCatalogueLineage) {
        return const S17SchedulePreparationResult(
          ok: false,
          stage: S17PreparationStage.silentFallbackGuard,
          detail:
              'REFUSED: baseline must not remain on PROG-S13-ELIG for schedule ops',
        );
      }
      return S17SchedulePreparationResult(
        ok: true,
        stage: S17PreparationStage.alreadyReady,
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
        stage: S17PreparationStage.diagnosis,
        detail:
            'Cannot prepare safely: ${diagnosis.cause.name} — ${diagnosis.detail}',
      );
    }

    final target = await _catalogue.findPublishedByLineage(targetLineage);
    if (target == null) {
      return S17SchedulePreparationResult(
        ok: false,
        stage: S17PreparationStage.catalogueUnavailable,
        detail:
            'REFUSED: published scheduling lineage $targetLineage '
            'not found in athlete catalogue',
      );
    }
    if (target.ambiguous) {
      return S17SchedulePreparationResult(
        ok: false,
        stage: S17PreparationStage.catalogueLookup,
        detail: 'REFUSED: ambiguous catalogue match for $targetLineage',
      );
    }
    if (!target.visible) {
      return S17SchedulePreparationResult(
        ok: false,
        stage: S17PreparationStage.catalogueIneligible,
        detail: 'REFUSED: $targetLineage is not visible to Athlete D',
      );
    }
    if (!target.eligible) {
      return S17SchedulePreparationResult(
        ok: false,
        stage: S17PreparationStage.catalogueIneligible,
        detail: 'REFUSED: $targetLineage is not eligible for Athlete D',
      );
    }
    if (target.lineageCode.trim() != targetLineage) {
      return S17SchedulePreparationResult(
        ok: false,
        stage: S17PreparationStage.incorrectTarget,
        detail:
            'REFUSED: catalogue lineage ${target.lineageCode} != requested '
            '$targetLineage',
      );
    }
    if (target.versionId.trim().isEmpty) {
      return const S17SchedulePreparationResult(
        ok: false,
        stage: S17PreparationStage.incorrectTarget,
        detail: 'REFUSED: target version id empty',
      );
    }
    if (target.executableSlotCount <
        S17OccurrenceBaseline.requiredUncompletedForScheduleOps) {
      return S17SchedulePreparationResult(
        ok: false,
        stage: S17PreparationStage.catalogueIneligible,
        detail:
            'REFUSED: target lineage ${target.lineageCode} has only '
            '${target.executableSlotCount} executable slots',
      );
    }
    if (target.versionId == request.currentVersionId) {
      return const S17SchedulePreparationResult(
        ok: false,
        stage: S17PreparationStage.incorrectTarget,
        detail: 'REFUSED: target version equals current one-slot version',
      );
    }

    final enrolled = await _enrolment.enrolOrSwitch(
      athleteId: request.athleteId,
      versionId: target.versionId,
    );
    if (enrolled.malformed) {
      return S17SchedulePreparationResult(
        ok: false,
        stage: S17PreparationStage.enrolMalformed,
        detail: 'Enrol/switch response malformed: ${enrolled.detail}',
      );
    }
    if (enrolled.rejected || !enrolled.ok) {
      return S17SchedulePreparationResult(
        ok: false,
        stage: enrolled.rejected
            ? S17PreparationStage.enrolRejected
            : S17PreparationStage.enrolSwitch,
        detail: 'Enrolment/switch failed: ${enrolled.detail}',
      );
    }
    if (enrolled.assignmentId.trim().isEmpty ||
        enrolled.versionId.trim().isEmpty) {
      return S17SchedulePreparationResult(
        ok: false,
        stage: S17PreparationStage.enrolMalformed,
        detail: 'Enrol/switch returned empty assignment or version',
      );
    }
    if (enrolled.versionId.trim() != target.versionId.trim()) {
      return S17SchedulePreparationResult(
        ok: false,
        stage: S17PreparationStage.enrolMalformed,
        detail: 'Enrol/switch version does not match catalogue target',
      );
    }

    final activePort = _activeAssignment;
    if (activePort != null) {
      final active = await activePort.getActive(request.athleteId);
      if (active == null) {
        return S17SchedulePreparationResult(
          ok: false,
          stage: S17PreparationStage.assignmentPostcondition,
          detail: 'No active assignment after enrol/switch',
          assignmentId: enrolled.assignmentId,
          versionId: enrolled.versionId,
          lineageCode: target.lineageCode,
        );
      }
      if (active.versionId.trim() != target.versionId.trim() ||
          active.lineageCode.trim() != targetLineage ||
          active.lineageCode.trim() ==
              S17OccurrenceBaseline.oneSlotCatalogueLineage) {
        return S17SchedulePreparationResult(
          ok: false,
          stage: S17PreparationStage.assignmentPostcondition,
          detail:
              'Active assignment still lineage=${active.lineageCode} '
              '(expected $targetLineage); silent PROG-S13-ELIG fallback refused',
          assignmentId: active.assignmentId,
          versionId: active.versionId,
          lineageCode: active.lineageCode,
        );
      }
    }

    final materialised = await _materialise.materialise(
      athleteId: request.athleteId,
      assignmentId: enrolled.assignmentId,
    );
    if (!materialised.ok) {
      return S17SchedulePreparationResult(
        ok: false,
        stage: S17PreparationStage.materialisation,
        detail:
            'Materialisation failed after switch; '
            '${materialised.classifiedDetail}',
        assignmentId: enrolled.assignmentId,
        versionId: enrolled.versionId,
        lineageCode: target.lineageCode,
      );
    }

    final packagePort = _packageSelection;
    if (packagePort != null) {
      final pkg = await packagePort.resolveForAssignment(
        athleteId: request.athleteId,
        assignmentId: enrolled.assignmentId,
      );
      if (pkg == null ||
          pkg.packageHash.trim().isEmpty ||
          pkg.versionId.trim() != target.versionId.trim() ||
          pkg.lineageCode.trim() != targetLineage) {
        return S17SchedulePreparationResult(
          ok: false,
          stage: S17PreparationStage.packageSelection,
          detail:
              'Selected plan-package missing or not belonging to $targetLineage',
          assignmentId: enrolled.assignmentId,
          versionId: enrolled.versionId,
          lineageCode: target.lineageCode,
        );
      }
    }

    final preparedPort = _preparedExecution;
    if (preparedPort != null) {
      final ready = await preparedPort.isReadyForAssignment(
        athleteId: request.athleteId,
        assignmentId: enrolled.assignmentId,
        expectedVersionId: target.versionId,
      );
      if (!ready) {
        return S17SchedulePreparationResult(
          ok: false,
          stage: S17PreparationStage.preparedExecution,
          detail: 'Prepared execution not ready for intended assignment',
          assignmentId: enrolled.assignmentId,
          versionId: enrolled.versionId,
          lineageCode: target.lineageCode,
        );
      }
    }

    final baseline = await _projection.loadBaseline(
      athleteId: request.athleteId,
      assignmentId: enrolled.assignmentId,
      lineageCode: target.lineageCode,
      authoredExecutableSlotCount: target.executableSlotCount,
    );

    if (baseline.lineageCode.trim() != targetLineage ||
        baseline.lineageCode.trim() ==
            S17OccurrenceBaseline.oneSlotCatalogueLineage) {
      return S17SchedulePreparationResult(
        ok: false,
        stage: S17PreparationStage.reconstruction,
        detail:
            'Reconstruction retained lineage=${baseline.lineageCode}; '
            'expected $targetLineage',
        assignmentId: enrolled.assignmentId,
        versionId: enrolled.versionId,
        lineageCode: baseline.lineageCode,
        packageHash: target.packageHash,
        uncompletedOccurrences: baseline.uncompletedOccurrenceCount,
        projectedOccurrences: baseline.projectedOccurrenceCount,
      );
    }

    final afterFail = S17OccurrenceBaseline.failClosedReason(baseline);
    if (afterFail != null) {
      return S17SchedulePreparationResult(
        ok: false,
        stage: S17PreparationStage.uncompletedOccurrences,
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
      stage: S17PreparationStage.ready,
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

  /// B4d.3 resume: materialise existing live S15A enrolment; never enrol/switch.
  Future<S17SchedulePreparationResult> _prepareExistingEnrolmentOnly(
    S17SchedulePreparationRequest request, {
    required S17OccurrenceBaselineSnapshot current,
  }) async {
    final targetLineage = request.targetSchedulingLineage.trim();
    final liveLineage = request.currentLineageCode.trim();
    final liveAssignment = request.currentAssignmentId.trim();
    final liveVersion = request.currentVersionId.trim();

    if (liveLineage == S17OccurrenceBaseline.oneSlotCatalogueLineage) {
      return const S17SchedulePreparationResult(
        ok: false,
        stage: S17PreparationStage.silentFallbackGuard,
        detail: 'REFUSED: resume cannot use PROG-S13-ELIG',
      );
    }
    if (liveLineage != targetLineage ||
        targetLineage != S17OccurrenceBaseline.multiSlotSchedulingLineage) {
      return S17SchedulePreparationResult(
        ok: false,
        stage: S17PreparationStage.incorrectTarget,
        detail:
            'REFUSED: resume requires live lineage '
            '${S17OccurrenceBaseline.multiSlotSchedulingLineage}; got $liveLineage',
      );
    }
    if (liveAssignment.isEmpty || liveVersion.isEmpty) {
      return const S17SchedulePreparationResult(
        ok: false,
        stage: S17PreparationStage.existingEnrolment,
        detail: 'REFUSED: live assignment/version missing',
      );
    }

    // B4d.5: never rematerialise an already-materialised assignment.
    if (request.currentIsMaterialised) {
      return _finishExistingMaterialisedEnrolment(
        request,
        current: current,
        liveAssignment: liveAssignment,
        liveVersion: liveVersion,
        liveLineage: liveLineage,
        targetLineage: targetLineage,
      );
    }

    // Catalogue metadata only (read) — never enrol/switch.
    final target = await _catalogue.findPublishedByLineage(targetLineage);
    if (target == null) {
      return S17SchedulePreparationResult(
        ok: false,
        stage: S17PreparationStage.catalogueUnavailable,
        detail:
            'REFUSED: published scheduling lineage $targetLineage '
            'not found in athlete catalogue',
      );
    }
    if (target.versionId.trim() != liveVersion) {
      return S17SchedulePreparationResult(
        ok: false,
        stage: S17PreparationStage.incorrectTarget,
        detail:
            'REFUSED: catalogue version does not match live S15A assignment version',
      );
    }
    if (target.executableSlotCount <
        S17OccurrenceBaseline.requiredUncompletedForScheduleOps) {
      return S17SchedulePreparationResult(
        ok: false,
        stage: S17PreparationStage.catalogueIneligible,
        detail:
            'REFUSED: target lineage has only ${target.executableSlotCount} slots',
      );
    }

    final activePort = _activeAssignment;
    if (activePort != null) {
      final active = await activePort.getActive(request.athleteId);
      if (active == null ||
          active.assignmentId.trim() != liveAssignment ||
          active.versionId.trim() != liveVersion ||
          active.lineageCode.trim() != targetLineage) {
        return S17SchedulePreparationResult(
          ok: false,
          stage: S17PreparationStage.assignmentPostcondition,
          detail:
              'REFUSED: active assignment drifted from bound live S15A enrolment',
          assignmentId: active?.assignmentId,
          versionId: active?.versionId,
          lineageCode: active?.lineageCode,
        );
      }
    }

    // Explicitly do not call enrolment — resumeExistingEnrolmentOnly.
    final materialised = await _materialise.materialise(
      athleteId: request.athleteId,
      assignmentId: liveAssignment,
    );
    if (!materialised.ok) {
      return S17SchedulePreparationResult(
        ok: false,
        stage: S17PreparationStage.materialisation,
        detail:
            'Materialisation failed for existing S15A enrolment; '
            '${materialised.classifiedDetail}',
        assignmentId: liveAssignment,
        versionId: liveVersion,
        lineageCode: liveLineage,
      );
    }

    final packagePort = _packageSelection;
    String packageHash = target.packageHash;
    if (packagePort != null) {
      final pkg = await packagePort.resolveForAssignment(
        athleteId: request.athleteId,
        assignmentId: liveAssignment,
      );
      if (pkg == null ||
          pkg.packageHash.trim().isEmpty ||
          pkg.versionId.trim() != liveVersion ||
          pkg.lineageCode.trim() != targetLineage) {
        return S17SchedulePreparationResult(
          ok: false,
          stage: S17PreparationStage.packageSelection,
          detail:
              'Selected plan-package missing or not belonging to $targetLineage',
          assignmentId: liveAssignment,
          versionId: liveVersion,
          lineageCode: liveLineage,
        );
      }
      packageHash = pkg.packageHash;
    }

    final preparedPort = _preparedExecution;
    if (preparedPort != null) {
      final ready = await preparedPort.isReadyForAssignment(
        athleteId: request.athleteId,
        assignmentId: liveAssignment,
        expectedVersionId: liveVersion,
      );
      if (!ready) {
        return S17SchedulePreparationResult(
          ok: false,
          stage: S17PreparationStage.preparedExecution,
          detail: 'Prepared execution not ready for live S15A assignment',
          assignmentId: liveAssignment,
          versionId: liveVersion,
          lineageCode: liveLineage,
          packageHash: packageHash,
        );
      }
    }

    final authored = request.authoredExecutableSlotCountHint > 0
        ? request.authoredExecutableSlotCountHint
        : target.executableSlotCount;
    final baseline = await _projection.loadBaseline(
      athleteId: request.athleteId,
      assignmentId: liveAssignment,
      lineageCode: liveLineage,
      authoredExecutableSlotCount: authored,
    );
    if (baseline.lineageCode.trim() != targetLineage ||
        baseline.lineageCode.trim() ==
            S17OccurrenceBaseline.oneSlotCatalogueLineage) {
      return S17SchedulePreparationResult(
        ok: false,
        stage: S17PreparationStage.reconstruction,
        detail:
            'Reconstruction retained lineage=${baseline.lineageCode}; '
            'expected $targetLineage',
        assignmentId: liveAssignment,
        versionId: liveVersion,
        lineageCode: baseline.lineageCode,
        packageHash: packageHash,
        uncompletedOccurrences: baseline.uncompletedOccurrenceCount,
        projectedOccurrences: baseline.projectedOccurrenceCount,
      );
    }
    final afterFail = S17OccurrenceBaseline.failClosedReason(baseline);
    if (afterFail != null) {
      return S17SchedulePreparationResult(
        ok: false,
        stage: S17PreparationStage.uncompletedOccurrences,
        detail: afterFail,
        assignmentId: liveAssignment,
        versionId: liveVersion,
        lineageCode: liveLineage,
        packageHash: packageHash,
        uncompletedOccurrences: baseline.uncompletedOccurrenceCount,
        projectedOccurrences: baseline.projectedOccurrenceCount,
      );
    }

    return S17SchedulePreparationResult(
      ok: true,
      stage: S17PreparationStage.ready,
      detail:
          'Prepared existing S15A enrolment (enrol/switch skipped); '
          'uncompleted=${baseline.uncompletedOccurrenceCount}',
      assignmentId: liveAssignment,
      versionId: liveVersion,
      lineageCode: liveLineage,
      packageHash: packageHash,
      uncompletedOccurrences: baseline.uncompletedOccurrenceCount,
      projectedOccurrences: baseline.projectedOccurrenceCount,
    );
  }

  /// Already materialised: validate package/prepared/projection only — never
  /// call materialise again (B4d.5).
  Future<S17SchedulePreparationResult> _finishExistingMaterialisedEnrolment(
    S17SchedulePreparationRequest request, {
    required S17OccurrenceBaselineSnapshot current,
    required String liveAssignment,
    required String liveVersion,
    required String liveLineage,
    required String targetLineage,
  }) async {
    final activePort = _activeAssignment;
    if (activePort != null) {
      final active = await activePort.getActive(request.athleteId);
      if (active == null ||
          active.assignmentId.trim() != liveAssignment ||
          active.versionId.trim() != liveVersion ||
          active.lineageCode.trim() != targetLineage ||
          !active.isMaterialised) {
        return S17SchedulePreparationResult(
          ok: false,
          stage: S17PreparationStage.assignmentPostcondition,
          detail:
              'REFUSED: materialised S15A assignment postcondition failed '
              '(no rematerialisation)',
          assignmentId: active?.assignmentId,
          versionId: active?.versionId,
          lineageCode: active?.lineageCode,
        );
      }
    }

    final packagePort = _packageSelection;
    String? packageHash;
    if (packagePort != null) {
      final pkg = await packagePort.resolveForAssignment(
        athleteId: request.athleteId,
        assignmentId: liveAssignment,
      );
      if (pkg == null ||
          pkg.packageHash.trim().isEmpty ||
          pkg.versionId.trim() != liveVersion ||
          pkg.lineageCode.trim() != targetLineage) {
        return S17SchedulePreparationResult(
          ok: false,
          stage: S17PreparationStage.packageSelection,
          detail:
              'Selected plan-package missing or not belonging to $targetLineage '
              '(no rematerialisation)',
          assignmentId: liveAssignment,
          versionId: liveVersion,
          lineageCode: liveLineage,
        );
      }
      packageHash = pkg.packageHash;
    }

    final preparedPort = _preparedExecution;
    if (preparedPort != null) {
      final ready = await preparedPort.isReadyForAssignment(
        athleteId: request.athleteId,
        assignmentId: liveAssignment,
        expectedVersionId: liveVersion,
      );
      if (!ready) {
        return S17SchedulePreparationResult(
          ok: false,
          stage: S17PreparationStage.preparedExecution,
          detail:
              'Prepared execution not ready for materialised S15A assignment '
              '(no rematerialisation)',
          assignmentId: liveAssignment,
          versionId: liveVersion,
          lineageCode: liveLineage,
          packageHash: packageHash,
        );
      }
    }

    final authored = request.authoredExecutableSlotCountHint > 0
        ? request.authoredExecutableSlotCountHint
        : current.authoredExecutableSlotCount;
    final baseline = await _projection.loadBaseline(
      athleteId: request.athleteId,
      assignmentId: liveAssignment,
      lineageCode: liveLineage,
      authoredExecutableSlotCount: authored > 0
          ? authored
          : current.projectedOccurrenceCount,
    );
    if (baseline.lineageCode.trim() != targetLineage ||
        baseline.lineageCode.trim() ==
            S17OccurrenceBaseline.oneSlotCatalogueLineage) {
      return S17SchedulePreparationResult(
        ok: false,
        stage: S17PreparationStage.reconstruction,
        detail:
            'Reconstruction retained lineage=${baseline.lineageCode}; '
            'expected $targetLineage (no rematerialisation)',
        assignmentId: liveAssignment,
        versionId: liveVersion,
        lineageCode: baseline.lineageCode,
        packageHash: packageHash,
        uncompletedOccurrences: baseline.uncompletedOccurrenceCount,
        projectedOccurrences: baseline.projectedOccurrenceCount,
      );
    }
    final afterFail = S17OccurrenceBaseline.failClosedReason(baseline);
    if (afterFail != null) {
      return S17SchedulePreparationResult(
        ok: false,
        stage: S17PreparationStage.uncompletedOccurrences,
        detail: '$afterFail (no rematerialisation)',
        assignmentId: liveAssignment,
        versionId: liveVersion,
        lineageCode: liveLineage,
        packageHash: packageHash,
        uncompletedOccurrences: baseline.uncompletedOccurrenceCount,
        projectedOccurrences: baseline.projectedOccurrenceCount,
      );
    }

    return S17SchedulePreparationResult(
      ok: true,
      stage: S17PreparationStage.alreadyReady,
      detail:
          'Reused materialised S15A enrolment (materialisation skipped); '
          'uncompleted=${baseline.uncompletedOccurrenceCount}',
      assignmentId: liveAssignment,
      versionId: liveVersion,
      lineageCode: liveLineage,
      packageHash: packageHash,
      uncompletedOccurrences: baseline.uncompletedOccurrenceCount,
      projectedOccurrences: baseline.projectedOccurrenceCount,
      skippedBecauseAlreadyReady: true,
    );
  }
}
