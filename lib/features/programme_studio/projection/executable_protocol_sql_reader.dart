import 'dart:convert';

import '../domain/programme_review_models.dart';
import 'sql_values_parser.dart';

class ExecutableProtocolRecord {
  const ExecutableProtocolRecord({
    required this.protocolId,
    required this.name,
    this.purpose,
    this.primarySessionIntent,
    this.coachingNotes,
    this.blocks = const [],
  });

  final String protocolId;
  final String name;
  final String? purpose;
  final String? primarySessionIntent;
  final String? coachingNotes;
  final List<ProgrammeReviewBlock> blocks;
}

class ExecutableProtocolSqlReader {
  const ExecutableProtocolSqlReader({
    this.parser = const SqlValuesParser(),
    this.extractor = const SqlInsertExtractor(),
  });

  final SqlValuesParser parser;
  final SqlInsertExtractor extractor;

  static const knownWorkoutFormats = {
    'none',
    'amrap',
    'emom',
    'for_time',
    'steady_state',
    'intervals',
    'tabata',
    'rounds',
    'other',
  };

  static const knownBlockTypes = {
    'warm_up',
    'strength',
    'skill',
    'accessory',
    'conditioning',
    'core',
    'cool_down',
    'custom',
  };

  Map<String, ExecutableProtocolRecord> read(Iterable<String> sqlSources) {
    final protocols = <String, _MutableProtocol>{};
    final blocks = <String, _MutableBlock>{};

    for (final sql in sqlSources) {
      _readProtocols(sql, protocols);
      _readBlocks(sql, blocks);
      _readExercises(sql, blocks);
    }

    final bySession = <String, List<ProgrammeReviewBlock>>{};
    for (final block in blocks.values) {
      bySession.putIfAbsent(block.sessionId, () => []).add(block.toReview());
    }
    for (final list in bySession.values) {
      list.sort((a, b) => a.position.compareTo(b.position));
    }

    return Map<String, ExecutableProtocolRecord>.unmodifiable({
      for (final entry in protocols.entries)
        entry.key: ExecutableProtocolRecord(
          protocolId: entry.value.protocolId,
          name: entry.value.name,
          purpose: entry.value.purpose,
          primarySessionIntent: entry.value.primarySessionIntent,
          coachingNotes: entry.value.coachingNotes,
          blocks: List<ProgrammeReviewBlock>.unmodifiable(
            bySession[entry.key] ?? const [],
          ),
        ),
    });
  }

  void _readProtocols(String sql, Map<String, _MutableProtocol> protocols) {
    final clause = extractor.valuesClause(
      sql: sql,
      table: 'performance_protocols',
    );
    if (clause == null) {
      return;
    }
    for (final row in parser.parseTupleList(clause)) {
      if (row.length < 2) {
        continue;
      }
      final id = row[0]?.toString();
      final name = row[1]?.toString();
      if (id == null || name == null) {
        continue;
      }
      protocols[id] = _MutableProtocol(
        protocolId: id,
        name: name,
        purpose: row.length > 2 ? row[2]?.toString() : null,
        primarySessionIntent: row.length > 12 ? row[12]?.toString() : null,
        coachingNotes: row.length > 13 ? row[13]?.toString() : null,
      );
    }
  }

  void _readBlocks(String sql, Map<String, _MutableBlock> blocks) {
    final clause = extractor.valuesClause(sql: sql, table: 'session_blocks');
    if (clause == null) {
      return;
    }
    for (final row in parser.parseTupleList(clause)) {
      if (row.length < 9) {
        continue;
      }
      final blockId = row[0]?.toString();
      final sessionId = row[1]?.toString();
      if (blockId == null || sessionId == null) {
        continue;
      }
      final format = row[5]?.toString();
      final type = row[2]?.toString() ?? 'custom';
      String? unsupported;
      if (format != null &&
          format.isNotEmpty &&
          !knownWorkoutFormats.contains(format)) {
        unsupported =
            'Unsupported workout_format "$format" on $blockId. Rendered from source; not inferred.';
      }
      if (!knownBlockTypes.contains(type)) {
        unsupported = [
          ?unsupported,
          'Unsupported block_type "$type" on $blockId. Rendered from source; not omitted.',
        ].join(' ');
      }
      blocks[blockId] = _MutableBlock(
        blockId: blockId,
        sessionId: sessionId,
        blockType: type,
        title: row[3]?.toString() ?? 'Block',
        content: row[4]?.toString(),
        workoutFormat: format,
        timerConfiguration: row[6]?.toString(),
        coachNotes: row[7]?.toString(),
        position: _asInt(row[8]) ?? blocks.length + 1,
        unsupportedReason: unsupported,
      );
    }
  }

