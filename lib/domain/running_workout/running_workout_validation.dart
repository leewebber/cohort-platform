import 'running_workout_model.dart';

enum RunningWorkoutIssueSeverity { error, warning }

class RunningWorkoutIssue {
  const RunningWorkoutIssue({
    required this.code,
    required this.message,
    required this.severity,
    this.path,
  });

  final String code;
  final String message;
  final RunningWorkoutIssueSeverity severity;
  final String? path;

  bool get isBlocking => severity == RunningWorkoutIssueSeverity.error;
}

class RunningWorkoutValidationResult {
  const RunningWorkoutValidationResult({
    required this.errors,
    required this.warnings,
  });

  final List<RunningWorkoutIssue> errors;
  final List<RunningWorkoutIssue> warnings;

  bool get isValid => errors.isEmpty;
}

class RunningWorkoutValidator {
  const RunningWorkoutValidator();

  static const supportedSchemaVersion = 1;
  static const maxRepeatCount = 32;

  RunningWorkoutValidationResult validate(RunningWorkout workout) {
    final errors = <RunningWorkoutIssue>[];
    final warnings = <RunningWorkoutIssue>[];

    void error(String code, String message, [String? path]) {
      errors.add(
        RunningWorkoutIssue(
          code: code,
          message: message,
          severity: RunningWorkoutIssueSeverity.error,
          path: path,
        ),
      );
    }

    void warning(String code, String message, [String? path]) {
      warnings.add(
        RunningWorkoutIssue(
          code: code,
          message: message,
          severity: RunningWorkoutIssueSeverity.warning,
          path: path,
        ),
      );
    }

    if (workout.schemaVersion != supportedSchemaVersion) {
      error(
        'unsupported_schema_version',
        'Schema version ${workout.schemaVersion} is not supported.',
      );
    }
    if (workout.workoutId.trim().isEmpty) {
      error('missing_workout_id', 'Workout ID is required.');
    }
    if (workout.steps.isEmpty) {
      error('empty_steps', 'A workout must contain at least one step.');
    }

    final ids = <String>{};
    void takeId(String id, String path) {
      if (id.trim().isEmpty) {
        error('missing_id', 'A stable local ID is required.', path);
        return;
      }
      if (!ids.add(id)) {
        error('duplicate_id', 'ID "$id" is not unique within the workout.', path);
      }
    }

    takeId(workout.workoutId, 'workout_id');
    _warnProse(workout.notes, 'notes', warning);
    _warnProse(workout.intent, 'intent', warning);

    for (var i = 0; i < workout.steps.length; i++) {
      _validateNode(
        workout.steps[i],
        'steps[$i]',
        errors: errors,
        warnings: warnings,
        takeId: takeId,
        error: error,
        warning: warning,
        insideRepeat: false,
      );
    }

    return RunningWorkoutValidationResult(errors: errors, warnings: warnings);
  }

  void _validateNode(
    RunningWorkoutNode node,
    String path, {
    required List<RunningWorkoutIssue> errors,
    required List<RunningWorkoutIssue> warnings,
    required void Function(String id, String path) takeId,
    required void Function(String code, String message, [String? path]) error,
    required void Function(String code, String message, [String? path]) warning,
    required bool insideRepeat,
  }) {
    switch (node) {
      case RunningAtomicStep():
        takeId(node.stepId, '$path.step_id');
        _validateDuration(node.duration, path, error);
        _validateTarget(node.target, path, error);
        _warnProse(node.notes, path, warning);
      case RunningRepeatGroup():
        if (insideRepeat) {
          error(
            'nested_repeat_group',
            'Structured Workout v1 allows only one repeat-group level.',
            path,
          );
        }
        takeId(node.groupId, '$path.group_id');
        if (node.count < 1 || node.count > maxRepeatCount) {
          error(
            'invalid_repeat_count',
            'Repeat count must be between 1 and $maxRepeatCount.',
            path,
          );
        }
        if (node.steps.isEmpty) {
          error(
            'empty_repeat_children',
            'A repeat group must contain at least one atomic step.',
            path,
          );
        }
        for (var i = 0; i < node.steps.length; i++) {
          _validateNode(
            node.steps[i],
            '$path.steps[$i]',
            errors: errors,
            warnings: warnings,
            takeId: takeId,
            error: error,
            warning: warning,
            insideRepeat: true,
          );
        }
    }
  }

