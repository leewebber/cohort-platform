import '../models/performance_result_type.dart';
import '../models/performance_snapshot.dart';
import '../models/session_result_entry_mode.dart';
import '../models/training_block_result_status.dart';
import '../models/training_session_record.dart';
import '../models/training_session_record_status.dart';
import '../../../models/session_block_type.dart';
import '../../../models/workout_format.dart';

class ProgressionDemoSet {
  const ProgressionDemoSet({
    required this.load,
    required this.reps,
    this.rpe,
    this.completed = true,
  });

  final double load;
  final int reps;
  final int? rpe;
  final bool completed;
}

/// Deterministic strength records for preview and contract tests.
abstract final class ProgressionMechanicsFixtures {
  static const athleteId = 'preview-athlete';
  static const exerciseId = 'EX-095';
  static const exerciseName = 'Weighted Pull-Up';

  static TrainingSessionRecord strengthRecord({
    required String recordId,
    required DateTime at,
    required List<ProgressionDemoSet> sets,
    TrainingSessionRecordStatus status = TrainingSessionRecordStatus.completed,
    SessionResultEntryMode entryMode = SessionResultEntryMode.live,
    DateTime? performedOn,
    DateTime? lastCorrectedAt,
  }) {
    final exercise = TrainingExerciseResult(
      exerciseResultId: '$recordId-ex',
      blockResultId: '$recordId-b',
      sourceExerciseId: exerciseId,
      position: 1,
      exerciseSnapshot: const ExercisePerformanceSnapshot(
        sourceExerciseId: exerciseId,
        displayName: exerciseName,
        position: 1,
        loadKind: StrengthActualLoadKind.external,
      ),
      setResults: [
        for (var i = 0; i < sets.length; i++)
          TrainingSetResult(
            setResultId: '$recordId-s$i',
            exerciseResultId: '$recordId-ex',
            setNumber: i + 1,
            position: i + 1,
            load: sets[i].load,
            loadUnit: 'kg',
            reps: sets[i].reps,
            rpe: sets[i].rpe,
            completed: sets[i].completed,
          ),
      ],
    );
    final snapshot = BlockPerformanceSnapshot(
      sourceBlockId: 'strength',
      title: 'Upper Strength',
      blockType: SessionBlockType.strength,
      content: '',
      workoutFormat: WorkoutFormat.none,
      position: 1,
      exercises: [exercise.exerciseSnapshot],
    );
    return TrainingSessionRecord(
      recordId: recordId,
      athleteId: athleteId,
      status: status,
      sessionSnapshot: SessionPerformanceSnapshot(
        sourceProtocolId: 'APOLLO-W1-MON-R1',
        sessionTitle: 'Apollo Strength',
        blocks: [snapshot],
      ),
      startedAt: at,
      completedAt: at,
      durationSeconds: 3600,
      overallRpe: 8,
      lastCorrectedAt: lastCorrectedAt,
      entryMode: entryMode,
      performedOn: performedOn,
      blockResults: [
        TrainingBlockResult(
          blockResultId: '$recordId-b',
          sessionRecordId: recordId,
          sourceBlockId: 'strength',
          blockSnapshot: snapshot,
          status: TrainingBlockResultStatus.completed,
          resultType: PerformanceResultType.strength,
          position: 1,
          exerciseResults: [exercise],
        ),
      ],
    );
  }

  static TrainingSessionRecord previous20x5() {
    return strengthRecord(
      recordId: 'prev',
      at: DateTime.utc(2026, 9, 7, 18),
      sets: const [ProgressionDemoSet(load: 20, reps: 5, rpe: 8)],
    );
  }

  static TrainingSessionRecord improved20x6() {
    return strengthRecord(
      recordId: 'curr-improved',
      at: DateTime.utc(2026, 9, 14, 18),
      sets: const [ProgressionDemoSet(load: 20, reps: 6, rpe: 8)],
    );
  }

  static TrainingSessionRecord matched20x5() {
    return strengthRecord(
      recordId: 'curr-matched',
      at: DateTime.utc(2026, 9, 14, 18),
      sets: const [ProgressionDemoSet(load: 20, reps: 5, rpe: 8)],
    );
  }

  static TrainingSessionRecord mixed90x3() {
    return strengthRecord(
      recordId: 'curr-mixed',
      at: DateTime.utc(2026, 9, 14, 18),
      sets: const [ProgressionDemoSet(load: 90, reps: 3, rpe: 8)],
    );
  }

  static TrainingSessionRecord previous80x5() {
    return strengthRecord(
      recordId: 'prev-80',
      at: DateTime.utc(2026, 9, 7, 18),
      sets: const [ProgressionDemoSet(load: 80, reps: 5, rpe: 8)],
    );
  }

