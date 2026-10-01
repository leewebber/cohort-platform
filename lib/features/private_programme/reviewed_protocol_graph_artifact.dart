import 'dart:convert';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:crypto/crypto.dart';

import '../../domain/running_workout/running_workout.dart';
import '../../models/timer_configuration.dart';
import '../../models/workout_format.dart';

class ReviewedProtocolGraphArtifactException implements Exception {
  const ReviewedProtocolGraphArtifactException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}

/// Loads a separately reviewed protocol graph without weakening Plan Package
/// or hosted publication authority.
///
/// The file hash pins the review artifact. Its protocol/revision identities
/// must exactly cover the compiled package, and any B3 mapping is re-projected
/// from the graph's timer configuration and stable persisted block identity.
class ReviewedProtocolGraphArtifact {
  const ReviewedProtocolGraphArtifact();

  List<Map<String, Object?>> decode({
    required PlanPackageCompileResult compileResult,
    required String source,
    required String expectedSha256,
  }) {
    final manifest = compileResult.manifest;
    if (!compileResult.isValid || manifest == null) {
      throw const ReviewedProtocolGraphArtifactException(
        'invalid_plan_package',
        'A valid compiled Plan Package is required.',
      );
    }
    final actualHash = sha256.convert(utf8.encode(source)).toString();
    if (expectedSha256.trim() != actualHash) {
      throw const ReviewedProtocolGraphArtifactException(
        'protocol_graph_hash_mismatch',
        'The reviewed protocol graph hash does not match.',
      );
    }
    final decoded = jsonDecode(source);
    if (decoded is! List) {
      throw const ReviewedProtocolGraphArtifactException(
        'invalid_protocol_graph',
        'The reviewed protocol graph must be a JSON array.',
      );
    }
    final graphs = <String, Map<String, Object?>>{};
    for (final raw in decoded) {
      if (raw is! Map) {
        throw const ReviewedProtocolGraphArtifactException(
          'invalid_protocol_graph',
          'Every protocol graph must be an object.',
        );
      }
      final graph = Map<String, Object?>.from(raw);
      final protocolId = graph['protocol_id']?.toString().trim() ?? '';
      if (protocolId.isEmpty || graphs.containsKey(protocolId)) {
        throw const ReviewedProtocolGraphArtifactException(
          'duplicate_protocol_graph',
          'Protocol graph identities must be non-empty and unique.',
        );
      }
      graphs[protocolId] = graph;
    }
    final sessionsByKey = {
      for (final session in manifest.sessions) session.sessionKey: session,
    };
    final expectedProtocols = {
      for (final session in manifest.sessions) session.protocolId,
    };
    if (graphs.keys.toSet().difference(expectedProtocols).isNotEmpty ||
        expectedProtocols.difference(graphs.keys.toSet()).isNotEmpty) {
      throw const ReviewedProtocolGraphArtifactException(
        'protocol_graph_scope_mismatch',
        'Reviewed graphs must exactly cover compiled package protocols.',
      );
    }
    for (final session in manifest.sessions) {
      final graph = graphs[session.protocolId]!;
      if (_positiveInt(graph['revision_number']) != session.revisionNumber) {
        throw const ReviewedProtocolGraphArtifactException(
          'protocol_revision_mismatch',
          'Reviewed graph revision does not match the compiled package.',
        );
      }
      _blocks(graph);
    }
    for (final week in manifest.weeks) {
      for (final day in week.days) {
        for (final slot in day.slots) {
          final running = slot.authoredRunningV1;
          if (running?.executableStepBindings == null) continue;
          final session = sessionsByKey[slot.sessionKey];
          if (session == null) {
            throw const ReviewedProtocolGraphArtifactException(
              'session_scope_mismatch',
              'A running slot references an unknown package session.',
            );
          }
          _validateRunning(
            running: running!,
            protocolId: session.protocolId,
            graph: graphs[session.protocolId]!,
          );
        }
      }
    }
    return [for (final graph in graphs.values) graph];
  }

