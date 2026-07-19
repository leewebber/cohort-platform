import 'package:cohort_platform/features/performance/models/block_capture_mode_resolver.dart';
import 'package:cohort_platform/features/performance/models/performance_result_type.dart';
import 'package:cohort_platform/features/performance/widgets/performance_numeric_field.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BlockCaptureModeResolver', () {
    test('legacy custom session with linked exercise only uses completion', () {
      final mode = BlockCaptureModeResolver.resolveForBlock(
        const SessionExecutionBlock(
          blockId: 'legacy-1',
          title: 'Session',
          blockType: SessionBlockType.custom,
          content: 'Warm-up row\nEasy pace',
          workoutFormat: WorkoutFormat.none,
          position: 1,
          linkedExercises: [
            SessionExecutionExerciseSummary(
              exerciseId: 'ROW-001',
              displayName: 'Row',
            ),
          ],
        ),
      );

      expect(mode, BlockCaptureMode.completion);
    });

    test('legacy custom session with structured prescription uses strength', () {
      final mode = BlockCaptureModeResolver.resolveForBlock(
        const SessionExecutionBlock(
          blockId: 'legacy-2',
          title: 'Session',
          blockType: SessionBlockType.custom,
          content: 'Back Squat\nSets: 5\nReps: 5\nLoad: 100 kg',
          workoutFormat: WorkoutFormat.none,
          position: 1,
          linkedExercises: [
            SessionExecutionExerciseSummary(
              exerciseId: 'SQ-001',
              displayName: 'Back Squat',
            ),
          ],
        ),
      );

      expect(mode, BlockCaptureMode.strength);
    });

    test('conditioning block with AMRAP format uses amrap capture', () {
      final mode = BlockCaptureModeResolver.resolveForBlock(
        const SessionExecutionBlock(
          blockId: 'block-amrap',
          title: 'Conditioning',
          blockType: SessionBlockType.conditioning,
          content: '12 min AMRAP burpees',
          workoutFormat: WorkoutFormat.amrap,
          position: 1,
        ),
      );

      expect(mode, BlockCaptureMode.amrap);
    });

    test('strength block type with linked exercise uses strength', () {
      final mode = BlockCaptureModeResolver.resolveForBlock(
        const SessionExecutionBlock(
          blockId: 'block-strength',
          title: 'Strength',
          blockType: SessionBlockType.strength,
          content: 'Back squat 5 x 5',
          workoutFormat: WorkoutFormat.none,
          position: 1,
          linkedExercises: [
            SessionExecutionExerciseSummary(
              exerciseId: 'SQ-001',
              displayName: 'Back Squat',
            ),
          ],
        ),
      );

      expect(mode, BlockCaptureMode.strength);
    });
  });

  group('PerformanceNumericField', () {
    testWidgets('preserves digit order while parent rebuilds on each change',
        (tester) async {
      var value = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return PerformanceNumericField(
                  key: const ValueKey('load-field'),
                  label: 'Load (kg)',
                  value: value,
                  allowDecimal: true,
                  onChanged: (next) => setState(() => value = next),
                );
              },
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '100');
      await tester.pump();

      expect(value, '100');
      expect(find.text('100'), findsOneWidget);
    });
  });
}
