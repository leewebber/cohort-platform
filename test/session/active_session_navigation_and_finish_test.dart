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
}

class _Harness extends StatelessWidget {
  _Harness({required this.saveCoordinator})
    : plan = _plan(),
      execution = SessionExecutionController(
        plan: _plan(),
        sessionKey: 'active-session-navigation-test',
      )..startSession();

  final _RecordingSaveCoordinator saveCoordinator;
  final SessionExecutionPlan plan;
  final SessionExecutionController execution;

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
                        performanceController:
                            PerformanceCaptureController.initializeFromExecutionPlan(
                              plan: plan,
                              athleteId: 'athlete',
                              trainingSessionId: 7,
                            ),
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
