import '../../../models/workout_format.dart';
import '../models/active_performance_draft.dart';
import '../models/interval_work_result.dart';
import '../models/performance_result_data.dart';
import '../models/performance_result_type.dart';
import '../models/training_block_result_status.dart';
import '../models/training_session_record_status.dart';

class PerformanceValidationResult {
  const PerformanceValidationResult({
    required this.isValid,
    this.fieldErrors = const {},
  });

  final bool isValid;
  final Map<String, String> fieldErrors;
}

class PerformanceValidationService {
  const PerformanceValidationService();

  PerformanceValidationResult validateForCompletion(
    ActivePerformanceDraft draft,
  ) {
    final errors = <String, String>{};

    if (draft.overallRpe != null &&
        (draft.overallRpe! < 1 || draft.overallRpe! > 10)) {
      errors['overallRpe'] = 'Session RPE must be between 1 and 10.';
    }

    if (draft.athleteNote != null && draft.athleteNote!.length > 2000) {
      errors['athleteNote'] = 'Session note must be 2000 characters or fewer.';
    }

    for (final block in draft.blockDrafts) {
      _validateBlock(block, errors);
    }

    return PerformanceValidationResult(
      isValid: errors.isEmpty,
      fieldErrors: errors,
    );
  }

  TrainingSessionRecordStatus resolveCompletionStatus(
    ActivePerformanceDraft draft,
  ) {
    final meaningfulBlocks = draft.blockDrafts.where(
      _blockCountsTowardCompletion,
    );
    if (meaningfulBlocks.isEmpty ||
        meaningfulBlocks.every(
          (block) => block.status == TrainingBlockResultStatus.skipped,
        )) {
      return TrainingSessionRecordStatus.abandoned;
    }

    if (draft.incompleteBlockCount > 0 || draft.skippedBlockCount > 0) {
      return TrainingSessionRecordStatus.partiallyCompleted;
    }

    return TrainingSessionRecordStatus.completed;
  }

