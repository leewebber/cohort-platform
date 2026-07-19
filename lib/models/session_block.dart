import 'session_block_exercise_link.dart';
import 'session_block_type.dart';
import 'timer_configuration.dart';
import 'workout_format.dart';

class SessionBlock {
  const SessionBlock({
    required this.localId,
    required this.blockType,
    required this.title,
    required this.content,
    required this.workoutFormat,
    required this.position,
    this.persistedId,
    this.timerConfiguration,
    this.linkedExercises = const [],
    this.coachNotes,
  });

  final String localId;
  final String? persistedId;
  final SessionBlockType blockType;
  final String title;
  final String content;
  final WorkoutFormat workoutFormat;
  final TimerConfiguration? timerConfiguration;
  final List<SessionBlockExerciseLink> linkedExercises;
  final String? coachNotes;
  final int position;

  String get stableId => persistedId ?? 'legacy-$position';

  factory SessionBlock.fromRow(
    Map<String, dynamic> row, {
    List<SessionBlockExerciseLink> linkedExercises = const [],
  }) {
    final timerRaw = row['timer_config'];
    TimerConfiguration? timer;
    if (timerRaw is Map<String, dynamic>) {
      timer = TimerConfiguration.fromJson(timerRaw);
    } else if (timerRaw is Map) {
      timer = TimerConfiguration.fromJson(Map<String, dynamic>.from(timerRaw));
    }

    return SessionBlock(
      localId: 'block-${row['block_id']}',
      persistedId: row['block_id']?.toString(),
      blockType: SessionBlockTypeDb.fromDb(row['block_type']?.toString()),
      title: row['title']?.toString() ?? '',
      content: row['content']?.toString() ?? '',
      workoutFormat: WorkoutFormatDb.fromDb(row['workout_format']?.toString()),
      timerConfiguration: timer,
      linkedExercises: linkedExercises,
      coachNotes: row['coach_notes']?.toString(),
      position: row['position'] as int? ?? 1,
    );
  }

  bool get hasAthleteVisibleContent {
    if (content.trim().isNotEmpty) return true;
    if (linkedExercises.isNotEmpty) return true;
    if (workoutFormat != WorkoutFormat.none &&
        timerConfiguration != null &&
        timerConfiguration!.isValidForFormat(workoutFormat)) {
      return true;
    }
    if (coachNotes?.trim().isNotEmpty == true) return true;
    return false;
  }
}