  void _readExercises(String sql, Map<String, _MutableBlock> blocks) {
    final clause = extractor.valuesClause(
      sql: sql,
      table: 'session_block_exercises',
    );
    if (clause == null) {
      return;
    }
    for (final row in parser.parseTupleList(clause)) {
      if (row.length < 5) {
        continue;
      }
      final blockId = row[0]?.toString();
      if (blockId == null) {
        continue;
      }
      final block = blocks[blockId];
      if (block == null) {
        continue;
      }
      final prescription = row[4]?.toString();
      final decoded = _decodePrescription(prescription);
      block.movements.add(
        ProgrammeReviewMovement(
          position: _asInt(row[2]) ?? block.movements.length + 1,
          name: row[3]?.toString() ?? row[1]?.toString() ?? 'Movement',
          exerciseId: row[1]?.toString(),
          sets: decoded.sets,
          reps: decoded.reps,
          duration: decoded.duration,
          distance: decoded.distance,
          recovery: decoded.recovery,
          notes: decoded.notes,
          rawPrescription: prescription,
          unsupportedReason: decoded.unsupported,
        ),
      );
    }
  }

  int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '');
  }

  _DecodedPrescription _decodePrescription(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const _DecodedPrescription();
    }
    try {
      final decoded = _decodeJsonMap(raw);
      if (decoded == null) {
        return const _DecodedPrescription(
          unsupported: 'Prescription is not JSON.',
        );
      }
      return _DecodedPrescription(
        sets: _display(decoded['sets']),
        reps: _display(decoded['reps']),
        duration: _display(
          decoded['duration'] ??
              decoded['duration_seconds'] ??
              decoded['work_seconds'],
        ),
        distance: _display(decoded['distance'] ?? decoded['distance_m']),
        recovery: _display(
          decoded['rest_seconds'] ?? decoded['recovery_seconds'],
        ),
        notes: _display(decoded['coach_cue'] ?? decoded['notes']),
      );
    } catch (error) {
      return _DecodedPrescription(
        unsupported: 'Malformed prescription JSON: $error',
      );
    }
  }

  Map<String, dynamic>? _decodeJsonMap(String raw) {
    if (!raw.trim().startsWith('{')) {
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  String? _display(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is Map) {
      final type = value['type']?.toString();
      if (type == 'range') {
        final min = value['min_reps'] ?? value['min'];
        final max = value['max_reps'] ?? value['max'];
        if (min != null && max != null) {
          return '$min–$max';
        }
      }
      if (type == 'exact') {
        return (value['exact_reps'] ?? value['text'])?.toString();
      }
      if (type == 'duration') {
        return value['text']?.toString();
      }
      if (type == 'freeText') {
        return value['text']?.toString();
      }
      return value.toString();
    }
    return value.toString();
  }
}

class _MutableProtocol {
  _MutableProtocol({
    required this.protocolId,
    required this.name,
    this.purpose,
    this.primarySessionIntent,
    this.coachingNotes,
  });

  final String protocolId;
  final String name;
  final String? purpose;
  final String? primarySessionIntent;
  final String? coachingNotes;
}

class _MutableBlock {
  _MutableBlock({
    required this.blockId,
    required this.sessionId,
    required this.blockType,
    required this.title,
    required this.position,
    this.content,
    this.workoutFormat,
    this.timerConfiguration,
    this.coachNotes,
    this.unsupportedReason,
  });

  final String blockId;
  final String sessionId;
  final String blockType;
  final String title;
  final int position;
  final String? content;
  final String? workoutFormat;
  final String? timerConfiguration;
  final String? coachNotes;
  final String? unsupportedReason;
  final List<ProgrammeReviewMovement> movements = [];

  ProgrammeReviewBlock toReview() {
    movements.sort((a, b) => a.position.compareTo(b.position));
    return ProgrammeReviewBlock(
      position: position,
      title: title,
      blockType: blockType,
      sourceIdentity: blockId,
      trainingIntent: null,
      content: content,
      workoutFormat: workoutFormat,
      timerConfiguration: timerConfiguration,
      coachNotes: coachNotes,
      movements: List<ProgrammeReviewMovement>.unmodifiable(movements),
      unsupportedReason: unsupportedReason,
    );
  }
}

class _DecodedPrescription {
  const _DecodedPrescription({
    this.sets,
    this.reps,
    this.duration,
    this.distance,
    this.recovery,
    this.notes,
    this.unsupported,
  });

  final String? sets;
  final String? reps;
  final String? duration;
  final String? distance;
  final String? recovery;
  final String? notes;
  final String? unsupported;
}

