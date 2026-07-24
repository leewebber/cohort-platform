import 'package:founder_importer/models/strength_exercise_prescription.dart';

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
  });

  final String localId;
  final String? persistedId;
  final String exerciseId;
  final int position;
  final String? displayLabelOverride;
  final StrengthExercisePrescription? prescription;

  bool get hasStructuredPrescription => prescription?.hasStructuredData == true;

  SessionBlockExerciseLink copyWith({
    String? localId,
    String? persistedId,
    String? exerciseId,
    int? position,
    String? displayLabelOverride,
    StrengthExercisePrescription? prescription,
    bool clearPrescription = false,
    bool clearDisplayLabelOverride = false,
  }) {
    return SessionBlockExerciseLink(
      localId: localId ?? this.localId,
      persistedId: persistedId ?? this.persistedId,
      exerciseId: exerciseId ?? this.exerciseId,
      position: position ?? this.position,
      displayLabelOverride: clearDisplayLabelOverride
          ? null
          : (displayLabelOverride ?? this.displayLabelOverride),
      prescription: clearPrescription ? null : (prescription ?? this.prescription),
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
    );
  }

  SessionBlockExerciseLink duplicateWithNewIdentity() {
    return SessionBlockExerciseLink(
      localId: 'link-${DateTime.now().microsecondsSinceEpoch}',
      exerciseId: exerciseId,
      position: position,
      displayLabelOverride: displayLabelOverride,
      prescription: prescription?.duplicateIdentity(),
    );
  }

  static String? _nullable(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
