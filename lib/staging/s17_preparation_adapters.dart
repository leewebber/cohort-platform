import '../data/repositories/programme_assignment_store.dart';
import '../data/repositories/programme_version_store.dart';
import '../features/programme/models/athlete_catalogue_enrolment.dart';
import '../features/programme/models/athlete_plan_materialisation.dart';
import '../features/programme/models/programme_template.dart';
import '../features/programme/services/athlete_catalogue_enrolment_service.dart';
import '../features/programme/services/athlete_plan_materialisation_service.dart';
import '../features/programme/services/athlete_programme_session_prepare_service.dart';
import '../features/programme/services/athlete_programme_switch_catalog_service.dart';
import '../features/programme/services/programme_schedule_restore_service.dart';
import '../domain/session_occurrence/value_objects/session_occurrence_date.dart';
import 's17_occurrence_baseline.dart';
import 's17_schedule_preparation.dart';

/// Athlete-authenticated catalogue lookup for preparation (read then enrol).
class S17AthleteCatalogueLookupAdapter implements S17CatalogueVersionLookup {
  S17AthleteCatalogueLookupAdapter({
    required AthleteProgrammeSwitchCatalogService catalog,
    required ProgrammeVersionStore versionStore,
  }) : _catalog = catalog,
       _versionStore = versionStore;

  final AthleteProgrammeSwitchCatalogService _catalog;
  final ProgrammeVersionStore _versionStore;

  @override
  Future<S17CatalogueVersionRef?> findPublishedByLineage(
    String lineageCode,
  ) async {
    final wanted = lineageCode.trim();
    if (wanted.isEmpty) return null;
    final entries = await _catalog.listPublishedAssignableProgrammes();
    final matches = entries
        .where((e) => e.lineageCode.trim() == wanted)
        .toList(growable: false);
    if (matches.isEmpty) return null;
    if (matches.length > 1) {
      return S17CatalogueVersionRef(
        versionId: matches.first.versionId,
        lineageCode: wanted,
        packageHash: '',
        executableSlotCount: 0,
        ambiguous: true,
      );
    }
    final entry = matches.first;
    final version = await _versionStore.getVersionById(entry.versionId);
    final tree = await _versionStore.loadTemplateTree(entry.versionId);
    final slots = _countExecutableSlots(tree);
    return S17CatalogueVersionRef(
      versionId: entry.versionId,
      lineageCode: entry.lineageCode,
      packageHash: version?.packageContentHash?.trim() ?? '',
      executableSlotCount: slots,
      visible: true,
      eligible: !entry.hasBlockingValidationErrors && entry.archivedAt == null,
    );
  }

  static int _countExecutableSlots(ProgrammeTemplateTree? tree) {
    if (tree == null) return 0;
    var count = 0;
    final weeks = List<ProgrammeTemplateWeekNode>.from(tree.weekNodes)
      ..sort(
        (left, right) => left.week.weekNumber.compareTo(right.week.weekNumber),
      );
    for (final week in weeks) {
      for (final day in week.sortedDays) {
        if (day.day.isRestDay) continue;
        for (final slot in day.sortedSlots) {
          if (slot.protocolId.trim().isEmpty) continue;
          count += 1;
        }
      }
    }
    return count;
  }
}

/// Enrolment port that always refuses — used in B4d.3 resume to prove
/// enrol/switch/replaceActive cannot run.
class S17RefuseEnrolmentAdapter implements S17AthleteEnrolmentPort {
  const S17RefuseEnrolmentAdapter();

  @override
  Future<S17EnrolmentOutcome> enrolOrSwitch({
    required String athleteId,
    required String versionId,
  }) async {
    return const S17EnrolmentOutcome(
      ok: false,
      rejected: true,
      detail: 'REFUSED: enrol/switch/replaceActive forbidden in resume binding',
    );
  }
}

class S17AthleteEnrolmentAdapter implements S17AthleteEnrolmentPort {
  S17AthleteEnrolmentAdapter({
    required AthleteCatalogueEnrolmentService enrolment,
  }) : _enrolment = enrolment;

  final AthleteCatalogueEnrolmentService _enrolment;

  /// Same timezone the Athlete D creator fixture uses for enrolment.
  /// Required by materialisation when assignment.timezone would otherwise be null.
  static const athleteTimezone = 'UTC';

