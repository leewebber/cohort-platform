import '../../../domain/hyrox_base/programme_prescription.dart';
import '../../../models/strength_exercise_prescription.dart';
import '../../../models/block_performance_capture_mode.dart';
import '../../../models/workout_format.dart';
import 'session_execution_plan.dart';

/// Validates actual runner semantics before consent/start and again on frozen start.
/// This is deliberately limited to the server's flat run/row/squat profile.
SessionExecutionPlan bindProgrammePrescription({
  required SessionExecutionPlan plan,
  required ProgrammePrescription prescription,
  required String protocolId,
  required String slotKey,
}) {
  if (slotKey.isEmpty) {
    _refuse();
  }
  final targets = prescription.targets
      .where((t) => t.binding['slot_key'] == slotKey)
      .toList();
  final seen = <String>{};
  for (final t in targets) {
    final blocks = plan.blocks.where((b) => b.blockId == t.blockId).toList();
    if (!seen.add(t.blockId) ||
        blocks.length != 1 ||
        t.binding['protocol_id'] != protocolId) {
      _refuse();
    }
    final b = blocks.single;
    if (b.linkedExercises.length != 1 ||
        b.linkedExercises.single.hasExecutionGroup ||
        b.linkedExercises.single.exerciseId !=
            (t.binding['exercise'] as Map)['id']) {
      _refuse();
    }
    if (t.kind == 'backSquat') {
      if (!{
        BlockPerformanceCaptureMode.automatic,
        BlockPerformanceCaptureMode.strength,
      }.contains(b.performanceCaptureMode)) {
        _refuse();
      }
      final p = b.linkedExercises.single.prescription;
      final reps = p?.reps;
      if (b.workoutFormat != WorkoutFormat.none ||
          b.timerConfiguration != null ||
          p == null ||
          p.sets != t.authored['sets'] ||
          reps?.type != StrengthRepType.exact ||
          reps?.exactReps != t.authored['reps'] ||
          (t.json['steps'] as List).isNotEmpty ||
          (t.binding['step_ids'] as List).isNotEmpty) {
        _refuse();
      }
    } else {
      if (!{
        BlockPerformanceCaptureMode.automatic,
        BlockPerformanceCaptureMode.intervals,
      }.contains(b.performanceCaptureMode)) {
        _refuse();
      }
      final timer = b.timerConfiguration;
      final repetitions = t.authored['repetitions'];
      final work = t.authored['work_seconds'];
      final rest = t.authored['recovery_seconds'];
      if (b.workoutFormat != WorkoutFormat.intervals ||
          timer == null ||
          !b.hasTimer ||
          timer.rounds != repetitions ||
          timer.workSeconds != work ||
          timer.restSeconds != rest ||
          timer.preparationSeconds != null ||
          timer.stations.isNotEmpty ||
          timer.captureStrategy != null ||
          timer.durationSeconds != null ||
          timer.timeCapSeconds != null ||
          timer.totalDurationSeconds != null ||
          timer.intervalSeconds != null ||
          timer.restBetweenRoundsSeconds != null ||
          timer.stopwatchEnabled ||
          repetitions is! int ||
          work is! int ||
          rest is! int ||
          repetitions <= 0 ||
          work <= 0 ||
          rest <= 0) {
        _refuse();
      }
      final expected = <Map<String, dynamic>>[];
      final workIds = <String>[];
      for (var n = 1; n <= repetitions; n++) {
        workIds.add('work-$n');
        expected.add({
          'step_id': 'work-$n',
          'kind': 'work',
          'duration_seconds': work,
          'target': t.calculated,
        });
        if (n < repetitions) {
          expected.add({
            'step_id': 'recovery-$n',
            'kind': 'recovery',
            'duration_seconds': rest,
            'target': null,
          });
        }
      }
      // Compare structure independently of map ordering from JSONB transports.
      if (!_equal(t.json['steps'], expected) ||
          !_equal(t.binding['step_ids'], workIds)) {
        _refuse();
      }
    }
  }
  return SessionExecutionPlan(
    authoredSource: plan.authoredSource,
    durationChoiceSnapshot: plan.durationChoiceSnapshot,
    sessionId: plan.sessionId,
    sessionTitle: plan.sessionTitle,
    protocol: plan.protocol,
    durationMin: plan.durationMin,
    coachNotes: plan.coachNotes,
    programmeContextLabel: plan.programmeContextLabel,
    prescriptionLoadOverrides: plan.prescriptionLoadOverrides,
    boundPrescriptionSnapshot: prescription.json,
    blocks: List.unmodifiable(
      plan.blocks.map((b) {
        final t = targets.where((t) => t.blockId == b.blockId).firstOrNull;
        return SessionExecutionBlock(
          blockId: b.blockId,
          title: b.title,
          blockType: b.blockType,
          content: b.content,
          workoutFormat: b.workoutFormat,
          position: b.position,
          timerConfiguration: b.timerConfiguration,
          timerSummary: b.timerSummary,
          coachNotes: b.coachNotes,
          performanceCaptureMode: b.performanceCaptureMode,
          boundTarget: t,
          linkedExercises: List.unmodifiable(
            b.linkedExercises.map((e) {
              final p = e.prescription;
              return SessionExecutionExerciseSummary(
                exerciseId: e.exerciseId,
                displayName: e.displayName,
                position: e.position,
                displayLabelOverride: e.displayLabelOverride,
                exercise: e.exercise,
                executionGroupKey: e.executionGroupKey,
                executionGroupLabel: e.executionGroupLabel,
                executionGroupRounds: e.executionGroupRounds,
                prescription: t?.kind == 'backSquat' && p != null
                    ? p.copyWith(
                        load: t!.available
                            ? StrengthLoadPrescription(
                                type: StrengthLoadType.fixedKg,
                                kg: (t.calculated['grams'] as int) / 1000,
                              )
                            : StrengthLoadPrescription(
                                type: StrengthLoadType.freeText,
                                text: t.json['authored_effort'] as String,
                              ),
                      )
                    : p,
              );
            }),
          ),
        );
      }),
    ),
  );
}

Never _refuse() => throw const FormatException(
  'This programme prescription cannot be represented safely by the workout runner.',
);
bool _equal(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((k) => b.containsKey(k) && _equal(a[k], b[k]));
  }
  if (a is List && b is List) {
    return a.length == b.length &&
        List.generate(a.length, (i) => i).every((i) => _equal(a[i], b[i]));
  }
  return a == b;
}
