import 'package:cohort_platform/features/performance/models/active_performance_draft.dart';
import 'package:cohort_platform/features/performance/models/performance_snapshot.dart';
import 'package:cohort_platform/features/performance/services/strength_exercise_capture_completion.dart';
import 'package:cohort_platform/models/strength_exercise_prescription.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const prescription = StrengthExercisePrescription(
    sets: 4,
    reps: StrengthRepPrescription(
      type: StrengthRepType.range,
      minReps: 6,
      maxReps: 8,
    ),
  );

  ExercisePerformanceDraft exercise(List<SetPerformanceDraft> sets) {
    return ExercisePerformanceDraft(
      exerciseResultId: 'result',
      sourceExerciseId: 'EX-095',
      exerciseSnapshot: const ExercisePerformanceSnapshot(
        sourceExerciseId: 'EX-095',
        displayName: 'Weighted Pull-Up',
        position: 1,
      ),
      position: 1,
      sets: sets,
    );
  }

  SetPerformanceDraft set({
    required int number,
    bool completed = false,
    int? reps,
  }) {
    return SetPerformanceDraft(
      setResultId: 'set-$number',
      setNumber: number,
      position: number,
      completed: completed,
      reps: reps,
    );
  }

  test('partial drafts stay incomplete until required sets are completed', () {
    final partial = exercise([
      set(number: 1, reps: 7),
      set(number: 2, reps: 6),
      set(number: 3),
      set(number: 4),
    ]);

    expect(
      StrengthExerciseCaptureCompletion.isComplete(
        exercise: partial,
        prescription: prescription,
      ),
      isFalse,
    );
    expect(
      StrengthExerciseCaptureCompletion.collapsedStatusLine(
        exercise: partial,
        prescription: prescription,
      ),
      isNull,
    );
  });

  test('all required completed sets yield a compact completed line', () {
    final complete = exercise([
      set(number: 1, completed: true, reps: 7),
      set(number: 2, completed: true, reps: 6),
      set(number: 3, completed: true, reps: 6),
      set(number: 4, completed: true, reps: 5),
    ]);

    expect(
      StrengthExerciseCaptureCompletion.isComplete(
        exercise: complete,
        prescription: prescription,
      ),
      isTrue,
    );
    expect(
      StrengthExerciseCaptureCompletion.collapsedStatusLine(
        exercise: complete,
        prescription: prescription,
      ),
      'Completed · 4 sets',
    );
  });

  test('clearing a completed set returns the exercise to incomplete', () {
    final corrected = exercise([
      set(number: 1, completed: true, reps: 7),
      set(number: 2, completed: true, reps: 6),
      set(number: 3, completed: true, reps: 6),
      set(number: 4, reps: 5),
    ]);

    expect(
      StrengthExerciseCaptureCompletion.isComplete(
        exercise: corrected,
        prescription: prescription,
      ),
      isFalse,
    );
  });
}
