part of 'history_tracking_adapter.dart';

final class _HistoryProjection {
  _HistoryProjection(this.frame, this.query, this.metric);
  final HistoryReadFrame frame;
  final HistoryTrackingQuery query;
  final TrackingMetricDefinition metric;
  HistoryFieldSelection get field => query.field;

  HistoryTrackingResult project() {
    final record = frame.record;
    if (record == null) {
      if ([
            frame.blocks,
            frame.exercises,
            frame.sets,
            frame.corrections,
          ].any((rows) => rows.isNotEmpty) ||
          frame.programmeWitness != null) {
        throw const _HistoryProblem('orphaned_history_rows');
      }
      return const HistoryTrackingAbsent('record_not_visible');
    }
    if (record['athlete_id'] != query.athleteId) {
      throw const _HistoryProblem('ownership_denied');
    }
    if (record['record_id'] != field.recordId) {
      throw const _HistoryProblem('record_reference_mismatch');
    }
    if (![
      'completed',
      'partially_completed',
      'abandoned',
    ].contains(record['status'])) {
      throw const _HistoryProblem('record_not_terminal');
    }
    final session = record['training_session_id'];
    if (session != null && (session is! int || session < 1)) {
      throw const _HistoryProblem('malformed_session_reference');
    }
    final witness = frame.programmeWitness;
    if (witness != null &&
        (witness.athleteId != query.athleteId ||
            witness.recordId != field.recordId ||
            witness.assignmentId != record['assignment_id'] ||
            witness.trainingSessionId != session?.toString() ||
            witness.scope.protocolId != record['source_protocol_id'])) {
      throw const _HistoryProblem('programme_scope_mismatch');
    }
    final blocks = _index(frame.blocks, 'block_result_id');
    final exercises = _index(frame.exercises, 'exercise_result_id');
    final sets = _index(frame.sets, 'set_result_id');
    for (final block in blocks.values) {
      if (block['session_record_id'] != field.recordId) {
        throw const _HistoryProblem('block_parent_mismatch');
      }
    }
    for (final exercise in exercises.values) {
      if (!blocks.containsKey(exercise['block_result_id'])) {
        throw const _HistoryProblem('exercise_parent_mismatch');
      }
    }
    for (final set in sets.values) {
      if (!exercises.containsKey(set['exercise_result_id'])) {
        throw const _HistoryProblem('set_parent_mismatch');
      }
    }
    final audits = _audits(record, blocks, sets);
    final block = blocks[field.blockResultId];
    if (block == null) {
      return const HistoryTrackingAbsent('block_result_missing');
    }
    if (block['source_block_id'] != field.sourceBlockId ||
        _map(block['block_snapshot'])['sourceBlockId'] != field.sourceBlockId) {
      throw const _HistoryProblem('source_block_mismatch');
    }
    if (field.exerciseResultId != null) {
      final exercise = exercises[field.exerciseResultId];
      if (exercise == null) {
        return const HistoryTrackingAbsent('exercise_result_missing');
      }
      if (exercise['block_result_id'] != field.blockResultId) {
        throw const _HistoryProblem('exercise_parent_mismatch');
      }
    }
    final set = sets[field.setResultId];
    if (field.setResultId != null) {
      if (set == null) return const HistoryTrackingAbsent('set_result_missing');
      if (set['exercise_result_id'] != field.exerciseResultId) {
        throw const _HistoryProblem('set_parent_mismatch');
      }
    }
    _programme(record, block);
    final captured = _capture(block, set);
    _assertCurrentAuditedScope(audits, block, set);
    final context = <String, String>{};
    final comparison = _map(block['block_snapshot'])['comparisonFamily'];
    if (comparison != null) {
      if (comparison is! String || !_text(comparison)) {
        throw const _HistoryProblem('malformed_context');
      }
      context['comparison_family'] = comparison;
    }
    final chronology = _chronology(record);
    final digest = _digest({
      'selected_inputs_schema': 1,
      'metric': metric.reference.toJson(),
      'source_identity': jsonDecode(field.sourceIdentity),
      'value': captured.value,
      'unit': captured.unit?.name,
      'state': captured.state.name,
      'running_capture_scope': _runningInputs(block),
      'context': context,
      'chronology': chronology,
    });
    if (field.expectedInputDigest != null &&
        field.expectedInputDigest != digest) {
      throw const _HistoryProblem('source_inputs_changed');
    }
    var state = captured.state;
    var reason = captured.reason;
    if (captured.value != null && captured.unit != metric.unit) {
      state = TrackingEvidenceState.incomparable;
      reason = 'canonical_unit_incompatible';
    } else if (state == TrackingEvidenceState.available ||
        state == TrackingEvidenceState.partial) {
      if (!metric.allowedSources.contains(TrackingSourceKind.historyResult)) {
        state = TrackingEvidenceState.ineligible;
        reason = 'history_source_not_allowed';
      } else if (metric.requiresAssessment) {
        state = TrackingEvidenceState.ineligible;
        reason = 'authored_assessment_not_proven';
      } else if (metric.freshnessCivilDays != null) {
        state = TrackingEvidenceState.ineligible;
        reason = 'freshness_not_evaluated';
      } else if (metric.requiredContext.any(
        (key) => !context.containsKey(key),
      )) {
        state = TrackingEvidenceState.ineligible;
        reason = 'required_context_unavailable';
      } else if (query.expectedContext.entries.any(
        (entry) => context[entry.key] != entry.value,
      )) {
        state = TrackingEvidenceState.incomparable;
        reason = 'comparison_context_incompatible';
      }
    }
    final unmeasured = [
      TrackingEvidenceState.missing,
      TrackingEvidenceState.skipped,
      TrackingEvidenceState.unavailable,
    ].contains(state);
    final value =
        unmeasured ||
            (captured.state == TrackingEvidenceState.partial &&
                !metric.allowPartial)
        ? null
        : captured.value;
    return HistoryTrackingObservation(
      source: TrackingHistorySource(
        recordId: field.recordId,
        blockResultId: field.blockResultId,
        sourceBlockId: field.sourceBlockId,
        fieldPath: field.fieldPath,
        inputDigest: digest,
        correctionId: field.expectedCorrectionId,
        exerciseResultId: field.exerciseResultId,
        setResultId: field.setResultId,
        workoutId: field.workoutId,
        stepId: field.stepId,
        repeatOrdinal: field.repeatOrdinal,
      ),
      sourceIdentity: field.sourceIdentity,
      evidence: TrackingEvidence(
        state: state,
        reason: state == TrackingEvidenceState.available ? null : reason,
        recordedCount: captured.state == TrackingEvidenceState.available
            ? 1
            : 0,
        requiredCount: 1,
      ),
      unit: captured.unit,
      value: value,
      context: context,
      chronology: chronology,
      correctionIds: audits.keys.toList()..sort(),
      auditSetDigest: _digest(
        (audits.keys.toList()..sort()).map((id) => audits[id]).toList(),
      ),
    );
  }

