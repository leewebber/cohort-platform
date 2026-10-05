/// Unwired, read-only interpretation of existing History actuals. The input
/// port is an authority boundary, not a results store or an ingestion API.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../domain/performance_tracking/performance_tracking.dart';

part 'history_tracking_read_contracts.dart';
part 'history_tracking_projection.dart';

final class HistoryTrackingAdapter {
  HistoryTrackingAdapter({
    required this.reader,
    required List<TrackingArtifact> definitions,
  }) : definitions = List.unmodifiable(definitions);

  final HistoryTrackingReadPort reader;
  final List<TrackingArtifact> definitions;

  Future<HistoryTrackingResult> read(HistoryTrackingQuery query) async {
    final actor = reader.authenticatedAthleteId;
    if (!_text(actor) || actor != query.athleteId) {
      return const HistoryTrackingFailure('ownership_denied');
    }
    if (query.historical) {
      return const HistoryTrackingFailure('historical_inputs_unavailable');
    }
    try {
      if (TrackingValidator().validate(definitions).isNotEmpty) {
        throw const _HistoryProblem('invalid_definition_closure');
      }
      final metrics = definitions.whereType<TrackingMetricDefinition>().where(
        (m) => _same(m.reference, query.metric),
      );
      if (metrics.length != 1) {
        throw const _HistoryProblem('unsupported_metric_reference');
      }
      final metric = metrics.single;
      final method = definitions
          .whereType<TrackingMethodDefinition>()
          .singleWhere((m) => _same(m.reference, metric.method));
      if (method.kind != TrackingMethodKind.fieldExtraction) {
        throw const _HistoryProblem('unsupported_method');
      }
      _validateSelection(query.field, metric);
      final frame = await reader.readCurrentRecord(
        query.field.recordId,
        programmeClaim: query.programmeClaim,
      );
      if (reader.authenticatedAthleteId != actor || frame.athleteId != actor) {
        throw const _HistoryProblem('ownership_denied');
      }
      if (frame.consistency != HistoryReadConsistency.singleStatementSnapshot ||
          !frame.completeRecordTree ||
          !frame.completeAuditSet) {
        throw const _HistoryProblem('coherent_read_required');
      }
      return _HistoryProjection(frame, query, metric).project();
    } on _HistoryProblem catch (problem) {
      return HistoryTrackingFailure(problem.code);
    } on FormatException {
      return const HistoryTrackingFailure('malformed_snapshot');
    } catch (_) {
      // Never expose transport exceptions or treat failed queries as emptiness.
      return const HistoryTrackingFailure('history_read_failed');
    }
  }
}

bool _text(String? value) =>
    value != null && value.isNotEmpty && value.trim() == value;
bool _hash(String? value) =>
    value != null && RegExp(r'^[0-9a-f]{64}$').hasMatch(value);
bool _same(TrackingReference a, TrackingReference b) =>
    a.id == b.id && a.version == b.version && a.digest == b.digest;

void _validateSelection(
  HistoryFieldSelection field,
  TrackingMetricDefinition metric,
) {
  if (![
        field.recordId,
        field.blockResultId,
        field.sourceBlockId,
      ].every(_text) ||
      field.fieldPath.isEmpty ||
      field.fieldPath.last != metric.captureField ||
      field.fieldPath.any(
        (s) => !RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(s),
      ) ||
      (field.expectedInputDigest != null &&
          !_hash(field.expectedInputDigest))) {
    throw const _HistoryProblem('invalid_field_reference');
  }
  for (final id in [
    field.exerciseResultId,
    field.setResultId,
    field.expectedCorrectionId,
  ]) {
    if (id != null && !_text(id)) {
      throw const _HistoryProblem('invalid_field_reference');
    }
  }
  if (field.setResultId != null && field.exerciseResultId == null) {
    throw const _HistoryProblem('set_requires_exercise_result');
  }
  final running =
      field.workoutId != null ||
      field.stepId != null ||
      field.repeatOrdinal != null;
  if (running &&
      (!_text(field.workoutId) ||
          !_text(field.stepId) ||
          field.repeatOrdinal == null ||
          field.repeatOrdinal! < 1 ||
          field.exerciseResultId != null ||
          field.setResultId != null)) {
    throw const _HistoryProblem('ambiguous_running_scope');
  }
  final path = field.fieldPath;
  final supported = field.setResultId != null
      ? path.length == 1 &&
            [
              'reps',
              'load',
              'distance',
              'duration_seconds',
            ].contains(path.single)
      : field.exerciseResultId == null &&
            (running
                ? path.length == 3 &&
                      path[0] == 'result_data' &&
                      path[1] == 'intervals' &&
                      path.last == 'paceSecondsPerKm'
                : path.length == 2 &&
                      path[0] == 'result_data' &&
                      ['durationSeconds', 'distance'].contains(path.last));
  if (!supported) throw const _HistoryProblem('unsupported_field_path');
}

final class _HistoryProblem implements Exception {
  const _HistoryProblem(this.code);
  final String code;
}

Map<String, Object?> _map(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw const _HistoryProblem('malformed_field_shape');
  }
  return Map<String, Object?>.from(value);
}

Object? _freeze(Object? value) {
  if (value is Map) {
    return Map<String, Object?>.unmodifiable(
      _map(value).map((k, v) => MapEntry(k, _freeze(v))),
    );
  }
  if (value is List) return List<Object?>.unmodifiable(value.map(_freeze));
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  throw const FormatException('History frame must contain JSON values');
}

Object? _sortJson(Object? value) {
  if (value is Map<String, Object?>) {
    final keys = value.keys.toList()..sort();
    return {for (final key in keys) key: _sortJson(value[key])};
  }
  if (value is List) return value.map(_sortJson).toList();
  return value;
}

String _digest(Object? value) =>
    sha256.convert(utf8.encode(jsonEncode(_sortJson(value)))).toString();
