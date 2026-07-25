import '../../../models/session_block.dart';
import '../../../models/session_block_exercise_link.dart';
import '../../../models/session_block_type.dart';
import '../../../models/strength_exercise_prescription.dart';
import '../../../models/timer_configuration.dart';
import '../../../models/workout_format.dart';
import '../evaluation/adaptation_evaluation_result.dart';

/// Derives reliable block duration estimates from authored block metadata only.
class PlannedBlockDurationEstimator {
  const PlannedBlockDurationEstimator._();

  static int? estimatedMinutesFromBlock(SessionBlock block) {
    final timer = block.timerConfiguration;
    if (timer != null) {
      final seconds = _reliableTimerSeconds(block.workoutFormat, timer);
      if (seconds != null && seconds > 0) {
        return (seconds / 60).ceil();
      }
    }
    return null;
  }

  static int? _reliableTimerSeconds(
    WorkoutFormat format,
    TimerConfiguration timer,
  ) {
    return switch (format) {
      WorkoutFormat.amrap => timer.durationSeconds,
      WorkoutFormat.emom => timer.totalDurationSeconds,
      WorkoutFormat.intervals =>
        _intervalTotalSeconds(timer.workSeconds, timer.restSeconds, timer.rounds),
      WorkoutFormat.tabata =>
        _intervalTotalSeconds(timer.workSeconds, timer.restSeconds, timer.rounds),
      WorkoutFormat.other => timer.durationSeconds ?? timer.totalDurationSeconds,
      WorkoutFormat.forTime => timer.timeCapSeconds,
      WorkoutFormat.rounds => null,
      WorkoutFormat.none => null,
    };
  }

  static int? _intervalTotalSeconds(int? work, int? rest, int? rounds) {
    if (work == null || rest == null || rounds == null) return null;
    if (work <= 0 || rounds <= 0 || rest < 0) return null;
    return rounds * (work + rest);
  }

  static List<PlannedExercisePrescriptionInput> prescriptionsFromBlock(
    SessionBlock block,
  ) {
    return block.linkedExercises
        .map((link) => prescriptionFromLink(block, link))
        .toList(growable: false);
  }

  static PlannedExercisePrescriptionInput prescriptionFromLink(
    SessionBlock block,
    SessionBlockExerciseLink link,
  ) {
    final prescription = link.prescription;
    if (prescription == null || !prescription.hasStructuredData) {
      return PlannedExercisePrescriptionInput(
        exerciseLinkLocalId: link.localId,
        exerciseId: link.exerciseId,
        supportsStructuredReduction: false,
      );
    }
    return PlannedExercisePrescriptionInput(
      exerciseLinkLocalId: link.localId,
      exerciseId: link.exerciseId,
      sets: prescription.sets,
      reps: prescription.reps.type == StrengthRepType.exact
          ? prescription.reps.exactReps
          : null,
      restSeconds: prescription.restSeconds,
      supportsStructuredReduction:
          block.blockType.supportsStructuredStrengthPrescription &&
              prescription.sets > 0,
    );
  }
}
