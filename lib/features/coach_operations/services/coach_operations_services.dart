import '../../../data/repositories/programme_assignment_supabase_store.dart';
import '../../../data/repositories/programme_slot_outcome_supabase_store.dart';
import '../../../data/repositories/programme_version_supabase_store.dart';
import '../../coach_athlete/services/coach_athlete_services.dart';
import '../../performance/repositories/supabase_performance_record_store.dart';
import '../../programme/services/programme_schedule_resolver_impl.dart';
import 'coach_athlete_daily_status_service.dart';

class CoachOperationsServices {
  CoachOperationsServices._();

  static CoachAthleteDailyStatusService createDailyStatusService() {
    return CoachAthleteDailyStatusService(
      coachAthleteService: CoachAthleteServices.createService(),
      assignmentStore: const ProgrammeAssignmentSupabaseStore(),
      versionStore: const ProgrammeVersionSupabaseStore(),
      slotOutcomeStore: const ProgrammeSlotOutcomeSupabaseStore(),
      scheduleResolver: const ProgrammeScheduleResolverImpl(),
      performanceRecordStore: SupabasePerformanceRecordStore(),
    );
  }
}
