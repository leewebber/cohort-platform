import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'running_workout.dart';

/// Public FIT field semantics only. No FIT binary, Garmin JSON or transport.
class FitWorkoutRefusal implements Exception {
  const FitWorkoutRefusal(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => '$code: $message';
}

Object? _ordered(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final k in keys) k: _ordered(value[k])};
  }
  if (value is List) return value.map(_ordered).toList();
  return value;
}

String fitManifestDigest(Object? value) =>
    sha256.convert(utf8.encode(jsonEncode(_ordered(value)))).toString();

/// JSON copy with recursively immutable maps/lists; never retains caller buffers.
Object? freezeFitValue(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.unmodifiable({
      for (final key in value.keys.cast<String>())
        key: freezeFitValue(value[key]),
    });
  }
  if (value is List) {
    return List<dynamic>.unmodifiable(value.map(freezeFitValue));
  }
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  throw const FitWorkoutRefusal(
    'invalid_json',
    'Use plain JSON source values.',
  );
}

/// Does not establish acceptance. The frozen-plan adapter supplies that boundary.
class TimedFitWorkoutConverter {
  const TimedFitWorkoutConverter();
  static const adapterVersion = 'local_fit_fields_v1';
  static const roundingPolicy = 'outward_speed_0_001_mps_v1';
  static const maxRawUint32 = 0xfffffffe; // 0xffffffff is FIT invalid.

  Map<String, dynamic> convert(RunningWorkout workout) {
    final validation = const RunningWorkoutValidator().validate(workout);
    if (!validation.isValid) {
      throw FitWorkoutRefusal(
        'invalid_workout',
        'Repair the authored workout: ${validation.errors.map((e) => e.message).join(' ')}',
      );
    }
    final rows = <Map<String, dynamic>>[];
    final frames = <Map<String, dynamic>>[];
    var total = 0;
    Map<String, dynamic> atomic(RunningAtomicStep step) {
      final ms = step.duration.milliseconds;
      if (step.duration.kind != RunningDurationKind.time ||
          ms == null ||
          ms <= 0 ||
          ms % 1000 != 0 ||
          ms > maxRawUint32) {
        throw FitWorkoutRefusal(
          'unsupported_duration',
          '${step.stepId}: use positive whole-second time within FIT uint32; distance/lap steps need a separate adapter.',
        );
      }
      if (step.role == RunningStepRole.open) {
        throw FitWorkoutRefusal(
          'unsupported_role',
          '${step.stepId}: open-role execution is outside this local subset.',
        );
      }
      final target = step.target;
      final fields = <String, dynamic>{'target_type': 2, 'target_value': 0};
      switch (target.kind) {
        case RunningTargetKind.none:
          break;
        case RunningTargetKind.paceRange:
          final fast = target.paceMillisecondsPerKilometreLow!;
          final slow = target.paceMillisecondsPerKilometreHigh!;
          // Integer arithmetic: raw speed is m/s * 1000, inverse ms/km.
          final low = 1000000000 ~/ slow;
          final high = (1000000000 + fast - 1) ~/ fast;
          if (low <= 0 || low >= high || high > maxRawUint32) {
            throw FitWorkoutRefusal(
              'unrepresentable_pace',
              '${step.stepId}: pace bounds cannot be represented at 0.001 m/s; retain the original prescription.',
            );
          }
          fields.addAll({
            'target_type': 0,
            'custom_target_value_low': low,
            'custom_target_value_high': high,
          });
        case RunningTargetKind.heartRateRange:
          final low = target.heartRateBpmLow!;
          final high = target.heartRateBpmHigh!;
          if (low < 1 || high > 250 || low >= high) {
            throw FitWorkoutRefusal(
              'invalid_bpm',
              '${step.stepId}: confirm ordered numerical BPM limits within 1–250.',
            );
          }
          fields.addAll({
            'target_type': 1,
            'custom_target_value_low': low + 100,
            'custom_target_value_high': high + 100,
          });
        default:
          throw FitWorkoutRefusal(
            'unsupported_target',
            '${step.stepId}: ${target.kind.name} is unsupported. Supply an accepted explicit pace/BPM range or keep execution in Cohort; no target is dropped.',
          );
      }
      return {
        'message_index': rows.length,
        'duration_type': 0,
        'duration_value': ms,
        ...fields,
        'intensity': switch (step.role) {
          RunningStepRole.work => 0,
          RunningStepRole.rest => 1,
          RunningStepRole.warmUp => 2,
          RunningStepRole.coolDown => 3,
          RunningStepRole.recovery => 4,
          RunningStepRole.open => 6,
        },
        'wkt_step_name': ?step.label,
        'notes': ?step.notes,
      };
    }

    void frame(
      RunningAtomicStep s,
      int index, {
      String? group,
      int? iteration,
    }) {
      total += s.duration.milliseconds!;
      frames.add({
        'step_id': s.stepId,
        'message_index': index,
        'group_id': ?group,
        'iteration': ?iteration,
      });
      if (frames.length > 512) {
        throw const FitWorkoutRefusal(
          'too_many_phases',
          'This local subset allows at most 512 expanded phases; split the authored workout explicitly.',
        );
      }
    }

    for (final node in workout.steps) {
      switch (node) {
        case RunningAtomicStep():
          final index = rows.length;
          rows.add(atomic(node));
          frame(node, index);
        case RunningRepeatGroup():
          final start = rows.length;
          for (final step in node.steps) {
            rows.add(atomic(step));
          }
          rows.add({
            'message_index': rows.length,
            'duration_type': 6,
            'duration_value': start,
            'target_type': 2,
            'target_value': node.count,
          });
          for (var iteration = 1; iteration <= node.count; iteration++) {
            for (var i = 0; i < node.steps.length; i++) {
              frame(
                node.steps[i],
                start + i,
                group: node.groupId,
                iteration: iteration,
              );
            }
          }
      }
    }
    return freezeFitValue({
          'representation': adapterVersion,
          'binary_fit': false,
          'training_api_payload': false,
          'rounding_policy': roundingPolicy,
          'workout': {
            'sport': 1,
            'num_valid_steps': rows.length,
            if (workout.title != null) 'wkt_name': workout.title,
          },
          'workout_steps': rows,
          'expanded_source_steps': frames,
          'total_duration_milliseconds': total,
        })
        as Map<String, dynamic>;
  }
}
