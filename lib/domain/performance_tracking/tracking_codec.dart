part of 'performance_tracking.dart';

/// Strict artifact wire format. Encoding does not attest registry validity;
/// callers must validate the complete supplied dependency closure separately.
abstract final class TrackingCodec {
  static String encode(TrackingArtifact artifact) =>
      jsonEncode(_sort(artifact.toJson()));

  static Object? _sort(Object? value) {
    if (value is Map<String, Object?>) {
      final keys = value.keys.toList()..sort();
      return {for (final key in keys) key: _sort(value[key])};
    }
    if (value is List) return value.map(_sort).toList();
    return value;
  }

  static TrackingArtifact decode(String json) {
    final r = _TrackingReader(jsonDecode(json));
    if (r.integer('schema_version') != 1) {
      throw const FormatException('Unsupported tracking schema');
    }
    final kind = r.string('artifact_kind');
    final id = r.string('id');
    final version = r.integer('version');
    const base = ['schema_version', 'artifact_kind', 'id', 'version'];
    switch (kind) {
      case 'method':
        r.keys([...base, 'kind', 'input_units', 'output_unit']);
        return TrackingMethodDefinition(
          id: id,
          version: version,
          kind: r.enumValue('kind', TrackingMethodKind.values),
          inputUnits: r.list('input_units').map((item) {
            return _enum(item, TrackingUnit.values);
          }).toList(),
          outputUnit: r.enumValue('output_unit', TrackingUnit.values),
        );
      case 'metric':
        r.keys([
          ...base,
          'label',
          'unit',
          'method',
          'allowed_sources',
          'capture_field',
          'required_context',
          'requires_assessment',
          'allow_partial',
          'freshness_civil_days',
        ]);
        return TrackingMetricDefinition(
          id: id,
          version: version,
          label: r.string('label'),
          unit: r.enumValue('unit', TrackingUnit.values),
          method: _reference(r.value('method')),
          allowedSources: r.list('allowed_sources').map((item) {
            return _enum(item, TrackingSourceKind.values);
          }).toList(),
          captureField: r.string('capture_field'),
          requiredContext: r.strings('required_context'),
          requiresAssessment: r.boolean('requires_assessment'),
          allowPartial: r.boolean('allow_partial'),
          freshnessCivilDays: r.optionalInteger('freshness_civil_days'),
        );
      case 'profile':
        r.keys([
          ...base,
          'kind',
          'name',
          'metrics',
          'athlete_id',
          'previous',
          'view',
        ]);
        return TrackingProfile(
          id: id,
          version: version,
          kind: r.enumValue('kind', TrackingProfileKind.values),
          name: r.string('name'),
          metrics: r.list('metrics').map(_reference).toList(),
          athleteId: r.optionalString('athlete_id'),
          previous: r.optionalReference('previous'),
          view: r.enumValue('view', TrackingView.values),
        );
      case 'selection':
        r.keys([
          ...base,
          'athlete_id',
          'action',
          'profile',
          'recorded_at',
          'previous',
          'programme_binding',
        ]);
        return TrackingSelectionRevision(
          id: id,
          version: version,
          athleteId: r.string('athlete_id'),
          action: r.enumValue('action', TrackingSelectionAction.values),
          profile: _reference(r.value('profile')),
          recordedAt: r.time('recorded_at'),
          previous: r.optionalReference('previous'),
          programmeBinding: r.optionalReference('programme_binding'),
        );
      case 'assessment':
        r.keys([...base, 'procedure_digest', 'metrics']);
        return TrackingAssessmentDefinition(
          id: id,
          version: version,
          procedureDigest: r.string('procedure_digest'),
          metrics: r.list('metrics').map(_reference).toList(),
        );
      case 'programme_binding':
        r.keys([
          ...base,
          'programme_version_id',
          'package_hash',
          'profile',
          'assessment_scopes',
        ]);
        return TrackingProgrammeBinding(
          id: id,
          version: version,
          programmeVersionId: r.string('programme_version_id'),
          packageHash: r.string('package_hash'),
          profile: _reference(r.value('profile')),
          assessmentScopes: r.list('assessment_scopes').map((item) {
            final s = _TrackingReader(item);
            s.keys(['assessment', 'window', 'scope']);
            return TrackingAssessmentScope(
              assessment: _reference(s.value('assessment')),
              window: s.string('window'),
              scope: _scope(s.value('scope')),
            );
          }).toList(),
        );
      case 'measurement':
        r.keys([
          ...base,
          'athlete_id',
          'metric',
          'unit',
          'source',
          'chronology',
          'evidence',
          'provenance',
          'context',
          'canonical_value',
          'previous',
          'correction_reason',
        ]);
        final context = _TrackingReader(r.value('context'));
        return TrackingMeasurementRevision(
          id: id,
          version: version,
          athleteId: r.string('athlete_id'),
          metric: _reference(r.value('metric')),
          unit: r.enumValue('unit', TrackingUnit.values),
          source: _source(r.value('source')),
          chronology: _chronology(r.value('chronology')),
          evidence: _evidence(r.value('evidence')),
          provenance: r.string('provenance'),
          context: {
            for (final key in context.map.keys) key: context.string(key),
          },
          canonicalValue: r.optionalString('canonical_value'),
          previous: r.optionalReference('previous'),
          correctionReason: r.optionalString('correction_reason'),
        );
      default:
        throw const FormatException('Unsupported tracking artifact');
    }
  }

