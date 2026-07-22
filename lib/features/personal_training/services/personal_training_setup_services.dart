import '../../../data/repositories/programme_assignment_supabase_store.dart';
import '../../../data/repositories/programme_version_supabase_store.dart';
import '../../auth/services/current_user_session.dart';
import '../../programme/services/programme_assignment_services.dart';
import '../../programme/services/programme_catalog_service.dart';
import '../../programme/services/programme_catalog_service_impl.dart';
import 'personal_training_setup_service.dart';

class PersonalTrainingSetupServices {
  PersonalTrainingSetupServices._();

  static PersonalTrainingSetupService createService({
    ProgrammeCatalogService? catalogService,
  }) {
    final coachId = CurrentUserSession.maybeInstance?.coachId ?? '';
    return PersonalTrainingSetupService(
      assignmentStore: const ProgrammeAssignmentSupabaseStore(),
      catalogService: catalogService ??
          ProgrammeCatalogServiceImpl(
            versionStore: const ProgrammeVersionSupabaseStore(),
            coachId: coachId,
          ),
      assignmentService: ProgrammeAssignmentServices.createAssignmentService(),
    );
  }
}
