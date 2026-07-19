import 'session_block_exercise_link.dart';
import 'session_block_type.dart';
import 'timer_configuration.dart';
import 'workout_format.dart';

/// Modular ordered unit of Session content (M6).
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

  SessionBlock copyWith({
    String? localId,
    String? persistedId,
    SessionBlockType? blockType,
    String? title,
    String? content,
    WorkoutFormat? workoutFormat,
    TimerConfiguration? timerConfiguration,
    List<SessionBlockExerciseLink>? linkedExercises,
    String? coachNotes,
    int? position,
    bool clearTimerConfiguration = false,
    bool clearCoachNotes = false,
  }) {
    return SessionBlock(
      localId: localId ?? this.localId,
      persistedId: persistedId ?? this.persistedId,
      blockType: blockType ?? this.blockType,
      title: title ?? this.title,
      content: content ?? this.content,
      workoutFormat: workoutFormat ?? this.workoutFormat,
      timerConfiguration: clearTimerConfiguration
          ? null
          : (timerConfiguration ?? this.timerConfiguration),
      linkedExercises: linkedExercises ?? this.linkedExercises,
      coachNotes: clearCoachNotes ? null : (coachNotes ?? this.coachNotes),
      position: position ?? this.position,
    );
  }

  Map<String, dynamic> toRowMap({required String sessionId}) {
    return {
      if (persistedId != null) 'block_id': persistedId,
      'session_id': sessionId,
      'block_type': blockType.dbValue,
      'title': title.trim(),
      'content': content,
      'workout_format': workoutFormat.dbValue,
      'timer_config': timerConfiguration?.toJson(),
      'coach_notes': _nullable(coachNotes),
      'position': position,
    };
  }

  factory SessionBlock.fromRow(
    Map<String, dynamic> row, {
    List<SessionBlockExerciseLink> linkedExercises = const [],
  }) {
    final timerRaw = row['timer_config'];
    TimerConfiguration? timer;
    if (timerRaw is Map<String, dynamic>) {
      timer = TimerConfiguration.fromJson(timerRaw);
    } else if (timerRaw is Map) {
      timer = TimerConfiguration.fromJson(
        Map<String, dynamic>.from(timerRaw),
      );
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

  static SessionBlock create({
    required SessionBlockType blockType,
    required int position,
  }) {
    return SessionBlock(
      localId: 'block-local-${DateTime.now().microsecondsSinceEpoch}-$position',
      blockType: blockType,
      title: blockType.defaultTitle,
      content: '',
      workoutFormat: WorkoutFormat.none,
      position: position,
    );
  }

  SessionBlock deepClone({required int position, String? titleSuffix}) {
    final clonedLinks = linkedExercises
        .asMap()
        .entries
        .map(
          (entry) => SessionBlockExerciseLink(
            localId:
                'link-clone-${DateTime.now().microsecondsSinceEpoch}-${entry.key}',
            exerciseId: entry.value.exerciseId,
            position: entry.value.position,
            displayLabelOverride: entry.value.displayLabelOverride,
          ),
        )
        .toList(growable: false);

    return SessionBlock(
      localId: 'block-clone-${DateTime.now().microsecondsSinceEpoch}-$position',
      blockType: blockType,
      title: titleSuffix == null ? title : '$title$titleSuffix',
      content: content,
      workoutFormat: workoutFormat,
      timerConfiguration: timerConfiguration == null
          ? null
          : TimerConfiguration.fromJson(timerConfiguration!.toJson()),
      linkedExercises: clonedLinks,
      coachNotes: coachNotes,
      position: position,
    );
  }

  bool get hasMeaningfulContent {
    if (content.trim().isNotEmpty) return true;
    if (linkedExercises.isNotEmpty) return true;
    if (workoutFormat != WorkoutFormat.none &&
        timerConfiguration != null &&
        timerConfiguration!.validateForFormat(workoutFormat).isEmpty) {
      return true;
    }
    return false;
  }

  static String? _nullable(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
