import 'dart:convert';

import 'running_workout_model.dart';

class RunningWorkoutCodecException implements Exception {
  RunningWorkoutCodecException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}

/// Deterministic RunningWorkout v1 JSON. Not a Plan Package or hosted contract.
class RunningWorkoutCodec {
  const RunningWorkoutCodec();

  static const schemaVersion = 1;

  String encode(RunningWorkout workout) {
    return jsonEncode(_workoutMap(workout));
  }

  RunningWorkout decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw RunningWorkoutCodecException(
        'invalid_json',
        'RunningWorkout JSON must be an object.',
      );
    }
    return decodeMap(Map<String, dynamic>.from(decoded));
  }

  RunningWorkout decodeMap(Map<String, dynamic> json) {
    _rejectUnknown(json, const {
      'schema_version',
      'workout_id',
      'title',
      'intent',
      'notes',
      'provenance',
      'steps',
    }, 'workout');
    final version = json['schema_version'];
    if (version != schemaVersion) {
      throw RunningWorkoutCodecException(
        'unsupported_schema_version',
        'Unsupported schema_version: $version',
      );
    }
    final workoutId = json['workout_id'];
    if (workoutId is! String) {
      throw RunningWorkoutCodecException(
        'missing_workout_id',
        'workout_id must be a string.',
      );
    }
    final stepsRaw = json['steps'];
    if (stepsRaw is! List) {
      throw RunningWorkoutCodecException(
        'invalid_steps',
        'steps must be an array.',
      );
    }
    return RunningWorkout(
      schemaVersion: schemaVersion,
      workoutId: workoutId,
      title: _optionalString(json['title']),
      intent: _optionalString(json['intent']),
      notes: _optionalString(json['notes']),
      provenance: json['provenance'] == null
          ? null
          : _decodeProvenance(_asMap(json['provenance'], 'provenance')),
      steps: [
        for (var i = 0; i < stepsRaw.length; i++)
          _decodeNode(_asMap(stepsRaw[i], 'steps[$i]'), 'steps[$i]'),
      ],
    );
  }

  Map<String, dynamic> _workoutMap(RunningWorkout workout) {
    return {
      'schema_version': workout.schemaVersion,
      'workout_id': workout.workoutId,
      if (workout.title != null) 'title': workout.title,
      if (workout.intent != null) 'intent': workout.intent,
      if (workout.notes != null) 'notes': workout.notes,
      if (workout.provenance != null)
        'provenance': _provenanceMap(workout.provenance!),
      'steps': [for (final step in workout.steps) _nodeMap(step)],
    };
  }

  Map<String, dynamic> _provenanceMap(RunningWorkoutProvenance provenance) {
    return {
      'kind': switch (provenance.kind) {
        RunningWorkoutProvenanceKind.authored => 'authored',
        RunningWorkoutProvenanceKind.projected => 'projected',
        RunningWorkoutProvenanceKind.unsupported => 'unsupported',
      },
      'source_kind': provenance.sourceKind,
      if (provenance.sourceFormat != null)
        'source_format': provenance.sourceFormat,
      'id_derivation': provenance.idDerivation,
    };
  }

  RunningWorkoutProvenance _decodeProvenance(Map<String, dynamic> json) {
    _rejectUnknown(json, const {
      'kind',
      'source_kind',
      'source_format',
      'id_derivation',
    }, 'provenance');
    final kind = switch (json['kind']) {
      'authored' => RunningWorkoutProvenanceKind.authored,
      'projected' => RunningWorkoutProvenanceKind.projected,
      'unsupported' => RunningWorkoutProvenanceKind.unsupported,
      final other => throw RunningWorkoutCodecException(
        'unknown_provenance_kind',
        'Unknown provenance kind: $other',
      ),
    };
    final sourceKind = json['source_kind'];
    final idDerivation = json['id_derivation'];
    if (sourceKind is! String || idDerivation is! String) {
      throw RunningWorkoutCodecException(
        'invalid_provenance',
        'provenance.source_kind and id_derivation are required strings.',
      );
    }
    return RunningWorkoutProvenance(
      kind: kind,
      sourceKind: sourceKind,
      sourceFormat: _optionalString(json['source_format']),
      idDerivation: idDerivation,
    );
  }

  Map<String, dynamic> _nodeMap(RunningWorkoutNode node) {
    switch (node) {
      case RunningAtomicStep():
        return {
          'kind': 'atomic',
          'step_id': node.stepId,
          'role': _roleName(node.role),
          'duration': _durationMap(node.duration),
          'target': _targetMap(node.target),
          if (node.notes != null) 'notes': node.notes,
        };
      case RunningRepeatGroup():
        return {
          'kind': 'repeat',
          'group_id': node.groupId,
          'count': node.count,
          'steps': [for (final step in node.steps) _nodeMap(step)],
        };
    }
  }

  RunningWorkoutNode _decodeNode(Map<String, dynamic> json, String path) {
    final kind = json['kind'];
    if (kind == 'atomic') {
      _rejectUnknown(json, const {
        'kind',
        'step_id',
        'role',
        'duration',
        'target',
        'notes',
      }, path);
      final stepId = json['step_id'];
      if (stepId is! String) {
        throw RunningWorkoutCodecException(
          'missing_id',
          '$path.step_id must be a string.',
        );
      }
      return RunningAtomicStep(
        stepId: stepId,
        role: _roleFromName(json['role'], path),
        duration: _decodeDuration(_asMap(json['duration'], '$path.duration'), path),
        target: json['target'] == null
            ? const RunningTarget.none()
            : _decodeTarget(_asMap(json['target'], '$path.target'), path),
        notes: _optionalString(json['notes']),
      );
    }
    if (kind == 'repeat') {
      _rejectUnknown(json, const {
        'kind',
        'group_id',
        'count',
        'steps',
      }, path);
      final groupId = json['group_id'];
      final count = json['count'];
      final stepsRaw = json['steps'];
      if (groupId is! String || count is! int || stepsRaw is! List) {
        throw RunningWorkoutCodecException(
          'invalid_repeat',
          '$path must have group_id, integer count, and steps.',
        );
      }
      return RunningRepeatGroup(
        groupId: groupId,
        count: count,
        steps: [
          for (var i = 0; i < stepsRaw.length; i++)
            _decodeAtomicChild(_asMap(stepsRaw[i], '$path.steps[$i]'), '$path.steps[$i]'),
        ],
      );
    }
    throw RunningWorkoutCodecException(
      'unknown_step_kind',
      'Unknown step kind at $path: $kind',
    );
  }

  RunningAtomicStep _decodeAtomicChild(Map<String, dynamic> json, String path) {
    final node = _decodeNode(json, path);
    if (node is! RunningAtomicStep) {
      throw RunningWorkoutCodecException(
        'nested_repeat_group',
        'Repeat groups may contain only atomic steps at $path.',
      );
    }
    return node;
  }

  Map<String, dynamic> _durationMap(RunningDuration duration) {
    return switch (duration.kind) {
      RunningDurationKind.time => {
        'kind': 'time',
        'milliseconds': duration.milliseconds,
      },
      RunningDurationKind.distance => {
        'kind': 'distance',
        'millimetres': duration.millimetres,
      },
      RunningDurationKind.manualLap => {'kind': 'manual_lap'},
    };
  }

  RunningDuration _decodeDuration(Map<String, dynamic> json, String path) {
    _rejectUnknown(json, const {
      'kind',
      'milliseconds',
      'millimetres',
    }, '$path.duration');
    return switch (json['kind']) {
      'time' => RunningDuration.time(_requireInt(json['milliseconds'], '$path.duration.milliseconds')),
      'distance' => RunningDuration.distance(
        _requireInt(json['millimetres'], '$path.duration.millimetres'),
      ),
      'manual_lap' => const RunningDuration.manualLap(),
      final other => throw RunningWorkoutCodecException(
        'unknown_duration_kind',
        'Unknown duration kind at $path: $other',
      ),
    };
  }

  Map<String, dynamic> _targetMap(RunningTarget target) {
    return switch (target.kind) {
      RunningTargetKind.none => {'kind': 'none'},
      RunningTargetKind.pace => {
        'kind': 'pace',
        'milliseconds_per_kilometre': target.paceMillisecondsPerKilometre,
      },
      RunningTargetKind.paceRange => {
        'kind': 'pace_range',
        'low': target.paceMillisecondsPerKilometreLow,
        'high': target.paceMillisecondsPerKilometreHigh,
      },
      RunningTargetKind.heartRate => {
        'kind': 'heart_rate',
        'bpm': target.heartRateBpm,
      },
      RunningTargetKind.heartRateRange => {
        'kind': 'heart_rate_range',
        'low': target.heartRateBpmLow,
        'high': target.heartRateBpmHigh,
      },
      RunningTargetKind.heartRateZoneRef => {
        'kind': 'heart_rate_zone_ref',
        'zone_ref': target.heartRateZoneRef,
      },
      RunningTargetKind.power => {'kind': 'power', 'watts': target.powerWatts},
      RunningTargetKind.powerRange => {
        'kind': 'power_range',
        'low': target.powerWattsLow,
        'high': target.powerWattsHigh,
      },
      RunningTargetKind.cadenceRange => {
        'kind': 'cadence_range',
        'unit': 'steps_per_minute',
        'low': target.cadenceStepsPerMinuteLow,
        'high': target.cadenceStepsPerMinuteHigh,
      },
      RunningTargetKind.rpe => {
        'kind': 'rpe',
        'scale': 'rpe_cr10',
        'value': target.rpeCr10,
      },
      RunningTargetKind.rpeRange => {
        'kind': 'rpe_range',
        'scale': 'rpe_cr10',
        'low': target.rpeCr10Low,
        'high': target.rpeCr10High,
      },
    };
  }

  RunningTarget _decodeTarget(Map<String, dynamic> json, String path) {
    final kind = json['kind'];
    switch (kind) {
      case 'none':
        _rejectUnknown(json, const {'kind'}, '$path.target');
        return const RunningTarget.none();
      case 'pace':
        _rejectUnknown(json, const {
          'kind',
          'milliseconds_per_kilometre',
        }, '$path.target');
        return RunningTarget.pace(
          _requireInt(json['milliseconds_per_kilometre'], '$path.target'),
        );
      case 'pace_range':
        _rejectUnknown(json, const {'kind', 'low', 'high'}, '$path.target');
        return RunningTarget.paceRange(
          low: _requireInt(json['low'], '$path.target.low'),
          high: _requireInt(json['high'], '$path.target.high'),
        );
      case 'heart_rate':
        _rejectUnknown(json, const {'kind', 'bpm'}, '$path.target');
        return RunningTarget.heartRate(_requireInt(json['bpm'], '$path.target'));
      case 'heart_rate_range':
        _rejectUnknown(json, const {'kind', 'low', 'high'}, '$path.target');
        return RunningTarget.heartRateRange(
          low: _requireInt(json['low'], '$path.target.low'),
          high: _requireInt(json['high'], '$path.target.high'),
        );
      case 'heart_rate_zone_ref':
        _rejectUnknown(json, const {'kind', 'zone_ref'}, '$path.target');
        final ref = json['zone_ref'];
        if (ref is! String) {
          throw RunningWorkoutCodecException(
            'invalid_target',
            '$path.target.zone_ref must be a string.',
          );
        }
        return RunningTarget.heartRateZoneRef(ref);
      case 'power':
        _rejectUnknown(json, const {'kind', 'watts'}, '$path.target');
        return RunningTarget.power(_requireInt(json['watts'], '$path.target'));
      case 'power_range':
        _rejectUnknown(json, const {'kind', 'low', 'high'}, '$path.target');
        return RunningTarget.powerRange(
          low: _requireInt(json['low'], '$path.target.low'),
          high: _requireInt(json['high'], '$path.target.high'),
        );
      case 'cadence_range':
        _rejectUnknown(json, const {
          'kind',
          'unit',
          'low',
          'high',
        }, '$path.target');
        if (json['unit'] != 'steps_per_minute') {
          throw RunningWorkoutCodecException(
            'invalid_target',
            'Cadence unit must be steps_per_minute.',
          );
        }
        return RunningTarget.cadenceRange(
          low: _requireInt(json['low'], '$path.target.low'),
          high: _requireInt(json['high'], '$path.target.high'),
        );
      case 'rpe':
        _rejectUnknown(json, const {'kind', 'scale', 'value'}, '$path.target');
        if (json['scale'] != 'rpe_cr10') {
          throw RunningWorkoutCodecException(
            'invalid_target',
            'RPE scale must be rpe_cr10.',
          );
        }
        return RunningTarget.rpe(_requireInt(json['value'], '$path.target'));
      case 'rpe_range':
        _rejectUnknown(json, const {
          'kind',
          'scale',
          'low',
          'high',
        }, '$path.target');
        if (json['scale'] != 'rpe_cr10') {
          throw RunningWorkoutCodecException(
            'invalid_target',
            'RPE scale must be rpe_cr10.',
          );
        }
        return RunningTarget.rpeRange(
          low: _requireInt(json['low'], '$path.target.low'),
          high: _requireInt(json['high'], '$path.target.high'),
        );
      default:
        throw RunningWorkoutCodecException(
          'unknown_target_kind',
          'Unknown target kind at $path: $kind',
        );
    }
  }

  String _roleName(RunningStepRole role) {
    return switch (role) {
      RunningStepRole.warmUp => 'warm_up',
      RunningStepRole.work => 'work',
      RunningStepRole.recovery => 'recovery',
      RunningStepRole.rest => 'rest',
      RunningStepRole.coolDown => 'cool_down',
      RunningStepRole.open => 'open',
    };
  }

  RunningStepRole _roleFromName(Object? value, String path) {
    return switch (value) {
      'warm_up' => RunningStepRole.warmUp,
      'work' => RunningStepRole.work,
      'recovery' => RunningStepRole.recovery,
      'rest' => RunningStepRole.rest,
      'cool_down' => RunningStepRole.coolDown,
      'open' => RunningStepRole.open,
      _ => throw RunningWorkoutCodecException(
        'unknown_role',
        'Unknown role at $path: $value',
      ),
    };
  }

  void _rejectUnknown(
    Map<String, dynamic> json,
    Set<String> allowed,
    String path,
  ) {
    for (final key in json.keys) {
      if (!allowed.contains(key)) {
        throw RunningWorkoutCodecException(
          'unknown_field',
          'Unknown authority field "$key" at $path.',
        );
      }
    }
  }

  Map<String, dynamic> _asMap(Object? value, String path) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw RunningWorkoutCodecException(
      'invalid_json',
      '$path must be an object.',
    );
  }

  int _requireInt(Object? value, String path) {
    if (value is int) return value;
    throw RunningWorkoutCodecException(
      'invalid_number',
      '$path must be an integer.',
    );
  }

  String? _optionalString(Object? value) {
    if (value == null) return null;
    if (value is String) return value;
    throw RunningWorkoutCodecException(
      'invalid_string',
      'Expected a string.',
    );
  }
}