  Map<String, Map<String, Object?>> _audits(
    Map<String, Object?> record,
    Map<String, Map<String, Object?>> blocks,
    Map<String, Map<String, Object?>> sets,
  ) {
    final audits = _index(frame.corrections, 'correction_id');
    if (audits.isNotEmpty && record['status'] != 'completed') {
      throw const _HistoryProblem('correction_lifecycle_mismatch');
    }
    for (final audit in audits.values) {
      if (audit['athlete_id'] != query.athleteId ||
          audit['record_id'] != field.recordId ||
          audit['training_session_id'] != record['training_session_id']) {
        throw const _HistoryProblem('correction_parent_mismatch');
      }
      _timestamp(audit['corrected_at']);
      final before = _map(audit['before_values']);
      final after = _map(audit['after_values']);
      if (before.isEmpty ||
          before.length != after.length ||
          !before.keys.every(after.containsKey)) {
        throw const _HistoryProblem('malformed_correction_scope');
      }
      for (final key in before.keys) {
        if (key == 'overall_rpe' || key == 'athlete_note') continue;
        final parts = key.split(':');
        if ((parts.length == 3 &&
                parts[0] == 'block' &&
                parts[2] == 'result_data' &&
                blocks.containsKey(parts[1])) ||
            (parts.length == 2 &&
                parts[0] == 'set' &&
                sets.containsKey(parts[1]))) {
          continue;
        }
        throw const _HistoryProblem('correction_scope_mismatch');
      }
    }
    if (field.expectedCorrectionId != null &&
        !audits.containsKey(field.expectedCorrectionId)) {
      throw const _HistoryProblem('correction_reference_not_found');
    }
    return audits;
  }

