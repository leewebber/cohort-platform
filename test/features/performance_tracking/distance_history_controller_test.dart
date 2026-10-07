import 'dart:async';

import 'package:cohort_platform/application/performance_tracking/distance_observations_profile.dart';
import 'package:cohort_platform/application/performance_tracking/history_tracking_adapter.dart';
import 'package:cohort_platform/domain/performance_tracking/performance_tracking.dart';
import 'package:cohort_platform/features/performance_tracking/distance_history_controller.dart';
import 'package:cohort_platform/internal_review/athlete_distance/synthetic_distance_history.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SyntheticDistanceHistory source;
  late DistanceHistoryController c;
  setUp(() {
    source = SyntheticDistanceHistory();
    c = source.controller();
  });
  tearDown(() async {
    c.dispose();
    await source.changes.close();
  });

  Future<void> open(int index) async {
    if (c.page.isEmpty) await c.loadPage();
    await c.toggleRecord(c.page[index]);
  }

  Future<void> choose(int record, int block) async => c.selectBlock(
    c.views[record].summary.id,
    c.views[record].candidates[block],
  );
  HistoryTrackingObservation observation(int index) =>
      c.views[index].input!.result as HistoryTrackingObservation;
  Map pair() => (c.evaluation!.content['comparisons'] as List).single as Map;

  test('approved exact closure is complete, extraction-only and immutable', () {
    expect(
      TrackingValidator().validate(DistanceObservationsProfile.definitions),
      isEmpty,
    );
    expect(
      DistanceObservationsProfile.metric.method.digest,
      DistanceObservationsProfile.method.digest,
    );
    expect(
      DistanceObservationsProfile.profile.metrics.single.digest,
      DistanceObservationsProfile.metric.digest,
    );
    expect(DistanceObservationsProfile.metric.allowPartial, isFalse);
    expect(DistanceObservationsProfile.metric.requiredContext, isEmpty);
    expect(
      () => DistanceObservationsProfile.definitions.clear(),
      throwsUnsupportedError,
    );
    expect(
      DistanceObservationsProfile.definitions.map((d) => d.digest).toList(),
      [
        '4534245267ad80461826294d32d660a4f8ea04cb5915adc19ea1885b9aa479ba',
        '86d3bc86a74d8e17e780cf7bc98ae46c4ba624f77bbfbea6bda3bb04d85c953d',
        '8023b1fe99318be5584fe7d49922df2d053f6557231c21a47104bc742f0539a4',
      ],
    );
  });
  test(
    'no silent multi-block selection; same titles have different exact identities',
    () async {
      await open(0);
      expect(c.views.single.selected, isNull);
      expect(c.evaluation, isNull);
      expect(c.views.single.candidates, hasLength(9));
      await choose(0, 1);
      expect(observation(0).value, '5');
      expect(observation(0).source.blockResultId, syntheticDistanceId(102));
      await choose(0, 0);
      expect(observation(0).value, '0');
      expect(
        source.reads,
        1,
        reason: 'same strict immutable record frame reused',
      );
    },
  );
  test(
    'adding/removing a record preserves independently evaluated chosen evidence',
    () async {
      await open(0);
      await choose(0, 1);
      await open(1);
      expect(c.evaluation!.content['observations'] as List, hasLength(1));
      await c.toggleRecord(c.page[1]);
      expect(c.evaluation!.content['observations'] as List, hasLength(1));
      expect(observation(0).value, '5');
    },
  );
  test(
    'at most two records, choices must come from owned metadata page',
    () async {
      await c.loadPage();
      await open(0);
      await open(1);
      await open(2);
      expect(c.views, hasLength(2));
      final outsider = DistanceRecordSummary(
        syntheticDistanceId(999),
        syntheticDistanceActor,
        '2026-09-01',
        'completed',
      );
      await c.toggleRecord(c.page[0]);
      await c.toggleRecord(outsider);
      expect(c.views, hasLength(1));
    },
  );
  for (final entry in {
    2: TrackingEvidenceState.unavailable,
    3: TrackingEvidenceState.partial,
    4: TrackingEvidenceState.skipped,
    5: TrackingEvidenceState.missing,
    7: TrackingEvidenceState.partial,
  }.entries) {
    test(
      'missing/partial/skipped scope ${entry.key} preserves state without value',
      () async {
        await open(0);
        await choose(0, entry.key);
        expect(observation(0).evidence.state, entry.value);
        expect(observation(0).value, isNull);
        expect(c.evaluation!.isFailure, isFalse);
      },
    );
  }
  test(
    'incompatible metres are visible, preserved and never converted',
    () async {
      await open(0);
      await choose(0, 6);
      expect(observation(0).value, '500');
      expect(observation(0).unit, TrackingUnit.metres);
      expect(observation(0).evidence.state, TrackingEvidenceState.incomparable);
      expect(observation(0).trackingEligible, isFalse);
    },
  );
  test(
    'unsupported unit remains a candidate with explicit C2/C3 failed outcome',
    () async {
      await open(0);
      await choose(0, 8);
      expect(
        (c.views.single.input!.result as HistoryTrackingFailure).code,
        'unsupported_source_unit',
      );
      expect(
        (c.evaluation!.content['inputs'] as List).single['outcome']['state'],
        'failure',
      );
    },
  );
  test(
    'corrected current observation keeps audits without reconstruction',
    () async {
      await open(2);
      await choose(0, 0);
      expect(observation(0).value, '5');
      expect(observation(0).correctionIds, [syntheticDistanceId(901)]);
      expect(
        observation(0).source.correctionId,
        isNull,
        reason: 'no latest audit selected',
      );
      expect(c.evaluation!.canReconstructHistoricalInputs, isFalse);
      expect(c.evaluation!.grantsPrescriptionEligibility, isFalse);
    },
  );
  test(
    'pair requested explicitly, actual C3 admits matching recorded context',
    () async {
      await open(0);
      await open(1);
      await choose(0, 1);
      await choose(1, 0);
      expect(c.evaluation!.content['comparisons'], isEmpty);
      c.compare();
      expect(pair()['state'], 'comparable');
      expect(pair()['reasons'], isEmpty);
    },
  );
  test(
    'missing context keeps independent observations while refusing comparison',
    () async {
      await open(0);
      await open(1);
      await choose(0, 1);
      await choose(1, 1);
      c.compare();
      expect(observation(0).trackingEligible, isTrue);
      expect(observation(1).trackingEligible, isTrue);
      expect(pair()['state'], 'comparison_unavailable');
      expect(pair()['reasons'], ['context_unavailable:comparison_family']);
    },
  );
  test(
    'different context and incompatible units preserve every refusal',
    () async {
      await open(0);
      await open(1);
      await choose(0, 6);
      await choose(1, 2);
      c.compare();
      expect(pair()['state'], 'incomparable');
      expect(
        pair()['reasons'],
        containsAll([
          'unit_incompatible',
          'context_incompatible:comparison_family',
          'evidence_not_available',
        ]),
      );
    },
  );
  test(
    'refresh clears all choices and explicitly gets new current frames',
    () async {
      await open(0);
      await choose(0, 1);
      await c.refresh();
      expect(c.views, isEmpty);
      expect(c.evaluation, isNull);
      await open(0);
      expect(source.reads, 2);
    },
  );
  test(
    'sign-out clears visible evidence synchronously and makes no new read',
    () async {
      await open(0);
      await choose(0, 1);
      source.signOut();
      expect(c.page, isEmpty);
      expect(c.views, isEmpty);
      expect(c.evaluation, isNull);
      expect(c.identityValid, isFalse);
      await c.loadPage();
      expect(source.reads, 1);
    },
  );
  test('account switch during metadata response discards response', () async {
    final waiting = Completer<void>();
    source.beforeList = () => waiting.future;
    final pending = c.loadPage();
    source.actor = syntheticDistanceId(2);
    waiting.complete();
    await pending;
    expect(c.page, isEmpty);
    expect(c.busy, isFalse);
    expect(c.identityValid, isFalse);
  });
  test(
    'account switch during RPC discards previous-account frame without event',
    () async {
      await c.loadPage();
      final waiting = Completer<void>();
      source.beforeRead = () => waiting.future;
      final pending = c.toggleRecord(c.page[0]);
      source.actor = syntheticDistanceId(2);
      waiting.complete();
      await pending;
      expect(c.views, isEmpty);
      expect(c.page, isEmpty);
      expect(c.busy, isFalse);
    },
  );
  test(
    'role denied or route override cannot supply ownership identity',
    () async {
      c.dispose();
      c = DistanceHistoryController(
        rpc: source,
        records: source,
        activeAthlete: () => null,
        identityChanges: source.changes.stream,
      );
      await c.loadPage();
      expect(c.page, isEmpty);
      expect(source.reads, 0);
    },
  );
  test('foreign/missing C2 record has same non-leaking absence', () async {
    await c.loadPage();
    source.envelopes.remove(c.page.first.id);
    await c.toggleRecord(c.page.first);
    expect(c.error, 'record_not_available');
    expect(c.views, isEmpty);
  });
  test(
    'strict bridge rejects malformed parents, incomplete frames and duplicate blocks',
    () async {
      await c.loadPage();
      final wire = source.envelopes[c.page.first.id]!;
      wire['complete_record_tree'] = false;
      await c.toggleRecord(c.page.first);
      expect(c.error, 'coherent_read_required');
      wire['complete_record_tree'] = true;
      (wire['blocks'] as List).first['session_record_id'] = syntheticDistanceId(
        999,
      );
      await c.toggleRecord(c.page.first);
      expect(c.error, 'parent_mismatch');
      (wire['blocks'] as List).first['session_record_id'] = c.page.first.id;
      (wire['blocks'] as List)[1]['block_result_id'] =
          (wire['blocks'] as List)[0]['block_result_id'];
      await c.toggleRecord(c.page.first);
      expect(c.error, 'invalid_row_identity');
    },
  );
}
