import 'package:cohort_platform/application/performance_tracking/history_tracking_adapter.dart';
import 'package:cohort_platform/internal_review/performance_tracking/tracking_review_scenarios.dart';
import 'package:flutter_test/flutter_test.dart';

List<Map> rows(TrackingReviewCase c, String key) =>
    (c.evaluation.content[key] as List? ?? []).cast<Map>();
List<Map> views(TrackingReviewCase c) => rows(
  c,
  'observations',
).expand((o) => (o['views'] as List).cast<Map>()).toList();
Map view(TrackingReviewCase c, String alias) =>
    views(c).singleWhere((v) => (v['aliases'] as List).contains(alias));

void main() {
  for (final scenario in TrackingReviewScenario.values) {
    test(
      '${scenario.name} uses exact C2 envelopes and deterministic C3 output',
      () async {
        for (final c in await buildTrackingReviewScenario(scenario)) {
          expect(c.evaluation.canonicalJson, c.reevaluate().canonicalJson);
          expect(
            c.evaluation.canonicalJson,
            c.reevaluate(reverseInputs: true).canonicalJson,
          );
          expect(c.evaluation.grantsPrescriptionEligibility, isFalse);
          expect(c.evaluation.canReconstructHistoricalInputs, isFalse);
          expect(
            c.evaluation.content['grants_prescription_eligibility'],
            isFalse,
          );
          expect(
            c.evaluation.content['can_reconstruct_historical_inputs'],
            isFalse,
          );
          for (final input in c.inputs) {
            expect(input.result.grantsPrescriptionEligibility, isFalse);
            expect(input.result.canReconstructHistoricalInputs, isFalse);
            expect(
              c.definitions.any(
                (d) => d.reference.digest == input.query.metric.digest,
              ),
              isTrue,
            );
          }
          for (final v in views(c)) {
            expect(v['grants_prescription_eligibility'], isFalse);
            expect(v['can_reconstruct_historical_inputs'], isFalse);
          }
        }
      },
    );
  }

  test(
    'complete profile preserves exact facts and comparable operands without arithmetic',
    () async {
      final c = (await buildTrackingReviewScenario(
        TrackingReviewScenario.complete,
      )).single;
      expect(view(c, 'a')['value'], '12');
      expect(view(c, 'b')['value'], '14');
      expect(view(c, 'a')['unit'], 'seconds');
      expect(
        (view(c, 'a')['chronology'] as Map)['performed_at'],
        '2026-01-01T12:00:00.000Z',
      );
      expect(
        (view(c, 'b')['chronology'] as Map)['performed_at'],
        '2026-01-08T12:00:00.000Z',
      );
      expect(rows(c, 'comparisons').single['state'], 'comparable');
      expect(rows(c, 'comparisons').single['reasons'], isEmpty);
      for (final key in ['difference', 'score', 'rank', 'improvement']) {
        expect(c.evaluation.content.containsKey(key), isFalse);
        expect(rows(c, 'comparisons').single.containsKey(key), isFalse);
      }
    },
  );

  test(
    'missing partial skipped and unavailable are honest; partial session has a complete field',
    () async {
      final c = (await buildTrackingReviewScenario(
        TrackingReviewScenario.missing,
      )).single;
      expect(c.evaluation.isFailure, isFalse);
      expect(view(c, 'complete-field')['tracking_eligible'], isTrue);
      for (final alias in ['missing', 'partial', 'skipped', 'unavailable']) {
        expect(view(c, alias)['state'], alias);
        expect(view(c, alias)['tracking_eligible'], isFalse);
        expect(view(c, alias)['value'], isNull);
        expect((view(c, alias)['evidence'] as Map)['recorded_count'], 0);
      }
      expect(view(c, 'partial-visible')['value'], '12');
      expect(view(c, 'partial-visible')['state'], 'partial');
      expect(view(c, 'partial-visible')['tracking_eligible'], isFalse);
      expect(
        (view(c, 'unavailable')['chronology'] as Map)['precision'],
        'civil_date',
      );
      expect((view(c, 'unavailable')['chronology'] as Map)['timezone'], isNull);
      expect(rows(c, 'observations'), hasLength(5));
      for (final pair in rows(c, 'comparisons')) {
        expect(pair['state'], 'comparison_unavailable');
        expect(pair['reasons'], contains('evidence_not_available'));
      }
    },
  );

  test(
    'correction membership retains tied audit times and incomplete selected inputs',
    () async {
      final c = (await buildTrackingReviewScenario(
        TrackingReviewScenario.corrected,
      )).single;
      final v = views(c).single;
      expect(v['value'], '12');
      expect(v['state'], 'available');
      expect(v['correction_ids'], hasLength(2));
      expect((v['source'] as Map)['correction_id'], 'synthetic.c4.audit.one');
      final audits = c.frames.single.corrections;
      expect(audits.map((a) => a['corrected_at']).toSet(), hasLength(1));
      for (final audit in audits) {
        expect(
          ((audit['after_values'] as Map).values.single as Map).containsKey(
            'duration_seconds',
          ),
          isFalse,
        );
      }
    },
  );

  test(
    'incompatible units methods context and unsupported difference stay explicit',
    () async {
      final cases = await buildTrackingReviewScenario(
        TrackingReviewScenario.incompatible,
      );
      expect(cases, hasLength(4));
      expect(view(cases[0], 'metres')['unit'], 'metres');
      expect(view(cases[0], 'metres')['value'], '12');
      expect(
        rows(cases[0], 'comparisons').single['reasons'],
        contains('unit_incompatible'),
      );
      expect(
        rows(cases[1], 'comparisons').single['reasons'],
        containsAll(['method_incompatible', 'metric_version_incompatible']),
      );
      expect(
        rows(cases[2], 'comparisons')[0]['reasons'],
        contains('context_incompatible:comparison_family'),
      );
      expect(
        rows(cases[2], 'comparisons')[1]['state'],
        'comparison_unavailable',
      );
      expect(cases[3].evaluation.failureCode, 'unsupported_method');
      expect(cases[3].inputs.single.result, isA<HistoryTrackingFailure>());
      expect(
        (cases[3].inputs.single.result as HistoryTrackingFailure).code,
        'unsupported_method',
      );
      expect(rows(cases[3], 'observations'), isEmpty);
    },
  );

  test(
    'aliases do not create attempts and conflicting aliases fail without a winner',
    () async {
      final cases = await buildTrackingReviewScenario(
        TrackingReviewScenario.aliases,
      );
      expect(rows(cases[0], 'observations'), hasLength(1));
      expect(views(cases[0]).single['aliases'], ['alias-a', 'alias-b']);
      expect(
        rows(cases[0], 'comparisons').single['reasons'],
        contains('same_observation'),
      );
      expect(cases[1].evaluation.failureCode, 'conflicting_source_aliases');
      expect(rows(cases[1], 'observations'), isEmpty);
    },
  );

  test(
    'independent eligibility does not grant programme attribution or replace failed reads',
    () async {
      final cases = await buildTrackingReviewScenario(
        TrackingReviewScenario.attribution,
      );
      expect(view(cases[0], 'independent')['tracking_eligible'], isTrue);
      expect(
        view(cases[0], 'independent')['programme_attribution'],
        'not_requested',
      );
      final failed =
          rows(
                cases[0],
                'inputs',
              ).singleWhere((r) => r['id'] == 'unproven')['outcome']
              as Map;
      expect(failed['state'], 'failure');
      expect(failed['programme_attribution'], 'unproven');
      expect(failed['reason'], 'programme_scope_unproven');
      expect(views(cases[1]).single['programme_attribution'], 'proven');
      expect(rows(cases[2], 'observations'), isEmpty);
      expect(
        (rows(cases[2], 'inputs').single['outcome']
            as Map)['programme_attribution'],
        'failed',
      );
    },
  );
}