  static TrainingSessionRecord below18x5() {
    return strengthRecord(
      recordId: 'curr-below',
      at: DateTime.utc(2026, 9, 14, 18),
      sets: const [ProgressionDemoSet(load: 18, reps: 5, rpe: 8)],
    );
  }

  static TrainingSessionRecord first20x5() {
    return strengthRecord(
      recordId: 'curr-first',
      at: DateTime.utc(2026, 9, 14, 18),
      sets: const [ProgressionDemoSet(load: 20, reps: 5, rpe: 8)],
    );
  }

  static TrainingSessionRecord previous3x10x15() {
    return strengthRecord(
      recordId: 'prev-3sets',
      at: DateTime.utc(2026, 9, 7, 18),
      sets: const [
        ProgressionDemoSet(load: 10, reps: 15),
        ProgressionDemoSet(load: 10, reps: 15),
        ProgressionDemoSet(load: 10, reps: 15),
      ],
    );
  }

  static TrainingSessionRecord changedPrescription4x10x12() {
    return strengthRecord(
      recordId: 'curr-4sets',
      at: DateTime.utc(2026, 9, 14, 18),
      sets: const [
        ProgressionDemoSet(load: 10, reps: 12),
        ProgressionDemoSet(load: 10, reps: 12),
        ProgressionDemoSet(load: 10, reps: 12),
        ProgressionDemoSet(load: 10, reps: 12),
      ],
    );
  }

  static TrainingSessionRecord precisePb25x5() {
    return strengthRecord(
      recordId: 'curr-pb',
      at: DateTime.utc(2026, 9, 14, 18),
      sets: const [ProgressionDemoSet(load: 25, reps: 5, rpe: 8)],
    );
  }

  static TrainingSessionRecord corrected18x5() {
    return strengthRecord(
      recordId: 'curr-corrected',
      at: DateTime.utc(2026, 9, 14, 18),
      lastCorrectedAt: DateTime.utc(2026, 9, 14, 21),
      sets: const [ProgressionDemoSet(load: 18, reps: 5, rpe: 8)],
    );
  }

  static TrainingSessionRecord olderBackfill20x5() {
    return strengthRecord(
      recordId: 'backfill',
      at: DateTime.utc(2026, 9, 13, 12),
      performedOn: DateTime.utc(2026, 8, 1),
      entryMode: SessionResultEntryMode.backfill,
      sets: const [ProgressionDemoSet(load: 20, reps: 5, rpe: 8)],
    );
  }

  static TrainingSessionRecord partial20x6() {
    return strengthRecord(
      recordId: 'curr-partial',
      at: DateTime.utc(2026, 9, 14, 18),
      status: TrainingSessionRecordStatus.partiallyCompleted,
      sets: const [
        ProgressionDemoSet(load: 20, reps: 6, rpe: 8),
        ProgressionDemoSet(load: 20, reps: 5, rpe: 8, completed: false),
      ],
    );
  }

  static TrainingSessionRecord notComparableBodyweight() {
    final at = DateTime.utc(2026, 9, 14, 18);
    final exercise = TrainingExerciseResult(
      exerciseResultId: 'bw-ex',
      blockResultId: 'bw-b',
      sourceExerciseId: exerciseId,
      position: 1,
      exerciseSnapshot: const ExercisePerformanceSnapshot(
        sourceExerciseId: exerciseId,
        displayName: exerciseName,
        position: 1,
        loadKind: StrengthActualLoadKind.bodyweight,
      ),
      setResults: [
        TrainingSetResult(
          setResultId: 'bw-s',
          exerciseResultId: 'bw-ex',
          setNumber: 1,
          position: 1,
          reps: 8,
          completed: true,
        ),
      ],
    );
    final snapshot = BlockPerformanceSnapshot(
      sourceBlockId: 'strength',
      title: 'Upper Strength',
      blockType: SessionBlockType.strength,
      content: '',
      workoutFormat: WorkoutFormat.none,
      position: 1,
      exercises: [exercise.exerciseSnapshot],
    );
    return TrainingSessionRecord(
      recordId: 'curr-bw',
      athleteId: athleteId,
      status: TrainingSessionRecordStatus.completed,
      sessionSnapshot: SessionPerformanceSnapshot(
        sourceProtocolId: 'APOLLO-W1-MON-R1',
        sessionTitle: 'Apollo Strength',
        blocks: [snapshot],
      ),
      startedAt: at,
      completedAt: at,
      blockResults: [
        TrainingBlockResult(
          blockResultId: 'bw-b',
          sessionRecordId: 'curr-bw',
          sourceBlockId: 'strength',
          blockSnapshot: snapshot,
          status: TrainingBlockResultStatus.completed,
          resultType: PerformanceResultType.strength,
          position: 1,
          exerciseResults: [exercise],
        ),
      ],
    );
  }
}
