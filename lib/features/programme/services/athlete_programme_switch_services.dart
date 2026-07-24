import '../../../data/repositories/programme_assignment_supabase_store.dart';
import '../../../data/repositories/programme_version_supabase_store.dart';
import '../../auth/services/current_user_session.dart';
import '../controllers/athlete_programme_controllers.dart';
import 'athlete_programme_switch_catalog_service.dart';
import 'athlete_programme_switch_coordinator.dart';
import 'programme_assignment_services.dart';
import 'programme_catalog_service_impl.dart';

class AthleteProgrammeSwitchServices {
  AthleteProgrammeSwitchServices._();

  static AthleteProgrammeSwitchCatalogService createCatalogService({
    ProgrammeCatalogServiceImpl? catalogService,
  }) {
    final coachId = CurrentUserSession.maybeInstance?.coachId ?? '';
    return AthleteProgrammeSwitchCatalogService(
      catalogService: catalogService ??
          ProgrammeCatalogServiceImpl(
            versionStore: const ProgrammeVersionSupabaseStore(),
            coachId: coachId,
          ),
    );
  }

  static AthleteProgrammeSwitchCoordinator createCoordinator() {
    return AthleteProgrammeSwitchCoordinator(
      assignmentService: ProgrammeAssignmentServices.createAssignmentService(),
    );
  }

  static AthleteProgrammeScreenController createProgrammeScreenController({
    required String athleteId,
  }) {
    return AthleteProgrammeScreenController(
      athleteId: athleteId,
      assignmentStore: const ProgrammeAssignmentSupabaseStore(),
      versionStore: const ProgrammeVersionSupabaseStore(),
    );
  }

  static AthleteProgrammeSelectionController createSelectionController({
    required String athleteId,
    AthleteProgrammeSwitchCatalogService? catalogService,
    AthleteProgrammeSwitchCoordinator? switchCoordinator,
  }) {
    return AthleteProgrammeSelectionController(
      athleteId: athleteId,
      catalogService: catalogService ?? createCatalogService(),
      switchCoordinator: switchCoordinator ?? createCoordinator(),
      assignmentStore: const ProgrammeAssignmentSupabaseStore(),
    );
  }
}
