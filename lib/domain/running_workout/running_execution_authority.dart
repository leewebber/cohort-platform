import 'package:cohort_plan_package/cohort_plan_package.dart';

class RunningExecutionAuthorityException implements Exception {
  const RunningExecutionAuthorityException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'RunningExecutionAuthorityException($code): $message';
}

class RunningStepBlockBinding {
  const RunningStepBlockBinding({
    required this.stepId,
    required this.sessionBlockId,
  });

  final String stepId;
  final String sessionBlockId;
}

class AuthoredRunningAttachmentScope {
  const AuthoredRunningAttachmentScope({
    required this.attachmentId,
    required this.stepIds,
  });

  final String attachmentId;
  final List<String> stepIds;
}

/// Launch-time projection of persisted Plan Package v2 running authority.
///
/// The full canonical JSON remains package authority. This type carries only
/// fields required to fail closed at the B3 execution boundary.
class AuthoredRunningExecutionAuthority {
  const AuthoredRunningExecutionAuthority._({
    required this.workoutId,
    required this.stepIds,
    required this.attachmentScopes,
    required this.executableStepBindings,
    required this.executionMappingSha256,
  });

  final String workoutId;
  final List<String> stepIds;
  final List<AuthoredRunningAttachmentScope> attachmentScopes;
  final List<RunningStepBlockBinding>? executableStepBindings;
  final String? executionMappingSha256;

  bool get isAttachedForExecution => executableStepBindings != null;

  String? get exactSessionBlockId {
    final bindings = executableStepBindings;
    if (bindings == null || bindings.isEmpty) return null;
    return bindings.first.sessionBlockId;
  }

  factory AuthoredRunningExecutionAuthority.fromCanonicalJson(
    Map<String, dynamic> json,
  ) {
    const baseKeys = {
      'schema_version',
      'workout_id',
      'step_ids',
      'advisory_attachments',
    };
    const mappingKeys = {
      'executable_step_bindings',
      'execution_mapping_sha256',
    };
    final hasBindings = json.containsKey('executable_step_bindings');
    final hasHash = json.containsKey('execution_mapping_sha256');
    final allowed = {...baseKeys, if (hasBindings || hasHash) ...mappingKeys};
    if (json.keys.toSet().difference(allowed).isNotEmpty ||
        !json.keys.toSet().containsAll(baseKeys) ||
        hasBindings != hasHash ||
        json['schema_version'] != 1) {
      throw const RunningExecutionAuthorityException(
        'invalid_authored_running_shape',
        'Authored running authority has an unsupported shape.',
      );
    }

    final workoutId = _identity(json['workout_id'], 'workout_id');
    final stepIds = _identityList(json['step_ids'], 'step_ids');
    final attachmentRaw = _list(
      json['advisory_attachments'],
      'advisory_attachments',
    );
    if (attachmentRaw.isEmpty) {
      throw const RunningExecutionAuthorityException(
        'missing_attachment_scope',
        'At least one authored advisory attachment is required.',
      );
    }
    final attachments = <AuthoredRunningAttachmentScope>[];
    final attachmentIds = <String>{};
    for (final raw in attachmentRaw) {
      final attachment = _map(raw, 'advisory_attachment');
      final attachmentId = _identity(
        attachment['attachment_id'],
        'attachment_id',
      );
      if (!attachmentIds.add(attachmentId)) {
        throw const RunningExecutionAuthorityException(
          'duplicate_attachment_id',
          'Advisory attachment identities must be unique.',
        );
      }
      final scopedSteps = _identityList(
        attachment['step_ids'],
        'attachment_step_ids',
      );
      if (scopedSteps.any((stepId) => !stepIds.contains(stepId))) {
        throw const RunningExecutionAuthorityException(
          'attachment_scope_mismatch',
          'An advisory attachment references an undeclared running step.',
        );
      }
      attachments.add(
        AuthoredRunningAttachmentScope(
          attachmentId: attachmentId,
          stepIds: List.unmodifiable(scopedSteps),
        ),
      );
    }

    List<RunningStepBlockBinding>? bindings;
    String? mappingHash;
    if (hasBindings) {
      final bindingRaw = _list(
        json['executable_step_bindings'],
        'executable_step_bindings',
      );
      if (bindingRaw.length != stepIds.length || bindingRaw.isEmpty) {
        throw const RunningExecutionAuthorityException(
          'incomplete_execution_mapping',
          'Every running step must have one executable block binding.',
        );
      }
      final parsed = <RunningStepBlockBinding>[];
      final blockIds = <String>{};
      for (var index = 0; index < bindingRaw.length; index++) {
        final binding = _map(bindingRaw[index], 'step_block_binding');
        if (binding.keys.toSet().difference(const {
          'step_id',
          'session_block_id',
        }).isNotEmpty) {
          throw const RunningExecutionAuthorityException(
            'invalid_execution_mapping_shape',
            'Execution bindings may contain only stable step and block IDs.',
          );
        }
        final stepId = _identity(binding['step_id'], 'binding_step_id');
        final blockId = binding['session_block_id']?.toString() ?? '';
        if (stepId != stepIds[index] ||
            !PlanPackageSchema.canonicalSessionBlockUuidPattern.hasMatch(
              blockId,
            )) {
          throw const RunningExecutionAuthorityException(
            'execution_mapping_scope_mismatch',
            'Execution bindings must exactly follow authored steps and canonical block UUIDs.',
          );
        }
        blockIds.add(blockId);
        parsed.add(
          RunningStepBlockBinding(stepId: stepId, sessionBlockId: blockId),
        );
      }
      if (blockIds.length != 1) {
        throw const RunningExecutionAuthorityException(
          'unsupported_execution_mapping',
          'B3 slice 1 supports one exact B1 executable block per workout.',
        );
      }
      mappingHash = json['execution_mapping_sha256']?.toString() ?? '';
      final expectedHash = RunningExecutionMappingHash.compute(
        workoutId: workoutId,
        bindings: parsed.map(
          (binding) =>
              (stepId: binding.stepId, sessionBlockId: binding.sessionBlockId),
        ),
      );
      if (mappingHash != expectedHash) {
        throw const RunningExecutionAuthorityException(
          'execution_mapping_hash_mismatch',
          'The executable running mapping hash does not match its bindings.',
        );
      }
      bindings = List.unmodifiable(parsed);
    }

    return AuthoredRunningExecutionAuthority._(
      workoutId: workoutId,
      stepIds: List.unmodifiable(stepIds),
      attachmentScopes: List.unmodifiable(attachments),
      executableStepBindings: bindings,
      executionMappingSha256: mappingHash,
    );
  }
}

