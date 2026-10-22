import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:cohort_platform/application/hyrox_base/bound_programme.dart';
import 'package:cohort_platform/application/hyrox_base/local_bound_repository.dart';
import 'package:cohort_platform/domain/hyrox_base/base_personalisation.dart';
import 'package:flutter_test/flutter_test.dart';

const catalogue = HyroxBindingCatalogue();
const compiler = PlanPackageCompiler(
  validator: PlanPackageValidator(personalisationResolver: catalogue),
);
BaseBenchmark evidence(
  BaseMetric metric,
  String value, {
  String id = 'r1',
  String owner = 'synthetic-a',
  BaseInputUnit? unit,
}) => BaseBenchmark.enter(
  id: id,
  athleteId: owner,
  metric: metric,
  value: value,
  unit:
      unit ??
      (metric == BaseMetric.backSquat5rm
          ? BaseInputUnit.kilograms
          : BaseInputUnit.seconds),
  testDate: '2026-10-22',
  sourceType: BaseSourceType.syntheticExample,
  sourceReference: 'fixture:$id',
);
LocalBoundRepository repository({String owner = 'synthetic-a'}) =>
    LocalBoundRepository(
      athleteId: owner,
      programme: BoundProgramme.compile(SyntheticBoundFixture.build().source),
      clock: () => DateTime.utc(2026, 10, 22),
    );
Future<void> select(LocalBoundRepository r, BaseBenchmark e) async {
  await r.enter(e);
  await r.accept(await r.propose('hyrox-${e.metric.name}', e.id));
}

Matcher refusal(String code) =>
    throwsA(isA<BoundRefusal>().having((e) => e.code, 'code', code));
Map<String, dynamic> target(BoundReviewReceipt r, int index) =>
    (r.document['targets'] as List)[index] as Map<String, dynamic>;
String mutated(void Function(Map<String, dynamic>) change) {
  final d =
      jsonDecode(SyntheticBoundFixture.build().source) as Map<String, dynamic>;
  change(d);
  return jsonEncode(d);
}

Map<String, dynamic> first(Map<String, dynamic> d) =>
    (d['personalisation_binding']['targets'] as List).first
        as Map<String, dynamic>;
