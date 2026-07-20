import 'package:cohort_platform/features/performance/models/block_capture_mode_resolver.dart';
import 'package:cohort_platform/features/performance/models/performance_result_data.dart';
import 'package:cohort_platform/features/performance/models/performance_result_type.dart';
import 'package:cohort_platform/features/performance/models/training_block_result_status.dart';
import 'package:cohort_platform/features/performance/models/training_session_record.dart';
import 'package:cohort_platform/features/performance/models/training_session_record_status.dart';
import 'package:cohort_platform/features/performance/services/endurance_metrics_calculator.dart';
import 'package:cohort_platform/features/performance/services/performance_result_summary_formatter.dart';
import 'package:cohort_platform/features/performance/widgets/performance_capture_widgets.dart';
import 'package:cohort_platform/features/performance/widgets/performance_numeric_field.dart';
import 'package:cohort_platform/features/session/controllers/session_execution_controller.dart';
import 'package:cohort_platform/features/session/models/active_session_state.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/models/session_execution_status.dart';
import 'package:cohort_platform/features/session/screens/active_session_screen.dart';
import 'package:cohort_platform/features/session/screens/session_complete_screen.dart';
import 'package:cohort_platform/features/session/widgets/athlete/athlete_block_card.dart';
import 'package:cohort_platform/features/performance/models/performance_snapshot.dart';
import 'package:cohort_platform/models/block_performance_capture_mode.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/m8_modern_capture_test_fixtures.dart';

