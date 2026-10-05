/// Unwired bridge for the versioned, single-statement History RPC. Never uses
/// the legacy multi-request hydration or supplies its own ownership identity.
library;

import 'dart:convert';

import 'history_tracking_adapter.dart';

/// Narrow transport port; no table reads, writes, fallback or role arguments.
abstract interface class HistoryTrackingRpcClient {
  String? get authenticatedAthleteId;
  Future<Object?> readTrackingHistory({
    required String recordId,
    required Map<String, Object?>? programmeClaim,
  });
}

final class CoherentHistoryRpcReader implements HistoryTrackingReadPort {
  const CoherentHistoryRpcReader(this.client);
  final HistoryTrackingRpcClient client;

  @override
  String? get authenticatedAthleteId => client.authenticatedAthleteId;

  @override
  Future<HistoryReadFrame> readCurrentRecord(
    String recordId, {
    HistoryProgrammeClaim? programmeClaim,
  }) async {
    final actor = authenticatedAthleteId;
    if (!_uuid(actor)) _fail('ownership_denied');
    if (!_uuid(recordId)) _fail('invalid_record_id');
    final claim = programmeClaim == null ? null : _claim(programmeClaim);
    Object? raw;
    try {
      raw = await client.readTrackingHistory(
        recordId: recordId,
        programmeClaim: claim,
      );
    } catch (_) {
      _fail('history_read_failed');
    }
    if (actor != authenticatedAthleteId) _fail('ownership_denied');
    final wire = _object(raw);
    final status = wire['status'];
    if (status == 'failure') {
      _keys(wire, const ['status', 'code']);
      final code = wire['code'];
      if (!_failureCodes.contains(code)) _fail('malformed_snapshot');
      _fail(code as String);
    }
    if (status == 'no_visible_record') {
      _keys(wire, const ['status', 'athlete_id']);
      if (wire['athlete_id'] != actor) _fail('ownership_denied');
      // The non-leaking absence envelope proves no programme attribution.
      // Preserve a supplied claim as explicit failure, never independent absence.
      if (claim != null) _fail('programme_scope_unproven');
      return HistoryReadFrame(
        athleteId: actor!,
        consistency: HistoryReadConsistency.singleStatementSnapshot,
        completeRecordTree: true,
        completeAuditSet: true,
        record: null,
      );
    }
    _keys(wire, const [
      'status',
      'athlete_id',
      'consistency',
      'complete_record_tree',
      'complete_audit_set',
      'counts',
      'record',
      'blocks',
      'exercises',
      'sets',
      'corrections',
    ]);
    if (status != 'ok' ||
        wire['consistency'] != 'single_statement_snapshot' ||
        wire['complete_record_tree'] != true ||
        wire['complete_audit_set'] != true) {
      _fail('coherent_read_required');
    }
    if (wire['athlete_id'] != actor) _fail('ownership_denied');
    // This migration cannot prove the actual training-session authority.
    // No success may ignore a supplied claim or manufacture a witness.
    if (claim != null) _fail('programme_authority_unavailable');
    final record = _object(wire['record']);
    if (record['athlete_id'] != actor) _fail('ownership_denied');
    if (record['record_id'] != recordId) _fail('record_identity_mismatch');
    final counts = _object(wire['counts']);
    _keys(counts, const ['blocks', 'exercises', 'sets', 'corrections']);
    final rows = <String, List<Map<String, Object?>>>{};
    var total = 0;
    for (final name in counts.keys) {
      final list = wire[name];
      final count = counts[name];
      if (list is! List || count is! int || count < 0 || count != list.length) {
        _fail('incomplete_evidence');
      }
      total += count;
      if (total > 10000) _fail('evidence_limit_exceeded');
      rows[name] = list.map(_object).toList();
    }
    try {
      if (utf8.encode(jsonEncode(wire)).length > 4194304) {
        _fail('evidence_limit_exceeded');
      }
    } on JsonUnsupportedObjectError {
      _fail('malformed_snapshot');
    }
    final blocks = _identities(rows['blocks']!, 'block_result_id');
    final exercises = _identities(rows['exercises']!, 'exercise_result_id');
    _identities(rows['sets']!, 'set_result_id');
    _identities(rows['corrections']!, 'correction_id');
    for (final b in rows['blocks']!) {
      if (b['session_record_id'] != recordId) _fail('parent_mismatch');
    }
    for (final e in rows['exercises']!) {
      if (!blocks.contains(e['block_result_id'])) _fail('parent_mismatch');
    }
    for (final s in rows['sets']!) {
      if (!exercises.contains(s['exercise_result_id'])) {
        _fail('parent_mismatch');
      }
    }
    for (final c in rows['corrections']!) {
      if (c['athlete_id'] != actor ||
          c['record_id'] != recordId ||
          c['training_session_id'] != record['training_session_id']) {
        _fail('correction_scope_mismatch');
      }
      if (c['corrected_at'] is! String ||
          c['before_values'] is! Map ||
          c['after_values'] is! Map) {
        _fail('malformed_snapshot');
      }
    }
    return HistoryReadFrame(
      athleteId: actor!,
      consistency: HistoryReadConsistency.singleStatementSnapshot,
      completeRecordTree: true,
      completeAuditSet: true,
      record: record,
      blocks: rows['blocks']!,
      exercises: rows['exercises']!,
      sets: rows['sets']!,
      corrections: rows['corrections']!,
    );
  }
}

