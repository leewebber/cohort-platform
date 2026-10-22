import 'dart:convert';

import 'package:crypto/crypto.dart';

enum BaseMetric { run10km, row2km, backSquat5rm, strictPress5rm, strictPullUps }

enum BaseInputUnit { seconds, minutes, milliseconds, kilograms, pounds, count }

enum BaseSourceType { knownResult, recordedResult, syntheticExample }

/// Local review data only. A declaration never attests a performed assessment.
class BaseBenchmark {
  BaseBenchmark._(
    this.id,
    this.athleteId,
    this.metric,
    this.canonicalValue,
    this.testDate,
    this.sourceType,
    this.sourceReference,
  );

  factory BaseBenchmark.enter({
    required String id,
    required String athleteId,
    required BaseMetric metric,
    required String value,
    required BaseInputUnit unit,
    required String testDate,
    required BaseSourceType sourceType,
    required String sourceReference,
  }) {
    if ([id, athleteId, sourceReference].any((s) => s.trim().isEmpty)) {
      throw const FormatException(
        'Benchmark identity, owner and source are required.',
      );
    }
    final date = DateTime.tryParse(testDate);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(testDate) ||
        date == null ||
        date.toIso8601String().substring(0, 10) != testDate) {
      throw const FormatException('Use a valid test date (YYYY-MM-DD).');
    }
    final allowed = switch (metric) {
      BaseMetric.run10km || BaseMetric.row2km => {
        BaseInputUnit.seconds,
        BaseInputUnit.minutes,
        BaseInputUnit.milliseconds,
      },
      BaseMetric.backSquat5rm || BaseMetric.strictPress5rm => {
        BaseInputUnit.kilograms,
        BaseInputUnit.pounds,
      },
      BaseMetric.strictPullUps => {BaseInputUnit.count},
    };
    if (!allowed.contains(unit)) {
      throw const FormatException('Unit does not match metric.');
    }
    final parsed = _decimal(value);
    final factor = switch (unit) {
      BaseInputUnit.seconds => const BaseFraction(1000, 1),
      BaseInputUnit.minutes => const BaseFraction(60000, 1),
      BaseInputUnit.kilograms => const BaseFraction(1000000000, 1),
      BaseInputUnit.pounds => const BaseFraction(453592370, 1),
      BaseInputUnit.milliseconds ||
      BaseInputUnit.count => const BaseFraction(1, 1),
    };
    final numerator = parsed.$1 * BigInt.from(factor.numerator);
    final denominator = parsed.$2 * BigInt.from(factor.denominator);
    // Preserve exact integer ms/micrograms; never round measured benchmark inputs.
    if (numerator % denominator != BigInt.zero) {
      throw const FormatException(
        'Value must resolve to whole milliseconds, micrograms or repetitions.',
      );
    }
    final exactCanonical = numerator ~/ denominator;
    final limit = switch (metric) {
      BaseMetric.backSquat5rm || BaseMetric.strictPress5rm => 1000000000000000,
      _ => 1000000000,
    };
    if (exactCanonical > BigInt.from(limit)) {
      throw const FormatException('Value exceeds the technical storage limit.');
    }
    final canonical = exactCanonical.toInt();
    if (canonical > limit ||
        canonical < 0 ||
        (canonical == 0 && metric != BaseMetric.strictPullUps)) {
      throw const FormatException(
        'Positive finite value required (zero strict pull-ups is valid); technical storage limit applies.',
      );
    }
    return BaseBenchmark._(
      id,
      athleteId,
      metric,
      canonical,
      testDate,
      sourceType,
      sourceReference,
    );
  }

  final String id, athleteId, testDate, sourceReference;
  final BaseMetric metric;
  final int canonicalValue;
  final BaseSourceType sourceType;
  String get canonicalUnit => switch (metric) {
    BaseMetric.run10km || BaseMetric.row2km => 'milliseconds',
    BaseMetric.backSquat5rm ||
    BaseMetric.strictPress5rm => 'micrograms_total_external_load',
    BaseMetric.strictPullUps => 'count',
  };
  Map<String, Object> toJson() => {
    'id': id,
    'athlete_id': athleteId,
    'metric': metric.name,
    'value': canonicalValue,
    'unit': canonicalUnit,
    'test_date': testDate,
    'source_type': sourceType.name,
    'source_reference': sourceReference,
    'claim': 'declared_result_only',
  };
  String get digest =>
      sha256.convert(utf8.encode(jsonEncode(toJson()))).toString();
}

