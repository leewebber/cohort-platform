import 'dart:convert';
import 'dart:io';
import 'package:cohort_platform/domain/hyrox_base/base_personalisation.dart';

/// Local SQL parity inputs from the actual approved Dart calculator, not SQL
/// reimplementation. Stdout is a deterministic JSONL fixture, never athlete data.
void main() {
  for (var week = 1; week <= 8; week++) {
    for (final minutes in ['40', '60']) {
      final run = benchmark(BaseMetric.run10km, minutes, BaseInputUnit.minutes);
      final preview = const BasePersonalisationCalculator().preview(
        athleteId: 'fixture',
        week: week,
        selected: {BaseMetric.run10km: run},
      );
      emit('runningIntervals', week, run.canonicalValue, null, {
        'status': 'calculated',
        ...preview.run.pace!.toJson(),
      });
    }
    for (final milliseconds in ['480000', '480001', '1000000000']) {
      final row = benchmark(
        BaseMetric.row2km,
        milliseconds,
        BaseInputUnit.milliseconds,
      );
      final preview = const BasePersonalisationCalculator().preview(
        athleteId: 'fixture',
        week: week,
        selected: {BaseMetric.row2km: row},
      );
      emit('dedicatedRowIntervals', week, row.canonicalValue, null, {
        'status': 'calculated',
        ...preview.row.pace!.toJson(),
      });
    }
    for (final kilograms in ['100', '101.5625', '0.001', '1000000']) {
      final squat = benchmark(
        BaseMetric.backSquat5rm,
        kilograms,
        BaseInputUnit.kilograms,
      );
      for (final increment in [1, 2500, 1000000000]) {
        final preview = const BasePersonalisationCalculator().preview(
          athleteId: 'fixture',
          week: week,
          selected: {BaseMetric.backSquat5rm: squat},
          incrementGrams: increment,
        );
        emit(
          'backSquat',
          week,
          squat.canonicalValue,
          increment,
          preview.squat.grams == null
              ? {
                  'status': 'unavailable',
                  'code': preview.squat.unavailableReason,
                }
              : {
                  'status': 'calculated',
                  'unit': 'grams_total_external_load',
                  'grams': preview.squat.grams,
                },
        );
      }
    }
  }
}

BaseBenchmark benchmark(BaseMetric metric, String value, BaseInputUnit unit) =>
    BaseBenchmark.enter(
      id: metric.name,
      athleteId: 'fixture',
      metric: metric,
      value: value,
      unit: unit,
      testDate: '2026-10-22',
      sourceType: BaseSourceType.syntheticExample,
      sourceReference: 'sql-parity',
    );

void emit(
  String kind,
  int week,
  int value,
  int? increment,
  Map<String, Object?> expected,
) {
  stdout.writeln(
    jsonEncode({
      'kind': kind,
      'week': week,
      'value': value,
      'increment': increment,
      'expected': expected,
    }),
  );
}
