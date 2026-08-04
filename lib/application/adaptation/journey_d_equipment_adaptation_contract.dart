/// Deterministic Journey D equipment-adaptation contract (B4d.19).
///
/// Shared by local product tests and the S17 Journey D harness. Substitution
/// identity is authored by the curated knowledge registry
/// (`cohort.substitution.back_squat_to_goblet_squat`), not invented here.
class JourneyDEquipmentAdaptationContract {
  const JourneyDEquipmentAdaptationContract._();

  static const sourceExerciseId = 'cohort.exercise.back_squat';
  static const replacementExerciseId = 'cohort.exercise.goblet_squat';
  static const substitutionRuleId =
      'cohort.substitution.back_squat_to_goblet_squat';

  /// Equipment present for the athlete — deliberately omits barbell + rack.
  static const availableEquipment = <String>{
    'cohort.equipment.kettlebell',
    'cohort.equipment.bodyweight',
    'cohort.equipment.dumbbell',
  };

  static const omittedRequiredEquipment = <String>{
    'cohort.equipment.barbell',
    'cohort.equipment.squat_rack',
  };
}
