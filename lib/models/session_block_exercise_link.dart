/// Reference link from a Session block to a canonical exercise (M6).
class SessionBlockExerciseLink {
  const SessionBlockExerciseLink({
    required this.localId,
    required this.exerciseId,
    required this.position,
    this.persistedId,
    this.displayLabelOverride,
  });

  final String localId;
  final String? persistedId;
  final String exerciseId;
  final int position;
  final String? displayLabelOverride;

  SessionBlockExerciseLink copyWith({
    String? localId,
    String? persistedId,
    String? exerciseId,
    int? position,
    String? displayLabelOverride,
  }) {
    return SessionBlockExerciseLink(
      localId: localId ?? this.localId,
      persistedId: persistedId ?? this.persistedId,
      exerciseId: exerciseId ?? this.exerciseId,
      position: position ?? this.position,
      displayLabelOverride: displayLabelOverride ?? this.displayLabelOverride,
    );
  }

  Map<String, dynamic> toRowMap({required String blockId}) {
    return {
      if (persistedId != null) 'id': persistedId,
      'block_id': blockId,
      'exercise_id': exerciseId,
      'position': position,
      'display_label_override': _nullable(displayLabelOverride),
    };
  }

  factory SessionBlockExerciseLink.fromRow(Map<String, dynamic> row) {
    return SessionBlockExerciseLink(
      localId: 'link-${row['id']}',
      persistedId: row['id']?.toString(),
      exerciseId: row['exercise_id']?.toString() ?? '',
      position: row['position'] as int? ?? 1,
      displayLabelOverride: row['display_label_override']?.toString(),
    );
  }

  static String? _nullable(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
