import '../../../../core/constants/programme_dev_identity.dart';
import '../../../../data/repositories/programme_assignment_supabase_store.dart';
import '../../../../data/repositories/programme_version_supabase_store.dart';
import '../../../programme/services/programme_catalog_service.dart';
import '../../../programme/services/programme_catalog_service_impl.dart';
import '../../../programme/services/programme_publishing_service.dart';
import '../../../programme/services/programme_publishing_service_impl.dart';
import '../../../programme/services/programme_schedule_resolver_impl.dart';
import '../../../programme_builder/services/programme_builder_publish_coordinator.dart';
import '../../../programme_builder/services/programme_builder_publish_coordinator_impl.dart';
import '../../../programme_builder/services/programme_builder_service.dart';
import '../../../programme_builder/services/programme_builder_service_impl.dart';
import '../../../programme_builder/services/programme_builder_validation_service.dart';
import '../../../programme_builder/services/programme_builder_validation_service_impl.dart';
import '../controllers/programme_catalogue_controller.dart';

/// Production wiring for Coach Studio Programme Catalogue.
class ProgrammeCatalogueServices {
  ProgrammeCatalogueServices._();

  static ProgrammeCatalogueController createController({
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

    final catalogService = ProgrammeCatalogServiceImpl(
      versionStore: versionStore,
      coachId: coachId,
    );

    final publishingService = ProgrammePublishingServiceImpl(
      versionStore: versionStore,
    );

    final publishCoordinator = ProgrammeBuilderPublishCoordinatorImpl(
      builderService: builderService,
      publishingService: publishingService,
      validationService: validationService,
    );

    return ProgrammeCatalogueController(
      builderService: builderService,
      catalogService: catalogService,
      publishCoordinator: publishCoordinator,
      publishingService: publishingService,
      validationService: validationService,
      coachId: coachId,
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

  static ProgrammeCatalogService createCatalogService({
    String coachId = ProgrammeDevIdentity.coachId,
  }) {
    return ProgrammeCatalogServiceImpl(
      versionStore: const ProgrammeVersionSupabaseStore(),
      coachId: coachId,
    );
  }

  static ProgrammePublishingService createPublishingService() {
    return ProgrammePublishingServiceImpl(
      versionStore: const ProgrammeVersionSupabaseStore(),
    );
  }

  static ProgrammeBuilderPublishCoordinator createPublishCoordinator({
    String coachId = ProgrammeDevIdentity.coachId,
  }) {
    final builderService = createBuilderService(coachId: coachId);
    return ProgrammeBuilderPublishCoordinatorImpl(
      builderService: builderService,
      publishingService: createPublishingService(),
      validationService: ProgrammeBuilderValidationServiceImpl(
        scheduleResolver: const ProgrammeScheduleResolverImpl(),
      ),
    );
  }
}
