import 'dart:convert';

import '../../../core/utils/database_uuid.dart';
import '../../programme/models/programme_execution_context.dart';
import '../../session/models/session_execution_plan.dart';
import '../../session/models/structured_running_execution.dart';
import '../models/active_performance_draft.dart';
import '../models/block_capture_mode_resolver.dart';
import '../models/interval_work_result.dart';
import '../models/performance_result_data.dart';
import '../models/performance_result_type.dart';
import '../models/performance_snapshot.dart';
import '../models/training_block_result_status.dart';
import '../models/training_session_record_status.dart';
import '../services/circuit_set_sync.dart';
import '../services/completed_session_duration.dart';
import '../services/interval_set_sync.dart';
import '../services/performance_snapshot_builder.dart';
import '../services/performance_validation_service.dart';

class PerformanceCaptureController {
  factory PerformanceCaptureController({
    required ActivePerformanceDraft draft,
    PerformanceValidationService? validationService,
  }) => PerformanceCaptureController._(
    draft,
    validationService ?? const PerformanceValidationService(),
  );

  PerformanceCaptureController._(this._draft, this._validationService);

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
    final firstBlockId = plan.blocks.isNotEmpty
        ? plan.blocks.first.blockId
        : null;

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
    return _updateBlock(sourceBlockId, (block) {
      var next = block.copyWith(resultData: resultData);
      if (resultData is IntervalResultData &&
          resultData.usesPerIntervalCapture) {
        next = next.copyWith(
          exerciseResults: IntervalSetSync.ensureAuthoredRows(
            exercises: next.exerciseResults,
            result: resultData,
          ),
        );
      }
      if (resultData is CircuitResultData && resultData.usesStationCapture) {
        next = next.copyWith(
          exerciseResults: CircuitSetSync.ensureAuthoredRows(
            exercises: next.exerciseResults,
            result: resultData,
          ),
        );
      }
      return next;
    });
  }

  PerformanceCaptureController bindStructuredRunning({
    required VerifiedStructuredRunningExecution execution,
    required bool allowInitialize,
  }) {
    final expectedSnapshot = StructuredRunningPerformanceSnapshot(
      workoutId: execution.workout.workoutId,
      executionMappingSha256: execution.executionMappingSha256,
      sessionBlockId: execution.sessionBlockId,
      packageContentHash: execution.frozenSnapshot.packageContentHash,
      frozenTargetSnapshot: execution.frozenSnapshot,
      workRepetitions: execution.workRepetitions
          .map(
            (item) => StructuredRunningRepetitionSnapshot(
              workoutId: item.workoutId,
              sessionBlockId: item.sessionBlockId,
              authoredStepId: item.authoredStepId,
              repeatOrdinal: item.repeatOrdinal,
              workSeconds: item.workSeconds,
            ),
          )
          .toList(growable: false),
    );
    final blocks = _draft.blockDrafts
        .map((block) {
          if (block.sourceBlockId != execution.sessionBlockId) return block;
          final existingAuthority = block.blockSnapshot.structuredRunning;
          final expectedRows = execution.workRepetitions;
          final existingResult = block.resultData;
          if (existingAuthority != null) {
            if (!_sameStructuredAuthority(
                  existingAuthority,
                  expectedSnapshot,
                ) ||
                existingResult is! IntervalResultData ||
                !_sameStructuredRows(existingResult.intervals, expectedRows)) {
              throw const StructuredRunningExecutionException(
                'structured_actuals_authority_mismatch',
                'Saved structured running actuals do not match launch authority.',
              );
            }
            return block;
          }
          if (!allowInitialize) {
            throw const StructuredRunningExecutionException(
              'missing_structured_actuals_authority',
              'Saved structured running actuals are missing immutable authority.',
            );
          }
          final rows = expectedRows
              .asMap()
              .entries
              .map(
                (entry) => IntervalWorkResult(
                  ordinal: entry.key + 1,
                  workSeconds: entry.value.workSeconds,
                  workoutId: entry.value.workoutId,
                  sessionBlockId: entry.value.sessionBlockId,
                  authoredStepId: entry.value.authoredStepId,
                  repeatOrdinal: entry.value.repeatOrdinal,
                ),
              )
              .toList(growable: false);
          return block.copyWith(
            blockSnapshot: block.blockSnapshot.withStructuredRunning(
              expectedSnapshot,
            ),
            resultType: PerformanceResultType.interval,
            resultData: IntervalResultData(
              totalIntervals: rows.length,
              paceUnit: IntervalPaceUnit.secondsPerKm,
              comparisonFamily: existingResult is IntervalResultData
                  ? existingResult.comparisonFamily
                  : null,
              intervals: rows,
            ),
          );
        })
        .toList(growable: false);
    if (!blocks.any(
      (block) => block.sourceBlockId == execution.sessionBlockId,
    )) {
      throw const StructuredRunningExecutionException(
        'mapped_block_mismatch',
        'Structured running actuals require the exact mapped block.',
      );
    }
    _draft = _draft.copyWith(blockDrafts: blocks);
    return this;
  }

  static bool _sameStructuredAuthority(
    StructuredRunningPerformanceSnapshot left,
    StructuredRunningPerformanceSnapshot right,
  ) => jsonEncode(left.toJson()) == jsonEncode(right.toJson());

  static bool _sameStructuredRows(
    List<IntervalWorkResult> rows,
    List<StructuredRunningWorkRepetition> expected,
  ) {
    if (rows.length != expected.length) return false;
    final byIdentity =
        <String, ({StructuredRunningWorkRepetition item, int ordinal})>{};
    for (var index = 0; index < expected.length; index++) {
      final item = expected[index];
      final key =
          '${item.workoutId}|${item.sessionBlockId}|'
          '${item.authoredStepId}|${item.repeatOrdinal}';
      if (byIdentity.containsKey(key)) return false;
      byIdentity[key] = (item: item, ordinal: index + 1);
    }
    final identities = <String>{};
    for (final row in rows) {
      final identity =
          '${row.workoutId}|${row.sessionBlockId}|'
          '${row.authoredStepId}|${row.repeatOrdinal}';
      final expectedRow = byIdentity[identity];
      if (expectedRow == null ||
          !identities.add(identity) ||
          row.workoutId != expectedRow.item.workoutId ||
          row.sessionBlockId != expectedRow.item.sessionBlockId ||
          row.authoredStepId != expectedRow.item.authoredStepId ||
          row.repeatOrdinal != expectedRow.item.repeatOrdinal ||
          row.ordinal != expectedRow.ordinal ||
          row.workSeconds != expectedRow.item.workSeconds ||
          !IntervalPaceUnit.isSupported(row.paceUnit)) {
        return false;
      }
    }
    return identities.length == byIdentity.length;
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
      final interval = block.resultData;
      if (interval is IntervalResultData && interval.usesPerIntervalCapture) {
        return block;
      }
      if (interval is CircuitResultData && interval.usesStationCapture) {
        return block;
      }
      final exercises = block.exerciseResults
          .map((exercise) {
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
          })
          .toList(growable: false);
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
      final exercises = block.exerciseResults
          .map((exercise) {
            if (exercise.sourceExerciseId != exerciseId) return exercise;
            final sets = exercise.sets
                .map(
                  (set) => set.setResultId == setResultId ? update(set) : set,
                )
                .toList(growable: false);
            return exercise.copyWith(sets: sets);
          })
          .toList(growable: false);
      return block.copyWith(exerciseResults: exercises);
    });
  }

  PerformanceCaptureController duplicateSet(
    String sourceBlockId,
    String exerciseId,
    String setResultId,
  ) {
    return _updateBlock(sourceBlockId, (block) {
      final interval = block.resultData;
      if (interval is IntervalResultData && interval.usesPerIntervalCapture) {
        return block;
      }
      if (interval is CircuitResultData && interval.usesStationCapture) {
        return block;
      }
      final exercises = block.exerciseResults
          .map((exercise) {
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
          })
          .toList(growable: false);
      return block.copyWith(exerciseResults: exercises);
    });
  }

  PerformanceCaptureController removeSet(
    String sourceBlockId,
    String exerciseId,
    String setResultId,
  ) {
    return _updateBlock(sourceBlockId, (block) {
      final interval = block.resultData;
      if (interval is IntervalResultData && interval.usesPerIntervalCapture) {
        return block;
      }
      if (interval is CircuitResultData && interval.usesStationCapture) {
        return block;
      }
      final exercises = block.exerciseResults
          .map((exercise) {
            if (exercise.sourceExerciseId != exerciseId) return exercise;
            final sets = exercise.sets
                .where((set) => set.setResultId != setResultId)
                .toList(growable: false);
            return exercise.copyWith(sets: sets);
          })
          .toList(growable: false);
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
      durationSeconds: CompletedSessionDuration.fromInstants(
        startedAt: _draft.startedAt,
        completedAt: DateTime.now().toUtc(),
      ),
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
      durationSeconds: CompletedSessionDuration.fromInstants(
        startedAt: _draft.startedAt,
        completedAt: endedAt,
      ),
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
    final blocks = _draft.blockDrafts
        .map((block) {
          if (block.sourceBlockId != sourceBlockId) return block;
          final updated = update(block);
          return updated.copyWith(
            startedAt:
                updated.startedAt ??
                (updated.status == TrainingBlockResultStatus.inProgress
                    ? DateTime.now().toUtc()
                    : null),
          );
        })
        .toList(growable: false);
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
