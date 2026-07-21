import 'package:cohort_platform/features/adaptation/services/post_completion_adaptation_evaluator.dart';
import 'package:cohort_platform/features/performance/models/performance_result_data.dart';
import 'package:cohort_platform/features/performance/models/performance_result_type.dart';
import 'package:cohort_platform/features/performance/models/performance_snapshot.dart';
import 'package:cohort_platform/features/performance/models/training_block_result_status.dart';
import 'package:cohort_platform/features/performance/models/training_session_record.dart';
import 'package:cohort_platform/features/performance/models/training_session_record_status.dart';
import 'package:cohort_platform/models/programme_slot_outcome.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PostCompletionAdaptationEvaluator', () {
    const evaluator = PostCompletionAdaptationEvaluator();

    const targetSlot = FutureProgrammeSlotRef(
      slotId: 'slot-2',
      weekNumber: 1,
      dayKey: 'day_2',
      sessionOrder: 1,
      protocolId: 'BW-001',
      slotTitle: 'Strength',
    );

    TrainingSessionRecord completedRecord({
      List<TrainingBlockResult> blocks = const [],
    }) {
      return TrainingSessionRecord(
        recordId: 'record-1',
        athleteId: 'athlete-1',
        status: TrainingSessionRecordStatus.completed,
        sessionSnapshot: const SessionPerformanceSnapshot(
          sourceProtocolId: 'BW-001',
          sessionTitle: 'Test',
        ),
        startedAt: DateTime.utc(2026, 7, 1),
        blockResults: blocks,
      );
    }

    TrainingBlockResult strengthBlock({
      required String exerciseId,
      required List<TrainingSetResult> sets,
    }) {
      return TrainingBlockResult(
        blockResultId: 'block-1',
        sessionRecordId: 'record-1',
        sourceBlockId: 'source-block-1',
        blockSnapshot: BlockPerformanceSnapshot(
          sourceBlockId: 'source-block-1',
          title: 'Squat',
          blockType: SessionBlockType.strength,
          content: 'Sets: 3',
          workoutFormat: WorkoutFormat.none,
          position: 1,
        ),
        status: TrainingBlockResultStatus.completed,
        resultType: PerformanceResultType.strength,
        position: 1,
        resultData: const StrengthResultData(),
        exerciseResults: [
          TrainingExerciseResult(
            exerciseResultId: 'exercise-result-1',
            blockResultId: 'block-1',
            sourceExerciseId: exerciseId,
            exerciseSnapshot: ExercisePerformanceSnapshot(
              sourceExerciseId: exerciseId,
              displayName: 'Back Squat',
              position: 1,
            ),
            position: 1,
            setResults: sets,
          ),
        ],
      );
    }

    test('skips when no future slot exists', () {
      final result = evaluator.evaluate(
        record: completedRecord(),
        plannedProtocolId: 'BW-001',
        completedSlotId: 'slot-1',
        assignmentOutcomes: const [],
        nextMatchingFutureSlot: null,
        strengthSummary: null,
        endedEarly: false,
        priorCompletedSameProtocolCount: 1,
      );

      expect(result, isNull);
    });

    test('load progression applies after consecutive full completions', () {
      final record = completedRecord(
        blocks: [
          strengthBlock(
            exerciseId: 'squat-001',
            sets: [
              const TrainingSetResult(
                setResultId: 'set-1',
                exerciseResultId: 'exercise-result-1',
                setNumber: 1,
                position: 1,
                reps: 8,
                load: 60,
                loadUnit: 'kg',
                completed: true,
              ),
              const TrainingSetResult(
                setResultId: 'set-2',
                exerciseResultId: 'exercise-result-1',
                setNumber: 2,
                position: 2,
                reps: 8,
                load: 60,
                loadUnit: 'kg',
                completed: true,
              ),
            ],
          ),
        ],
      );

      final summary = evaluator.summarizeStrengthPerformance(record);

      final evaluation = evaluator.evaluate(
        record: record,
        plannedProtocolId: 'BW-001',
        completedSlotId: 'slot-1',
        assignmentOutcomes: const [
          ProgrammeSlotOutcome(
            id: 'outcome-1',
            assignmentId: 'assignment-1',
            sessionSlotId: 'slot-0',
            weekNumber: 1,
            dayKey: 'day_0',
            sessionOrder: 1,
            outcomeStatus: ProgrammeSlotOutcomeStatus.completed,
          ),
        ],
        nextMatchingFutureSlot: targetSlot,
        strengthSummary: summary,
        endedEarly: false,
        priorCompletedSameProtocolCount: 1,
      );

      expect(evaluation, isNotNull);
      expect(evaluation!.type, AdaptationEvaluationType.loadProgression);
      expect(
        evaluation.explanation,
        contains('two consecutive sessions'),
      );
      expect(evaluation.newLoadKg, 62.5);
    });

    test('partial completion schedules recovery substitution', () {
      final evaluation = evaluator.evaluate(
        record: completedRecord(),
        plannedProtocolId: 'BW-001',
        completedSlotId: 'slot-1',
        assignmentOutcomes: const [],
        nextMatchingFutureSlot: targetSlot,
        strengthSummary: null,
        endedEarly: true,
        priorCompletedSameProtocolCount: 0,
      );

      expect(evaluation, isNotNull);
      expect(evaluation!.type, AdaptationEvaluationType.protocolSubstitution);
      expect(evaluation.explanation, contains('ended early'));
    });
  });
}
