import '../../../core/utils/database_uuid.dart';
import '../../../models/session_block_type.dart';
import '../../../models/workout_format.dart';
import '../../programme/models/programme_execution_context.dart';
import '../../session/models/session_execution_plan.dart';
import '../models/active_performance_draft.dart';
import '../models/block_capture_mode_resolver.dart';
import '../models/performance_result_data.dart';
import '../models/performance_result_type.dart';
import '../models/training_block_result_status.dart';
import '../models/training_session_record_status.dart';
import '../services/performance_snapshot_builder.dart';
import '../services/performance_validation_service.dart';

class PerformanceCaptureController {
  PerformanceCaptureController({
    required ActivePerformanceDraft draft,
    PerformanceSnapshotBuilder? snapshotBuilder,
    PerformanceValidationService? validationService,
  })  : _draft = draft,
        _snapshotBuilder = snapshotBuilder ?? const PerformanceSnapshotBuilder(),
        _validationService =
            validationService ?? const PerformanceValidationService();

  final PerformanceSnapshotBuilder _snapshotBuilder;
  final PerformanceValidationService _validationService;
  ActivePerformanceDraft _draft;

  ActivePerformanceDraft get draft => _draft;

  static PerformanceCaptureController initializeFromExecutionPlan({
    required SessionExecutionPlan plan,
    required String athleteId,
    required int trainingSessionId,
    ProgrammeExecutionContext? programmeContext,
    ActivePerformanceDraft? restoredDraft,
  }) {
    if (restoredDraft != null) {
      return PerformanceCaptureController(draft: restoredDraft);
    }

    const snapshotBuilder = PerformanceSnapshotBuilder();
    final snapshot = snapshotBuilder.buildSessionSnapshot(
      plan: plan,
      programmeContext: programmeContext,
      assignmentId: programmeContext?.assignmentId,
    );
    final blockDrafts = snapshotBuilder.buildInitialBlockDrafts(plan);
    final firstBlockId =
        plan.blocks.isNotEmpty ? plan.blocks.first.blockId : null;

    return PerformanceCaptureController(
      draft: ActivePerformanceDraft(
        recordId: DatabaseUuid.newV4(),
        athleteId: athleteId,
        trainingSessionId: trainingSessionId,
        sourceProtocolId: plan.sessionId,
        sessionSnapshot: snapshot,
        status: TrainingSessionRecordStatus.inProgress,
        startedAt: DateTime.now().toUtc(),
        programmeId: programmeContext?.programmeVersionId,
        assignmentId: programmeContext?.assignmentId,
        programmeSessionId: programmeContext?.sessionSlotId,
        activeBlockId: firstBlockId,
        blockDrafts: blockDrafts,
      ),
    );
  }

  PerformanceCaptureController updateSessionRpe(int? rpe) {
    _draft = _draft.copyWith(overallRpe: rpe);
    return this;
  }

  PerformanceCaptureController updateSessionNote(String? note) {
    _draft = _draft.copyWith(athleteNote: _trim(note));
    return this;
  }

  PerformanceCaptureController setActiveBlock(String? blockId) {
    _draft = _draft.copyWith(activeBlockId: blockId);
    return this;
  }

  PerformanceCaptureController setBlockCaptureMode(
    String sourceBlockId,
    BlockCaptureMode mode,
  ) {
    return _updateBlock(sourceBlockId, (block) {
      final resultType = BlockCaptureModeResolver.resultTypeFor(mode);
      return block.copyWith(
        captureMode: mode,
        resultType: resultType,
        resultData: BlockCaptureModeResolver.initialResultData(
          mode,
          _executionBlockFor(block),
        ),
      );
    });
  }

  PerformanceCaptureController updateBlockResultData(
    String sourceBlockId,
    PerformanceResultData resultData,
  ) {
    return _updateBlock(
      sourceBlockId,
      (block) => block.copyWith(resultData: resultData),
    );
  }

  PerformanceCaptureController updateBlockNote(
    String sourceBlockId,
    String? note,
  ) {
    return _updateBlock(
      sourceBlockId,
      (block) => block.copyWith(athleteNote: _trim(note)),
    );
  }

  PerformanceCaptureController addSet(String sourceBlockId, String exerciseId) {
    return _updateBlock(sourceBlockId, (block) {
      final exercises = block.exerciseResults.map((exercise) {
        if (exercise.sourceExerciseId != exerciseId) return exercise;
        final nextNumber = exercise.sets.isEmpty
            ? 1
            : exercise.sets
                    .map((s) => s.setNumber)
                    .reduce((a, b) => a > b ? a : b) +
                1;
        final nextPosition = exercise.sets.length + 1;
        return exercise.copyWith(
          sets: [
            ...exercise.sets,
            SetPerformanceDraft.empty(
              setNumber: nextNumber,
              position: nextPosition,
            ),
          ],
        );
      }).toList(growable: false);
      return block.copyWith(exerciseResults: exercises);
    });
  }