  void _validateDuration(
    RunningDuration duration,
    String path,
    void Function(String code, String message, [String? path]) error,
  ) {
    switch (duration.kind) {
      case RunningDurationKind.time:
        if (duration.milliseconds == null || duration.milliseconds! <= 0) {
          error(
            'invalid_duration',
            'Time duration must be a positive integer in milliseconds.',
            path,
          );
        }
        if (duration.millimetres != null) {
          error(
            'conflicting_duration',
            'A step may have only one duration authority.',
            path,
          );
        }
      case RunningDurationKind.distance:
        if (duration.millimetres == null || duration.millimetres! <= 0) {
          error(
            'invalid_duration',
            'Distance duration must be a positive integer in millimetres.',
            path,
          );
        }
        if (duration.milliseconds != null) {
          error(
            'conflicting_duration',
            'A step may have only one duration authority.',
            path,
          );
        }
      case RunningDurationKind.manualLap:
        if (duration.milliseconds != null || duration.millimetres != null) {
          error(
            'conflicting_duration',
            'A manual-lap step must not carry time or distance.',
            path,
          );
        }
    }
  }

  void _validateTarget(
    RunningTarget target,
    String path,
    void Function(String code, String message, [String? path]) error,
  ) {
    bool positive(int? value) => value != null && value > 0;

    void range(int? low, int? high, String label) {
      if (!positive(low) || !positive(high)) {
        error(
          'invalid_target',
          '$label range values must be positive integers.',
          path,
        );
        return;
      }
      if (low! >= high!) {
        error(
          'invalid_target_range',
          '$label range lower bound must be less than the upper bound.',
          path,
        );
      }
    }

    switch (target.kind) {
      case RunningTargetKind.none:
        return;
      case RunningTargetKind.pace:
        if (!positive(target.paceMillisecondsPerKilometre)) {
          error(
            'invalid_target',
            'Pace must be a positive integer in milliseconds per kilometre.',
            path,
          );
        }
      case RunningTargetKind.paceRange:
        range(
          target.paceMillisecondsPerKilometreLow,
          target.paceMillisecondsPerKilometreHigh,
          'Pace',
        );
      case RunningTargetKind.heartRate:
        if (!positive(target.heartRateBpm) || target.heartRateBpm! > 250) {
          error('invalid_target', 'Heart rate must be 1–250 bpm.', path);
        }
      case RunningTargetKind.heartRateRange:
        range(target.heartRateBpmLow, target.heartRateBpmHigh, 'Heart rate');
      case RunningTargetKind.heartRateZoneRef:
        if (target.heartRateZoneRef == null ||
            target.heartRateZoneRef!.trim().isEmpty) {
          error(
            'invalid_target',
            'Heart-rate zone reference must be a non-empty identifier.',
            path,
          );
        }
      case RunningTargetKind.power:
        if (!positive(target.powerWatts)) {
          error('invalid_target', 'Power must be a positive integer in watts.', path);
        }
      case RunningTargetKind.powerRange:
        range(target.powerWattsLow, target.powerWattsHigh, 'Power');
      case RunningTargetKind.cadenceRange:
        range(
          target.cadenceStepsPerMinuteLow,
          target.cadenceStepsPerMinuteHigh,
          'Cadence',
        );
      case RunningTargetKind.rpe:
        if (target.rpeCr10 == null ||
            target.rpeCr10! < 1 ||
            target.rpeCr10! > 10) {
          error('invalid_target', 'RPE must be an integer 1–10 on scale rpe_cr10.', path);
        }
      case RunningTargetKind.rpeRange:
        range(target.rpeCr10Low, target.rpeCr10High, 'RPE');
        if ((target.rpeCr10Low != null && target.rpeCr10Low! > 10) ||
            (target.rpeCr10High != null && target.rpeCr10High! > 10)) {
          error('invalid_target', 'RPE range must stay within 1–10.', path);
        }
    }
  }

  void _warnProse(
    String? notes,
    String path,
    void Function(String code, String message, [String? path]) warning,
  ) {
    final text = notes?.trim() ?? '';
    if (text.isEmpty) return;
    final lower = text.toLowerCase();
    if (lower.contains('zone') ||
        lower.contains('threshold') ||
        lower.contains('easy') ||
        RegExp(r'\d+\s*km').hasMatch(lower) ||
        RegExp(r'\d+:\d+\s*/\s*km').hasMatch(lower)) {
      warning(
        'untyped_guidance',
        'Authored guidance was preserved as notes and was not numericised.',
        path,
      );
    }
  }
}
