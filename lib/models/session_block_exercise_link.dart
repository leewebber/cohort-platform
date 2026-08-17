import 'strength_exercise_prescription.dart';

/// Reference link from a Session block to a canonical exercise (M6).
///
/// When [prescription] is present the link carries structured strength programming
/// (Sprint 10). Links without a prescription remain legacy reference-only links.
class SessionBlockExerciseLink {
  const SessionBlockExerciseLink({
    required this.localId,
    required this.exerciseId,
    required this.position,
    this.persistedId,
    this.displayLabelOverride,
    this.prescription,
    this.executionGroupKey,
    this.executionGroupLabel,
    this.executionGroupRounds,
  });

  final String localId;
  final String? persistedId;
  final String exerciseId;
  final int position;
  final String? displayLabelOverride;
  final StrengthExercisePrescription? prescription;
  final String? executionGroupKey;
  final String? executionGroupLabel;
  final int? executionGroupRounds;

  bool get hasStructuredPrescription => prescription?.hasStructuredData == true;
  bool get hasExecutionGroup =>
      executionGroupKey != null &&
      executionGroupLabel != null &&
      executionGroupRounds != null;

  SessionBlockExerciseLink copyWith({
    String? localId,
    String? persistedId,
    String? exerciseId,
    int? position,
    String? displayLabelOverride,
    StrengthExercisePrescription? prescription,
    String? executionGroupKey,
    String? executionGroupLabel,
    int? executionGroupRounds,
    bool clearPrescription = false,
    bool clearDisplayLabelOverride = false,
    bool clearExecutionGroup = false,
  }) {
    return SessionBlockExerciseLink(
      localId: localId ?? this.localId,
      persistedId: persistedId ?? this.persistedId,
      exerciseId: exerciseId ?? this.exerciseId,
      position: position ?? this.position,
      displayLabelOverride: clearDisplayLabelOverride
          ? null
          : (displayLabelOverride ?? this.displayLabelOverride),
      prescription: clearPrescription
          ? null
          : (prescription ?? this.prescription),
      executionGroupKey: clearExecutionGroup
          ? null
          : (executionGroupKey ?? this.executionGroupKey),
      executionGroupLabel: clearExecutionGroup
          ? null
          : (executionGroupLabel ?? this.executionGroupLabel),
      executionGroupRounds: clearExecutionGroup
          ? null
          : (executionGroupRounds ?? this.executionGroupRounds),
    );
  }

  Map<String, dynamic> toRowMap({required String blockId}) {
    return {
      if (persistedId != null) 'id': persistedId,
      'block_id': blockId,
      'exercise_id': exerciseId,
      'position': position,
      'display_label_override': _nullable(displayLabelOverride),
      if (prescription != null && prescription!.hasStructuredData)
        'prescription': prescription!.toJson(),
      'execution_group_key': _nullable(executionGroupKey),
      'execution_group_label': _nullable(executionGroupLabel),
      'execution_group_rounds': executionGroupRounds,
    };
  }

  factory SessionBlockExerciseLink.fromRow(Map<String, dynamic> row) {
    final prescriptionRaw = row['prescription'];
    StrengthExercisePrescription? prescription;
    if (prescriptionRaw is Map<String, dynamic>) {
      prescription = StrengthExercisePrescription.fromJson(prescriptionRaw);
    } else if (prescriptionRaw is Map) {
      prescription = StrengthExercisePrescription.fromJson(
        Map<String, dynamic>.from(prescriptionRaw),
      );
    }

    return SessionBlockExerciseLink(
      localId: 'link-${row['id']}',
      persistedId: row['id']?.toString(),
      exerciseId: row['exercise_id']?.toString() ?? '',
      position: row['position'] as int? ?? 1,
      displayLabelOverride: row['display_label_override']?.toString(),
      prescription: prescription,
      executionGroupKey: _nullable(row['execution_group_key']?.toString()),
      executionGroupLabel: _nullable(row['execution_group_label']?.toString()),
      executionGroupRounds: row['execution_group_rounds'] as int?,
    );
  }

  SessionBlockExerciseLink duplicateWithNewIdentity() {
    return SessionBlockExerciseLink(
      localId: 'link-${DateTime.now().microsecondsSinceEpoch}',
      exerciseId: exerciseId,
      position: position,
      displayLabelOverride: displayLabelOverride,
      prescription: prescription?.duplicateIdentity(),
      executionGroupKey: executionGroupKey,
      executionGroupLabel: executionGroupLabel,
      executionGroupRounds: executionGroupRounds,
    );
  }

  static String? _nullable(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
