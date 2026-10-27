import '../../../core/persistence/session_execution_plan_codec.dart';
import '../../../domain/hyrox_base/programme_prescription.dart';
import '../../../domain/running_workout/running_workout.dart';
import 'session_execution_plan.dart';
import '../../../domain/running_workout/alpha_quality_targets.dart';

const confirmedZone2Reference = 'athlete_confirmed_zone_2';

Iterable<RunningAtomicStep> runningAtomicSteps(RunningWorkout workout) sync* {
  for (final node in workout.steps) {
    switch (node) {
      case RunningAtomicStep():
        yield node;
      case RunningRepeatGroup():
        yield* node.steps;
    }
  }
}

bool requiresZone2Admission(SessionExecutionPlan plan) => plan.blocks.any((b) {
  final workout = b.timerConfiguration?.runningWorkout;
  return workout != null &&
      runningAtomicSteps(
        workout,
      ).any((s) => s.target.heartRateZoneRef == confirmedZone2Reference);
});

void validateConfirmedZone2(int? lower, int? upper) {
  if (lower == null ||
      upper == null ||
      lower < 1 ||
      upper > 250 ||
      lower >= upper) {
    throw const FormatException(
      'Enter whole-number BPM limits from 1–250, with lower below upper.',
    );
  }
}

/// Validate exact server-review/source binding. This neither derives a zone nor
/// turns an arbitrary current profile into a started prescription.
void validateRunningTargetDocument(
  SessionExecutionPlan plan,
  Map<String, dynamic> doc, {
  required String athleteId,
  required String occurrenceId,
  required String assignmentId,
  required String versionId,
  required String packageHash,
}) {
  if (doc['schema_version'] != 1 ||
      doc['athlete_id'] != athleteId ||
      doc['occurrence_id'] != occurrenceId ||
      doc['assignment_id'] != assignmentId ||
      doc['programme_version_id'] != versionId ||
      doc['package_hash'] != packageHash ||
      doc['protocol_id'] != plan.sessionId ||
      doc['blocks'] is! List) {
    throw const FormatException(
      'Running target review does not match this athlete and workout. Re-prepare the session.',
    );
  }
  if (requiresZone2Admission(plan)) {
    if (doc['zone2'] is! Map) {
      throw const FormatException('A confirmed Zone 2 range is required.');
    }
    final z = doc['zone2'] as Map;
    if (z['athlete_id'] != athleteId ||
        z['withdrawn'] != false ||
        z['revision'] is! String ||
        (z['revision'] as String).isEmpty ||
        DateTime.tryParse(z['confirmed_at']?.toString() ?? '') == null ||
        z['lower_bpm'] is! int ||
        z['upper_bpm'] is! int) {
      throw const FormatException('A confirmed Zone 2 range is required.');
    }
    validateConfirmedZone2(z['lower_bpm'] as int, z['upper_bpm'] as int);
  } else if (doc['zone2'] != null) {
    throw const FormatException('Unexpected Zone 2 scope.');
  }
  if (requiresQualityAdmission(plan)) {
    validateQualityTargetDocument(plan, doc);
  } else if (doc['quality'] != null) {
    throw const FormatException('Unexpected quality targets.');
  }
  final expected = {
    for (final b in plan.blocks)
      if (b.timerConfiguration?.runningWorkout != null)
        b.blockId: b.timerConfiguration!.toJson()['running_workout'],
  };
  final actual = <String, dynamic>{};
  for (final row in doc['blocks'] as List) {
    if (row is! Map ||
        row['block_id'] is! String ||
        actual.containsKey(row['block_id'])) {
      throw const FormatException('Invalid running source scope.');
    }
    actual[row['block_id'] as String] = row['workout'];
  }
  if (!samePrescription(expected, actual) ||
      !requiresRunningTargetAdmission(plan)) {
    throw const FormatException(
      'Running target review source has changed. Re-prepare the session.',
    );
  }
}

SessionExecutionPlan applyRunningTargetAdmission(
  SessionExecutionPlan plan,
  Map<String, dynamic> snapshot,
) {
  const codec = SessionExecutionPlanCodec();
  if (plan.runningTargetAdmissionSnapshot != null &&
      !samePrescription(plan.runningTargetAdmissionSnapshot, snapshot)) {
    throw const FormatException('Started running targets are immutable.');
  }
  return codec.decodePlan({
    ...codec.encodePlan(plan),
    'runningTargetAdmissionV1': snapshot,
  });
}