  // A consistency check where the existing audit actually contains the entire
  // affected input. This does not order audits, choose a latest revision or
  // reconstruct fields omitted by older set audit payloads.
  void _assertCurrentAuditedScope(
    Map<String, Map<String, Object?>> audits,
    Map<String, Object?> block,
    Map<String, Object?>? set,
  ) {
    final key = set == null
        ? 'block:${field.blockResultId}:result_data'
        : 'set:${field.setResultId}';
    final afters = audits.values
        .map((audit) => _map(audit['after_values']))
        .where((after) => after.containsKey(key))
        .map((after) => after[key])
        .toList();
    if (afters.isEmpty) return;
    if (set == null) {
      if (!afters.any(
        (after) => _digest(after) == _digest(block['result_data']),
      )) {
        throw const _HistoryProblem('correction_inputs_mismatch');
      }
      return;
    }
    final fields = [
      field.fieldPath.single,
      'completed',
      if (field.fieldPath.single == 'load') 'load_unit',
      if (field.fieldPath.single == 'distance') 'distance_unit',
    ];
    final rows = afters.map(_map).toList();
    if (rows.any((row) => fields.any((name) => !row.containsKey(name)))) return;
    if (!rows.any((row) => fields.every((name) => row[name] == set[name]))) {
      throw const _HistoryProblem('correction_inputs_mismatch');
    }
  }

  void _programme(Map<String, Object?> record, Map<String, Object?> block) {
    final claim = query.programmeClaim;
    if (claim == null) return;
    final scope = claim.scope;
    if (![
          claim.assignmentId,
          claim.occurrenceId,
          claim.trainingSessionId,
          scope.programmeVersionId,
          scope.slotKey,
          scope.protocolId,
          scope.blockId,
        ].every(_text) ||
        !_hash(scope.packageHash) ||
        scope.protocolRevision < 1 ||
        scope.blockId != field.sourceBlockId ||
        scope.workoutId != field.workoutId ||
        scope.stepId != field.stepId ||
        scope.repeatOrdinal != field.repeatOrdinal ||
        (scope.workoutId != null && !_hash(scope.mappingHash)) ||
        (scope.workoutId == null && scope.mappingHash != null)) {
      throw const _HistoryProblem('programme_scope_mismatch');
    }
    for (final entry in {
      'assignment_id': claim.assignmentId,
      'training_session_id': claim.trainingSessionId,
      'source_protocol_id': scope.protocolId,
    }.entries) {
      final value = record[entry.key];
      if (value == null) {
        throw const _HistoryProblem('programme_scope_unproven');
      }
      if (value.toString() != entry.value) {
        throw const _HistoryProblem('programme_scope_mismatch');
      }
    }
    final witness = frame.programmeWitness;
    if (witness == null) {
      throw const _HistoryProblem('programme_scope_unproven');
    }
    if (witness.athleteId != query.athleteId ||
        witness.recordId != field.recordId ||
        witness.assignmentId != claim.assignmentId ||
        witness.occurrenceId != claim.occurrenceId ||
        witness.trainingSessionId != claim.trainingSessionId ||
        _digest(witness.scope.toJson()) != _digest(scope.toJson())) {
      throw const _HistoryProblem('programme_scope_mismatch');
    }
    if (field.workoutId != null) {
      final running = _map(
        _map(block['block_snapshot'])['structuredRunningV1'],
      );
      if (running['package_content_hash'] != scope.packageHash ||
          running['execution_mapping_sha256'] != scope.mappingHash) {
        throw const _HistoryProblem('programme_running_scope_mismatch');
      }
    }
  }

