import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:cohort_platform/domain/hyrox_base/base_personalisation.dart';
import 'package:cohort_platform/internal_review/hyrox_base/base_review_controller.dart';

BaseBenchmark benchmark(
  BaseMetric metric,
  String value,
  BaseInputUnit unit, {
  String id = 'benchmark',
  String athlete = 'synthetic-a',
  String date = '2026-10-22',
}) => BaseBenchmark.enter(
  id: id,
  athleteId: athlete,
  metric: metric,
  value: value,
  unit: unit,
  testDate: date,
  sourceType: BaseSourceType.syntheticExample,
  sourceReference: 'local:$id',
);
BaseSessionPreview calculate({
  int week = 1,
  String run = '2400',
  String row = '420',
  String squat = '100',
  int? increment = 2500,
}) => const BasePersonalisationCalculator().preview(
  athleteId: 'synthetic-a',
  week: week,
  incrementGrams: increment,
  selected: {
    BaseMetric.run10km: benchmark(
      BaseMetric.run10km,
      run,
      BaseInputUnit.seconds,
      id: 'run',
    ),
    BaseMetric.row2km: benchmark(
      BaseMetric.row2km,
      row,
      BaseInputUnit.seconds,
      id: 'row',
    ),
    BaseMetric.backSquat5rm: benchmark(
      BaseMetric.backSquat5rm,
      squat,
      BaseInputUnit.kilograms,
      id: 'squat',
    ),
  },
);
void select(BaseReviewController c, BaseBenchmark b) {
  expect(c.enter(b), true);
  expect(c.acceptSelection(c.proposeSelection(b.id)!), true);
}

