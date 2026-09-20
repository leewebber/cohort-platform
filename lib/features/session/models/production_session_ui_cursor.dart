/// Versioned production UI cursor. Never changes athletic result semantics.
class ProductionSessionUiCursor {
  const ProductionSessionUiCursor({
    required this.schemaVersion,
    required this.athleteId,
    required this.assignmentId,
    required this.trainingSessionId,
    this.occurrenceId,
    this.activeBlockId,
    this.activeBlockIndex,
    this.activeExerciseId,
    this.activeExerciseIndex,
    this.activeIntervalId,
    this.expandedBlockIds = const {},
    this.capturePage,
    this.savedAt,
  });

  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final String athleteId;
  final String assignmentId;
  final int trainingSessionId;
  final String? occurrenceId;
  final String? activeBlockId;
  final int? activeBlockIndex;
  final String? activeExerciseId;
  final int? activeExerciseIndex;
  final String? activeIntervalId;
  final Set<String> expandedBlockIds;
  final String? capturePage;
  final DateTime? savedAt;

  bool get isUnsupportedFutureVersion =>
      schemaVersion > currentSchemaVersion;

  Map<String, dynamic> toJson() {
    return {
      'schema_version': schemaVersion,
      'athlete_id': athleteId,
      'assignment_id': assignmentId,
      'training_session_id': trainingSessionId,
      if (occurrenceId != null) 'occurrence_id': occurrenceId,
      if (activeBlockId != null) 'active_block_id': activeBlockId,
      if (activeBlockIndex != null) 'active_block_index': activeBlockIndex,
      if (activeExerciseId != null) 'active_exercise_id': activeExerciseId,
      if (activeExerciseIndex != null)
        'active_exercise_index': activeExerciseIndex,
      if (activeIntervalId != null) 'active_interval_id': activeIntervalId,
      'expanded_block_ids': expandedBlockIds.toList()..sort(),
      if (capturePage != null) 'capture_page': capturePage,
      if (savedAt != null) 'saved_at': savedAt!.toUtc().toIso8601String(),
    };
  }

  factory ProductionSessionUiCursor.fromJson(Map<String, dynamic> json) {
    final expandedRaw = json['expanded_block_ids'];
    return ProductionSessionUiCursor(
      schemaVersion: json['schema_version'] as int? ?? 0,
      athleteId: json['athlete_id'] as String? ?? '',
      assignmentId: json['assignment_id'] as String? ?? '',
      trainingSessionId: json['training_session_id'] as int? ?? 0,
      occurrenceId: json['occurrence_id'] as String?,
      activeBlockId: json['active_block_id'] as String?,
      activeBlockIndex: json['active_block_index'] as int?,
      activeExerciseId: json['active_exercise_id'] as String?,
      activeExerciseIndex: json['active_exercise_index'] as int?,
      activeIntervalId: json['active_interval_id'] as String?,
      expandedBlockIds: expandedRaw is List
          ? expandedRaw.map((e) => e.toString()).toSet()
          : const {},
      capturePage: json['capture_page'] as String?,
      savedAt: DateTime.tryParse(json['saved_at'] as String? ?? ''),
    );
  }
}
