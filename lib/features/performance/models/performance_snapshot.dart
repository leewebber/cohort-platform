import '../../../models/session_block_type.dart';
import '../../../models/workout_format.dart';

class ExercisePerformanceSnapshot {
  const ExercisePerformanceSnapshot({
    required this.sourceExerciseId,
    required this.displayName,
    required this.position,
    this.labelOverride,
  });

  final String sourceExerciseId;
  final String displayName;
  final int position;
  final String? labelOverride;

  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'sourceExerciseId': sourceExerciseId,
        'displayName': displayName,
        'position': position,
        if (labelOverride != null) 'labelOverride': labelOverride,
      };

  factory ExercisePerformanceSnapshot.fromJson(Map<String, dynamic> json) {
    return ExercisePerformanceSnapshot(
      sourceExerciseId: json['sourceExerciseId']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      position: json['position'] is int
          ? json['position'] as int
          : int.tryParse(json['position']?.toString() ?? '') ?? 0,
      labelOverride: _trim(json['labelOverride']),
    );
  }

  static String? _trim(dynamic value) {
    final trimmed = value?.toString().trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

class BlockPerformanceSnapshot {
  const BlockPerformanceSnapshot({
    required this.sourceBlockId,
    required this.title,
    required this.blockType,
    required this.content,
    required this.workoutFormat,
    required this.position,
    this.timerSummary,
    this.coachNotes,
    this.exercises = const [],
  });

  final String sourceBlockId;
  final String title;
  final SessionBlockType blockType;
  final String content;
  final WorkoutFormat workoutFormat;
  final int position;
  final String? timerSummary;
  final String? coachNotes;
  final List<ExercisePerformanceSnapshot> exercises;

  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'sourceBlockId': sourceBlockId,
        'title': title,
        'blockType': blockType.dbValue,
        'content': content,
        'workoutFormat': workoutFormat.dbValue,
        'position': position,
        if (timerSummary != null) 'timerSummary': timerSummary,
        if (coachNotes != null) 'coachNotes': coachNotes,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  factory BlockPerformanceSnapshot.fromJson(Map<String, dynamic> json) {
    final exercisesJson = json['exercises'];
    return BlockPerformanceSnapshot(
      sourceBlockId: json['sourceBlockId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      blockType: SessionBlockTypeDb.fromDb(json['blockType']?.toString()),
      content: json['content']?.toString() ?? '',
      workoutFormat: WorkoutFormatDb.fromDb(json['workoutFormat']?.toString()),
      position: json['position'] is int
          ? json['position'] as int
          : int.tryParse(json['position']?.toString() ?? '') ?? 0,
      timerSummary: _trim(json['timerSummary']),
      coachNotes: _trim(json['coachNotes']),
      exercises: exercisesJson is List
          ? exercisesJson
              .whereType<Map>()
              .map(
                (item) => ExercisePerformanceSnapshot.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
          : const [],
    );
  }

  static String? _trim(dynamic value) {
    final trimmed = value?.toString().trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

class SessionPerformanceSnapshot {
  const SessionPerformanceSnapshot({
    required this.sourceProtocolId,
    required this.sessionTitle,
    this.sessionDescription,
    this.programmeTitle,
    this.programmeContextLabel,
    this.coachDisplayName,
    this.assignmentId,
    this.programmeId,
    this.programmeSessionId,
    this.lineageCode,
    this.blocks = const [],
  });

  final String sourceProtocolId;
  final String sessionTitle;
  final String? sessionDescription;
  final String? programmeTitle;
  final String? programmeContextLabel;
  final String? coachDisplayName;
  final String? assignmentId;
  final String? programmeId;
  final String? programmeSessionId;
  final String? lineageCode;
  final List<BlockPerformanceSnapshot> blocks;

  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'sourceProtocolId': sourceProtocolId,
        'sessionTitle': sessionTitle,
        if (sessionDescription != null) 'sessionDescription': sessionDescription,
        if (programmeTitle != null) 'programmeTitle': programmeTitle,
        if (programmeContextLabel != null)
          'programmeContextLabel': programmeContextLabel,
        if (coachDisplayName != null) 'coachDisplayName': coachDisplayName,
        if (assignmentId != null) 'assignmentId': assignmentId,
        if (programmeId != null) 'programmeId': programmeId,
        if (programmeSessionId != null) 'programmeSessionId': programmeSessionId,
        if (lineageCode != null) 'lineageCode': lineageCode,
        'blocks': blocks.map((b) => b.toJson()).toList(),
      };

  factory SessionPerformanceSnapshot.fromJson(Map<String, dynamic> json) {
    final blocksJson = json['blocks'];
    return SessionPerformanceSnapshot(
      sourceProtocolId: json['sourceProtocolId']?.toString() ?? '',
      sessionTitle: json['sessionTitle']?.toString() ?? '',
      sessionDescription: _trim(json['sessionDescription']),
      programmeTitle: _trim(json['programmeTitle']),
      programmeContextLabel: _trim(json['programmeContextLabel']),
      coachDisplayName: _trim(json['coachDisplayName']),
      assignmentId: _trim(json['assignmentId']),
      programmeId: _trim(json['programmeId']),
      programmeSessionId: _trim(json['programmeSessionId']),
      lineageCode: _trim(json['lineageCode']),
      blocks: blocksJson is List
          ? blocksJson
              .whereType<Map>()
              .map(
                (item) => BlockPerformanceSnapshot.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
          : const [],
    );
  }

  static String? _trim(dynamic value) {
    final trimmed = value?.toString().trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
