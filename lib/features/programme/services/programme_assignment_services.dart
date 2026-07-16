import '../../../data/repositories/athlete_state_supabase_store.dart';
import '../../../data/repositories/programme_assignment_supabase_store.dart';
import '../../../data/repositories/programme_slot_outcome_supabase_store.dart';
import '../../../data/repositories/programme_version_supabase_store.dart';
import 'athlete_state_sync_service.dart';
import 'athlete_state_sync_service_impl.dart';
import 'programme_assignment_development_service.dart';
import 'programme_assignment_development_service_impl.dart';
import 'programme_assignment_service.dart';
import 'programme_assignment_service_impl.dart';
import 'programme_schedule_resolver_impl.dart';
import 'today_session_service.dart';
import 'today_session_service_impl.dart';

/// Production wiring for programme assignment services.
class ProgrammeAssignmentServices {
  ProgrammeAssignmentServices._();

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

  static ProgrammeAssignmentService createAssignmentService() {
    return ProgrammeAssignmentServiceImpl(
      assignmentStore: const ProgrammeAssignmentSupabaseStore(),
      versionStore: const ProgrammeVersionSupabaseStore(),
      scheduleResolver: const ProgrammeScheduleResolverImpl(),
      todaySessionService: createTodaySessionService(),
      athleteStateSyncService: createAthleteStateSyncService(),
    );
  }

  static ProgrammeAssignmentDevelopmentService createDevelopmentService() {
    return ProgrammeAssignmentDevelopmentServiceImpl(
      assignmentStore: const ProgrammeAssignmentSupabaseStore(),
      slotOutcomeStore: const ProgrammeSlotOutcomeSupabaseStore(),
      versionStore: const ProgrammeVersionSupabaseStore(),
      scheduleResolver: const ProgrammeScheduleResolverImpl(),
      todaySessionService: createTodaySessionService(),
      athleteStateSyncService: createAthleteStateSyncService(),
    );
  }
}