enum RunningLaunchTargetState { calculated, intentOnly }

class RunningLaunchTarget {
  const RunningLaunchTarget({
    required this.attachmentId,
    required this.workoutId,
    required this.stepIds,
    required this.state,
    required this.frozenAtUtc,
    this.reason,
    this.paceUnit,
    this.benchmarkAthleteId,
  });

  final String attachmentId;
  final String workoutId;
  final List<String> stepIds;
  final RunningLaunchTargetState state;
  final DateTime frozenAtUtc;
  final String? reason;
  final String? paceUnit;
  final String? benchmarkAthleteId;
}

/// Exact B2 frozen aggregate returned by the authoritative start/resume RPC.
class RunningTargetSnapshotAggregate {
  const RunningTargetSnapshotAggregate._({
    required this.occurrenceId,
    required this.athleteId,
    required this.assignmentId,
    required this.programmeVersionId,
    required this.sessionSlotId,
    required this.packageContentHash,
    required this.workoutId,
    required this.frozenAtUtc,
    required this.targets,
  });

  final String occurrenceId;
  final String athleteId;
  final String assignmentId;
  final String programmeVersionId;
  final String sessionSlotId;
  final String packageContentHash;
  final String workoutId;
  final DateTime frozenAtUtc;
  final List<RunningLaunchTarget> targets;

