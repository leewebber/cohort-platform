import 'package:cohort_platform/models/authored_int_range.dart';
import 'package:cohort_platform/models/strength_exercise_prescription.dart';

/// The founder-approved alternative for a separate one-session private trial.
class M31ThursdayEquipmentTrial {
  M31ThursdayEquipmentTrial._();

  static const versionId = '5d095027-a4fb-4529-9ade-7a96a75e743f';
  static const protocolId = 'protocol-514e5f5a-c825-49cd-911a-a2bdf4f6c6d3';
  static const packageHash =
      'f6fdc8bbe341f56d1dc819a3878a7df2ede766bc4b3b295e40efd8709f50352b';
  static const slotKey = 'LW10K-W01-D04';
  static const permissionId = 'm31-w01-d04-rdl';
  static const loadLabel = 'kg per dumbbell';
  static const cue =
      'Use one of two matching dumbbells in each hand. Hinge with soft knees '
      'and keep the dumbbells close. Stop before spinal position changes.';
  static const prescription = StrengthExercisePrescription(
    sets: 2,
    reps: StrengthRepPrescription(
      type: StrengthRepType.range,
      minReps: 5,
      maxReps: 6,
    ),
    rirRange: AuthoredIntRange(2, 3),
    restSecondsRange: AuthoredIntRange(120, 180),
    load: StrengthLoadPrescription(type: StrengthLoadType.athleteSelected),
    tempo: 'Lower under control for about two seconds.',
    coachCue: cue,
    performanceCapture: ExercisePerformanceCapture(
      loadUnit: 'kg',
      loadLabel: loadLabel,
    ),
  );
}
