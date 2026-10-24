import '../../domain/hyrox_base/programme_prescription.dart';
import 'dart:convert';

import '../../core/persistence/session_execution_plan_codec.dart';
import '../../features/session/models/session_execution_plan.dart';

Map<String, List<int>> authoredDurationWindows(SessionExecutionPlan plan) => {
  for (final block in plan.blocks)
    if (block.timerConfiguration?.durationSecondsRange case final range?)
      block.blockId: range.toJson(),
};

/// Validate a deliberate choice against every original inclusive source window.
/// This is preparation only; it does not manufacture a started/server snapshot.
void validateDurationChoices(
  SessionExecutionPlan plan,
  Map<String, int> choices,
) {
  final windows = authoredDurationWindows(plan);
  if (choices.length != windows.length ||
      choices.keys.any((id) => !windows.containsKey(id))) {
    throw const FormatException(
      'Choose a duration for each authored running window.',
    );
  }
  for (final entry in windows.entries) {
    final chosen = choices[entry.key];
    if (chosen == null || chosen < entry.value[0] || chosen > entry.value[1]) {
      throw const FormatException(
        'Selected duration lies outside its authored window.',
      );
    }
  }
}

/// Apply only the authenticated start response after its owner/occurrence scope
/// was checked by the existing launcher. No client-calculated target is trusted.
SessionExecutionPlan applyFrozenDurationChoices(
  SessionExecutionPlan plan,
  Map<String, dynamic> snapshot,
) {
  if (snapshot['schema_version'] != 1 ||
      snapshot['protocol_id'] != plan.sessionId ||
      snapshot['choices'] is! Map) {
    throw const FormatException('Invalid frozen duration-choice snapshot.');
  }
  final rows = Map<String, dynamic>.from(snapshot['choices'] as Map),
      chosen = <String, int>{};
  final windows = authoredDurationWindows(plan);
  for (final e in rows.entries) {
    if (e.value is! Map ||
        jsonEncode(e.value['authored_range_seconds']) !=
            jsonEncode(windows[e.key]) ||
        e.value['selected_seconds'] is! int) {
      throw const FormatException(
        'Frozen duration does not match the original source.',
      );
    }
    chosen[e.key] = e.value['selected_seconds'] as int;
  }
  validateDurationChoices(plan, chosen);
  if (plan.durationChoiceSnapshot != null &&
      !samePrescription(plan.durationChoiceSnapshot, snapshot)) {
    throw const FormatException('Started duration choice is immutable.');
  }
  const codec = SessionExecutionPlanCodec();
  final encoded = codec.encodePlan(plan);
  encoded['durationChoiceV1'] = _freeze(snapshot);
  for (final raw in encoded['blocks'] as List) {
    final block = raw as Map<String, dynamic>;
    if (chosen.containsKey(block['blockId'])) {
      final timer = block['timerConfiguration'] as Map<String, dynamic>;
      timer['durationSeconds'] = chosen[block['blockId']];
    }
  }
  return codec.decodePlan(encoded);
}

Object? _freeze(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.unmodifiable(
      value.map((k, v) => MapEntry(k as String, _freeze(v))),
    );
  }
  if (value is List) return List<Object?>.unmodifiable(value.map(_freeze));
  return value;
}