(BigInt, BigInt) _decimal(String text) {
  if (!RegExp(r'^\d{1,10}(\.\d{1,6})?$').hasMatch(text)) {
    throw const FormatException(
      'Enter a finite nonnegative decimal, without exponent notation.',
    );
  }
  final parts = text.split('.');
  final decimals = parts.length == 2 ? parts[1] : '';
  final denominator = _power10(decimals.length);
  return (
    BigInt.parse(parts[0]) * BigInt.from(denominator) +
        (decimals.isEmpty ? BigInt.zero : BigInt.parse(decimals)),
    BigInt.from(denominator),
  );
}

int _power10(int n) {
  var value = 1;
  for (var i = 0; i < n; i++) {
    value *= 10;
  }
  return value;
}

/// Exact nonnegative rational. Bounds are pace (smaller is faster), never speed.
class BaseFraction {
  const BaseFraction(this.numerator, this.denominator);
  final int numerator, denominator;
  double get value => numerator / denominator;
  Map<String, int> toJson() => {
    'numerator': numerator,
    'denominator': denominator,
  };
}

enum BasePaceUnit {
  millisecondsPerKilometre('milliseconds_per_kilometre'),
  millisecondsPer500Metres('milliseconds_per_500_metres');

  const BasePaceUnit(this.wireName);
  final String wireName;
}

class BasePaceWindow {
  const BasePaceWindow(this.faster, this.slower, this.unit);
  final BaseFraction faster, slower;
  final BasePaceUnit unit;
  Map<String, Object> toJson() => {
    'unit': unit.wireName,
    'faster': faster.toJson(),
    'slower': slower.toJson(),
  };
  String get label =>
      '${_pace(faster)}–${_pace(slower)} ${unit == BasePaceUnit.millisecondsPerKilometre ? '/km' : '/500 m'}';
}

String _pace(BaseFraction pace) {
  // Display only, nearest tenth-second; exact bounds remain in the snapshot.
  final tenths =
      (pace.numerator * 10 + pace.denominator * 500) ~/
      (pace.denominator * 1000);
  final minutes = tenths ~/ 600;
  final seconds = (tenths % 600) / 10;
  return '$minutes:${seconds.toStringAsFixed(1).padLeft(4, '0')}';
}

class BaseWeekRule {
  const BaseWeekRule(
    this.easyMin,
    this.easyMax,
    this.runReps,
    this.runMinutes,
    this.longMin,
    this.longMax,
    this.rowReps,
    this.rowMinutes,
    this.rowRecovery,
    this.squatSets,
    this.squatReps,
    this.squatBasisPoints,
    this.rir,
  );
  final int easyMin, easyMax, runReps, runMinutes, longMin, longMax;
  final int rowReps,
      rowMinutes,
      rowRecovery,
      squatSets,
      squatReps,
      squatBasisPoints;
  final String rir;
  static const weeks = [
    BaseWeekRule(45, 60, 4, 4, 50, 70, 6, 2, 90, 3, 8, 8000, '3'),
    BaseWeekRule(45, 65, 5, 4, 55, 75, 7, 2, 90, 3, 8, 8250, '2–3'),
    BaseWeekRule(50, 65, 4, 6, 60, 80, 5, 3, 90, 4, 6, 8750, '2'),
    BaseWeekRule(45, 60, 4, 4, 55, 70, 4, 2, 90, 2, 6, 7000, '4'),
    BaseWeekRule(50, 65, 5, 5, 60, 80, 6, 2, 75, 4, 6, 8750, '3'),
    BaseWeekRule(50, 70, 4, 7, 65, 80, 7, 2, 75, 4, 5, 9000, '2–3'),
    BaseWeekRule(55, 70, 3, 10, 65, 80, 5, 3, 75, 4, 4, 9500, '2'),
    BaseWeekRule(45, 60, 4, 5, 55, 75, 4, 2, 90, 2, 5, 7500, '3–4'),
  ];
}

