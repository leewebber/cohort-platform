import 'package:cohort_platform/application/ports/knowledge_graph_reader.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/strength_exercise_prescription.dart';

import 'approved_equipment_substitution.dart';

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
    KnowledgeGraphReader? knowledge,
    ApprovedEquipmentSubstitution? approval,
  }) {
    if (snapshot.sourceProtocolId.trim() != authoredDraft.protocolId.trim()) {
      throw StateError(
        'Snapshot protocol does not match authored draft protocol.',
      );
    }

    final swaps = snapshot.appliedAdaptationAudit.where(
      (entry) => entry.actionType == AdaptationActionType.swapExercise,
    );
    if (swaps.isNotEmpty) {
      if (knowledge == null ||
          snapshot.appliedAdaptationAudit.length != 1 ||
          snapshot.omittedBlocks.isNotEmpty) {
        throw StateError('Expected one exact equipment substitution.');
      }
      return _applyExerciseSwap(
        originalPlan,
        authoredDraft,
        swaps.single,
        knowledge,
        approval: approval,
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
      blocks.add(_applyRetainedBlock(base, retained));
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

  SessionExecutionPlan _applyExerciseSwap(
    SessionExecutionPlan plan,
    ProtocolDraft draft,
    AdaptationStepAuditEntry swap,
    KnowledgeGraphReader knowledge, {
    required ApprovedEquipmentSubstitution? approval,
  }) {
    final source = swap.originalValueReference;
    final replacement = swap.appliedValueReference;
    final draftBlock = draft.blocks.singleWhere(
      (block) => block.localId == swap.blockLocalId,
    );
    final link = draftBlock.linkedExercises.singleWhere(
      (link) =>
          link.localId == swap.exerciseLinkLocalId && link.exerciseId == source,
    );
    final block = plan.blocks.singleWhere(
      (block) => block.blockId == draftBlock.stableId,
    );
    final original = block.linkedExercises.singleWhere(
      (exercise) =>
          exercise.position == link.position && exercise.exerciseId == source,
    );
    final originalExercise = source == null
        ? null
        : knowledge.exerciseById(source);
    final candidate = replacement == null
        ? null
        : knowledge.exerciseById(replacement);
    final prescription = original.prescription;
    if (approval != null &&
        (draft.protocolId != approval.protocolId ||
            source != approval.sourceId ||
            replacement != approval.replacementId ||
            block.position != approval.blockPosition ||
            original.position != approval.exercisePosition ||
            prescription?.authoredDetails?['source_occurrence_id'] !=
                approval.occurrenceKey)) {
      throw StateError('The approved exercise occurrence does not match.');
    }
    const bodyweight = 'cohort.equipment.bodyweight';
    // Keep this slice to a working strength placement with transferable
    // programming. Exercise-specific loads or capture instructions need review.
    if (originalExercise == null ||
        candidate == null ||
        originalExercise.requiredEquipmentIds.contains(bodyweight) ||
        candidate.requiredEquipmentIds.isEmpty ||
        candidate.requiredEquipmentIds.contains(bodyweight) ||
        candidate.meta.status != 'active' ||
        candidate.meta.label.trim().isEmpty ||
        (block.blockType != SessionBlockType.strength &&
            block.blockType != SessionBlockType.accessory) ||
        prescription == null ||
        !prescription.hasStructuredData ||
        (prescription.load != null &&
            prescription.load!.type != StrengthLoadType.athleteSelected) ||
        (approval == null &&
            (prescription.coachCue?.trim().isNotEmpty == true ||
                prescription.authoredDetails != null ||
                prescription.performanceCapture != null)) ||
        plan.prescriptionLoadOverrides.isNotEmpty) {
      throw StateError(
        'The replacement needs an approved strength prescription.',
      );
    }
    if (block.linkedExercises.any(
      (exercise) => exercise.exerciseId == replacement,
    )) {
      throw StateError(
        'The replacement would duplicate an exercise in this block.',
      );
    }

    final adaptedBlock = SessionExecutionBlock(
      blockId: block.blockId,
      title: block.title,
      blockType: block.blockType,
      content: block.content,
      workoutFormat: block.workoutFormat,
      position: block.position,
      boundTarget: block.boundTarget,
      timerConfiguration: block.timerConfiguration,
      timerSummary: block.timerSummary,
      coachNotes: block.coachNotes,
      performanceCaptureMode: block.performanceCaptureMode,
      linkedExercises: [
        for (final exercise in block.linkedExercises)
          if (identical(exercise, original))
            SessionExecutionExerciseSummary(
              exerciseId: candidate.id,
              displayName: candidate.meta.label,
              position: original.position,
              prescription: approval?.prescription ?? prescription,
              executionGroupKey: original.executionGroupKey,
              executionGroupLabel: original.executionGroupLabel,
              executionGroupRounds: original.executionGroupRounds,
            )
          else
            exercise,
      ],
    );
    return SessionExecutionPlan(
      sessionId: plan.sessionId,
      sessionTitle: plan.sessionTitle,
      blocks: [
        for (final original in plan.blocks)
          identical(original, block) ? adaptedBlock : original,
      ],
      protocol: plan.protocol,
      durationMin: plan.durationMin,
      coachNotes: plan.coachNotes,
      programmeContextLabel: plan.programmeContextLabel,
      prescriptionLoadOverrides: plan.prescriptionLoadOverrides,
      boundPrescriptionSnapshot: plan.boundPrescriptionSnapshot,
      durationChoiceSnapshot: plan.durationChoiceSnapshot,
      runningTargetAdmissionSnapshot: plan.runningTargetAdmissionSnapshot,
      authoredSource: plan.authoredSource,
    );
  }

  SessionExecutionBlock _applyRetainedBlock(
    SessionExecutionBlock base,
    BlockExecutionSnapshot retained,
  ) {
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
