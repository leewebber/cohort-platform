import '../../../data/repositories/training_session_repository.dart';
import '../../../models/training_session_completion_context.dart';
import '../../programme/models/programme_execution_context.dart';
import '../../session/services/programme_session_progression_coordinator.dart';
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
  });

  final TrainingSessionRecord record;
  final bool progressionFailed;
  final String? progressionMessage;
}

class PerformanceRecordSaveCoordinator {
  PerformanceRecordSaveCoordinator({
    PerformanceRecordStore? store,
    TrainingSessionRepository? trainingSessionRepository,
    ProgrammeSessionProgressionCoordinator? progressionCoordinator,
  })  : _store = store ?? SupabasePerformanceRecordStore(),
        _trainingSessionRepository =
            trainingSessionRepository ?? const TrainingSessionRepository(),
        _progressionCoordinator =
            progressionCoordinator ?? ProgrammeSessionProgressionCoordinator();

  final PerformanceRecordStore _store;
  final TrainingSessionRepository _trainingSessionRepository;
  final ProgrammeSessionProgressionCoordinator _progressionCoordinator;

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
    if (programmeContext != null && programmeContext.isProgrammeBacked) {
      try {
        await _progressionCoordinator.handleSessionCompleted(
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
    }

    return PerformanceCompletionResult(
      record: record,
      progressionFailed: progressionFailed,
      progressionMessage: progressionMessage,
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