enum BaseStepKind { work, recovery }

class BaseIntervalStep {
  const BaseIntervalStep(
    this.kind,
    this.ordinal,
    this.durationSeconds,
    this.pace,
  );
  final BaseStepKind kind;
  final int ordinal, durationSeconds;
  final BasePaceWindow? pace;
  Map<String, Object?> toJson() => {
    'id': '${kind.name}-$ordinal',
    'kind': kind.name,
    'duration_seconds': durationSeconds,
    'calculated_pace': pace?.toJson(),
    'authored_effort': kind == BaseStepKind.recovery ? 'easy' : null,
  };
}

class BaseIntervalPreview {
  BaseIntervalPreview({
    required this.activity,
    required this.repetitions,
    required this.workSeconds,
    required this.recoverySeconds,
    required this.effort,
    required this.pace,
    required this.unavailableReason,
    required this.benchmark,
  }) : steps = List.unmodifiable([
         for (var i = 1; i <= repetitions; i++) ...[
           BaseIntervalStep(BaseStepKind.work, i, workSeconds, pace),
           if (i < repetitions)
             BaseIntervalStep(BaseStepKind.recovery, i, recoverySeconds, null),
         ],
       ]);
  final String activity, effort;
  final int repetitions, workSeconds, recoverySeconds;
  final BasePaceWindow? pace;
  final String? unavailableReason;
  final BaseBenchmark? benchmark;
  final List<BaseIntervalStep> steps;
  Map<String, Object?> toJson() => {
    'authored': {
      'activity': activity,
      'repetitions': repetitions,
      'work_seconds': workSeconds,
      'recovery_seconds_between': recoverySeconds,
      'effort': effort,
    },
    'calculated': pace?.toJson(),
    'unavailable_reason': unavailableReason,
    'benchmark': benchmark?.toJson(),
    'benchmark_digest': benchmark?.digest,
    'steps': steps.map((s) => s.toJson()).toList(),
    'actual': null,
  };
}

class BaseSquatPreview {
  const BaseSquatPreview(
    this.grams,
    this.unavailableReason,
    this.benchmark,
    this.incrementGrams,
  );
  final int? grams, incrementGrams;
  final String? unavailableReason;
  final BaseBenchmark? benchmark;
}

class BaseSessionPreview {
  BaseSessionPreview._(
    this.athleteId,
    this.week,
    this.rule,
    this.run,
    this.row,
    this.squat,
  );
  static const ruleVersion = 'hyrox-base-personalisation-v1';
  static const approvedBriefSha256 =
      '5ae2ebcc020883ce2f496b457296d349ee1793c513818501d616238341d32056';
  final String athleteId;
  final int week;
  final BaseWeekRule rule;
  final BaseIntervalPreview run, row;
  final BaseSquatPreview squat;
  Map<String, Object?> toJson() => {
    'format': 'hyrox_base_local_review_v1',
    'rule_version': ruleVersion,
    'approved_brief_sha256': approvedBriefSha256,
    'scope': 'independent_synthetic_review_only',
    'athlete_id': athleteId,
    'week': week,
    'run_quality': run.toJson(),
    'dedicated_row': row.toJson(),
    'easy_run': {
      'authored_minutes': [rule.easyMin, rule.easyMax],
      'effort': 'conversational, RPE about 3–4',
      'numeric_pace': null,
    },
    'long_run': {
      'authored_minutes': [rule.longMin, rule.longMax],
      'effort': 'conversational, RPE about 3–4',
      'numeric_pace': null,
    },
    'back_squat': {
      'authored': {
        'sets': rule.squatSets,
        'reps': rule.squatReps,
        'five_rm_basis_points': rule.squatBasisPoints,
        'rir': rule.rir,
      },
      'calculated_grams_total_external_load': squat.grams,
      'configured_increment_grams': squat.incrementGrams,
      'rounding': 'nearest_configured_total_increment_ties_down',
      'unavailable_reason': squat.unavailableReason,
      'benchmark': squat.benchmark?.toJson(),
      'benchmark_digest': squat.benchmark?.digest,
      'actual': null,
    },
    'limitations': [
      'partial sessions; supporting work/warm-up/cooldown not authored here',
      'Base starting windows, not measured physiological thresholds',
      'no production binding, completion, persistence or Garmin integration',
    ],
  };
  String get digest =>
      sha256.convert(utf8.encode(jsonEncode(toJson()))).toString();
}