void main() {
  test(
    'compile bound source, select 40/60-minute evidence, review and freeze exact prescription',
    () async {
      for (final (owner, seconds, faster, slower) in [
        ('synthetic-a', '2400', 240000, 252000),
        ('synthetic-b', '3600', 360000, 378000),
      ]) {
        final r = repository(owner: owner);
        await select(r, evidence(BaseMetric.run10km, seconds, owner: owner));
        final review = await r.review('W1-RUN');
        expect(target(review, 0)['state'], 'calculated');
        final pace = target(review, 0)['prescription']['calculated'];
        expect(
          pace['faster']['numerator'] / pace['faster']['denominator'],
          faster,
        );
        expect(
          pace['slower']['numerator'] / pace['slower']['denominator'],
          slower,
        );
        final frozen = await r.start(review), d = frozen.document;
        expect(d['package_hash'], r.programme.hash);
        expect(d['package_canonical_json'], r.programme.canonicalJson);
        expect(d['authored_source'], r.programme.source);
        expect(
          d['source_text_sha256'],
          personalisationTextDigest(r.programme.source),
        );
        expect(d['review_digest'], review.digest);
        expect(d['frozen_at_utc'], '2026-10-22T00:00:00.000Z');
        final dep = (d['dependencies'] as List).single;
        expect(personalisationDigest(dep['rule']), dep['rule_digest']);
        expect(personalisationDigest(dep['binding']), dep['binding_digest']);
        expect(
          d['review']['targets'][0]['selected_evidence']['evidence_revision']['revision'],
          1,
        );
        expect(d['review']['targets'][0]['actual'], isNull);
        expect(
          (jsonDecode(dep['session_source'] as String) as Map)['protocol_id'],
          'SYNTH-W1-RUN-R1',
        );
        expect(await r.start(review), same(frozen));
        await r.dispose();
      }
    },
  );
  test(
    'row and squat use their own selected definitions, correct rounding and no WOD transfer',
    () async {
      final r = repository();
      await r.configureIncrement(5000);
      await select(r, evidence(BaseMetric.row2km, '420', id: 'row'));
      await select(r, evidence(BaseMetric.backSquat5rm, '100', id: 'squat'));
      final w2 = await r.review('W2-GYM');
      final squat = target(w2, 0), row = target(w2, 1);
      expect(
        squat['prescription']['calculated_grams_total_external_load'],
        80000,
      ); // 82.5kg tie ->80
      expect(
        row['prescription']['calculated']['faster']['numerator'] / 4,
        115000,
      );
      expect((row['prescription']['steps'] as List).last['kind'], 'work');
      final w4 = await r.review('W4-GYM');
      expect(
        target(w4, 1)['prescription']['calculated']['faster']['numerator'] / 4,
        123000,
      );
      final w8 = await r.review('W8-GYM');
      expect(
        target(w8, 1)['prescription']['calculated']['faster']['numerator'] / 4,
        120000,
      );
      final source = mutated((d) => first(d)['kind'] = 'mixedWod');
      expect(compiler.compile(source).isValid, false);
      await expectLater(r.complete('W1-GYM'), refusal('session_not_started'));
    },
  );
  test(
    'all eight compiled week bindings dispatch existing approved calculator parameters',
    () async {
      final r = repository();
      await r.configureIncrement(2500);
      await select(r, evidence(BaseMetric.run10km, '2400', id: 'run'));
      await select(r, evidence(BaseMetric.row2km, '540', id: 'row'));
      await select(r, evidence(BaseMetric.backSquat5rm, '100', id: 'squat'));
      for (var week = 1; week <= 8; week++) {
        final existing = const BasePersonalisationCalculator().preview(
          athleteId: 'synthetic-a',
          week: week,
          incrementGrams: 2500,
          selected: {
            BaseMetric.run10km: r.selected['hyrox-run10km']!.evidence.benchmark,
            BaseMetric.row2km: r.selected['hyrox-row2km']!.evidence.benchmark,
            BaseMetric.backSquat5rm:
                r.selected['hyrox-backSquat5rm']!.evidence.benchmark,
          },
        );
        expect(
          target(await r.review('W$week-RUN'), 0)['prescription'],
          existing.run.toJson(),
        );
        final gym = await r.review('W$week-GYM');
        expect(target(gym, 1)['prescription'], existing.row.toJson());
        expect(target(gym, 0)['prescription'], existing.toJson()['back_squat']);
      }
    },
  );
  test(
    'missing evidence/increment stay unavailable; started snapshots and actuals are separate',
    () async {
      final r = repository();
      final missing = await r.review('W1-GYM');
      expect(target(missing, 0)['state'], 'missing_evidence');
      expect(target(missing, 1)['prescription']['calculated'], isNull);
      await r.start(missing);
      await select(r, evidence(BaseMetric.backSquat5rm, '100'));
      final next = await r.review('W2-GYM');
      expect(target(next, 0)['state'], 'missing_equipment_increment');
      expect(
        target(next, 0)['prescription']['calculated_grams_total_external_load'],
        isNull,
      );
      await r.configureIncrement(2500);
      expect(target(await r.review('W2-GYM'), 0)['state'], 'calculated');
      final old = r.started['W1-GYM']!;
      await r.complete('W1-GYM', actualSquatGrams: 77500);
      expect(r.started['W1-GYM'], same(old));
      expect(
        jsonDecode(r.completedActuals['W1-GYM']!)['actual_squat_grams'],
        77500,
      );
      await expectLater(
        r.complete('W1-GYM'),
        refusal('completion_already_recorded'),
      );
    },
  );
  test(
    'replacement before/after start requires explicit consent and preserves completed history',
    () async {
      final r = repository();
      await select(r, evidence(BaseMetric.run10km, '2400', id: 'old'));
      final oldReceipt = await r.review('W1-RUN');
      final old = await r.start(oldReceipt);
      await r.complete('W1-RUN');
      await r.enter(evidence(BaseMetric.run10km, '3600', id: 'new'));
      final unchanged = await r.review('W2-RUN');
      expect(
        target(
          unchanged,
          0,
        )['selected_evidence']['evidence_revision']['benchmark']['id'],
        'old',
      );
      final proposal = await r.propose('hyrox-run10km', 'new');
      await expectLater(r.start(unchanged), refusal('stale_or_foreign_review'));
      expect(r.selected['hyrox-run10km']!.evidence.benchmark.id, 'old');
      await r.accept(proposal);
      final future = await r.review('W2-RUN');
      expect(
        target(future, 0)['selected_evidence']['evidence_revision']['revision'],
        2,
      );
      expect(
        target(future, 0)['prescription']['calculated']['slower']['numerator'] /
            1000,
        378000,
      );
      expect(await r.start(oldReceipt), same(old));
      expect(r.started['W1-RUN']!.json, old.json);
      final started = await r.start(future);
      expect(started.digest, isNot(old.digest));
    },
  );
  test(
    'concurrent start wins before update; update wins before start and refuses stale receipt',
    () async {
      for (final startFirst in [true, false]) {
        final r = repository();
        await select(r, evidence(BaseMetric.run10km, '2400', id: 'old'));
        final receipt = await r.review('W1-RUN');
        Future<void> update() async {
          await select(r, evidence(BaseMetric.run10km, '3600', id: 'new'));
        }

        if (startFirst) {
          final starting = r.start(receipt), updating = update();
          final frozen = await starting;
          await updating;
          expect(
            frozen
                .document['review']['targets'][0]['selected_evidence']['evidence_revision']['benchmark']['id'],
            'old',
          );
          expect(r.selected['hyrox-run10km']!.evidence.benchmark.id, 'new');
        } else {
          final updating = update();
          await expectLater(
            r.start(receipt),
            refusal('stale_or_foreign_review'),
          );
          await updating;
          expect(r.started, isEmpty);
          await r.start(await r.review('W1-RUN'));
          expect(
            r
                .started['W1-RUN']!
                .document['review']['targets'][0]['selected_evidence']['evidence_revision']['benchmark']['id'],
            'new',
          );
        }
      }
    },
  );
  test(
    'stale/foreign consent and ownership/hash lookalikes cannot authorise a start',
    () async {
      final a = repository(), b = repository();
      final e = evidence(BaseMetric.run10km, '2400');
      await a.enter(e);
      await b.enter(e);
      final proposal = await a.propose('hyrox-run10km', e.id);
      await expectLater(
        b.accept(proposal),
        refusal('stale_or_foreign_consent'),
      );
      await a.configureIncrement(2500);
      await expectLater(
        a.accept(proposal),
        refusal('stale_or_foreign_consent'),
      );
      await expectLater(
        a.enter(
          evidence(
            BaseMetric.run10km,
            '3600',
            owner: 'synthetic-b',
            id: 'foreign',
          ),
        ),
        refusal('foreign_evidence_owner'),
      );
      await select(a, e);
      await select(b, e);
      final ar = await a.review('W1-RUN'), br = await b.review('W1-RUN');
      await b.start(br);
      await expectLater(b.start(ar), refusal('foreign_review_receipt'));
      await expectLater(
        a.enter(evidence(BaseMetric.run10km, '3600')),
        refusal('immutable_evidence_identity_conflict'),
      );
    },
  );
  test(
    'late reviews and disposed repositories cannot publish stale receipts',
    () async {
      final r = repository();
      final entered = Completer<void>(), release = Completer<void>();
      final pending = r.review(
        'W1-RUN',
        beforeReply: () {
          entered.complete();
          return release.future;
        },
      );
      await entered.future;
      await select(r, evidence(BaseMetric.run10km, '2400'));
      release.complete();
      await expectLater(pending, refusal('stale_review'));
      final firstEntered = Completer<void>(), secondRelease = Completer<void>();
      final first = r.review(
        'W1-RUN',
        beforeReply: () {
          firstEntered.complete();
          return secondRelease.future;
        },
      );
      await firstEntered.future;
      final latest = await r.review('W1-RUN');
      secondRelease.complete();
      await expectLater(first, refusal('stale_review'));
      await r.start(latest);
      await r.dispose();
      await expectLater(r.review('W2-RUN'), refusal('repository_disposed'));
    },
  );
  test(
    'invalid units, values and configuration refuse; unrelated exercises never provide squat',
    () async {
      final r = repository();
      expect(() => evidence(BaseMetric.run10km, 'NaN'), throwsFormatException);
      expect(
        () =>
            evidence(BaseMetric.run10km, '2400', unit: BaseInputUnit.kilograms),
        throwsFormatException,
      );
      final press = BaseBenchmark.enter(
        id: 'press',
        athleteId: 'synthetic-a',
        metric: BaseMetric.strictPress5rm,
        value: '60',
        unit: BaseInputUnit.kilograms,
        testDate: '2026-10-22',
        sourceType: BaseSourceType.knownResult,
        sourceReference: 'press',
      );
      await expectLater(
        r.enter(press),
        refusal('unrelated_benchmark_definition'),
      );
      await r.configureIncrement(2500);
      await expectLater(
        r.configureIncrement(0),
        refusal('invalid_equipment_increment'),
      );
      expect(r.incrementGrams, isNull);
      await select(r, evidence(BaseMetric.backSquat5rm, '0.001'));
      await r.configureIncrement(2500);
      expect(target(await r.review('W1-GYM'), 0)['state'], 'unavailable');
    },
  );
  test(
    'v1/v2 original canonical bytes and hashes remain exact; v3 imports always refuse',
    () {
      for (final version in [1, 2]) {
        final prefix =
            'packages/cohort_plan_package/test/fixtures/minimal_plan_package${version == 1 ? '' : '_v2'}';
        final result = compiler.compile(
          File('$prefix.yaml').readAsStringSync(),
        );
        expect(result.isValid, true);
        expect(
          result.canonicalJson,
          File('$prefix.canonical.json').readAsStringSync().trim(),
        );
        expect(
          result.contentHashSha256,
          File('$prefix.sha256').readAsStringSync().trim(),
        );
      }
      final result = compiler.compile(SyntheticBoundFixture.build().source);
      expect(result.isValid, true);
      expect(
        compiler.verifyCanonicalArtifact(result.canonicalJson!).isValid,
        true,
      );
      expect(
        () => const PlanPackageImportPayloadBuilder().build(
          compileResult: result,
          importedBy: 'local',
        ),
        throwsStateError,
      );
      expect(
        () => const PlanPackageImportPayloadBuilder().buildRetainedPublication(
          compileResult: result,
          importedBy: 'local',
        ),
        throwsStateError,
      );
      final noBinding = mutated((d) => d.remove('personalisation_binding'));
      expect(const PlanPackageCompiler().compile(noBinding).isValid, true);
    },
  );
  test(
    'v1/v2 forbid bindings; v3 requires resolver and retains reserved tracking refusal',
    () {
      for (final v in [1, 2]) {
        expect(
          compiler
              .compile(mutated((d) => d['package_schema_version'] = v))
              .issues
              .map((i) => i.code),
          contains('personalisation_requires_v3'),
        );
      }
      expect(
        const PlanPackageCompiler()
            .compile(SyntheticBoundFixture.build().source)
            .issues
            .map((i) => i.code),
        contains('unresolved_personalisation_dependencies'),
      );
      expect(
        compiler
            .compile(mutated((d) => d['tracking_profile_binding'] = {}))
            .issues
            .map((i) => i.code),
        contains('reserved_tracking_binding_unsupported'),
      );
    },
  );
  test(
    'malformed, unsupported, unresolved and contradictory target bindings fail closed',
    () {
      final mutations = <void Function(Map<String, dynamic>)>[
        (d) => d['personalisation_binding'] = null,
        (d) => d['personalisation_binding']['extra'] = true,
        (d) => d['personalisation_binding']['targets'] = [],
        (d) => first(d)['input_unit'] = 'count',
        (d) => first(d)['output_unit'] = 'millisecondsPer500Metres',
        (d) => first(d)['rule']['version'] = 2,
        (d) => first(d)['rule']['digest'] = '0' * 64,
        (d) => first(d)['benchmark']['id'] = 'other',
        (d) => first(d)['identity_namespace'] = 'canonical_exercise',
        (d) => first(d)['exercise']['digest'] = '0' * 64,
        (d) => first(d)['parameters']['sets'] = 99,
        (d) => first(d)['parameters']['sets'] = double.nan,
        (d) => first(d)['slot_key'] = 'missing',
        (d) => first(d)['protocol_revision'] = 2,
        (d) => first(d)['week_number'] = 0,
        (d) => first(d)['step_ids'] = ['work-1', 'work-1'],
        (d) => d['personalisation_binding']['targets'].add(first(d)),
        (d) => d['personalisation_binding']['freshness'] = '30_days',
      ];
      for (var i = 0; i < mutations.length; i++) {
        if (i == 11) continue; // JSON does not encode NaN; YAML case below.
        expect(
          compiler.compile(mutated(mutations[i])).isValid,
          false,
          reason: 'mutation $i',
        );
      }
      expect(
        compiler
            .compile(
              SyntheticBoundFixture.build().source.replaceFirst(
                '"sets":3',
                '"sets":.nan',
              ),
            )
            .isValid,
        false,
      );
      expect(
        () => BoundProgramme.compile(
          mutated((d) => first(d)['session_body_sha256'] = '0' * 64),
        ),
        throwsFormatException,
      );
      expect(
        () => BoundProgramme.compile(
          mutated((d) => first(d)['block_id'] = 'missing-block'),
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'canonical key order stable; changing any authored binding unit/source/rule changes or refuses package meaning',
    () {
      final source = SyntheticBoundFixture.build().source;
      final parsed = jsonDecode(source) as Map<String, dynamic>;
      final reversed = {
        for (final k in parsed.keys.toList().reversed) k: parsed[k],
      };
      expect(
        compiler.compile(jsonEncode(reversed)).contentHashSha256,
        compiler.compile(source).contentHashSha256,
      );
      final changed = compiler.compile(
        mutated((d) => first(d)['session_body_sha256'] = '0' * 64),
      );
      expect(changed.isValid, true);
      expect(
        changed.contentHashSha256,
        isNot(compiler.compile(source).contentHashSha256),
      );
      expect(
        () => BoundProgramme.compile(
          jsonEncode(changed.manifest!.personalisationBinding!.toJson()),
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'snapshot ownership, immutable views, actual target scope and UTC freeze are enforced',
    () async {
      final r = repository();
      final review = await r.review('W1-RUN');
      final starts = await Future.wait([r.start(review), r.start(review)]);
      expect(starts[0], same(starts[1]));
      final copy = starts[0].document;
      copy['package_hash'] = 'tampered';
      expect(starts[0].document['package_hash'], r.programme.hash);
      expect(() => r.started.clear(), throwsUnsupportedError);
      await expectLater(
        r.complete('W1-RUN', actualSquatGrams: 1000),
        refusal('actual_target_scope_mismatch'),
      );
      final invalid = LocalBoundRepository(
        athleteId: 'synthetic-a',
        programme: r.programme,
        clock: () => DateTime(2026, 10, 22),
      );
      await expectLater(
        invalid.start(await invalid.review('W1-RUN')),
        refusal('invalid_freeze_clock'),
      );
      expect(invalid.started, isEmpty);
      expect(
        () => LocalBoundRepository(
          athleteId: 'real-athlete',
          programme: r.programme,
        ),
        throwsA(isA<BoundRefusal>()),
      );
    },
  );
  test(
    'new v3 canonical vector is stable without modifying any legacy golden',
    () {
      expect(
        compiler
            .compile(SyntheticBoundFixture.build().source)
            .contentHashSha256,
        File(
          'test/hyrox_base/fixtures/bound_v3.sha256',
        ).readAsStringSync().trim(),
      );
    },
  );
}