RunningWorkout resolveAdmittedRunningTargets(
  RunningWorkout source,
  String blockId,
  Map<String, dynamic>? snapshot,
) {
  if (!runningAtomicSteps(source).any(
    (s) =>
        s.target.heartRateZoneRef == confirmedZone2Reference ||
        s.target.kind == RunningTargetKind.qualityPaceRef,
  )) {
    return source;
  }
  if (snapshot == null ||
      snapshot['blocks'] is! List ||
      snapshot['training_session_id'] is! int) {
    throw const FormatException(
      'Review and accept running targets before starting this run.',
    );
  }
  final z = snapshot['zone2'] as Map?;
  if (runningAtomicSteps(
    source,
  ).any((s) => s.target.heartRateZoneRef == confirmedZone2Reference)) {
    if (z == null) throw const FormatException('Missing frozen Zone 2.');
    if (z['withdrawn'] != false ||
        z['lower_bpm'] is! int ||
        z['upper_bpm'] is! int) {
      throw const FormatException('Invalid frozen Zone 2 range.');
    }
    validateConfirmedZone2(z['lower_bpm'] as int, z['upper_bpm'] as int);
  }
  final rows = (snapshot['blocks'] as List)
      .where((r) => r is Map && r['block_id'] == blockId)
      .toList();
  const codec = RunningWorkoutCodec();
  if (rows.length != 1 ||
      !samePrescription(rows.single['workout'], codec.toJson(source))) {
    throw const FormatException(
      'Frozen running source does not match this block.',
    );
  }
  final raw = codec.toJson(source);
  void resolve(Map<String, dynamic> step) {
    if (step['kind'] == 'repeat') {
      for (final child in step['steps'] as List) {
        resolve(child as Map<String, dynamic>);
      }
      return;
    }
    if ((step['target'] as Map?)?['kind'] == 'alpha_quality_pace_v1') {
      final rows = (snapshot['quality_targets'] as List?)
          ?.where(
            (r) =>
                r is Map &&
                r['block_id'] == blockId &&
                r['step_id'] == step['step_id'],
          )
          .toList();
      if (rows?.length != 1) {
        throw const FormatException(
          'A frozen quality target is required for every authored work step.',
        );
      }
      final row = rows!.single as Map;
      final t = row['target'] as Map;
      if (row['category'] != (step['target'] as Map)['category'] ||
          row['source'] != snapshot['quality']['selected_source'] ||
          row['rule_id'] != snapshot['quality']['rule_id']) {
        throw const FormatException('Frozen quality source mismatch.');
      }
      if (t['unit'] == 'seconds_per_kilometre') {
        if (t['lower'] is! int ||
            t['upper'] is! int ||
            (t['lower'] as int) < 1 ||
            (t['lower'] as int) >= (t['upper'] as int)) {
          throw const FormatException('Invalid frozen pace window.');
        }
      } else if (t['unit'] == 'rpe_cr10') {
        if (t['value'] is! int ||
            t['value'] != (step['target'] as Map)['fallback_rpe']) {
          throw const FormatException('Invalid authored RPE target.');
        }
      } else {
        throw const FormatException('Unsupported frozen target unit.');
      }

      step['target'] = t['unit'] == 'rpe_cr10'
          ? {'kind': 'rpe', 'scale': 'rpe_cr10', 'value': t['value']}
          : {
              'kind': 'pace_range',
              'low': (t['lower'] as int) * 1000,
              'high': (t['upper'] as int) * 1000,
            };
    }
    if ((step['target'] as Map?)?['zone_ref'] == confirmedZone2Reference) {
      step['target'] = {
        'kind': 'heart_rate_range',
        'low': z!['lower_bpm'],
        'high': z['upper_bpm'],
      };
    }
  }

  for (final step in raw['steps'] as List) {
    resolve(step as Map<String, dynamic>);
  }
  return codec.decodeMap(raw);
}

bool requiresQualityAdmission(SessionExecutionPlan plan) =>
    plan.blocks.any((b) {
      final w = b.timerConfiguration?.runningWorkout;
      return w != null &&
          runningAtomicSteps(
            w,
          ).any((s) => s.target.kind == RunningTargetKind.qualityPaceRef);
    });
