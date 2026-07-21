import '../../../data/repositories/programme_assignment_supabase_store.dart';
import '../../../data/repositories/programme_version_supabase_store.dart';
import '../../auth/services/current_user_session.dart';
import '../../programme/services/programme_assignment_services.dart';
import '../../programme/services/programme_catalog_service.dart';
import '../../programme/services/programme_catalog_service_impl.dart';
import '../repositories/supabase_coach_athlete_repository.dart';
import 'coach_athlete_service.dart';

class CoachAthleteServices {
  CoachAthleteServices._();

  static CoachAthleteService createService({
    ProgrammeCatalogService? catalogService,
  }) {
    final coachId = CurrentUserSession.maybeInstance?.coachId ?? '';
    return CoachAthleteService(
      relationshipRepository: const SupabaseCoachAthleteRelationshipRepository(),
      inviteRepository: const SupabaseCoachAthleteInviteRepository(),
      assignmentStore: const ProgrammeAssignmentSupabaseStore(),
      versionStore: const ProgrammeVersionSupabaseStore(),
      catalogService: catalogService ??
          ProgrammeCatalogServiceImpl(
            versionStore: const ProgrammeVersionSupabaseStore(),
            coachId: coachId,
          ),
      assignmentService: ProgrammeAssignmentServices.createAssignmentService(),
    );
  }
}
