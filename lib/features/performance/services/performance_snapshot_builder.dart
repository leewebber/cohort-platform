import '../../../core/utils/database_uuid.dart';
import '../../../models/block_performance_capture_mode.dart';
import '../../../models/session_block_type.dart';
import '../../../models/workout_format.dart';
import '../../programme/models/programme_execution_context.dart';
import '../../session/models/session_execution_plan.dart';
import '../models/active_performance_draft.dart';
import '../models/block_capture_mode_resolver.dart';
import '../models/performance_result_data.dart';
import '../models/performance_result_type.dart';
import '../models/performance_snapshot.dart';
import '../models/training_block_result_status.dart';

class PerformanceSnapshotBuilder {
  const PerformanceSnapshotBuilder();

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
      programmeContextLabel: plan.programmeContextLabel ??
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
            (block) => BlockPerformanceSnapshot(
              sourceBlockId: block.blockId,
              title: block.title,
              blockType: block.blockType,
              content: block.content,
              workoutFormat: block.workoutFormat,
              position: block.position,
              timerSummary: block.timerSummary,
              coachNotes: block.coachNotes,
              performanceCaptureMode: block.performanceCaptureMode.dbValue,
              exercises: block.linkedExercises
                  .asMap()
                  .entries
                  .map(
                    (entry) => ExercisePerformanceSnapshot(
                      sourceExerciseId: entry.value.exerciseId,
                      displayName: entry.value.displayName,
                      position: entry.key + 1,
                    ),
                  )
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
    );
  }

  List<BlockPerformanceDraft> buildInitialBlockDrafts(SessionExecutionPlan plan) {
    return plan.blocks.map((block) {
      final snapshot = BlockPerformanceSnapshot(
        sourceBlockId: block.blockId,
        title: block.title,
        blockType: block.blockType,
        content: block.content,
        workoutFormat: block.workoutFormat,
        position: block.position,
        timerSummary: block.timerSummary,
        coachNotes: block.coachNotes,
        performanceCaptureMode: block.performanceCaptureMode.dbValue,
        exercises: block.linkedExercises
            .asMap()
            .entries
            .map(
              (entry) => ExercisePerformanceSnapshot(
                sourceExerciseId: entry.value.exerciseId,
                displayName: entry.value.displayName,
                position: entry.key + 1,
              ),
            )
            .toList(growable: false),
      );

      final captureMode = BlockCaptureModeResolver.resolveForBlock(block);
      final resultType = BlockCaptureModeResolver.resultTypeFor(captureMode);

      return BlockPerformanceDraft(
        blockResultId: DatabaseUuid.newV4(),
        sourceBlockId: block.blockId,
        blockSnapshot: snapshot,
        position: block.position,
        status: TrainingBlockResultStatus.notStarted,
        captureMode: captureMode,
        resultType: resultType,
        resultData: BlockCaptureModeResolver.initialResultData(
          captureMode,
          block,
        ),
        exerciseResults: block.linkedExercises
            .asMap()
            .entries
            .map(
              (entry) => ExercisePerformanceDraft(
                exerciseResultId: DatabaseUuid.newV4(),
                sourceExerciseId: entry.value.exerciseId,
                exerciseSnapshot: ExercisePerformanceSnapshot(
                  sourceExerciseId: entry.value.exerciseId,
                  displayName: entry.value.displayName,
                  position: entry.key + 1,
                ),
                position: entry.key + 1,
              ),
            )
            .toList(growable: false),
      );
    }).toList(growable: false);
  }
}
