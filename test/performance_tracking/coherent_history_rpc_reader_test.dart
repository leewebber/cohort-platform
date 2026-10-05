import 'dart:convert';

import 'package:cohort_platform/application/performance_tracking/coherent_history_rpc_reader.dart';
import 'package:cohort_platform/application/performance_tracking/history_tracking_adapter.dart';
import 'package:cohort_platform/domain/performance_tracking/performance_tracking.dart';
import 'package:flutter_test/flutter_test.dart';

import 'history_tracking_fixtures.dart';

const actor = 'c2000000-0000-4000-8000-000000000001';
const other = 'c2000000-0000-4000-8000-000000000002';
const recordId = 'c2000000-0000-4000-8000-000000000010';
const blockId = 'c2000000-0000-4000-8000-000000000011';
const exerciseId = 'c2000000-0000-4000-8000-000000000012';
const setId = 'c2000000-0000-4000-8000-000000000013';
const auditId = 'c2000000-0000-4000-8000-000000000014';

Map<String, Object?> wire() =>
    jsonDecode(jsonEncode(_wire())) as Map<String, Object?>;

Map<String, Object?> _wire() => {
  'status': 'ok',
  'athlete_id': actor,
  'consistency': 'single_statement_snapshot',
  'complete_record_tree': true,
  'complete_audit_set': true,
  'counts': {'blocks': 1, 'exercises': 1, 'sets': 1, 'corrections': 1},
  'record': {
    ...SyntheticHistory.record(),
    'record_id': recordId,
    'athlete_id': actor,
  },
  'blocks': [
    {
      ...SyntheticHistory.block(),
      'block_result_id': blockId,
      'session_record_id': recordId,
    },
  ],
  'exercises': [
    {
      ...SyntheticHistory.exercise(),
      'exercise_result_id': exerciseId,
      'block_result_id': blockId,
    },
  ],
  'sets': [
    {
      ...SyntheticHistory.set(),
      'set_result_id': setId,
      'exercise_result_id': exerciseId,
    },
  ],
  'corrections': [
    {
      ...SyntheticHistory.audit(),
      'correction_id': auditId,
      'record_id': recordId,
      'athlete_id': actor,
      'before_values': {
        'set:$setId': {'reps': 2},
      },
      'after_values': {
        'set:$setId': {'reps': 3},
      },
    },
  ],
};

class FakeRpc implements HistoryTrackingRpcClient {
  FakeRpc(this.response);
  Object? response;
  String? actorId = actor;
  int calls = 0;
  Map<String, Object?>? lastClaim;
  void Function()? duringRead;
  @override
  String? get authenticatedAthleteId => actorId;
  @override
  Future<Object?> readTrackingHistory({
    required String recordId,
    required Map<String, Object?>? programmeClaim,
  }) async {
    calls++;
    lastClaim = programmeClaim;
    duringRead?.call();
    return response;
  }
}

HistoryProgrammeClaim claim({
  String block = 'synthetic.block',
  String trainingId = '17',
}) => HistoryProgrammeClaim(
  assignmentId: 'c2000000-0000-4000-8000-000000000020',
  occurrenceId: 'c2000000-0000-4000-8000-000000000021',
  trainingSessionId: trainingId,
  scope: TrackingProgrammeScope(
    programmeVersionId: 'c2000000-0000-4000-8000-000000000022',
    packageHash: SyntheticHistory.hashA,
    slotKey: 'synthetic.slot',
    protocolId: 'synthetic.protocol',
    protocolRevision: 1,
    blockId: block,
  ),
);
Matcher fails(String code) => throwsA(
  isA<HistoryTrackingReadException>().having((e) => e.code, 'code', code),
);

