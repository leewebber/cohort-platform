import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Hash contract binding one authored running workout and its ordered steps to
/// exact persisted executable session blocks.
abstract final class RunningExecutionMappingHash {
  static const algorithm = 'sha256';
  static const domain = 'cohort.running_execution_mapping.v1';

  static String compute({
    required String workoutId,
    required Iterable<({String stepId, String sessionBlockId})> bindings,
  }) {
    final canonical = StringBuffer('$domain|workout_id=$workoutId');
    for (final binding in bindings) {
      canonical
        ..write('|step_id=')
        ..write(binding.stepId)
        ..write(',session_block_id=')
        ..write(binding.sessionBlockId);
    }
    return sha256.convert(utf8.encode(canonical.toString())).toString();
  }
}
