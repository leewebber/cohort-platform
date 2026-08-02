import '../../../data/repositories/programme_assignment_store.dart';
import '../../../models/programme_assignment.dart';
import '../../athlete_profile/services/athlete_profile_session.dart';
import '../models/athlete_catalogue_enrolment.dart';
import '../models/athlete_plan_materialisation.dart';
import 'athlete_plan_materialisation_store.dart';

/// Sprint 1.4A Start Programme orchestration.
///
/// Materialises an enrolled exact-version assignment. Does not prepare
/// sessions, touch Home/today, or invoke Coach Brain.
class AthletePlanMaterialisationService {
  const AthletePlanMaterialisationService({
    required AthletePlanMaterialisationStore materialisationStore,
    ProgrammeAssignmentStore? assignmentStore,
    bool Function()? legacyHasActivePlan,
  }) : _materialisationStore = materialisationStore,
       _assignmentStore = assignmentStore,
       _legacyHasActivePlan =
           legacyHasActivePlan ?? _defaultLegacyHasActivePlan;

  final AthletePlanMaterialisationStore _materialisationStore;
  final ProgrammeAssignmentStore? _assignmentStore;
  final bool Function() _legacyHasActivePlan;

  static bool _defaultLegacyHasActivePlan() =>
      AthleteProfileSession.hasActivePlan;

  /// Explicit Start Programme for [programmeAssignmentId].
  ///
  /// Blocks when the local session reports a legacy Plan Library active plan.
  /// That check is client-only compatibility protection — not a database
  /// invariant.
  Future<AthletePlanMaterialisationResult> startProgramme({
    required String programmeAssignmentId,
    required String athleteId,
    String? timezone,
  }) async {
    if (_legacyHasActivePlan()) {
      return const AthletePlanMaterialisationResult(
        status: AthletePlanMaterialisationStatus.legacyPlanConflict,
        code: 'legacy_plan_library_active',
        message:
            'You already have an active plan on this device. '
            'Switching programmes is not available yet.',
      );
    }

    final trimmedAssignment = programmeAssignmentId.trim();
    final trimmedAthlete = athleteId.trim();

    final result = await _materialisationStore.materialise(
      programmeAssignmentId: trimmedAssignment,
      timezone: timezone,
    );

    if (result.isSuccess) {
      return result;
    }

    if (result.status == AthletePlanMaterialisationStatus.failed) {
      final reconciled = await _reconcileAfterAmbiguousFailure(
        athleteId: trimmedAthlete,
        programmeAssignmentId: trimmedAssignment,
      );
      if (reconciled != null) return reconciled;
    }

    return result;
  }

  /// Handoff from enrolment result — unchanged Sprint 1.3 contract.
  AthletePlanMaterialisationHandoff? handoffFromEnrolment(
    AthleteCatalogueEnrolmentResult result,
  ) {
    if (!result.isSuccess) return null;
    try {
      return AthletePlanMaterialisationHandoff.fromEnrolmentResult(result);
    } on ArgumentError {
      return null;
    }
  }

  Future<AthletePlanMaterialisationResult?> _reconcileAfterAmbiguousFailure({
    required String athleteId,
    required String programmeAssignmentId,
  }) async {
    final store = _assignmentStore;
    if (store == null || athleteId.isEmpty || programmeAssignmentId.isEmpty) {
      return null;
    }

    try {
      final active = await store.getActiveAssignment(athleteId);
      if (active == null) return null;
      if (active.id.trim() != programmeAssignmentId) return null;
      if (!active.isMaterialised) return null;

      return AthletePlanMaterialisationResult(
        status: AthletePlanMaterialisationStatus.alreadyMaterialised,
        enrolmentId: active.id,
        programmeVersionId: active.programmeVersionId,
        lineageCode: active.lineageCode,
        materialisedAt: active.materialisedAt,
        materialisationSource: active.materialisationSource,
        materialisedPackageContentHash: active.materialisedPackageContentHash,
        materialisedPackageSchemaVersion:
            active.materialisedPackageSchemaVersion,
        startedAt: active.startedAt,
        timezone: active.timezone,
        currentWeek: active.currentWeek,
        currentDayKey: active.currentDayKey,
        currentSlotOrder: active.currentSessionOrder,
        athleteId: active.athleteId,
        message: 'This programme is already started.',
      );
    } catch (_) {
      return null;
    }
  }
}

/// View helpers for programme screen presentation.
class AthletePlanMaterialisationLabels {
  const AthletePlanMaterialisationLabels._();

  static String statusLabel(ProgrammeAssignment assignment) {
    if (assignment.isMaterialised) {
      return 'Started · Week ${assignment.currentWeek} · '
          '${assignment.currentDayKey.replaceAll('_', ' ')}';
    }
    return 'Enrolled · Not started';
  }
}