  PerformanceCaptureController updateSet(
    String sourceBlockId,
    String exerciseId,
    String setResultId,
    SetPerformanceDraft Function(SetPerformanceDraft current) update,
  ) {
    return _updateBlock(sourceBlockId, (block) {
      final exercises = block.exerciseResults.map((exercise) {
        if (exercise.sourceExerciseId != exerciseId) return exercise;
        final sets = exercise.sets
            .map(
              (set) => set.setResultId == setResultId ? update(set) : set,
            )
            .toList(growable: false);
        return exercise.copyWith(sets: sets);
      }).toList(growable: false);
      return block.copyWith(exerciseResults: exercises);
    });
  }

  PerformanceCaptureController duplicateSet(
    String sourceBlockId,
    String exerciseId,
    String setResultId,
  ) {
    return _updateBlock(sourceBlockId, (block) {
      final exercises = block.exerciseResults.map((exercise) {
        if (exercise.sourceExerciseId != exerciseId) return exercise;
        final source = exercise.sets.firstWhere(
          (set) => set.setResultId == setResultId,
        );
        final duplicate = source.copyWith(
          setResultId: DatabaseUuid.newV4(),
          setNumber: source.setNumber + 1,
          position: exercise.sets.length + 1,
          completed: false,
        );
        return exercise.copyWith(sets: [...exercise.sets, duplicate]);
      }).toList(growable: false);
      return block.copyWith(exerciseResults: exercises);
    });
  }

  PerformanceCaptureController removeSet(
    String sourceBlockId,
    String exerciseId,
    String setResultId,
  ) {
    return _updateBlock(sourceBlockId, (block) {
      final exercises = block.exerciseResults.map((exercise) {
        if (exercise.sourceExerciseId != exerciseId) return exercise;
        final sets = exercise.sets
            .where((set) => set.setResultId != setResultId)
            .toList(growable: false);
        return exercise.copyWith(sets: sets);
      }).toList(growable: false);
      return block.copyWith(exerciseResults: exercises);
    });
  }

  PerformanceCaptureController markBlockComplete(String sourceBlockId) {
    return _updateBlock(sourceBlockId, (block) {
      return block.copyWith(
        status: TrainingBlockResultStatus.completed,
        startedAt: block.startedAt ?? DateTime.now().toUtc(),
        completedAt: DateTime.now().toUtc(),
        resultData: _syncResultCompletion(block.resultData, completed: true),
      );
    });
  }

  PerformanceCaptureController reopenBlock(String sourceBlockId) {
    return _updateBlock(
      sourceBlockId,
      (block) => block.copyWith(
        status: TrainingBlockResultStatus.inProgress,
        completedAt: null,
        resultData: _syncResultCompletion(block.resultData, completed: false),
      ),
    );
  }

  PerformanceCaptureController markBlockSkipped(String sourceBlockId) {
    return _updateBlock(
      sourceBlockId,
      (block) => block.copyWith(
        status: TrainingBlockResultStatus.skipped,
        completedAt: DateTime.now().toUtc(),
      ),
    );
  }

  PerformanceCaptureController markSessionAbandoned() {
    _draft = _draft.copyWith(
      status: TrainingSessionRecordStatus.abandoned,
      completedAt: DateTime.now().toUtc(),
      durationSeconds:
          DateTime.now().toUtc().difference(_draft.startedAt).inSeconds,
    );
    return this;
  }

  ActivePerformanceDraft buildPersistableDraft({
    required TrainingSessionRecordStatus status,
    DateTime? completedAt,
  }) {
    final endedAt = completedAt ?? DateTime.now().toUtc();
    return _draft.copyWith(
      status: status,
      completedAt: endedAt,
      durationSeconds: endedAt.difference(_draft.startedAt).inSeconds,
    );
  }

  PerformanceValidationResult validateForCompletion() {
    return _validationService.validateForCompletion(_draft);
  }

  TrainingSessionRecordStatus resolveCompletionStatus() {
    return _validationService.resolveCompletionStatus(_draft);
  }

  PerformanceCaptureController _updateBlock(
    String sourceBlockId,
    BlockPerformanceDraft Function(BlockPerformanceDraft current) update,
  ) {
    final blocks = _draft.blockDrafts.map((block) {
      if (block.sourceBlockId != sourceBlockId) return block;
      final updated = update(block);
      return updated.copyWith(
        startedAt: updated.startedAt ??
            (updated.status == TrainingBlockResultStatus.inProgress
                ? DateTime.now().toUtc()
                : null),
      );
    }).toList(growable: false);
    _draft = _draft.copyWith(blockDrafts: blocks);
    return this;
  }

  SessionExecutionBlock _executionBlockFor(BlockPerformanceDraft block) {
    return SessionExecutionBlock(
      blockId: block.sourceBlockId,
      title: block.blockSnapshot.title,
      blockType: block.blockSnapshot.blockType,
      content: block.blockSnapshot.content,
      workoutFormat: block.blockSnapshot.workoutFormat,
      position: block.blockSnapshot.position,
    );
  }

  static String? _trim(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static PerformanceResultData _syncResultCompletion(
    PerformanceResultData? resultData, {
    required bool completed,
  }) {
    final result = resultData ?? const CompletionResultData();
    if (result is CompletionResultData) {
      return result.copyWith(completed: completed);
    }
    if (result is EnduranceResultData) {
      return result.copyWith(completed: completed);
    }
    if (result is ForTimeResultData) {
      return result.copyWith(completed: completed);
    }
    return result;
  }
}
