import '../../../core/persistence/athlete_local_repository.dart';
import '../../../data/repositories/training_session_repository.dart';
import '../../../models/training_session_completion_context.dart';
import '../../programme/models/athlete_programme_completion.dart';
import '../../programme/models/programme_execution_context.dart';
import '../../programme/models/programme_progression_result.dart';
import '../../programme/services/athlete_programme_completion_service.dart';
import '../../session/services/programme_session_progression_coordinator.dart';
import '../../adaptation/models/adaptation_execution_result.dart';
import '../../adaptation/services/adaptation_execution_coordinator.dart';
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
    this.programmeCompletion,
  });

  final TrainingSessionRecord record;
  final bool progressionFailed;
  final String? progressionMessage;
  final ProgrammeProgressionResult? progressionResult;
  final AdaptationExecutionResult? adaptationResult;
  final AthleteProgrammeCompletionResult? programmeCompletion;
}

class PerformanceRecordSaveCoordinator {
  PerformanceRecordSaveCoordinator({
    PerformanceRecordStore? store,
    TrainingSessionRepository? trainingSessionRepository,
    // ignore: avoid_unused_constructor_parameters
    ProgrammeSessionProgressionCoordinator? progressionCoordinator,
    AdaptationExecutionCoordinator? adaptationCoordinator,
    AthleteProgrammeCompletionService? programmeCompletionService,
    AthleteLocalRepository? localRepository,
  }) : _store = store ?? SupabasePerformanceRecordStore(),
       _trainingSessionRepository =
           trainingSessionRepository ?? const TrainingSessionRepository(),
       _adaptationCoordinator =
           adaptationCoordinator ?? AdaptationExecutionCoordinator(),
       _programmeCompletionService =
           programmeCompletionService ??
           AthleteProgrammeCompletionService(
             performanceStore: store ?? SupabasePerformanceRecordStore(),
             localRepository: localRepository,
           );

  final PerformanceRecordStore _store;
  final TrainingSessionRepository _trainingSessionRepository;
  final AdaptationExecutionCoordinator _adaptationCoordinator;
  final AthleteProgrammeCompletionService _programmeCompletionService;

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
    String? idempotencyKey,
  }) async {
    final validation = controller.validateForCompletion();
    if (!validation.isValid) {
      throw PerformanceRecordStoreException(
        validation.fieldErrors.values.first,
      );
    }

    // Sprint 1.5A programme path: one atomic RPC for completion + cursor.
    if (programmeContext != null && programmeContext.isProgrammeBacked) {
      return _completeProgrammeBacked(
        controller: controller,
        trainingSessionId: trainingSessionId,
        athleteId: athleteId,
        programmeContext: programmeContext,
        idempotencyKey: idempotencyKey,
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

    return PerformanceCompletionResult(record: record);
  }

  Future<PerformanceCompletionResult> _completeProgrammeBacked({
    required PerformanceCaptureController controller,
    required int trainingSessionId,
    required String athleteId,
    required ProgrammeExecutionContext programmeContext,
    String? idempotencyKey,
  }) async {
    final logicalKey = _programmeCompletionService.buildLogicalCompletionKey(
      programmeContext,
    );
    final key =
        idempotencyKey ??
        _programmeCompletionService.buildIdempotencyKey(
          logicalCompletionKey: logicalKey,
          requestNonce:
              '${DateTime.now().toUtc().microsecondsSinceEpoch}-'
              '${identityHashCode(controller)}',
        );

    final programmeCompletion = await _programmeCompletionService.submit(
      controller: controller,
      programmeContext: programmeContext,
      trainingSessionId: trainingSessionId,
      idempotencyKey: key,
      frozenLogicalKey: logicalKey,
    );

    if (!programmeCompletion.isSuccess) {
      final record = const PerformanceRecordMapper().fromDraft(
        controller.buildPersistableDraft(
          status: controller.resolveCompletionStatus(),
        ),
      );
      return PerformanceCompletionResult(
        record: programmeCompletion.record ?? record,
        progressionFailed: true,
        progressionMessage:
            programmeCompletion.message ??
            programmeCompletion.code ??
            programmeCompletion.status.name,
        programmeCompletion: programmeCompletion,
      );
    }

    final record = programmeCompletion.record!;
    final endedEarly = record.status != TrainingSessionRecordStatus.completed;
    try {
      await _trainingSessionRepository.completeSession(
        trainingSessionId,
        completion: TrainingSessionCompletionContext(
          endedEarly: endedEarly,
          sessionNote: record.athleteNote,
          completedExerciseCount: record.completedBlockCount,
          totalExerciseCount: record.blockResults.length,
        ),
      );
    } catch (_) {
      // Secondary context only; RPC already committed authority.
    }

    // Adaptation remains behind existing acceptance policy (defaults skip).
    AdaptationExecutionResult? adaptationResult;
    try {
      adaptationResult = await _adaptationCoordinator
          .executeAfterSessionCompleted(
            athleteId: athleteId,
            record: record,
            programmeContext: programmeContext,
            trainingSessionId: trainingSessionId,
            endedEarly: endedEarly,
            progressionResult: null,
          );
    } catch (_) {
      adaptationResult = AdaptationExecutionResult.skipped(
        'Adaptation execution failed',
      );
    }

    return PerformanceCompletionResult(
      record: record,
      progressionFailed: false,
      programmeCompletion: programmeCompletion,
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
