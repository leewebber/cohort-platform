import '../../../../core/constants/programme_dev_identity.dart';
import '../../../../data/repositories/programme_assignment_supabase_store.dart';
import '../../../../data/repositories/programme_version_supabase_store.dart';
import '../../../programme/services/programme_publishing_service.dart';
import '../../../programme/services/programme_publishing_service_impl.dart';
import '../../../programme/services/programme_schedule_resolver_impl.dart';
import '../../../programme_builder/services/programme_builder_preview_service.dart';
import '../../../programme_builder/services/programme_builder_preview_service_impl.dart';
import '../../../programme_builder/services/programme_builder_protocol_name_resolver.dart';
import '../../../programme_builder/services/programme_builder_protocol_name_resolver_impl.dart';
import '../../../programme_builder/services/programme_builder_protocol_picker_service.dart';
import '../../../programme_builder/services/programme_builder_protocol_picker_service_impl.dart';
import '../../../programme_builder/services/programme_builder_publish_coordinator.dart';
import '../../../programme_builder/services/programme_builder_publish_coordinator_impl.dart';
import '../../../programme_builder/services/programme_builder_service.dart';
import '../../../programme_builder/services/programme_builder_service_impl.dart';
import '../../../programme_builder/services/programme_builder_validation_service.dart';
import '../../../programme_builder/services/programme_builder_validation_service_impl.dart';
import '../../../admin/services/protocol_builder_service.dart';
import '../../../programme_builder/services/programme_session_authoring_coordinator.dart';
import '../../../programme_builder/services/programme_session_authoring_services.dart';
import '../controllers/programme_editor_controller.dart';

/// Production wiring for Programme Editor.
class ProgrammeEditorServices {
  ProgrammeEditorServices._();

  static ProgrammeEditorController createController({
    required String versionId,
    String coachId = ProgrammeDevIdentity.coachId,
  }) {
    final versionStore = const ProgrammeVersionSupabaseStore();
    final assignmentStore = const ProgrammeAssignmentSupabaseStore();

    final validationService = ProgrammeBuilderValidationServiceImpl(
      scheduleResolver: const ProgrammeScheduleResolverImpl(),
    );

    final builderService = ProgrammeBuilderServiceImpl(
      versionStore: versionStore,
      assignmentStore: assignmentStore,
      validationService: validationService,
    );

    final publishCoordinator = ProgrammeBuilderPublishCoordinatorImpl(
      builderService: builderService,
      publishingService: ProgrammePublishingServiceImpl(
        versionStore: versionStore,
      ),
      validationService: validationService,
    );

    return ProgrammeEditorController(
      builderService: builderService,
      validationService: validationService,
      publishCoordinator: publishCoordinator,
      previewService: const ProgrammeBuilderPreviewServiceImpl(),
      protocolPickerService: ProgrammeBuilderProtocolPickerServiceImpl(),
      protocolNameResolver: ProgrammeBuilderProtocolNameResolverImpl(),
      coachId: coachId,
      versionId: versionId,
    );
  }

  static ProgrammeBuilderService createBuilderService({
    String coachId = ProgrammeDevIdentity.coachId,
  }) {
    final versionStore = const ProgrammeVersionSupabaseStore();
    final assignmentStore = const ProgrammeAssignmentSupabaseStore();
    final validationService = ProgrammeBuilderValidationServiceImpl(
      scheduleResolver: const ProgrammeScheduleResolverImpl(),
    );

    return ProgrammeBuilderServiceImpl(
      versionStore: versionStore,
      assignmentStore: assignmentStore,
      validationService: validationService,
    );
  }

  static ProgrammeBuilderPreviewService createPreviewService() {
    return const ProgrammeBuilderPreviewServiceImpl();
  }

  static ProgrammeBuilderProtocolPickerService createProtocolPickerService() {
    return ProgrammeBuilderProtocolPickerServiceImpl();
  }

  static ProgrammeBuilderProtocolNameResolver createProtocolNameResolver() {
    return ProgrammeBuilderProtocolNameResolverImpl();
  }

  static ProgrammeBuilderPublishCoordinator createPublishCoordinator({
    String coachId = ProgrammeDevIdentity.coachId,
  }) {
    final builderService = createBuilderService(coachId: coachId);
    return ProgrammeBuilderPublishCoordinatorImpl(
      builderService: builderService,
      publishingService: ProgrammePublishingServiceImpl(
        versionStore: const ProgrammeVersionSupabaseStore(),
      ),
      validationService: ProgrammeBuilderValidationServiceImpl(
        scheduleResolver: const ProgrammeScheduleResolverImpl(),
      ),
    );
  }

  static ProgrammeBuilderValidationService createValidationService() {
    return ProgrammeBuilderValidationServiceImpl(
      scheduleResolver: const ProgrammeScheduleResolverImpl(),
    );
  }

  static ProgrammeSessionAuthoringCoordinator createSessionAuthoringCoordinator({
    required ProgrammeEditorController controller,
    ProtocolBuilderService? protocolBuilderService,
  }) {
    return ProgrammeSessionAuthoringServices.createCoordinator(
      controller: controller,
      protocolBuilderService: protocolBuilderService,
    );
  }
}
