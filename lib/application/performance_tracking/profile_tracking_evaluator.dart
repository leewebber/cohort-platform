/// Unwired, synchronous evaluation of trusted C2 outcomes. No read authority,
/// storage, arithmetic, automatic selection or prescription permission.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../domain/performance_tracking/performance_tracking.dart';
import 'history_tracking_adapter.dart';

part 'profile_tracking_evaluation_contracts.dart';

final class ProfileTrackingEvaluator {
  ProfileTrackingEvaluator({required List<TrackingArtifact> definitions})
    : definitions = List.unmodifiable(definitions);

  final List<TrackingArtifact> definitions;

  ProfileTrackingEvaluation evaluate({
    required String athleteId,
    required List<TrackingProfileRequest> profiles,
    required List<TrackingEvaluationInput> inputs,
    List<TrackingComparisonRequest> comparisons = const [],
  }) {
    try {
      if (!_text(athleteId)) throw const _Problem('invalid_athlete');
      if (TrackingValidator().validate(definitions).isNotEmpty) {
        throw const _Problem('invalid_definition_closure');
      }
      final context = _EvaluationContext(definitions, athleteId);
      if (inputs.any((i) => !_text(i.id)) ||
          inputs.map((i) => i.id).toSet().length != inputs.length) {
        throw const _Problem('duplicate_or_invalid_input_identity');
      }
      if (profiles.map((r) => _hash(r.profile.toJson())).toSet().length !=
          profiles.length) {
        throw const _Problem('duplicate_profile_request');
      }
      if (comparisons.any((r) => !_text(r.id)) ||
          comparisons.map((r) => r.id).toSet().length != comparisons.length) {
        throw const _Problem('duplicate_or_invalid_comparison_identity');
      }

      final byAlias = <String, _Input>{};
      for (final input
          in inputs.toList()..sort((a, b) => a.id.compareTo(b.id))) {
        if (!_text(input.id) || byAlias.containsKey(input.id)) {
          throw const _Problem('duplicate_or_invalid_input_identity');
        }
        byAlias[input.id] = context.input(input);
      }
      final sources = <String, List<_Input>>{};
      for (final input in byAlias.values) {
        if (input.observation != null) {
          sources.putIfAbsent(input.physicalId, () => []).add(input);
        }
      }
      // Validate all aliases, regardless of profile membership or query mode.
      for (final group in sources.values) {
        context.aliases(group);
      }
      context.batch(byAlias.values.toList());
      final profileRows = <String, Map<String, Object?>>{};
      for (final request
          in profiles.toList()..sort(
            (a, b) =>
                _hash(a.profile.toJson()).compareTo(_hash(b.profile.toJson())),
          )) {
        final key = _hash(request.profile.toJson());
        if (profileRows.containsKey(key)) {
          throw const _Problem('duplicate_profile_request');
        }
        profileRows[key] = context.profile(request, byAlias.values.toList());
      }
      final comparisonRows = <String, Map<String, Object?>>{};
      for (final request
          in comparisons.toList()..sort((a, b) => a.id.compareTo(b.id))) {
        if (!_text(request.id) || comparisonRows.containsKey(request.id)) {
          throw const _Problem('duplicate_or_invalid_comparison_identity');
        }
        comparisonRows[request.id] = context.compare(request, byAlias);
      }
      final observationRows = <Map<String, Object?>>[];
      for (final physicalId in sources.keys.toList()..sort()) {
        final views = <String, Map<String, Object?>>{};
        for (final input in sources[physicalId]!) {
          final row = views.putIfAbsent(
            input.viewId,
            () => {...input.view, 'aliases': <String>[]},
          );
          (row['aliases'] as List<String>).add(input.input.id);
        }
        for (final row in views.values) {
          (row['aliases'] as List<String>).sort();
        }
        observationRows.add({
          'physical_id': physicalId,
          'athlete_id': athleteId,
          'source_identity': jsonDecode(
            sources[physicalId]!.first.input.query.field.sourceIdentity,
          ),
          'views': [for (final id in views.keys.toList()..sort()) views[id]],
        });
      }
      return ProfileTrackingEvaluation._({
        'evaluation_schema': 1,
        'athlete_id': athleteId,
        'state': profiles.isEmpty ? 'profile_not_configured' : 'evaluated',
        'policy': TrackingComparabilityPolicy.reference.toJson(),
        'profiles': [
          for (final id in profileRows.keys.toList()..sort()) profileRows[id],
        ],
        'observations': observationRows,
        'inputs': [
          for (final id in byAlias.keys.toList()..sort())
            byAlias[id]!.referenceJson,
        ],
        'comparisons': [
          for (final id in comparisonRows.keys.toList()..sort())
            comparisonRows[id],
        ],
        'grants_prescription_eligibility': false,
        'can_reconstruct_historical_inputs': false,
      });
    } on _Problem catch (error) {
      return ProfileTrackingEvaluation._({
        'evaluation_schema': 1,
        'state': 'failure',
        'reason': error.code,
        'grants_prescription_eligibility': false,
        'can_reconstruct_historical_inputs': false,
      });
    }
  }
}

