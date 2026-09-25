import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../models/timer_configuration.dart';
import '../../models/workout_format.dart';
import 'running_workout_model.dart';
import 'running_workout_validation.dart';

class RunningWorkoutProjectionResult {
  const RunningWorkoutProjectionResult({
    this.workout,
    required this.errors,
    required this.warnings,
  });

  final RunningWorkout? workout;
  final List<RunningWorkoutIssue> errors;
  final List<RunningWorkoutIssue> warnings;

  bool get isSupported => workout != null && errors.isEmpty;
}

/// One-way projection. Does not replace timer execution authority.
class RunningWorkoutProjector {
  const RunningWorkoutProjector();

  static const idDerivation = 'sha256_16(format|timer_tokens|source_ref)';

  RunningWorkoutProjectionResult project({
    required WorkoutFormat format,
    required TimerConfiguration configuration,
    String? sourceRef,
    String? title,
    String? notes,
    String? untypedGuidance,
  }) {
    final warnings = <RunningWorkoutIssue>[];
    final errors = <RunningWorkoutIssue>[];

    void warning(String code, String message) {
      warnings.add(
        RunningWorkoutIssue(
          code: code,
          message: message,
          severity: RunningWorkoutIssueSeverity.warning,
        ),
      );
    }

    void error(String code, String message) {
      errors.add(
        RunningWorkoutIssue(
          code: code,
          message: message,
          severity: RunningWorkoutIssueSeverity.error,
        ),
      );
    }

    final guidance = [
      if (untypedGuidance != null && untypedGuidance.trim().isNotEmpty)
        untypedGuidance.trim(),
      if (configuration.timerNotes != null &&
          configuration.timerNotes!.trim().isNotEmpty)
        configuration.timerNotes!.trim(),
    ].join(' ');
    if (guidance.isNotEmpty) {
      warning(
        'untyped_guidance',
        'Authored labels/notes were preserved and were not numericised.',
      );
    }

    switch (format) {
      case WorkoutFormat.steadyState:
        final seconds = configuration.durationSeconds;
        if (seconds == null || seconds <= 0) {
          error(
            'unsupported_timer_shape',
            'Steady-state projection requires a positive durationSeconds.',
          );
          return RunningWorkoutProjectionResult(
            errors: errors,
            warnings: warnings,
          );
        }
        final workoutId = _workoutId(format, configuration, sourceRef);
        return RunningWorkoutProjectionResult(
          workout: RunningWorkout(
            workoutId: workoutId,
            title: title,
            notes: notes ?? (guidance.isEmpty ? null : guidance),
            provenance: RunningWorkoutProvenance(
              kind: RunningWorkoutProvenanceKind.projected,
              sourceKind: 'timer_configuration',
              sourceFormat: format.dbValue,
              idDerivation: idDerivation,
            ),
            steps: [
              RunningAtomicStep(
                stepId: '$workoutId:s:0',
                role: RunningStepRole.work,
                duration: RunningDuration.time(seconds * 1000),
              ),
            ],
          ),
          errors: errors,
          warnings: warnings,
        );
      case WorkoutFormat.intervals:
        final work = configuration.workSeconds;
        final rounds = configuration.rounds;
        final rest = configuration.restSeconds;
        if (work == null || work <= 0 || rounds == null || rounds <= 0) {
          error(
            'unsupported_timer_shape',
            'Interval projection requires positive workSeconds and rounds.',
          );
          return RunningWorkoutProjectionResult(
            errors: errors,
            warnings: warnings,
          );
        }
        if (configuration.stations.isNotEmpty ||
            configuration.restBetweenRoundsSeconds != null) {
          error(
            'unsupported_timer_shape',
            'Interval projection does not accept circuit stations or between-round recovery.',
          );
          return RunningWorkoutProjectionResult(
            errors: errors,
            warnings: warnings,
          );
        }
        final workoutId = _workoutId(format, configuration, sourceRef);
        final children = <RunningAtomicStep>[
          RunningAtomicStep(
            stepId: '$workoutId:s:work',
            role: RunningStepRole.work,
            duration: RunningDuration.time(work * 1000),
          ),
        ];
        if (rest != null && rest > 0) {
          children.add(
            RunningAtomicStep(
              stepId: '$workoutId:s:recovery',
              role: RunningStepRole.recovery,
              duration: RunningDuration.time(rest * 1000),
            ),
          );
        } else {
          warning(
            'projected_without_recovery',
            rest == 0
                ? 'Authored restSeconds is 0; no recovery step was created.'
                : 'No authored restSeconds; runtime default rest was not invented.',
          );
        }
        return RunningWorkoutProjectionResult(
          workout: RunningWorkout(
            workoutId: workoutId,
            title: title,
            notes: notes ?? (guidance.isEmpty ? null : guidance),
            provenance: RunningWorkoutProvenance(
              kind: RunningWorkoutProvenanceKind.projected,
              sourceKind: 'timer_configuration',
              sourceFormat: format.dbValue,
              idDerivation: idDerivation,
            ),
            steps: [
              RunningRepeatGroup(
                groupId: '$workoutId:g:0',
                count: rounds,
                steps: children,
              ),
            ],
          ),
          errors: errors,
          warnings: warnings,
        );
      case WorkoutFormat.amrap:
      case WorkoutFormat.emom:
      case WorkoutFormat.forTime:
      case WorkoutFormat.tabata:
      case WorkoutFormat.rounds:
      case WorkoutFormat.other:
      case WorkoutFormat.none:
        error(
          'unsupported_timer_shape',
          'Format ${format.dbValue} is not a supported B1 running projection.',
        );
        return RunningWorkoutProjectionResult(
          errors: errors,
          warnings: warnings,
        );
    }
  }

  String _workoutId(
    WorkoutFormat format,
    TimerConfiguration configuration,
    String? sourceRef,
  ) {
    final token = [
      format.dbValue,
      'd=${configuration.durationSeconds ?? ''}',
      'w=${configuration.workSeconds ?? ''}',
      'r=${configuration.restSeconds ?? ''}',
      'n=${configuration.rounds ?? ''}',
      'src=${sourceRef ?? ''}',
    ].join('|');
    final digest = sha256.convert(utf8.encode(token)).toString().substring(0, 16);
    return 'rw1:p:$digest';
  }
}
