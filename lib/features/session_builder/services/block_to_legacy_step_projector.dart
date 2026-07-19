import '../../../models/protocol_step_draft.dart';
import '../../../models/session_block.dart';
import '../../../models/session_block_type.dart';
import '../../../models/workout_format.dart';

/// Projects modular blocks to legacy steps for execution compatibility (M6).
class BlockToLegacyStepProjector {
  const BlockToLegacyStepProjector();

  List<ProtocolStepDraft> projectBlocksToSteps(List<SessionBlock> blocks) {
    final ordered = List<SessionBlock>.from(blocks)
      ..sort((a, b) => a.position.compareTo(b.position));

    return [
      for (var index = 0; index < ordered.length; index++)
        _blockToStep(ordered[index], stepOrder: index + 1),
    ];
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
