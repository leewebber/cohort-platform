import 'dart:convert';
import 'dart:io';
import 'package:cohort_platform/application/hyrox_base/bound_programme.dart';
import 'package:cohort_platform/application/hyrox_base/local_bound_repository.dart';
import 'package:cohort_platform/domain/hyrox_base/base_personalisation.dart';

Future<void> main() async {
  final fixture = SyntheticBoundFixture.build();
  final programme = BoundProgramme.compile(
    fixture.source,
    sourceRegistry: fixture,
  );
  final examples = <Object>[];
  for (final (owner, run, row, squat, increment) in [
    ('synthetic-a', '2400', '420', '100', 2500),
    ('synthetic-b', '3600', '540', '75', 1000),
  ]) {
    final repo = LocalBoundRepository(
      athleteId: owner,
      programme: programme,
      clock: () => DateTime.utc(2026, 10, 22),
    );
    await repo.configureIncrement(increment);
    for (final (metric, value, unit) in [
      (BaseMetric.run10km, run, BaseInputUnit.seconds),
      (BaseMetric.row2km, row, BaseInputUnit.seconds),
      (BaseMetric.backSquat5rm, squat, BaseInputUnit.kilograms),
    ]) {
      final b = BaseBenchmark.enter(
        id: '$owner-${metric.name}-r1',
        athleteId: owner,
        metric: metric,
        value: value,
        unit: unit,
        testDate: '2026-10-22',
        sourceType: BaseSourceType.syntheticExample,
        sourceReference: 'bound-fixture:${metric.name}',
      );
      await repo.enter(b);
      await repo.accept(await repo.propose('hyrox-${metric.name}', b.id));
    }
    for (final slot in programme.slots) {
      final review = await repo.review(slot);
      final frozen = await repo.start(review);
      examples.add({
        'slot': slot,
        'athlete': owner,
        'review': review.document,
        'frozen_digest': frozen.digest,
      });
    }
    await repo.dispose();
  }
  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert({
      'package_hash': programme.hash,
      'fixture_source': jsonDecode(fixture.source),
      'fixture_source_text': fixture.source,
      'fixture_session_sources': fixture.bodies,
      'examples': examples,
      'claim':
          'synthetic partial targets; no production persistence or complete programme',
    }),
  );
}
