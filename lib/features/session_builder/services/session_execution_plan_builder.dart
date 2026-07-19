import '../../../models/exercise.dart';
import '../../../models/session_block.dart';
import '../../../models/session_block_exercise_link.dart';
import '../../../models/session_block_type.dart';
import '../../../models/timer_configuration.dart';
import '../../../models/workout_format.dart';

/// Athlete-facing projection of modular Session content (M6).
class SessionExecutionPlan {
  const SessionExecutionPlan({
    required this.sessionTitle,
    required this.blocks,
  });

  final String sessionTitle;
  final List<SessionExecutionBlock> blocks;
}

class SessionExecutionBlock {
  const SessionExecutionBlock({
    required this.title,
    required this.blockTypeLabel,
    required this.content,
    required this.workoutFormat,
    this.timerSummary,
    this.linkedExerciseSummaries = const [],
    this.coachNotes,
  });

  final String title;
  final String blockTypeLabel;
  final String content;
  final WorkoutFormat workoutFormat;
  final String? timerSummary;
  final List<SessionExecutionExerciseSummary> linkedExerciseSummaries;
  final String? coachNotes;

  String? get workoutFormatLabel =>
      workoutFormat == WorkoutFormat.none ? null : workoutFormat.displayLabel;
}

class SessionExecutionExerciseSummary {
  const SessionExecutionExerciseSummary({
    required this.displayName,
    this.exerciseId,
  });

  final String displayName;
  final String? exerciseId;
}

class SessionExecutionPlanBuilder {
  const SessionExecutionPlanBuilder();

  SessionExecutionPlan build({
    required String sessionTitle,
    required List<SessionBlock> blocks,
    List<Exercise> exercises = const [],
  }) {
    final exerciseById = {
      for (final exercise in exercises) exercise.exerciseId: exercise,
    };

    final ordered = List<SessionBlock>.from(blocks)
      ..sort((a, b) => a.position.compareTo(b.position));

    return SessionExecutionPlan(
      sessionTitle:
          sessionTitle.trim().isEmpty ? 'Session' : sessionTitle.trim(),
      blocks: ordered
          .map(
            (block) => _blockToExecutionBlock(
              block,
              exerciseById: exerciseById,
            ),
          )
          .toList(growable: false),
    );
  }

  SessionExecutionBlock _blockToExecutionBlock(
    SessionBlock block, {
    required Map<String, Exercise> exerciseById,
  }) {
    final summaries = block.linkedExercises
        .map(
          (link) => SessionExecutionExerciseSummary(
            displayName: _displayNameForLink(link, exerciseById),
            exerciseId: link.exerciseId,
          ),
        )
        .toList(growable: false);

    final timer = block.timerConfiguration;
    final timerSummary =
        block.workoutFormat == WorkoutFormat.none || timer == null
            ? null
            : timer.summaryForFormat(block.workoutFormat);

    return SessionExecutionBlock(
      title: block.title.trim().isEmpty
          ? block.blockType.defaultTitle
          : block.title.trim(),
      blockTypeLabel: block.blockType.displayLabel,
      content: block.content,
      workoutFormat: block.workoutFormat,
      timerSummary: timerSummary,
      linkedExerciseSummaries: summaries,
      coachNotes: block.coachNotes?.trim().isEmpty == true
          ? null
          : block.coachNotes?.trim(),
    );
  }

  String _displayNameForLink(
    SessionBlockExerciseLink link,
    Map<String, Exercise> exerciseById,
  ) {
    final override = link.displayLabelOverride?.trim();
    if (override != null && override.isNotEmpty) {
      return override;
    }

    return exerciseById[link.exerciseId]?.name ?? link.exerciseId;
  }
}