final class _EvaluationContext {
  _EvaluationContext(this.definitions, this.athlete);
  final List<TrackingArtifact> definitions;
  final String athlete;

  T resolve<T extends TrackingArtifact>(TrackingReference reference) {
    final matches = definitions.whereType<T>().where(
      (a) => _same(a.reference, reference),
    );
    if (matches.length != 1) {
      throw const _Problem('unsupported_exact_reference');
    }
    return matches.single;
  }

  TrackingMetricDefinition metric(TrackingReference reference) {
    final metric = resolve<TrackingMetricDefinition>(reference);
    final method = resolve<TrackingMethodDefinition>(metric.method);
    if (method.kind != TrackingMethodKind.fieldExtraction) {
      throw const _Problem('unsupported_method');
    }
    if (!metric.allowedSources.contains(TrackingSourceKind.historyResult)) {
      throw const _Problem('unsupported_source');
    }
    if (!_supportedMetric(metric)) throw const _Problem('unsupported_metric');
    return metric;
  }

  _Input input(TrackingEvaluationInput input) {
    final query = input.query;
    if (query.athleteId != athlete) throw const _Problem('ownership_denied');
    if (query.historical) throw const _Problem('historical_inputs_unavailable');
    final definition = metric(query.metric);
    final field = query.field;
    if (!_validField(field, definition)) {
      throw const _Problem('unsupported_field_reference');
    }
    final physicalId = _hash([athlete, jsonDecode(field.sourceIdentity)]);
    final result = input.result;
    final claim = query.programmeClaim;
    if (claim != null &&
        (claim.scope.blockId != field.sourceBlockId ||
            claim.scope.workoutId != field.workoutId ||
            claim.scope.stepId != field.stepId ||
            claim.scope.repeatOrdinal != field.repeatOrdinal ||
            !_text(claim.scope.programmeVersionId) ||
            !_digest(claim.scope.packageHash) ||
            !_text(claim.scope.slotKey) ||
            !_text(claim.scope.protocolId) ||
            claim.scope.protocolRevision < 1 ||
            (field.workoutId != null &&
                (claim.scope.mappingHash == null ||
                    !_digest(claim.scope.mappingHash!))) ||
            (field.workoutId == null && claim.scope.mappingHash != null) ||
            !_text(claim.assignmentId) ||
            !_text(claim.occurrenceId) ||
            !_text(claim.trainingSessionId))) {
      throw const _Problem('programme_scope_conflict');
    }
    final base = <String, Object?>{
      'metric': query.metric.toJson(),
      'method': definition.method.toJson(),
      'physical_id': physicalId,
      'requested_source_identity': jsonDecode(field.sourceIdentity),
      'field_scope': _scope(field),
      'programme_claim': claim == null ? null : _claim(claim),
      'expected_context': query.expectedContext,
      'expected_input_digest': field.expectedInputDigest,
      'expected_correction_id': field.expectedCorrectionId,
      'grants_prescription_eligibility': false,
      'can_reconstruct_historical_inputs': false,
    };
    switch (result) {
      case HistoryTrackingFailure():
        if (!_text(result.code)) throw const _Problem('malformed_outcome');
        base.addAll({
          'state': 'failure',
          'reason': result.code,
          'tracking_eligible': false,
          'programme_attribution': claim == null
              ? 'not_requested'
              : result.code == 'programme_scope_unproven'
              ? 'unproven'
              : 'failed',
        });
      case HistoryTrackingAbsent():
        if (!_text(result.reason)) throw const _Problem('malformed_outcome');
        base.addAll({
          'state': 'missing',
          'evidence': result.evidence.toJson(),
          'tracking_eligible': false,
          'programme_attribution': claim == null ? 'not_requested' : 'unproven',
        });
      case HistoryTrackingObservation():
        final source = result.source;
        if (HistoryFieldSelection.fromReference(source).sourceIdentity !=
                field.sourceIdentity ||
            result.sourceIdentity != field.sourceIdentity ||
            !_digest(source.inputDigest) ||
            !_digest(result.auditSetDigest) ||
            source.correctionId != field.expectedCorrectionId ||
            (field.expectedInputDigest != null &&
                field.expectedInputDigest != source.inputDigest) ||
            result.correctionIds.toSet().length !=
                result.correctionIds.length ||
            result.correctionIds.any((id) => !_text(id)) ||
            (source.correctionId != null &&
                !result.correctionIds.contains(source.correctionId))) {
          throw const _Problem('source_reference_conflict');
        }
        _validateObservation(result, definition, query);
        base.addAll({
          'state': result.evidence.state.name,
          'evidence': result.evidence.toJson(),
          'source': source.toJson(),
          'value': result.value,
          'unit': result.unit?.name,
          'context': result.context,
          'chronology': result.chronology,
          'correction_ids': result.correctionIds.toList()..sort(),
          'audit_set_digest': result.auditSetDigest,
          'tracking_eligible': result.trackingEligible,
          'programme_attribution': claim == null ? 'not_requested' : 'proven',
        });
    }
    return _Input(input, definition, physicalId, base);
  }

