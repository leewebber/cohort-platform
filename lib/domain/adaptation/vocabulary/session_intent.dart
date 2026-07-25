/// Canonical session training intent (V1 taxonomy).
///
/// Finer-grained than [ProgrammeIntent]; used for adaptation fidelity and
/// candidate ranking. See `07 Documentation/79_Adaptation_Ontology_V1.md`.
library;

enum SessionIntent {
  // Strength
  upperBodyStrength,
  lowerBodyStrength,
  fullBodyStrength,
  pushStrength,
  pullStrength,
  squatStrength,
  hingeStrength,
  unilateralLowerBodyStrength,
  strengthEndurance,

  // Hypertrophy
  upperBodyHypertrophy,
  lowerBodyHypertrophy,
  fullBodyHypertrophy,
  pushHypertrophy,
  pullHypertrophy,
  shoulderHypertrophy,
  armHypertrophy,
  chestHypertrophy,
  backHypertrophy,
  legHypertrophy,
  gluteHypertrophy,

  // Running
  aerobicBase,
  recoveryRunning,
  steadyAerobicEndurance,
  tempo,
  threshold,
  vo2Max,
  runningEconomy,
  racePace,
  longRun,
  hills,
  sprintDevelopment,
  techniqueAndDrills,

  // Conditioning
  aerobicConditioning,
  anaerobicConditioning,
  mixedModalConditioning,
  muscularEndurance,
  workCapacity,
  highIntensityIntervals,
  hyroxSpecificConditioning,
  compromisedRunning,
  stationSpecificConditioning,

  // Recovery / movement
  activeRecovery,
  mobility,
  flexibility,
  movementQuality,
  prehabilitation,
  breathingAndRecovery,
  skillDevelopment,
}

extension SessionIntentDb on SessionIntent {
  String get dbValue {
    return switch (this) {
      SessionIntent.upperBodyStrength => 'upper_body_strength',
      SessionIntent.lowerBodyStrength => 'lower_body_strength',
      SessionIntent.fullBodyStrength => 'full_body_strength',
      SessionIntent.pushStrength => 'push_strength',
      SessionIntent.pullStrength => 'pull_strength',
      SessionIntent.squatStrength => 'squat_strength',
      SessionIntent.hingeStrength => 'hinge_strength',
      SessionIntent.unilateralLowerBodyStrength =>
        'unilateral_lower_body_strength',
      SessionIntent.strengthEndurance => 'strength_endurance',
      SessionIntent.upperBodyHypertrophy => 'upper_body_hypertrophy',
      SessionIntent.lowerBodyHypertrophy => 'lower_body_hypertrophy',
      SessionIntent.fullBodyHypertrophy => 'full_body_hypertrophy',
      SessionIntent.pushHypertrophy => 'push_hypertrophy',
      SessionIntent.pullHypertrophy => 'pull_hypertrophy',
      SessionIntent.shoulderHypertrophy => 'shoulder_hypertrophy',
      SessionIntent.armHypertrophy => 'arm_hypertrophy',
      SessionIntent.chestHypertrophy => 'chest_hypertrophy',
      SessionIntent.backHypertrophy => 'back_hypertrophy',
      SessionIntent.legHypertrophy => 'leg_hypertrophy',
      SessionIntent.gluteHypertrophy => 'glute_hypertrophy',
      SessionIntent.aerobicBase => 'aerobic_base',
      SessionIntent.recoveryRunning => 'recovery_running',
      SessionIntent.steadyAerobicEndurance => 'steady_aerobic_endurance',
      SessionIntent.tempo => 'tempo',
      SessionIntent.threshold => 'threshold',
      SessionIntent.vo2Max => 'vo2_max',
      SessionIntent.runningEconomy => 'running_economy',
      SessionIntent.racePace => 'race_pace',
      SessionIntent.longRun => 'long_run',
      SessionIntent.hills => 'hills',
      SessionIntent.sprintDevelopment => 'sprint_development',
      SessionIntent.techniqueAndDrills => 'technique_and_drills',
      SessionIntent.aerobicConditioning => 'aerobic_conditioning',
      SessionIntent.anaerobicConditioning => 'anaerobic_conditioning',
      SessionIntent.mixedModalConditioning => 'mixed_modal_conditioning',
      SessionIntent.muscularEndurance => 'muscular_endurance',
      SessionIntent.workCapacity => 'work_capacity',
      SessionIntent.highIntensityIntervals => 'high_intensity_intervals',
      SessionIntent.hyroxSpecificConditioning => 'hyrox_specific_conditioning',
      SessionIntent.compromisedRunning => 'compromised_running',
      SessionIntent.stationSpecificConditioning =>
        'station_specific_conditioning',
      SessionIntent.activeRecovery => 'active_recovery',
      SessionIntent.mobility => 'mobility',
      SessionIntent.flexibility => 'flexibility',
      SessionIntent.movementQuality => 'movement_quality',
      SessionIntent.prehabilitation => 'prehabilitation',
      SessionIntent.breathingAndRecovery => 'breathing_and_recovery',
      SessionIntent.skillDevelopment => 'skill_development',
    };
  }

  static SessionIntent? fromDb(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim().toLowerCase();
    for (final intent in SessionIntent.values) {
      if (intent.dbValue == normalized) return intent;
    }
    return null;
  }
}
