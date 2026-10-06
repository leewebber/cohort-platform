/// Unwired programme attribution over one owner-gated statement snapshot.
library;

import 'dart:convert';
import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:crypto/crypto.dart';
import 'coherent_history_rpc_reader.dart';
import 'history_tracking_adapter.dart';

abstract interface class ProgrammeHistoryRpcClient {
  String? get authenticatedAthleteId;
  Future<Object?> readProgrammeHistory({
    required String recordId,
    required Map<String, Object?> programmeClaim,
  });
}

final class ProgrammeHistoryRpcReader implements HistoryTrackingReadPort {
  const ProgrammeHistoryRpcReader(this.client);
  final ProgrammeHistoryRpcClient client;
  @override
  String? get authenticatedAthleteId => client.authenticatedAthleteId;

  @override
  Future<HistoryReadFrame> readCurrentRecord(
    String recordId, {
    HistoryProgrammeClaim? programmeClaim,
  }) async {
    try {
      return await _read(recordId, programmeClaim: programmeClaim);
    } on HistoryTrackingReadException {
      rethrow;
    } catch (_) {
      _fail('malformed_snapshot');
    }
  }

  Future<HistoryReadFrame> _read(
    String recordId, {
    HistoryProgrammeClaim? programmeClaim,
  }) async {
    final actor = authenticatedAthleteId;
    if (!_uuid(actor)) {
      _fail('ownership_denied');
    }
    if (!_uuid(recordId)) {
      _fail('invalid_record_id');
    }
    if (programmeClaim == null) {
      _fail('invalid_programme_claim');
    }
    final claim = encodeHistoryProgrammeClaim(programmeClaim);
    if (!_uuid(claim['block_id'])) {
      _fail('invalid_programme_claim');
    }
    Object? raw;
    try {
      raw = await client.readProgrammeHistory(
        recordId: recordId,
        programmeClaim: claim,
      );
    } catch (_) {
      _fail('history_read_failed');
    }
    if (actor != authenticatedAthleteId) {
      _fail('ownership_denied');
    }
    final wire = _map(raw);
    if (wire['status'] == 'failure') {
      // Reuse the deployed decoder's closed failure contract; no second read.
      return CoherentHistoryRpcReader(
        _FrameClient(actor!, wire),
      ).readCurrentRecord(recordId, programmeClaim: programmeClaim);
    }
    if (utf8.encode(jsonEncode(wire)).length > 4194304) {
      _fail('evidence_limit_exceeded');
    }
    final programme = _map(wire.remove('programme'));
    _keys(programme, ['claim', 'artifact', 'current_scope', 'witness']);
    if (_json(programme['claim']) != _json(claim)) {
      _fail('programme_scope_conflict');
    }
    final artifact = _map(programme['artifact']);
    _keys(artifact, [
      'programme_version_id',
      'package_schema_version',
      'package_content_hash',
      'canonical_text',
      'scope_seal_text',
      'scope_seal_hash',
      'compiler_release',
      'compiler_contract',
      'capture_contract',
      'captured_at',
      'publisher',
    ]);
    if (artifact['programme_version_id'] != claim['programme_version_id'] ||
        artifact['package_content_hash'] != claim['package_hash'] ||
        artifact['compiler_release'] != 'cohort_plan_package@1.0.0' ||
        artifact['compiler_contract'] !=
            'cohort_plan_package.v1-v2.canonical.v1' ||
        artifact['capture_contract'] != 'tracking.publication.scope.v1' ||
        artifact['publisher'] !=
            'publish_private_exact_programme_version_retained_v1' ||
        artifact['captured_at'] is! String ||
        DateTime.tryParse(artifact['captured_at'] as String) == null) {
      _fail('programme_scope_conflict');
    }
    final canonical = _attestedText(
      artifact['canonical_text'],
      artifact['package_content_hash'],
    );
    final compiled = const PlanPackageCompiler().verifyCanonicalArtifact(
      canonical,
    );
    if (!compiled.isValid ||
        compiled.canonicalJson != canonical ||
        compiled.contentHashSha256 != artifact['package_content_hash'] ||
        compiled.manifest!.packageSchemaVersion !=
            artifact['package_schema_version']) {
      _fail('invalid_retained_artifact');
    }
    final sealText = _attestedText(
      artifact['scope_seal_text'],
      artifact['scope_seal_hash'],
    );
    Object? decoded;
    try {
      decoded = jsonDecode(sealText);
    } catch (_) {
      _fail('invalid_retained_artifact');
    }
    final seal = _map(decoded);
    _keys(seal, [
      'schema_version',
      'programme_version_id',
      'package_hash',
      'sessions',
      'slots',
    ]);
    if (seal['schema_version'] != 1 ||
        seal['programme_version_id'] != claim['programme_version_id'] ||
        seal['package_hash'] != claim['package_hash'] ||
        _json(programme['current_scope']) != _json(seal)) {
      _fail('programme_scope_conflict');
    }
    // The seal's digest is separate from the canonical package hash. It attests
    // publication-time scope, not protocol immutability or performed tests.
    final sessions = _rows(seal['sessions']);
    final slots = _rows(seal['slots']);
    final manifest = compiled.manifest!;
    if (sessions.length != manifest.sessions.length) {
      _fail('invalid_retained_artifact');
    }
    final sessionKeys = <String>{};
    final allBlocks = <String>{};
    final allExercises = <String>{};
    for (final session in sessions) {
      _keys(session, [
        'session_key',
        'protocol_id',
        'session_lineage_id',
        'revision_number',
        'blocks',
      ]);
      if (session['session_key'] is! String ||
          !sessionKeys.add(session['session_key'] as String)) {
        _fail('invalid_retained_artifact');
      }
      final refs = manifest.sessions
          .where((r) => r.sessionKey == session['session_key'])
          .toList();
      if (refs.length != 1 ||
          refs.single.protocolId != session['protocol_id'] ||
          refs.single.sessionLineageId != session['session_lineage_id'] ||
          refs.single.revisionNumber != session['revision_number']) {
        _fail('programme_scope_conflict');
      }
      final blocks = _rows(session['blocks']);
      if (blocks.isEmpty) {
        _fail('invalid_retained_artifact');
      }
      for (final block in blocks) {
        _keys(block, [
          'block_id',
          'session_id',
          'position',
          'block_type',
          'title',
          'content',
          'workout_format',
          'timer_config',
          'coach_notes',
          'performance_capture_mode',
          'exercises',
        ]);
        if (!_uuid(block['block_id']) ||
            !allBlocks.add(block['block_id'] as String) ||
            block['session_id'] != session['protocol_id'] ||
            block['position'] is! int ||
            (block['position'] as int) < 1 ||
            block['block_type'] is! String ||
            block['title'] is! String ||
            block['content'] is! String ||
            block['workout_format'] is! String ||
            block['performance_capture_mode'] is! String) {
          _fail('invalid_retained_artifact');
        }
        for (final exercise in _rows(block['exercises'])) {
          _keys(exercise, [
            'id',
            'block_id',
            'exercise_id',
            'position',
            'display_label_override',
            'prescription',
            'execution_group_key',
            'execution_group_label',
            'execution_group_rounds',
          ]);
          if (exercise['exercise_id'] is! String ||
              exercise['position'] is! int ||
              (exercise['position'] as int) < 1) {
            _fail('invalid_retained_artifact');
          }
          if (!_uuid(exercise['id']) ||
              !allExercises.add(exercise['id'] as String) ||
              exercise['block_id'] != block['block_id']) {
            _fail('invalid_retained_artifact');
          }
        }
      }
    }
    final expectedSlots = <String, Map<String, Object?>>{};
    final canonicalTree = _map(jsonDecode(canonical));
    for (final week in _rows(canonicalTree['weeks'])) {
      for (final day in _rows(week['days'])) {
        for (final slot in _rows(day['slots'])) {
          final session = sessions.singleWhere(
            (s) => s['session_key'] == slot['session_key'],
          );
          expectedSlots[slot['slot_key'] as String] = {
            'slot_key': slot['slot_key'],
            'week_number': week['week_number'],
            'day_key': day['day_key'],
            'day_order': day['day_order'],
            'session_order': slot['session_order'],
            'protocol_id': session['protocol_id'],
            'authored_running_v1': slot['authored_running_v1'],
          };
        }
      }
    }
    if (slots.length != expectedSlots.length) {
      _fail('invalid_retained_artifact');
    }
    final slotIds = <String>{};
    final slotKeys = <String>{};
    for (final slot in slots) {
      _keys(slot, [
        'slot_id',
        'slot_key',
        'week_number',
        'day_key',
        'day_order',
        'session_order',
        'protocol_id',
        'authored_running_v1',
      ]);
      if (!_uuid(slot['slot_id']) ||
          !slotIds.add(slot['slot_id'] as String) ||
          slot['slot_key'] is! String ||
          !slotKeys.add(slot['slot_key'] as String)) {
        _fail('invalid_retained_artifact');
      }
      final shape = {...slot}..remove('slot_id');
      if (_json(shape) != _json(expectedSlots[slot['slot_key']])) {
        _fail('programme_scope_conflict');
      }
    }
    final selectedSlots = slots
        .where((s) => s['slot_key'] == claim['slot_key'])
        .toList();
    final selectedSessions = sessions
        .where(
          (s) =>
              s['protocol_id'] == claim['protocol_id'] &&
              s['revision_number'] == claim['protocol_revision'],
        )
        .toList();
    if (selectedSlots.length != 1 ||
        selectedSessions.length != 1 ||
        selectedSlots.single['protocol_id'] != claim['protocol_id']) {
      _fail('programme_scope_conflict');
    }
    final blockMatches = _rows(
      selectedSessions.single['blocks'],
    ).where((b) => b['block_id'] == claim['block_id']).toList();
    if (blockMatches.length != 1) {
      _fail('programme_scope_conflict');
    }
    final frame = await CoherentHistoryRpcReader(
      _FrameClient(actor!, wire),
    ).readCurrentRecord(recordId);
    for (final correction in frame.corrections) {
      if (correction['actor_id'] != actor) {
        _fail('correction_scope_mismatch');
      }
    }
    final record = frame.record!;
    if (record['assignment_id'] != claim['assignment_id'] ||
        record['training_session_id'].toString() !=
            claim['training_session_id'] ||
        record['source_protocol_id'] != claim['protocol_id'] ||
        record['programme_session_id'] != selectedSlots.single['slot_id'] ||
        frame.blocks
                .where((b) => b['source_block_id'] == claim['block_id'])
                .length !=
            1) {
      _fail('programme_scope_conflict');
    }
    _validateProgrammeLinks(
      programme['witness'],
      actor,
      record,
      claim,
      selectedSlots.single,
      artifact['package_schema_version'] as int,
    );
    if (claim.containsKey('workout_id')) {
      final running = _map(selectedSlots.single['authored_running_v1']);
      final b = frame.blocks.singleWhere(
        (b) => b['source_block_id'] == claim['block_id'],
      );
      final snapshot = _map(_map(b['block_snapshot'])['structuredRunningV1']);
      if (running['workout_id'] != claim['workout_id'] ||
          running['execution_mapping_sha256'] != claim['mapping_hash'] ||
          snapshot['workout_id'] != claim['workout_id'] ||
          snapshot['session_block_id'] != claim['block_id'] ||
          snapshot['package_content_hash'] != claim['package_hash'] ||
          snapshot['execution_mapping_sha256'] != claim['mapping_hash'] ||
          !_rows(running['executable_step_bindings']).any(
            (r) =>
                r['step_id'] == claim['step_id'] &&
                r['session_block_id'] == claim['block_id'],
          ) ||
          !_rows(snapshot['work_repetitions']).any(
            (r) =>
                r['workout_id'] == claim['workout_id'] &&
                r['session_block_id'] == claim['block_id'] &&
                r['authored_step_id'] == claim['step_id'] &&
                r['repeat_ordinal'] == claim['repeat_ordinal'],
          )) {
        _fail('programme_scope_conflict');
      }
      final frozen = _map(snapshot['frozen_target_snapshot']);
      if (frozen['athlete_id'] != actor ||
          frozen['assignment_id'] != claim['assignment_id'] ||
          frozen['occurrence_id'] != claim['occurrence_id'] ||
          frozen['programme_version_id'] != claim['programme_version_id'] ||
          frozen['session_slot_id'] != selectedSlots.single['slot_id'] ||
          frozen['package_content_hash'] != claim['package_hash']) {
        _fail('programme_scope_conflict');
      }
    }
    if (actor != authenticatedAthleteId) {
      _fail('ownership_denied');
    }
    return HistoryReadFrame(
      athleteId: actor,
      consistency: frame.consistency,
      completeRecordTree: true,
      completeAuditSet: true,
      record: record,
      blocks: frame.blocks,
      exercises: frame.exercises,
      sets: frame.sets,
      corrections: frame.corrections,
      programmeWitness: HistoryProgrammeWitness(
        athleteId: actor,
        recordId: recordId,
        assignmentId: programmeClaim.assignmentId,
        occurrenceId: programmeClaim.occurrenceId,
        trainingSessionId: programmeClaim.trainingSessionId,
        scope: programmeClaim.scope,
      ),
    );
  }
}

