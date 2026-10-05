import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cohort_platform/application/performance_tracking/programme_history_rpc_reader.dart';
import 'package:cohort_platform/application/performance_tracking/history_tracking_adapter.dart';
import 'package:cohort_platform/domain/performance_tracking/performance_tracking.dart';
import 'history_tracking_fixtures.dart';

const actor = 'c2000000-0000-4000-8000-000000000001';
const recordId = 'c2000000-0000-4000-8000-000000000070';
Map<String, dynamic> wire() =>
    jsonDecode(
          File(
            'test/performance_tracking/fixtures/synthetic_programme_history_frame.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;
HistoryProgrammeClaim claim([Map<String, dynamic>? input]) {
  final c = (input ?? wire())['programme']['claim'] as Map;
  return HistoryProgrammeClaim(
    assignmentId: c['assignment_id'],
    occurrenceId: c['occurrence_id'],
    trainingSessionId: c['training_session_id'],
    scope: TrackingProgrammeScope(
      programmeVersionId: c['programme_version_id'],
      packageHash: c['package_hash'],
      slotKey: c['slot_key'],
      protocolId: c['protocol_id'],
      protocolRevision: c['protocol_revision'],
      blockId: c['block_id'],
      workoutId: c['workout_id'],
      stepId: c['step_id'],
      repeatOrdinal: c['repeat_ordinal'],
      mappingHash: c['mapping_hash'],
    ),
  );
}

final class FakeClient implements ProgrammeHistoryRpcClient {
  FakeClient(this.response);
  Object? response;
  String? actorId = actor;
  int calls = 0;
  bool changeActor = false;
  @override
  String? get authenticatedAthleteId => actorId;
  @override
  Future<Object?> readProgrammeHistory({
    required String recordId,
    required Map<String, Object?> programmeClaim,
  }) async {
    calls++;
    if (changeActor) actorId = 'c2000000-0000-4000-8000-000000000002';
    return response;
  }
}

void reseal(
  Map<String, dynamic> w,
  void Function(Map<String, dynamic>) change,
) {
  final a = w['programme']['artifact'] as Map;
  final s = jsonDecode(a['scope_seal_text'] as String) as Map<String, dynamic>;
  change(s);
  final text = jsonEncode(s);
  a['scope_seal_text'] = text;
  a['scope_seal_hash'] = sha256.convert(utf8.encode(text)).toString();
  w['programme']['current_scope'] = s;
}

void main() {
  test(
    'complete real-shaped synthetic RPC frame admits exact programme witness',
    () async {
      final client = FakeClient(wire());
      final frame = await ProgrammeHistoryRpcReader(
        client,
      ).readCurrentRecord(recordId, programmeClaim: claim());
      expect(client.calls, 1);
      expect(
        frame.programmeWitness!.scope.packageHash,
        claim().scope.packageHash,
      );
      expect(frame.corrections, hasLength(3));
      expect(frame.completeAuditSet, true);
    },
  );
  test(
    'adapter uses current actuals and keeps prescription/reconstruction false',
    () async {
      final metric = SyntheticHistory.metric();
      final adapter = HistoryTrackingAdapter(
        reader: ProgrammeHistoryRpcReader(FakeClient(wire())),
        definitions: [SyntheticHistory.method(TrackingUnit.seconds), metric],
      );
      final result = await adapter.read(
        HistoryTrackingQuery(
          athleteId: actor,
          metric: metric.reference,
          field: HistoryFieldSelection(
            recordId: recordId,
            blockResultId: 'c2000000-0000-4000-8000-000000000071',
            sourceBlockId: claim().scope.blockId,
            fieldPath: ['result_data', 'durationSeconds'],
          ),
          programmeClaim: claim(),
        ),
      );
      expect(result, isA<HistoryTrackingObservation>());
      expect(result.grantsPrescriptionEligibility, false);
      expect(result.canReconstructHistoricalInputs, false);
    },
  );
  final cases = <String, void Function(Map<String, dynamic>)>{
    'claim contradiction': (w) => w['programme']['claim']['slot_key'] = 'wrong',
    'artifact byte tampering': (w) =>
        w['programme']['artifact']['canonical_text'] += ' ',
    'seal byte tampering': (w) =>
        w['programme']['artifact']['scope_seal_text'] += ' ',
    'current graph drift': (w) =>
        w['programme']['current_scope']['sessions'][0]['blocks'][0]['content'] =
            'changed',
    'seal wrong version': (w) => reseal(
      w,
      (s) => s['programme_version_id'] = 'c2000000-0000-4000-8000-000000000099',
    ),
    'seal wrong revision': (w) =>
        reseal(w, (s) => s['sessions'][0]['revision_number'] = 2),
    'seal wrong block parent': (w) => reseal(
      w,
      (s) => s['sessions'][0]['blocks'][0]['session_id'] = 'foreign',
    ),
    'seal extra session': (w) =>
        reseal(w, (s) => s['sessions'].add(s['sessions'][0])),
    'seal duplicate block': (w) => reseal(
      w,
      (s) => s['sessions'][0]['blocks'].add(s['sessions'][0]['blocks'][0]),
    ),
    'seal wrong slot': (w) =>
        reseal(w, (s) => s['slots'][0]['slot_key'] = 'wrong'),
    'seal extra field': (w) => reseal(w, (s) => s['unproven'] = true),
    'unrecognized artifact provenance': (w) =>
        w['programme']['artifact']['publisher'] = 'client-supplied',
    'wrong scope contract': (w) =>
        w['programme']['artifact']['capture_contract'] = 'unknown.v2',
    'wrong actor': (w) =>
        w['record']['athlete_id'] = 'c2000000-0000-4000-8000-000000000002',
    'wrong assignment': (w) =>
        w['record']['assignment_id'] = 'c2000000-0000-4000-8000-000000000099',
    'wrong slot parent': (w) => w['record']['programme_session_id'] =
        'c2000000-0000-4000-8000-000000000099',
    'wrong audit actor': (w) => w['corrections'][0]['actor_id'] =
        'c2000000-0000-4000-8000-000000000002',
    'audit incompleteness': (w) => w['counts']['corrections'] = 2,
    'response bound': (w) =>
        w['record']['session_snapshot'] = {'synthetic': 'x' * 4194304},
    'unknown success field': (w) => w['client_hash_authority'] = true,
    'malformed raw seal': (w) =>
        w['programme']['artifact']['scope_seal_text'] = '[]',
  };
  for (final entry in cases.entries) {
    test('rejects ${entry.key}', () async {
      final w = wire();
      entry.value(w);
      await expectLater(
        ProgrammeHistoryRpcReader(
          FakeClient(w),
        ).readCurrentRecord(recordId, programmeClaim: claim()),
        throwsA(isA<HistoryTrackingReadException>()),
      );
    });
  }
  test(
    'matching hash strings cannot substitute for canonical compiler validation',
    () async {
      final w = wire();
      final a = w['programme']['artifact'] as Map;
      final text = '${a['canonical_text']} ';
      final hash = sha256.convert(utf8.encode(text)).toString();
      a['canonical_text'] = text;
      a['package_content_hash'] = hash;
      w['programme']['claim']['package_hash'] = hash;
      await expectLater(
        ProgrammeHistoryRpcReader(
          FakeClient(w),
        ).readCurrentRecord(recordId, programmeClaim: claim(w)),
        throwsA(
          isA<HistoryTrackingReadException>().having(
            (e) => e.code,
            'code',
            'invalid_retained_artifact',
          ),
        ),
      );
    },
  );
  test(
    'retained B3 frame validates mapping and frozen owner scope independently',
    () async {
      final w =
          jsonDecode(
                File(
                  'test/performance_tracking/fixtures/synthetic_programme_running_history_frame.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final frame = await ProgrammeHistoryRpcReader(FakeClient(w))
          .readCurrentRecord(
            w['record']['record_id'] as String,
            programmeClaim: claim(w),
          );
      expect(frame.programmeWitness!.scope.workoutId, claim(w).scope.workoutId);
      final snapshot =
          (w['blocks'] as List)
                  .single['block_snapshot']['structuredRunningV1']['frozen_target_snapshot']
              as Map;
      snapshot['athlete_id'] = 'c2000000-0000-4000-8000-000000000002';
      await expectLater(
        ProgrammeHistoryRpcReader(FakeClient(w)).readCurrentRecord(
          w['record']['record_id'] as String,
          programmeClaim: claim(w),
        ),
        throwsA(isA<HistoryTrackingReadException>()),
      );
    },
  );
  test('running repeat cannot be inferred outside retained work scope', () async {
    final w =
        jsonDecode(
              File(
                'test/performance_tracking/fixtures/synthetic_programme_running_history_frame.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    w['programme']['claim']['repeat_ordinal'] = 2;
    await expectLater(
      ProgrammeHistoryRpcReader(FakeClient(w)).readCurrentRecord(
        w['record']['record_id'] as String,
        programmeClaim: claim(w),
      ),
      throwsA(isA<HistoryTrackingReadException>()),
    );
  });
  test('actor changes during RPC are denied', () async {
    final client = FakeClient(wire())..changeActor = true;
    await expectLater(
      ProgrammeHistoryRpcReader(
        client,
      ).readCurrentRecord(recordId, programmeClaim: claim()),
      throwsA(
        isA<HistoryTrackingReadException>().having(
          (e) => e.code,
          'code',
          'ownership_denied',
        ),
      ),
    );
  });
  for (final code in [
    'programme_scope_unproven',
    'programme_scope_conflict',
    'evidence_limit_exceeded',
  ]) {
    test('$code never falls back to independent History', () async {
      final client = FakeClient({'status': 'failure', 'code': code});
      await expectLater(
        ProgrammeHistoryRpcReader(
          client,
        ).readCurrentRecord(recordId, programmeClaim: claim()),
        throwsA(
          isA<HistoryTrackingReadException>().having(
            (e) => e.code,
            'code',
            code,
          ),
        ),
      );
      expect(client.calls, 1);
    });
  }
  test('programme reader requires a claim before transport', () async {
    final client = FakeClient(wire());
    await expectLater(
      ProgrammeHistoryRpcReader(client).readCurrentRecord(recordId),
      throwsA(isA<HistoryTrackingReadException>()),
    );
    expect(client.calls, 0);
  });
}
