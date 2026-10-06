import 'dart:convert';

import 'package:cohort_platform/application/performance_tracking/history_tracking_adapter.dart';
import 'package:cohort_platform/application/performance_tracking/profile_tracking_evaluator.dart';
import 'package:cohort_platform/domain/performance_tracking/performance_tracking.dart';
import 'package:flutter_test/flutter_test.dart';

import 'history_tracking_fixtures.dart';

TrackingProfile profile(
  TrackingMetricDefinition metric, {
  String id = 'synthetic.profile',
  String? athlete,
  TrackingProfile? previous,
  int version = 1,
}) => TrackingProfile(
  id: id,
  version: version,
  kind: athlete == null
      ? TrackingProfileKind.curated
      : TrackingProfileKind.custom,
  name: 'Synthetic only',
  athleteId: athlete,
  previous: previous?.reference,
  metrics: [metric.reference],
);

TrackingMetricDefinition metric({
  String id = 'synthetic.metric',
  int version = 1,
  String field = 'durationSeconds',
  TrackingUnit unit = TrackingUnit.seconds,
  TrackingMethodDefinition? method,
  bool partial = false,
  bool assessment = false,
  int? freshness,
  List<String> context = const [],
}) => TrackingMetricDefinition(
  id: id,
  version: version,
  label: 'Synthetic only',
  unit: unit,
  method: (method ?? SyntheticHistory.method(unit)).reference,
  allowedSources: const [TrackingSourceKind.historyResult],
  captureField: field,
  allowPartial: partial,
  requiresAssessment: assessment,
  freshnessCivilDays: freshness,
  requiredContext: context,
);

List<TrackingArtifact> closure(TrackingMetricDefinition m, TrackingProfile p) =>
    [SyntheticHistory.method(m.unit), m, p];

HistoryFieldSelection otherField(
  HistoryFieldSelection f, {
  String suffix = '.second',
}) => HistoryFieldSelection(
  recordId: f.recordId + suffix,
  blockResultId: f.blockResultId + suffix,
  sourceBlockId: f.sourceBlockId + suffix,
  fieldPath: f.fieldPath,
  exerciseResultId: f.exerciseResultId == null
      ? null
      : f.exerciseResultId! + suffix,
  setResultId: f.setResultId == null ? null : f.setResultId! + suffix,
  workoutId: f.workoutId,
  stepId: f.stepId,
  repeatOrdinal: f.repeatOrdinal,
);

HistoryReadFrame otherFrame(HistoryReadFrame frame) {
  Object? rename(Object? v) {
    if (v is String &&
        [
          'synthetic.record',
          'synthetic.block-result',
          'synthetic.block',
          'synthetic.exercise-result',
          'synthetic.set-result',
        ].contains(v)) {
      return '$v.second';
    }
    if (v is Map) return v.map((k, v) => MapEntry(k, rename(v)));
    if (v is List) return v.map(rename).toList();
    return v;
  }

  return HistoryReadFrame(
    athleteId: frame.athleteId,
    consistency: frame.consistency,
    completeRecordTree: frame.completeRecordTree,
    completeAuditSet: frame.completeAuditSet,
    record: (rename(frame.record) as Map).cast<String, Object?>(),
    blocks: frame.blocks
        .map((b) => (rename(b) as Map).cast<String, Object?>())
        .toList(),
    exercises: frame.exercises
        .map((b) => (rename(b) as Map).cast<String, Object?>())
        .toList(),
    sets: frame.sets
        .map((b) => (rename(b) as Map).cast<String, Object?>())
        .toList(),
  );
}

Future<TrackingEvaluationInput> input(
  String id,
  TrackingMetricDefinition m, {
  HistoryReadFrame? frame,
  HistoryFieldSelection? field,
  HistoryProgrammeClaim? claim,
  List<TrackingArtifact>? definitions,
}) async {
  final query = HistoryTrackingQuery(
    athleteId: 'synthetic.athlete',
    metric: m.reference,
    field: field ?? SyntheticHistory.field(name: m.captureField),
    programmeClaim: claim,
  );
  final result = await HistoryTrackingAdapter(
    reader: FakeHistoryReader(frame ?? SyntheticHistory.frame()),
    definitions: definitions ?? [SyntheticHistory.method(m.unit), m],
  ).read(query);
  return TrackingEvaluationInput(id: id, query: query, result: result);
}

ProfileTrackingEvaluation evaluate(
  TrackingMetricDefinition m,
  TrackingProfile p,
  List<TrackingEvaluationInput> inputs, {
  List<TrackingArtifact>? definitions,
  List<TrackingProfileRequest>? profiles,
  List<TrackingComparisonRequest> comparisons = const [],
}) => ProfileTrackingEvaluator(definitions: definitions ?? closure(m, p))
    .evaluate(
      athleteId: 'synthetic.athlete',
      profiles: profiles ?? [TrackingProfileRequest(profile: p.reference)],
      inputs: inputs,
      comparisons: comparisons,
    );

