import '../../../data/repositories/programme_assignment_store.dart';
import '../../../models/programme_assignment.dart';
import '../models/athlete_catalogue_enrolment.dart';
import 'athlete_catalogue_enrolment_store.dart';

/// Sprint 1.3 catalogue enrolment orchestration.
///
/// Pins an exact catalogue-eligible `programme_version_id` for the signed-in
/// athlete. Does not perform payment, subscription, or plan materialisation.
class AthleteCatalogueEnrolmentService {
  const AthleteCatalogueEnrolmentService({
    required AthleteCatalogueEnrolmentStore enrolmentStore,
    ProgrammeAssignmentStore? assignmentStore,
  }) : _enrolmentStore = enrolmentStore,
       _assignmentStore = assignmentStore;

  final AthleteCatalogueEnrolmentStore _enrolmentStore;
  final ProgrammeAssignmentStore? _assignmentStore;

  Future<AthleteCatalogueEnrolmentResult> enrol({
    required String programmeVersionId,
    required String athleteId,
    String? timezone,
    bool replaceActive = false,
  }) async {
    final trimmedVersion = programmeVersionId.trim();
    final trimmedAthlete = athleteId.trim();

    final result = await _enrolmentStore.enrol(
      programmeVersionId: trimmedVersion,
      timezone: timezone,
      replaceActive: replaceActive,
    );

    if (result.isSuccess) {
      return result;
    }

    if (result.status == AthleteCatalogueEnrolmentStatus.failed) {
      final reconciled = await _reconcileAfterAmbiguousFailure(
        athleteId: trimmedAthlete,
        programmeVersionId: trimmedVersion,
      );
      if (reconciled != null) return reconciled;
    }

    return result;
  }

  Future<ProgrammeAssignment?> getActiveEnrolment({
    required String athleteId,
  }) async {
    final store = _assignmentStore;
    if (store == null) return null;
    return store.getActiveAssignment(athleteId.trim());
  }

  /// Builds the future materialisation handoff when enrolment succeeded.
  AthletePlanMaterialisationHandoff? materialisationHandoff(
    AthleteCatalogueEnrolmentResult result,
  ) {
    if (!result.isSuccess) return null;
    try {
      return AthletePlanMaterialisationHandoff.fromEnrolmentResult(result);
    } on ArgumentError {
      return null;
    }
  }

  Future<AthleteCatalogueEnrolmentResult?> _reconcileAfterAmbiguousFailure({
    required String athleteId,
    required String programmeVersionId,
  }) async {
    final store = _assignmentStore;
    if (store == null || athleteId.isEmpty || programmeVersionId.isEmpty) {
      return null;
    }

    try {
      final active = await store.getActiveAssignment(athleteId);
      if (active == null) return null;
      if (active.programmeVersionId.trim() != programmeVersionId) return null;

      return AthleteCatalogueEnrolmentResult(
        status: AthleteCatalogueEnrolmentStatus.alreadyEnrolled,
        enrolmentId: active.id,
        programmeVersionId: active.programmeVersionId,
        lineageCode: active.lineageCode,
        enrolmentSource: EnrolmentSourceDb.fromDb(active.enrolmentSource),
        athleteId: active.athleteId,
        message: 'You are already enrolled in this programme.',
      );
    } catch (_) {
      return null;
    }
  }
}
