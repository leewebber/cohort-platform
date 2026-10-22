import 'dart:convert';
import 'dart:io';

import 'package:cohort_platform/domain/hyrox_base/base_personalisation.dart';
import 'package:cohort_platform/internal_review/hyrox_base/base_review_controller.dart';

/// Terminal counterpart of the isolated review UI. No file intake or athlete IO.
Future<void> main() async {
  final examples = <Object>[];
  for (final (athlete, runMinutes, rowSeconds, squatKg, increment) in [
    ('synthetic-a', '40', '420', '100', 2500),
    ('synthetic-b', '60', '540', '75', 1000),
  ]) {
    final c = BaseReviewController(athlete);
    for (final (metric, value, unit) in [
      (BaseMetric.run10km, runMinutes, BaseInputUnit.minutes),
      (BaseMetric.row2km, rowSeconds, BaseInputUnit.seconds),
      (BaseMetric.backSquat5rm, squatKg, BaseInputUnit.kilograms),
      (BaseMetric.strictPress5rm, '40', BaseInputUnit.kilograms),
      (BaseMetric.strictPullUps, '0', BaseInputUnit.count),
    ]) {
      final b = BaseBenchmark.enter(
        id: '$athlete-${metric.name}-v1',
        athleteId: athlete,
        metric: metric,
        value: value,
        unit: unit,
        testDate: '2026-10-22',
        sourceType: BaseSourceType.syntheticExample,
        sourceReference: 'local-example:${metric.name}',
      );
      if (!c.enter(b) || !c.acceptSelection(c.proposeSelection(b.id)!)) {
        throw StateError('Synthetic selection failed');
      }
    }
    for (var week = 1; week <= 8; week++) {
      c.configure(week: week, incrementGrams: increment);
      if (!await c.review()) throw StateError('Synthetic review failed');
      examples.add(c.preview!.toJson());
    }
    c.dispose();
  }
  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert({
      'examples': examples,
      'claim':
          'synthetic partial-session review; no complete 48-session package',
    }),
  );
}
