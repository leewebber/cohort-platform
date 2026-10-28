import '../../../domain/running_workout/fit_workout_representation.dart';
import '../../../domain/running_workout/running_workout.dart';
import '../../programme/models/programme_execution_context.dart';
import 'authored_timed_running_execution.dart';
import 'running_target_admission.dart';
import 'session_execution_plan.dart';

/// Local-only consumer of a trusted canonical started snapshot. Caller supplies
/// its independently retained digest; this does not authenticate arbitrary JSON.
class FrozenRunningFitExport {
  FrozenRunningFitExport._(this.json) : digest = fitManifestDigest(json);
  final Map<String, dynamic> json;
  final String digest;
  Map<String, dynamic> get scope => json['scope'] as Map<String, dynamic>;

  factory FrozenRunningFitExport.fromAcceptedPlan({
    required SessionExecutionPlan plan,
    required ProgrammeExecutionContext context,
    required String athleteId,
    required int trainingSessionId,
    required String expectedSnapshotDigest,
  }) {
    final snapshot = plan.runningTargetAdmissionSnapshot;
    final hex = RegExp(r'^[a-f0-9]{64}$');
    if (athleteId.trim().isEmpty ||
        context.assignmentId.isEmpty ||
        context.programmeVersionId.isEmpty ||
        context.sessionSlotId.isEmpty ||
        context.occurrenceId?.isNotEmpty != true ||
        !hex.hasMatch(context.packageContentHash ?? '') ||
        !{1, 2}.contains(context.packageSchemaVersion) ||
        context.plannedProtocolId != context.effectiveProtocolId ||
        plan.sessionId != context.effectiveProtocolId ||
        plan.boundPrescriptionSnapshot != null ||
        plan.prescriptionLoadOverrides.isNotEmpty ||
        plan.durationChoiceSnapshot != null ||
        plan.blocks.length != 1) {
      throw const FitWorkoutRefusal(
        'unsupported_scope',
        'Use one original fixed v1/v2 timed body with exact owner, occurrence, slot and package identity; adapted/v3/multiple-body exports are not supported.',
      );
    }
    if (snapshot == null ||
        trainingSessionId <= 0 ||
        snapshot['training_session_id'] != trainingSessionId ||
        !hex.hasMatch(snapshot['review_hash']?.toString() ?? '') ||
        DateTime.tryParse(snapshot['accepted_at']?.toString() ?? '')?.isUtc !=
            true ||
        !hex.hasMatch(expectedSnapshotDigest) ||
        fitManifestDigest(snapshot) != expectedSnapshotDigest) {
      throw const FitWorkoutRefusal(
        'unfrozen_or_changed',
        'Load the original accepted canonical session snapshot and retained digest; a preview or edited snapshot cannot be exported.',
      );
    }
    try {
      validateRunningTargetDocument(
        plan,
        snapshot,
        athleteId: athleteId,
        occurrenceId: context.occurrenceId!,
        assignmentId: context.assignmentId,
        versionId: context.programmeVersionId,
        packageHash: context.packageContentHash!,
      );
    } on TypeError {
      throw const FitWorkoutRefusal(
        'malformed_snapshot',
        'Reload the canonical accepted snapshot; its target packet is malformed.',
      );
    }
    final block = plan.blocks.single;
    final source = block.timerConfiguration?.runningWorkout;
    if (source == null) {
      throw const FitWorkoutRefusal(
        'missing_body',
        'Load the exact structured running body.',
      );
    }
    final execution = AuthoredTimedRunningExecution.fromBlock(
      block,
      admission: snapshot,
    );
    final representation = const TimedFitWorkoutConverter().convert(
      execution.workout,
    );
    const codec = RunningWorkoutCodec();
    return FrozenRunningFitExport._(
      freezeFitValue({
            'schema': 'cohort_local_frozen_fit_export_v1',
            'scope': {
              'athlete_id': athleteId,
              'assignment_id': context.assignmentId,
              'programme_version_id': context.programmeVersionId,
              'package_schema_version': context.packageSchemaVersion,
              'package_hash': context.packageContentHash,
              'protocol_id': plan.sessionId,
              'occurrence_id': context.occurrenceId,
              'session_slot_id': context.sessionSlotId,
              'training_session_id': trainingSessionId,
              'block_id': block.blockId,
              'workout_id': source.workoutId,
            },
            'source_body_sha256': fitManifestDigest(codec.toJson(source)),
            'accepted_snapshot_sha256': expectedSnapshotDigest,
            'prescription': {
              'source_body': codec.toJson(source),
              'resolved_body': codec.toJson(execution.workout),
              'accepted_snapshot': snapshot,
            },
            'fit_fields': representation,
          })
          as Map<String, dynamic>,
    );
  }
}