TrackingComparisonRequest pair(
  TrackingMetricDefinition m, {
  String left = 'a',
  String right = 'b',
}) => TrackingComparisonRequest(
  id: 'synthetic.pair',
  metric: m.reference,
  policy: TrackingComparabilityPolicy.reference,
  leftInputId: left,
  rightInputId: right,
);
List<dynamic> observations(ProfileTrackingEvaluation e) =>
    e.content['observations'] as List;
Map<dynamic, dynamic> view(ProfileTrackingEvaluation e) =>
    ((observations(e).first as Map)['views'] as List).first as Map;
Map<dynamic, dynamic> comparison(ProfileTrackingEvaluation e) =>
    (e.content['comparisons'] as List).first as Map;
TrackingEvaluationInput replace(
  TrackingEvaluationInput original,
  HistoryTrackingResult result, {
  String? id,
  HistoryTrackingQuery? query,
}) => TrackingEvaluationInput(
  id: id ?? original.id,
  query: query ?? original.query,
  result: result,
);
HistoryTrackingObservation edit(
  HistoryTrackingObservation o, {
  String? value,
  TrackingUnit? unit,
  List<String>? audits,
  String? auditDigest,
  Map<String, String>? context,
  Map<String, Object?>? chronology,
}) => HistoryTrackingObservation(
  source: o.source,
  sourceIdentity: o.sourceIdentity,
  evidence: o.evidence,
  unit: unit ?? o.unit,
  value: value ?? o.value,
  context: context ?? o.context,
  chronology: chronology ?? o.chronology,
  correctionIds: audits ?? o.correctionIds,
  auditSetDigest: auditDigest ?? o.auditSetDigest,
);