class BasePersonalisationCalculator {
  const BasePersonalisationCalculator();
  BaseSessionPreview preview({
    required String athleteId,
    required int week,
    required Map<BaseMetric, BaseBenchmark> selected,
    int? incrementGrams,
  }) {
    if (week < 1 || week > 8) throw const FormatException('Week must be 1–8.');
    if (incrementGrams != null &&
        (incrementGrams <= 0 || incrementGrams > 1000000000)) {
      throw const FormatException(
        'Configure a positive total-barbell increment in grams.',
      );
    }
    for (final entry in selected.entries) {
      if (entry.value.athleteId != athleteId ||
          entry.key != entry.value.metric) {
        throw const FormatException(
          'Benchmark owner or exact metric mismatch.',
        );
      }
    }
    final r = BaseWeekRule.weeks[week - 1];
    final run = selected[BaseMetric.run10km], row = selected[BaseMetric.row2km];
    final squat = selected[BaseMetric.backSquat5rm];
    final (fast, slow) = switch (r.runMinutes) {
      4 || 5 => (100, 105),
      6 || 7 => (102, 107),
      10 => (103, 108),
      _ => throw StateError('Unapproved duration'),
    };
    final runPace = run == null
        ? null
        : BasePaceWindow(
            BaseFraction(run.canonicalValue * fast, 1000),
            BaseFraction(run.canonicalValue * slow, 1000),
            BasePaceUnit.millisecondsPerKilometre,
          );
    final (rowFast, rowSlow) = week == 4
        ? (18, 23)
        : week == 8
        ? (15, 20)
        : r.rowMinutes == 2
        ? (10, 15)
        : (12, 18);
    final rowPace = row == null
        ? null
        : BasePaceWindow(
            BaseFraction(row.canonicalValue + rowFast * 4000, 4),
            BaseFraction(row.canonicalValue + rowSlow * 4000, 4),
            BasePaceUnit.millisecondsPer500Metres,
          );
    int? grams;
    if (squat != null && incrementGrams != null) {
      final numerator =
          BigInt.from(squat.canonicalValue) * BigInt.from(r.squatBasisPoints);
      final denominator =
          BigInt.from(10000) *
          BigInt.from(incrementGrams) *
          BigInt.from(1000000);
      final floor = numerator ~/ denominator;
      grams =
          (floor +
                  (numerator % denominator * BigInt.two > denominator
                      ? BigInt.one
                      : BigInt.zero))
              .toInt() *
          incrementGrams;
      if (grams == 0) grams = null;
    }
    return BaseSessionPreview._(
      athleteId,
      week,
      r,
      BaseIntervalPreview(
        activity: 'running',
        repetitions: r.runReps,
        workSeconds: r.runMinutes * 60,
        recoverySeconds: 120,
        effort:
            'controlled, repeatable, approximate RPE 7; easy jogging recoveries',
        pace: runPace,
        unavailableReason: run == null ? 'missing_10km_benchmark' : null,
        benchmark: run,
      ),
      BaseIntervalPreview(
        activity: 'dedicated_rowing',
        repetitions: r.rowReps,
        workSeconds: r.rowMinutes * 60,
        recoverySeconds: r.rowRecovery,
        effort: 'dedicated rowing intervals; does not apply inside mixed WODs',
        pace: rowPace,
        unavailableReason: row == null
            ? 'missing_2km_row_benchmark_no_authored_numeric_fallback'
            : null,
        benchmark: row,
      ),
      BaseSquatPreview(
        grams,
        squat == null
            ? 'missing_back_squat_5rm_use_authored_rir'
            : incrementGrams == null
            ? 'missing_equipment_increment_use_authored_rir'
            : grams == null
            ? 'rounded_load_not_positive_use_authored_rir'
            : null,
        squat,
        incrementGrams,
      ),
    );
  }
}
