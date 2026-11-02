import '../../../domain/running_workout/running_workout_model.dart';

/// A view of contiguous typed steps. It retains every source step, including
/// every recovery. This is never written back as a new workout representation.
class RunningPresentationGroup {
  const RunningPresentationGroup(this.steps, {this.repetitions = 1});
  final List<RunningAtomicStep> steps;
  final int repetitions;
  bool get repeated => repetitions > 1;
  bool get recoveryAfterLast => steps.last.role == RunningStepRole.recovery;
}

bool _sameStep(RunningAtomicStep a, RunningAtomicStep b) =>
    a.role == b.role &&
    a.duration == b.duration &&
    a.target == b.target &&
    a.label == b.label &&
    a.notes == b.notes;

/// Only adjacent, identical work/recovery cycles are grouped. IDs remain in
/// order. Changed cues, targets, durations or roles stop a group; labels are
/// compared for fidelity, never interpreted to infer workout meaning.
List<RunningPresentationGroup> groupRunningSteps(
  List<RunningWorkoutNode> nodes,
) {
  final steps = <RunningAtomicStep>[];
  for (final node in nodes) {
    switch (node) {
      case RunningAtomicStep():
        steps.add(node);
      case RunningRepeatGroup():
        for (var i = 0; i < node.count; i++) {
          steps.addAll(node.steps);
        }
    }
  }
  final groups = <RunningPresentationGroup>[];
  var i = 0;
  while (i < steps.length) {
    final work = steps[i];
    if (work.role != RunningStepRole.work ||
        i + 1 >= steps.length ||
        steps[i + 1].role != RunningStepRole.recovery) {
      groups.add(RunningPresentationGroup([work]));
      i++;
      continue;
    }
    final recovery = steps[i + 1];
    var end = i, count = 0;
    while (end < steps.length && _sameStep(work, steps[end])) {
      count++;
      end++;
      if (end < steps.length && _sameStep(recovery, steps[end])) {
        end++;
      } else {
        break;
      }
    }
    if (count < 2) {
      groups.add(RunningPresentationGroup([work]));
      i++;
    } else {
      groups.add(
        RunningPresentationGroup(
          List.unmodifiable(steps.sublist(i, end)),
          repetitions: count,
        ),
      );
      i = end;
    }
  }
  return groups;
}

String runDuration(RunningDuration d) => switch (d.kind) {
  RunningDurationKind.distance => '${d.millimetres! / 1000000} km',
  RunningDurationKind.manualLap => 'Until lap confirmation',
  RunningDurationKind.time =>
    d.milliseconds! % 60000 == 0
        ? '${d.milliseconds! ~/ 60000} min'
        : d.milliseconds! < 60000
        ? '${d.milliseconds! ~/ 1000} sec'
        : '${d.milliseconds! ~/ 60000} min ${(d.milliseconds! % 60000) ~/ 1000} sec',
};

String runTarget(RunningTarget target) => switch (target.kind) {
  RunningTargetKind.none => 'Coached effort',
  RunningTargetKind.heartRateZoneRef => 'Personalised Zone 2 heart rate',
  RunningTargetKind.qualityPaceRef =>
    target.qualityCategory == 'threshold'
        ? 'Personalised threshold pace'
        : 'Personalised current 10K pace',
  RunningTargetKind.rpeRange =>
    'RPE ${target.rpeCr10Low}–${target.rpeCr10High}/10',
  RunningTargetKind.rpe => 'RPE ${target.rpeCr10}/10',
  RunningTargetKind.heartRate => '${target.heartRateBpm} bpm',
  RunningTargetKind.heartRateRange =>
    '${target.heartRateBpmLow}–${target.heartRateBpmHigh} bpm',
  _ => 'See the retained target in Advanced tools',
};
