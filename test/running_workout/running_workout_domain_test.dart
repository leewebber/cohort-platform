import 'package:cohort_platform/domain/running_workout/running_workout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const codec = RunningWorkoutCodec();
  const validator = RunningWorkoutValidator();

  RunningWorkout workout({
    String id = 'rw1:test',
    List<RunningWorkoutNode>? steps,
    RunningWorkoutProvenance? provenance,
    String? notes,
  }) {
    return RunningWorkout(
      workoutId: id,
      notes: notes,
      provenance: provenance,
      steps:
          steps ??
          [
            const RunningAtomicStep(
              stepId: 'rw1:test:s:0',
              role: RunningStepRole.work,
              duration: RunningDuration.time(60000),
            ),
          ],
    );
  }

  test('schema version is 1 and value equality holds', () {
    final a = workout();
    final b = workout();
    expect(a.schemaVersion, 1);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(
      a,
      isNot(
        workout(
          steps: [
            const RunningAtomicStep(
              stepId: 'rw1:test:s:0',
              role: RunningStepRole.warmUp,
              duration: RunningDuration.time(60000),
            ),
          ],
        ),
      ),
    );
  });

  test('JSON round-trip is equivalent and byte-stable', () {
    final original = RunningWorkout(
      workoutId: 'rw1:stable',
      title: 'Steady',
      intent: 'Aerobic',
      notes: 'Conversational',
      provenance: const RunningWorkoutProvenance(
        kind: RunningWorkoutProvenanceKind.projected,
        sourceKind: 'timer_configuration',
        sourceFormat: 'steady_state',
        idDerivation: 'sha256_16',
      ),
      steps: const [
        RunningAtomicStep(
          stepId: 'rw1:stable:s:0',
          role: RunningStepRole.work,
          duration: RunningDuration.time(3600000),
        ),
      ],
    );
    final first = codec.encode(original);
    final second = codec.encode(codec.decode(first));
    expect(second, first);
    expect(codec.decode(first), original);
  });

  test('unknown schema and discriminators fail closed', () {
    expect(
      () => codec.decode('{"schema_version":2,"workout_id":"x","steps":[]}'),
      throwsA(
        isA<RunningWorkoutCodecException>().having(
          (error) => error.code,
          'code',
          'unsupported_schema_version',
        ),
      ),
    );
    expect(
      () => codec.decode(
        '{"schema_version":1,"workout_id":"x","steps":[{"kind":"mystery"}]}',
      ),
      throwsA(
        isA<RunningWorkoutCodecException>().having(
          (error) => error.code,
          'code',
          'unknown_step_kind',
        ),
      ),
    );
    expect(
      () => codec.decode(
        '{"schema_version":1,"workout_id":"x","secret":true,"steps":[]}',
      ),
      throwsA(
        isA<RunningWorkoutCodecException>().having(
          (error) => error.code,
          'code',
          'unknown_field',
        ),
      ),
    );
  });

  test('all atomic roles and duration kinds encode', () {
    const cases = <(RunningStepRole, RunningDuration)>[
      (RunningStepRole.warmUp, RunningDuration.time(120000)),
      (RunningStepRole.work, RunningDuration.distance(1000000)),
      (RunningStepRole.recovery, RunningDuration.time(60000)),
      (RunningStepRole.rest, RunningDuration.time(30000)),
      (RunningStepRole.coolDown, RunningDuration.time(180000)),
      (RunningStepRole.open, RunningDuration.manualLap()),
    ];
    for (final entry in cases) {
      final model = workout(
        steps: [
          RunningAtomicStep(
            stepId: 'rw1:test:${entry.$1.name}',
            role: entry.$1,
            duration: entry.$2,
          ),
        ],
      );
      expect(codec.decode(codec.encode(model)), model);
      expect(validator.validate(model).isValid, isTrue);
    }
  });

  test('all typed targets encode and validate ranges', () {
    final targets = <RunningTarget>[
      const RunningTarget.none(),
      const RunningTarget.pace(240000),
      const RunningTarget.paceRange(low: 220000, high: 260000),
      const RunningTarget.heartRate(140),
      const RunningTarget.heartRateRange(low: 130, high: 150),
      const RunningTarget.heartRateZoneRef('zone_ref_a'),
      const RunningTarget.power(200),
      const RunningTarget.powerRange(low: 180, high: 220),
      const RunningTarget.cadenceRange(low: 160, high: 180),
      const RunningTarget.rpe(5),
      const RunningTarget.rpeRange(low: 4, high: 6),
    ];
    for (final target in targets) {
      final model = workout(
        steps: [
          RunningAtomicStep(
            stepId: 'rw1:test:${target.kind.name}',
            role: RunningStepRole.work,
            duration: const RunningDuration.time(60000),
            target: target,
          ),
        ],
      );
      expect(codec.decode(codec.encode(model)), model);
      expect(validator.validate(model).isValid, isTrue);
    }
  });

  test('invalid values fail validation with stable codes', () {
    expect(
      validator.validate(workout(id: '')).errors.map((issue) => issue.code),
      contains('missing_workout_id'),
    );
    expect(
      validator
          .validate(const RunningWorkout(workoutId: 'rw1:empty', steps: []))
          .errors
          .map((issue) => issue.code),
      contains('empty_steps'),
    );
    expect(
      validator
          .validate(
            workout(
              steps: const [
                RunningAtomicStep(
                  stepId: 'dup',
                  role: RunningStepRole.work,
                  duration: RunningDuration.time(1000),
                ),
                RunningAtomicStep(
                  stepId: 'dup',
                  role: RunningStepRole.recovery,
                  duration: RunningDuration.time(1000),
                ),
              ],
            ),
          )
          .errors
          .map((issue) => issue.code),
      contains('duplicate_id'),
    );
    expect(
      validator
          .validate(
            workout(
              steps: const [
                RunningAtomicStep(
                  stepId: 'rw1:test:s:bad',
                  role: RunningStepRole.work,
                  duration: RunningDuration.time(0),
                ),
              ],
            ),
          )
          .errors
          .map((issue) => issue.code),
      contains('invalid_duration'),
    );
    expect(
      validator
          .validate(
            workout(
              steps: const [
                RunningAtomicStep(
                  stepId: 'rw1:test:s:range',
                  role: RunningStepRole.work,
                  duration: RunningDuration.time(1000),
                  target: RunningTarget.paceRange(low: 300000, high: 200000),
                ),
              ],
            ),
          )
          .errors
          .map((issue) => issue.code),
      contains('invalid_target_range'),
    );
  });

  test('one-level repeat is valid and nested repeat is rejected', () {
    final valid = workout(
      steps: const [
        RunningRepeatGroup(
          groupId: 'rw1:test:g:0',
          count: 5,
          steps: [
            RunningAtomicStep(
              stepId: 'rw1:test:s:work',
              role: RunningStepRole.work,
              duration: RunningDuration.time(180000),
            ),
            RunningAtomicStep(
              stepId: 'rw1:test:s:recovery',
              role: RunningStepRole.recovery,
              duration: RunningDuration.time(120000),
            ),
          ],
        ),
      ],
    );
    expect(validator.validate(valid).isValid, isTrue);
    expect(codec.decode(codec.encode(valid)), valid);

    expect(
      () => codec.decode(
        '{"schema_version":1,"workout_id":"rw1:x","steps":[{"kind":"repeat","group_id":"g","count":2,"steps":[{"kind":"repeat","group_id":"inner","count":2,"steps":[]}]}]}',
      ),
      throwsA(
        isA<RunningWorkoutCodecException>().having(
          (error) => error.code,
          'code',
          'nested_repeat_group',
        ),
      ),
    );
  });

  test('ambiguous prose is a warning and not a numeric target', () {
    final model = workout(notes: 'Zone 2 conversational 1 km at 4:30/km');
    final result = validator.validate(model);
    expect(result.isValid, isTrue);
    expect(result.warnings.map((issue) => issue.code), contains('untyped_guidance'));
    expect(model.steps.whereType<RunningAtomicStep>().single.target.kind, RunningTargetKind.none);
  });

  test('formatted strings are not numerical authority', () {
    const duration = RunningDuration.time(60000);
    expect(duration.milliseconds, 60000);
    expect(duration.millimetres, isNull);
  });
}
