/// Synthetic wire envelopes only. Imported solely by preview and tests.
library;

import 'dart:async';
import 'dart:convert';

import '../../application/performance_tracking/coherent_history_rpc_reader.dart';
import '../../features/performance_tracking/distance_history_controller.dart';

const syntheticDistanceActor = 'd5000000-0000-4000-8000-000000000001';
String syntheticDistanceId(int n) =>
    'd5000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

final class SyntheticDistanceHistory
    implements HistoryTrackingRpcClient, DistanceRecordListPort {
  String? actor = syntheticDistanceActor;
  final changes = StreamController<void>.broadcast(sync: true);
  final envelopes = <String, Map<String, Object?>>{};
  int reads = 0;
  Future<void> Function()? beforeRead;
  Future<void> Function()? beforeList;
  SyntheticDistanceHistory() {
    envelopes[syntheticDistanceId(10)] = _wire(10, [
      _block(10, 101, 'Synthetic distance', value: 0),
      _block(10, 102, 'Synthetic distance', value: 5),
      _block(10, 103, 'Synthetic missing value', value: null),
      _block(10, 104, 'Synthetic partial', state: 'in_progress'),
      _block(10, 105, 'Synthetic skipped', state: 'skipped'),
      _block(10, 106, 'Synthetic not started', state: 'not_started'),
      _block(10, 107, 'Synthetic incompatible metres', value: 500, unit: 'm'),
      _block(
        10,
        108,
        'Synthetic incomplete endurance',
        type: 'endurance',
        complete: false,
      ),
      _block(10, 109, 'Synthetic unsupported unit', unit: 'miles'),
    ]);
    envelopes[syntheticDistanceId(20)] = _wire(20, [
      _block(20, 201, 'Synthetic comparison distance', value: 6),
      _block(20, 202, 'Synthetic missing context', family: null),
      _block(
        20,
        203,
        'Synthetic different context',
        family: 'synthetic.other.family',
      ),
    ]);
    final corrected = _block(30, 301, 'Synthetic corrected distance', value: 5);
    envelopes[syntheticDistanceId(30)] = _wire(
      30,
      [corrected],
      audits: [
        {
          'correction_id': syntheticDistanceId(901),
          'athlete_id': syntheticDistanceActor,
          'record_id': syntheticDistanceId(30),
          'training_session_id': 30,
          'corrected_at': '2026-09-15T12:00:00Z',
          'before_values': {
            'block:${syntheticDistanceId(301)}:result_data': {
              'resultType': 'distance',
              'distance': 4,
              'distanceUnit': 'km',
            },
          },
          'after_values': {
            'block:${syntheticDistanceId(301)}:result_data':
                corrected['result_data'],
          },
        },
      ],
    );
  }
  @override
  String? get authenticatedAthleteId => actor;
  @override
  Future<List<DistanceRecordSummary>> listOwned(
    String athleteId,
    int offset,
  ) async {
    await beforeList?.call();
    if (actor != athleteId) {
      throw StateError('ownership_denied');
    }
    if (offset > 0 || actor != syntheticDistanceActor) {
      return [];
    }
    return [
      for (final entry in envelopes.entries)
        DistanceRecordSummary(
          entry.key,
          athleteId,
          (entry.value['record'] as Map)['performed_on'] as String,
          'completed',
        ),
    ];
  }

  @override
  Future<Object?> readTrackingHistory({
    required String recordId,
    required Map<String, Object?>? programmeClaim,
  }) async {
    reads++;
    await beforeRead?.call();
    if (programmeClaim != null) {
      throw StateError('No programme claims in this preview');
    }
    if (actor != syntheticDistanceActor || !envelopes.containsKey(recordId)) {
      return {'status': 'no_visible_record', 'athlete_id': actor};
    }
    return jsonDecode(jsonEncode(envelopes[recordId]));
  }

  void signOut() {
    actor = null;
    changes.add(null);
  }

  DistanceHistoryController controller() => DistanceHistoryController(
    rpc: this,
    records: this,
    activeAthlete: () => actor,
    identityChanges: changes.stream,
  );
}

Map<String, Object?> _block(
  int record,
  int id,
  String title, {
  num? value = 3,
  String unit = 'km',
  String state = 'completed',
  String type = 'distance',
  bool complete = true,
  String? family = 'synthetic.distance.family.a',
}) => {
  'block_result_id': syntheticDistanceId(id),
  'session_record_id': syntheticDistanceId(record),
  'source_block_id': 'synthetic.source.$id',
  'status': state,
  'result_type': type,
  'block_snapshot': {
    'sourceBlockId': 'synthetic.source.$id',
    'title': title,
    'comparisonFamily': ?family,
  },
  'result_data': {
    'resultType': type,
    'distance': ?value,
    'distanceUnit': unit,
    if (type == 'endurance') 'completed': complete,
  },
};
Map<String, Object?> _wire(
  int id,
  List<Map<String, Object?>> blocks, {
  List<Map<String, Object?>> audits = const [],
}) => {
  'status': 'ok',
  'athlete_id': syntheticDistanceActor,
  'consistency': 'single_statement_snapshot',
  'complete_record_tree': true,
  'complete_audit_set': true,
  'counts': {
    'blocks': blocks.length,
    'exercises': 0,
    'sets': 0,
    'corrections': audits.length,
  },
  'record': {
    'record_id': syntheticDistanceId(id),
    'athlete_id': syntheticDistanceActor,
    'status': 'completed',
    'training_session_id': id,
    'performed_precision': 'date',
    'performed_on': id == 10
        ? '2026-09-01'
        : id == 20
        ? '2026-09-08'
        : '2026-09-15',
  },
  'blocks': blocks,
  'exercises': [],
  'sets': [],
  'corrections': audits,
};