bool requiresRunningTargetAdmission(SessionExecutionPlan plan) =>
    requiresZone2Admission(plan) || requiresQualityAdmission(plan);

void validateQualityTargetDocument(
  SessionExecutionPlan plan,
  Map<String, dynamic> doc,
) {
  final q = doc['quality'];
  if (q is! Map ||
      doc['quality_targets'] is! List ||
      !alphaQualitySources.contains(q['selected_source'])) {
    throw const FormatException('Invalid frozen quality targets.');
  }
  final source = q['selected_source'] as String;
  final rule = source == 'five_k'
      ? alphaFiveKRuleId
      : source == 'manual_threshold'
      ? alphaManualThresholdRuleId
      : authoredRpeRuleId;
  if (q['rule_id'] != rule || q['rounding'] != 'nearest_second_half_up') {
    throw const FormatException('Unsupported alpha quality rule.');
  }
  int? seconds;
  if (source != 'authored_rpe') {
    final input = q['input'];
    if (input is! Map ||
        input['athlete_id'] != doc['athlete_id'] ||
        input['revision'] is! String ||
        (input['revision'] as String).isEmpty ||
        DateTime.tryParse(input['confirmed_at']?.toString() ?? '') == null) {
      throw const FormatException('Invalid owned quality input.');
    }
    if (source == 'five_k') {
      if (input['five_k_withdrawn'] != false ||
          input['sustained'] != true ||
          input['five_k_seconds'] is! int ||
          input['five_k_date'] is! String ||
          q['evaluation_local_date'] is! String ||
          input['five_k_timezone'] != q['evaluation_timezone'] ||
          q['freshness_days'] != 56 ||
          q['cutoff_inclusive'] != true ||
          !alphaFiveKDateEligible(
            input['five_k_date'] as String,
            q['evaluation_local_date'] as String,
          )) {
        throw const FormatException('The reviewed 5K does not qualify.');
      }
      seconds = input['five_k_seconds'] as int;
    } else {
      if (input['manual_withdrawn'] != false ||
          input['manual_seconds_per_km'] is! int ||
          !{
            'manual_entry',
            'garmin_read_manually',
          }.contains(input['manual_origin'])) {
        throw const FormatException(
          'The manual threshold input is unavailable.',
        );
      }
      seconds = input['manual_seconds_per_km'] as int;
    }
  }
  final expected = <String, RunningAtomicStep>{};
  for (final b in plan.blocks) {
    final w = b.timerConfiguration?.runningWorkout;
    if (w != null) {
      for (final step in runningAtomicSteps(w)) {
        if (step.target.kind == RunningTargetKind.qualityPaceRef) {
          expected['${b.blockId}|${step.stepId}'] = step;
        }
      }
    }
  }
  final seen = <String>{};
  for (final row in doc['quality_targets'] as List) {
    if (row is! Map) throw const FormatException('Invalid quality step.');
    final key = '${row['block_id']}|${row['step_id']}';
    final step = expected[key];
    final t = row['target'];
    if (step == null ||
        !seen.add(key) ||
        row['source'] != source ||
        row['rule_id'] != rule ||
        row['category'] != step.target.qualityCategory ||
        t is! Map) {
      throw const FormatException('Quality target scope changed.');
    }
    if (source == 'authored_rpe') {
      if (step.target.fallbackRpe == null ||
          t['unit'] != 'rpe_cr10' ||
          t['value'] != step.target.fallbackRpe) {
        throw const FormatException('An authored RPE alternative is required.');
      }
    } else {
      final range = alphaQualityPaceWindow(
        seconds: seconds!,
        category: step.target.qualityCategory!,
        manualThreshold: source == 'manual_threshold',
      );
      if (t['unit'] != 'seconds_per_kilometre' ||
          t['lower'] is! int ||
          t['upper'] is! int ||
          t['lower'] != range.lower ||
          t['upper'] != range.upper) {
        throw const FormatException('Quality pace window is invalid.');
      }
    }
  }
  if (seen.length != expected.length || expected.isEmpty) {
    throw const FormatException('Every quality step needs a target.');
  }
}
