import '../../../data/repositories/programme_assignment_store.dart';
import '../../../data/repositories/programme_store_exception.dart';
import '../../programme/errors/programme_schedule_exception.dart';
import '../../programme/models/resolved_today_session.dart';
import '../../programme/services/athlete_state_sync_service.dart';
import '../../programme/services/today_session_service.dart';

/// V0.1 manual programme continuation for rest days and day-complete states.
///
/// Applies [ResolvedTodaySession.suggestedNextCursor] via assignment update only —
/// does not mutate cursor during read-only resolution.
class HomeProgrammeContinuationService {
  const HomeProgrammeContinuationService({
    required ProgrammeAssignmentStore assignmentStore,
    required TodaySessionService todaySessionService,
    required AthleteStateSyncService athleteStateSyncService,
  })  : _assignmentStore = assignmentStore,
        _todaySessionService = todaySessionService,
        _athleteStateSyncService = athleteStateSyncService;

  final ProgrammeAssignmentStore _assignmentStore;
  final TodaySessionService _todaySessionService;
  final AthleteStateSyncService _athleteStateSyncService;

  Future<ResolvedTodaySession> continueFromSuggestedCursor({
    required String athleteId,
    required ResolvedTodaySession resolution,
  }) async {
    final cursor = resolution.suggestedNextCursor;
    if (cursor == null) {
      throw ProgrammeScheduleException(
        ProgrammeScheduleErrorCode.malformedAssignmentCursor,
        'No suggested next cursor available for programme continuation',
      );
    }

    final assignment = await _assignmentStore.getActiveAssignment(athleteId);
    if (assignment == null) {
      throw ProgrammeStoreException(
        'No active programme assignment for $athleteId',
        operation: 'continueFromSuggestedCursor',
        tableName: 'programme_assignments',
      );
    }

    if (assignment.id != resolution.assignmentId) {
      throw ProgrammeStoreException(
        'Resolution assignment ${resolution.assignmentId} does not match '
        'active assignment ${assignment.id}',
        operation: 'continueFromSuggestedCursor',
      );
    }

    await _assignmentStore.update(
      assignment.copyWith(
        currentWeek: cursor.weekNumber,
        currentDayKey: cursor.dayKey,
        currentSessionOrder: cursor.slotOrder,
      ),
    );

    final nextResolution =
        await _todaySessionService.resolveForAthlete(athleteId);

    await _athleteStateSyncService.syncFromResolvedSession(
      athleteId: athleteId,
      resolution: nextResolution,
    );

    return nextResolution;
  }
}