const _failureCodes = {
  'ownership_denied',
  'invalid_record_id',
  'invalid_programme_claim',
  'programme_scope_unproven',
  'programme_scope_conflict',
  'programme_authority_unavailable',
  'evidence_limit_exceeded',
};
Never _fail(String code) => throw HistoryTrackingReadException(code);
bool _uuid(Object? value) =>
    value is String &&
    RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    ).hasMatch(value);
bool _hash(Object? value) =>
    value is String && RegExp(r'^[0-9a-f]{64}$').hasMatch(value);
bool _text(Object? value) =>
    value is String && value.isNotEmpty && value.trim() == value;
Map<String, Object?> _object(Object? raw) {
  if (raw is! Map || raw.keys.any((k) => k is! String)) {
    _fail('malformed_snapshot');
  }
  return Map<String, Object?>.from(raw);
}

void _keys(Map<String, Object?> wire, List<String> keys) {
  if (wire.length != keys.length || !keys.every(wire.containsKey)) {
    _fail('malformed_snapshot');
  }
}

Set<String> _identities(List<Map<String, Object?>> rows, String key) {
  final ids = <String>{};
  for (final r in rows) {
    final id = r[key];
    if (!_uuid(id) || !ids.add(id as String)) _fail('invalid_row_identity');
  }
  return ids;
}

Map<String, Object?> _claim(HistoryProgrammeClaim claim) {
  final s = claim.scope;
  final running =
      s.workoutId != null ||
      s.stepId != null ||
      s.repeatOrdinal != null ||
      s.mappingHash != null;
  if (!_uuid(claim.assignmentId) ||
      !_uuid(claim.occurrenceId) ||
      !_uuid(s.programmeVersionId) ||
      !_hash(s.packageHash) ||
      !RegExp(r'^[1-9][0-9]{0,18}$').hasMatch(claim.trainingSessionId) ||
      BigInt.parse(claim.trainingSessionId) >
          BigInt.parse('9223372036854775807') ||
      ![s.slotKey, s.protocolId, s.blockId].every(_text) ||
      s.protocolRevision < 1 ||
      s.protocolRevision > 999999999 ||
      (running &&
          (!_text(s.workoutId) ||
              !_text(s.stepId) ||
              s.repeatOrdinal == null ||
              s.repeatOrdinal! < 1 ||
              s.repeatOrdinal! > 999999999 ||
              !_hash(s.mappingHash)))) {
    _fail('invalid_programme_claim');
  }
  final payload = <String, Object?>{
    'assignment_id': claim.assignmentId,
    'occurrence_id': claim.occurrenceId,
    'training_session_id': claim.trainingSessionId,
    'programme_version_id': s.programmeVersionId,
    'package_hash': s.packageHash,
    'slot_key': s.slotKey,
    'protocol_id': s.protocolId,
    'protocol_revision': s.protocolRevision,
    'block_id': s.blockId,
    if (running) 'workout_id': s.workoutId,
    if (running) 'step_id': s.stepId,
    if (running) 'repeat_ordinal': s.repeatOrdinal,
    if (running) 'mapping_hash': s.mappingHash,
  };
  if (utf8.encode(jsonEncode(payload)).length > 16384) {
    _fail('invalid_programme_claim');
  }
  return payload;
}
