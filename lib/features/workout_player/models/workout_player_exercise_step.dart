import '../../session/models/session_execution_plan.dart';

/// Flattened exercise step for the athlete Workout Player.
class WorkoutPlayerExerciseStep {
  const WorkoutPlayerExerciseStep({
    required this.stepIndex,
    required this.blockId,
    required this.blockTitle,
    required this.exercise,
    required this.totalSets,
  });

  final int stepIndex;
  final String blockId;
  final String blockTitle;
  final SessionExecutionExerciseSummary exercise;
  final int totalSets;

  String get name => exercise.athleteLabel;

  String? get movementCategory {
    final exerciseModel = exercise.exercise;
    return exerciseModel?.category?.trim().isNotEmpty == true
        ? exerciseModel!.category
        : exerciseModel?.movementPattern;
  }

  String? get description {
    final model = exercise.exercise;
    final execution = model?.execution?.trim();
    if (execution != null && execution.isNotEmpty) return execution;
    final purpose = model?.purpose?.trim();
    if (purpose != null && purpose.isNotEmpty) return purpose;
    return null;
  }

  String? get coachingCues {
    final fromPrescription = exercise.prescription?.coachCue?.trim();
    if (fromPrescription != null && fromPrescription.isNotEmpty) {
      return fromPrescription;
    }
    final fromExercise = exercise.exercise?.coachingCues?.trim();
    if (fromExercise != null && fromExercise.isNotEmpty) return fromExercise;
    return null;
  }

  String get setsLabel => '$totalSets';

  String get repsLabel {
    final prescription = exercise.prescription;
    if (prescription == null) return 'As prescribed';
    final reps = prescription.reps.toLegacyMetadataValue().trim();
    return reps.isEmpty ? 'As prescribed' : reps;
  }

  String? get loadGuidance {
    final load = exercise.prescription?.load;
    if (load == null || !load.hasValue) {
      return exercise.exercise?.loadingOptions?.trim();
    }
    return load.toLegacyMetadataValue();
  }

  String? get restGuidance {
    final rest = exercise.prescription?.restSeconds;
    if (rest != null && rest > 0) return '${rest}s rest';
    return exercise.exercise?.restGuidance?.trim();
  }

  String? get rpeGuidance {
    final tempo = exercise.prescription?.tempo?.trim();
    if (tempo != null && tempo.isNotEmpty) return tempo;
    return exercise.exercise?.tempoGuidance?.trim();
  }

  String get prescriptionSummary {
    final parts = <String>[
      '$totalSets sets',
      repsLabel,
      if (loadGuidance != null && loadGuidance!.isNotEmpty) loadGuidance!,
    ];
    return parts.join(' · ');
  }
}