  void _validateRunning({
    required PlanPackageAuthoredRunningV1 running,
    required String protocolId,
    required Map<String, Object?> graph,
  }) {
    final bindings = running.executableStepBindings!;
    final blockIds = bindings.map((binding) => binding.sessionBlockId).toSet();
    if (blockIds.length != 1) {
      throw const ReviewedProtocolGraphArtifactException(
        'running_block_scope_mismatch',
        'A B3 fixture must map its steps to one exact executable block.',
      );
    }
    Map<String, Object?>? matched;
    for (final block in _blocks(graph)) {
      final position = _positiveInt(block['position']);
      if (position == null) continue;
      if (_stableBlockId(protocolId, position) == blockIds.single) {
        matched = block;
        break;
      }
    }
    if (matched == null) {
      throw const ReviewedProtocolGraphArtifactException(
        'running_block_identity_mismatch',
        'The reviewed graph cannot create the mapped session block.',
      );
    }
    final timerRaw = matched['timer_config'];
    if (timerRaw is! Map) {
      throw const ReviewedProtocolGraphArtifactException(
        'missing_running_timer',
        'The mapped running block requires a timer configuration.',
      );
    }
    final projected = const RunningWorkoutProjector().project(
      format: WorkoutFormatDb.fromDb(matched['workout_format']?.toString()),
      configuration: TimerConfiguration.fromJson(
        Map<String, dynamic>.from(timerRaw),
      ),
      sourceRef: blockIds.single,
    );
    final workout = projected.workout;
    if (!projected.isSupported ||
        workout == null ||
        workout.workoutId != running.workoutId ||
        !_same(projectedStepIds(workout), running.stepIds) ||
        !_same(
          bindings.map((binding) => binding.stepId).toList(),
          running.stepIds,
        )) {
      throw const ReviewedProtocolGraphArtifactException(
        'running_projection_mismatch',
        'The reviewed timer does not reproduce the authored running identity.',
      );
    }
  }

  List<String> projectedStepIds(RunningWorkout workout) {
    final json = jsonDecode(const RunningWorkoutCodec().encode(workout)) as Map;
    final ids = <String>[];
    for (final node in json['steps'] as List) {
      final map = node as Map;
      if (map['kind'] == 'atomic') {
        ids.add(map['step_id'] as String);
      } else {
        for (final child in map['steps'] as List) {
          ids.add((child as Map)['step_id'] as String);
        }
      }
    }
    return ids;
  }

  List<Map<String, Object?>> _blocks(Map<String, Object?> graph) {
    final raw = graph['blocks'];
    if (raw is! List || raw.isEmpty) {
      throw const ReviewedProtocolGraphArtifactException(
        'invalid_protocol_graph',
        'Every reviewed protocol graph requires at least one block.',
      );
    }
    final blocks = <Map<String, Object?>>[];
    final positions = <int>{};
    for (final item in raw) {
      if (item is! Map) {
        throw const ReviewedProtocolGraphArtifactException(
          'invalid_protocol_graph',
          'Reviewed blocks must be objects.',
        );
      }
      final block = Map<String, Object?>.from(item);
      final position = _positiveInt(block['position']);
      if (position == null || !positions.add(position)) {
        throw const ReviewedProtocolGraphArtifactException(
          'invalid_block_position',
          'Reviewed block positions must be positive and unique.',
        );
      }
      blocks.add(block);
    }
    return blocks;
  }

  static int? _positiveInt(Object? value) {
    final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
    return parsed != null && parsed > 0 ? parsed : null;
  }

  static String _stableBlockId(String protocolId, int position) {
    final hex = md5
        .convert(utf8.encode('$protocolId:block:$position'))
        .toString();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-4'
        '${hex.substring(12, 15)}-8${hex.substring(16, 19)}-'
        '${hex.substring(20, 32)}';
  }

  static bool _same(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }
}
