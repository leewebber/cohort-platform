// SOFTWARE FIXTURES ONLY. No real Garmin data, content approval or athlete proof.
import 'package:cohort_platform/domain/running_workout/running_workout.dart';
import 'package:cohort_platform/domain/running_workout/fit_workout_representation.dart';
import 'package:cohort_platform/features/programme/models/programme_execution_context.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/models/frozen_running_fit_export.dart';
import 'package:cohort_platform/features/session/models/running_target_admission.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/timer_configuration.dart';
import 'package:cohort_platform/models/workout_format.dart';

class FrozenFitFixture {
  FrozenFitFixture({
    this.owner = 'fixture-owner-a',
    this.version = 'fixture-version-1',
    this.occurrence = 'fixture-occurrence-1',
    this.inputRevision = 'fixture-input-1',
  }) {
    context = ProgrammeExecutionContext(
      assignmentId: 'fixture-assignment',
      programmeVersionId: version,
      sessionSlotId: 'fixture-slot',
      weekNumber: 1,
      dayKey: 'day_1',
      sessionOrder: 1,
      plannedProtocolId: 'fixture-protocol',
      effectiveProtocolId: 'fixture-protocol',
      packageContentHash: 'a' * 64,
      occurrenceId: occurrence,
      packageSchemaVersion: 2,
    );
    source = const RunningWorkout(
      workoutId: 'SOFTWARE-FIXTURE-M25',
      title: '[SOFTWARE FIXTURE ONLY] M25 mixed targets',
      notes: 'Do not publish or train from this synthetic conversion fixture.',
      steps: [
        RunningAtomicStep(
          stepId: 'warm',
          role: RunningStepRole.warmUp,
          duration: RunningDuration.time(300000),
        ),
        RunningRepeatGroup(
          groupId: 'repetitions',
          count: 3,
          steps: [
            RunningAtomicStep(
              stepId: 'effort',
              role: RunningStepRole.work,
              duration: RunningDuration.time(120000),
              target: RunningTarget.qualityPaceRef('threshold'),
            ),
            RunningAtomicStep(
              stepId: 'recover',
              role: RunningStepRole.recovery,
              duration: RunningDuration.time(60000),
              target: RunningTarget.heartRateZoneRef(confirmedZone2Reference),
            ),
          ],
        ),
        RunningAtomicStep(
          stepId: 'cool',
          role: RunningStepRole.coolDown,
          duration: RunningDuration.time(300000),
        ),
      ],
    );
    snapshot = {
      'schema_version': 1,
      'athlete_id': owner,
      'assignment_id': context.assignmentId,
      'programme_version_id': version,
      'package_hash': context.packageContentHash,
      'protocol_id': 'fixture-protocol',
      'occurrence_id': occurrence,
      'training_session_id': 17,
      'review_hash': 'b' * 64,
      'accepted_at': '2026-10-28T00:00:00Z',
      'blocks': [
        {
          'block_id': 'fixture-block',
          'workout': const RunningWorkoutCodec().toJson(source),
        },
      ],
      'zone2': {
        'athlete_id': owner,
        'withdrawn': false,
        'revision': 'fixture-zone-1',
        'confirmed_at': '2026-10-27T00:00:00Z',
        'lower_bpm': 130,
        'upper_bpm': 145,
      },
      'quality': {
        'rule_id': 'alpha_manual_threshold_pm2_v1',
        'rounding': 'nearest_second_half_up',
        'selected_source': 'manual_threshold',
        'input': {
          'athlete_id': owner,
          'revision': inputRevision,
          'confirmed_at': '2026-10-27T00:00:00Z',
          'manual_withdrawn': false,
          'manual_seconds_per_km': 300,
          'manual_origin': 'manual_entry',
        },
      },
      'quality_targets': [
        {
          'block_id': 'fixture-block',
          'step_id': 'effort',
          'category': 'threshold',
          'source': 'manual_threshold',
          'rule_id': 'alpha_manual_threshold_pm2_v1',
          'target': {
            'unit': 'seconds_per_kilometre',
            'lower': 294,
            'upper': 306,
          },
        },
      ],
    };
    retainedDigest = fitManifestDigest(snapshot);
  }
  final String owner, version, occurrence, inputRevision;
  late final ProgrammeExecutionContext context;
  late final RunningWorkout source;
  late final Map<String, dynamic> snapshot;
  late final String retainedDigest;
  SessionExecutionPlan plan({
    RunningWorkout? body,
    Map<String, dynamic>? admission,
  }) => SessionExecutionPlan(
    sessionId: 'fixture-protocol',
    sessionTitle: '[FIXTURE ONLY]',
    runningTargetAdmissionSnapshot: admission ?? snapshot,
    blocks: [
      SessionExecutionBlock(
        blockId: 'fixture-block',
        title: '[FIXTURE ONLY]',
        blockType: SessionBlockType.conditioning,
        content: 'Synthetic software fixture',
        workoutFormat: WorkoutFormat.steadyState,
        position: 1,
        timerConfiguration: TimerConfiguration(
          durationSeconds: 1140,
          runningWorkout: body ?? source,
        ),
      ),
    ],
  );
  FrozenRunningFitExport export({
    String? actor,
    String? digest,
    SessionExecutionPlan? executionPlan,
    ProgrammeExecutionContext? scope,
    int session = 17,
  }) => FrozenRunningFitExport.fromAcceptedPlan(
    plan: executionPlan ?? plan(),
    context: scope ?? context,
    athleteId: actor ?? owner,
    trainingSessionId: session,
    expectedSnapshotDigest: digest ?? retainedDigest,
  );
}
