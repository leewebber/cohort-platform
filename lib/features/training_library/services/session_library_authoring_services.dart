import '../../../core/services/current_coach_identity.dart';
import '../../../core/services/training_content_id_generator.dart';
import '../../../features/admin/services/protocol_builder_service.dart';
import 'session_library_authoring_coordinator.dart';

/// Production wiring for Session Library authoring (M4).
class SessionLibraryAuthoringServices {
  SessionLibraryAuthoringServices._();

  static SessionLibraryAuthoringCoordinator createCoordinator({
    ProtocolBuilderService? protocolBuilderService,
    TrainingContentIdGenerator? idGenerator,
    CurrentCoachIdentity? coachIdentity,
  }) {
    return SessionLibraryAuthoringCoordinator(
      protocolBuilderService:
          protocolBuilderService ?? ProtocolBuilderService(),
      idGenerator: idGenerator ?? const UuidTrainingContentIdGenerator(),
      coachIdentity: coachIdentity ?? const DevCoachIdentity(),
    );
  }
}
