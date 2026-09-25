import 'dart:convert';

import '../domain/programme_review_models.dart';
import 'programme_review_source.dart';
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

class ExecutableProtocolReadResult {
  const ExecutableProtocolReadResult({
    required this.protocols,
    this.findings = const [],
  });

  final Map<String, ExecutableProtocolRecord> protocols;
  final List<ProgrammeReviewFinding> findings;
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
    return readWithCorrections(insertSql: sqlSources).protocols;
  }

  ExecutableProtocolReadResult readWithCorrections({
    required Iterable<String> insertSql,
    Iterable<ProgrammeSqlSource> corrections = const [],
  }) {
    final protocols = <String, _MutableProtocol>{};
    final blocks = <String, _MutableBlock>{};

    for (final sql in insertSql) {
      _readProtocols(sql, protocols);
      _readBlocks(sql, blocks);
      _readExercises(sql, blocks);
    }

    final findings = <ProgrammeReviewFinding>[];
    for (final source in corrections) {
      findings.addAll(_applyCorrection(source, protocols, blocks));
    }

    return ExecutableProtocolReadResult(
      protocols: _freeze(protocols, blocks),
      findings: List<ProgrammeReviewFinding>.unmodifiable(findings),
    );
  }

  Map<String, ExecutableProtocolRecord> _freeze(
    Map<String, _MutableProtocol> protocols,
    Map<String, _MutableBlock> blocks,
  ) {
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

  List<ProgrammeReviewFinding> _applyCorrection(
    ProgrammeSqlSource source,
    Map<String, _MutableProtocol> protocols,
    Map<String, _MutableBlock> blocks,
  ) {
    final name = source.path.split('/').last;
    try {
      if (name ==
          '20260823121000_structure_apollo_week1_monday_warmup_exercises.sql') {
        _applyWeek1MondayWarmup(source.sql, blocks);
      } else if (name ==
          '20260824121000_correct_apollo_structured_warmup_prescriptions.sql') {
        _applyWeek1MondayPrescriptions(source.sql, blocks);
      } else if (name ==
          '20260825120000_structure_all_apollo_warmups_and_athlete_details.sql') {
        _applyAllWarmups(source.sql, protocols, blocks);
      } else if (name ==
          '20260903120000_classify_continuous_conditioning_as_steady_state.sql') {
        _applySteadyStateClassification(blocks);
      } else if (name ==
          '20260906160000_apollo_w5_fixed_work_rounds_capture.sql') {
        _applyW5FixedWorkCapture(source.sql, blocks);
      } else if (_looksLikeRelevantCorrection(source.sql)) {
        return [
          ProgrammeReviewFinding(
            code: 'unsupported_sql_correction',
            severity: ProgrammeReviewFindingSeverity.error,
            message:
                'A relevant protocol-body SQL correction is not a supported '
                'deterministic replay. Projection fails closed.',
            sourceContext: source.path,
          ),
        ];
      } else {
        return [
          ProgrammeReviewFinding(
            code: 'unsupported_sql_correction',
            severity: ProgrammeReviewFindingSeverity.error,
            message:
                'Correction artifact is not a recognized Apollo body replay.',
            sourceContext: source.path,
          ),
        ];
      }
    } on FormatException catch (error) {
      return [
        ProgrammeReviewFinding(
          code: 'unsupported_sql_correction',
          severity: ProgrammeReviewFindingSeverity.error,
          message: 'Supported correction replay failed closed: $error',
          sourceContext: source.path,
        ),
      ];
    }
    return [
      ProgrammeReviewFinding(
        code: 'sql_correction_applied',
        severity: ProgrammeReviewFindingSeverity.info,
        message: 'Applied authored SQL correction in source order.',
        sourceContext: source.path,
      ),
    ];
  }

  bool _looksLikeRelevantCorrection(String sql) {
    return sql.contains('UPDATE public.session_blocks') ||
        sql.contains('UPDATE public.session_block_exercises') ||
        sql.contains('INSERT INTO public.session_block_exercises') ||
        sql.contains('UPDATE public.performance_protocols');
  }

  void _applyWeek1MondayWarmup(String sql, Map<String, _MutableBlock> blocks) {
    final updateAt = sql.indexOf('UPDATE public.session_blocks');
    if (updateAt < 0) {
      throw const FormatException('Week 1 Monday warmup UPDATE missing.');
    }
    final updateSql = sql.substring(updateAt);
    final blockId =
        _firstQuotedAfter(updateSql, 'block_id =') ??
        (throw const FormatException('Week 1 Monday warmup block_id missing.'));
    final block = blocks[blockId];
    if (block == null) {
      throw const FormatException(
        'Week 1 Monday warmup target block is absent.',
      );
    }
    block.content = '';
    block.coachNotes =
        _firstQuotedAfter(updateSql, 'coach_notes =') ?? block.coachNotes;
    _readExercises(sql, blocks);
  }

  void _applyWeek1MondayPrescriptions(
    String sql,
    Map<String, _MutableBlock> blocks,
  ) {
    final blockId =
        _firstQuotedAfter(sql, 'target.block_id =') ??
        (throw const FormatException('Warm-up prescription block_id missing.'));
    final block = blocks[blockId];
    if (block == null) {
      throw const FormatException(
        'Warm-up prescription target block is absent.',
      );
    }
    final valuesAt = sql.indexOf('VALUES');
    final aliasAt = sql.indexOf(') AS correction');
    if (valuesAt < 0 || aliasAt < 0 || aliasAt <= valuesAt) {
      throw const FormatException('Warm-up prescription VALUES missing.');
    }
    final clause = sql.substring(valuesAt + 'VALUES'.length, aliasAt + 1);
    for (final row in parser.parseTupleList(clause)) {
      if (row.length < 2) {
        continue;
      }
      final exerciseId = row[0]?.toString();
      final prescription = row[1]?.toString();
      if (exerciseId == null || prescription == null) {
        continue;
      }
      _replaceMovementPrescription(
        block,
        exerciseId: exerciseId,
        prescription: prescription,
      );
    }
  }

  void _applyAllWarmups(
    String sql,
    Map<String, _MutableProtocol> protocols,
    Map<String, _MutableBlock> blocks,
  ) {
    final templates = _parseWarmupTemplates(sql);
    final titleToTemplate = _parseTitleTemplates(sql);
    final noteRules = _parseCoachNoteRules(sql);
    if (templates.isEmpty || titleToTemplate.isEmpty) {
      throw const FormatException('All-warmup templates could not be parsed.');
    }

    final monday = protocols['APOLLO-W1-MON-R1'];
    if (monday != null &&
        sql.contains("protocol_id = 'APOLLO-W1-MON-R1'") &&
        sql.contains('coaching_notes = NULL')) {
      monday.coachingNotes = null;
    }

    for (final block in blocks.values) {
      final template = titleToTemplate[block.title];
      if (template == null) {
        continue;
      }
      final links = templates[template];
      if (links == null) {
        throw FormatException('Missing warmup template "$template".');
      }
      block.content = '';
      block.coachNotes = _coachNotesFor(block, noteRules);
      for (final link in links) {
        _upsertMovement(
          block,
          position: link.position,
          exerciseId: link.exerciseId,
          name: link.label,
          prescription: link.prescription,
        );
      }
    }
  }

  void _applySteadyStateClassification(Map<String, _MutableBlock> blocks) {
    final sessionRe = RegExp(r'^APOLLO-W([1-9]|1[0-2])-[A-Z]{3}-R1$');
    var matched = 0;
    for (final block in blocks.values) {
      if (!sessionRe.hasMatch(block.sessionId)) {
        continue;
      }
      if (block.blockType != 'conditioning') {
        continue;
      }
      if (block.workoutFormat != 'intervals' &&
          block.workoutFormat != 'steady_state') {
        continue;
      }
      final config = _jsonMap(block.timerConfiguration);
      if (config == null) {
        continue;
      }
      final tracking = config['tracking'];
      if (tracking is! List ||
          !tracking.contains('distance') ||
          !tracking.contains('average_pace') ||
          !tracking.contains('average_hr')) {
        continue;
      }
      final duration =
          _asInt(
            config['duration_seconds'] ??
                config['durationSeconds'] ??
                config['work_seconds'],
          ) ??
          0;
      if (duration <= 0) {
        continue;
      }
      if (config.containsKey('rounds') ||
          config.containsKey('rest_seconds') ||
          config.containsKey('recovery_seconds')) {
        continue;
      }
      matched += 1;
      block.workoutFormat = 'steady_state';
      config.remove('work_seconds');
      config.remove('durationSeconds');
      config['duration_seconds'] = duration;
      block.timerConfiguration = jsonEncode(config);
    }
    if (matched != 23) {
      throw FormatException(
        'Steady-state correction expected 23 structural targets, found $matched.',
      );
    }
  }

  void _applyW5FixedWorkCapture(String sql, Map<String, _MutableBlock> blocks) {
    final sessionId =
        _firstQuotedAfter(sql, 'session_id =') ??
        (throw const FormatException('W5 capture session_id missing.'));
    final strategy =
        RegExp(r"'capture_strategy',\s*'([^']+)'").firstMatch(sql)?.group(1) ??
        (throw const FormatException('W5 capture_strategy missing.'));
    final exerciseIds = RegExp(r"exercise_id IN \(([^)]+)\)")
        .firstMatch(sql)
        ?.group(1)
        ?.split(',')
        .map((item) => item.replaceAll("'", '').trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (exerciseIds == null || exerciseIds.isEmpty) {
      throw const FormatException('W5 capture exercise list missing.');
    }

    var blockHits = 0;
    for (final block in blocks.values) {
      if (block.sessionId != sessionId ||
          block.blockType != 'conditioning' ||
          block.workoutFormat != 'rounds') {
        continue;
      }
      blockHits += 1;
      final config = _jsonMap(block.timerConfiguration) ?? <String, dynamic>{};
      config['capture_strategy'] = strategy;
      block.timerConfiguration = jsonEncode(config);
      for (final exerciseId in exerciseIds) {
        final movement = _movementByExercise(block, exerciseId);
        if (movement == null) {
          continue;
        }
        final prescription =
            _jsonMap(movement.rawPrescription) ?? <String, dynamic>{};
        prescription['load'] = {'type': 'athleteSelected', 'unit': 'kg'};
        _upsertMovement(
          block,
          position: movement.position,
          exerciseId: exerciseId,
          name: movement.name,
          prescription: jsonEncode(prescription),
        );
      }
    }
    if (blockHits == 0) {
      throw const FormatException('W5 capture found no matching blocks.');
    }
  }

  Map<String, List<_WarmupLink>> _parseWarmupTemplates(String sql) {
    final clause = extractor.valuesClause(
      sql: sql,
      table: 'expected_apollo_preparation_links',
      publicQualified: false,
    );
    if (clause == null) {
      throw const FormatException('Warm-up template VALUES missing.');
    }
    final byTemplate = <String, List<_WarmupLink>>{};
    for (final row in parser.parseTupleList(clause)) {
      if (row.length < 5) {
        continue;
      }
      final template = row[0]?.toString();
      final position = _asInt(row[1]);
      final exerciseId = row[2]?.toString();
      final label = row[3]?.toString();
      final prescription = row[4]?.toString();
      if (template == null ||
          position == null ||
          exerciseId == null ||
          label == null ||
          prescription == null) {
        continue;
      }
      byTemplate
          .putIfAbsent(template, () => [])
          .add(
            _WarmupLink(
              position: position,
              exerciseId: exerciseId,
              label: label,
              prescription: prescription,
            ),
          );
    }
    return byTemplate;
  }

  Map<String, String> _parseTitleTemplates(String sql) {
    final start = sql.indexOf('CASE title');
    final end = sql.indexOf('END AS template');
    if (start < 0 || end < 0 || end <= start) {
      throw const FormatException('Warm-up title CASE missing.');
    }
    return {
      for (final match in RegExp(
        r"WHEN '([^']+)' THEN '([^']+)'",
      ).allMatches(sql.substring(start, end)))
        match.group(1)!: match.group(2)!,
    };
  }

  List<_CoachNoteRule> _parseCoachNoteRules(String sql) {
    final start = sql.indexOf('coach_notes = CASE');
    final end = sql.indexOf('ELSE b.coach_notes');
    if (start < 0 || end < 0 || end <= start) {
      return const [];
    }
    final chunk = sql.substring(start, end);
    return [
      for (final match in RegExp(
        r"WHEN b\.title = '([^']+)'(?:\s+AND b\.session_id = '([^']+)')?(?:\s+AND b\.coach_notes LIKE '([^']+)')?\s+THEN '([^']+)'",
      ).allMatches(chunk))
        _CoachNoteRule(
          title: match.group(1)!,
          sessionId: match.group(2),
          notesContains: match.group(3)?.replaceAll('%', ''),
          value: match.group(4)!,
        ),
    ];
  }

  String? _coachNotesFor(_MutableBlock block, List<_CoachNoteRule> rules) {
    for (final rule in rules) {
      if (rule.title != block.title) {
        continue;
      }
      if (rule.sessionId != null && rule.sessionId != block.sessionId) {
        continue;
      }
      if (rule.notesContains != null &&
          !(block.coachNotes ?? '').contains(rule.notesContains!)) {
        continue;
      }
      return rule.value;
    }
    return block.coachNotes;
  }

  void _replaceMovementPrescription(
    _MutableBlock block, {
    required String exerciseId,
    required String prescription,
  }) {
    final current = _movementByExercise(block, exerciseId);
    if (current == null) {
      throw FormatException('No movement $exerciseId on ${block.blockId}.');
    }
    _upsertMovement(
      block,
      position: current.position,
      exerciseId: exerciseId,
      name: current.name,
      prescription: prescription,
    );
  }

  ProgrammeReviewMovement? _movementByExercise(
    _MutableBlock block,
    String exerciseId,
  ) {
    for (final movement in block.movements) {
      if (movement.exerciseId == exerciseId) {
        return movement;
      }
    }
    return null;
  }

  void _upsertMovement(
    _MutableBlock block, {
    required int position,
    required String exerciseId,
    required String name,
    required String prescription,
  }) {
    final decoded = _decodePrescription(prescription);
    final next = ProgrammeReviewMovement(
      position: position,
      name: name,
      exerciseId: exerciseId,
      sets: decoded.sets,
      reps: decoded.reps,
      duration: decoded.duration,
      distance: decoded.distance,
      recovery: decoded.recovery,
      notes: decoded.notes,
      rawPrescription: prescription,
      unsupportedReason: decoded.unsupported,
    );
    final index = block.movements.indexWhere(
      (item) => item.position == position,
    );
    if (index >= 0) {
      block.movements[index] = next;
    } else {
      block.movements.add(next);
    }
  }

  Map<String, dynamic>? _jsonMap(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return _decodeJsonMap(raw);
  }

  String? _firstQuotedAfter(String sql, String marker) {
    final at = sql.indexOf(marker);
    if (at < 0) {
      return null;
    }
    return _nextQuoted(sql, at + marker.length);
  }

  String? _nextQuoted(String sql, int start) {
    var i = start;
    while (i < sql.length && sql[i] != "'") {
      i++;
    }
    if (i >= sql.length) {
      return null;
    }
    final buffer = StringBuffer();
    i++;
    while (i < sql.length) {
      final ch = sql[i];
      if (ch == "'" && i + 1 < sql.length && sql[i + 1] == "'") {
        buffer.write("'");
        i += 2;
        continue;
      }
      if (ch == "'") {
        return buffer.toString();
      }
      buffer.write(ch);
      i++;
    }
    throw const FormatException('Unclosed SQL string literal.');
  }

  void _readProtocols(String sql, Map<String, _MutableProtocol> protocols) {
    for (final clause in extractor.valuesClauses(
      sql: sql,
      table: 'performance_protocols',
    )) {
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
  }

  void _readBlocks(String sql, Map<String, _MutableBlock> blocks) {
    for (final clause in extractor.valuesClauses(
      sql: sql,
      table: 'session_blocks',
    )) {
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
  }

  void _readExercises(String sql, Map<String, _MutableBlock> blocks) {
    for (final clause in extractor.valuesClauses(
      sql: sql,
      table: 'session_block_exercises',
    )) {
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
  String? coachingNotes;
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
  String? content;
  String? workoutFormat;
  String? timerConfiguration;
  String? coachNotes;
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

class _WarmupLink {
  const _WarmupLink({
    required this.position,
    required this.exerciseId,
    required this.label,
    required this.prescription,
  });

  final int position;
  final String exerciseId;
  final String label;
  final String prescription;
}

class _CoachNoteRule {
  const _CoachNoteRule({
    required this.title,
    required this.value,
    this.sessionId,
    this.notesContains,
  });

  final String title;
  final String value;
  final String? sessionId;
  final String? notesContains;
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