  void batch(List<_Input> inputs) {
    final parents = <String, String>{};
    final records = <String, String>{};
    final origins = <String, String>{};
    void declare(
      Map<String, String> index,
      String key,
      Object? value,
      String code,
    ) {
      final encoded = _json(value);
      final prior = index[key];
      if (prior != null && prior != encoded) throw _Problem(code);
      index[key] = encoded;
    }

    for (final input in inputs) {
      final observation = input.observation;
      if (observation == null) continue; // A failed query attests no parents.
      final field = input.input.query.field;
      declare(parents, 'block:${field.blockResultId}', [
        field.recordId,
        field.sourceBlockId,
      ], 'source_parent_conflict');
      if (field.exerciseResultId != null) {
        declare(
          parents,
          'exercise:${field.exerciseResultId}',
          field.blockResultId,
          'source_parent_conflict',
        );
      }
      if (field.setResultId != null) {
        declare(
          parents,
          'set:${field.setResultId}',
          field.exerciseResultId,
          'source_parent_conflict',
        );
      }
      for (final audit in observation.correctionIds) {
        declare(
          parents,
          'audit:$audit',
          field.recordId,
          'source_parent_conflict',
        );
      }
      declare(records, field.recordId, {
        'chronology': observation.chronology,
        'audit_set_digest': observation.auditSetDigest,
        'correction_ids': observation.correctionIds.toList()..sort(),
      }, 'inconsistent_record_provenance');
      final claim = input.input.query.programmeClaim;
      if (claim != null) {
        declare(origins, field.recordId, {
          'assignment': claim.assignmentId,
          'occurrence': claim.occurrenceId,
          'session': claim.trainingSessionId,
          'version': claim.scope.programmeVersionId,
          'hash': claim.scope.packageHash,
          'slot': claim.scope.slotKey,
          'protocol': claim.scope.protocolId,
          'protocol_revision': claim.scope.protocolRevision,
        }, 'programme_scope_conflict');
      }
    }
  }

  void aliases(List<_Input> inputs) {
    for (var i = 0; i < inputs.length; i++) {
      final a = inputs[i].observation!;
      for (final other in inputs.skip(i + 1)) {
        final b = other.observation!;
        if (_hash(a.context) != _hash(b.context) ||
            _hash(a.chronology) != _hash(b.chronology) ||
            a.auditSetDigest != b.auditSetDigest ||
            _hash(a.correctionIds.toList()..sort()) !=
                _hash(b.correctionIds.toList()..sort()) ||
            a.evidence.recordedCount != b.evidence.recordedCount ||
            (_captureState(a) != null &&
                _captureState(b) != null &&
                _captureState(a) != _captureState(b)) ||
            (a.unit != null && b.unit != null && a.unit != b.unit) ||
            (a.value != null && b.value != null && a.value != b.value) ||
            (_same(
                  inputs[i].definition.reference,
                  other.definition.reference,
                ) &&
                a.source.inputDigest != b.source.inputDigest)) {
          throw const _Problem('conflicting_source_aliases');
        }
      }
    }
  }

