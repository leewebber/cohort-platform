import '../../../models/protocol_step_draft.dart';
import '../../../models/session_block.dart';
import '../../../models/session_block_exercise_link.dart';
import '../../../models/session_block_type.dart';
import '../../../models/workout_format.dart';

/// Projects modular blocks to legacy steps for execution compatibility (M6).
///
/// When a block contains structured strength prescriptions, each prescribed
/// exercise becomes its own legacy step with metadata populated for capture.
class BlockToLegacyStepProjector {
  const BlockToLegacyStepProjector();

  List<ProtocolStepDraft> projectBlocksToSteps(List<SessionBlock> blocks) {
    final ordered = List<SessionBlock>.from(blocks)
      ..sort((a, b) => a.position.compareTo(b.position));

    final steps = <ProtocolStepDraft>[];
    var stepOrder = 1;
    for (final block in ordered) {
      final blockSteps = _projectBlock(block, startOrder: stepOrder);
      steps.addAll(blockSteps);
      stepOrder += blockSteps.length;
    }
    return steps;
  }

  List<ProtocolStepDraft> _projectBlock(
    SessionBlock block, {
    required int startOrder,
  }) {
    if (_hasStructuredPrescriptions(block)) {
      return _projectStructuredBlock(block, startOrder: startOrder);
    }
    return [_blockToStep(block, stepOrder: startOrder)];
  }

  bool _hasStructuredPrescriptions(SessionBlock block) {
    return block.linkedExercises.any((link) => link.hasStructuredPrescription);
  }

  List<ProtocolStepDraft> _projectStructuredBlock(
    SessionBlock block, {
    required int startOrder,
  }) {
    final steps = <ProtocolStepDraft>[];
    var stepOrder = startOrder;

    final blockInstructions = block.content.trim();
    if (blockInstructions.isNotEmpty) {
      steps.add(
        ProtocolStepDraft(
          localId: 'step-proj-${block.localId}-instructions',
          stepOrder: stepOrder,
          title: '${block.title.trim().isEmpty ? block.blockType.defaultTitle : block.title.trim()} — Instructions',
          section: block.blockType.displayLabel,
          stepType: 'Instruction',
          displayStyle: 'instruction',
          notes: blockInstructions,
        ),
      );
      stepOrder++;
    }

    for (final link in block.linkedExercises) {
      steps.add(_linkToStep(block, link, stepOrder: stepOrder));
      stepOrder++;
    }

    if (steps.isEmpty) {
      return [_blockToStep(block, stepOrder: startOrder)];
    }

    return steps;
  }

  ProtocolStepDraft _linkToStep(
    SessionBlock block,
    SessionBlockExerciseLink link, {
    required int stepOrder,
  }) {
    final prescription = link.prescription;
    final title = link.displayLabelOverride?.trim().isNotEmpty == true
        ? link.displayLabelOverride!.trim()
        : 'Exercise $stepOrder';

    if (prescription == null || !prescription.hasStructuredData) {
      return ProtocolStepDraft(
        localId: 'step-proj-${link.localId}',
        stepOrder: stepOrder,
        title: title,
        section: block.blockType.displayLabel,
        stepType: 'Block',
        displayStyle: 'exercise',
        exerciseId: link.exerciseId,
        notes: block.content.trim().isEmpty ? null : block.content.trim(),
      );
    }

    return ProtocolStepDraft(
      localId: 'step-proj-${link.localId}',
      stepOrder: stepOrder,
      title: title,
      section: block.blockType.displayLabel,
      stepType: 'Strength',
      displayStyle: 'exercise',
      exerciseId: link.exerciseId,
      notes: prescription.coachCue,
      sets: prescription.sets > 0 ? prescription.sets.toString() : null,
      reps: prescription.reps.toLegacyMetadataValue(),
      load: prescription.load?.toLegacyMetadataValue(),
      rest: prescription.restSeconds != null && prescription.restSeconds! > 0
          ? '${prescription.restSeconds}s'
          : null,
      tempo: prescription.tempo,
    );
  }

  ProtocolStepDraft _blockToStep(SessionBlock block, {required int stepOrder}) {
    final primaryExercise = block.linkedExercises.isEmpty
        ? null
        : block.linkedExercises.first.exerciseId;

    final notesParts = <String>[];
    if (block.content.trim().isNotEmpty) {
      notesParts.add(block.content.trim());
    }
    if (block.coachNotes?.trim().isNotEmpty == true) {
      notesParts.add(block.coachNotes!.trim());
    }
    if (block.workoutFormat != WorkoutFormat.none) {
      notesParts.add('Format: ${block.workoutFormat.displayLabel}');
      final timer = block.timerConfiguration;
      if (timer != null) {
        notesParts.add(timer.summaryForFormat(block.workoutFormat));
      }
    }

    return ProtocolStepDraft(
      localId: 'step-proj-${block.localId}',
      stepOrder: stepOrder,
      title: block.title.trim().isEmpty ? 'Block $stepOrder' : block.title.trim(),
      section: block.blockType.displayLabel,
      stepType: 'Block',
      displayStyle: 'exercise',
      exerciseId: primaryExercise,
      notes: notesParts.isEmpty ? null : notesParts.join('\n\n'),
    );
  }
}
