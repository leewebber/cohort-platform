import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:cohort_platform/domain/running_workout/running_workout.dart';
import 'package:cohort_platform/domain/running_workout/fit_workout_representation.dart';
import 'package:cohort_platform/features/programme/models/programme_execution_context.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'fixtures/m25/frozen_fixture.dart';

void main() {
  test(
    'frozen scope/rules/source retained; raw FIT repeats/durations/targets are exact',
    () {
      final f = FrozenFitFixture();
      final e = f.export();
      final fields = e.json['fit_fields'] as Map;
      expect(e.scope['occurrence_id'], f.occurrence);
      expect(e.json['accepted_snapshot_sha256'], f.retainedDigest);
      expect(
        e.json['prescription']['accepted_snapshot']['quality']['rule_id'],
        'alpha_manual_threshold_pm2_v1',
      );
      final rows = fields['workout_steps'] as List;
      expect(fields['binary_fit'], false);
      expect(rows.map((r) => r['duration_type']), [0, 0, 0, 6, 0]);
      expect(rows.map((r) => r['duration_value']), [
        300000,
        120000,
        60000,
        1,
        300000,
      ]);
      expect(rows[3]['target_value'], 3);
      expect(rows.map((r) => r['intensity']), [2, 0, 4, null, 3]);
      expect(rows[1]['target_type'], 0);
      expect(rows[1]['target_value'], 0);
      expect(rows[1]['custom_target_value_low'], 3267);
      expect(rows[1]['custom_target_value_high'], 3402);
      expect(rows[2]['target_type'], 1);
      expect(rows[2]['custom_target_value_low'], 230);
      expect(rows[2]['custom_target_value_high'], 245);
      expect(fields['total_duration_milliseconds'], 1140000);
      expect((fields['expanded_source_steps'] as List).length, 8);
      expect(
        e.json['prescription']['resolved_body']['steps'][1]['steps'][0]['target'],
        {'kind': 'pace_range', 'low': 294000, 'high': 306000},
      );
      expect(
        e.json['prescription']['source_body']['steps'][1]['steps'][0]['target']['kind'],
        'alpha_quality_pace_v1',
      );
    },
  );
  test('later input edits cannot mutate exported frozen prescription', () {
    final f = FrozenFitFixture();
    final original = f.export();
    final bytes = jsonEncode(original.json);
    final digest = original.digest;
    (f.snapshot['quality'] as Map)['input']['manual_seconds_per_km'] = 400;
    expect(jsonEncode(original.json), bytes);
    expect(original.digest, digest);
    expect(
      () => original.scope['athlete_id'] = 'other',
      throwsUnsupportedError,
    );
    expect(
      () =>
          original.json['prescription']['accepted_snapshot']['zone2']['lower_bpm'] =
              120,
      throwsUnsupportedError,
    );
    expect(() => f.export(), throwsA(isA<FitWorkoutRefusal>()));
  });
  test(
    'key ordering does not change exact frozen identity; changed input revision does',
    () {
      final a = FrozenFitFixture();
      final b = FrozenFitFixture();
      final reversed = Map<String, dynamic>.fromEntries(
        b.snapshot.entries.toList().reversed,
      );
      expect(
        b.export(executionPlan: b.plan(admission: reversed)).digest,
        a.export().digest,
      );
      expect(
        FrozenFitFixture(inputRevision: 'revision-2').export().digest,
        isNot(a.export().digest),
      );
    },
  );
  test('new version and occurrence remain different immutable exports', () {
    final old = FrozenFitFixture().export();
    final next = FrozenFitFixture(
      version: 'version-2',
      occurrence: 'occurrence-2',
    ).export();
    expect(next.digest, isNot(old.digest));
    expect(old.scope['programme_version_id'], 'fixture-version-1');
  });
  test(
    'foreign owner/session/version, changed source and preview cannot export',
    () {
      final f = FrozenFitFixture();
      expect(() => f.export(actor: 'foreign'), throwsFormatException);
      expect(() => f.export(session: 18), throwsA(isA<FitWorkoutRefusal>()));
      final other = FrozenFitFixture(version: 'other');
      expect(() => f.export(scope: other.context), throwsFormatException);
      final changed = RunningWorkout(
        workoutId: f.source.workoutId,
        steps: [
          const RunningAtomicStep(
            stepId: 'other',
            role: RunningStepRole.work,
            duration: RunningDuration.time(1140000),
          ),
        ],
      );
      expect(
        () => f.export(executionPlan: f.plan(body: changed)),
        throwsFormatException,
      );
      final preview = Map<String, dynamic>.from(f.snapshot)
        ..remove('accepted_at');
      expect(
        () => f.export(
          executionPlan: f.plan(admission: preview),
          digest: fitManifestDigest(preview),
        ),
        throwsA(isA<FitWorkoutRefusal>()),
      );
      expect(
        () => f.export(scope: f.context.copyWith(occurrenceId: 'other')),
        throwsFormatException,
      );
    },
  );
  test(
    'frozen evaluation remains valid without reading newer benchmark state',
    () {
      final f = FrozenFitFixture();
      expect(
        f.export().json['prescription']['accepted_snapshot']['accepted_at'],
        '2026-10-28T00:00:00Z',
      );
      expect(f.export().digest, f.export().digest);
      // No current benchmark/date/provider store is an input to this exporter.
    },
  );
  test('existing quality fixture RPE is refused, not silently stripped', () {
    final source = const RunningWorkoutCodec().decode(
      File(
        'test/session/fixtures/quality_admission/quality_run.json',
      ).readAsStringSync(),
    );
    expect(
      () => const TimedFitWorkoutConverter().convert(source),
      throwsA(isA<FitWorkoutRefusal>()),
    );
  });
  test('changed version and invented rule refuse before conversion', () {
    final f = FrozenFitFixture();
    final other = FrozenFitFixture(version: 'other');
    expect(
      () => f.export(executionPlan: other.plan(), digest: other.retainedDigest),
      throwsFormatException,
    );
    final badRule = jsonDecode(jsonEncode(f.snapshot)) as Map<String, dynamic>;
    badRule['quality']['rule_id'] = 'invented-rule';
    expect(
      () => f.export(
        executionPlan: f.plan(admission: badRule),
        digest: fitManifestDigest(badRule),
      ),
      throwsFormatException,
    );
  });
  test('v3, nonfixed, adapted and multi-body scope are explicitly refused', () {
    final f = FrozenFitFixture();
    ProgrammeExecutionContext context({
      int schema = 2,
      String effective = 'fixture-protocol',
      String? occurrence = 'fixture-occurrence-1',
    }) => ProgrammeExecutionContext(
      assignmentId: f.context.assignmentId,
      programmeVersionId: f.version,
      sessionSlotId: 'fixture-slot',
      weekNumber: 1,
      dayKey: 'day_1',
      sessionOrder: 1,
      plannedProtocolId: 'fixture-protocol',
      effectiveProtocolId: effective,
      occurrenceId: occurrence,
      packageSchemaVersion: schema,
      packageContentHash: 'a' * 64,
    );
    for (final c in [
      context(schema: 3),
      context(occurrence: null),
      context(effective: 'adapted'),
    ]) {
      expect(
        () => f.export(scope: c),
        throwsA(
          isA<FitWorkoutRefusal>().having(
            (e) => e.code,
            'code',
            'unsupported_scope',
          ),
        ),
      );
    }
    final plan = f.plan();
    expect(
      () => f.export(
        executionPlan: SessionExecutionPlan(
          sessionId: plan.sessionId,
          sessionTitle: plan.sessionTitle,
          runningTargetAdmissionSnapshot: f.snapshot,
          blocks: [...plan.blocks, ...plan.blocks],
        ),
      ),
      throwsA(
        isA<FitWorkoutRefusal>().having(
          (e) => e.code,
          'code',
          'unsupported_scope',
        ),
      ),
    );
  });
  test('malformed accepted packet gives an actionable refusal', () {
    final f = FrozenFitFixture();
    final bad = jsonDecode(jsonEncode(f.snapshot)) as Map<String, dynamic>;
    bad['quality_targets'][0]['target'] = {
      'unit': 'seconds_per_kilometre',
      'lower': 294,
      'upper': 'invalid',
    };
    expect(
      () => f.export(
        executionPlan: f.plan(admission: bad),
        digest: fitManifestDigest(bad),
      ),
      throwsFormatException,
    );
  });
  const converter = TimedFitWorkoutConverter();
  RunningWorkout one({
    RunningDuration duration = const RunningDuration.time(1000),
    RunningTarget target = const RunningTarget.none(),
    RunningStepRole role = RunningStepRole.work,
  }) => RunningWorkout(
    workoutId: 'fixture-one',
    steps: [
      RunningAtomicStep(
        stepId: 'step',
        role: role,
        duration: duration,
        target: target,
      ),
    ],
  );
  test('independent published pace vector and open target', () {
    final r =
        (converter.convert(
                  one(
                    target: const RunningTarget.paceRange(
                      low: 300000,
                      high: 330000,
                    ),
                  ),
                )['workout_steps']
                as List)
            .single;
    expect(r['custom_target_value_low'], 3030);
    expect(r['custom_target_value_high'], 3334);
    expect(
      (converter.convert(one())['workout_steps'] as List).single['target_type'],
      2,
    );
  });
  for (final duration in [
    const RunningDuration.time(1),
    const RunningDuration.time(0),
    const RunningDuration.time(4294968000),
    const RunningDuration.distance(1000000),
    const RunningDuration.manualLap(),
  ]) {
    test(
      'refuses unsupported duration ${duration.kind}/${duration.milliseconds}',
      () {
        expect(
          () => converter.convert(one(duration: duration)),
          throwsA(isA<FitWorkoutRefusal>()),
        );
      },
    );
  }
  for (final target in [
    const RunningTarget.pace(300000),
    const RunningTarget.heartRate(140),
    const RunningTarget.rpe(2),
    const RunningTarget.rpeRange(low: 2, high: 4),
    const RunningTarget.power(200),
    const RunningTarget.powerRange(low: 200, high: 250),
    const RunningTarget.cadenceRange(low: 170, high: 180),
    const RunningTarget.heartRateZoneRef('unresolved'),
    const RunningTarget.qualityPaceRef('threshold'),
    const RunningTarget.heartRateRange(low: 130, high: 251),
    const RunningTarget.paceRange(low: 1000000001, high: 1000000002),
  ]) {
    test('refuses unsupported/unrepresentable target ${target.kind}', () {
      expect(
        () => converter.convert(one(target: target)),
        throwsA(isA<FitWorkoutRefusal>()),
      );
    });
  }
  test(
    'roles rest, no invented final recovery and original labels preserved',
    () {
      final source = RunningWorkout(
        workoutId: 'fixture',
        steps: [
          const RunningAtomicStep(
            stepId: 'rest',
            role: RunningStepRole.rest,
            duration: RunningDuration.time(1000),
            label: 'Keep this label',
            notes: 'Exact note',
          ),
        ],
      );
      final row = (converter.convert(source)['workout_steps'] as List).single;
      expect(row['intensity'], 1);
      expect(row['wkt_step_name'], 'Keep this label');
      expect(row['notes'], 'Exact note');
      expect(
        () => converter.convert(one(role: RunningStepRole.open)),
        throwsA(isA<FitWorkoutRefusal>()),
      );
    },
  );
  test('repeat count and 512 expanded phase admission are bounded', () {
    RunningWorkout many(int count, int children) => RunningWorkout(
      workoutId: 'fixture',
      steps: [
        RunningRepeatGroup(
          groupId: 'repeat',
          count: count,
          steps: List.generate(
            children,
            (i) => RunningAtomicStep(
              stepId: 'step-$i',
              role: RunningStepRole.work,
              duration: const RunningDuration.time(1000),
            ),
          ),
        ),
      ],
    );
    expect(
      (converter.convert(many(32, 16))['expanded_source_steps'] as List).length,
      512,
    );
    expect(
      () => converter.convert(many(32, 17)),
      throwsA(isA<FitWorkoutRefusal>()),
    );
    expect(
      () => converter.convert(many(33, 1)),
      throwsA(isA<FitWorkoutRefusal>()),
    );
  });
}