  _Captured _capture(Map<String, Object?> block, Map<String, Object?>? set) {
    final status = block['status'];
    if (![
      'not_started',
      'in_progress',
      'completed',
      'skipped',
    ].contains(status)) {
      throw const _HistoryProblem('malformed_completion_state');
    }
    String? value;
    TrackingUnit? unit;
    var complete = status == 'completed';
    var paceUnavailable = false;
    if (set != null) {
      if (field.fieldPath.length != 1) {
        throw const _HistoryProblem('unsupported_field_path');
      }
      final name = field.fieldPath.single;
      switch (name) {
        case 'reps':
          unit = TrackingUnit.count;
        case 'duration_seconds':
          unit = TrackingUnit.seconds;
        case 'load':
          unit = _unit(set['load_unit'], 'load', set[name] != null);
        case 'distance':
          unit = _unit(set['distance_unit'], 'distance', set[name] != null);
        default:
          throw const _HistoryProblem('unsupported_field_path');
      }
      value = _number(
        set[name],
        integral: name == 'reps' || name == 'duration_seconds',
      );
      if (set['completed'] is! bool) {
        throw const _HistoryProblem('malformed_completion_state');
      }
      complete = complete && set['completed'] == true;
    } else if (field.exerciseResultId != null) {
      throw const _HistoryProblem('unsupported_exercise_field');
    } else {
      final path = field.fieldPath;
      final running = field.workoutId != null;
      if ((!running &&
              (path.length != 2 ||
                  path[0] != 'result_data' ||
                  !['durationSeconds', 'distance'].contains(path.last))) ||
          (running &&
              (path.length != 3 ||
                  path[0] != 'result_data' ||
                  path[1] != 'intervals' ||
                  path.last != 'paceSecondsPerKm'))) {
        throw const _HistoryProblem('unsupported_field_path');
      }
      final type = block['result_type'];
      if (!(running
          ? type == 'interval'
          : ['duration', 'distance', 'endurance'].contains(type))) {
        throw const _HistoryProblem('unsupported_result_shape');
      }
      if (!running && path.last == 'distance' && type == 'duration') {
        throw const _HistoryProblem('unsupported_result_shape');
      }
      final data = block['result_data'] == null
          ? <String, Object?>{}
          : _map(block['result_data']);
      if (data.isNotEmpty && data['resultType'] != type) {
        throw const _HistoryProblem('contradictory_result_type');
      }
      if (running) {
        unit = TrackingUnit.secondsPerKilometre;
        final row = _runningRow(block, data);
        if (row == null) {
          return const _Captured(
            null,
            TrackingUnit.secondsPerKilometre,
            TrackingEvidenceState.missing,
            'running_result_missing',
          );
        }
        switch (row['state']) {
          case 'completed':
            complete = status == 'completed';
          case 'pending':
            complete = false;
          case 'skipped':
            return const _Captured(
              null,
              TrackingUnit.secondsPerKilometre,
              TrackingEvidenceState.skipped,
              'running_work_skipped',
            );
          case 'pace_unavailable':
            paceUnavailable = true;
          default:
            throw const _HistoryProblem('malformed_completion_state');
        }
        value = _number(row['paceSecondsPerKm']);
        _unit(row['paceUnit'], 'pace', value != null);
        if (paceUnavailable && value != null) {
          throw const _HistoryProblem('contradictory_pace_state');
        }
        if (value == '0') {
          throw const _HistoryProblem('malformed_numeric_value');
        }
      } else {
        final name = path.last;
        unit = name == 'durationSeconds'
            ? TrackingUnit.seconds
            : _unit(data['distanceUnit'], 'distance', data[name] != null);
        value = _number(data[name], integral: name == 'durationSeconds');
        if (type == 'endurance' && data.isNotEmpty) {
          if (data['completed'] is! bool) {
            throw const _HistoryProblem('malformed_completion_state');
          }
          complete = complete && data['completed'] == true;
        }
      }
    }
    if (status == 'skipped') {
      return _Captured(
        null,
        unit,
        TrackingEvidenceState.skipped,
        'block_skipped',
      );
    }
    if (status == 'not_started') {
      return _Captured(
        null,
        unit,
        TrackingEvidenceState.missing,
        'block_not_started',
      );
    }
    if (paceUnavailable || (complete && value == null)) {
      return _Captured(
        null,
        unit,
        TrackingEvidenceState.unavailable,
        'actual_not_captured',
      );
    }
    if (!complete) {
      return _Captured(
        value,
        unit,
        TrackingEvidenceState.partial,
        'selected_scope_incomplete',
      );
    }
    return _Captured(value, unit, TrackingEvidenceState.available, null);
  }

