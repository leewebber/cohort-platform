import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/domain/session_occurrence/session_occurrence_domain.dart';
import 'package:cohort_platform/domain/training_session_record/training_session_record_domain.dart';
import 'package:cohort_platform/domain/workout_player/workout_player_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/adaptation_application_test_support.dart';
import '../../support/adaptation_planning_test_support.dart';

void main() {
  final plannedDate = SessionOccurrenceDate.fromDateTime(DateTime.utc(2026, 7, 28));
  final t0 = DateTime.utc(2026, 7, 28, 8);
  final t1 = DateTime.utc(2026, 7, 28, 8, 5);
  final t2 = DateTime.utc(2026, 7, 28, 9);

  late AdaptedSessionExecutionSnapshot snapshot;
  late List<WorkoutPlayerNavigableStep> steps;

  setUp(() {
    final draft = buildTimedPlanningSession(protocolId: 'proto-record-1');
    final input = timedPlanningInputFromDraft(draft);
    final applied = applyTimedSessionPlan(
      draft: draft,
      constraints: const AdaptationConstraintContext(availableDurationMin: 55),
      input: input,
    );
    snapshot = applied.snapshot!;
    steps = WorkoutPlayerNavigation.navigableSteps(snapshot);
  });

  WorkoutPlayer _completedPlayer() {
    final opened = WorkoutPlayer.openReady(
      playerId: 'player-1',
      occurrenceId: 'occ-record-1',
      executionSnapshot: snapshot,
    );
    return opened.player!
        .activate(recordedAt: t1)
        .player!
        .finishWorkout(recordedAt: t2)
        .player!;
  }

  TrainingExerciseExecutionEntry _entryForStep(
    WorkoutPlayerNavigableStep step, {
    required TrainingExerciseExecutionOutcome outcome,
    String? note,
  }) {
    final block = snapshot.retainedBlocks.firstWhere(
      (b) => b.sourceBlockLocalId == step.sourceBlockLocalId,
    );
    final exercise = block.exercises.firstWhere(
      (e) => e.exerciseLinkLocalId == step.exerciseLinkLocalId,
    );
    return TrainingExerciseExecutionEntry(
      sourceBlockLocalId: step.sourceBlockLocalId,
      exerciseLinkLocalId: step.exerciseLinkLocalId,
      exerciseId: exercise.exerciseId,
      stepIndex: step.stepIndex,
      outcome: outcome,
      note: note,
    );
  }

  group('TrainingSessionRecord creation', () {
    test('beginRecording captures ids and snapshot reference', () {
      final result = TrainingSessionRecord.beginRecording(
        recordId: 'rec-1',
        occurrenceId: 'occ-1',
        executionSnapshot: snapshot,
        startedAt: t1,
        playerId: 'player-1',
      );
      expect(result.isSuccess, isTrue);
      final record = result.record!;
      expect(record.lifecycleStatus,
          TrainingSessionRecordLifecycleStatus.recording);
      expect(record.executionSnapshot, same(snapshot));
      expect(record.exerciseEntries, isEmpty);
    });

    test('beginFromWorkoutPlayer requires terminal player with startedAt', () {
      final player = _completedPlayer();
      final ok = TrainingSessionRecord.beginFromWorkoutPlayer(
        player: player,
        recordId: 'rec-1',
      );
      expect(ok.isSuccess, isTrue);
      expect(ok.record!.playerId, player.playerId);

      final active = WorkoutPlayer.openReady(
        playerId: 'player-1',
        occurrenceId: 'occ-1',
        executionSnapshot: snapshot,
      ).player!.activate(recordedAt: t1).player!;
      expect(
        TrainingSessionRecord.beginFromWorkoutPlayer(
          player: active,
          recordId: 'rec-1',
        ).issues.single.code,
        TrainingSessionRecordTransitionIssueCode.playerNotTerminal,
      );
    });
  });

  group('TrainingSessionRecord lifecycle', () {
    test('recording → completed is terminal', () {
      final recording = TrainingSessionRecord.beginRecording(
        recordId: 'rec-1',
        occurrenceId: 'occ-1',
        executionSnapshot: snapshot,
        startedAt: t1,
      ).record!;

      final completed = recording.completeRecording(
        finishedAt: t2,
        athleteNotes: ' Felt good ',
      );
      expect(completed.isSuccess, isTrue);
      expect(
        completed.record!.lifecycleStatus,
        TrainingSessionRecordLifecycleStatus.completed,
      );
      expect(completed.record!.athleteNotes, 'Felt good');
      expect(completed.record!.isTerminal, isTrue);

      expect(
        completed.record!.recordExerciseOutcome(
          sourceBlockLocalId: steps.first.sourceBlockLocalId,
          exerciseLinkLocalId: steps.first.exerciseLinkLocalId,
          outcome: TrainingExerciseExecutionOutcome.completed,
        ).issues.single.code,
        TrainingSessionRecordTransitionIssueCode.terminalState,
      );
    });

    test('recording → abandoned', () {
      final recording = TrainingSessionRecord.beginRecording(
        recordId: 'rec-1',
        occurrenceId: 'occ-1',
        executionSnapshot: snapshot,
        startedAt: t1,
      ).record!;

      final abandoned = recording.abandonRecording(finishedAt: t2);
      expect(abandoned.isSuccess, isTrue);
      expect(
        abandoned.record!.lifecycleStatus,
        TrainingSessionRecordLifecycleStatus.abandoned,
      );
    });

    test('rejects finishedAt before startedAt', () {
      final recording = TrainingSessionRecord.beginRecording(
        recordId: 'rec-1',
        occurrenceId: 'occ-1',
        executionSnapshot: snapshot,
        startedAt: t2,
      ).record!;

      expect(
        recording.completeRecording(finishedAt: t1).issues.single.code,
        TrainingSessionRecordTransitionIssueCode.invalidTimestamp,
      );
    });
  });

  group('TrainingSessionRecord exercise outcomes', () {
    test('records completed, skipped, and modified exercises', () {
      final step0 = steps[0];
      final step1 = steps.length > 1 ? steps[1] : steps[0];

      var recording = TrainingSessionRecord.beginRecording(
        recordId: 'rec-1',
        occurrenceId: 'occ-1',
        executionSnapshot: snapshot,
        startedAt: t1,
      ).record!;

      recording = recording
          .recordExerciseOutcome(
            sourceBlockLocalId: step0.sourceBlockLocalId,
            exerciseLinkLocalId: step0.exerciseLinkLocalId,
            outcome: TrainingExerciseExecutionOutcome.completed,
          )
          .record!;

      if (steps.length > 1) {
        recording = recording
            .recordExerciseOutcome(
              sourceBlockLocalId: step1.sourceBlockLocalId,
              exerciseLinkLocalId: step1.exerciseLinkLocalId,
              outcome: TrainingExerciseExecutionOutcome.skipped,
              note: 'Shoulder',
            )
            .record!;
      }

      recording = recording
          .recordExerciseOutcome(
            sourceBlockLocalId: step0.sourceBlockLocalId,
            exerciseLinkLocalId: step0.exerciseLinkLocalId,
            outcome: TrainingExerciseExecutionOutcome.modified,
            note: 'Used lighter variation',
          )
          .record!;

      expect(recording.completedExercises, isEmpty);
      expect(recording.modifiedExercises, hasLength(1));
      expect(recording.modifiedExercises.single.note, 'Used lighter variation');
      if (steps.length > 1) {
        expect(recording.skippedExercises, hasLength(1));
      }

      expect(
        recording.recordExerciseOutcome(
          sourceBlockLocalId: 'missing-block',
          exerciseLinkLocalId: 'missing-link',
          outcome: TrainingExerciseExecutionOutcome.completed,
        ).issues.single.code,
        TrainingSessionRecordTransitionIssueCode.unknownExercise,
      );
    });
  });

  group('TrainingSessionRecord finalizeFromWorkoutPlayer', () {
    test('materializes completed player with outcomes', () {
      final player = _completedPlayer();
      final outcomes = [
        for (final step in steps)
          _entryForStep(
            step,
            outcome: TrainingExerciseExecutionOutcome.completed,
          ),
      ];

      final result = TrainingSessionRecord.finalizeFromWorkoutPlayer(
        player: player,
        recordId: 'rec-1',
        exerciseOutcomes: outcomes,
        athleteNotes: 'Done',
      );
      expect(result.isSuccess, isTrue);
      expect(result.record!.lifecycleStatus,
          TrainingSessionRecordLifecycleStatus.completed);
      expect(result.record!.completedExercises.length, steps.length);
      expect(result.record!.executionSnapshot, same(snapshot));
    });
  });

  group('TrainingSessionRecord immutability and equality', () {
    test('transitions return new instances preserving snapshot', () {
      final recording = TrainingSessionRecord.beginRecording(
        recordId: 'rec-1',
        occurrenceId: 'occ-1',
        executionSnapshot: snapshot,
        startedAt: t1,
      ).record!;

      final updated = recording
          .recordExerciseOutcome(
            sourceBlockLocalId: steps.first.sourceBlockLocalId,
            exerciseLinkLocalId: steps.first.exerciseLinkLocalId,
            outcome: TrainingExerciseExecutionOutcome.completed,
          )
          .record!;

      expect(identical(recording, updated), isFalse);
      expect(recording.exerciseEntries, isEmpty);
      expect(updated.executionSnapshot, same(snapshot));

      final a = updated;
      final b = updated
          .completeRecording(finishedAt: t2)
          .record!;
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });
  });
}
