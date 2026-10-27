import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../../../domain/running_workout/running_workout.dart';
import '../../../models/block_performance_capture_mode.dart';
import 'session_execution_plan.dart';
import 'running_target_admission.dart';
import 'structured_running_execution.dart';

/// Derives execution from an exact physical block body, not a benchmark policy.
/// The digest occupies the shared cursor's legacy mapping-hash field only in the
/// separate authored-timed-run container; it never claims B2 mapping authority.
class AuthoredTimedRunningExecution extends TimedRunningExecution {
  const AuthoredTimedRunningExecution._({
    required this.sessionBlockId,
    required this.workout,
    required this.executionMappingSha256,
    required this.authoredGuidance,
  });

  @override
  final String sessionBlockId;
  @override
  final RunningWorkout workout;
  @override
  final String executionMappingSha256;
  @override
  final String? authoredGuidance;
  @override
  bool get pauseOnInterruption => true;

  factory AuthoredTimedRunningExecution.fromBlock(
    SessionExecutionBlock block, {
    Map<String, dynamic>? admission,
  }) {
    final config = block.timerConfiguration;
    if (config?.runningWorkout == null ||
        !block.hasTimer ||
        block.boundTarget != null ||
        (block.performanceCaptureMode !=
                BlockPerformanceCaptureMode.automatic &&
            block.performanceCaptureMode !=
                BlockPerformanceCaptureMode.endurance)) {
      throw const FormatException('This authored timed run is not executable.');
    }
    const codec = RunningWorkoutCodec();
    final decoded = resolveAdmittedZone2(
      codec.decode(codec.encode(config!.runningWorkout!)),
      block.blockId,
      admission,
    );
    // Own an immutable source snapshot for the lifetime of this execution.
    final workout = RunningWorkout(
      schemaVersion: decoded.schemaVersion,
      workoutId: decoded.workoutId,
      title: decoded.title,
      intent: decoded.intent,
      notes: decoded.notes,
      provenance: decoded.provenance,
      steps: List.unmodifiable(
        decoded.steps.map(
          (node) => switch (node) {
            RunningAtomicStep() => node,
            RunningRepeatGroup() => RunningRepeatGroup(
              groupId: node.groupId,
              count: node.count,
              steps: List.unmodifiable(node.steps),
            ),
          },
        ),
      ),
    );
    final digest = sha256
        .convert(
          utf8.encode(
            jsonEncode({
              'session_block_id': block.blockId,
              if (admission != null) 'admission': _orderedAdmission(admission),
              'duration_seconds': config.durationSeconds,
              'running_workout': codec.toJson(workout),
            }),
          ),
        )
        .toString();
    final guidance = [
      block.content,
      block.coachNotes,
      workout.intent,
      workout.notes,
    ].whereType<String>().where((s) => s.trim().isNotEmpty).join('\n');
    return AuthoredTimedRunningExecution._(
      sessionBlockId: block.blockId,
      workout: workout,
      executionMappingSha256: digest,
      authoredGuidance: guidance.isEmpty ? null : guidance,
    );
  }
}

// JSON object order is not part of the accepted prescription identity.
Object? _orderedAdmission(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _orderedAdmission(value[key])};
  }
  if (value is List) return value.map(_orderedAdmission).toList();
  return value;
}
