import 'package:cohort_platform/features/performance/models/active_performance_draft.dart';
import 'package:cohort_platform/features/performance/models/performance_result_data.dart';
import 'package:cohort_platform/features/performance/models/performance_result_type.dart';
import 'package:cohort_platform/features/performance/models/performance_snapshot.dart';
import 'package:cohort_platform/features/performance/models/training_block_result_status.dart';
import 'package:cohort_platform/features/performance/models/training_session_record.dart';
import 'package:cohort_platform/features/performance/widgets/performance_capture_widgets.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/services/athlete_exercise_label_resolver.dart';
import 'package:cohort_platform/models/exercise.dart';
import 'package:cohort_platform/models/session_block_exercise_link.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AthleteExerciseLabelResolver', () {
    test('prefers label override', () {
      expect(
        AthleteExerciseLabelResolver.fromExerciseLink(
          link: const SessionBlockExerciseLink(
            localId: 'link-1',
            exerciseId: 'SQ-001',
            position: 1,
            displayLabelOverride: 'Tempo Back Squat',
          ),
        ),
        'Tempo Back Squat',
      );
    });

    test('execution summary uses displayLabelOverride over ID displayName', () {
      expect(
        AthleteExerciseLabelResolver.fromExecutionSummary(
          const SessionExecutionExerciseSummary(
            exerciseId: 'SQ-001',
            displayName: 'SQ-001',
            displayLabelOverride: 'Back Squat',
          ),
        ),
        'Back Squat',
      );
    });

    test('uses snapshot display name for historical records', () {
      expect(
        AthleteExerciseLabelResolver.fromSnapshot(
          const ExercisePerformanceSnapshot(
            sourceExerciseId: 'SQ-001',
            displayName: 'Back Squat',
            position: 1,
          ),
          historical: true,
        ),
        'Back Squat',
      );
    });

    test('blank displayName falls back to exercise ID', () {
      expect(
        AthleteExerciseLabelResolver.fromSnapshot(
          const ExercisePerformanceSnapshot(
            sourceExerciseId: 'SQ-001',
            displayName: '',
            position: 1,
          ),
          historical: true,
        ),
        'SQ-001',
      );
    });

    test('missing displayName falls back to exercise ID', () {
      expect(
        AthleteExerciseLabelResolver.resolve(
          sourceExerciseId: 'BP-001',
          snapshotDisplayName: '   ',
          historical: true,
        ),
        'BP-001',
      );
    });

    test('active execution uses live exercise name when snapshot stores ID', () {
      expect(
        AthleteExerciseLabelResolver.fromExecutionSummary(
          SessionExecutionExerciseSummary(
            exerciseId: 'SQ-001',
            displayName: 'SQ-001',
            exercise: const Exercise(
              exerciseId: 'SQ-001',
              name: 'Back Squat',
              published: true,
            ),
          ),
        ),
        'Back Squat',
      );
    });

    test('historical name remains stable if live exercise name changes', () {
      expect(
        AthleteExerciseLabelResolver.fromExerciseDraft(
          ExercisePerformanceDraft(
            exerciseResultId: 'result-1',
            sourceExerciseId: 'SQ-001',
            exerciseSnapshot: const ExercisePerformanceSnapshot(
              sourceExerciseId: 'SQ-001',
              displayName: 'Back Squat',
              position: 1,
            ),
            position: 1,
          ),
          executionSummary: SessionExecutionExerciseSummary(
            exerciseId: 'SQ-001',
            displayName: 'Low Bar Back Squat',
            exercise: const Exercise(
              exerciseId: 'SQ-001',
              name: 'Low Bar Back Squat',
              published: true,
            ),
          ),
          historical: true,
        ),
        'Back Squat',
      );
    });

    test('performance draft resolves via execution summary during active capture',
        () {
      expect(
        AthleteExerciseLabelResolver.fromExerciseDraft(
          ExercisePerformanceDraft(
            exerciseResultId: 'result-1',
            sourceExerciseId: 'BP-001',
            exerciseSnapshot: const ExercisePerformanceSnapshot(
              sourceExerciseId: 'BP-001',
              displayName: 'BP-001',
              position: 1,
            ),
            position: 1,
          ),
          executionSummary: const SessionExecutionExerciseSummary(
            exerciseId: 'BP-001',
            displayName: 'BP-001',
            exercise: Exercise(
              exerciseId: 'BP-001',
              name: 'Bench Press',
              published: true,
            ),
          ),
        ),
        'Bench Press',
      );
    });

    test('saved exercise result prefers snapshot for history detail', () {
      expect(
        AthleteExerciseLabelResolver.fromExerciseResult(
          TrainingExerciseResult(
            exerciseResultId: 'saved-1',
            blockResultId: 'block-1',
            sourceExerciseId: 'SQ-001',
            exerciseSnapshot: const ExercisePerformanceSnapshot(
              sourceExerciseId: 'SQ-001',
              displayName: 'Back Squat',
              position: 1,
            ),
            position: 1,
            setResults: const [],
          ),
        ),
        'Back Squat',
      );
    });
  });

  group('Athlete execution label UI', () {
    BlockPerformanceDraft strengthDraftWithIdSnapshot() {
      return BlockPerformanceDraft(
        blockResultId: 'block-result-1',
        sourceBlockId: 'block-strength',
        blockSnapshot: const BlockPerformanceSnapshot(
          sourceBlockId: 'block-strength',
          title: 'Strength',
          blockType: SessionBlockType.strength,
          content: 'Back squat and bench press',
          workoutFormat: WorkoutFormat.none,
          position: 1,
        ),
        position: 1,
        status: TrainingBlockResultStatus.inProgress,
        captureMode: BlockCaptureMode.strength,
        resultType: PerformanceResultType.strength,
        resultData: const StrengthResultData(),
        exerciseResults: [
          ExercisePerformanceDraft(
            exerciseResultId: 'exercise-result-1',
            sourceExerciseId: 'SQ-001',
            exerciseSnapshot: const ExercisePerformanceSnapshot(
              sourceExerciseId: 'SQ-001',
              displayName: 'SQ-001',
              position: 1,
            ),
            position: 1,
          ),
          ExercisePerformanceDraft(
            exerciseResultId: 'exercise-result-2',
            sourceExerciseId: 'BP-001',
            exerciseSnapshot: const ExercisePerformanceSnapshot(
              sourceExerciseId: 'BP-001',
              displayName: 'BP-001',
              position: 2,
            ),
            position: 2,
          ),
        ],
      );
    }

    const linkedExercises = [
      SessionExecutionExerciseSummary(
        exerciseId: 'SQ-001',
        displayName: 'SQ-001',
        exercise: Exercise(
          exerciseId: 'SQ-001',
          name: 'Back Squat',
          published: true,
        ),
      ),
      SessionExecutionExerciseSummary(
        exerciseId: 'BP-001',
        displayName: 'BP-001',
        exercise: Exercise(
          exerciseId: 'BP-001',
          name: 'Bench Press',
          published: true,
        ),
      ),
    ];

    testWidgets('strength editor headings use display names instead of IDs',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlockResultEditor(
              blockDraft: strengthDraftWithIdSnapshot(),
              linkedExercises: linkedExercises,
              onResultChanged: (_) {},
              onAddSet: (_) {},
              onUpdateSet: (_, __, ___) {},
              onDuplicateSet: (_, __) {},
              onRemoveSet: (_, __) {},
            ),
          ),
        ),
      );

      expect(find.text('Back Squat'), findsOneWidget);
      expect(find.text('Bench Press'), findsOneWidget);
      expect(find.text('SQ-001'), findsNothing);
      expect(find.text('BP-001'), findsNothing);
    });
  });

  group('HistoricalBlockResultCard', () {
    testWidgets('uses snapshot exercise names in history detail', (tester) async {
      final block = TrainingBlockResult(
        blockResultId: 'block-1',
        sessionRecordId: 'session-1',
        sourceBlockId: 'block-strength',
        blockSnapshot: const BlockPerformanceSnapshot(
          sourceBlockId: 'block-strength',
          title: 'Strength',
          blockType: SessionBlockType.strength,
          content: 'Strength work',
          workoutFormat: WorkoutFormat.none,
          position: 1,
        ),
        position: 1,
        status: TrainingBlockResultStatus.completed,
        resultType: PerformanceResultType.strength,
        exerciseResults: [
          TrainingExerciseResult(
            exerciseResultId: 'exercise-1',
            blockResultId: 'block-1',
            sourceExerciseId: 'SQ-001',
            exerciseSnapshot: const ExercisePerformanceSnapshot(
              sourceExerciseId: 'SQ-001',
              displayName: 'Back Squat',
              position: 1,
            ),
            position: 1,
            setResults: const [],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HistoricalBlockResultCard(block: block),
          ),
        ),
      );

      expect(find.text('Back Squat'), findsOneWidget);
      expect(find.text('SQ-001'), findsNothing);
    });
  });
}
