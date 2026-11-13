import '../../../domain/running_workout/running_workout.dart';
import '../../session/models/running_target_admission.dart';

/// Read-only doses for a fixed, fully timed quality run. The original workout
/// and its unresolved targets still go through the normal start and review flow.
class ScheduledQualityRunSummary {
  const ScheduledQualityRunSummary._(this.totalSeconds, this.phases);

  final int totalSeconds;
  final List<String> phases;

  static ScheduledQualityRunSummary? fromWorkout(RunningWorkout? workout) {
    if (workout == null) return null;
    final steps = runningAtomicSteps(workout);
    if (!steps.any(
          (step) => step.target.kind == RunningTargetKind.qualityPaceRef,
        ) ||
        steps.any((step) {
          final milliseconds = step.duration.milliseconds;
          return step.duration.kind != RunningDurationKind.time ||
              milliseconds == null ||
              milliseconds <= 0 ||
              milliseconds % 1000 != 0;
        })) {
      return null;
    }

    final ordered = <RunningAtomicStep>[
      for (final node in workout.steps)
        if (node is RunningAtomicStep)
          node
        else if (node is RunningRepeatGroup)
          for (var repeat = 0; repeat < node.count; repeat++) ...node.steps,
    ];
    final phases = <String>[];
    var index = 0;
    while (index < ordered.length) {
      final step = ordered[index];
      if (step.role == RunningStepRole.work &&
          index + 1 < ordered.length &&
          _isRecovery(ordered[index + 1])) {
        final recovery = ordered[index + 1];
        var next = index + 2;
        var reps = 1;
        var recoveryAfterLast = true;
        while (next < ordered.length && _sameDose(step, ordered[next])) {
          if (next + 1 == ordered.length || !_isRecovery(ordered[next + 1])) {
            reps++;
            next++;
            recoveryAfterLast = false;
            break;
          }
          if (!_sameDose(recovery, ordered[next + 1])) break;
          reps++;
          next += 2;
        }
        if (reps > 1) {
          final pattern = recoveryAfterLast
              ? 'after each'
              : 'between reps only (${reps - 1} recoveries)';
          phases.add('$reps × ${_dose(step)} · ${_dose(recovery)} $pattern');
          index = next;
          continue;
        }
      }
      phases.add(_dose(step));
      index++;
    }

    return ScheduledQualityRunSummary._(
      ordered.fold(0, (total, step) => total + _seconds(step)),
      List.unmodifiable(phases),
    );
  }

  static bool _isRecovery(RunningAtomicStep step) =>
      step.role == RunningStepRole.recovery ||
      step.role == RunningStepRole.rest;

  static bool _sameDose(RunningAtomicStep a, RunningAtomicStep b) =>
      a.role == b.role &&
      a.duration == b.duration &&
      a.target == b.target &&
      a.label == b.label &&
      a.notes == b.notes;

  static int _seconds(RunningAtomicStep step) =>
      step.duration.milliseconds! ~/ 1000;

  static String _dose(RunningAtomicStep step) {
    final seconds = _seconds(step);
    final duration = seconds % 60 == 0
        ? '${seconds ~/ 60} min'
        : '$seconds sec';
    final authoredLabel = step.label?.trim();
    final label = authoredLabel == null || authoredLabel.isEmpty
        ? switch (step.role) {
            RunningStepRole.warmUp => 'warm-up',
            RunningStepRole.work => 'work',
            RunningStepRole.recovery => 'recovery',
            RunningStepRole.rest => 'rest',
            RunningStepRole.coolDown => 'cooldown',
            RunningStepRole.open => 'open phase',
          }
        : '${authoredLabel[0].toLowerCase()}${authoredLabel.substring(1)}';
    return '$duration $label';
  }
}