void main() {
  test(
    'extraction reuses C2 and zero remains an actual, never a default',
    () async {
      final m = metric();
      final p = profile(m);
      final block = SyntheticHistory.block();
      block['result_data'] = {'resultType': 'duration', 'durationSeconds': 0};
      final a = await input(
        'a',
        m,
        frame: SyntheticHistory.frame(blockRow: block),
      );
      final e = evaluate(m, p, [a]);
      expect(e.isFailure, isFalse);
      expect(view(e)['value'], '0');
      expect(view(e)['tracking_eligible'], isTrue);
      expect(e.grantsPrescriptionEligibility, isFalse);
      expect(e.canReconstructHistoricalInputs, isFalse);
    },
  );

  for (final spec in [
    ('durationSeconds', TrackingUnit.seconds, false, false),
    ('distance', TrackingUnit.metres, false, false),
    ('distance', TrackingUnit.kilometres, false, false),
    ('reps', TrackingUnit.count, true, false),
    ('load', TrackingUnit.kilograms, true, false),
    ('distance', TrackingUnit.metres, true, false),
    ('duration_seconds', TrackingUnit.seconds, true, false),
    ('paceSecondsPerKm', TrackingUnit.secondsPerKilometre, false, true),
  ]) {
    test(
      'supported field ${spec.$1} ${spec.$2} set=${spec.$3} running=${spec.$4}',
      () async {
        final m = metric(field: spec.$1, unit: spec.$2);
        final p = profile(m);
        final block = spec.$4
            ? SyntheticHistory.runningBlock()
            : SyntheticHistory.block();
        if (!spec.$3 && spec.$1 == 'distance') {
          block['result_type'] = 'distance';
          block['result_data'] = {
            'resultType': 'distance',
            'distance': 12,
            'distanceUnit': spec.$2 == TrackingUnit.metres ? 'm' : 'km',
          };
        }
        final a = await input(
          'a',
          m,
          frame: SyntheticHistory.frame(
            blockRow: block,
            exercises: spec.$3 ? [SyntheticHistory.exercise()] : [],
            sets: spec.$3 ? [SyntheticHistory.set()] : [],
          ),
          field: SyntheticHistory.field(
            name: spec.$1,
            fromSet: spec.$3,
            running: spec.$4,
          ),
        );
        final e = evaluate(m, p, [a]);
        expect(e.isFailure, isFalse);
        expect(view(e)['tracking_eligible'], isTrue);
        expect(view(e)['unit'], spec.$2.name);
        expect(view(e)['source'], contains('input_digest'));
      },
    );
  }

  test(
    'aliases and profiles share one physical source without dropping references',
    () async {
      final m = metric();
      final p = profile(m);
      final custom = profile(
        m,
        id: 'synthetic.custom',
        athlete: 'synthetic.athlete',
      );
      final a = await input('a', m);
      final b = replace(a, a.result, id: 'b');
      final e = evaluate(
        m,
        p,
        [a, b],
        definitions: [...closure(m, p), custom],
        profiles: [
          TrackingProfileRequest(profile: p.reference),
          TrackingProfileRequest(profile: custom.reference),
        ],
      );
      expect(observations(e), hasLength(1));
      expect((observations(e).first as Map)['views'], hasLength(1));
      expect(view(e)['aliases'], ['a', 'b']);
      expect(e.content['profiles'], hasLength(2));
      expect(
        comparison(evaluate(m, p, [a, b], comparisons: [pair(m)]))['reasons'],
        contains('same_observation'),
      );
    },
  );

  test(
    'distinct observations remain distinct and explicitly comparable',
    () async {
      final m = metric();
      final p = profile(m);
      final a = await input('a', m);
      final b = await input(
        'b',
        m,
        frame: otherFrame(SyntheticHistory.frame()),
        field: otherField(SyntheticHistory.field()),
      );
      final e = evaluate(m, p, [a, b], comparisons: [pair(m)]);
      expect(observations(e), hasLength(2));
      expect(comparison(e)['state'], 'comparable');
      final json = e.canonicalJson;
      expect(json, isNot(contains('delta')));
      expect(json, isNot(contains('score')));
    },
  );

  test(
    'input definition profile and audit membership order do not change output',
    () async {
      final m = metric();
      final p = profile(m);
      final a = await input('a', m);
      final b = await input(
        'b',
        m,
        frame: otherFrame(SyntheticHistory.frame()),
        field: otherField(SyntheticHistory.field()),
      );
      final e = evaluate(m, p, [a, b], comparisons: [pair(m)]);
      final reordered = evaluate(
        m,
        p,
        [b, a],
        definitions: closure(m, p).reversed.toList(),
        comparisons: [pair(m)],
      );
      expect(reordered.canonicalJson, e.canonicalJson);
      expect(reordered.digest, e.digest);
      expect(jsonDecode(e.canonicalJson), e.content);
      expect(
        () => (e.content['observations'] as List).clear(),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'wrong profile or metric version/digest never resolves latest',
    () async {
      final m = metric();
      final p = profile(m);
      final a = await input('a', m);
      final wrong = TrackingReference(id: p.id, version: 2, digest: p.digest);
      expect(
        evaluate(
          m,
          p,
          [a],
          profiles: [TrackingProfileRequest(profile: wrong)],
        ).failureCode,
        'unsupported_exact_reference',
      );
      final q = HistoryTrackingQuery(
        athleteId: a.query.athleteId,
        metric: TrackingReference(
          id: m.id,
          version: 1,
          digest: SyntheticHistory.hashA,
        ),
        field: a.query.field,
      );
      expect(
        evaluate(m, p, [replace(a, a.result, query: q)]).failureCode,
        'unsupported_exact_reference',
      );
      expect(
        evaluate(m, p, [a], definitions: [...closure(m, p), m]).failureCode,
        'invalid_definition_closure',
      );
    },
  );

  test('difference signatures and unsupported fields cannot be executed', () {
    final method = TrackingMethodDefinition(
      id: 'synthetic.difference',
      version: 1,
      kind: TrackingMethodKind.difference,
      inputUnits: [TrackingUnit.seconds, TrackingUnit.seconds],
      outputUnit: TrackingUnit.seconds,
    );
    final derived = TrackingMetricDefinition(
      id: 'synthetic.derived',
      version: 1,
      label: 'Synthetic only',
      unit: TrackingUnit.seconds,
      method: method.reference,
      allowedSources: [],
      captureField: 'durationSeconds',
    );
    final p = profile(derived);
    expect(
      evaluate(derived, p, [], definitions: [method, derived, p]).failureCode,
      'unsupported_method',
    );
    final unsupported = metric(field: 'plannedDuration');
    expect(
      evaluate(unsupported, profile(unsupported), []).failureCode,
      'unsupported_metric',
    );
    final signature = TrackingMethodDefinition(
      id: 'synthetic.extract',
      version: 1,
      kind: TrackingMethodKind.fieldExtraction,
      inputUnits: [TrackingUnit.metres],
      outputUnit: TrackingUnit.seconds,
    );
    expect(
      evaluate(
        unsupported,
        profile(unsupported),
        [],
        definitions: [signature, unsupported, profile(unsupported)],
      ).failureCode,
      'invalid_definition_closure',
    );
  });

  for (final state in ['missing', 'partial', 'skipped', 'unavailable']) {
    test('$state evidence preserves honest value and eligibility', () async {
      final m = metric(partial: true);
      final p = profile(m);
      final block = SyntheticHistory.block();
      if (state == 'missing') {
        block['status'] = 'not_started';
        block['result_data'] = null;
      }
      if (state == 'partial') block['status'] = 'in_progress';
      if (state == 'skipped') block['status'] = 'skipped';
      if (state == 'unavailable') {
        block['result_data'] = {'resultType': 'duration'};
      }
      final a = await input(
        'a',
        m,
        frame: SyntheticHistory.frame(blockRow: block),
      );
      final b = await input(
        'b',
        m,
        frame: otherFrame(SyntheticHistory.frame()),
        field: otherField(SyntheticHistory.field()),
      );
      final e = evaluate(m, p, [a, b], comparisons: [pair(m)]);
      final row = observations(e)
          .expand((o) => (o as Map)['views'] as List)
          .cast<Map>()
          .firstWhere((v) => (v['aliases'] as List).contains('a'));
      expect(row['state'], state);
      expect(row['tracking_eligible'], isFalse);
      expect(row['value'], state == 'partial' ? '12' : null);
      expect(comparison(e)['state'], 'comparison_unavailable');
    });
  }

  test(
    'partial policy projections differ without duplicating a raw observation',
    () async {
      final m = metric();
      final allowed = metric(id: 'synthetic.partial', partial: true);
      final p = profile(m);
      final block = SyntheticHistory.block()..['status'] = 'in_progress';
      final frame = SyntheticHistory.frame(blockRow: block);
      final a = await input('a', m, frame: frame);
      final b = await input('b', allowed, frame: frame);
      final e = evaluate(
        m,
        p,
        [a, b],
        definitions: [...closure(m, p), allowed],
      );
      expect(e.isFailure, isFalse);
      expect(observations(e), hasLength(1));
      expect((observations(e).first as Map)['views'], hasLength(2));
    },
  );

  test(
    'unit mismatch remains incomparable without implicit conversion',
    () async {
      final m = metric(field: 'distance', unit: TrackingUnit.kilometres);
      final p = profile(m);
      final block = SyntheticHistory.block()..['result_type'] = 'distance';
      block['result_data'] = {
        'resultType': 'distance',
        'distance': 12,
        'distanceUnit': 'm',
      };
      final a = await input(
        'a',
        m,
        frame: SyntheticHistory.frame(blockRow: block),
      );
      final e = evaluate(m, p, [a]);
      expect(view(e)['state'], 'incomparable');
      expect(view(e)['value'], '12');
      expect(view(e)['unit'], 'metres');
    },
  );

  test(
    'context mismatch and missing contexts retain explicit pair reasons',
    () async {
      final m = metric();
      final p = profile(m);
      final a = await input('a', m);
      final changed = SyntheticHistory.block();
      (changed['block_snapshot'] as Map)['comparisonFamily'] =
          'synthetic.other';
      final b = await input(
        'b',
        m,
        frame: otherFrame(SyntheticHistory.frame(blockRow: changed)),
        field: otherField(SyntheticHistory.field()),
      );
      expect(
        comparison(evaluate(m, p, [a, b], comparisons: [pair(m)]))['reasons'],
        contains('context_incompatible:comparison_family'),
      );
      final missing = SyntheticHistory.block();
      (missing['block_snapshot'] as Map).remove('comparisonFamily');
      final c = await input(
        'b',
        m,
        frame: otherFrame(SyntheticHistory.frame(blockRow: missing)),
        field: otherField(SyntheticHistory.field()),
      );
      expect(
        comparison(evaluate(m, p, [a, c], comparisons: [pair(m)]))['state'],
        'comparison_unavailable',
      );
    },
  );

  test(
    'method/version mismatch is explicit even beside missing evidence',
    () async {
      final m = metric();
      final p = profile(m);
      final otherMethod = TrackingMethodDefinition(
        id: 'synthetic.extract.other',
        version: 1,
        kind: TrackingMethodKind.fieldExtraction,
        inputUnits: [TrackingUnit.seconds],
        outputUnit: TrackingUnit.seconds,
      );
      final newer = metric(version: 2, method: otherMethod);
      final a = await input('a', m);
      final b = await input(
        'b',
        newer,
        field: otherField(SyntheticHistory.field()),
        frame: otherFrame(
          SyntheticHistory.frame(missingRecord: false, blocks: []),
        ),
        definitions: [otherMethod, newer],
      );
      final e = evaluate(
        m,
        p,
        [a, b],
        definitions: [...closure(m, p), otherMethod, newer],
        comparisons: [pair(m)],
      );
      expect(e.isFailure, isFalse);
      expect(comparison(e)['state'], 'incomparable');
      expect(
        comparison(e)['reasons'],
        containsAll([
          'method_incompatible',
          'metric_version_incompatible',
          'evidence_not_available',
        ]),
      );
    },
  );

  test(
    'correction provenance remains unordered and never becomes historical replay',
    () async {
      final m = metric();
      final p = profile(m);
      final a = await input(
        'a',
        m,
        field: SyntheticHistory.field(correction: 'synthetic.audit'),
        frame: SyntheticHistory.frame(
          audits: [
            SyntheticHistory.audit(),
            SyntheticHistory.audit(id: 'synthetic.audit.two'),
          ],
        ),
      );
      final e = evaluate(m, p, [a]);
      expect(e.isFailure, isFalse);
      expect(view(e)['state'], 'available');
      expect(view(e)['correction_ids'], [
        'synthetic.audit',
        'synthetic.audit.two',
      ]);
      expect((view(e)['source'] as Map)['correction_id'], 'synthetic.audit');
      expect(e.canReconstructHistoricalInputs, isFalse);
      final reordered = replace(
        a,
        edit(
          a.result as HistoryTrackingObservation,
          audits: ['synthetic.audit.two', 'synthetic.audit'],
        ),
      );
      expect(evaluate(m, p, [reordered]).canonicalJson, e.canonicalJson);
    },
  );

  test(
    'conflicting alias value or audit membership never chooses newest',
    () async {
      final m = metric();
      final p = profile(m);
      final a = await input('a', m);
      final o = a.result as HistoryTrackingObservation;
      for (final conflicting in [
        edit(o, value: '14'),
        edit(
          o,
          audits: ['synthetic.other'],
          auditDigest: SyntheticHistory.hashB,
        ),
      ]) {
        final b = replace(a, conflicting, id: 'b');
        expect(
          evaluate(m, p, [a, b]).failureCode,
          'conflicting_source_aliases',
        );
        expect(
          evaluate(m, p, [b, a]).canonicalJson,
          evaluate(m, p, [a, b]).canonicalJson,
        );
      }
    },
  );

  test(
    'legacy unproven programme claim does not poison independent actual',
    () async {
      final m = metric();
      final p = profile(m);
      final a = await input('a', m);
      final b = await input('b', m, claim: SyntheticHistory.claim());
      expect(
        (b.result as HistoryTrackingFailure).code,
        'programme_scope_unproven',
      );
      final e = evaluate(m, p, [a, b]);
      expect(e.isFailure, isFalse);
      expect(view(e)['tracking_eligible'], isTrue);
      expect(view(e)['programme_attribution'], 'not_requested');
      final failure =
          (e.content['inputs'] as List).cast<Map>().firstWhere(
                (r) => r['id'] == 'b',
              )['outcome']
              as Map;
      expect(failure['programme_attribution'], 'unproven');
      expect(failure['state'], 'failure');
      expect(evaluate(m, p, [b]).content['observations'], isEmpty);
    },
  );

  test(
    'trusted C2 witness can prove exact scope without prescription eligibility',
    () async {
      final m = metric();
      final p = profile(m);
      final a = await input(
        'a',
        m,
        claim: SyntheticHistory.claim(),
        frame: SyntheticHistory.frame(
          programmeWitness: SyntheticHistory.witness(),
        ),
      );
      final e = evaluate(m, p, [a]);
      expect(e.isFailure, isFalse);
      expect(view(e)['programme_attribution'], 'proven');
      expect(view(e)['grants_prescription_eligibility'], isFalse);
      final b = await input(
        'b',
        m,
        claim: SyntheticHistory.claim(
          value: SyntheticHistory.scope(slot: 'synthetic.wrong'),
        ),
        frame: SyntheticHistory.frame(
          programmeWitness: SyntheticHistory.witness(),
        ),
      );
      final bad = evaluate(m, p, [b]);
      expect(bad.isFailure, isFalse);
      expect(observations(bad), isEmpty);
      expect(
        ((bad.content['inputs'] as List).first as Map)['outcome'],
        containsPair('state', 'failure'),
      );
    },
  );

  test(
    'query reference and stale pins cannot be swapped after C2 read',
    () async {
      final m = metric();
      final p = profile(m);
      final a = await input('a', m);
      final wrong = HistoryTrackingQuery(
        athleteId: 'synthetic.athlete',
        metric: m.reference,
        field: otherField(a.query.field),
      );
      expect(
        evaluate(m, p, [replace(a, a.result, query: wrong)]).failureCode,
        'source_reference_conflict',
      );
      final stale = HistoryTrackingQuery(
        athleteId: 'synthetic.athlete',
        metric: m.reference,
        field: SyntheticHistory.field(digest: SyntheticHistory.hashB),
      );
      expect(
        evaluate(m, p, [replace(a, a.result, query: stale)]).failureCode,
        'source_reference_conflict',
      );
      final foreign = HistoryTrackingQuery(
        athleteId: 'synthetic.foreign',
        metric: m.reference,
        field: a.query.field,
      );
      expect(
        evaluate(m, p, [replace(a, a.result, query: foreign)]).failureCode,
        'ownership_denied',
      );
    },
  );

  test(
    'selection closure requires explicit upgrades and custom owner',
    () async {
      final m = metric();
      final p = profile(m);
      final next = profile(m, version: 2);
      final a = await input('a', m);
      final select = TrackingSelectionRevision(
        id: 'synthetic.selection',
        version: 1,
        athleteId: 'synthetic.athlete',
        action: TrackingSelectionAction.select,
        profile: p.reference,
        recordedAt: DateTime.utc(2026),
      );
      final upgrade = TrackingSelectionRevision(
        id: select.id,
        version: 2,
        athleteId: select.athleteId,
        action: TrackingSelectionAction.upgrade,
        profile: next.reference,
        previous: select.reference,
        recordedAt: DateTime.utc(2026, 1, 2),
      );
      final defs = [...closure(m, p), next, select, upgrade];
      expect(
        evaluate(
          m,
          p,
          [a],
          definitions: defs,
          profiles: [
            TrackingProfileRequest(
              profile: next.reference,
              selection: upgrade.reference,
            ),
          ],
        ).isFailure,
        isFalse,
      );
      expect(
        evaluate(
          m,
          p,
          [a],
          definitions: defs,
          profiles: [
            TrackingProfileRequest(
              profile: next.reference,
              selection: select.reference,
            ),
          ],
        ).failureCode,
        'selection_reference_conflict',
      );
      final custom = profile(m, athlete: 'synthetic.foreign');
      expect(evaluate(m, custom, []).failureCode, 'ownership_denied');
      final unannounced = TrackingSelectionRevision(
        id: select.id,
        version: 2,
        athleteId: select.athleteId,
        action: TrackingSelectionAction.revise,
        profile: next.reference,
        previous: select.reference,
        recordedAt: upgrade.recordedAt,
      );
      expect(
        evaluate(
          m,
          p,
          [],
          definitions: [...closure(m, p), next, select, unannounced],
        ).failureCode,
        'invalid_definition_closure',
      );
    },
  );

  test(
    'deselection, absent configuration and automatic latest stay distinct',
    () {
      final m = metric();
      final p = profile(m);
      final select = TrackingSelectionRevision(
        id: 'synthetic.selection',
        version: 1,
        athleteId: 'synthetic.athlete',
        action: TrackingSelectionAction.select,
        profile: p.reference,
        recordedAt: DateTime.utc(2026),
      );
      final deselect = TrackingSelectionRevision(
        id: select.id,
        version: 2,
        athleteId: select.athleteId,
        action: TrackingSelectionAction.deselect,
        profile: p.reference,
        previous: select.reference,
        recordedAt: DateTime.utc(2026, 1, 2),
      );
      final e = evaluate(
        m,
        p,
        [],
        definitions: [...closure(m, p), select, deselect],
        profiles: [
          TrackingProfileRequest(
            profile: p.reference,
            selection: deselect.reference,
          ),
        ],
      );
      expect(
        ((e.content['profiles'] as List).first as Map)['state'],
        'not_selected',
      );
      expect(
        evaluate(m, p, [], profiles: []).content['state'],
        'profile_not_configured',
      );
      expect(
        evaluate(
          m,
          p,
          [],
          profiles: [
            TrackingProfileRequest(
              profile: p.reference,
              automaticSelection: true,
            ),
          ],
        ).failureCode,
        'automatic_selection_unsupported',
      );
      expect(
        ((evaluate(m, p, []).content['profiles'] as List).first
            as Map)['members'],
        isNotEmpty,
      );
    },
  );

  test(
    'duplicate identities, invalid pair aliases and policy revisions fail explicitly',
    () async {
      final m = metric();
      final p = profile(m);
      final a = await input('a', m);
      expect(
        evaluate(m, p, [a, a]).failureCode,
        'duplicate_or_invalid_input_identity',
      );
      expect(
        evaluate(
          m,
          p,
          [a],
          profiles: [
            TrackingProfileRequest(profile: p.reference),
            TrackingProfileRequest(profile: p.reference),
          ],
        ).failureCode,
        'duplicate_profile_request',
      );
      expect(
        evaluate(m, p, [a], comparisons: [pair(m)]).failureCode,
        'comparison_input_not_found',
      );
      final req = TrackingComparisonRequest(
        id: 'synthetic.pair',
        metric: m.reference,
        policy: TrackingReference(
          id: 'same_metric_context_v1',
          version: 2,
          digest: TrackingComparabilityPolicy.reference.digest,
        ),
        leftInputId: 'a',
        rightInputId: 'a',
      );
      expect(
        evaluate(m, p, [a], comparisons: [req]).failureCode,
        'unsupported_comparison_policy',
      );
    },
  );
  test(
    'one actual can have different metric digests without another observation',
    () async {
      final m = metric();
      final second = metric(id: 'synthetic.metric.other');
      final p = profile(m);
      final a = await input('a', m);
      final b = await input('b', second);
      expect(
        (a.result as HistoryTrackingObservation).source.inputDigest,
        isNot((b.result as HistoryTrackingObservation).source.inputDigest),
      );
      final e = evaluate(m, p, [a, b], definitions: [...closure(m, p), second]);
      expect(e.isFailure, isFalse);
      expect(observations(e), hasLength(1));
      expect((observations(e).first as Map)['views'], hasLength(2));
    },
  );

  test(
    'different canonical units and method versions are never converted',
    () async {
      final m = metric(field: 'distance', unit: TrackingUnit.metres);
      final p = profile(m);
      final otherMethod = TrackingMethodDefinition(
        id: 'synthetic.extract.km',
        version: 2,
        kind: TrackingMethodKind.fieldExtraction,
        inputUnits: [TrackingUnit.kilometres],
        outputUnit: TrackingUnit.kilometres,
      );
      final km = metric(
        field: 'distance',
        unit: TrackingUnit.kilometres,
        version: 2,
        method: otherMethod,
      );
      HistoryReadFrame distance(String unit) {
        final row = SyntheticHistory.block()..['result_type'] = 'distance';
        row['result_data'] = {
          'resultType': 'distance',
          'distance': 12,
          'distanceUnit': unit,
        };
        return SyntheticHistory.frame(blockRow: row);
      }

      final a = await input('a', m, frame: distance('m'));
      final b = await input(
        'b',
        km,
        frame: otherFrame(distance('km')),
        field: otherField(SyntheticHistory.field(name: 'distance')),
        definitions: [otherMethod, km],
      );
      final e = evaluate(
        m,
        p,
        [a, b],
        definitions: [...closure(m, p), otherMethod, km],
        comparisons: [pair(m)],
      );
      expect(e.isFailure, isFalse);
      expect(comparison(e)['state'], 'incomparable');
      expect(
        comparison(e)['reasons'],
        containsAll([
          'unit_incompatible',
          'method_incompatible',
          'metric_version_incompatible',
        ]),
      );
      expect(observations(e), hasLength(2));
    },
  );

  test(
    'different selected field scopes cannot establish comparison equivalence',
    () async {
      final m = metric();
      final setMetric = metric(
        id: 'synthetic.set.duration',
        field: 'duration_seconds',
      );
      final p = profile(m);
      final a = await input('a', m);
      final b = await input(
        'b',
        setMetric,
        field: SyntheticHistory.field(name: 'duration_seconds', fromSet: true),
        frame: SyntheticHistory.frame(
          exercises: [SyntheticHistory.exercise()],
          sets: [SyntheticHistory.set()],
        ),
      );
      final e = evaluate(
        m,
        p,
        [a, b],
        definitions: [...closure(m, p), setMetric],
        comparisons: [pair(m)],
      );
      expect(comparison(e)['reasons'], contains('field_scope_incompatible'));
      expect(observations(e), hasLength(2));
    },
  );

  test(
    'running repetitions have distinct physical identity even in one result row',
    () async {
      final m = metric(
        field: 'paceSecondsPerKm',
        unit: TrackingUnit.secondsPerKilometre,
      );
      final p = profile(m);
      final first = SyntheticHistory.runningBlock();
      final second = SyntheticHistory.runningBlock();
      final snapshot =
          ((second['block_snapshot'] as Map)['structuredRunningV1'] as Map);
      ((snapshot['work_repetitions'] as List).first as Map)['repeat_ordinal'] =
          3;
      ((((second['result_data'] as Map)['intervals'] as List).first)
              as Map)['repeatOrdinal'] =
          3;
      final f = SyntheticHistory.field(name: 'paceSecondsPerKm', running: true);
      final another = HistoryFieldSelection(
        recordId: f.recordId,
        blockResultId: f.blockResultId,
        sourceBlockId: f.sourceBlockId,
        fieldPath: f.fieldPath,
        workoutId: f.workoutId,
        stepId: f.stepId,
        repeatOrdinal: 3,
      );
      final a = await input(
        'a',
        m,
        frame: SyntheticHistory.frame(blockRow: first),
        field: f,
      );
      final b = await input(
        'b',
        m,
        frame: SyntheticHistory.frame(blockRow: second),
        field: another,
      );
      final e = evaluate(m, p, [a, b]);
      expect(e.isFailure, isFalse);
      expect(observations(e), hasLength(2));
    },
  );

  test('assessment and unevaluated freshness stay ineligible', () async {
    for (final m in [
      metric(assessment: true),
      metric(freshness: 7),
      metric(context: ['synthetic_missing']),
    ]) {
      final p = profile(m);
      final e = evaluate(m, p, [await input('a', m)]);
      expect(e.isFailure, isFalse);
      expect(view(e)['state'], 'ineligible');
      expect(view(e)['tracking_eligible'], isFalse);
    }
    final manual = TrackingMetricDefinition(
      id: 'synthetic.manual',
      version: 1,
      label: 'Synthetic only',
      unit: TrackingUnit.seconds,
      method: SyntheticHistory.method(TrackingUnit.seconds).reference,
      allowedSources: [TrackingSourceKind.manualEntry],
      captureField: 'durationSeconds',
    );
    expect(
      evaluate(manual, profile(manual), []).failureCode,
      'unsupported_source',
    );
  });

  test(
    'optional bindings pin profile/version/hash without upgrading legacy scope',
    () async {
      final m = metric();
      final p = profile(m);
      final s = SyntheticHistory.scope();
      final binding = TrackingProgrammeBinding(
        id: 'synthetic.binding',
        version: 1,
        programmeVersionId: s.programmeVersionId,
        packageHash: s.packageHash,
        profile: p.reference,
      );
      final a = await input('a', m);
      final b = await input('b', m, claim: SyntheticHistory.claim());
      final e = evaluate(
        m,
        p,
        [a, b],
        definitions: [...closure(m, p), binding],
        profiles: [
          TrackingProfileRequest(
            profile: p.reference,
            programmeBinding: binding.reference,
          ),
        ],
      );
      expect(e.isFailure, isFalse);
      expect(view(e)['programme_attribution'], 'not_requested');
      final different = TrackingProgrammeBinding(
        id: 'synthetic.binding.other',
        version: 1,
        programmeVersionId: 'synthetic.other.version',
        packageHash: s.packageHash,
        profile: p.reference,
      );
      expect(
        evaluate(
          m,
          p,
          [a, b],
          definitions: [...closure(m, p), different],
          profiles: [
            TrackingProfileRequest(
              profile: p.reference,
              programmeBinding: different.reference,
            ),
          ],
        ).failureCode,
        'binding_scope_conflict',
      );
    },
  );

  test(
    'profile member order is authored but profiles and inputs are unordered',
    () async {
      final m = metric();
      final second = metric(id: 'synthetic.metric.other');
      final p = TrackingProfile(
        id: 'synthetic.profile',
        version: 1,
        kind: TrackingProfileKind.curated,
        name: 'Synthetic only',
        metrics: [second.reference, m.reference],
      );
      final custom = profile(
        m,
        id: 'synthetic.custom',
        athlete: 'synthetic.athlete',
      );
      final a = await input('a', m);
      final b = await input('b', second);
      final defs = [...closure(m, p), second, custom];
      final requests = [
        TrackingProfileRequest(profile: p.reference),
        TrackingProfileRequest(profile: custom.reference),
      ];
      final e = evaluate(m, p, [a, b], definitions: defs, profiles: requests);
      final other = evaluate(
        m,
        p,
        [b, a],
        definitions: defs.reversed.toList(),
        profiles: requests.reversed.toList(),
      );
      expect(other.digest, e.digest);
      final row = (e.content['profiles'] as List).cast<Map>().firstWhere(
        (r) => (r['profile'] as Map)['id'] == p.id,
      );
      expect(
        ((row['members'] as List).first as Map)['metric'],
        second.reference.toJson(),
      );
    },
  );

  test(
    'malformed or contradictory supplied projections fail without promotion',
    () async {
      final m = metric();
      final p = profile(m);
      final a = await input('a', m);
      final o = a.result as HistoryTrackingObservation;
      for (final malformed in [
        edit(o, value: '-1'),
        edit(o, value: '1.5'),
        edit(o, chronology: {}),
        edit(o, audits: ['synthetic.audit', 'synthetic.audit']),
      ]) {
        expect(evaluate(m, p, [replace(a, malformed)]).isFailure, isTrue);
      }
      expect(
        evaluate(m, p, [
          replace(a, edit(o, unit: TrackingUnit.milliseconds)),
        ]).failureCode,
        'malformed_source_unit',
      );
      final absent = replace(
        a,
        const HistoryTrackingAbsent('record_not_visible'),
      );
      expect(
        ((evaluate(m, p, [absent]).content['inputs'] as List).first
            as Map)['outcome'],
        containsPair('state', 'missing'),
      );
      final denied = replace(
        a,
        const HistoryTrackingFailure('ownership_denied'),
      );
      expect(
        ((evaluate(m, p, [denied]).content['inputs'] as List).first
            as Map)['outcome'],
        containsPair('state', 'failure'),
      );
    },
  );

  test(
    'unordered invalid requests fail deterministically before choosing any value',
    () async {
      final m = metric();
      final p = profile(m);
      final a = await input('a', m);
      final invalidQuery = HistoryTrackingQuery(
        athleteId: 'synthetic.foreign',
        metric: m.reference,
        field: a.query.field,
      );
      final invalid = replace(a, a.result, query: invalidQuery);
      expect(
        evaluate(m, p, [a, invalid]).canonicalJson,
        evaluate(m, p, [invalid, a]).canonicalJson,
      );
      expect(
        evaluate(m, p, [a, invalid]).failureCode,
        'duplicate_or_invalid_input_identity',
      );
      final req = pair(m);
      expect(
        evaluate(m, p, [a], comparisons: [req, req]).failureCode,
        'duplicate_or_invalid_comparison_identity',
      );
    },
  );
  test(
    'a result-row ID cannot claim different parents across separate outcomes',
    () async {
      final m = metric();
      final p = profile(m);
      final a = await input('a', m);
      final row = SyntheticHistory.block()
        ..['session_record_id'] = 'synthetic.record.second';
      final record = SyntheticHistory.record()
        ..['record_id'] = 'synthetic.record.second';
      final field = HistoryFieldSelection(
        recordId: 'synthetic.record.second',
        blockResultId: 'synthetic.block-result',
        sourceBlockId: 'synthetic.block',
        fieldPath: ['result_data', 'durationSeconds'],
      );
      final b = await input(
        'b',
        m,
        field: field,
        frame: SyntheticHistory.frame(recordRow: record, blockRow: row),
      );
      expect(b.result, isA<HistoryTrackingObservation>());
      expect(evaluate(m, p, [a, b]).failureCode, 'source_parent_conflict');
    },
  );

  test(
    'different fields of one record must retain coherent audit membership',
    () async {
      final m = metric();
      final loadMethod = TrackingMethodDefinition(
        id: 'synthetic.extract.load',
        version: 1,
        kind: TrackingMethodKind.fieldExtraction,
        inputUnits: [TrackingUnit.kilograms],
        outputUnit: TrackingUnit.kilograms,
      );
      final load = metric(
        id: 'synthetic.load',
        field: 'load',
        unit: TrackingUnit.kilograms,
        method: loadMethod,
      );
      final p = profile(m);
      final a = await input('a', m);
      final b = await input(
        'b',
        load,
        field: SyntheticHistory.field(name: 'load', fromSet: true),
        frame: SyntheticHistory.frame(
          exercises: [SyntheticHistory.exercise()],
          sets: [SyntheticHistory.set()],
          audits: [SyntheticHistory.audit()],
        ),
        definitions: [loadMethod, load],
      );
      expect(b.result, isA<HistoryTrackingObservation>());
      expect(
        evaluate(
          m,
          p,
          [a, b],
          definitions: [...closure(m, p), loadMethod, load],
        ).failureCode,
        'inconsistent_record_provenance',
      );
    },
  );
}
