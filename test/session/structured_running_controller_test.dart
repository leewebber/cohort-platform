import 'dart:async';

import 'package:cohort_platform/domain/running_workout/running_workout.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/models/structured_running_execution.dart';
import 'package:cohort_platform/features/session/screens/structured_running_timer_screen.dart';
import 'package:cohort_platform/features/session/services/structured_running_controller.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/timer_configuration.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StructuredRunningController', () {
    test('pause, background, exit and cold restore preserve work cursor', () {
      final execution = _execution();
      final controller = StructuredRunningController.fresh(
        execution: execution,
      );

      controller.start();
      controller.elapse(const Duration(seconds: 2));
      controller.pause();
      final paused = controller.cursor;
      expect(paused.authoredStepId, endsWith(':s:work'));
      expect(paused.repeatOrdinal, 1);
      expect(paused.phase, StructuredRunningPhase.work);
      expect(paused.remainingMilliseconds, 3000);
      expect(paused.isPaused, isTrue);

      final restored = StructuredRunningController.restore(
        execution: execution,
        cursor: StructuredRunningCursor.fromJson(paused.toJson()),
      );
      expect(
        identical(restored.execution.frozenSnapshot, execution.frozenSnapshot),
        isTrue,
      );
      restored.start();
      restored.elapse(const Duration(seconds: 1));
      restored.background();
      expect(restored.cursor.remainingMilliseconds, 2000);
      expect(restored.cursor.isPaused, isTrue);
      restored.start();
      restored.exit();
      expect(restored.cursor.isPaused, isTrue);
    });

    test('cold restores recovery and preserves manual evidence', () {
      final execution = _execution();
      final controller = StructuredRunningController.fresh(
        execution: execution,
      );
      controller.start();
      controller.elapse(const Duration(seconds: 6));
      controller.markManualEvidenceCaptured();
      controller.exit();

      final recovery = controller.cursor;
      expect(recovery.authoredStepId, endsWith(':s:recovery'));
      expect(recovery.repeatOrdinal, 1);
      expect(recovery.phase, StructuredRunningPhase.recovery);
      expect(recovery.remainingMilliseconds, 2000);
      expect(
        recovery.manualEvidenceState,
        StructuredRunningManualEvidenceState.captured,
      );

      final restored = StructuredRunningController.restore(
        execution: execution,
        cursor: StructuredRunningCursor.fromJson(recovery.toJson()),
      );
      expect(restored.cursor.toJson(), recovery.toJson());
      restored.start();
      restored.background();
      expect(restored.cursor.phase, StructuredRunningPhase.recovery);
    });

    test('background checkpoints exact elapsed time during recovery', () {
      var elapsed = Duration.zero;
      final execution = _execution();
      final controller = StructuredRunningController.fresh(
        execution: execution,
        elapsedTime: () => elapsed,
      );

      controller.start();
      elapsed = const Duration(milliseconds: 5750);
      controller.background();

      final cursor = controller.cursor;
      expect(cursor.authoredStepId, endsWith(':s:recovery'));
      expect(cursor.repeatOrdinal, 1);
      expect(cursor.phase, StructuredRunningPhase.recovery);
      expect(cursor.remainingMilliseconds, 2250);
      expect(cursor.isPaused, isTrue);

      final restored = StructuredRunningController.restore(
        execution: execution,
        cursor: StructuredRunningCursor.fromJson(cursor.toJson()),
        elapsedTime: () => elapsed,
      );
      expect(restored.cursor.toJson(), cursor.toJson());
    });

    testWidgets(
      'cold restore of running cursor restarts ticker without lost time',
      (tester) async {
        var elapsed = Duration.zero;
        final execution = _execution();
        final original = StructuredRunningController.fresh(
          execution: execution,
          elapsedTime: () => elapsed,
        );
        original.start();
        final running = original.cursor;
        original.dispose();

        final restored = StructuredRunningController.restore(
          execution: execution,
          cursor: running,
          elapsedTime: () => elapsed,
        );
        expect(restored.cursor.isPaused, isFalse);

        elapsed = const Duration(milliseconds: 1250);
        await tester.pump(const Duration(seconds: 1));
        restored.background();
        expect(restored.cursor.remainingMilliseconds, 3750);
        expect(restored.cursor.isPaused, isTrue);
      },
    );

    test(
      'final recovery restores and timer finish does not complete anything',
      () {
        final checkpoints = <StructuredRunningCursor>[];
        final execution = _execution();
        final controller = StructuredRunningController.fresh(
          execution: execution,
          onCheckpoint: checkpoints.add,
        );
        controller.start();
        controller.elapse(const Duration(seconds: 22));
        controller.pause();
        final finalRecovery = controller.cursor;
        expect(finalRecovery.repeatOrdinal, 3);
        expect(finalRecovery.phase, StructuredRunningPhase.recovery);
        expect(finalRecovery.remainingMilliseconds, 2000);

        final restored = StructuredRunningController.restore(
          execution: execution,
          cursor: finalRecovery,
          onCheckpoint: checkpoints.add,
        );
        restored.start();
        restored.elapse(const Duration(seconds: 2));
        expect(restored.cursor.isFinished, isTrue);
        expect(restored.cursor.isPaused, isTrue);
        expect(restored.cursor.remainingMilliseconds, 0);
        expect(checkpoints.last.isFinished, isTrue);
        // There is intentionally no block/session completion callback.
      },
    );

    test('fails closed when cursor mapping or pinned step disagrees', () {
      final execution = _execution();
      final cursor = StructuredRunningController.fresh(
        execution: execution,
      ).cursor;

      expect(
        () => StructuredRunningController.restore(
          execution: execution,
          cursor: _copy(cursor, executionMappingSha256: 'wrong'),
        ),
        throwsA(
          isA<StructuredRunningExecutionException>().having(
            (error) => error.code,
            'code',
            'cursor_authority_mismatch',
          ),
        ),
      );
      expect(
        () => StructuredRunningController.restore(
          execution: execution,
          cursor: _copy(cursor, authoredStepId: 'invented-step'),
        ),
        throwsA(
          isA<StructuredRunningExecutionException>().having(
            (error) => error.code,
            'code',
            'cursor_step_mismatch',
          ),
        ),
      );
    });
  });

  testWidgets('production timer checkpoints background and exit', (
    tester,
  ) async {
    StructuredRunningCursor? returned;
    final checkpoints = <StructuredRunningCursor>[];
    final execution = _execution();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              returned = await Navigator.of(context).push(
                MaterialPageRoute<StructuredRunningCursor>(
                  builder: (_) => StructuredRunningTimerScreen(
                    execution: execution,
                    onCheckpoint: (cursor) async {
                      checkpoints.add(cursor);
                      return true;
                    },
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pump(const Duration(seconds: 2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(checkpoints.last.isPaused, isTrue);
    expect(
      checkpoints.last.remainingMilliseconds,
      inInclusiveRange(2500, 3000),
    );
    await tester.tap(find.byTooltip('Exit timer'));
    await tester.pumpAndSettle();
    expect(returned?.toJson(), checkpoints.last.toJson());
  });

  testWidgets('timer exit is single-flight and blocks on save failure', (
    tester,
  ) async {
    StructuredRunningCursor? returned;
    var allowExit = false;
    var exitCheckpoints = 0;
    final firstExit = Completer<bool>();
    final execution = _execution();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              returned = await Navigator.of(context).push(
                MaterialPageRoute<StructuredRunningCursor>(
                  builder: (_) => StructuredRunningTimerScreen(
                    execution: execution,
                    onCheckpoint: (cursor) {
                      exitCheckpoints++;
                      if (exitCheckpoints == 1) return firstExit.future;
                      return Future.value(allowExit);
                    },
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Exit timer'));
    await tester.tap(find.byTooltip('Exit timer'), warnIfMissed: false);
    await tester.pump();
    expect(exitCheckpoints, 1);
    expect(find.text('Structured run'), findsOneWidget);
    expect(returned, isNull);

    firstExit.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('Structured run'), findsOneWidget);

    allowExit = true;
    await tester.tap(find.byTooltip('Exit timer'));
    await tester.pumpAndSettle();
    expect(exitCheckpoints, 2);
    expect(returned, isNotNull);
    expect(find.text('Open'), findsOneWidget);
  });
}

const _blockId = '123e4567-e89b-42d3-a456-426614174000';

VerifiedStructuredRunningExecution _execution() {
  const timer = TimerConfiguration(workSeconds: 5, restSeconds: 3, rounds: 3);
  final workout = const RunningWorkoutProjector()
      .project(
        format: WorkoutFormat.intervals,
        configuration: timer,
        sourceRef: _blockId,
      )
      .workout!;
  final ids = workout.steps
      .whereType<RunningRepeatGroup>()
      .single
      .steps
      .map((step) => step.stepId)
      .toList(growable: false);
  final bindings = ids
      .map((id) => (stepId: id, sessionBlockId: _blockId))
      .toList(growable: false);
  final hash = RunningExecutionMappingHash.compute(
    workoutId: workout.workoutId,
    bindings: bindings,
  );
  final authority = AuthoredRunningExecutionAuthority.fromCanonicalJson({
    'schema_version': 1,
    'workout_id': workout.workoutId,
    'step_ids': ids,
    'executable_step_bindings': [
      for (final id in ids) {'step_id': id, 'session_block_id': _blockId},
    ],
    'execution_mapping_sha256': hash,
    'advisory_attachments': [
      {'attachment_id': 'target-1', 'step_ids': ids},
    ],
  });
  final snapshot = RunningTargetSnapshotAggregate.fromJson({
    'schema_version': 1,
    'authority': 'advisory',
    'occurrence_id': 'occurrence-1',
    'athlete_id': 'athlete-1',
    'assignment_id': 'assignment-1',
    'programme_version_id': 'version-1',
    'session_slot_id': 'slot-1',
    'package_content_hash': List.filled(64, 'a').join(),
    'workout_id': workout.workoutId,
    'frozen_at_utc': '2026-09-29T01:00:00.000Z',
    'freeze_source': 'in_app_start',
    'targets': [
      {
        'schema_version': 1,
        'authority': 'advisory',
        'attachment_id': 'target-1',
        'scope': {'workout_id': workout.workoutId, 'step_ids': ids},
        'frozen_at_utc': '2026-09-29T01:00:00.000Z',
        'freeze_source': 'in_app_start',
        'policy': {
          'display_rounding': {
            'increment_milliseconds_per_kilometre': 1000,
            'direction': 'nearest',
          },
        },
        'state': 'intent_only',
        'reason': 'no_evidence',
      },
    ],
  });
  return VerifiedStructuredRunningExecution.fromLaunch(
    plan: const SessionExecutionPlan(
      sessionId: 'session-1',
      sessionTitle: 'Identity is not the title',
      blocks: [
        SessionExecutionBlock(
          blockId: _blockId,
          title: 'Position is not identity',
          blockType: SessionBlockType.conditioning,
          content: '',
          workoutFormat: WorkoutFormat.intervals,
          position: 99,
          timerConfiguration: timer,
        ),
      ],
    ),
    authority: authority,
    frozenSnapshot: snapshot,
  );
}

StructuredRunningCursor _copy(
  StructuredRunningCursor cursor, {
  String? executionMappingSha256,
  String? authoredStepId,
}) {
  return StructuredRunningCursor(
    schemaVersion: cursor.schemaVersion,
    workoutId: cursor.workoutId,
    executionMappingSha256:
        executionMappingSha256 ?? cursor.executionMappingSha256,
    sessionBlockId: cursor.sessionBlockId,
    authoredStepId: authoredStepId ?? cursor.authoredStepId,
    repeatOrdinal: cursor.repeatOrdinal,
    phase: cursor.phase,
    remainingMilliseconds: cursor.remainingMilliseconds,
    isPaused: cursor.isPaused,
    manualEvidenceState: cursor.manualEvidenceState,
    isFinished: cursor.isFinished,
  );
}
