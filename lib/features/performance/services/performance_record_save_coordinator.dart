import '../../../data/repositories/training_session_repository.dart';
import '../../../models/training_session_completion_context.dart';
import '../../programme/models/programme_execution_context.dart';
import '../../session/services/programme_session_progression_coordinator.dart';
import '../../adaptation/models/adaptation_execution_result.dart';
import '../../adaptation/services/adaptation_execution_coordinator.dart';
import '../../programme/models/programme_progression_result.dart';
import '../controllers/performance_capture_controller.dart';
import '../mappers/performance_record_mapper.dart';
import '../models/training_session_record.dart';
import '../models/training_session_record_status.dart';
import '../repositories/performance_record_store.dart';
import '../repositories/supabase_performance_record_store.dart';

class PerformanceCompletionResult {
  const PerformanceCompletionResult({
    required this.record,
    this.progressionFailed = false,
    this.progressionMessage,
    this.progressionResult,
    this.adaptationResult,
  });

  final TrainingSessionRecord record;
  final bool progressionFailed;
  final String? progressionMessage;
  final ProgrammeProgressionResult? progressionResult;
  final AdaptationExecutionResult? adaptationResult;
}

class PerformanceRecordSaveCoordinator {
  PerformanceRecordSaveCoordinator({
    PerformanceRecordStore? store,
    TrainingSessionRepository? trainingSessionRepository,
    ProgrammeSessionProgressionCoordinator? progressionCoordinator,
    AdaptationExecutionCoordinator? adaptationCoordinator,
  })  : _store = store ?? SupabasePerformanceRecordStore(),
        _trainingSessionRepository =
            trainingSessionRepository ?? const TrainingSessionRepository(),
        _progressionCoordinator =
            progressionCoordinator ?? ProgrammeSessionProgressionCoordinator(),
        _adaptationCoordinator =
            adaptationCoordinator ?? AdaptationExecutionCoordinator();

  final PerformanceRecordStore _store;
  final TrainingSessionRepository _trainingSessionRepository;
  final ProgrammeSessionProgressionCoordinator _progressionCoordinator;
  final AdaptationExecutionCoordinator _adaptationCoordinator;

  Future<TrainingSessionRecord> createOrResumeInProgress({
    required PerformanceCaptureController controller,
  }) {
    return _store.createOrResumeInProgress(controller.draft);
  }

  Future<TrainingSessionRecord> saveDraft({
    required PerformanceCaptureController controller,
  }) {
    return _store.saveDraft(controller.draft);
  }

  Future<PerformanceCompletionResult> completeSession({
    required PerformanceCaptureController controller,
    required int trainingSessionId,
    required String athleteId,
    ProgrammeExecutionContext? programmeContext,
    TrainingSessionRecordStatus? forcedStatus,
  }) async {
    final validation = controller.validateForCompletion();
    if (!validation.isValid) {
      throw PerformanceRecordStoreException(
        validation.fieldErrors.values.first,
      );
    }

    final status = forcedStatus ?? controller.resolveCompletionStatus();
    final persistableDraft = controller.buildPersistableDraft(status: status);
    final record = await _store.completeRecord(persistableDraft);

    final endedEarly = status != TrainingSessionRecordStatus.completed;
    await _trainingSessionRepository.completeSession(
      trainingSessionId,
      completion: TrainingSessionCompletionContext(
        endedEarly: endedEarly,
        sessionNote: persistableDraft.athleteNote,
        completedExerciseCount: persistableDraft.completedBlockCount,
        totalExerciseCount: persistableDraft.blockDrafts.length,
      ),
    );

    var progressionFailed = false;
    String? progressionMessage;
    ProgrammeProgressionResult? progressionResult;
    AdaptationExecutionResult? adaptationResult;

    if (programmeContext != null && programmeContext.isProgrammeBacked) {
      try {
        progressionResult = await _progressionCoordinator.handleSessionCompleted(
          athleteId: athleteId,
          programmeContext: programmeContext,
          trainingSessionId: trainingSessionId,
          endedEarly: endedEarly,
          resolutionNote: persistableDraft.athleteNote,
        );
      } catch (error) {
        progressionFailed = true;
        progressionMessage = error.toString();
      }

      if (!progressionFailed) {
        try {
          adaptationResult = await _adaptationCoordinator.executeAfterSessionCompleted(
            athleteId: athleteId,
            record: record,
            programmeContext: programmeContext,
            trainingSessionId: trainingSessionId,
            endedEarly: endedEarly,
            progressionResult: progressionResult,
          );
        } catch (_) {
          adaptationResult = AdaptationExecutionResult.skipped(
            'Adaptation execution failed',
          );
        }
      }
    }

    return PerformanceCompletionResult(
      record: record,
      progressionFailed: progressionFailed,
      progressionMessage: progressionMessage,
      progressionResult: progressionResult,
      adaptationResult: adaptationResult,
    );
  }

  Future<TrainingSessionRecord?> loadInProgressDraftAsRecord({
    required String athleteId,
    required int trainingSessionId,
  }) {
    return _store.getInProgressForTrainingSession(
      athleteId: athleteId,
      trainingSessionId: trainingSessionId,
    );
  }

  Future<List<TrainingSessionRecord>> listHistory({
    required String athleteId,
    int limit = 25,
    int offset = 0,
  }) {
    return _store.listHistory(
      athleteId: athleteId,
      limit: limit,
      offset: offset,
    );
  }

  Future<TrainingSessionRecord?> getRecordById(String recordId) {
    return _store.getById(recordId);
  }
}

extension PerformanceRecordRestore on PerformanceRecordSaveCoordinator {
  PerformanceCaptureController restoreControllerFromRecord(
    TrainingSessionRecord record,
  ) {
    const mapper = PerformanceRecordMapper();
    return PerformanceCaptureController(draft: mapper.toDraft(record));
  }
}
