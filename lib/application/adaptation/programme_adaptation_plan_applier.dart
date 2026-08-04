import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/strength_exercise_prescription.dart';

/// Builds a reviewed [SessionExecutionPlan] from an adapted snapshot + authored draft.
///
/// Deterministic translation only — not a second adaptation engine.
class ProgrammeAdaptationPlanApplier {
  const ProgrammeAdaptationPlanApplier();

  /// Applies retained/omitted snapshot structure onto the authored draft blocks,
  /// preserving original [SessionExecutionPlan] identity fields.
  SessionExecutionPlan applySnapshot({
    required SessionExecutionPlan originalPlan,
    required ProtocolDraft authoredDraft,
    required AdaptedSessionExecutionSnapshot snapshot,
  }) {
    if (snapshot.sourceProtocolId.trim() != authoredDraft.protocolId.trim()) {
      throw StateError(
        'Snapshot protocol does not match authored draft protocol.',
      );
    }

    final omitted = {
      for (final block in snapshot.omittedBlocks) block.sourceBlockLocalId,
    };
    final retainedByLocalId = {
      for (final block in snapshot.retainedBlocks)
        block.sourceBlockLocalId: block,
    };

    final blocks = <SessionExecutionBlock>[];
    for (final draftBlock in authoredDraft.blocks) {
      if (omitted.contains(draftBlock.localId)) continue;
      final retained = retainedByLocalId[draftBlock.localId];
      final base = SessionExecutionBlock.fromSessionBlock(
        draftBlock,
        exercisesById: const {},
      );
      if (retained == null) {
        blocks.add(base);
        continue;
      }
      final swapByOriginal = <String, String>{
        for (final entry in snapshot.appliedAdaptationAudit)
          if (entry.actionType == AdaptationActionType.swapExercise &&
              entry.originalValueReference != null &&
              entry.appliedValueReference != null)
            entry.originalValueReference!: entry.appliedValueReference!,
      };
      blocks.add(
        _applyRetainedBlock(base, retained, swapByOriginalId: swapByOriginal),
      );
    }

    if (blocks.isEmpty) {
      throw StateError('Adapted plan would contain no executable blocks.');
    }

    return SessionExecutionPlan(
      sessionId: originalPlan.sessionId,
      sessionTitle: originalPlan.sessionTitle,
      blocks: List.unmodifiable(blocks),
      protocol: originalPlan.protocol,
      durationMin:
          snapshot.resultingEstimatedDurationMin ?? originalPlan.durationMin,
      coachNotes: originalPlan.coachNotes,
      programmeContextLabel: originalPlan.programmeContextLabel,
      prescriptionLoadOverrides: originalPlan.prescriptionLoadOverrides,
    );
  }

  SessionExecutionBlock _applyRetainedBlock(
    SessionExecutionBlock base,
    BlockExecutionSnapshot retained, {
    Map<String, String> swapByOriginalId = const {},
  }) {
    final byLinkId = {
      for (final exercise in retained.exercises)
        exercise.exerciseLinkLocalId: exercise,
    };
    final byExerciseId = {
      for (final exercise in retained.exercises) exercise.exerciseId: exercise,
    };

    final linked = base.linkedExercises
        .map((summary) {
          ExerciseExecutionSnapshot? match;
          // Prefer stable exercise id; link local ids are not on SessionExecutionExerciseSummary.
          match = byExerciseId[summary.exerciseId];
          final swappedTo = swapByOriginalId[summary.exerciseId];
          if (match == null && swappedTo != null) {
            match = byExerciseId[swappedTo];
          }
          if (match == null &&
              byLinkId.length == 1 &&
              base.linkedExercises.length == 1) {
            match = byLinkId.values.first;
          }
          if (match == null || !match.adapted) return summary;

          final execution = match.executionPrescription;
          final original = summary.prescription;
          final exerciseIdChanged = match.exerciseId != summary.exerciseId;
          if (!exerciseIdChanged &&
              original == null &&
              execution.sets == null &&
              execution.reps == null) {
            return summary;
          }
          return SessionExecutionExerciseSummary(
            exerciseId: match.exerciseId,
            displayName: exerciseIdChanged
                ? match.exerciseId
                : summary.displayName,
            displayLabelOverride: summary.displayLabelOverride,
            exercise: exerciseIdChanged ? null : summary.exercise,
            prescription: StrengthExercisePrescription(
              sets: execution.sets ?? original?.sets ?? 0,
              reps: execution.reps != null
                  ? StrengthRepPrescription.exact(execution.reps!)
                  : (original?.reps ?? StrengthRepPrescription.exact(0)),
              restSeconds: execution.restSeconds ?? original?.restSeconds,
              tempo: original?.tempo,
              load: original?.load,
              coachCue: original?.coachCue,
              groupId: original?.groupId,
            ),
          );
        })
        .toList(growable: false);

    return SessionExecutionBlock(
      blockId: base.blockId,
      title: base.title,
      blockType: base.blockType,
      content: base.content,
      workoutFormat: base.workoutFormat,
      position: base.position,
      timerConfiguration: base.timerConfiguration,
      timerSummary: base.timerSummary,
      linkedExercises: linked,
      coachNotes: base.coachNotes,
      performanceCaptureMode: base.performanceCaptureMode,
    );
  }
}