// These projections are derived from owned database rows in the same statement.
// Claim echo, artifact attestation and complete History alone do not prove these
// joins. No field is defaulted, and missing proof never grants a witness.
void _validateProgrammeLinks(
  Object? raw,
  String actor,
  Map<String, Object?> record,
  Map<String, Object?> claim,
  Map<String, Object?> slot,
  int schema,
) {
  if (raw == null) _fail('programme_scope_unproven');
  final witness = _map(raw);
  _keys(witness, [
    'assignment',
    'version',
    'projection',
    'occurrence',
    'outcome',
    'session',
    'frozen',
  ]);
  final pin = {
    'programme_version_id': claim['programme_version_id'],
    'package_hash': claim['package_hash'],
  };
  final assignment = {'assignment_id': claim['assignment_id']};
  final placement = {
    'session_slot_id': slot['slot_id'],
    'week_number': slot['week_number'],
    'day_key': slot['day_key'],
    'session_order': slot['session_order'],
    'programmed_session_key':
        'prog:${claim['assignment_id']}@${claim['programme_version_id']}:w${slot['week_number']}:${slot['day_key']}:s${slot['session_order']}:${claim['protocol_id']}',
  };
  _exactLinks(witness['assignment'], {
    'id': claim['assignment_id'],
    'athlete_id': actor,
    ...pin,
    'package_schema_version': schema.toString(),
  });
  if (witness['version'] == null) _fail('programme_scope_unproven');
  final version = _map(witness['version']);
  _keys(version, [
    'id',
    'package_hash',
    'package_schema_version',
    'lifecycle_status',
    'published_at',
  ]);
  if (version['id'] != claim['programme_version_id'] ||
      version['package_hash'] != claim['package_hash'] ||
      version['package_schema_version'] is! int ||
      version['package_schema_version'] != schema ||
      !['published', 'archived'].contains(version['lifecycle_status']) ||
      version['published_at'] is! String ||
      DateTime.tryParse(version['published_at'] as String) == null) {
    _fail('programme_scope_conflict');
  }
  _exactLinks(witness['projection'], {
    ...assignment,
    'athlete_id': actor,
    ...pin,
  });
  _exactLinks(witness['occurrence'], {
    'id': claim['occurrence_id'],
    ...assignment,
    ...pin,
    ...placement,
    'protocol_id': claim['protocol_id'],
  });
  _exactLinks(witness['session'], {
    'id': claim['training_session_id'],
    'athlete_id': actor,
    'protocol_id': claim['protocol_id'],
  });
  if (witness['outcome'] == null) _fail('programme_scope_unproven');
  final outcome = _map(witness['outcome']);
  _keys(outcome, [
    ...assignment.keys,
    ...pin.keys,
    ...placement.keys,
    'training_session_id',
    'outcome_status',
    'completion_record_id',
    'replacement_protocol_id',
  ]);
  final outcomeLinks = {...outcome}
    ..remove('outcome_status')
    ..remove('completion_record_id')
    ..remove('replacement_protocol_id');
  _exactLinks(outcomeLinks, {
    ...assignment,
    ...pin,
    ...placement,
    'training_session_id': claim['training_session_id'],
  });
  if (outcome['replacement_protocol_id'] != null &&
      outcome['replacement_protocol_id'] != claim['protocol_id']) {
    _fail('programme_scope_conflict');
  }
  if (['completed', 'partially_completed'].contains(record['status'])) {
    if (![
      'completed',
      'completed_partial',
    ].contains(outcome['outcome_status'])) {
      _fail('programme_scope_conflict');
    }
    if (outcome['completion_record_id'] == null) {
      _fail('programme_scope_unproven');
    }
    if (outcome['completion_record_id'] != record['record_id']) {
      _fail('programme_scope_conflict');
    }
  } else if (record['status'] == 'in_progress' &&
      outcome['outcome_status'] != 'in_progress') {
    _fail('programme_scope_conflict');
  }
  if (claim.containsKey('workout_id')) {
    _exactLinks(witness['frozen'], {
      'occurrence_id': claim['occurrence_id'],
      'athlete_id': actor,
      ...assignment,
      'training_session_id': claim['training_session_id'],
    });
  } else if (witness['frozen'] != null) {
    _fail('programme_scope_conflict');
  }
}

