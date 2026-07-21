import '../../performance/models/training_session_record.dart';
import '../../programme/models/programme_execution_context.dart';
import '../../programme/models/programme_progression_result.dart';
import '../models/adaptation_execution_result.dart';
import 'adaptation_execution_service.dart';

/// Bridge between M8 session completion and deterministic adaptation execution.
class AdaptationExecutionCoordinator {
  AdaptationExecutionCoordinator({
    AdaptationExecutionService? executionService,
  }) : _executionService = executionService ?? AdaptationExecutionService();

  final AdaptationExecutionService _executionService;

  Future<AdaptationExecutionResult?> executeAfterSessionCompleted({
    required String athleteId,
    required TrainingSessionRecord record,
    required ProgrammeExecutionContext? programmeContext,
    required int trainingSessionId,
    required bool endedEarly,
    ProgrammeProgressionResult? progressionResult,
  }) async {
    if (programmeContext == null || !programmeContext.isProgrammeBacked) {
      return null;
    }

    if (progressionResult?.status == ProgrammeProgressionStatus.staleResolution) {
      return AdaptationExecutionResult.skipped('Stale programme resolution');
    }

    return _executionService.executeAfterSessionCompletion(
      athleteId: athleteId,
      record: record,
      programmeContext: programmeContext,
      trainingSessionId: trainingSessionId,
      endedEarly: endedEarly,
      progressionResult: progressionResult,
    );
  }
}
