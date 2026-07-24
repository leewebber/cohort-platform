import 'package:founder_importer/models/protocol_step_draft.dart';
import 'package:founder_importer/models/session_block.dart';
import 'package:founder_importer/models/session_block_exercise_link.dart';
import 'package:founder_importer/models/session_block_type.dart';
import 'package:founder_importer/models/workout_format.dart';

/// Converts legacy [ProtocolStepDraft] rows into modular [SessionBlock]s (M6).
class LegacyStepToBlockConverter {
  const LegacyStepToBlockConverter();

  List<SessionBlock> convertStepsToBlocks(List<ProtocolStepDraft> steps) {
    if (steps.isEmpty) {
      return const [];
    }

    final ordered = List<ProtocolStepDraft>.from(steps)
      ..sort((a, b) => a.stepOrder.compareTo(b.stepOrder));

    final content = _buildContent(ordered);
    final links = _buildExerciseLinks(ordered);

    return [
      SessionBlock(
        localId: 'block-legacy-${DateTime.now().microsecondsSinceEpoch}',
        blockType: SessionBlockType.custom,
        title: 'Session',
        content: content,
        workoutFormat: WorkoutFormat.none,
        position: 1,
        linkedExercises: links,
      ),
    ];
  }

  String _buildContent(List<ProtocolStepDraft> steps) {
    final parts = <String>[];

    for (final step in steps) {
      final lines = <String>[];
      if (step.title.trim().isNotEmpty) {
        lines.add(step.title.trim());
      }
      if (step.notes?.trim().isNotEmpty == true) {
        lines.add(step.notes!.trim());
      }
      _appendPrescription(lines, 'Sets', step.sets);
      _appendPrescription(lines, 'Reps', step.reps);
      _appendPrescription(lines, 'Load', step.load);
      _appendPrescription(lines, 'Duration', step.duration);
      _appendPrescription(lines, 'Distance', step.distance);
      _appendPrescription(lines, 'Rest', step.rest);
      _appendPrescription(lines, 'Tempo', step.tempo);

      if (lines.isNotEmpty) {
        parts.add(lines.join('\n'));
      }
    }

    return parts.join('\n\n');
  }

  void _appendPrescription(List<String> lines, String label, String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    lines.add('$label: $trimmed');
  }

  List<SessionBlockExerciseLink> _buildExerciseLinks(
    List<ProtocolStepDraft> steps,
  ) {
    final links = <SessionBlockExerciseLink>[];
    var position = 1;

    for (final step in steps) {
      final exerciseId = step.exerciseId?.trim();
      if (exerciseId == null || exerciseId.isEmpty) continue;

      links.add(
        SessionBlockExerciseLink(
          localId: 'link-legacy-${step.localId}',
          exerciseId: exerciseId,
          position: position,
          displayLabelOverride: step.title.trim().isEmpty
              ? null
              : step.title.trim(),
        ),
      );
      position++;
    }

    return links;
  }
}
