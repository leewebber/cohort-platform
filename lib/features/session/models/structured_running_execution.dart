import '../../../domain/running_workout/running_workout.dart';
import '../models/session_execution_plan.dart';

enum StructuredRunningPhase { work, recovery }

enum StructuredRunningManualEvidenceState { notCaptured, captured }

class StructuredRunningExecutionException implements Exception {
  const StructuredRunningExecutionException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'StructuredRunningExecutionException($code): $message';
}

/// Identity-bound authority for the opt-in B3 structured runner.
///
/// It is constructed only from the already validated B3 slice 1 launch result
/// and independently rechecks the exact B1 projection. Titles and positions
/// are deliberately absent from this contract.
class VerifiedStructuredRunningExecution {
  const VerifiedStructuredRunningExecution._({
    required this.sessionBlockId,
    required this.executionMappingSha256,
    required this.workout,
    required this.frozenSnapshot,
  });

  final String sessionBlockId;
  final String executionMappingSha256;
  final RunningWorkout workout;
  final RunningTargetSnapshotAggregate frozenSnapshot;

  factory VerifiedStructuredRunningExecution.fromLaunch({
    required SessionExecutionPlan plan,
    required AuthoredRunningExecutionAuthority authority,
    required RunningTargetSnapshotAggregate frozenSnapshot,
  }) {
    final bindings = authority.executableStepBindings;
    final mappingHash = authority.executionMappingSha256;
    final blockId = authority.exactSessionBlockId;
    if (bindings == null ||
        bindings.isEmpty ||
        mappingHash == null ||
        mappingHash.isEmpty ||
        blockId == null ||
        frozenSnapshot.workoutId != authority.workoutId) {
      throw const StructuredRunningExecutionException(
        'unverified_launch_authority',
        'Structured running launch authority is incomplete.',
      );
    }
    final blocks = plan.blocks.where((block) => block.blockId == blockId);
    if (blocks.length != 1 || blocks.single.timerConfiguration == null) {
      throw const StructuredRunningExecutionException(
        'mapped_block_mismatch',
        'The mapped running block is not uniquely executable.',
      );
    }
    final block = blocks.single;
    final projected = const RunningWorkoutProjector().project(
      format: block.workoutFormat,
      configuration: block.timerConfiguration!,
      sourceRef: block.blockId,
    );
    final workout = projected.workout;
    if (!projected.isSupported ||
        workout == null ||
        workout.workoutId != authority.workoutId) {
      throw const StructuredRunningExecutionException(
        'workout_projection_mismatch',
        'The pinned workout does not match the mapped executable block.',
      );
    }
    final projectedIds = <String>[];
    for (final node in workout.steps) {
      switch (node) {
        case RunningAtomicStep():
          projectedIds.add(node.stepId);
        case RunningRepeatGroup():
          projectedIds.addAll(node.steps.map((step) => step.stepId));
      }
    }
    if (!_sameIds(projectedIds, authority.stepIds) ||
        bindings.any((binding) => binding.sessionBlockId != blockId)) {
      throw const StructuredRunningExecutionException(
        'step_scope_mismatch',
        'The mapped running steps do not match the pinned workout.',
      );
    }
    for (final node in workout.steps) {
      switch (node) {
        case RunningAtomicStep():
          _requireTime(node);
        case RunningRepeatGroup():
          for (final step in node.steps) {
            _requireTime(step);
          }
      }
    }
    return VerifiedStructuredRunningExecution._(
      sessionBlockId: blockId,
      executionMappingSha256: mappingHash,
      workout: workout,
      frozenSnapshot: frozenSnapshot,
    );
  }

  static void _requireTime(RunningAtomicStep step) {
    if (step.duration.kind != RunningDurationKind.time ||
        (step.duration.milliseconds ?? 0) <= 0) {
      throw const StructuredRunningExecutionException(
        'unsupported_duration',
        'B3 slice 2 supports positive time-based steps only.',
      );
    }
  }

  static bool _sameIds(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}

/// Lossless B3 running position persisted inside the production UI cursor.
class StructuredRunningCursor {
  const StructuredRunningCursor({
    required this.schemaVersion,
    required this.workoutId,
    required this.executionMappingSha256,
    required this.sessionBlockId,
    required this.authoredStepId,
    required this.repeatOrdinal,
    required this.phase,
    required this.remainingMilliseconds,
    required this.isPaused,
    required this.manualEvidenceState,
    required this.isFinished,
  });

  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final String workoutId;
  final String executionMappingSha256;
  final String sessionBlockId;
  final String authoredStepId;
  final int repeatOrdinal;
  final StructuredRunningPhase phase;
  final int remainingMilliseconds;
  final bool isPaused;
  final StructuredRunningManualEvidenceState manualEvidenceState;
  final bool isFinished;

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'workout_id': workoutId,
    'execution_mapping_sha256': executionMappingSha256,
    'session_block_id': sessionBlockId,
    'authored_step_id': authoredStepId,
    'repeat_ordinal': repeatOrdinal,
    'phase': phase.name,
    'remaining_milliseconds': remainingMilliseconds,
    'is_paused': isPaused,
    'manual_evidence_state': manualEvidenceState.name,
    'is_finished': isFinished,
  };

  factory StructuredRunningCursor.fromJson(Map<String, dynamic> json) {
    const keys = {
      'schema_version',
      'workout_id',
      'execution_mapping_sha256',
      'session_block_id',
      'authored_step_id',
      'repeat_ordinal',
      'phase',
      'remaining_milliseconds',
      'is_paused',
      'manual_evidence_state',
      'is_finished',
    };
    if (json.keys.toSet().difference(keys).isNotEmpty ||
        !json.keys.toSet().containsAll(keys) ||
        json['schema_version'] != currentSchemaVersion) {
      throw const FormatException('unsupported structured running cursor');
    }
    final phase = StructuredRunningPhase.values
        .where((value) => value.name == json['phase'])
        .firstOrNull;
    final evidence = StructuredRunningManualEvidenceState.values
        .where((value) => value.name == json['manual_evidence_state'])
        .firstOrNull;
    final remaining = json['remaining_milliseconds'];
    final ordinal = json['repeat_ordinal'];
    if (phase == null ||
        evidence == null ||
        remaining is! int ||
        remaining < 0 ||
        ordinal is! int ||
        ordinal < 1 ||
        json['is_paused'] is! bool ||
        json['is_finished'] is! bool) {
      throw const FormatException('invalid structured running cursor');
    }
    String identity(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw const FormatException('invalid structured running identity');
      }
      return value;
    }

    return StructuredRunningCursor(
      schemaVersion: currentSchemaVersion,
      workoutId: identity('workout_id'),
      executionMappingSha256: identity('execution_mapping_sha256'),
      sessionBlockId: identity('session_block_id'),
      authoredStepId: identity('authored_step_id'),
      repeatOrdinal: ordinal,
      phase: phase,
      remainingMilliseconds: remaining,
      isPaused: json['is_paused'] as bool,
      manualEvidenceState: evidence,
      isFinished: json['is_finished'] as bool,
    );
  }
}
