import '../../../core/services/current_coach_identity.dart';
import '../../../core/services/training_content_id_generator.dart';
import '../../../features/admin/services/protocol_builder_service.dart';
import '../../coach_studio/programmes/controllers/programme_editor_controller.dart';
import '../../training_library/services/session_library_authoring_coordinator.dart';
import '../../training_library/services/session_library_authoring_services.dart';
import '../models/programme_builder_document.dart';
import '../models/programme_builder_operation_result.dart';
import '../ports/programme_session_assignment_port.dart';
import '../ports/programme_editor_session_assignment_port.dart';
import '../../session_builder/services/session_clone_service.dart';
import 'cohort_protocol_customisation_coordinator.dart';
import 'programme_session_authoring_coordinator.dart';
import 'programme_session_authoring_services.dart';

/// Production wiring for Cohort Protocol copy-and-customise (M5).
class CohortProtocolCustomisationServices {
  CohortProtocolCustomisationServices._();

  static CohortProtocolCustomisationCoordinator create({
    required ProtocolBuilderService protocolBuilderService,
    required ProgrammeSessionAuthoringCoordinator programmeSessionCoordinator,
    required SessionLibraryAuthoringCoordinator librarySessionCoordinator,
    SessionCloneService? sessionCloneService,
    CurrentCoachIdentity? coachIdentity,
    ProgrammeEditorController? programmeController,
  }) {
    return CohortProtocolCustomisationCoordinator(
      protocolBuilderService: protocolBuilderService,
      programmeSessionCoordinator: programmeSessionCoordinator,
      librarySessionCoordinator: librarySessionCoordinator,
      sessionCloneService: sessionCloneService ?? const SessionCloneService(),
      coachIdentity: coachIdentity ?? const DevCoachIdentity(),
      assignmentPort: programmeController == null
          ? null
          : ProgrammeEditorSessionAssignmentPort(
              controller: programmeController,
            ),
    );
  }

  static CohortProtocolCustomisationCoordinator forProgrammeEditor({
    required ProgrammeEditorController controller,
    ProtocolBuilderService? protocolBuilderService,
    TrainingContentIdGenerator? idGenerator,
    CurrentCoachIdentity? coachIdentity,
  }) {
    final protocolService =
        protocolBuilderService ?? ProtocolBuilderService();

    return create(
      protocolBuilderService: protocolService,
      programmeSessionCoordinator: ProgrammeSessionAuthoringServices.createCoordinator(
        controller: controller,
        protocolBuilderService: protocolService,
        idGenerator: idGenerator,
        coachIdentity: coachIdentity,
      ),
      librarySessionCoordinator: SessionLibraryAuthoringServices.createCoordinator(
        protocolBuilderService: protocolService,
        idGenerator: idGenerator,
        coachIdentity: coachIdentity,
      ),
      coachIdentity: coachIdentity,
      programmeController: controller,
    );
  }

  static CohortProtocolCustomisationCoordinator forTrainingLibrary({
    ProtocolBuilderService? protocolBuilderService,
    TrainingContentIdGenerator? idGenerator,
    CurrentCoachIdentity? coachIdentity,
  }) {
    final protocolService =
        protocolBuilderService ?? ProtocolBuilderService();

    return create(
      protocolBuilderService: protocolService,
      programmeSessionCoordinator: ProgrammeSessionAuthoringCoordinator(
        protocolBuilderService: protocolService,
        assignmentPort: _NoOpAssignmentPort(),
        idGenerator: idGenerator ?? const UuidTrainingContentIdGenerator(),
        coachIdentity: coachIdentity ?? const DevCoachIdentity(),
      ),
      librarySessionCoordinator: SessionLibraryAuthoringServices.createCoordinator(
        protocolBuilderService: protocolService,
        idGenerator: idGenerator,
        coachIdentity: coachIdentity,
      ),
      coachIdentity: coachIdentity,
    );
  }
}

class _NoOpAssignmentPort implements ProgrammeSessionAssignmentPort {
  @override
  ProgrammeBuilderDocument? get document => null;

  @override
  bool get isEditable => false;

  @override
  String get programmeVersionId => '';

  @override
  bool slotExists({
    required String weekLocalId,
    required String dayLocalId,
    required String slotLocalId,
  }) =>
      false;

  @override
  Future<ProgrammeBuilderEditResult> assignSession({
    required String slotLocalId,
    required String contentId,
    required String displayTitle,
  }) async {
    throw UnsupportedError('No programme context.');
  }
}