void main() {
  group('SessionCompleteScreen navigation', () {
    testWidgets('Done pops to root Home route', (tester) async {
      const homeKey = ValueKey('athlete-home');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            key: homeKey,
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SessionCompleteScreen(
                        state: _completedSessionState(),
                      ),
                    ),
                  );
                },
                child: const Text('Open complete'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open complete'));
      await tester.pumpAndSettle();
      expect(find.text('Done'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.byKey(homeKey), findsOneWidget);
      expect(find.text('Open complete'), findsOneWidget);
    });
  });

  group('EnduranceResultData', () {
    test('serialises and restores', () {
      const original = EnduranceResultData(
        distance: 6.4,
        distanceUnit: 'km',
        durationSeconds: 1800,
        averageHeartRate: 168,
        note: 'Steady',
      );
      final decoded = PerformanceResultData.fromJson(original.toJson());
      expect(decoded, isA<EnduranceResultData>());
      final endurance = decoded as EnduranceResultData;
      expect(endurance.distance, 6.4);
      expect(endurance.durationSeconds, 1800);
      expect(endurance.averageHeartRate, 168);
    });

    test('pace calculation handles null and zero safely', () {
      expect(
        EnduranceMetricsCalculator.formatPaceOrSpeed(
          distance: null,
          distanceUnit: 'km',
          durationSeconds: 1800,
        ),
        isNull,
      );
      expect(
        EnduranceMetricsCalculator.formatPaceOrSpeed(
          distance: 0,
          distanceUnit: 'km',
          durationSeconds: 1800,
        ),
        isNull,
      );
      expect(
        EnduranceMetricsCalculator.formatPaceOrSpeed(
          distance: 6.4,
          distanceUnit: 'km',
          durationSeconds: 1800,
        ),
        'Avg pace 4:41/km',
      );
    });
  });

  group('BlockCaptureModeResolver explicit metadata', () {
    test('modern explicit endurance overrides linked exercise', () {
      final mode = BlockCaptureModeResolver.resolveForBlock(
        SessionExecutionBlock(
          blockId: 'run-1',
          title: 'Threshold Run',
          blockType: SessionBlockType.conditioning,
          content: '30 min steady',
          workoutFormat: WorkoutFormat.none,
          position: 3,
          performanceCaptureMode: BlockPerformanceCaptureMode.endurance,
          linkedExercises: const [
            SessionExecutionExerciseSummary(
              exerciseId: 'RUN-001',
              displayName: 'Run',
            ),
          ],
        ),
      );

      expect(mode, BlockCaptureMode.endurance);
      expect(
        BlockCaptureModeResolver.resultTypeFor(mode),
        PerformanceResultType.endurance,
      );
    });

    test('legacy structured endurance metadata resolves to endurance', () {
      final mode = BlockCaptureModeResolver.resolveForBlock(
        const SessionExecutionBlock(
          blockId: 'legacy-run',
          title: 'Threshold Run',
          blockType: SessionBlockType.custom,
          content: 'Threshold Run\nDuration: 30 min\nDistance: 6 km',
          workoutFormat: WorkoutFormat.none,
          position: 1,
        ),
      );

      expect(mode, BlockCaptureMode.endurance);
    });
  });

  group('PerformanceResultSummaryFormatter', () {
    test('completion summary avoids strength wording', () {
      final summary = PerformanceResultSummaryFormatter.formatBlock(
        TrainingBlockResult(
          blockResultId: 'b1',
          sessionRecordId: 'r1',
          sourceBlockId: 'block-1',
          blockSnapshot: const BlockPerformanceSnapshot(
            sourceBlockId: 'block-1',
            title: 'Warm-up',
            blockType: SessionBlockType.warmUp,
            content: 'Row easy',
            workoutFormat: WorkoutFormat.none,
            position: 1,
          ),
          status: TrainingBlockResultStatus.completed,
          resultType: PerformanceResultType.completion,
          position: 1,
          resultData: const CompletionResultData(completed: true),
          exerciseResults: const [
            TrainingExerciseResult(
              exerciseResultId: 'e1',
              blockResultId: 'b1',
              sourceExerciseId: 'ROW-001',
              exerciseSnapshot: ExercisePerformanceSnapshot(
                sourceExerciseId: 'ROW-001',
                displayName: 'Row',
                position: 1,
              ),
              position: 1,
              setResults: [],
            ),
          ],
        ),
      );

      expect(summary, 'Completed as prescribed');
      expect(summary.contains('sets logged'), isFalse);
    });

    test('endurance summary includes distance and pace', () {
      final summary = PerformanceResultSummaryFormatter.formatBlock(
        TrainingBlockResult(
          blockResultId: 'b2',
          sessionRecordId: 'r1',
          sourceBlockId: 'block-2',
          blockSnapshot: const BlockPerformanceSnapshot(
            sourceBlockId: 'block-2',
            title: 'Threshold Run',
            blockType: SessionBlockType.conditioning,
            content: 'Steady run',
            workoutFormat: WorkoutFormat.none,
            position: 2,
          ),
          status: TrainingBlockResultStatus.completed,
          resultType: PerformanceResultType.endurance,
          position: 2,
          resultData: const EnduranceResultData(
            distance: 6.4,
            distanceUnit: 'km',
            durationSeconds: 1800,
            averageHeartRate: 168,
          ),
        ),
      );

      expect(summary, contains('6.4 km'));
      expect(summary, contains('in 30:00'));
      expect(summary, contains('Avg pace'));
      expect(summary, contains('168 bpm'));
      expect(summary.contains('1800'), isFalse);
    });

    test('amrap summary uses rounds plus reps', () {
      final summary = PerformanceResultSummaryFormatter.formatBlock(
        TrainingBlockResult(
          blockResultId: 'b3',
          sessionRecordId: 'r1',
          sourceBlockId: 'block-3',
          blockSnapshot: const BlockPerformanceSnapshot(
            sourceBlockId: 'block-3',
            title: 'AMRAP',
            blockType: SessionBlockType.conditioning,
            content: '12 min AMRAP',
            workoutFormat: WorkoutFormat.amrap,
            position: 3,
          ),
          status: TrainingBlockResultStatus.completed,
          resultType: PerformanceResultType.amrap,
          position: 3,
          resultData: const AmrapResultData(rounds: 7, extraReps: 14),
        ),
      );

      expect(summary, '7 rounds + 14 reps');
    });
  });

  group('ActiveSessionScreen execution UX', () {
    Future<SessionExecutionController> mountActiveSession(
      WidgetTester tester,
      SessionExecutionPlan plan, {
      String? sessionKeySuffix,
    }) async {
      final controller = SessionExecutionController(
        plan: plan,
        sessionKey:
            'm8-fixture:${plan.sessionId}:${sessionKeySuffix ?? plan.blocks.length}',
        memoryStore: AthleteSessionMemoryStore.instance,
      )..startSession();

      await tester.pumpWidget(
        MaterialApp(
          home: ActiveSessionScreen(
            controller: controller,
            performanceController:
                M8ModernCaptureTestFixtures.performanceController(plan),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return controller;
    }

    testWidgets('hides duplicate navigation for one block', (tester) async {
      await mountActiveSession(
        tester,
        M8ModernCaptureTestFixtures.singleBlockPlan(),
        sessionKeySuffix: 'single',
      );

      expect(find.text('< Previous'), findsNothing);
      expect(find.text('Next >'), findsNothing);
      expect(find.text('ALL BLOCKS'), findsNothing);
      expect(find.text('CURRENT BLOCK'), findsNothing);
      expect(find.text('Finish Session'), findsOneWidget);
    });

    testWidgets('multi-block session shows each block once with inline navigation',
        (tester) async {
      await mountActiveSession(
        tester,
        M8ModernCaptureTestFixtures.fullCapturePlan(),
        sessionKeySuffix: 'full',
      );

      expect(find.text('ALL BLOCKS'), findsNothing);
      expect(find.text('CURRENT BLOCK'), findsNothing);
      expect(find.byType(AthleteBlockCard), findsNWidgets(5));
      expect(find.text('< Previous'), findsOneWidget);
      expect(find.text('Next >'), findsOneWidget);
      expect(find.text('Finish Session'), findsOneWidget);
    });

    testWidgets('navigation moves between blocks without duplicating content',
        (tester) async {
      await mountActiveSession(
        tester,
        M8ModernCaptureTestFixtures.fullCapturePlan(),
        sessionKeySuffix: 'nav',
      );

      expect(find.text('Easy row and mobility'), findsOneWidget);

      await tester.tap(find.text('Next >'));
      await tester.pumpAndSettle();

      expect(find.text('Easy row and mobility'), findsNothing);
      expect(find.text('Back squat and bench press'), findsOneWidget);
    });

    testWidgets('completed blocks collapse and future blocks stay collapsed',
        (tester) async {
      await mountActiveSession(
        tester,
        M8ModernCaptureTestFixtures.fullCapturePlan(),
        sessionKeySuffix: 'collapse',
      );

      expect(find.text('Easy row and mobility'), findsOneWidget);
      expect(find.text('Back squat and bench press'), findsNothing);

      await tester.tap(find.text('Mark block complete'));
      await tester.pumpAndSettle();

      expect(find.text('Easy row and mobility'), findsNothing);
      expect(find.text('Back squat and bench press'), findsOneWidget);
    });

    testWidgets('shows exercise display names instead of IDs', (tester) async {
      await mountActiveSession(
        tester,
        M8ModernCaptureTestFixtures.fullCapturePlan(),
        sessionKeySuffix: 'names',
      );

      await tester.tap(find.text('Next >'));
      await tester.pumpAndSettle();

      expect(find.text('Back Squat'), findsWidgets);
      expect(find.text('Bench Press'), findsWidgets);
      expect(find.text('SQ-001'), findsNothing);
      expect(find.text('BP-001'), findsNothing);
      expect(find.textContaining('linked exercise'), findsNothing);
    });
  });

  group('Completion capture controls', () {
    testWidgets('completion editor does not show duplicate Completed toggle',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlockResultEditor(
              blockDraft: M8ModernCaptureTestFixtures.completionBlockDraft(),
              onResultChanged: (_) {},
              onAddSet: (_) {},
              onUpdateSet: (_, __, ___) {},
              onDuplicateSet: (_, __) {},
              onRemoveSet: (_, __) {},
            ),
          ),
        ),
      );

      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.text('Performance'), findsNothing);
      expect(
        find.text('Use Mark block complete below when you finish this block.'),
        findsNothing,
      );
    });
  });

  group('Athlete-facing wording polish', () {
    testWidgets('review save indicator uses Ready to save', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PerformanceSaveIndicator(state: PerformanceSaveState.idle),
          ),
        ),
      );

      expect(find.text('Ready to save'), findsOneWidget);
      expect(find.text('Draft ready'), findsNothing);
    });

    testWidgets('session RPE helper explains scale', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionRpeSelector(
              value: null,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(
        find.text(
          'How hard did the session feel? 1 = very easy, 10 = maximal.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('session complete omits status suffix from saved message',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SessionCompleteScreen(
            state: _completedSessionState(),
            savedRecord: TrainingSessionRecord(
              recordId: 'record-1',
              athleteId: 'athlete-1',
              status: TrainingSessionRecordStatus.completed,
              startedAt: DateTime.utc(2026, 7, 19, 9),
              completedAt: DateTime.utc(2026, 7, 19, 10),
              sessionSnapshot: const SessionPerformanceSnapshot(
                sourceProtocolId: 'test',
                sessionTitle: 'Test',
                blocks: [],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Saved to training history.'), findsOneWidget);
      expect(find.textContaining('(Completed)'), findsNothing);
    });
  });

  group('PerformanceNumericField regression', () {
    testWidgets('24 and 42 preserve digit order', (tester) async {
      for (final entry in ['24', '42']) {
        var value = '';
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return PerformanceNumericField(
                    key: ValueKey('field-$entry'),
                    label: 'Load',
                    value: value,
                    onChanged: (next) => setState(() => value = next),
                  );
                },
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), entry);
        await tester.pump();
        expect(value, entry);
      }
    });
  });
}

ActiveSessionState _completedSessionState() {
  final plan = M8ModernCaptureTestFixtures.singleBlockPlan();
  return ActiveSessionState(
    sessionKey: 'test-complete',
    plan: plan,
    blockStates: const [],
    activeBlockIndex: 0,
    completedBlockIds: {plan.blocks.first.blockId},
    expandedBlockIds: const {},
    sessionStatus: SessionExecutionStatus.completed,
    startedAt: DateTime.utc(2026, 7, 19, 9),
    endedAt: DateTime.utc(2026, 7, 19, 10),
  );
}