  static TrackingReference _reference(Object? value) {
    final r = _TrackingReader(value);
    r.keys(['id', 'version', 'digest']);
    return TrackingReference(
      id: r.string('id'),
      version: r.integer('version'),
      digest: r.string('digest'),
    );
  }

  static TrackingProgrammeScope _scope(Object? value) {
    final r = _TrackingReader(value);
    r.keys([
      'programme_version_id',
      'package_hash',
      'slot_key',
      'protocol_id',
      'protocol_revision',
      'block_id',
      'workout_id',
      'step_id',
      'repeat_ordinal',
      'mapping_hash',
    ]);
    return TrackingProgrammeScope(
      programmeVersionId: r.string('programme_version_id'),
      packageHash: r.string('package_hash'),
      slotKey: r.string('slot_key'),
      protocolId: r.string('protocol_id'),
      protocolRevision: r.integer('protocol_revision'),
      blockId: r.string('block_id'),
      workoutId: r.optionalString('workout_id'),
      stepId: r.optionalString('step_id'),
      repeatOrdinal: r.optionalInteger('repeat_ordinal'),
      mappingHash: r.optionalString('mapping_hash'),
    );
  }

  static TrackingHistorySource _history(Object? value) {
    final r = _TrackingReader(value);
    r.keys([
      'record_id',
      'block_result_id',
      'source_block_id',
      'field_path',
      'input_digest',
      'historical_inputs',
      'exercise_result_id',
      'set_result_id',
      'correction_id',
      'workout_id',
      'step_id',
      'repeat_ordinal',
    ]);
    if (r.string('historical_inputs') != 'unavailable') {
      throw const FormatException('Historical reconstruction is unproven');
    }
    return TrackingHistorySource(
      recordId: r.string('record_id'),
      blockResultId: r.string('block_result_id'),
      sourceBlockId: r.string('source_block_id'),
      fieldPath: r.strings('field_path'),
      inputDigest: r.string('input_digest'),
      exerciseResultId: r.optionalString('exercise_result_id'),
      setResultId: r.optionalString('set_result_id'),
      correctionId: r.optionalString('correction_id'),
      workoutId: r.optionalString('workout_id'),
      stepId: r.optionalString('step_id'),
      repeatOrdinal: r.optionalInteger('repeat_ordinal'),
    );
  }

