import '../../../core/persistence/session_execution_plan_codec.dart';
import '../../../domain/hyrox_base/programme_prescription.dart';
import '../../../domain/running_workout/running_workout.dart';
import 'session_execution_plan.dart';

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
      doc['zone2'] is! Map ||
      doc['blocks'] is! List) {
    throw const FormatException(
      'Running target review does not match this athlete and workout. Re-prepare the session.',
    );
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
  if (!samePrescription(expected, actual) || !requiresZone2Admission(plan)) {
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

RunningWorkout resolveAdmittedZone2(
  RunningWorkout source,
  String blockId,
  Map<String, dynamic>? snapshot,
) {
  if (!runningAtomicSteps(
    source,
  ).any((s) => s.target.heartRateZoneRef == confirmedZone2Reference)) {
    return source;
  }
  if (snapshot == null ||
      snapshot['zone2'] is! Map ||
      snapshot['blocks'] is! List ||
      snapshot['training_session_id'] is! int) {
    throw const FormatException(
      'Review and accept Zone 2 before starting this run.',
    );
  }
  final z = snapshot['zone2'] as Map;
  if (z['withdrawn'] != false ||
      z['lower_bpm'] is! int ||
      z['upper_bpm'] is! int) {
    throw const FormatException('Invalid frozen Zone 2 range.');
  }
  validateConfirmedZone2(z['lower_bpm'] as int, z['upper_bpm'] as int);
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
    if ((step['target'] as Map?)?['zone_ref'] == confirmedZone2Reference) {
      step['target'] = {
        'kind': 'heart_rate_range',
        'low': z['lower_bpm'],
        'high': z['upper_bpm'],
      };
    }
  }

  for (final step in raw['steps'] as List) {
    resolve(step as Map<String, dynamic>);
  }
  return codec.decodeMap(raw);
}
