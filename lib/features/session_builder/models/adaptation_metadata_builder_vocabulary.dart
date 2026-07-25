import '../../../domain/adaptation/adaptation_domain.dart';
import '../../../models/session_block_type.dart';

/// Coach-facing labels for adaptation metadata in Session Builder.
class AdaptationMetadataBuilderVocabulary {
  const AdaptationMetadataBuilderVocabulary._();

  static const minimumViableDurationHelper =
      'Shortest duration that can still preserve the purpose of this session.';

  static const useRecommendedLabel = 'Use recommended for block type';

  static List<SessionIntent> get orderedSessionIntents {
    final values = List<SessionIntent>.from(SessionIntent.values);
    values.sort(
      (a, b) => sessionIntentDisplayLabel(a)
          .compareTo(sessionIntentDisplayLabel(b)),
    );
    return values;
  }

  static String sessionIntentDisplayLabel(SessionIntent intent) {
    return switch (intent) {
      SessionIntent.upperBodyStrength => 'Upper body strength',
      SessionIntent.lowerBodyStrength => 'Lower body strength',
      SessionIntent.fullBodyStrength => 'Full body strength',
      SessionIntent.pushStrength => 'Push strength',
      SessionIntent.pullStrength => 'Pull strength',
      SessionIntent.squatStrength => 'Squat strength',
      SessionIntent.hingeStrength => 'Hinge strength',
      SessionIntent.unilateralLowerBodyStrength => 'Unilateral lower body strength',
      SessionIntent.strengthEndurance => 'Strength endurance',
      SessionIntent.upperBodyHypertrophy => 'Upper body hypertrophy',
      SessionIntent.lowerBodyHypertrophy => 'Lower body hypertrophy',
      SessionIntent.fullBodyHypertrophy => 'Full body hypertrophy',
      SessionIntent.pushHypertrophy => 'Push hypertrophy',
      SessionIntent.pullHypertrophy => 'Pull hypertrophy',
      SessionIntent.shoulderHypertrophy => 'Shoulder hypertrophy',
      SessionIntent.armHypertrophy => 'Arm hypertrophy',
      SessionIntent.chestHypertrophy => 'Chest hypertrophy',
      SessionIntent.backHypertrophy => 'Back hypertrophy',
      SessionIntent.legHypertrophy => 'Leg hypertrophy',
      SessionIntent.gluteHypertrophy => 'Glute hypertrophy',
      SessionIntent.aerobicBase => 'Aerobic base',
      SessionIntent.recoveryRunning => 'Recovery running',
      SessionIntent.steadyAerobicEndurance => 'Steady aerobic endurance',
      SessionIntent.tempo => 'Tempo',
      SessionIntent.threshold => 'Threshold',
      SessionIntent.vo2Max => 'VO₂ max',
      SessionIntent.runningEconomy => 'Running economy',
      SessionIntent.racePace => 'Race pace',
      SessionIntent.longRun => 'Long run',
      SessionIntent.hills => 'Hills',
      SessionIntent.sprintDevelopment => 'Sprint development',
      SessionIntent.techniqueAndDrills => 'Technique and drills',
      SessionIntent.aerobicConditioning => 'Aerobic conditioning',
      SessionIntent.anaerobicConditioning => 'Anaerobic conditioning',
      SessionIntent.mixedModalConditioning => 'Mixed modal conditioning',
      SessionIntent.muscularEndurance => 'Muscular endurance',
      SessionIntent.workCapacity => 'Work capacity',
      SessionIntent.highIntensityIntervals => 'High intensity intervals',
      SessionIntent.hyroxSpecificConditioning => 'Hyrox specific conditioning',
      SessionIntent.compromisedRunning => 'Compromised running',
      SessionIntent.stationSpecificConditioning => 'Station specific conditioning',
      SessionIntent.activeRecovery => 'Active recovery',
      SessionIntent.mobility => 'Mobility',
      SessionIntent.flexibility => 'Flexibility',
      SessionIntent.movementQuality => 'Movement quality',
      SessionIntent.prehabilitation => 'Prehabilitation',
      SessionIntent.breathingAndRecovery => 'Breathing and recovery',
      SessionIntent.skillDevelopment => 'Skill development',
    };
  }

  static String blockPriorityDisplayLabel(BlockPriority priority) {
    return switch (priority) {
      BlockPriority.essential => 'Essential',
      BlockPriority.primary => 'Important',
      BlockPriority.secondary => 'Secondary',
      BlockPriority.optional => 'Optional',
      BlockPriority.disposable => 'Disposable',
    };
  }

  static String recommendedBlockPriorityLabel(SessionBlockType blockType) {
    final effective =
        SessionBlockTypeAdaptationPolicy.defaultPriority(blockType);
    return blockPriorityDisplayLabel(effective);
  }

  static String policyFlagLabel(String key) {
    return switch (key) {
      'canRemove' => 'Can remove block',
      'canShorten' => 'Can shorten block',
      'canReduceVolume' => 'Can reduce volume',
      'canReduceIntensity' => 'Can reduce intensity',
      'canIncreaseRest' => 'Can increase rest',
      'canSuperset' => 'Can superset',
      'canReplaceExercises' => 'Can replace exercises',
      'canReplaceBlock' => 'Can replace block',
      _ => key,
    };
  }
}