  Map<String, Object?> profile(
    TrackingProfileRequest request,
    List<_Input> inputs,
  ) {
    final profile = resolve<TrackingProfile>(request.profile);
    if (profile.athleteId != null && profile.athleteId != athlete) {
      throw const _Problem('ownership_denied');
    }
    TrackingSelectionRevision? selection;
    if (request.selection != null) {
      selection = resolve<TrackingSelectionRevision>(request.selection!);
      if (selection.athleteId != athlete ||
          !_same(selection.profile, profile.reference)) {
        throw const _Problem('selection_reference_conflict');
      }
    }
    if (request.automaticSelection) {
      throw const _Problem('automatic_selection_unsupported');
    }
    final bindingRef = request.programmeBinding;
    if (selection != null &&
        !_optionalSame(selection.programmeBinding, bindingRef)) {
      throw const _Problem('binding_reference_conflict');
    }
    if (bindingRef != null) {
      final binding = resolve<TrackingProgrammeBinding>(bindingRef);
      if (!_same(binding.profile, profile.reference)) {
        throw const _Problem('binding_reference_conflict');
      }
      // A declared binding cannot upgrade unproven scope. Proven programme
      // projections must also match the bound version/hash.
      for (final input in inputs) {
        final claim = input.input.query.programmeClaim;
        if (claim != null &&
            profile.metrics.any((m) => _same(m, input.definition.reference)) &&
            (claim.scope.programmeVersionId != binding.programmeVersionId ||
                claim.scope.packageHash != binding.packageHash)) {
          throw const _Problem('binding_scope_conflict');
        }
      }
    }
    for (final ref in profile.metrics) {
      metric(ref); // Reject unsupported definitions even without observations.
    }
    final deselected = selection?.action == TrackingSelectionAction.deselect;
    return {
      'profile': profile.reference.toJson(),
      'view': profile.view.name,
      'selection': selection?.reference.toJson(),
      'programme_binding': bindingRef?.toJson(),
      'state': deselected ? 'not_selected' : 'evaluated',
      'members': [
        if (!deselected)
          for (final metric in profile.metrics)
            {
              'metric': metric.toJson(),
              'state': inputs.any((i) => _same(i.definition.reference, metric))
                  ? 'evaluated'
                  : 'missing',
              'input_ids': [
                for (final id
                    in inputs
                        .where((i) => _same(i.definition.reference, metric))
                        .map((i) => i.input.id)
                        .toList()
                      ..sort())
                  id,
              ],
              'physical_ids':
                  inputs
                      .where(
                        (i) =>
                            _same(i.definition.reference, metric) &&
                            i.observation != null,
                      )
                      .map((i) => i.physicalId)
                      .toSet()
                      .toList()
                    ..sort(),
            },
      ],
    };
  }

  Map<String, Object?> compare(
    TrackingComparisonRequest request,
    Map<String, _Input> inputs,
  ) {
    if (!_same(request.policy, TrackingComparabilityPolicy.reference)) {
      throw const _Problem('unsupported_comparison_policy');
    }
    final definition = metric(request.metric);
    final left = inputs[request.leftInputId];
    final right = inputs[request.rightInputId];
    if (left == null || right == null) {
      throw const _Problem('comparison_input_not_found');
    }
    final mismatches = <String>{};
    final unavailable = <String>{};
    if (!_same(left.definition.reference, request.metric) ||
        !_same(right.definition.reference, request.metric)) {
      mismatches.add('metric_version_incompatible');
    }
    if (!_same(left.definition.method, right.definition.method)) {
      mismatches.add('method_incompatible');
    }
    if (left.physicalId == right.physicalId) {
      mismatches.add('same_observation');
    }
    if (_hash(_scope(left.input.query.field)) !=
        _hash(_scope(right.input.query.field))) {
      mismatches.add('field_scope_incompatible');
    }
    final a = left.observation;
    final b = right.observation;
    for (final input in [left, right]) {
      if (input.observation?.trackingEligible != true) {
        unavailable.add('evidence_not_available');
      }
    }
    // Declared units still expose contradictions when an operand is missing.
    if (left.definition.unit != right.definition.unit ||
        (a?.unit != null && a!.unit != definition.unit) ||
        (b?.unit != null && b!.unit != definition.unit)) {
      mismatches.add('unit_incompatible');
    }
    for (final key in {'comparison_family', ...definition.requiredContext}) {
      final x = a?.context[key];
      final y = b?.context[key];
      if (x != null && y != null && x != y) {
        mismatches.add('context_incompatible:$key');
      }
      if (!_text(x) || !_text(y)) {
        unavailable.add('context_unavailable:$key');
      }
    }
    return {
      'id': request.id,
      'metric': request.metric.toJson(),
      'policy': request.policy.toJson(),
      'left': left.referenceJson,
      'right': right.referenceJson,
      'state': mismatches.isNotEmpty
          ? 'incomparable'
          : unavailable.isNotEmpty
          ? 'comparison_unavailable'
          : 'comparable',
      'reasons': [...mismatches, ...unavailable]..sort(),
      'grants_prescription_eligibility': false,
      'can_reconstruct_historical_inputs': false,
    };
  }
}

