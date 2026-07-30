import '../../performance/models/training_session_record.dart';
import '../../programme/models/programme_execution_context.dart';
import '../../programme/models/programme_progression_result.dart';
import '../models/adaptation_execution_result.dart';
import 'adaptation_execution_service.dart';

/// Bridge between M8 session completion and deterministic adaptation execution.
///
/// Coaching Constitution: no adaptation may be applied automatically. Callers
/// must pass [athleteAcceptedRecommendation] only after an explicit accept.
/// Future-slot mutations additionally require [coachAuthoredFutureMutationPermission].
class AdaptationExecutionCoordinator {
  AdaptationExecutionCoordinator({AdaptationExecutionService? executionService})
    : _executionService = executionService ?? AdaptationExecutionService();

  final AdaptationExecutionService _executionService;

  Future<AdaptationExecutionResult?> executeAfterSessionCompleted({
    required String athleteId,
    required TrainingSessionRecord record,
    required ProgrammeExecutionContext? programmeContext,
    required int trainingSessionId,
    required bool endedEarly,
    ProgrammeProgressionResult? progressionResult,
    bool athleteAcceptedRecommendation = false,
    bool coachAuthoredFutureMutationPermission = false,
  }) async {
    if (programmeContext == null || !programmeContext.isProgrammeBacked) {
      return null;
    }

    if (progressionResult?.status ==
        ProgrammeProgressionStatus.staleResolution) {
      return AdaptationExecutionResult.skipped('Stale programme resolution');
    }

    // Constitution: recommendations must not mutate durable state before accept;
    // future sessions require coach-authored permission.
    if (!athleteAcceptedRecommendation) {
      return AdaptationExecutionResult.skipped(
        'awaiting_athlete_acceptance',
      );
    }
    if (!coachAuthoredFutureMutationPermission) {
      return AdaptationExecutionResult.skipped(
        'requires_coach_authored_future_permission',
      );
    }

    return _executionService.executeAfterSessionCompletion(
      athleteId: athleteId,
      record: record,
      programmeContext: programmeContext,
      trainingSessionId: trainingSessionId,
      endedEarly: endedEarly,
      progressionResult: progressionResult,
      athleteAcceptedRecommendation: athleteAcceptedRecommendation,
      coachAuthoredFutureMutationPermission:
          coachAuthoredFutureMutationPermission,
    );
  }
}