  @override
  Future<S17EnrolmentOutcome> enrolOrSwitch({
    required String athleteId,
    required String versionId,
  }) async {
    final result = await _enrolment.enrol(
      programmeVersionId: versionId,
      athleteId: athleteId,
      timezone: athleteTimezone,
      replaceActive: true,
    );
    if (!result.isSuccess) {
      return S17EnrolmentOutcome(
        ok: false,
        rejected:
            result.status == AthleteCatalogueEnrolmentStatus.conflict ||
            result.status ==
                AthleteCatalogueEnrolmentStatus.authorizationFailure ||
            result.status ==
                AthleteCatalogueEnrolmentStatus.validationFailure ||
            result.status == AthleteCatalogueEnrolmentStatus.failed,
        detail: 'status=${result.status.name} code=${result.code ?? 'none'}',
      );
    }
    final assignmentId = result.enrolmentId?.trim() ?? '';
    final enrolledVersion = result.programmeVersionId?.trim() ?? '';
    if (assignmentId.isEmpty || enrolledVersion.isEmpty) {
      return S17EnrolmentOutcome(
        ok: false,
        malformed: true,
        detail: 'null or empty enrolment_id/programme_version_id',
      );
    }
    if (enrolledVersion != versionId.trim()) {
      return S17EnrolmentOutcome(
        ok: false,
        malformed: true,
        detail: 'enrolment version mismatch vs requested target',
      );
    }
    return S17EnrolmentOutcome(
      ok: true,
      assignmentId: assignmentId,
      versionId: enrolledVersion,
      lineageCode: result.lineageCode?.trim() ?? '',
      detail: 'status=${result.status.name}',
    );
  }
}

class S17PlanMaterialiseAdapter implements S17PlanMaterialisePort {
  S17PlanMaterialiseAdapter({
    required AthletePlanMaterialisationService materialise,
  }) : _materialise = materialise;

  final AthletePlanMaterialisationService _materialise;

  @override
  Future<S17MaterialisationOutcome> materialise({
    required String athleteId,
    required String assignmentId,
  }) async {
    if (assignmentId.trim().isEmpty) {
      return const S17MaterialisationOutcome(
        ok: false,
        callKind: S17MaterialisationCallKind.nullOrMalformed,
        statusName: 'validationFailure',
        code: 'invalid_args',
        detail: 'empty assignment id',
        attempted: false,
        returnedNormally: true,
      );
    }
    try {
      final result = await _materialise.startProgramme(
        programmeAssignmentId: assignmentId,
        athleteId: athleteId,
        timezone: S17AthleteEnrolmentAdapter.athleteTimezone,
      );
      final code = result.code?.trim() ?? '';
      final statusName = result.status.name;
      if (result.isSuccess) {
        return S17MaterialisationOutcome(
          ok: true,
          callKind: S17MaterialisationCallKind.success,
          statusName: statusName,
          code: code.isEmpty ? 'ok' : code,
          detail: 'materialisation succeeded',
        );
      }
      final kind = switch (result.status) {
        AthletePlanMaterialisationStatus.authorizationFailure ||
        AthletePlanMaterialisationStatus.validationFailure ||
        AthletePlanMaterialisationStatus.conflict ||
        AthletePlanMaterialisationStatus.legacyPlanConflict =>
          S17MaterialisationCallKind.typedRejection,
        AthletePlanMaterialisationStatus.failed =>
          code == 'client_error'
              ? S17MaterialisationCallKind.transportOrRpcFailure
              : S17MaterialisationCallKind.typedRejection,
        AthletePlanMaterialisationStatus.materialised ||
        AthletePlanMaterialisationStatus.alreadyMaterialised =>
          S17MaterialisationCallKind.postconditionMismatch,
      };
      return S17MaterialisationOutcome(
        ok: false,
        callKind: kind,
        statusName: statusName,
        code: code.isEmpty ? 'none' : _safeCode(code),
        detail: 'typed materialisation rejection',
      );
    } catch (_) {
      return const S17MaterialisationOutcome(
        ok: false,
        callKind: S17MaterialisationCallKind.transportOrRpcFailure,
        statusName: 'failed',
        code: 'client_error',
        detail: 'uncaught client exception (redacted)',
        returnedNormally: false,
      );
    }
  }

  static String _safeCode(String code) {
    // Stable product codes only — reject free-form payloads.
    final trimmed = code.trim();
    if (trimmed.length > 64) return 'code_truncated';
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(trimmed)) return 'code_redacted';
    return trimmed;
  }
}

