import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cohort_platform/features/programme_studio/domain/programme_review_models.dart';
import 'package:cohort_platform/features/programme_studio/projection/movement_prescription_review.dart';
import 'package:cohort_platform/features/programme_studio/projection/programme_review_catalog.dart';
import 'package:cohort_platform/features/programme_studio/projection/programme_review_projector.dart';
import 'package:cohort_platform/features/programme_studio/projection/programme_review_source.dart';
import 'package:cohort_platform/features/programme_studio/projection/programme_review_workspace.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/protocol_authoring_fixtures.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/synthetic_strength_lineage.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/synthetic_strength_session_compiler.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/synthetic_strength_review_bridge.dart';
import 'package:cohort_platform/features/programme_studio/composition/synthetic_composition_controller.dart';
import 'package:cohort_platform/features/programme_studio/composition/source_export/canonical_source_bundle.dart';
import 'programme_first_controller_test.dart' show changed, selection;

ProgrammeReviewMovement movement(
  Map<String, dynamic> fields, {
  String? notes,
}) => ProgrammeReviewMovement(
  position: 1,
  name: 'Identical synthetic title',
  exerciseId: 'EX-9001',
  rawPrescription: jsonEncode(fields),
  notes: notes,
);
MovementPrescriptionReview review(Map<String, dynamic> fields) =>
    MovementPrescriptionReview.fromMovement(movement(fields));
Future<ProgrammeReviewCatalog> syntheticReview({String? extraFields}) async {
  final source = await SyntheticStrengthSessionCompiler().compileExact(
    d2R1Source(),
    SyntheticStrengthLineage.a.identity(1),
  );
  const bridge = SyntheticStrengthReviewBridge();
  var sql = bridge.readerText([source]);
  if (extraFields != null) {
    sql = sql.replaceFirst('"sets":2', '"sets":2,$extraFields');
  }
  return const ProgrammeReviewProjector().project(
    ProgrammeReviewProjectionRequest(
      bundles: [
        ProgrammeReviewSourceBundle(
          spec: const ProgrammeReviewSourceSpec(
            catalogId: 'source-review-fixture',
            classification: ProgrammeReviewClassification.fixtureTestExample,
            planPackagePath: 'synthetic/package.yaml',
            fixture: true,
          ),
          planPackageYaml: bridge.packageSource(source, [source]),
          executableProtocolSql: [sql],
        ),
      ],
    ),
  );
}

