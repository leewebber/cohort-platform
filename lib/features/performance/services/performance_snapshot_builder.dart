import '../../../core/utils/database_uuid.dart';
import '../../../models/block_performance_capture_mode.dart';
import '../../../models/session_block_type.dart';
import '../../programme/models/programme_execution_context.dart';
import '../../session/services/athlete_exercise_label_resolver.dart';
import '../../session/models/session_execution_plan.dart';
import '../models/active_performance_draft.dart';
import '../models/block_capture_mode_resolver.dart';
import '../models/performance_result_data.dart';
import '../models/performance_snapshot.dart';
import '../models/training_block_result_status.dart';
import 'interval_capture_contract.dart';
import 'interval_set_sync.dart';

class PerformanceSnapshotBuilder {
  const PerformanceSnapshotBuilder();

  ExercisePerformanceSnapshot exerciseSnapshotFromSummary(
    SessionExecutionExerciseSummary summary, {
    required int position,
    SessionBlockType blockType = SessionBlockType.custom,
  }) {
    return ExercisePerformanceSnapshot(
      sourceExerciseId: summary.exerciseId,
      displayName: AthleteExerciseLabelResolver.fromExecutionSummary(summary),
      labelOverride: summary.displayLabelOverride,
      position: position,
      loadKind: StrengthActualLoadKind.fromPrescription(
        blockType: blockType,
        prescription: summary.prescription,
      ),
    );
  }

  SessionPerformanceSnapshot buildSessionSnapshot({
    required SessionExecutionPlan plan,
    ProgrammeExecutionContext? programmeContext,
    String? assignmentId,
    String? coachDisplayName,
  }) {
    return SessionPerformanceSnapshot(
      sourceProtocolId: plan.sessionId,
      sessionTitle: plan.sessionTitle,
      sessionDescription: plan.coachNotes,
      programmeTitle: programmeContext?.programmeName,
      programmeContextLabel:
          plan.programmeContextLabel ??
          (programmeContext != null
              ? 'Week ${programmeContext.weekNumber} · ${programmeContext.dayKey}'
              : null),
      coachDisplayName: coachDisplayName,
      assignmentId: assignmentId ?? programmeContext?.assignmentId,
      programmeId: programmeContext?.programmeVersionId,
      programmeSessionId: programmeContext?.sessionSlotId,
      lineageCode: programmeContext?.lineageCode,
      blocks: plan.blocks
          .map(
            (block) => _blockSnapshot(block),
          )
          .toList(growable: false),
    );
  }

  List<BlockPerformanceDraft> buildInitialBlockDrafts(
    SessionExecutionPlan plan,
  ) {
    return plan.blocks
        .map((block) {
          final snapshot = _blockSnapshot(block);
          final captureMode = BlockCaptureModeResolver.resolveForBlock(block);
          final resultType = BlockCaptureModeResolver.resultTypeFor(
            captureMode,
          );
          final resultData = BlockCaptureModeResolver.initialResultData(
            captureMode,
            block,
          );
          var exercises = _authoredSummaries(block)
              .map(
                (entry) => _initialExerciseDraft(
                  entry.summary,
                  position: entry.position,
                  blockType: block.blockType,
                ),
              )
              .toList(growable: false);
          if (resultData is IntervalResultData &&
              IntervalCaptureContract.requiresPerIntervalRows(block)) {
            exercises = IntervalSetSync.ensureAuthoredRows(
              exercises: exercises,
              result: resultData,
              block: block,
            );
          }

          return BlockPerformanceDraft(
            blockResultId: DatabaseUuid.newV4(),
            sourceBlockId: block.blockId,
            blockSnapshot: snapshot,
            position: block.position,
            status: TrainingBlockResultStatus.notStarted,
            captureMode: captureMode,
            resultType: resultType,
            resultData: resultData,
            exerciseResults: exercises,
          );
        })
        .toList(growable: false);
  }

  BlockPerformanceSnapshot _blockSnapshot(SessionExecutionBlock block) {
    final result = IntervalCaptureContract.authoredResult(block);
    return BlockPerformanceSnapshot(
      sourceBlockId: block.blockId,
      title: block.title,
      blockType: block.blockType,
      content: block.content,
      workoutFormat: block.workoutFormat,
      position: block.position,
      timerSummary: block.timerSummary,
      coachNotes: block.coachNotes,
      performanceCaptureMode: block.performanceCaptureMode.dbValue,
      workSeconds: block.timerConfiguration?.workSeconds,
      recoverySeconds: block.timerConfiguration?.restSeconds,
      tracking: block.timerConfiguration?.tracking ?? const [],
      comparisonFamily: result.comparisonFamily,
      exercises: _authoredExerciseSnapshots(block),
    );
  }

  List<ExercisePerformanceSnapshot> _authoredExerciseSnapshots(
    SessionExecutionBlock block,
  ) {
    return _authoredSummaries(block)
        .map(
          (entry) => exerciseSnapshotFromSummary(
            entry.summary,
            position: entry.position,
            blockType: block.blockType,
          ),
        )
        .toList(growable: false);
  }

  List<({SessionExecutionExerciseSummary summary, int position})>
  _authoredSummaries(SessionExecutionBlock block) {
    final indexed = block.linkedExercises.asMap().entries.toList()
      ..sort((a, b) {
        final aPos = a.value.position > 0 ? a.value.position : a.key + 1;
        final bPos = b.value.position > 0 ? b.value.position : b.key + 1;
        return aPos.compareTo(bPos);
      });
    return indexed
        .map(
          (entry) => (
            summary: entry.value,
            position: entry.value.position > 0
                ? entry.value.position
                : entry.key + 1,
          ),
        )
        .toList(growable: false);
  }

  ExercisePerformanceDraft _initialExerciseDraft(
    SessionExecutionExerciseSummary summary, {
    required int position,
    required SessionBlockType blockType,
  }) {
    final prescription = summary.prescription;
    final capture = prescription?.performanceCapture;
    final loadKind = StrengthActualLoadKind.fromPrescription(
      blockType: blockType,
      prescription: prescription,
    );
    final rowCount = prescription == null || prescription.sets <= 0
        ? 0
        : prescription.sets;

    return ExercisePerformanceDraft(
      exerciseResultId: DatabaseUuid.newV4(),
      sourceExerciseId: summary.exerciseId,
      exerciseSnapshot: exerciseSnapshotFromSummary(
        summary,
        position: position,
        blockType: blockType,
      ),
      position: position,
      sets: List.generate(
        rowCount,
        (index) => SetPerformanceDraft.empty(
          setNumber: index + 1,
          position: index + 1,
          loadUnit: loadKind.expectsExternalLoad
              ? (capture?.loadUnit?.trim().isNotEmpty == true
                    ? capture!.loadUnit!.trim()
                    : 'kg')
              : null,
          distanceUnit: capture?.distanceUnit?.trim().isNotEmpty == true
              ? capture!.distanceUnit!.trim()
              : null,
        ),
        growable: false,
      ),
    );
  }
}
