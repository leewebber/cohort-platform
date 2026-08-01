import '../../../data/repositories/programme_assignment_supabase_store.dart';
import '../../../data/repositories/programme_version_supabase_store.dart';
import '../../auth/services/current_user_session.dart';
import '../controllers/athlete_programme_controllers.dart';
import 'athlete_catalogue_enrolment_service.dart';
import 'athlete_catalogue_enrolment_supabase_store.dart';
import 'athlete_plan_materialisation_service.dart';
import 'athlete_plan_materialisation_supabase_store.dart';
import 'athlete_programme_switch_catalog_service.dart';
import 'programme_catalog_service_impl.dart';

/// Production wiring for Sprint 1.3 enrolment and Sprint 1.4A materialisation.
class AthleteCatalogueEnrolmentServices {
  AthleteCatalogueEnrolmentServices._();

  static AthleteCatalogueEnrolmentService createEnrolmentService() {
    return AthleteCatalogueEnrolmentService(
      enrolmentStore: const AthleteCatalogueEnrolmentSupabaseStore(),
      assignmentStore: const ProgrammeAssignmentSupabaseStore(),
    );
  }

  static AthletePlanMaterialisationService createMaterialisationService() {
    return AthletePlanMaterialisationService(
      materialisationStore: const AthletePlanMaterialisationSupabaseStore(),
      assignmentStore: const ProgrammeAssignmentSupabaseStore(),
    );
  }

  static AthleteProgrammeSwitchCatalogService createCatalogService({
    ProgrammeCatalogServiceImpl? catalogService,
  }) {
    final coachId = CurrentUserSession.maybeInstance?.coachId ?? '';
    return AthleteProgrammeSwitchCatalogService(
      catalogService:
          catalogService ??
          ProgrammeCatalogServiceImpl(
            versionStore: const ProgrammeVersionSupabaseStore(),
            coachId: coachId,
          ),
    );
  }

  static AthleteProgrammeSelectionController createSelectionController({
    required String athleteId,
    AthleteProgrammeSwitchCatalogService? catalogService,
    AthleteCatalogueEnrolmentService? enrolmentService,
  }) {
    return AthleteProgrammeSelectionController(
      athleteId: athleteId,
      catalogService: catalogService ?? createCatalogService(),
      enrolmentService: enrolmentService ?? createEnrolmentService(),
      assignmentStore: const ProgrammeAssignmentSupabaseStore(),
    );
  }

  static AthleteProgrammeScreenController createProgrammeScreenController({
    required String athleteId,
    AthletePlanMaterialisationService? materialisationService,
  }) {
    return AthleteProgrammeScreenController(
      athleteId: athleteId,
      assignmentStore: const ProgrammeAssignmentSupabaseStore(),
      versionStore: const ProgrammeVersionSupabaseStore(),
      materialisationService:
          materialisationService ?? createMaterialisationService(),
    );
  }
}