  void _validateBlock(BlockPerformanceDraft block, Map<String, String> errors) {
    final prefix = 'block:${block.sourceBlockId}';

    if (block.athleteNote != null && block.athleteNote!.length > 1000) {
      errors['$prefix.note'] = 'Block note must be 1000 characters or fewer.';
    }

    final resultData = block.resultData;
    if (resultData is AmrapResultData) {
      if (resultData.rounds < 0) {
        errors['$prefix.rounds'] = 'Rounds cannot be negative.';
      }
      if (resultData.extraReps < 0) {
        errors['$prefix.extraReps'] = 'Extra reps cannot be negative.';
      }
    } else if (resultData is ForTimeResultData) {
      if (resultData.completed &&
          (resultData.elapsedSeconds == null ||
              resultData.elapsedSeconds! <= 0)) {
        errors['$prefix.elapsedSeconds'] =
            'Elapsed time must be greater than zero.';
      }
    } else if (resultData is IntervalResultData) {
      if (resultData.recordedCount < 0) {
        errors['$prefix.intervalsCompleted'] =
            'Intervals completed cannot be negative.';
      }
      final prescribed = resultData.prescribedCount;
      if (prescribed != null && resultData.recordedCount > prescribed) {
        errors['$prefix.intervalsCompleted'] =
            'Intervals completed cannot exceed the authored rounds.';
      }
      if (resultData.usesPerIntervalCapture &&
          prescribed != null &&
          resultData.intervals.length > prescribed) {
        errors['$prefix.intervals'] =
            'More interval results than authored rounds.';
      }
      if (!IntervalPaceUnit.isSupported(resultData.paceUnit)) {
        errors['$prefix.paceUnit'] = 'Unsupported interval pace unit.';
      }
      for (final row in resultData.intervals) {
        if (prescribed != null &&
            (row.ordinal < 1 || row.ordinal > prescribed)) {
          errors['$prefix.interval:${row.ordinal}'] =
              'Interval number is outside the authored block.';
        }
        if (row.state == IntervalWorkState.completed &&
            (row.paceSecondsPerKm == null || row.paceSecondsPerKm! <= 0)) {
          errors['$prefix.interval:${row.ordinal}'] =
              'Completed intervals need a valid pace or Pace unavailable.';
        }
      }
    } else if (resultData is DistanceResultData) {
      if (resultData.distance != null && resultData.distance! <= 0) {
        errors['$prefix.distance'] = 'Distance must be greater than zero.';
      }
      if (resultData.durationSeconds != null &&
          resultData.durationSeconds! <= 0) {
        errors['$prefix.durationSeconds'] =
            'Duration must be greater than zero.';
      }
    } else if (resultData is EnduranceResultData) {
      if (resultData.distance != null && resultData.distance! <= 0) {
        errors['$prefix.distance'] = 'Distance must be greater than zero.';
      }
      if (resultData.durationSeconds != null &&
          resultData.durationSeconds! <= 0) {
        errors['$prefix.durationSeconds'] =
            'Duration must be greater than zero.';
      }
      if (resultData.averageHeartRate != null &&
          (resultData.averageHeartRate! < 30 ||
              resultData.averageHeartRate! > 250)) {
        errors['$prefix.averageHeartRate'] =
            'Average heart rate must be between 30 and 250 bpm.';
      }
    } else if (resultData is DurationResultData) {
      if (resultData.durationSeconds != null &&
          resultData.durationSeconds! <= 0) {
        errors['$prefix.durationSeconds'] =
            'Duration must be greater than zero.';
      }
    } else if (resultData is RoundsResultData) {
      if (resultData.roundsCompleted < 0) {
        errors['$prefix.roundsCompleted'] = 'Rounds cannot be negative.';
      }
      if (resultData.extraReps < 0) {
        errors['$prefix.extraReps'] = 'Extra reps cannot be negative.';
      }
    } else if (resultData is CustomMetricResultData) {
      if (resultData.numericValue != null &&
          (resultData.label == null || resultData.label!.isEmpty)) {
        errors['$prefix.label'] = 'Enter a label for the custom metric.';
      }
    }

    if (block.status == TrainingBlockResultStatus.completed) {
      if (resultData is AmrapResultData && !resultData.entered) {
        errors['$prefix.amrap'] =
            'Enter performed rounds or reps before completing this block.';
      } else if (resultData is IntervalResultData &&
          !resultData.entered &&
          resultData.recordedCount == 0) {
        errors['$prefix.intervals'] =
            'Enter completed intervals before completing this block.';
      } else if (resultData is CircuitResultData &&
          resultData.recordedCount == 0) {
        errors['$prefix.circuit'] =
            'Record at least one station actual before completing this block.';
      } else if (resultData is RoundsResultData && !resultData.entered) {
        errors['$prefix.rounds'] =
            'Enter performed rounds or reps before completing this block.';
      } else if (block.captureMode == BlockCaptureMode.completion &&
          block.exerciseResults.any((exercise) => exercise.sets.isNotEmpty)) {
        for (final exercise in block.exerciseResults) {
          if (exercise.sets.any((set) => !set.completed)) {
            errors['$prefix.exercise:${exercise.sourceExerciseId}'] =
                'Acknowledge every required warm-up movement before completing this block.';
          }
        }
      } else if (block.captureMode == BlockCaptureMode.strength) {
        for (final exercise in block.exerciseResults) {
          final isDistanceCapture = exercise.sets.any(
            (set) => set.distanceUnit?.trim().isNotEmpty == true,
          );
          if (isDistanceCapture) {
            final incompleteActual =
                exercise.sets.isEmpty ||
                exercise.sets.any(
                  (set) =>
                      !set.completed ||
                      set.load == null ||
                      set.load! <= 0 ||
                      set.distance == null ||
                      set.distance! <= 0,
                );
            if (incompleteActual) {
              errors['$prefix.exercise:${exercise.sourceExerciseId}'] =
                  'Complete every prescribed carry set with load per hand and distance.';
            }
            continue;
          }
          final completedActual = exercise.sets.any(
            (set) =>
                set.completed && (set.reps != null || set.distance != null),
          );
          if (!completedActual) {
            errors['$prefix.exercise:${exercise.sourceExerciseId}'] =
                'Enter and complete at least one performed set with actual reps.';
          }
        }
      } else if (resultData is EnduranceResultData &&
          resultData.distance == null &&
          resultData.durationSeconds == null) {
        errors['$prefix.endurance'] =
            'Enter performed distance or duration before completing this block.';
      } else if (resultData is CustomMetricResultData &&
          (resultData.label == null ||
              resultData.label!.isEmpty ||
              resultData.numericValue == null)) {
        errors['$prefix.customMetric'] =
            'Enter the performed metric and value before completing this block.';
      }
    }

    for (final exercise in block.exerciseResults) {
      for (final set in exercise.sets) {
        final setPrefix = '$prefix.set:${set.setResultId}';
        if (set.reps != null && set.reps! < 0) {
          errors['$setPrefix.reps'] = 'Reps cannot be negative.';
        }
        if (set.load != null && set.load! < 0) {
          errors['$setPrefix.load'] = 'Load cannot be negative.';
        }
        if (set.distance != null && set.distance! < 0) {
          errors['$setPrefix.distance'] = 'Distance cannot be negative.';
        }
        if (set.durationSeconds != null && set.durationSeconds! < 0) {
          errors['$setPrefix.durationSeconds'] = 'Duration cannot be negative.';
        }
        if (set.rpe != null && (set.rpe! < 1 || set.rpe! > 10)) {
          errors['$setPrefix.rpe'] = 'Set RPE must be between 1 and 10.';
        }
      }
    }
  }

  bool _blockCountsTowardCompletion(BlockPerformanceDraft block) {
    return block.blockSnapshot.content.trim().isNotEmpty ||
        block.blockSnapshot.exercises.isNotEmpty ||
        block.blockSnapshot.workoutFormat.supportsTimer;
  }
}
