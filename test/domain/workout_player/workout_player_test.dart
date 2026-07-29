import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/domain/session_occurrence/session_occurrence_domain.dart';
import 'package:cohort_platform/domain/workout_player/workout_player_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/adaptation_application_test_support.dart';
import '../../support/adaptation_planning_test_support.dart';

void main() {
  final plannedDate = SessionOccurrenceDate.fromDateTime(
    DateTime.utc(2026, 7, 28),
  );
  final t0 = DateTime.utc(2026, 7, 28, 8);
  final t1 = DateTime.utc(2026, 7, 28, 8, 5);
  final t2 = DateTime.utc(2026, 7, 28, 8, 30);
  final t3 = DateTime.utc(2026, 7, 28, 9);

  late AdaptedSessionExecutionSnapshot snapshot;

  setUp(() {
    final draft = buildTimedPlanningSession(protocolId: 'proto-player-1');
    final input = timedPlanningInputFromDraft(draft);
    final applied = applyTimedSessionPlan(
      draft: draft,
      constraints: const AdaptationConstraintContext(availableDurationMin: 55),
      input: input,
    );
    snapshot = applied.snapshot!;
  });

  SessionOccurrence _inProgressOccurrence() {
    final scheduled = SessionOccurrence.schedule(
      occurrenceId: 'occ-player-1',
      sourceSessionId: 'proto-player-1',
      plannedDate: plannedDate,
      recordedAt: t0,
    );
    final adapted = scheduled.attachAdaptation(
      executionSnapshot: snapshot,
      recordedAt: t0,
    );
    final started = adapted.occurrence!.startInProgress(recordedAt: t1);
    return started.occurrence!;
  }

  WorkoutPlayer _readyPlayer() {
    final opened = WorkoutPlayer.openReady(
      playerId: 'player-1',
      occurrenceId: 'occ-player-1',
      executionSnapshot: snapshot,
    );
    expect(opened.isSuccess, isTrue);
    return opened.player!;
  }

  WorkoutPlayer _activePlayer() {
    final ready = _readyPlayer();
    final active = ready.activate(recordedAt: t1);
    expect(active.isSuccess, isTrue);
    return active.player!;
  }

  group('WorkoutPlayer creation', () {
    test('openReady positions at first exercise in workout order', () {
      final steps = WorkoutPlayerNavigation.navigableSteps(snapshot);
      expect(steps, isNotEmpty);

      final result = WorkoutPlayer.openReady(
        playerId: 'player-1',
        occurrenceId: 'occ-1',
        executionSnapshot: snapshot,
      );
      expect(result.isSuccess, isTrue);
      final player = result.player!;
      expect(player.executionStatus, WorkoutPlayerExecutionStatus.ready);
      expect(player.currentPosition, steps.first.toPosition());
      expect(player.executionSnapshot, same(snapshot));
      expect(player.startedAt, isNull);
    });

    test('openForOccurrence requires inProgress and snapshot', () {
      final inProgress = _inProgressOccurrence();
      final ok = WorkoutPlayer.openForOccurrence(
        occurrence: inProgress,
        playerId: 'player-1',
      );
      expect(ok.isSuccess, isTrue);
      expect(ok.player!.occurrenceId, inProgress.occurrenceId);

      final scheduled = SessionOccurrence.schedule(
        occurrenceId: 'occ-sched',
        sourceSessionId: 'proto-player-1',
        plannedDate: plannedDate,
        recordedAt: t0,
      );
      final notStarted = WorkoutPlayer.openForOccurrence(
        occurrence: scheduled,
        playerId: 'player-1',
      );
      expect(notStarted.isSuccess, isFalse);
      expect(
        notStarted.issues.single.code,
        WorkoutPlayerTransitionIssueCode.occurrenceNotInProgress,
      );

      final noSnapshot = scheduled.startInProgress(recordedAt: t1).occurrence!;
      final missingSnapshot = WorkoutPlayer.openForOccurrence(
        occurrence: noSnapshot,
        playerId: 'player-1',
      );
      expect(missingSnapshot.isSuccess, isFalse);
      expect(
        missingSnapshot.issues.single.code,
        WorkoutPlayerTransitionIssueCode.snapshotRequired,
      );
    });

    test('rejects invalid ids and empty workout', () {
      expect(
        WorkoutPlayer.openReady(
          playerId: ' ',
          occurrenceId: 'occ-1',
          executionSnapshot: snapshot,
        ).issues.single.code,
        WorkoutPlayerTransitionIssueCode.invalidPlayerId,
      );

      const emptySnapshot = AdaptedSessionExecutionSnapshot(
        snapshotId: 'snap-empty',
        sourceProtocolId: 'proto-empty',
        status: AdaptedSessionExecutionSnapshotStatus.ready,
        originalPlannedDurationMin: 45,
        resultingEstimatedDurationMin: 45,
        durationEstimateReliable: true,
        primarySessionIntent: null,
        secondarySessionIntents: [],
        retainedBlocks: [],
        omittedBlocks: [],
        appliedAdaptationAudit: [],
        expectedFidelity: AdaptationFidelity.full,
        adaptationConfidence: AdaptationConfidence.high,
        evaluationOutcome: AdaptationEvaluationOutcome.noAdaptationRequired,
        planStatus: AdaptationPlanStatus.noPlanRequired,
        unresolvedConstraints: [],
        exactDurationFeasibilityConfirmed: true,
        unresolvedDurationDeficitMinutes: null,
        planFindings: [],
      );

      expect(
        WorkoutPlayer.openReady(
          playerId: 'player-1',
          occurrenceId: 'occ-1',
          executionSnapshot: emptySnapshot,
        ).issues.single.code,
        WorkoutPlayerTransitionIssueCode.emptyWorkout,
      );
    });
  });

  group('WorkoutPlayer lifecycle', () {
    test('ready → active → paused → active → completed', () {
      final ready = _readyPlayer();
      final original = ready;

      final active = ready.activate(recordedAt: t1);
      expect(active.isSuccess, isTrue);
      expect(
        active.player!.executionStatus,
        WorkoutPlayerExecutionStatus.active,
      );
      expect(active.player!.startedAt, t1);
      expect(original.executionStatus, WorkoutPlayerExecutionStatus.ready);

      final paused = active.player!.pause(recordedAt: t2);
      expect(paused.isSuccess, isTrue);
      expect(paused.player!.pausedAt, t2);

      final resumed = paused.player!.resume(recordedAt: t2);
      expect(resumed.isSuccess, isTrue);
      expect(resumed.player!.pausedAt, isNull);

      final completed = resumed.player!.finishWorkout(recordedAt: t3);
      expect(completed.isSuccess, isTrue);
      expect(
        completed.player!.executionStatus,
        WorkoutPlayerExecutionStatus.completed,
      );
      expect(completed.player!.finishedAt, t3);
      expect(completed.player!.hasFinished, isTrue);
    });

    test('active can abandon', () {
      final abandoned = _activePlayer().abandon(recordedAt: t3);
      expect(abandoned.isSuccess, isTrue);
      expect(
        abandoned.player!.executionStatus,
        WorkoutPlayerExecutionStatus.abandoned,
      );
    });

    test('rejects invalid lifecycle transitions', () {
      final ready = _readyPlayer();
      expect(
        ready.pause(recordedAt: t1).issues.single.code,
        WorkoutPlayerTransitionIssueCode.invalidExecutionStatus,
      );
      expect(
        ready.nextExercise().issues.single.code,
        WorkoutPlayerTransitionIssueCode.invalidExecutionStatus,
      );

      final completed = _activePlayer().finishWorkout(recordedAt: t3).player!;
      expect(
        completed.activate(recordedAt: t3).issues.single.code,
        WorkoutPlayerTransitionIssueCode.terminalState,
      );
      expect(
        completed.nextExercise().issues.single.code,
        WorkoutPlayerTransitionIssueCode.terminalState,
      );
    });
  });

  group('WorkoutPlayer navigation', () {
    test('next and previous exercise move within snapshot order', () {
      final steps = WorkoutPlayerNavigation.navigableSteps(snapshot);
      var player = _activePlayer();
      expect(player.currentPosition.stepIndex, 0);

      final next = player.nextExercise();
      expect(next.isSuccess, isTrue);
      player = next.player!;
      expect(player.currentPosition.stepIndex, 1);
      expect(
        player.currentPosition.exerciseLinkLocalId,
        steps[1].exerciseLinkLocalId,
      );

      final prev = player.previousExercise();
      expect(prev.isSuccess, isTrue);
      expect(prev.player!.currentPosition.stepIndex, 0);
    });

    test('navigation boundaries are explicit failures', () {
      final player = _activePlayer();
      expect(
        player.previousExercise().issues.single.code,
        WorkoutPlayerTransitionIssueCode.navigationBoundary,
      );

      var atEnd = player;
      while (true) {
        final moved = atEnd.nextExercise();
        if (!moved.isSuccess) {
          expect(
            moved.issues.single.code,
            WorkoutPlayerTransitionIssueCode.navigationBoundary,
          );
          break;
        }
        atEnd = moved.player!;
      }
      expect(atEnd.isAtLastStep, isTrue);
    });

    test('nextBlock jumps to first exercise of the following block', () {
      final steps = WorkoutPlayerNavigation.navigableSteps(snapshot);
      if (steps.length < 2) return;

      final firstBlockId = steps.first.sourceBlockLocalId;
      final hasAnotherBlock = steps.any(
        (s) => s.sourceBlockLocalId != firstBlockId,
      );
      if (!hasAnotherBlock) return;

      final player = _activePlayer();
      final jumped = player.nextBlock();
      expect(jumped.isSuccess, isTrue);
      expect(
        jumped.player!.currentPosition.sourceBlockLocalId,
        isNot(firstBlockId),
      );
    });

    test('remaining steps reflects current position', () {
      final player = _activePlayer();
      final total = player.totalStepCount;
      expect(player.remainingStepCount, total - 1);
    });

    test('paused player cannot navigate', () {
      final paused = _activePlayer().pause(recordedAt: t2).player!;
      expect(
        paused.nextExercise().issues.single.code,
        WorkoutPlayerTransitionIssueCode.invalidExecutionStatus,
      );
    });
  });

  group('WorkoutPlayer immutability and equality', () {
    test('transitions return new instances', () {
      final ready = _readyPlayer();
      final active = ready.activate(recordedAt: t1).player!;
      expect(identical(ready, active), isFalse);
      expect(ready.executionStatus, WorkoutPlayerExecutionStatus.ready);
    });

    test('execution snapshot reference is preserved across transitions', () {
      final ready = _readyPlayer();
      final moved = ready
          .activate(recordedAt: t1)
          .player!
          .nextExercise()
          .player!;
      expect(moved.executionSnapshot, same(snapshot));
    });

    test('equality compares execution fields', () {
      final a = _readyPlayer();
      final b = WorkoutPlayer.openReady(
        playerId: 'player-1',
        occurrenceId: 'occ-player-1',
        executionSnapshot: snapshot,
      ).player!;
      expect(a, equals(b));

      final different = a.activate(recordedAt: t1).player!;
      expect(a == different, isFalse);
    });
  });
}
