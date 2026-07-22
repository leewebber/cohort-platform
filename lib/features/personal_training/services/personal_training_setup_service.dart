import '../../../data/repositories/programme_assignment_store.dart';
import '../../../data/repositories/programme_store_exception.dart';
import '../../../features/auth/services/current_user_session.dart';
import '../../../models/programme_vocabulary.dart';
import '../../coach_athlete/services/coach_athlete_service.dart';
import '../../programme/models/programme_assignment_operation_result.dart';
import '../../programme/models/programme_catalog_entry.dart';
import '../../programme/services/programme_assignment_service.dart';
import '../../programme/services/programme_catalog_service.dart';
import '../models/personal_training_operation_result.dart';

/// Orchestrates personal training setup for dual-role coach/athlete users.
///
/// Assignment rules remain in [ProgrammeAssignmentService]; this service only
/// authorizes self-assignment and resolves identities from [CurrentUserSession].
class PersonalTrainingSetupService {
  PersonalTrainingSetupService({
    ProgrammeAssignmentStore? assignmentStore,
    ProgrammeCatalogService? catalogService,
    ProgrammeAssignmentService? assignmentService,
  })  : _assignmentStore = assignmentStore,
        _catalogService = catalogService,
        _assignmentService = assignmentService;

  final ProgrammeAssignmentStore? _assignmentStore;
  final ProgrammeCatalogService? _catalogService;
  final ProgrammeAssignmentService? _assignmentService;

  bool get canSetupPersonalTraining {
    final session = CurrentUserSession.maybeInstance;
    return session != null && session.isCoach && session.isAthlete;
  }

  Future<PersonalTrainingCurrentAssignmentResult> getCurrentAssignment() async {
    final athleteId = _requireDualRoleAthleteId();
    if (athleteId == null) {
      return PersonalTrainingOperationResult.failure(
        status: PersonalTrainingOperationStatus.dualRoleRequired,
        message: 'Coach and athlete roles are required to set up personal training.',
      );
    }

    final store = _assignmentStore;
    if (store == null) {
      return PersonalTrainingOperationResult.failure(
        status: PersonalTrainingOperationStatus.failed,
        message: 'Assignment lookup is unavailable.',
      );
    }

    try {
      final assignment = await store.getActiveAssignment(athleteId);
      return PersonalTrainingOperationResult.success(assignment);
    } on ProgrammeStoreException catch (error) {
      return PersonalTrainingOperationResult.failure(
        status: PersonalTrainingOperationStatus.failed,
        message: error.message,
      );
    }
  }

  Future<PersonalTrainingCatalogueResult> listPublishedProgrammes() async {
    if (!canSetupPersonalTraining) {
      return PersonalTrainingOperationResult.failure(
        status: PersonalTrainingOperationStatus.dualRoleRequired,
        message: 'Coach and athlete roles are required to choose a programme.',
      );
    }

    final catalog = _catalogService;
    if (catalog == null) {
      return PersonalTrainingOperationResult.failure(
        status: PersonalTrainingOperationStatus.failed,
        message: 'Programme catalogue is unavailable.',
      );
    }

    try {
      final entries = await catalog.listCatalogue(
        query: const ProgrammeCatalogueQuery(
          lifecycleStatus: ProgrammeLifecycleStatus.published,
        ),
      );
      return PersonalTrainingOperationResult.success(entries);
    } catch (error) {
      return PersonalTrainingOperationResult.failure(
        status: PersonalTrainingOperationStatus.failed,
        message: error.toString(),
      );
    }
  }

  Future<PersonalTrainingAssignmentResult> assignProgrammeToSelf({
    required String programmeVersionId,
    required DateTime startedAt,
    required String timezone,
    bool replaceExistingActive = false,
  }) async {
    final athleteId = _requireDualRoleAthleteId();
    if (athleteId == null) {
      return PersonalTrainingOperationResult.failure(
        status: PersonalTrainingOperationStatus.dualRoleRequired,
        message: 'Coach and athlete roles are required to assign personal training.',
      );
    }

    final assignmentService = _assignmentService;
    if (assignmentService == null) {
      return PersonalTrainingOperationResult.failure(
        status: PersonalTrainingOperationStatus.failed,
        message: 'Assignment service is unavailable.',
      );
    }

    final accessible = await _isProgrammeVersionAccessible(programmeVersionId);
    if (!accessible) {
      return PersonalTrainingOperationResult.failure(
        status: PersonalTrainingOperationStatus.inaccessibleProgramme,
        message: 'That programme version is not available to assign.',
      );
    }

    final result = await assignmentService.assignProgramme(
      athleteId: athleteId,
      programmeVersionId: programmeVersionId,
      startedAt: startedAt,
      timezone: timezone,
      replaceExistingActive: replaceExistingActive,
    );

    if (!result.isSuccess) {
      return PersonalTrainingOperationResult.failure(
        status: PersonalTrainingOperationStatus.failed,
        message: _assignmentFailureMessage(result),
      );
    }

    final assignment = result.assignment;
    if (assignment == null) {
      return PersonalTrainingOperationResult.failure(
        status: PersonalTrainingOperationStatus.failed,
        message: 'Programme assignment did not complete.',
      );
    }

    return PersonalTrainingOperationResult.success(
      ProgrammeAssignmentOperationSummary(
        assignment: assignment,
        programmeName: assignment.lineageCode,
      ),
    );
  }

  String? _requireDualRoleAthleteId() {
    final session = CurrentUserSession.maybeInstance;
    if (session == null) return null;
    if (!session.isCoach || !session.isAthlete) return null;
    return session.athleteId;
  }

  Future<bool> _isProgrammeVersionAccessible(String programmeVersionId) async {
    final catalogue = await listPublishedProgrammes();
    if (!catalogue.isSuccess) return false;

    final trimmed = programmeVersionId.trim();
    return catalogue.value!.any((entry) => entry.versionId == trimmed);
  }

  String _assignmentFailureMessage(ProgrammeAssignmentOperationResult result) {
    if (result.status == ProgrammeAssignmentOperationStatus.alreadyActiveConflict) {
      return 'You already have an active programme. Confirm replacement to continue.';
    }
    if (result.warnings.isNotEmpty) {
      return result.warnings.first;
    }
    return 'Programme assignment failed.';
  }
}