void main() {
  test(
    'raw rows, exact parent identities and incomplete audit payload survive',
    () async {
      final r = FakeRpc(wire());
      final frame = await CoherentHistoryRpcReader(
        r,
      ).readCurrentRecord(recordId);
      expect(frame.record!['record_id'], recordId);
      expect(frame.sets.single['duration_seconds'], 12);
      expect(frame.corrections.single['after_values'], {
        'set:$setId': {'reps': 3},
      });
      expect(frame.programmeWitness, isNull);
      expect(r.lastClaim, isNull);
      expect(() => frame.sets.single['reps'] = 7, throwsUnsupportedError);
    },
  );
  test('missing and inaccessible share one empty frame', () async {
    final r = FakeRpc({'status': 'no_visible_record', 'athlete_id': actor});
    final f = await CoherentHistoryRpcReader(r).readCurrentRecord(recordId);
    expect(f.record, isNull);
    expect(f.completeAuditSet, isTrue);
  });
  test('no auth or malformed identity never invokes RPC', () async {
    final r = FakeRpc(wire())..actorId = null;
    await expectLater(
      CoherentHistoryRpcReader(r).readCurrentRecord(recordId),
      fails('ownership_denied'),
    );
    r.actorId = actor;
    await expectLater(
      CoherentHistoryRpcReader(r).readCurrentRecord('not-uuid'),
      fails('invalid_record_id'),
    );
    expect(r.calls, 0);
  });
  test('actor switching while awaiting fails', () async {
    final r = FakeRpc(wire());
    r.duringRead = () => r.actorId = other;
    await expectLater(
      CoherentHistoryRpcReader(r).readCurrentRecord(recordId),
      fails('ownership_denied'),
    );
  });
  for (final entry in {
    'foreign owner': 'ownership_denied',
    'wrong record': 'record_identity_mismatch',
    'wrong parent': 'parent_mismatch',
    'wrong audit': 'correction_scope_mismatch',
    'duplicate': 'invalid_row_identity',
    'bad count': 'incomplete_evidence',
    'numeric count string': 'incomplete_evidence',
    'unknown keys': 'malformed_snapshot',
    'missing marker': 'malformed_snapshot',
    'false completeness': 'coherent_read_required',
    'invented witness': 'malformed_snapshot',
  }.entries) {
    test('rejects ${entry.key}', () async {
      final w = wire();
      switch (entry.key) {
        case 'foreign owner':
          (w['record'] as Map)['athlete_id'] = other;
        case 'wrong record':
          (w['record'] as Map)['record_id'] = other;
        case 'wrong parent':
          ((w['sets'] as List).single as Map)['exercise_result_id'] = other;
        case 'wrong audit':
          ((w['corrections'] as List).single as Map)['athlete_id'] = other;
        case 'duplicate':
          (w['sets'] as List).add((w['sets'] as List).single);
          (w['counts'] as Map)['sets'] = 2;
        case 'bad count':
          (w['counts'] as Map)['sets'] = 2;
        case 'numeric count string':
          (w['counts'] as Map)['sets'] = '1';
        case 'unknown keys':
          w['extra'] = true;
        case 'missing marker':
          w.remove('consistency');
        case 'false completeness':
          w['complete_audit_set'] = false;
        case 'invented witness':
          w['programme_witness'] = {'verified': true};
      }
      await expectLater(
        CoherentHistoryRpcReader(FakeRpc(w)).readCurrentRecord(recordId),
        fails(entry.value),
      );
    });
  }
  for (final code in [
    'programme_authority_unavailable',
    'programme_scope_unproven',
    'programme_scope_conflict',
    'invalid_programme_claim',
    'evidence_limit_exceeded',
  ]) {
    test('retains typed $code without fallback', () async {
      final rpc = FakeRpc({'status': 'failure', 'code': code});
      await expectLater(
        CoherentHistoryRpcReader(
          rpc,
        ).readCurrentRecord(recordId, programmeClaim: claim()),
        fails(code),
      );
      expect(rpc.calls, 1);
      expect(
        rpc.lastClaim!['programme_version_id'],
        claim().scope.programmeVersionId,
      );
      expect(rpc.lastClaim!['protocol_revision'], 1);
    });
  }
  test(
    'success cannot ignore supplied claim or accept unproven canonical package',
    () async {
      await expectLater(
        CoherentHistoryRpcReader(
          FakeRpc(wire()),
        ).readCurrentRecord(recordId, programmeClaim: claim()),
        fails('programme_authority_unavailable'),
      );
      final w = wire()..['canonical_package'] = '{}';
      await expectLater(
        CoherentHistoryRpcReader(FakeRpc(w)).readCurrentRecord(recordId),
        fails('malformed_snapshot'),
      );
    },
  );
  test('malformed claim rejected before transport', () async {
    final rpc = FakeRpc(wire());
    await expectLater(
      CoherentHistoryRpcReader(
        rpc,
      ).readCurrentRecord(recordId, programmeClaim: SyntheticHistory.claim()),
      fails('invalid_programme_claim'),
    );
    for (final invalid in [
      claim(trainingId: '9999999999999999999'),
      claim(block: List.filled(16384, 'x').join()),
    ]) {
      await expectLater(
        CoherentHistoryRpcReader(
          rpc,
        ).readCurrentRecord(recordId, programmeClaim: invalid),
        fails('invalid_programme_claim'),
      );
    }
    expect(rpc.calls, 0);
  });
  test('invalid envelopes and unknown failures never become missing', () async {
    for (final response in [
      null,
      [],
      {'status': 'failure', 'code': 'internal details'},
      {'status': 'no_visible_record'},
    ]) {
      await expectLater(
        CoherentHistoryRpcReader(FakeRpc(response)).readCurrentRecord(recordId),
        fails('malformed_snapshot'),
      );
    }
  });
  test('byte bound is explicit', () async {
    final w = wire();
    (w['record'] as Map)['athlete_note'] = List.filled(4194304, 'x').join();
    await expectLater(
      CoherentHistoryRpcReader(FakeRpc(w)).readCurrentRecord(recordId),
      fails('evidence_limit_exceeded'),
    );
  });
  test(
    'bridge integrates with extraction, tied audits and historical refusal',
    () async {
      final w = wire();
      final audits = w['corrections'] as List;
      audits.add({
        ...audits.single as Map,
        'correction_id': 'c2000000-0000-4000-8000-000000000015',
      });
      (w['counts'] as Map)['corrections'] = 2;
      final metric = SyntheticHistory.metric();
      final rpc = FakeRpc(w);
      final adapter = HistoryTrackingAdapter(
        reader: CoherentHistoryRpcReader(rpc),
        definitions: [SyntheticHistory.method(TrackingUnit.seconds), metric],
      );
      HistoryTrackingQuery query({bool historical = false}) =>
          HistoryTrackingQuery(
            athleteId: actor,
            metric: metric.reference,
            historical: historical,
            field: HistoryFieldSelection(
              recordId: recordId,
              blockResultId: blockId,
              sourceBlockId: 'synthetic.block',
              fieldPath: ['result_data', 'durationSeconds'],
            ),
          );
      final result = await adapter.read(query()) as HistoryTrackingObservation;
      expect(result.value, '12');
      expect(result.correctionIds, hasLength(2));
      expect(result.source.correctionId, isNull);
      expect(result.grantsPrescriptionEligibility, isFalse);
      expect(result.canReconstructHistoricalInputs, isFalse);
      final again = await adapter.read(query()) as HistoryTrackingObservation;
      expect(again.auditSetDigest, result.auditSetDigest);
      expect(jsonEncode(result.chronology), jsonEncode(again.chronology));
      final failure =
          await adapter.read(query(historical: true)) as HistoryTrackingFailure;
      expect(failure.code, 'historical_inputs_unavailable');
      rpc.response = {'status': 'failure', 'code': 'evidence_limit_exceeded'};
      expect(
        (await adapter.read(query()) as HistoryTrackingFailure).code,
        'evidence_limit_exceeded',
      );
    },
  );
}
