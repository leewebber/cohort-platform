import '../../../data/repositories/athlete_state_supabase_store.dart';
import '../../../data/repositories/programme_assignment_supabase_store.dart';
import '../../../data/repositories/programme_slot_outcome_supabase_store.dart';
import '../../../data/repositories/programme_version_supabase_store.dart';
import '../../programme/models/programme_execution_context.dart';
import '../../programme/models/programme_progression_result.dart';
import '../../programme/services/athlete_state_sync_service_impl.dart';
import '../../programme/services/programme_progression_service.dart';
import '../../programme/services/programme_progression_service_impl.dart';
import '../../programme/services/programme_schedule_resolver_impl.dart';
import '../../programme/services/programme_slot_outcome_service_impl.dart';
import '../../programme/services/today_session_service_impl.dart';

/// Shared integration point between Execution Engine completion and Programme Engine.
class ProgrammeSessionProgressionCoordinator {
  ProgrammeSessionProgressionCoordinator({
    ProgrammeProgressionService? progressionService,
  }) : _progressionService = progressionService ?? _createDefaultService();

  static ProgrammeProgressionService _createDefaultService() {
    return ProgrammeProgressionServiceImpl(
      assignmentStore: const ProgrammeAssignmentSupabaseStore(),
      slotOutcomeStore: const ProgrammeSlotOutcomeSupabaseStore(),
      versionStore: const ProgrammeVersionSupabaseStore(),
      slotOutcomeService: ProgrammeSlotOutcomeServiceImpl(
        slotOutcomeStore: const ProgrammeSlotOutcomeSupabaseStore(),
      ),
      scheduleResolver: const ProgrammeScheduleResolverImpl(),
      todaySessionService: TodaySessionServiceImpl(
        assignmentStore: const ProgrammeAssignmentSupabaseStore(),
        versionStore: const ProgrammeVersionSupabaseStore(),
        slotOutcomeStore: const ProgrammeSlotOutcomeSupabaseStore(),
        scheduleResolver: const ProgrammeScheduleResolverImpl(),
      ),
      athleteStateSyncService: AthleteStateSyncServiceImpl(
        athleteStateStore: const AthleteStateSupabaseStore(),
      ),
    );
  }

  final ProgrammeProgressionService _progressionService;

  Future<ProgrammeProgressionResult?> markSessionStartedIfProgrammeBacked({
    required String athleteId,
    required ProgrammeExecutionContext? programmeContext,
    int? trainingSessionId,
  }) async {
    if (programmeContext == null || !programmeContext.isProgrammeBacked) {
      return null;
    }

    return _progressionService.markSessionStarted(
      athleteId: athleteId,
      resolution: programmeContext.toResolvedSession(),
      trainingSessionId: trainingSessionId,
    );
  }

  Future<ProgrammeProgressionResult?> handleSessionCompleted({
    required String athleteId,
    required ProgrammeExecutionContext? programmeContext,
    required int trainingSessionId,
    required bool endedEarly,
    String? resolutionNote,
  }) async {
    if (programmeContext == null || !programmeContext.isProgrammeBacked) {
      return null;
    }

    final resolution = programmeContext.toResolvedSession();

    if (endedEarly) {
      return _progressionService.completeSessionPartial(
        athleteId: athleteId,
        resolution: resolution,
        trainingSessionId: trainingSessionId,
        resolutionNote: resolutionNote,
      );
    }

    return _progressionService.completeSession(
      athleteId: athleteId,
      resolution: resolution,
      trainingSessionId: trainingSessionId,
      resolutionNote: resolutionNote,
    );
  }
}
