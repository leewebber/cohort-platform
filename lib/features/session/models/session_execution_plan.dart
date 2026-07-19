import '../../../models/exercise.dart';
import '../../../models/protocol.dart';
import '../../../models/session_block.dart';
import '../../../models/session_block_exercise_link.dart';
import '../../../models/session_block_type.dart';
import '../../../models/timer_configuration.dart';
import '../../../models/workout_format.dart';

class SessionExecutionExerciseSummary {
  const SessionExecutionExerciseSummary({
    required this.exerciseId,
    required this.displayName,
    this.exercise,
  });

  final String exerciseId;
  final String displayName;
  final Exercise? exercise;
}

class SessionExecutionBlock {
  const SessionExecutionBlock({
    required this.blockId,
    required this.title,
    required this.blockType,
    required this.content,
    required this.workoutFormat,
    required this.position,
    this.timerConfiguration,
    this.timerSummary,
    this.linkedExercises = const [],
    this.coachNotes,
  });

  final String blockId;
  final String title;
  final SessionBlockType blockType;
  final String content;
  final WorkoutFormat workoutFormat;
  final int position;
  final TimerConfiguration? timerConfiguration;
  final String? timerSummary;
  final List<SessionExecutionExerciseSummary> linkedExercises;
  final String? coachNotes;

  String get blockTypeLabel => blockType.displayLabel;
  String? get workoutFormatLabel =>
      workoutFormat == WorkoutFormat.none ? null : workoutFormat.displayLabel;

  bool get hasTimer =>
      workoutFormat.supportsTimer &&
      timerConfiguration != null &&
      timerConfiguration!.isValidForFormat(workoutFormat);

  bool get hasAthleteVisibleContent {
    if (content.trim().isNotEmpty) return true;
    if (linkedExercises.isNotEmpty) return true;
    if (hasTimer) return true;
    if (coachNotes?.trim().isNotEmpty == true) return true;
    return false;
  }

  factory SessionExecutionBlock.fromSessionBlock(
    SessionBlock block, {
    required Map<String, Exercise> exercisesById,
  }) {
    final timer = block.timerConfiguration;
    final summaries = block.linkedExercises
        .map(
          (link) => SessionExecutionExerciseSummary(
            exerciseId: link.exerciseId,
            displayName: _displayName(link, exercisesById),
            exercise: exercisesById[link.exerciseId],
          ),
        )
        .toList(growable: false);

    return SessionExecutionBlock(
      blockId: block.stableId,
      title: block.title.trim().isEmpty ? block.blockType.defaultTitle : block.title.trim(),
      blockType: block.blockType,
      content: block.content,
      workoutFormat: block.workoutFormat,
      position: block.position,
      timerConfiguration: timer,
      timerSummary: timer == null || block.workoutFormat == WorkoutFormat.none
          ? null
          : timer.summaryForFormat(block.workoutFormat),
      linkedExercises: summaries,
      coachNotes: block.coachNotes?.trim().isEmpty == true
          ? null
          : block.coachNotes?.trim(),
    );
  }

  static String _displayName(
    SessionBlockExerciseLink link,
    Map<String, Exercise> exercisesById,
  ) {
    final override = link.displayLabelOverride?.trim();
    if (override != null && override.isNotEmpty) return override;
    return exercisesById[link.exerciseId]?.name ?? link.exerciseId;
  }
}

class SessionExecutionPlan {
  const SessionExecutionPlan({
    required this.sessionId,
    required this.sessionTitle,
    required this.blocks,
    this.protocol,
    this.durationMin,
    this.coachNotes,
    this.programmeContextLabel,
  });

  final String sessionId;
  final String sessionTitle;
  final List<SessionExecutionBlock> blocks;
  final Protocol? protocol;
  final int? durationMin;
  final String? coachNotes;
  final String? programmeContextLabel;

  bool get hasExecutableBlocks =>
      blocks.any((block) => block.hasAthleteVisibleContent);

  int get blockCount => blocks.length;
}