void main() {
  test(
    'retains RIR zero and ranges, RPE, resistance and eccentric values without conversion',
    () {
      for (final rir in [0, 2, '2-3', '3+']) {
        final r = review({
          'sets': 2,
          'reps': '8/leg',
          'rir': rir,
          'rpe': '7-8',
          'resistance': 'manual/towel',
          'eccentric_seconds': 3,
          'per_side': true,
        });
        expect(r.complete, true);
        expect(
          r.lines,
          containsAll([
            'RIR (authored): $rir',
            'RPE (authored): 7-8',
            'Resistance: “manual/towel”',
            'Eccentric: 3 seconds (authored)',
            'Per side: true',
            '8/leg reps',
          ]),
        );
      }
    },
  );
  test(
    'absent load is distinct from authored scalar text and explicit false',
    () {
      expect(
        review({'sets': 1, 'reps': 5}).lines,
        contains('Load: Unspecified'),
      );
      expect(
        review({'load': 'Unspecified', 'per_side': false}).lines,
        containsAll(['Load (authored text): “Unspecified”', 'Per side: false']),
      );
      expect(review({'load': null}).complete, false);
    },
  );
  test(
    'textual rest ranges survive unchanged; numeric rest uses existing formatter',
    () {
      final r = review({'rest_seconds': '150-180', 'recovery_seconds': 90});
      expect(r.complete, true);
      expect(r.lines, [
        'Rest: 150-180 seconds (authored)',
        'Recovery: 90 seconds',
      ]);
      expect(review({'rest_seconds': 60}).lines, ['Rest 1 min']);
    },
  );
  final typedLoads = <Map<String, dynamic>, String>{
    {'type': 'bodyweight'}: 'Bodyweight',
    {'type': 'fixedKg', 'kg': 12.5}: '12.5 kg',
    {'type': 'rpe', 'rpe': 8}: 'RPE 8',
    {'type': 'rir', 'rir': 0}: '0 RIR',
    {'type': 'percent1rm', 'percent_1rm': 75}: '75% 1RM',
    {'type': 'freeText', 'text': 'Very light'}: 'Very light',
    {'type': 'athleteSelected', 'unit': 'kg'}: 'Load: athlete selected (kg)',
    {'unit': 'bodyweight'}: 'Bodyweight',
    {'unit': 'kg', 'value': 12.5}: '12.5 kg',
    {'unit': 'rpe', 'value': 7}: 'RPE 7',
    {'unit': 'rir', 'value': 2}: '2 RIR',
  };
  for (final entry in typedLoads.entries) {
    test('read-only load uses existing semantics ${entry.key}', () {
      final r = review({'load': entry.key});
      expect(r.complete, true);
      expect(r.lines, [entry.value]);
    });
  }
  test(
    'compact kg and authored load guidance are preserved, never equivalent intensity',
    () {
      expect(review({'load': 12.5}).lines, ['12.5 kg']);
      expect(review({'load': 'lighter_than_benchmark'}).lines, [
        'Load (authored text): “lighter_than_benchmark”',
      ]);
    },
  );
  test(
    'typed exact/range/duration/distance use existing reps models without JSON or reps mislabelling',
    () {
      final values = <Map<String, dynamic>, String>{
        {'type': 'exact', 'exact_reps': 5}: '5 reps',
        {'type': 'range', 'min_reps': 8, 'max_reps': 10}: '8–10 reps',
        {'type': 'range', 'min': 8, 'max': 10}: '8–10 reps',
        {'type': 'duration', 'text': '45 sec'}: 'Duration: 45 sec',
        {'type': 'distance', 'text': '20 m'}: 'Distance: 20 m',
      };
      for (final entry in values.entries) {
        final r = review({'reps': entry.key});
        expect(r.complete, true, reason: entry.key.toString());
        expect(r.lines.first, entry.value);
      }
    },
  );
  for (final fields in <Map<String, dynamic>>[
    {
      'future_target': {'mode': 'unknown', 'value': 123},
    },
    {
      'load': {'type': 'futureMode', 'kg': 10},
    },
    {
      'load': {'type': 'rpe', 'rpe': 7, 'kg': 100},
    },
    {
      'load': {'unit': 'bodyweight', 'value': 10},
    },
    {
      'load': {'unit': 'futureUnit', 'value': 1},
    },
    {
      'load': {'type': 'fixedKg'},
    },
    {
      'reps': {'type': 'range', 'min': 5},
    },
    {
      'reps': {'type': 'range', 'min_reps': 5, 'max_reps': 8, 'min': 4},
    },
    {
      'reps': {'type': 'distance', 'text': '20 m', 'exact_reps': 9},
    },
    {'reps': []},
    {
      'rest_seconds': {'min': 60, 'max': 90},
    },
    {'rir': null},
  ]) {
    test(
      'uninterpreted fields fail completeness and never change raw source $fields',
      () {
        final m = movement(fields);
        final before = jsonEncode(m.toJson());
        final r = MovementPrescriptionReview.fromMovement(m);
        expect(r.complete, false);
        expect(r.limitations, isNotEmpty);
        expect(jsonEncode(m.toJson()), before);
        expect(m.rawPrescription, jsonEncode(fields));
      },
    );
  }
  for (final raw in ['{broken', '[]', 'null', '42']) {
    test(
      'malformed/non-object source $raw remains available without a crash',
      () {
        final m = ProgrammeReviewMovement(
          position: 1,
          name: 'Synthetic',
          rawPrescription: raw,
        );
        expect(MovementPrescriptionReview.fromMovement(m).complete, false);
        expect(m.rawPrescription, raw);
      },
    );
  }
  for (final raw in [
    r'{"rir":0,"rir":3}',
    r'{"rir":0,"r\u0069r":3}',
    r'{"load":{"type":"rpe","rpe":7,"rpe":9}}',
  ]) {
    test(
      'duplicate prescription keys are retained but never silently resolved $raw',
      () {
        final m = ProgrammeReviewMovement(
          position: 1,
          name: 'Synthetic',
          rawPrescription: raw,
        );
        final r = MovementPrescriptionReview.fromMovement(m);
        expect(r.complete, false);
        expect(r.lines, isEmpty);
        expect(m.rawPrescription, raw);
      },
    );
  }
  test('competing aliases are visible and cannot pass review completeness', () {
    final r = review({
      'load': {'type': 'bodyweight'},
      'target_rpe': 7,
      'notes': 'first note',
      'coach_cue': 'second note',
    });
    expect(r.complete, false);
    expect(
      r.lines,
      containsAll([
        'Bodyweight',
        'Target RPE (authored): 7',
        'Prescription notes: “first note”',
        'Cue: “second note”',
      ]),
    );
  });
  test(
    'known synthetic prescriptions retain green readability; unknown fields fail gate with exact raw values',
    () async {
      final known = (await syntheticReview()).developerFixtures.single;
      expect(
        known.readiness
            .singleWhere((c) => c.id == 'prescription_renderable')
            .status,
        ProgrammeReviewCheckStatus.passed,
      );
      final unknown = (await syntheticReview(
        extraFields: '"future_target":{"mode":"uninterpreted","value":123}',
      )).developerFixtures.single;
      expect(unknown.compile.state, ProgrammeReviewCompileState.valid);
      expect(
        unknown.compile.contentHashSha256,
        known.compile.contentHashSha256,
      );
      expect(
        unknown.readiness
            .singleWhere((c) => c.id == 'prescription_renderable')
            .status,
        ProgrammeReviewCheckStatus.failed,
      );
      expect(
        unknown.findings.any(
          (f) =>
              f.code == 'unsupported_prescription' &&
              f.message.contains('future_target'),
        ),
        true,
      );
      expect(
        unknown
            .weeks
            .single
            .days
            .first
            .sessions
            .single
            .blocks
            .single
            .movements
            .first
            .rawPrescription,
        contains('"future_target":{"mode":"uninterpreted","value":123}'),
      );
    },
  );
  test(
    'all registered existing sources retain exact bytes and raw movement JSON; limitations never prove library approval',
    () {
      final paths = ProgrammeReviewCatalogRegistry.realReadablePaths;
      final digests = {
        for (final p in paths)
          p: sha256.convert(File(p).readAsBytesSync()).toString(),
      };
      final catalog = ProgrammeReviewWorkspace(
        readAsset: (p) => File(p).readAsStringSync(),
      ).loadRealCatalog();
      var count = 0;
      for (final p in catalog.programmes) {
        expect(
          p.readiness
              .singleWhere((c) => c.id == 'prescription_renderable')
              .status,
          ProgrammeReviewCheckStatus.failed,
        );
        for (final m
            in p.weeks
                .expand((w) => w.days)
                .expand((d) => d.sessions)
                .expand((s) => s.blocks)
                .expand((b) => b.movements)) {
          final before = jsonEncode(m.toJson());
          MovementPrescriptionReview.fromMovement(m);
          expect(jsonEncode(m.toJson()), before);
          count++;
        }
      }
      expect(count, 1570);
      expect({
        for (final p in paths)
          p: sha256.convert(File(p).readAsBytesSync()).toString(),
      }, digests);
      final apollo = catalog.programmes.first;
      expect(
        apollo.classification,
        ProgrammeReviewClassification.internalPersonal,
      );
      expect(
        apollo.compile.contentHashSha256,
        '810334293c72aa2804ebd8bc2a426ca9f3e4977aed3da00989f67ae949dd0b83',
      );
    },
  );
  test(
    'immutable pre-existing v1 review transport still reopens and re-exports exactly',
    () async {
      final text = File(
        'docs/checkpoints/programme_studio_strength_lineages/ORIGINAL_V1_HANDOFF.json',
      ).readAsStringSync();
      final c = SyntheticCompositionController();
      await c.ready;
      addTearDown(c.dispose);
      expect(await c.reopen(text), true, reason: c.errors.join(' '));
      expect(c.reconstructedExport(), text);
    },
  );
  test(
    'read-only coverage grants no editing trust; unsupported shape/profile refuses with live workspace intact',
    () async {
      final c = SyntheticCompositionController();
      await c.ready;
      addTearDown(c.dispose);
      final r = await changed(c);
      final p = (await c.prepareUseVersion('W1D1S1', r))!;
      final editable = (await c.saveEditableWorkspace())!;
      final source = c.programme.draftSource, available = c.admitted;
      final tampered = jsonDecode(editable) as Map<String, dynamic>;
      final frozen = tampered['owners'][0]['catalogue']['frozen'][0] as Map;
      final original = frozen['source'] as String;
      frozen['source'] = original.replaceFirstMapped(
        RegExp(r'^(\s*)sets: 2$', multiLine: true),
        (m) => '${m[1]}rir: 0\n${m[0]}',
      );
      expect(frozen['source'], isNot(original));
      await expectLater(
        c.prepareEditableWorkspace(jsonEncode(tampered)),
        throwsA(isA<FormatException>()),
      );
      expect(c.programme.draftSource, source);
      expect(c.admitted, available);
      expect(selection(c), 'SYN-D2-STRENGTH-R1');
      expect(c.isCurrentVersionUse(p), true);
      expect(await c.usePreparedVersion(p), true);
      final packet = (await c.exportHandoff())!;
      final bundle = CanonicalSourceBundle.fromReview(c.current!);
      expect(bundle.files['review.json'], packet);
      expect(await c.reopen(packet), true);
      expect(c.reconstructedExport(), packet);
      final restored =
          await SyntheticCompositionController.restoreEditableWorkspace(
            (await c.saveEditableWorkspace())!,
          );
      addTearDown(restored.dispose);
      expect(selection(restored), 'SYN-D2-STRENGTH-R2');
    },
  );
}
