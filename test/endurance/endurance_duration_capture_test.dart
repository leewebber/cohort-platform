import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/models/active_performance_draft.dart';
import 'package:cohort_platform/features/performance/models/performance_result_data.dart';
import 'package:cohort_platform/features/performance/models/performance_result_type.dart';
import 'package:cohort_platform/features/performance/models/performance_snapshot.dart';
import 'package:cohort_platform/features/performance/models/training_block_result_status.dart';
import 'package:cohort_platform/features/performance/models/training_session_record.dart';
import 'package:cohort_platform/features/performance/services/endurance_metrics_calculator.dart';
import 'package:cohort_platform/features/performance/services/performance_result_summary_formatter.dart';
import 'package:cohort_platform/features/performance/widgets/endurance_duration_field.dart';
import 'package:cohort_platform/features/performance/widgets/performance_capture_widgets.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EnduranceMetricsCalculator duration parsing', () {
    test('30:00 converts to 1800 seconds', () {
      final parsed = EnduranceMetricsCalculator.parseAthleteDuration('30:00');
      expect(parsed.isValid, isTrue);
      expect(parsed.seconds, 1800);
    });

    test('1:05:30 converts to 3930 seconds', () {
      final parsed = EnduranceMetricsCalculator.parseAthleteDuration('1:05:30');
      expect(parsed.isValid, isTrue);
      expect(parsed.seconds, 3930);
    });

    test('1800 seconds restores as 30:00', () {
      expect(
        EnduranceMetricsCalculator.formatAthleteDuration(1800),
        '30:00',
      );
    });

    test('3930 seconds restores as 1:05:30', () {
      expect(
        EnduranceMetricsCalculator.formatAthleteDuration(3930),
        '1:05:30',
      );
    });

    test('partial duration input does not throw', () {
      for (final value in ['3', '30', '30:', '30:0', '1:05:']) {
        expect(
          () => EnduranceMetricsCalculator.parseAthleteDuration(value),
          returnsNormally,
        );
        expect(
          EnduranceMetricsCalculator.parseAthleteDuration(value).isPartial,
          isTrue,
        );
      }
    });

    test('zero and null distance safety for live pace', () {
      expect(
        EnduranceMetricsCalculator.liveMetric(
          distance: null,
          distanceUnit: 'km',
          durationSeconds: 1800,
        ),
        isNull,
      );
      expect(
        EnduranceMetricsCalculator.liveMetric(
          distance: 0,
          distanceUnit: 'km',
          durationSeconds: 1800,
        ),
        isNull,
      );
    });

    test('zero and null duration safety for live pace', () {
      expect(
        EnduranceMetricsCalculator.liveMetric(
          distance: 5,
          distanceUnit: 'km',
          durationSeconds: null,
        ),
        isNull,
      );
      expect(
        EnduranceMetricsCalculator.liveMetric(
          distance: 5,
          distanceUnit: 'km',
          durationSeconds: 0,
        ),
        isNull,
      );
    });
  });

  group('EnduranceMetricsCalculator live pace', () {
    test('5 km + 30:00 displays 6:00 /km', () {
      final metric = EnduranceMetricsCalculator.liveMetric(
        distance: 5,
        distanceUnit: 'km',
        durationSeconds: 1800,
      );

      expect(metric?.label, 'Average pace');
      expect(metric?.value, '6:00 /km');
    });

    test('6.4 km + 30:00 displays 4:41 /km', () {
      final metric = EnduranceMetricsCalculator.liveMetric(
        distance: 6.4,
        distanceUnit: 'km',
        durationSeconds: 1800,
      );

      expect(metric?.value, '4:41 /km');
    });

    test('mile pace formatting', () {
      final metric = EnduranceMetricsCalculator.liveMetric(
        distance: 1,
        distanceUnit: 'mi',
        durationSeconds: 483,
      );

      expect(metric?.label, 'Average pace');
      expect(metric?.value, '8:03 /mi');
    });

    test('unsupported units hide derived speed metrics', () {
      expect(
        EnduranceMetricsCalculator.formatPaceOrSpeed(
          distance: 40,
          distanceUnit: 'watts',
          durationSeconds: 3600,
        ),
        isNull,
      );
      expect(
        EnduranceMetricsCalculator.liveMetric(
          distance: 40,
          distanceUnit: 'watts',
          durationSeconds: 3600,
        ),
        isNull,
      );
    });

    test('supported speed units format average speed', () {
      expect(
        EnduranceMetricsCalculator.formatPaceOrSpeed(
          distance: 10,
          distanceUnit: 'km/h',
          durationSeconds: 3600,
        ),
        'Avg speed 10.0 km/h',
      );
    });
  });

  group('EnduranceDurationField', () {
    testWidgets('restores formatted duration from durationSeconds', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnduranceDurationField(
              durationSeconds: 1800,
              onDurationSecondsChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.widgetWithText(TextField, '30:00'), findsOneWidget);
    });

    testWidgets('typing 30:00 emits 1800 seconds', (tester) async {
      int? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnduranceDurationField(
              durationSeconds: null,
              onDurationSecondsChanged: (value) => captured = value,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '30:00');
      await tester.pump();

      expect(captured, 1800);
    });

    testWidgets('backspace and re-entry remain stable', (tester) async {
      int? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EnduranceDurationField(
              durationSeconds: null,
              onDurationSecondsChanged: (value) => captured = value,
            ),
          ),
        ),
      );

      final field = find.byType(TextField);
      await tester.enterText(field, '30:00');
      await tester.pump();
      expect(captured, 1800);

      await tester.enterText(field, '30:0');
      await tester.pump();
      expect(
        EnduranceMetricsCalculator.parseAthleteDuration('30:0').isPartial,
        isTrue,
      );

      await tester.enterText(field, '30:00');
      await tester.pump();
      expect(captured, 1800);
    });
  });

  group('Endurance editor UI', () {
    testWidgets('shows live pace for 5 km and 30:00', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlockResultEditor(
              blockDraft: BlockPerformanceDraft(
                blockResultId: 'block-1',
                sourceBlockId: 'run-1',
                blockSnapshot: const BlockPerformanceSnapshot(
                  sourceBlockId: 'run-1',
                  title: 'Run',
                  blockType: SessionBlockType.conditioning,
                  content: 'Steady run',
                  workoutFormat: WorkoutFormat.none,
                  position: 1,
                ),
                position: 1,
                status: TrainingBlockResultStatus.inProgress,
                captureMode: BlockCaptureMode.endurance,
                resultType: PerformanceResultType.endurance,
                resultData: const EnduranceResultData(
                  distance: 5,
                  distanceUnit: 'km',
                  durationSeconds: 1800,
                ),
              ),
              onResultChanged: (_) {},
              onAddSet: (_) {},
              onUpdateSet: (_, __, ___) {},
              onDuplicateSet: (_, __) {},
              onRemoveSet: (_, __) {},
            ),
          ),
        ),
      );

      expect(find.text('Average pace'), findsOneWidget);
      expect(find.text('6:00 /km'), findsOneWidget);
      expect(find.text('Duration (seconds)'), findsNothing);
    });
  });

  group('Endurance persistence and history', () {
    test('saved endurance result still persists durationSeconds', () {
      const result = EnduranceResultData(
        distance: 5,
        distanceUnit: 'km',
        durationSeconds: 1800,
      );

      final decoded = PerformanceResultData.fromJson(result.toJson());
      expect(decoded, isA<EnduranceResultData>());
      expect((decoded as EnduranceResultData).durationSeconds, 1800);
    });

    test('history shows formatted duration and pace', () {
      final summary = PerformanceResultSummaryFormatter.formatBlock(
        TrainingBlockResult(
          blockResultId: 'b1',
          sessionRecordId: 'r1',
          sourceBlockId: 'run-1',
          blockSnapshot: const BlockPerformanceSnapshot(
            sourceBlockId: 'run-1',
            title: 'Threshold Run',
            blockType: SessionBlockType.conditioning,
            content: 'Steady run',
            workoutFormat: WorkoutFormat.none,
            position: 1,
          ),
          status: TrainingBlockResultStatus.completed,
          resultType: PerformanceResultType.endurance,
          position: 1,
          resultData: const EnduranceResultData(
            distance: 5,
            distanceUnit: 'km',
            durationSeconds: 1800,
            averageHeartRate: 168,
          ),
        ),
      );

      expect(summary, contains('km in 30:00'));
      expect(summary, contains('Avg pace 6:00/km'));
      expect(summary, contains('Avg HR 168 bpm'));
      expect(summary.contains('1800'), isFalse);
    });

    test('capture controller preserves durationSeconds on update', () {
      final controller = PerformanceCaptureController.initializeFromExecutionPlan(
        plan: SessionExecutionPlan(
          sessionId: 'run-session',
          sessionTitle: 'Run',
          blocks: const [
            SessionExecutionBlock(
              blockId: 'run-1',
              title: 'Run',
              blockType: SessionBlockType.conditioning,
              content: 'Steady run',
              workoutFormat: WorkoutFormat.none,
              position: 1,
            ),
          ],
        ),
        athleteId: 'athlete-1',
        trainingSessionId: 42,
      );

      final blockId = controller.draft.blockDrafts.first.sourceBlockId;
      controller.updateBlockResultData(
        blockId,
        const EnduranceResultData(
          distance: 5,
          distanceUnit: 'km',
          durationSeconds: 1800,
        ),
      );

      final draft = controller.draft.blockDraftFor(blockId)!;
      expect((draft.resultData as EnduranceResultData).durationSeconds, 1800);
    });
  });
}