class S17ActiveAssignmentAdapter implements S17ActiveAssignmentPort {
  S17ActiveAssignmentAdapter({required ProgrammeAssignmentStore store})
    : _store = store;

  final ProgrammeAssignmentStore _store;

  @override
  Future<S17ActiveAssignmentView?> getActive(String athleteId) async {
    final active = await _store.getActiveAssignment(athleteId);
    if (active == null) return null;
    return S17ActiveAssignmentView(
      assignmentId: active.id,
      versionId: active.programmeVersionId,
      lineageCode: active.lineageCode,
      packageHash: active.materialisedPackageContentHash,
      isMaterialised: active.isMaterialised,
    );
  }
}

class S17PackageSelectionAdapter implements S17PackageSelectionPort {
  S17PackageSelectionAdapter({
    required ProgrammeAssignmentStore assignmentStore,
    required ProgrammeVersionStore versionStore,
  }) : _assignmentStore = assignmentStore,
       _versionStore = versionStore;

  final ProgrammeAssignmentStore _assignmentStore;
  final ProgrammeVersionStore _versionStore;

  @override
  Future<S17PackageSelectionView?> resolveForAssignment({
    required String athleteId,
    required String assignmentId,
  }) async {
    final active = await _assignmentStore.getActiveAssignment(athleteId);
    if (active == null || active.id != assignmentId) return null;
    final hash = active.materialisedPackageContentHash?.trim() ?? '';
    if (hash.isEmpty || !active.isMaterialised) return null;
    final version = await _versionStore.getVersionById(
      active.programmeVersionId,
    );
    final versionHash = version?.packageContentHash?.trim() ?? '';
    if (versionHash.isEmpty || versionHash != hash) return null;
    return S17PackageSelectionView(
      versionId: active.programmeVersionId,
      lineageCode: active.lineageCode,
      packageHash: hash,
    );
  }
}

class S17PreparedExecutionAdapter implements S17PreparedExecutionPort {
  S17PreparedExecutionAdapter({
    required AthleteProgrammeSessionPrepareService prepare,
  }) : _prepare = prepare;

  final AthleteProgrammeSessionPrepareService _prepare;

  @override
  Future<bool> isReadyForAssignment({
    required String athleteId,
    required String assignmentId,
    required String expectedVersionId,
  }) async {
    final prepared = await _prepare.prepareForAthlete(athleteId);
    if (!prepared.isReady || prepared.package == null) return false;
    final pkg = prepared.package!;
    final pkgAssignment = pkg.assignmentId?.trim() ?? '';
    final pkgVersion = pkg.programmeVersionId?.trim() ?? '';
    if (pkgAssignment.isNotEmpty && pkgAssignment != assignmentId) {
      return false;
    }
    return pkgVersion == expectedVersionId.trim();
  }
}

class S17ProjectionBaselineAdapter implements S17ProjectionBaselinePort {
  S17ProjectionBaselineAdapter({
    required ProgrammeScheduleRestoreService restore,
  }) : _restore = restore;

  final ProgrammeScheduleRestoreService _restore;

  @override
  Future<S17OccurrenceBaselineSnapshot> loadBaseline({
    required String athleteId,
    required String assignmentId,
    required String lineageCode,
    int? authoredExecutableSlotCount,
  }) async {
    final restored = await _restore.ensureAndRestore(
      athleteId: athleteId,
      programmeAssignmentId: assignmentId,
    );
    if (!restored.isSuccess || restored.projection == null) {
      return S17OccurrenceBaselineSnapshot(
        authoredExecutableSlotCount: authoredExecutableSlotCount,
        projectedOccurrenceCount: 0,
        uncompletedOccurrenceCount: 0,
        completedOrSkippedCount: 0,
        lineageCode: lineageCode,
      );
    }
    final today = SessionOccurrenceDate.fromDateTime(DateTime.now().toUtc());
    final snapshot = _restore.snapshotForPreview(
      projection: restored.projection!,
      today: today,
    );
    final uncompleted = snapshot.projection.occurrences
        .where((o) => o.isUncompleted)
        .length;
    final projected = snapshot.projection.occurrences.length;
    return S17OccurrenceBaselineSnapshot(
      authoredExecutableSlotCount: authoredExecutableSlotCount,
      projectedOccurrenceCount: projected,
      uncompletedOccurrenceCount: uncompleted,
      completedOrSkippedCount: projected - uncompleted,
      lineageCode: lineageCode,
      schedulingHorizonEnd: snapshot.schedulingHorizonEnd?.toString(),
    );
  }
}