  factory RunningTargetSnapshotAggregate.fromJson(Map<String, dynamic> json) {
    const aggregateKeys = {
      'schema_version',
      'authority',
      'occurrence_id',
      'athlete_id',
      'assignment_id',
      'programme_version_id',
      'session_slot_id',
      'package_content_hash',
      'workout_id',
      'frozen_at_utc',
      'freeze_source',
      'targets',
    };
    if (json.keys.toSet().difference(aggregateKeys).isNotEmpty ||
        !json.keys.toSet().containsAll(aggregateKeys) ||
        json['schema_version'] != 1 ||
        json['authority'] != 'advisory' ||
        json['freeze_source'] != 'in_app_start') {
      throw const RunningExecutionAuthorityException(
        'invalid_snapshot_shape',
        'The frozen running target aggregate has an unsupported shape.',
      );
    }
    final frozenAt = DateTime.tryParse(json['frozen_at_utc']?.toString() ?? '');
    if (frozenAt == null || !frozenAt.isUtc) {
      throw const RunningExecutionAuthorityException(
        'invalid_snapshot_timestamp',
        'The frozen running target timestamp must be UTC.',
      );
    }
    final targetsRaw = _list(json['targets'], 'targets');
    if (targetsRaw.isEmpty) {
      throw const RunningExecutionAuthorityException(
        'missing_snapshot_targets',
        'The frozen running target aggregate must contain targets.',
      );
    }
    final targets = targetsRaw
        .map((target) => _parseTarget(_map(target, 'target')))
        .toList(growable: false);
    return RunningTargetSnapshotAggregate._(
      occurrenceId: _requiredString(json['occurrence_id'], 'occurrence_id'),
      athleteId: _requiredString(json['athlete_id'], 'athlete_id'),
      assignmentId: _requiredString(json['assignment_id'], 'assignment_id'),
      programmeVersionId: _requiredString(
        json['programme_version_id'],
        'programme_version_id',
      ),
      sessionSlotId: _requiredString(
        json['session_slot_id'],
        'session_slot_id',
      ),
      packageContentHash: _requiredString(
        json['package_content_hash'],
        'package_content_hash',
      ),
      workoutId: _identity(json['workout_id'], 'workout_id'),
      frozenAtUtc: frozenAt,
      targets: List.unmodifiable(targets),
    );
  }
}