void main() {
  test('rule trace pins exact retained approved brief bytes', () {
    final bytes = File(
      'docs/checkpoints/hyrox_base_personalisation/FOUNDER_BRIEF.txt',
    ).readAsBytesSync();
    expect(
      BaseSessionPreview.approvedBriefSha256,
      sha256.convert(bytes).toString(),
    );
    expect(
      calculate().toJson()['approved_brief_sha256'],
      BaseSessionPreview.approvedBriefSha256,
    );
    expect(calculate().run.pace!.unit, BasePaceUnit.millisecondsPerKilometre);
    expect(calculate().row.pace!.unit, BasePaceUnit.millisecondsPer500Metres);
  });

  test(
    '40/60-minute athletes have distinct exact pace windows in every week',
    () {
      const factors = [
        (100, 105),
        (100, 105),
        (102, 107),
        (100, 105),
        (100, 105),
        (102, 107),
        (103, 108),
        (100, 105),
      ];
      for (var week = 1; week <= 8; week++) {
        for (final seconds in [2400, 3600]) {
          final p = calculate(week: week, run: '$seconds');
          expect(
            p.run.pace!.faster.value,
            seconds / 10 * factors[week - 1].$1 / 100 * 1000,
          );
          expect(
            p.run.pace!.slower.value,
            seconds / 10 * factors[week - 1].$2 / 100 * 1000,
          );
          expect(p.run.pace!.faster.value, lessThan(p.run.pace!.slower.value));
        }
      }
      expect(calculate().run.pace!.label, '4:00.0–4:12.0 /km');
      expect(calculate(run: '3600').run.pace!.label, '6:00.0–6:18.0 /km');
    },
  );
  test(
    'dedicated row bounds including W4 and W8 override repetition duration',
    () {
      const offsets = [
        (10, 15),
        (10, 15),
        (12, 18),
        (18, 23),
        (10, 15),
        (10, 15),
        (12, 18),
        (15, 20),
      ];
      for (var week = 1; week <= 8; week++) {
        for (final row in [420, 540]) {
          final p = calculate(week: week, row: '$row');
          expect(
            p.row.pace!.faster.value,
            (row / 4 + offsets[week - 1].$1) * 1000,
          );
          expect(
            p.row.pace!.slower.value,
            (row / 4 + offsets[week - 1].$2) * 1000,
          );
        }
      }
    },
  );
  test(
    'authored run, row, deload, consolidation and squat arrays are exact',
    () {
      const run = [
        (4, 4),
        (5, 4),
        (4, 6),
        (4, 4),
        (5, 5),
        (4, 7),
        (3, 10),
        (4, 5),
      ];
      const easy = [
        (45, 60),
        (45, 65),
        (50, 65),
        (45, 60),
        (50, 65),
        (50, 70),
        (55, 70),
        (45, 60),
      ];
      const long = [
        (50, 70),
        (55, 75),
        (60, 80),
        (55, 70),
        (60, 80),
        (65, 80),
        (65, 80),
        (55, 75),
      ];
      const row = [
        (6, 2, 90),
        (7, 2, 90),
        (5, 3, 90),
        (4, 2, 90),
        (6, 2, 75),
        (7, 2, 75),
        (5, 3, 75),
        (4, 2, 90),
      ];
      const strength = [
        (3, 8, 80000, '3'),
        (3, 8, 82500, '2–3'),
        (4, 6, 87500, '2'),
        (2, 6, 70000, '4'),
        (4, 6, 87500, '3'),
        (4, 5, 90000, '2–3'),
        (4, 4, 95000, '2'),
        (2, 5, 75000, '3–4'),
      ];
      for (var i = 0; i < 8; i++) {
        final p = calculate(week: i + 1, increment: 500);
        final r = p.rule;
        expect((r.runReps, r.runMinutes), run[i]);
        expect((r.easyMin, r.easyMax), easy[i]);
        expect((r.longMin, r.longMax), long[i]);
        expect((r.rowReps, r.rowMinutes, r.rowRecovery), row[i]);
        expect((r.squatSets, r.squatReps, p.squat.grams, r.rir), strength[i]);
        for (final interval in [p.run, p.row]) {
          expect(interval.steps.length, interval.repetitions * 2 - 1);
          expect(interval.steps.last.kind, BaseStepKind.work);
          expect(
            interval.steps.where((s) => s.kind == BaseStepKind.recovery).length,
            interval.repetitions - 1,
          );
          expect(
            interval.steps
                .where((s) => s.kind == BaseStepKind.recovery)
                .every((s) => s.pace == null),
            true,
          );
        }
      }
    },
  );
  test('squat nearest-increment ties round down, no guessed increment', () {
    expect(
      calculate(week: 2, increment: 5000).squat.grams,
      80000,
    ); // 82.5 -> 80, tie
    expect(
      calculate(week: 2, squat: '100.001', increment: 5000).squat.grams,
      85000,
    );
    expect(
      calculate(week: 2, squat: '99.999', increment: 5000).squat.grams,
      80000,
    );
    expect(
      calculate(increment: null).squat.unavailableReason,
      'missing_equipment_increment_use_authored_rir',
    );
    expect(
      calculate(squat: '0.001').squat.unavailableReason,
      'rounded_load_not_positive_use_authored_rir',
    );
    expect(() => calculate(increment: 0), throwsFormatException);
    expect(() => calculate(increment: -1), throwsFormatException);
  });
  test(
    'typed conversion is exact and rejects precision loss, NaN, infinity, negative, zero',
    () {
      expect(
        benchmark(
          BaseMetric.run10km,
          '40',
          BaseInputUnit.minutes,
        ).canonicalValue,
        2400000,
      );
      expect(
        benchmark(
          BaseMetric.row2km,
          '420.123',
          BaseInputUnit.seconds,
        ).canonicalValue,
        420123,
      );
      expect(
        benchmark(
          BaseMetric.backSquat5rm,
          '100.125',
          BaseInputUnit.kilograms,
        ).canonicalValue,
        100125000000,
      );
      expect(
        benchmark(
          BaseMetric.backSquat5rm,
          '100000',
          BaseInputUnit.pounds,
        ).canonicalValue,
        45359237000000,
      );
      expect(
        benchmark(
          BaseMetric.backSquat5rm,
          '100',
          BaseInputUnit.pounds,
        ).canonicalValue,
        45359237000,
      );
    },
  );
  test(
    'zero strict pull-ups valid; fractional counts and unrelated units refuse',
    () {
      expect(
        benchmark(
          BaseMetric.strictPullUps,
          '0',
          BaseInputUnit.count,
        ).canonicalValue,
        0,
      );
      expect(
        () => benchmark(BaseMetric.strictPullUps, '1.5', BaseInputUnit.count),
        throwsFormatException,
      );
      expect(
        () => benchmark(BaseMetric.run10km, '40', BaseInputUnit.kilograms),
        throwsFormatException,
      );
      for (final text in [
        'NaN',
        'Infinity',
        '-1',
        '0',
        '1e3',
        '',
        '2400.0001',
        '9999999999.999999',
      ]) {
        expect(
          () => benchmark(BaseMetric.run10km, text, BaseInputUnit.seconds),
          throwsFormatException,
          reason: text,
        );
      }
    },
  );
  test('invalid dates and provenance refuse; no freshness cutoff', () {
    for (final date in ['2026-02-30', '2026-13-01', 'x', '2026-1-01']) {
      expect(
        () => benchmark(
          BaseMetric.run10km,
          '2400',
          BaseInputUnit.seconds,
          date: date,
        ),
        throwsFormatException,
      );
    }
    expect(
      benchmark(
        BaseMetric.run10km,
        '2400',
        BaseInputUnit.seconds,
        date: '2000-01-01',
      ).testDate,
      '2000-01-01',
    );
    expect(
      () =>
          benchmark(BaseMetric.run10km, '2400', BaseInputUnit.seconds, id: ''),
      throwsFormatException,
    );
  });
  test('missing inputs are unavailable; press never supplies squat', () {
    final p = const BasePersonalisationCalculator().preview(
      athleteId: 'synthetic-a',
      week: 1,
      selected: {
        BaseMetric.strictPress5rm: benchmark(
          BaseMetric.strictPress5rm,
          '60',
          BaseInputUnit.kilograms,
        ),
      },
    );
    expect(p.run.pace, isNull);
    expect(p.row.pace, isNull);
    expect(p.squat.grams, isNull);
    expect(
      p.squat.unavailableReason,
      'missing_back_squat_5rm_use_authored_rir',
    );
    expect(
      () => const BasePersonalisationCalculator().preview(
        athleteId: 'synthetic-a',
        week: 1,
        selected: {
          BaseMetric.backSquat5rm: benchmark(
            BaseMetric.strictPress5rm,
            '60',
            BaseInputUnit.kilograms,
          ),
        },
      ),
      throwsFormatException,
    );
  });
  test('benchmark owner is exact; invalid weeks refuse', () {
    expect(
      () => const BasePersonalisationCalculator().preview(
        athleteId: 'foreign',
        week: 1,
        selected: {
          BaseMetric.run10km: benchmark(
            BaseMetric.run10km,
            '2400',
            BaseInputUnit.seconds,
          ),
        },
      ),
      throwsFormatException,
    );
    for (final week in [0, 9]) {
      expect(() => calculate(week: week), throwsFormatException);
    }
    expect(() => BaseReviewController('real-athlete'), throwsFormatException);
  });
  test('identity/source/rule trace retained and actuals remain absent', () {
    final p = calculate();
    final json = p.toJson();
    expect(json['rule_version'], BaseSessionPreview.ruleVersion);
    expect((json['run_quality'] as Map)['actual'], isNull);
    expect(
      (json['run_quality'] as Map)['benchmark_digest'],
      p.run.benchmark!.digest,
    );
    expect(p.digest, calculate().digest);
    expect(p.digest, isNot(calculate(run: '3600').digest));
  });
  test(
    'replacement acceptance changes future only and completion is not progression',
    () async {
      final c = BaseReviewController('synthetic-a');
      select(
        c,
        benchmark(
          BaseMetric.backSquat5rm,
          '100',
          BaseInputUnit.kilograms,
          id: 'old',
        ),
      );
      c.configure(week: 1, incrementGrams: 2500);
      expect(await c.review(), true);
      final old = c.start('w1')!;
      expect(old.prescription.squat.grams, 80000);
      final replacement = benchmark(
        BaseMetric.backSquat5rm,
        '120',
        BaseInputUnit.kilograms,
        id: 'new',
      );
      expect(c.enter(replacement), true);
      final proposal = c.proposeSelection('new')!;
      expect(c.selected[BaseMetric.backSquat5rm]!.id, 'old');
      expect(c.start('new-while-pending'), isNull);
      c.cancelSelection();
      expect(c.acceptSelection(proposal), false);
      expect(c.selected[BaseMetric.backSquat5rm]!.id, 'old');
      expect(c.acceptSelection(c.proposeSelection('new')!), true);
      expect(await c.review(), true);
      expect(c.preview!.squat.grams, 95000);
      expect(c.start('w1'), same(old));
      expect(old.prescription.squat.grams, 80000);
      final future = c.start('future')!;
      expect(future.prescription.squat.grams, 95000);
      expect(c.complete('w1', actualSquatGrams: 77500), true);
      expect(c.workouts['w1']!.prescription, same(old.prescription));
      expect(c.workouts['w1']!.actualSquatGrams, 77500);
      expect(c.complete('w1', actualSquatGrams: 90000), false);
      expect(c.preview, same(future.prescription));
      expect(c.week, 1);
      expect(c.selected[BaseMetric.backSquat5rm]!.id, 'new');
    },
  );
  test(
    'conflicting benchmark IDs, foreign entries and stale proposals fail closed',
    () {
      final c = BaseReviewController('synthetic-a');
      final b = benchmark(BaseMetric.run10km, '2400', BaseInputUnit.seconds);
      expect(c.enter(b), true);
      final proposal = c.proposeSelection(b.id)!;
      c.configure(week: 2);
      expect(c.acceptSelection(proposal), false);
      expect(
        c.enter(benchmark(BaseMetric.run10km, '3600', BaseInputUnit.seconds)),
        false,
      );
      expect(c.entries[b.id]!.digest, b.digest);
      expect(
        c.enter(
          benchmark(
            BaseMetric.run10km,
            '3600',
            BaseInputUnit.seconds,
            id: 'foreign',
            athlete: 'synthetic-b',
          ),
        ),
        false,
      );
      expect(c.selected, isEmpty);
    },
  );
  test(
    'async results after selection, config, invalid input or dispose never publish',
    () async {
      for (final invalidate in <void Function(BaseReviewController)>[
        (c) => c.configure(week: 2),
        (c) => select(
          c,
          benchmark(
            BaseMetric.run10km,
            '3600',
            BaseInputUnit.seconds,
            id: 'new',
          ),
        ),
        (c) => c.rejectInput('invalid'),
        (c) => c.dispose(),
      ]) {
        final completer = Completer<BaseSessionPreview>();
        final c = BaseReviewController(
          'synthetic-a',
          builder: (_, _, _, _) => completer.future,
        );
        final future = c.review();
        invalidate(c);
        completer.complete(
          const BasePersonalisationCalculator().preview(
            athleteId: 'synthetic-a',
            week: 1,
            selected: {},
          ),
        );
        expect(await future, false);
        expect(c.preview, isNull);
        expect(c.busy, false);
      }
    },
  );
  test(
    'out-of-order review and late failure cannot replace newest state',
    () async {
      final requests = <Completer<BaseSessionPreview>>[];
      final c = BaseReviewController(
        'synthetic-a',
        builder: (_, _, _, _) {
          final p = Completer<BaseSessionPreview>();
          requests.add(p);
          return p.future;
        },
      );
      final first = c.review(), second = c.review();
      final expected = const BasePersonalisationCalculator().preview(
        athleteId: 'synthetic-a',
        week: 1,
        selected: {},
      );
      requests[1].complete(expected);
      expect(await second, true);
      requests[0].completeError(StateError('late'));
      expect(await first, false);
      expect(c.preview, same(expected));
      expect(c.error, isNull);
    },
  );
  test(
    'mismatched worker scope refuses and collection views are immutable',
    () async {
      final c = BaseReviewController(
        'synthetic-a',
        builder: (_, _, _, _) async => calculate(week: 8),
      );
      expect(await c.review(), false);
      expect(c.preview, isNull);
      expect(c.error, isNotNull);
      expect(() => c.entries.clear(), throwsUnsupportedError);
      expect(() => c.selected.clear(), throwsUnsupportedError);
      expect(() => c.workouts.clear(), throwsUnsupportedError);
      expect(() => calculate().run.steps.clear(), throwsUnsupportedError);
    },
  );
  test(
    'exact microgram pounds conversion reaches deterministic gram increment target',
    () {
      final p = const BasePersonalisationCalculator().preview(
        athleteId: 'synthetic-a',
        week: 1,
        incrementGrams: 2500,
        selected: {
          BaseMetric.backSquat5rm: benchmark(
            BaseMetric.backSquat5rm,
            '220',
            BaseInputUnit.pounds,
          ),
        },
      );
      expect(p.squat.grams, 80000);
      final lower = benchmark(
        BaseMetric.run10km,
        '0.001',
        BaseInputUnit.seconds,
      );
      expect(lower.canonicalValue, 1);
      expect(
        () =>
            benchmark(BaseMetric.run10km, '1000000.001', BaseInputUnit.seconds),
        throwsFormatException,
      );
      expect(
        () =>
            benchmark(BaseMetric.strictPullUps, '0.0001', BaseInputUnit.count),
        throwsFormatException,
      );
    },
  );
  test(
    'review failure can retry; dispose and invalid configuration cannot revive stale preview',
    () async {
      var calls = 0;
      final c = BaseReviewController(
        'synthetic-a',
        builder: (athlete, week, selected, increment) async {
          if (calls++ == 0) throw StateError('temporary worker failure');
          return const BasePersonalisationCalculator().preview(
            athleteId: athlete,
            week: week,
            selected: selected,
            incrementGrams: increment,
          );
        },
      );
      expect(await c.review(), false);
      expect(c.preview, isNull);
      expect(c.busy, false);
      expect(await c.review(), true);
      expect(c.error, isNull);
      c.configure(week: 9);
      expect(c.preview, isNull);
      expect(await c.review(), false);
      expect(c.start('invalid'), isNull);
      c.dispose();
      expect(await c.review(), false);
      expect(c.start('disposed'), isNull);
    },
  );
}
