import '../../../../core/services/authenticated_identity.dart';
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

  static ProgrammeCatalogueController createController() {
    final coachId = AuthenticatedIdentity.requireCoachId();
    return _createController(coachId: coachId);
  }

  static ProgrammeCatalogueController createControllerForCoachId({
    required String coachId,
  }) {
    return _createController(coachId: coachId);
  }

  static ProgrammeCatalogueController _createController({
    required String coachId,
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

  static ProgrammeBuilderService createBuilderService() {
    AuthenticatedIdentity.requireCoachId();
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

  static ProgrammeCatalogService createCatalogService() {
    return ProgrammeCatalogServiceImpl(
      versionStore: const ProgrammeVersionSupabaseStore(),
      coachId: AuthenticatedIdentity.requireCoachId(),
    );
  }

  static ProgrammePublishingService createPublishingService() {
    return ProgrammePublishingServiceImpl(
      versionStore: const ProgrammeVersionSupabaseStore(),
    );
  }

  static ProgrammeBuilderPublishCoordinator createPublishCoordinator() {
    final coachId = AuthenticatedIdentity.requireCoachId();
    final builderService = createBuilderService();
    return ProgrammeBuilderPublishCoordinatorImpl(
      builderService: builderService,
      publishingService: createPublishingService(),
      validationService: ProgrammeBuilderValidationServiceImpl(
        scheduleResolver: const ProgrammeScheduleResolverImpl(),
      ),
    );
  }
}