void _exactLinks(Object? raw, Map<String, Object?> expected) {
  if (raw == null) _fail('programme_scope_unproven');
  final links = _map(raw);
  _keys(links, expected.keys.toList());
  if (expected.entries.any(
    (e) => links[e.key] != e.value || (e.value is int && links[e.key] is! int),
  )) {
    _fail('programme_scope_conflict');
  }
}

final class _FrameClient implements HistoryTrackingRpcClient {
  const _FrameClient(this.authenticatedAthleteId, this.frame);
  @override
  final String authenticatedAthleteId;
  final Map<String, Object?> frame;
  @override
  Future<Object?> readTrackingHistory({
    required String recordId,
    required Map<String, Object?>? programmeClaim,
  }) async => frame;
}

Never _fail(String code) => throw HistoryTrackingReadException(code);
bool _uuid(Object? v) =>
    v is String &&
    RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    ).hasMatch(v);
Map<String, Object?> _map(Object? v) {
  if (v is! Map || v.keys.any((k) => k is! String)) {
    _fail('malformed_snapshot');
  }
  return Map<String, Object?>.from(v);
}

List<Map<String, Object?>> _rows(Object? v) {
  if (v is! List) {
    _fail('malformed_snapshot');
  }
  return v.map(_map).toList();
}

void _keys(Map<String, Object?> v, List<String> keys) {
  if (v.length != keys.length || !keys.every(v.containsKey)) {
    _fail('malformed_snapshot');
  }
}

String _attestedText(Object? value, Object? hash) {
  if (value is! String ||
      utf8.encode(value).length > 1048576 ||
      sha256.convert(utf8.encode(value)).toString() != hash) {
    _fail('invalid_retained_artifact');
  }
  return value;
}

String _json(Object? value) => jsonEncode(_sort(value));
Object? _sort(Object? v) {
  if (v is Map) {
    final keys = v.keys.cast<String>().toList()..sort();
    return {for (final k in keys) k: _sort(v[k])};
  }
  if (v is List) return v.map(_sort).toList();
  return v;
}
