import 'package:cohort_platform/core/persistence/models/execution_result_models.dart';
import 'package:cohort_platform/features/session/models/production_restore_outcome.dart';
import 'package:cohort_platform/features/session/services/workout_progress_snapshot_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = WorkoutProgressSnapshotPolicy();

  WorkoutProgressSnapshot snapshot({
    String athleteId = 'athlete-1',
    List<Map<String, dynamic>> enteredResults = const [],
  }) {
    return WorkoutProgressSnapshot(
      sessionId: 'legacy-session',
      athleteId: athleteId,
      currentExerciseIndex: 1,
      currentSet: 2,
      completedExerciseIndexes: const [0],
      startedAt: DateTime.utc(2026, 9, 1),
      lastUpdatedAt: DateTime.utc(2026, 9, 1),
      enteredResults: enteredResults,
    );
  }

  test('snapshot never authorizes resume by itself', () {
    expect(
      policy.bootAction(
        snapshot: snapshot(),
        currentAthleteId: 'athlete-1',
      ),
      WorkoutProgressSnapshotBootAction.clearSafely,
    );
  });

  test('foreign snapshot is cleared without exposure', () {
    expect(
      policy.bootAction(
        snapshot: snapshot(athleteId: 'other'),
        currentAthleteId: 'athlete-1',
      ),
      WorkoutProgressSnapshotBootAction.clearSafely,
    );
  });

  test('unmappable entered results are not fabricated into a workout', () {
    expect(
      policy.bootAction(
        snapshot: snapshot(enteredResults: const [{'reps': 5}]),
        currentAthleteId: 'athlete-1',
      ),
      WorkoutProgressSnapshotBootAction.showCannotRestore,
    );
  });

  test('completed hosted snapshot is cleared', () {
    expect(
      policy.bootAction(
        snapshot: snapshot(enteredResults: const [{'reps': 5}]),
        currentAthleteId: 'athlete-1',
        durableOutcome: ProductionRestoreOutcome.completedHosted,
      ),
      WorkoutProgressSnapshotBootAction.clearSafely,
    );
  });

  test('empty snapshot list is a no-op', () {
    expect(
      policy.bootAction(snapshot: null, currentAthleteId: 'athlete-1'),
      WorkoutProgressSnapshotBootAction.none,
    );
  });
}
