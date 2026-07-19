import '../../../models/protocol_step.dart';
import '../../../models/session_block.dart';
import '../../../models/session_block_exercise_link.dart';
import '../../../models/session_block_type.dart';
import '../../../models/workout_format.dart';

/// Converts persisted [ProtocolStep] rows into [SessionBlock]s for athlete loading.
///
/// Authoring-time draft conversion lives in
/// [LegacyStepToBlockConverter] under session_builder.
class ProtocolStepToBlockConverter {
  const ProtocolStepToBlockConverter();

  List<SessionBlock> convertStepsToBlocks(List<ProtocolStep> steps) {
    if (steps.isEmpty) return const [];

    final ordered = List<ProtocolStep>.from(steps)
      ..sort((a, b) => a.stepOrder.compareTo(b.stepOrder));

    final contentParts = <String>[];
    final links = <SessionBlockExerciseLink>[];
    var linkPosition = 1;

    for (final step in ordered) {
      final lines = <String>[];
      if (step.title.trim().isNotEmpty) lines.add(step.title.trim());
      if (step.notes?.trim().isNotEmpty == true) lines.add(step.notes!.trim());
      _append(lines, 'Sets', step.sets);
      _append(lines, 'Reps', step.reps);
      _append(lines, 'Load', step.load);
      _append(lines, 'Duration', step.duration);
      _append(lines, 'Rest', step.rest);
      if (lines.isNotEmpty) contentParts.add(lines.join('\n'));

      final exerciseId = step.exerciseId?.trim();
      if (exerciseId != null && exerciseId.isNotEmpty) {
        links.add(
          SessionBlockExerciseLink(
            localId: 'link-legacy-${step.id}',
            exerciseId: exerciseId,
            position: linkPosition,
            displayLabelOverride:
                step.title.trim().isEmpty ? null : step.title.trim(),
          ),
        );
        linkPosition++;
      }
    }

    return [
      SessionBlock(
        localId: 'block-legacy-session',
        blockType: SessionBlockType.custom,
        title: 'Session',
        content: contentParts.join('\n\n'),
        workoutFormat: WorkoutFormat.none,
        position: 1,
        linkedExercises: links,
      ),
    ];
  }

  void _append(List<String> lines, String label, String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    lines.add('$label: $trimmed');
  }
}