final class _Input {
  _Input(this.input, this.definition, this.physicalId, this.view);
  final TrackingEvaluationInput input;
  final TrackingMetricDefinition definition;
  final String physicalId;
  final Map<String, Object?> view;
  HistoryTrackingObservation? get observation =>
      input.result is HistoryTrackingObservation
      ? input.result as HistoryTrackingObservation
      : null;
  String get viewId => _hash(view);
  Map<String, Object?> get referenceJson => {
    'id': input.id,
    'physical_id': physicalId,
    'view_digest': viewId,
    if (observation == null) 'outcome': view,
  };
}

bool _supportedMetric(TrackingMetricDefinition metric) =>
    switch (metric.captureField) {
      'durationSeconds' ||
      'duration_seconds' => metric.unit == TrackingUnit.seconds,
      'reps' => metric.unit == TrackingUnit.count,
      'load' => metric.unit == TrackingUnit.kilograms,
      'distance' => [
        TrackingUnit.metres,
        TrackingUnit.kilometres,
      ].contains(metric.unit),
      'paceSecondsPerKm' => metric.unit == TrackingUnit.secondsPerKilometre,
      _ => false,
    };

bool _validField(HistoryFieldSelection field, TrackingMetricDefinition metric) {
  if (![
        field.recordId,
        field.blockResultId,
        field.sourceBlockId,
      ].every(_text) ||
      field.fieldPath.isEmpty ||
      field.fieldPath.last != metric.captureField ||
      (field.expectedInputDigest != null &&
          !_digest(field.expectedInputDigest!)) ||
      (field.expectedCorrectionId != null &&
          !_text(field.expectedCorrectionId))) {
    return false;
  }
  final running =
      field.workoutId != null ||
      field.stepId != null ||
      field.repeatOrdinal != null;
  if (running) {
    return _text(field.workoutId) &&
        _text(field.stepId) &&
        field.repeatOrdinal != null &&
        field.repeatOrdinal! > 0 &&
        field.exerciseResultId == null &&
        field.setResultId == null &&
        _json(field.fieldPath) ==
            _json(['result_data', 'intervals', 'paceSecondsPerKm']);
  }
  if (field.setResultId != null) {
    return _text(field.exerciseResultId) &&
        _text(field.setResultId) &&
        field.fieldPath.length == 1 &&
        [
          'reps',
          'load',
          'distance',
          'duration_seconds',
        ].contains(field.fieldPath.single);
  }
  return field.exerciseResultId == null &&
      field.fieldPath.length == 2 &&
      field.fieldPath.first == 'result_data' &&
      ['durationSeconds', 'distance'].contains(field.fieldPath.last);
}

