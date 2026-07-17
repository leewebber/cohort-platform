import '../../../core/services/current_coach_identity.dart';
import '../../../core/services/training_content_id_generator.dart';
import '../../../features/admin/services/protocol_builder_service.dart';
import '../../coach_studio/programmes/controllers/programme_editor_controller.dart';
import '../ports/programme_editor_session_assignment_port.dart';
import 'programme_session_authoring_coordinator.dart';

/// Production wiring for programme Session authoring (M3).
class ProgrammeSessionAuthoringServices {
  ProgrammeSessionAuthoringServices._();

  static ProgrammeSessionAuthoringCoordinator createCoordinator({
    required ProgrammeEditorController controller,
    ProtocolBuilderService? protocolBuilderService,
    TrainingContentIdGenerator? idGenerator,
    CurrentCoachIdentity? coachIdentity,
  }) {
    return ProgrammeSessionAuthoringCoordinator(
      protocolBuilderService:
          protocolBuilderService ?? ProtocolBuilderService(),
      assignmentPort: ProgrammeEditorSessionAssignmentPort(
        controller: controller,
      ),
      idGenerator: idGenerator ?? const UuidTrainingContentIdGenerator(),
      coachIdentity: coachIdentity ?? const DevCoachIdentity(),
    );
  }
}