  static TrackingMeasurementSource _source(Object? value) {
    final r = _TrackingReader(value);
    r.keys([
      'kind',
      'source_id',
      'history',
      'assessment',
      'attempt_id',
      'programme_scope',
      'assignment_id',
      'occurrence_id',
      'training_session_id',
    ]);
    return TrackingMeasurementSource(
      kind: r.enumValue('kind', TrackingSourceKind.values),
      sourceId: r.string('source_id'),
      history: r.optional('history') == null
          ? null
          : _history(r.value('history')),
      assessment: r.optionalReference('assessment'),
      attemptId: r.optionalString('attempt_id'),
      programmeScope: r.optional('programme_scope') == null
          ? null
          : _scope(r.value('programme_scope')),
      assignmentId: r.optionalString('assignment_id'),
      occurrenceId: r.optionalString('occurrence_id'),
      trainingSessionId: r.optionalString('training_session_id'),
    );
  }

  static TrackingChronology _chronology(Object? value) {
    final r = _TrackingReader(value);
    r.keys([
      'precision',
      'recorded_at',
      'performed_at',
      'performed_on',
      'timezone',
    ]);
    return TrackingChronology(
      precision: r.enumValue('precision', TrackingTimePrecision.values),
      recordedAt: r.time('recorded_at'),
      performedAt: r.optional('performed_at') == null
          ? null
          : r.time('performed_at'),
      performedOn: r.optionalString('performed_on'),
      timezone: r.optionalString('timezone'),
    );
  }

  static TrackingEvidence _evidence(Object? value) {
    final r = _TrackingReader(value);
    r.keys(['state', 'reason', 'recorded_count', 'required_count']);
    return TrackingEvidence(
      state: r.enumValue('state', TrackingEvidenceState.values),
      reason: r.optionalString('reason'),
      recordedCount: r.optionalInteger('recorded_count'),
      requiredCount: r.optionalInteger('required_count'),
    );
  }

  static T _enum<T extends Enum>(Object? value, List<T> values) {
    for (final item in values) {
      if (item.name == value) return item;
    }
    throw const FormatException('Unknown tracking vocabulary');
  }
}

class _TrackingReader {
  _TrackingReader(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Expected tracking object');
    }
    map = value;
  }

  late final Map<String, dynamic> map;

  void keys(List<String> allowed) {
    if (map.keys.any((key) => !allowed.contains(key))) {
      throw const FormatException('Unknown tracking field');
    }
  }

  Object? value(String key) {
    if (!map.containsKey(key)) throw FormatException('Missing $key');
    return map[key];
  }

  Object? optional(String key) {
    if (map.containsKey(key) && map[key] == null) {
      throw FormatException('Null optional $key must be omitted');
    }
    return map[key];
  }

  String string(String key) {
    final v = value(key);
    if (v is! String) throw FormatException('Expected string $key');
    return v;
  }

  int integer(String key) {
    final v = value(key);
    if (v is! int) throw FormatException('Expected integer $key');
    return v;
  }

  int? optionalInteger(String key) {
    // The metric freshness field explicitly admits null.
    if (key == 'freshness_civil_days') {
      final v = value(key);
      if (v == null) return null;
      return integer(key);
    }
    return optional(key) == null ? null : integer(key);
  }

  String? optionalString(String key) =>
      optional(key) == null ? null : string(key);

  TrackingReference? optionalReference(String key) =>
      optional(key) == null ? null : TrackingCodec._reference(value(key));

  bool boolean(String key) {
    final v = value(key);
    if (v is! bool) throw FormatException('Expected boolean $key');
    return v;
  }

  List<dynamic> list(String key) {
    final v = value(key);
    if (v is! List) throw FormatException('Expected array $key');
    return v;
  }

  List<String> strings(String key) => list(key).map((item) {
    if (item is! String) throw FormatException('Expected string in $key');
    return item;
  }).toList();

  T enumValue<T extends Enum>(String key, List<T> values) =>
      TrackingCodec._enum(value(key), values);

  DateTime time(String key) {
    final v = string(key);
    // Require exact UTC representation rather than accepting local timestamps,
    // overflow-normalised dates or multiple wire spellings of the same instant.
    final time = DateTime.tryParse(v);
    if (time == null || !time.isUtc || time.toIso8601String() != v) {
      throw FormatException('Expected canonical UTC timestamp $key');
    }
    return time;
  }
}
