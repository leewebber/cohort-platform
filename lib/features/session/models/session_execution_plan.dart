import '../../../models/block_performance_capture_mode.dart';
import '../../../models/exercise.dart';
import '../../../models/protocol.dart';
import '../../../models/session_block.dart';
import '../../../models/session_block_exercise_link.dart';
import '../../../models/strength_exercise_prescription.dart';
import '../services/athlete_exercise_label_resolver.dart';
import '../../../models/session_block_type.dart';
import '../../../models/timer_configuration.dart';
import '../../../models/workout_format.dart';

class SessionExecutionExerciseSummary {
  const SessionExecutionExerciseSummary({
    required this.exerciseId,
    required this.displayName,
    this.displayLabelOverride,
    this.exercise,
    this.prescription,
  });

  final String exerciseId;
  final String displayName;
  final String? displayLabelOverride;
  final Exercise? exercise;
  final StrengthExercisePrescription? prescription;

  /// Athlete-facing label with resolver fallbacks.
  String get athleteLabel =>
      AthleteExerciseLabelResolver.fromExecutionSummary(this);
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
    this.performanceCaptureMode = BlockPerformanceCaptureMode.automatic,
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
  final BlockPerformanceCaptureMode performanceCaptureMode;

  String get blockTypeLabel => blockType.displayLabel;
  String? get workoutFormatLabel =>
      workoutFormat == WorkoutFormat.none ? null : workoutFormat.displayLabel;

  bool get hasTimer =>
      workoutFormat.supportsTimer &&
      timerConfiguration != null &&
      timerConfiguration!.isValidForFormat(workoutFormat);

  bool get hasAthleteVisibleContent {
    if (content.trim().isNotEmpty) return true;
    if (linkedExercises.any((exercise) => exercise.prescription?.hasStructuredData == true)) {
      return true;
    }
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
            displayLabelOverride: link.displayLabelOverride,
            exercise: exercisesById[link.exerciseId],
            prescription: link.prescription,
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
      performanceCaptureMode: block.performanceCaptureMode,
    );
  }

  static String _displayName(
    SessionBlockExerciseLink link,
    Map<String, Exercise> exercisesById,
  ) {
    return AthleteExerciseLabelResolver.fromExerciseLink(
      link: link,
      exercise: exercisesById[link.exerciseId],
    );
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
    this.prescriptionLoadOverrides = const {},
  });

  final String sessionId;
  final String sessionTitle;
  final List<SessionExecutionBlock> blocks;
  final Protocol? protocol;
  final int? durationMin;
  final String? coachNotes;
  final String? programmeContextLabel;
  final Map<String, String> prescriptionLoadOverrides;

  bool get hasExecutableBlocks =>
      blocks.any((block) => block.hasAthleteVisibleContent);

  int get blockCount => blocks.length;
}