void _validateObservation(
  HistoryTrackingObservation result,
  TrackingMetricDefinition metric,
  HistoryTrackingQuery query,
) {
  final supportedUnits = switch (query.field.fieldPath.last) {
    'durationSeconds' || 'duration_seconds' => {TrackingUnit.seconds},
    'reps' => {TrackingUnit.count},
    'load' => {TrackingUnit.kilograms},
    'distance' => {TrackingUnit.metres, TrackingUnit.kilometres},
    'paceSecondsPerKm' => {TrackingUnit.secondsPerKilometre},
    _ => <TrackingUnit>{},
  };
  if (result.unit != null && !supportedUnits.contains(result.unit)) {
    throw const _Problem('malformed_source_unit');
  }
  final state = result.evidence.state;
  final value = result.value;
  final coverage = result.evidence;
  final chronology = result.chronology;
  final precision = chronology['precision'];
  if (result.context.entries.any((e) => !_text(e.key) || !_text(e.value)) ||
      !(precision == 'timestamp' &&
              chronology.length == 2 &&
              chronology['performed_at'] is String &&
              DateTime.tryParse(chronology['performed_at'] as String)?.isUtc ==
                  true ||
          precision == 'civil_date' &&
              chronology.length == 3 &&
              chronology['performed_on'] is String &&
              chronology['timezone'] == null &&
              _validDate(chronology['performed_on'] as String))) {
    throw const _Problem('malformed_observation');
  }
  if (state != TrackingEvidenceState.available && !_text(coverage.reason) ||
      coverage.requiredCount != 1 ||
      ![0, 1].contains(coverage.recordedCount) ||
      state == TrackingEvidenceState.available && coverage.recordedCount != 1 ||
      state == TrackingEvidenceState.partial && coverage.recordedCount != 0 ||
      value != null &&
          (!RegExp(r'^(0|[1-9][0-9]*)(\.[0-9]*[1-9])?$').hasMatch(value) ||
              result.unit == null ||
              [
                    TrackingUnit.count,
                    TrackingUnit.seconds,
                  ].contains(result.unit) &&
                  value.contains('.') ||
              result.unit == TrackingUnit.secondsPerKilometre &&
                  value == '0') ||
      [
            TrackingEvidenceState.missing,
            TrackingEvidenceState.skipped,
            TrackingEvidenceState.unavailable,
          ].contains(state) &&
          (value != null || coverage.recordedCount != 0) ||
      state == TrackingEvidenceState.partial &&
          !metric.allowPartial &&
          value != null) {
    throw const _Problem('malformed_observation');
  }
  if (state == TrackingEvidenceState.available &&
      (value == null ||
          result.unit != metric.unit ||
          metric.requiresAssessment ||
          metric.freshnessCivilDays != null ||
          metric.requiredContext.any((k) => !_text(result.context[k])) ||
          query.expectedContext.entries.any(
            (e) => result.context[e.key] != e.value,
          ))) {
    throw const _Problem('contradictory_tracking_eligibility');
  }
}

/// C2 counts capture completeness before metric-specific eligibility policies.
/// Ineligible/incomparable partial views may hide their original capture state;
/// keep that uncertainty instead of inferring a missing/skipped classification.
TrackingEvidenceState? _captureState(HistoryTrackingObservation observation) {
  if (observation.evidence.recordedCount == 1) {
    return TrackingEvidenceState.available;
  }
  return switch (observation.evidence.state) {
    TrackingEvidenceState.partial ||
    TrackingEvidenceState.missing ||
    TrackingEvidenceState.skipped ||
    TrackingEvidenceState.unavailable => observation.evidence.state,
    _ => null,
  };
}

bool _validDate(String value) {
  final parsed = DateTime.tryParse('${value}T00:00:00Z');
  return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) &&
      parsed != null &&
      parsed.toIso8601String().substring(0, 10) == value;
}

Map<String, Object?> _scope(HistoryFieldSelection field) => {
  'kind': field.setResultId != null
      ? 'set'
      : field.workoutId != null
      ? 'running'
      : 'block',
  'path': field.fieldPath,
};
Map<String, Object?> _claim(HistoryProgrammeClaim claim) => {
  'assignment_id': claim.assignmentId,
  'occurrence_id': claim.occurrenceId,
  'training_session_id': claim.trainingSessionId,
  'scope': claim.scope.toJson(),
};
bool _text(String? value) =>
    value != null && value.isNotEmpty && value.trim() == value;
bool _digest(String value) => RegExp(r'^[0-9a-f]{64}$').hasMatch(value);
bool _same(TrackingReference a, TrackingReference b) =>
    a.id == b.id && a.version == b.version && a.digest == b.digest;
bool _optionalSame(TrackingReference? a, TrackingReference? b) =>
    a == null ? b == null : b != null && _same(a, b);

final class _Problem implements Exception {
  const _Problem(this.code);
  final String code;
}

Object? _sort(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _sort(value[key])};
  }
  if (value is List) return value.map(_sort).toList();
  return value;
}

String _json(Object? value) => jsonEncode(_sort(value));
String _hash(Object? value) =>
    sha256.convert(utf8.encode(_json(value))).toString();
Object? _freeze(Object? value) {
  if (value is Map) {
    return Map<String, Object?>.unmodifiable(
      value.map((key, v) => MapEntry(key as String, _freeze(v))),
    );
  }
  if (value is List) return List<Object?>.unmodifiable(value.map(_freeze));
  return value;
}
