import 'strength_exercise_prescription.dart';

/// Athlete- and coach-facing formatting for structured strength prescriptions.
class StrengthPrescriptionFormatter {
  const StrengthPrescriptionFormatter._();

  static String formatSetsReps(StrengthExercisePrescription prescription) {
    final setsLabel = prescription.sets > 0 ? '${prescription.sets}' : '—';
    final repsLabel = formatReps(prescription.reps);
    return '$setsLabel × $repsLabel';
  }

  static String formatReps(StrengthRepPrescription reps) {
    return switch (reps.type) {
      StrengthRepType.exact => reps.exactReps?.toString() ?? '—',
      StrengthRepType.range => '${reps.minReps}–${reps.maxReps}',
      StrengthRepType.duration ||
      StrengthRepType.distance ||
      StrengthRepType.maxEffort ||
      StrengthRepType.freeText =>
        reps.text?.trim().isNotEmpty == true ? reps.text!.trim() : '—',
    };
  }

  static String? formatLoad(StrengthLoadPrescription? load) {
    if (load == null || !load.hasValue) return null;
    return load.toLegacyMetadataValue();
  }

  static String? formatRest(int? restSeconds) {
    if (restSeconds == null || restSeconds <= 0) return null;
    if (restSeconds >= 60 && restSeconds % 60 == 0) {
      final minutes = restSeconds ~/ 60;
      return 'Rest ${minutes}:00';
    }
    return 'Rest ${restSeconds}s';
  }

  static String? formatTempo(String? tempo) {
    final trimmed = tempo?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return 'Tempo $trimmed';
  }

  static String summaryLine(StrengthExercisePrescription prescription) {
    final parts = <String>[
      formatSetsReps(prescription),
      if (formatLoad(prescription.load) case final load?) load,
    ];
    return parts.join(' · ');
  }

  static String detailLine(StrengthExercisePrescription prescription) {
    final parts = <String>[
      if (formatRest(prescription.restSeconds) case final rest?) rest,
      if (formatTempo(prescription.tempo) case final tempo?) tempo,
    ];
    return parts.join(' · ');
  }
}