RunningLaunchTarget _parseTarget(Map<String, dynamic> target) {
  final state = target['state'];
  final commonKeys = {
    'schema_version',
    'authority',
    'attachment_id',
    'scope',
    'frozen_at_utc',
    'freeze_source',
    'policy',
    'state',
  };
  final stateKeys = switch (state) {
    'calculated' => {'benchmark', 'calculated_exact_range'},
    'intent_only' => {'reason'},
    _ => const <String>{},
  };
  if (stateKeys.isEmpty ||
      target.keys.toSet().difference({
        ...commonKeys,
        ...stateKeys,
      }).isNotEmpty ||
      !target.keys.toSet().containsAll({...commonKeys, ...stateKeys}) ||
      target['schema_version'] != 1 ||
      target['authority'] != 'advisory' ||
      target['freeze_source'] != 'in_app_start') {
    throw const RunningExecutionAuthorityException(
      'invalid_snapshot_target_state',
      'A frozen running target has invalid state or shape.',
    );
  }
  final scope = _map(target['scope'], 'scope');
  if (scope.keys.toSet().difference(const {
    'workout_id',
    'step_ids',
  }).isNotEmpty) {
    throw const RunningExecutionAuthorityException(
      'invalid_snapshot_scope',
      'A frozen running target has an invalid step scope.',
    );
  }
  final stepIds = _identityList(scope['step_ids'], 'target_step_ids');
  final scopeWorkoutId = _identity(scope['workout_id'], 'target_workout_id');
  final targetFrozenAt = DateTime.tryParse(
    target['frozen_at_utc']?.toString() ?? '',
  );
  if (targetFrozenAt == null || !targetFrozenAt.isUtc) {
    throw const RunningExecutionAuthorityException(
      'invalid_snapshot_target_timestamp',
      'A frozen target timestamp must be UTC.',
    );
  }
  final policy = _map(target['policy'], 'policy');
  final rounding = _map(policy['display_rounding'], 'display_rounding');
  final increment = rounding['increment_milliseconds_per_kilometre'];
  if (increment is! int ||
      increment < 1 ||
      !const {'down', 'nearest', 'up'}.contains(rounding['direction'])) {
    throw const RunningExecutionAuthorityException(
      'invalid_snapshot_display_units',
      'Frozen display rounding must use positive milliseconds per kilometre.',
    );
  }

  if (state == 'intent_only') {
    final reason = target['reason']?.toString() ?? '';
    if (!const {
      'no_evidence',
      'duplicate_evidence_identity',
      'no_athlete_scoped_evidence',
      'no_timezone_matched_evidence',
      'no_eligible_completed_test',
      'no_fresh_evidence',
    }.contains(reason)) {
      throw const RunningExecutionAuthorityException(
        'invalid_snapshot_intent_reason',
        'Intent-only target reason is not supported.',
      );
    }
    return RunningLaunchTarget(
      attachmentId: _identity(target['attachment_id'], 'attachment_id'),
      workoutId: scopeWorkoutId,
      stepIds: List.unmodifiable(stepIds),
      state: RunningLaunchTargetState.intentOnly,
      frozenAtUtc: targetFrozenAt,
      reason: reason,
    );
  }

  final benchmark = _map(target['benchmark'], 'benchmark');
  if (benchmark['duration_basis'] != 'elapsed_including_pauses' ||
      benchmark['distance_metres'] is! int ||
      (benchmark['distance_metres'] as int) < 1 ||
      benchmark['elapsed_duration_milliseconds'] is! int ||
      (benchmark['elapsed_duration_milliseconds'] as int) < 1) {
    throw const RunningExecutionAuthorityException(
      'invalid_snapshot_benchmark_units',
      'Calculated targets require elapsed milliseconds and distance metres.',
    );
  }
  final range = _map(
    target['calculated_exact_range'],
    'calculated_exact_range',
  );
  if (range['unit'] != 'milliseconds_per_kilometre') {
    throw const RunningExecutionAuthorityException(
      'invalid_snapshot_pace_unit',
      'Calculated running targets must use milliseconds per kilometre.',
    );
  }
  for (final key in const ['faster', 'slower']) {
    final pace = _map(range[key], key);
    if (pace['numerator'] is! int ||
        (pace['numerator'] as int) < 1 ||
        pace['denominator'] is! int ||
        (pace['denominator'] as int) < 1) {
      throw const RunningExecutionAuthorityException(
        'invalid_snapshot_exact_pace',
        'Exact pace values require positive integer numerator and denominator.',
      );
    }
  }
  return RunningLaunchTarget(
    attachmentId: _identity(target['attachment_id'], 'attachment_id'),
    workoutId: scopeWorkoutId,
    stepIds: List.unmodifiable(stepIds),
    state: RunningLaunchTargetState.calculated,
    frozenAtUtc: targetFrozenAt,
    paceUnit: 'milliseconds_per_kilometre',
    benchmarkAthleteId: _requiredString(
      benchmark['athlete_id'],
      'benchmark_athlete_id',
    ),
  );
}

Map<String, dynamic> _map(Object? value, String field) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw RunningExecutionAuthorityException(
    'invalid_$field',
    '$field must be an object.',
  );
}

List<Object?> _list(Object? value, String field) {
  if (value is List) return List<Object?>.from(value);
  throw RunningExecutionAuthorityException(
    'invalid_$field',
    '$field must be a list.',
  );
}

String _requiredString(Object? value, String field) {
  final result = value?.toString().trim() ?? '';
  if (result.isEmpty) {
    throw RunningExecutionAuthorityException(
      'invalid_$field',
      '$field must be a non-empty string.',
    );
  }
  return result;
}

String _identity(Object? value, String field) {
  final result = _requiredString(value, field);
  if (!PlanPackageSchema.identityPattern.hasMatch(result)) {
    throw RunningExecutionAuthorityException(
      'invalid_$field',
      '$field must be a stable authored identity.',
    );
  }
  return result;
}

List<String> _identityList(Object? value, String field) {
  final result = _list(
    value,
    field,
  ).map((item) => _identity(item, field)).toList(growable: false);
  if (result.isEmpty || result.toSet().length != result.length) {
    throw RunningExecutionAuthorityException(
      'invalid_$field',
      '$field must contain unique authored identities.',
    );
  }
  return result;
}
