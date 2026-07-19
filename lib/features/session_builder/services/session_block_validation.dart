import '../../../models/session_block.dart';
import '../../../models/timer_configuration.dart';
import '../../../models/workout_format.dart';

/// Block-aware validation for Session authoring (M6).
class SessionBlockValidation {
  const SessionBlockValidation();

  List<String> validateSession({
    required String name,
    required List<SessionBlock> blocks,
    bool requirePublishableContent = true,
  }) {
    final messages = <String>[];

    if (name.trim().isEmpty) {
      messages.add('Session title is required.');
    }

    if (requirePublishableContent && blocks.isEmpty) {
      messages.add('Add at least one block.');
    }

    final ordered = List<SessionBlock>.from(blocks)
      ..sort((a, b) => a.position.compareTo(b.position));

    for (var index = 0; index < ordered.length; index++) {
      final block = ordered[index];
      final expectedPosition = index + 1;

      if (block.position != expectedPosition) {
        messages.add(
          'Block order must run from 1 to ${ordered.length} without gaps.',
        );
        break;
      }

      messages.addAll(
        validateBlock(block).map((message) => 'Block ${block.position}: $message'),
      );
    }

    if (requirePublishableContent &&
        ordered.isNotEmpty &&
        !ordered.any((block) => block.hasMeaningfulContent)) {
      messages.add('Add content, linked exercises, or a timer to at least one block.');
    }

    return messages;
  }

  List<String> validateBlock(SessionBlock block) {
    final messages = <String>[];

    if (block.title.trim().isEmpty) {
      messages.add('title is required.');
    }

    if (block.workoutFormat != WorkoutFormat.none) {
      final timer = block.timerConfiguration ?? const TimerConfiguration();
      messages.addAll(timer.validateForFormat(block.workoutFormat));
    }

    final seenExerciseIds = <String>{};
    for (final link in block.linkedExercises) {
      if (link.exerciseId.trim().isEmpty) {
        messages.add('linked exercises must reference a valid exercise.');
      } else if (!seenExerciseIds.add(link.exerciseId.trim())) {
        messages.add('duplicate exercise links are not allowed in one block.');
      }
    }

    return messages;
  }
}
