import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/mappers/performance_record_mapper.dart';
import 'package:cohort_platform/features/performance/models/training_session_record.dart';
import 'package:cohort_platform/features/performance/repositories/performance_record_store.dart';
import 'package:cohort_platform/features/performance/services/performance_record_save_coordinator.dart';
import 'package:cohort_platform/features/session/controllers/session_execution_controller.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/models/session_execution_status.dart';
import 'package:cohort_platform/features/session/screens/active_session_screen.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/strength_exercise_prescription.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Back saves and returns Home without completing the session', (
    tester,
  ) async {
    final harness = _Harness(saveCoordinator: _RecordingSaveCoordinator());
    await tester.pumpWidget(harness);
    await tester.tap(find.text('Open session'));
    await tester.pumpAndSettle();

    expect(find.text('Back to Home'), findsOneWidget);
    await tester.tap(find.text('Back to Home'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(
      harness.execution.state.sessionStatus,
      SessionExecutionStatus.inProgress,
    );
    expect(harness.saveCoordinator.calls, greaterThanOrEqualTo(2));
  });

  testWidgets('save failure blocks exit and offers Retry or Stay', (
    tester,
  ) async {
    final harness = _Harness(
      saveCoordinator: _RecordingSaveCoordinator(fail: true),
    );
    await tester.pumpWidget(harness);
    await tester.tap(find.text('Open session'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Back to Home'));
    await tester.pumpAndSettle();

    expect(find.text('Could not save session'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Stay'), findsOneWidget);
    expect(find.text('Morning Session'), findsOneWidget);

    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.text('Morning Session'), findsOneWidget);
  });

  testWidgets('Finish is disabled at zero completed blocks', (tester) async {
    final harness = _Harness(saveCoordinator: _RecordingSaveCoordinator());
    await tester.pumpWidget(harness);
    await tester.tap(find.text('Open session'));
    await tester.pumpAndSettle();

    expect(find.text('Complete 1 remaining block'), findsOneWidget);
    await tester.tap(find.text('Finish Session'));
    await tester.pumpAndSettle();

    expect(find.text('Morning Session'), findsOneWidget);
    expect(
      harness.execution.state.sessionStatus,
      SessionExecutionStatus.inProgress,
    );
  });

  testWidgets('valid block completion enables Finish', (tester) async {
    final harness = _Harness(saveCoordinator: _RecordingSaveCoordinator());
    await tester.pumpWidget(harness);
    await tester.tap(find.text('Open session'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark block complete'));
    await tester.pumpAndSettle();

    expect(find.text('Ready to finish'), findsOneWidget);
    final button = tester.widget<InkWell>(
      find.ancestor(
        of: find.text('Finish Session'),
        matching: find.byType(InkWell),
      ),
    );
    expect(button.onTap, isNotNull);
  });

  testWidgets(
    'incomplete warm-up permits main logging but still blocks block and session completion',
    (tester) async {
      final harness = _Harness(
        saveCoordinator: _RecordingSaveCoordinator(),
        plan: _warmUpAndMainPlan(),
      );
      await tester.pumpWidget(harness);
      await tester.tap(find.text('Open session'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Next >'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Next >'));
      await tester.pumpAndSettle();

      expect(harness.execution.state.activeBlock?.blockId, 'main-work');
      expect(harness.execution.state.completedBlockIds, isEmpty);
      expect(find.byType(TextField), findsWidgets);
      expect(find.byType(Checkbox), findsWidgets);

      await tester.ensureVisible(find.byType(TextField).first);
      await tester.enterText(find.byType(TextField).first, '8');
      await tester.ensureVisible(find.byType(Checkbox).first);
      await tester.tap(find.byType(Checkbox).first);
      await tester.scrollUntilVisible(
        find.text('Mark block complete'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Mark block complete'));
      await tester.pumpAndSettle();

      expect(harness.execution.state.completedBlockIds, {'main-work'});
      expect(harness.execution.state.activeBlock?.blockId, 'warm-up');
      expect(find.text('Complete 1 remaining block'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Mark block complete'),
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Mark block complete'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Acknowledge every required warm-up movement before completing this block.',
        ),
        findsOneWidget,
      );
      expect(harness.execution.state.completedBlockIds, {'main-work'});

      final warmUp = harness.performanceController.draft.blockDraftFor(
        'warm-up',
      )!;
      for (final exercise in warmUp.exerciseResults) {
        for (final set in exercise.sets) {
          harness.performanceController.updateSet(
            'warm-up',
            exercise.sourceExerciseId,
            set.setResultId,
            (current) => current.copyWith(completed: true),
          );
        }
      }
      await tester.tap(find.text('Mark block complete'));
      await tester.pumpAndSettle();

      expect(harness.execution.state.completedBlockIds, {
        'warm-up',
        'main-work',
      });
      expect(find.text('Ready to finish'), findsOneWidget);
    },
  );
}

class _Harness extends StatelessWidget {
  _Harness({required this.saveCoordinator, SessionExecutionPlan? plan})
    : plan = plan ?? _plan(),
      execution = SessionExecutionController(
        plan: plan ?? _plan(),
        sessionKey:
            'active-session-navigation-test:${plan?.sessionId ?? 'default'}',
      )..startSession();

  final _RecordingSaveCoordinator saveCoordinator;
  final SessionExecutionPlan plan;
  final SessionExecutionController execution;

  late final PerformanceCaptureController performanceController =
      PerformanceCaptureController.initializeFromExecutionPlan(
        plan: plan,
        athleteId: 'athlete',
        trainingSessionId: 7,
      );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Column(
            children: [
              const Text('Home'),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ActiveSessionScreen(
                        controller: execution,
                        performanceController: performanceController,
                        trainingSessionId: 7,
                        athleteId: 'athlete',
                        saveCoordinator: saveCoordinator,
                      ),
                    ),
                  );
                },
                child: const Text('Open session'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordingSaveCoordinator extends PerformanceRecordSaveCoordinator {
  _RecordingSaveCoordinator({this.fail = false});

  final bool fail;
  int calls = 0;

  @override
  Future<TrainingSessionRecord> saveDraft({
    required PerformanceCaptureController controller,
  }) async {
    calls++;
    if (fail) {
      throw const PerformanceRecordStoreException('simulated save failure');
    }
    return const PerformanceRecordMapper().fromDraft(controller.draft);
  }
}

SessionExecutionPlan _plan() {
  return const SessionExecutionPlan(
    sessionId: 'session-1',
    sessionTitle: 'Morning Session',
    blocks: [
      SessionExecutionBlock(
        blockId: 'block-1',
        title: 'Warm-up',
        blockType: SessionBlockType.warmUp,
        content: 'Structured warm-up',
        workoutFormat: WorkoutFormat.none,
        position: 1,
      ),
    ],
  );
}

SessionExecutionPlan _warmUpAndMainPlan() {
  return const SessionExecutionPlan(
    sessionId: 'session-sequencing',
    sessionTitle: 'Sequenced Session',
    blocks: [
      SessionExecutionBlock(
        blockId: 'warm-up',
        title: 'Warm-up',
        blockType: SessionBlockType.warmUp,
        content: 'Required preparation',
        workoutFormat: WorkoutFormat.none,
        position: 1,
        linkedExercises: [
          SessionExecutionExerciseSummary(
            exerciseId: 'warm-up-movement',
            displayName: 'Required warm-up movement',
            prescription: StrengthExercisePrescription(
              sets: 1,
              reps: StrengthRepPrescription(
                type: StrengthRepType.exact,
                exactReps: 5,
              ),
            ),
          ),
        ],
      ),
      SessionExecutionBlock(
        blockId: 'main-work',
        title: 'Main work',
        blockType: SessionBlockType.strength,
        content: 'Main workout',
        workoutFormat: WorkoutFormat.none,
        position: 2,
        linkedExercises: [
          SessionExecutionExerciseSummary(
            exerciseId: 'main-movement',
            displayName: 'Main movement',
            prescription: StrengthExercisePrescription(
              sets: 1,
              reps: StrengthRepPrescription(
                type: StrengthRepType.exact,
                exactReps: 8,
              ),
            ),
          ),
        ],
      ),
    ],
  );
}
