import '../../../models/session_block_type.dart';
import '../../../models/strength_exercise_prescription.dart';
import '../../../models/workout_format.dart';

/// How an exercise should persist and display load.
enum StrengthActualLoadKind {
  external,
  bodyweight,
  none;

  String get dbValue => name;

  static StrengthActualLoadKind fromDb(String? value) {
    return switch (value) {
      'external' => StrengthActualLoadKind.external,
      'bodyweight' => StrengthActualLoadKind.bodyweight,
      'none' => StrengthActualLoadKind.none,
      _ => StrengthActualLoadKind.none,
    };
  }

  static StrengthActualLoadKind fromPrescription({
    required SessionBlockType blockType,
    StrengthExercisePrescription? prescription,
  }) {
    final load = prescription?.load;
    if (load?.type == StrengthLoadType.bodyweight) {
      return StrengthActualLoadKind.bodyweight;
    }
    if (load?.type == StrengthLoadType.fixedKg ||
        load?.type == StrengthLoadType.percent1rm ||
        load?.type == StrengthLoadType.athleteSelected ||
        load?.type == StrengthLoadType.rpe ||
        load?.type == StrengthLoadType.rir) {
      return StrengthActualLoadKind.external;
    }
    final capture = prescription?.performanceCapture;
    if (capture?.loadUnit?.trim().isNotEmpty == true ||
        capture?.loadLabel?.trim().isNotEmpty == true) {
      return StrengthActualLoadKind.external;
    }
    if (blockType == SessionBlockType.strength ||
        blockType == SessionBlockType.accessory) {
      return load == null
          ? StrengthActualLoadKind.external
          : StrengthActualLoadKind.none;
    }
    return StrengthActualLoadKind.none;
  }

  bool get expectsExternalLoad => this == StrengthActualLoadKind.external;
}

class ExercisePerformanceSnapshot {
  const ExercisePerformanceSnapshot({
    required this.sourceExerciseId,
    required this.displayName,
    required this.position,
    this.labelOverride,
    this.loadKind = StrengthActualLoadKind.none,
  });

  final String sourceExerciseId;
  final String displayName;
  final int position;
  final String? labelOverride;
  final StrengthActualLoadKind loadKind;

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'sourceExerciseId': sourceExerciseId,
    'displayName': displayName,
    'position': position,
    if (labelOverride != null) 'labelOverride': labelOverride,
    'loadKind': loadKind.dbValue,
  };

  factory ExercisePerformanceSnapshot.fromJson(Map<String, dynamic> json) {
    return ExercisePerformanceSnapshot(
      sourceExerciseId: json['sourceExerciseId']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      position: json['position'] is int
          ? json['position'] as int
          : int.tryParse(json['position']?.toString() ?? '') ?? 0,
      labelOverride: _trim(json['labelOverride']),
      loadKind: StrengthActualLoadKind.fromDb(json['loadKind']?.toString()),
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
    this.performanceCaptureMode,
    this.workSeconds,
    this.recoverySeconds,
    this.tracking = const [],
    this.comparisonFamily,
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
  final String? performanceCaptureMode;
  final int? workSeconds;
  final int? recoverySeconds;
  final List<String> tracking;
  final String? comparisonFamily;

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
    if (performanceCaptureMode != null)
      'performanceCaptureMode': performanceCaptureMode,
    if (workSeconds != null) 'workSeconds': workSeconds,
    if (recoverySeconds != null) 'recoverySeconds': recoverySeconds,
    if (tracking.isNotEmpty) 'tracking': tracking,
    if (comparisonFamily != null) 'comparisonFamily': comparisonFamily,
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
      performanceCaptureMode: _trim(json['performanceCaptureMode']),
      workSeconds: _int(json['workSeconds'] ?? json['work_seconds']),
      recoverySeconds: _int(
        json['recoverySeconds'] ??
            json['recovery_seconds'] ??
            json['restSeconds'],
      ),
      tracking: _stringList(json['tracking']),
      comparisonFamily: _trim(json['comparisonFamily']),
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

  static int? _int(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
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
