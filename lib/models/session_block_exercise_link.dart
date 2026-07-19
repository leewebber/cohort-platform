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

  factory SessionBlockExerciseLink.fromRow(Map<String, dynamic> row) {
    return SessionBlockExerciseLink(
      localId: 'link-${row['id']}',
      persistedId: row['id']?.toString(),
      exerciseId: row['exercise_id']?.toString() ?? '',
      position: row['position'] as int? ?? 1,
      displayLabelOverride: row['display_label_override']?.toString(),
    );
  }
}