  Map<String, Object?>? _runningRow(
    Map<String, Object?> block,
    Map<String, Object?> data,
  ) {
    final snapshot = _map(_map(block['block_snapshot'])['structuredRunningV1']);
    final mapping = snapshot['execution_mapping_sha256'];
    final package = snapshot['package_content_hash'];
    if (snapshot['schema_version'] != 1 ||
        snapshot['workout_id'] != field.workoutId ||
        snapshot['session_block_id'] != field.sourceBlockId ||
        mapping is! String ||
        !_hash(mapping) ||
        package is! String ||
        !_hash(package)) {
      throw const _HistoryProblem('running_snapshot_mismatch');
    }
    final authored = _jsonRows(snapshot['work_repetitions']);
    final matches = authored.where(
      (row) =>
          row['workout_id'] == field.workoutId &&
          row['session_block_id'] == field.sourceBlockId &&
          row['authored_step_id'] == field.stepId &&
          row['repeat_ordinal'] == field.repeatOrdinal,
    );
    if (matches.length != 1) {
      throw const _HistoryProblem('running_authored_scope_mismatch');
    }
    final work = matches.single['work_seconds'];
    if (work is! int || work < 1) {
      throw const _HistoryProblem('running_snapshot_mismatch');
    }
    final actuals = data.isEmpty
        ? <Map<String, Object?>>[]
        : _jsonRows(data['intervals']);
    final seen = <String>{};
    for (final row in actuals) {
      if (row['repeatOrdinal'] is! int || row['workSeconds'] is! int) {
        throw const _HistoryProblem('running_result_scope_mismatch');
      }
      final identity = jsonEncode([
        row['workoutId'],
        row['sessionBlockId'],
        row['authoredStepId'],
        row['repeatOrdinal'],
      ]);
      if (!seen.add(identity)) {
        throw const _HistoryProblem('ambiguous_running_result');
      }
      if (!authored.any(
        (a) =>
            a['workout_id'] == row['workoutId'] &&
            a['session_block_id'] == row['sessionBlockId'] &&
            a['authored_step_id'] == row['authoredStepId'] &&
            a['repeat_ordinal'] == row['repeatOrdinal'] &&
            a['work_seconds'] == row['workSeconds'],
      )) {
        throw const _HistoryProblem('running_result_scope_mismatch');
      }
    }
    return actuals
        .where(
          (row) =>
              row['workoutId'] == field.workoutId &&
              row['sessionBlockId'] == field.sourceBlockId &&
              row['authoredStepId'] == field.stepId &&
              row['repeatOrdinal'] == field.repeatOrdinal,
        )
        .firstOrNull;
  }

