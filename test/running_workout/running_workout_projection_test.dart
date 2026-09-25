import 'package:cohort_platform/domain/running_workout/running_workout.dart';
import 'package:cohort_platform/models/timer_configuration.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const projector = RunningWorkoutProjector();

  test('steady-state projects one work time step without targets', () {
    final first = projector.project(
      format: WorkoutFormat.steadyState,
      configuration: const TimerConfiguration(durationSeconds: 3600),
      sourceRef: 'APOLLO-W5-TUE-R1:block:1',
      untypedGuidance: 'Zone 2',
    );
    final second = projector.project(
      format: WorkoutFormat.steadyState,
      configuration: const TimerConfiguration(durationSeconds: 3600),
      sourceRef: 'APOLLO-W5-TUE-R1:block:1',
      untypedGuidance: 'Zone 2',
    );
    expect(first.isSupported, isTrue);
    expect(first.workout, second.workout);
    final step = first.workout!.steps.single as RunningAtomicStep;
    expect(step.role, RunningStepRole.work);
    expect(step.duration, const RunningDuration.time(3600000));
    expect(step.target.kind, RunningTargetKind.none);
    expect(first.warnings.map((issue) => issue.code), contains('untyped_guidance'));
  });

  test('intervals project one repeat group including final recovery', () {
    final result = projector.project(
      format: WorkoutFormat.intervals,
      configuration: const TimerConfiguration(
        workSeconds: 180,
        restSeconds: 90,
        rounds: 5,
      ),
      sourceRef: 'protocol:block:2',
    );
    expect(result.isSupported, isTrue);
    final group = result.workout!.steps.single as RunningRepeatGroup;
    expect(group.count, 5);
    expect(group.steps, hasLength(2));
    expect(group.steps[0].role, RunningStepRole.work);
    expect(group.steps[0].duration, const RunningDuration.time(180000));
    expect(group.steps[1].role, RunningStepRole.recovery);
    expect(group.steps[1].duration, const RunningDuration.time(90000));
    expect(group.steps.every((step) => step.target.kind == RunningTargetKind.none), isTrue);
  });

  test('zero restSeconds omits recovery and does not invent a target', () {
    final result = projector.project(
      format: WorkoutFormat.intervals,
      configuration: const TimerConfiguration(
        workSeconds: 60,
        restSeconds: 0,
        rounds: 3,
      ),
    );
    expect(result.isSupported, isTrue);
    final group = result.workout!.steps.single as RunningRepeatGroup;
    expect(group.steps, hasLength(1));
    expect(result.warnings.map((issue) => issue.code), contains('projected_without_recovery'));
  });

  test('unsupported timer shapes fail without a workout', () {
    for (final format in [
      WorkoutFormat.amrap,
      WorkoutFormat.emom,
      WorkoutFormat.forTime,
      WorkoutFormat.tabata,
      WorkoutFormat.rounds,
      WorkoutFormat.other,
      WorkoutFormat.none,
    ]) {
      final result = projector.project(
        format: format,
        configuration: const TimerConfiguration(durationSeconds: 600),
      );
      expect(result.isSupported, isFalse, reason: format.dbValue);
      expect(result.workout, isNull);
      expect(result.errors.single.code, 'unsupported_timer_shape');
    }
  });

  test('does not create distance steps or pace from labels', () {
    final result = projector.project(
      format: WorkoutFormat.steadyState,
      configuration: const TimerConfiguration(
        durationSeconds: 1200,
        timerNotes: 'run 1 km at threshold',
      ),
    );
    final step = result.workout!.steps.single as RunningAtomicStep;
    expect(step.duration.kind, RunningDurationKind.time);
    expect(step.target.kind, RunningTargetKind.none);
  });
}
