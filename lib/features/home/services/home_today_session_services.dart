import '../../../data/repositories/athlete_state_repository.dart';
import '../../../data/repositories/athlete_state_supabase_store.dart';
import '../../../data/repositories/programme_assignment_supabase_store.dart';
import '../../../data/repositories/programme_repository.dart';
import '../../../data/repositories/programme_slot_outcome_supabase_store.dart';
import '../../../data/repositories/programme_version_supabase_store.dart';
import '../../../data/repositories/protocol_repository.dart';
import '../../../data/repositories/training_session_repository.dart';
import '../../programme/services/athlete_state_sync_service.dart';
import '../../programme/services/athlete_state_sync_service_impl.dart';
import '../../programme/services/programme_schedule_resolver_impl.dart';
import '../../programme/services/today_session_service.dart';
import '../../programme/services/today_session_service_impl.dart';
import '../../session/services/programme_session_progression_coordinator.dart';
import 'home_programme_continuation_service.dart';
import 'home_today_session_loader.dart';

/// Production wiring for Home programme session integration.
class HomeTodaySessionServices {
  HomeTodaySessionServices._();

  static TodaySessionService createTodaySessionService() {
    return TodaySessionServiceImpl(
      assignmentStore: const ProgrammeAssignmentSupabaseStore(),
      versionStore: const ProgrammeVersionSupabaseStore(),
      slotOutcomeStore: const ProgrammeSlotOutcomeSupabaseStore(),
      scheduleResolver: const ProgrammeScheduleResolverImpl(),
    );
  }

  static AthleteStateSyncService createAthleteStateSyncService() {
    return AthleteStateSyncServiceImpl(
      athleteStateStore: const AthleteStateSupabaseStore(),
    );
  }

  static HomeTodaySessionLoader createLoader() {
    return HomeTodaySessionLoader(
      todaySessionService: createTodaySessionService(),
      athleteStateSyncService: createAthleteStateSyncService(),
      athleteStateRepository: const AthleteStateRepository(),
      protocolRepository: ProtocolRepository(),
      programmeRepository: ProgrammeRepository(),
      trainingSessionRepository: const TrainingSessionRepository(),
    );
  }

  static HomeProgrammeContinuationService createContinuationService() {
    return HomeProgrammeContinuationService(
      assignmentStore: const ProgrammeAssignmentSupabaseStore(),
      todaySessionService: createTodaySessionService(),
      athleteStateSyncService: createAthleteStateSyncService(),
    );
  }

  static ProgrammeSessionProgressionCoordinator createProgressionCoordinator() {
    return ProgrammeSessionProgressionCoordinator();
  }
}