  Map<String, Object?>? _runningInputs(Map<String, Object?> block) {
    if (field.workoutId == null) return null;
    // _capture already verified these exact retained snapshot/repetition inputs.
    final snapshot = _map(_map(block['block_snapshot'])['structuredRunningV1']);
    final repetition = _jsonRows(snapshot['work_repetitions']).singleWhere(
      (row) =>
          row['workout_id'] == field.workoutId &&
          row['session_block_id'] == field.sourceBlockId &&
          row['authored_step_id'] == field.stepId &&
          row['repeat_ordinal'] == field.repeatOrdinal,
    );
    return {
      'package_content_hash': snapshot['package_content_hash'],
      'execution_mapping_sha256': snapshot['execution_mapping_sha256'],
      'work_seconds': repetition['work_seconds'],
    };
  }
}

final class _Captured {
  const _Captured(this.value, this.unit, this.state, this.reason);
  final String? value;
  final TrackingUnit? unit;
  final TrackingEvidenceState state;
  final String? reason;
}

Map<String, Map<String, Object?>> _index(
  List<Map<String, Object?>> rows,
  String key,
) {
  final result = <String, Map<String, Object?>>{};
  for (final row in rows) {
    final id = row[key];
    if (id is! String || !_text(id)) {
      throw const _HistoryProblem('malformed_row_identity');
    }
    if (result.containsKey(id)) {
      throw const _HistoryProblem('duplicate_row_identity');
    }
    result[id] = row;
  }
  return result;
}

List<Map<String, Object?>> _jsonRows(Object? value) {
  if (value is! List) throw const _HistoryProblem('malformed_field_shape');
  return value.map(_map).toList();
}

TrackingUnit? _unit(Object? value, String field, bool required) {
  if (value == null && !required) return null;
  return switch ((field, value)) {
    ('load', 'kg') => TrackingUnit.kilograms,
    ('distance', 'm') => TrackingUnit.metres,
    ('distance', 'km') => TrackingUnit.kilometres,
    ('pace', 'sec_per_km') => TrackingUnit.secondsPerKilometre,
    _ => throw const _HistoryProblem('unsupported_source_unit'),
  };
}

String? _number(Object? value, {bool integral = false}) {
  if (value == null) return null;
  if (value is! num ||
      !value.isFinite ||
      value < 0 ||
      (integral && value != value.truncate())) {
    throw const _HistoryProblem('malformed_numeric_value');
  }
  var canonical = value.toString();
  if (canonical.endsWith('.0')) {
    canonical = canonical.substring(0, canonical.length - 2);
  }
  if (!RegExp(r'^(0|[1-9][0-9]*)(\.[0-9]*[1-9])?$').hasMatch(canonical)) {
    throw const _HistoryProblem('unsupported_numeric_representation');
  }
  return canonical;
}

DateTime _timestamp(Object? value) {
  final parsed = value is String ? DateTime.tryParse(value) : null;
  if (parsed == null ||
      !parsed.isUtc ||
      !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value as String)) {
    throw const _HistoryProblem('malformed_chronology');
  }
  return parsed;
}

Map<String, Object?> _chronology(Map<String, Object?> record) {
  final precision = record['performed_precision'] ?? 'timestamp';
  if (precision == 'timestamp' && record['performed_on'] == null) {
    return {
      'precision': 'timestamp',
      'performed_at': _timestamp(record['started_at']).toIso8601String(),
    };
  }
  final date = record['performed_on'];
  final parsed = date is String ? DateTime.tryParse('${date}T00:00:00Z') : null;
  if (precision != 'date' ||
      date is! String ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
      parsed == null ||
      parsed.toIso8601String().substring(0, 10) != date) {
    throw const _HistoryProblem('malformed_chronology');
  }
  return {'precision': 'civil_date', 'performed_on': date, 'timezone': null};
}
