import '../core/presentation/athlete_duration_formatter.dart';
import 'authored_station_target_formatter.dart';
import 'strength_exercise_prescription.dart';

/// Athlete- and coach-facing formatting for structured strength prescriptions.
class StrengthPrescriptionFormatter {
  const StrengthPrescriptionFormatter._();

  static String formatSetsReps(StrengthExercisePrescription prescription) {
    final setsLabel = prescription.sets > 0 ? '${prescription.sets}' : '—';
    final distance = prescription.authoredDistanceLabel;
    if (distance != null) {
      return '$setsLabel × $distance';
    }
    final repsLabel =
        '${formatReps(prescription.reps)}'
        '${prescription.perSide ? ' / side' : ''}';
    return '$setsLabel × $repsLabel';
  }

  /// Compact collapsed-card volume from the authored prescription.
  ///
  /// V1 prescriptions are uniform across sets. When dosage is missing, this
  /// returns a truthful set-count label instead of a fabricated shorthand.
  static String collapsedVolumeLine(
    StrengthExercisePrescription? prescription,
  ) {
    if (prescription == null || prescription.sets <= 0) {
      return 'Prescribed sets';
    }
    final hasDose =
        prescription.authoredDistanceLabel != null ||
        prescription.reps.hasValue;
    if (!hasDose) {
      final count = prescription.sets;
      return '$count prescribed set${count == 1 ? '' : 's'}';
    }
    return formatSetsReps(prescription);
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
    return 'Rest ${AthleteDurationFormatter.formatSeconds(restSeconds)}';
  }

  static String? formatTempo(String? tempo) {
    final trimmed = tempo?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return 'Tempo $trimmed';
  }

  static String summaryLine(StrengthExercisePrescription prescription) {
    final parts = <String>[
      formatSetsReps(prescription),
      ?formatLoad(prescription.load),
    ];
    return parts.join(' · ');
  }

  static String detailLine(StrengthExercisePrescription prescription) {
    final parts = <String>[
      ?formatRest(prescription.restSeconds),
      ?formatTempo(prescription.tempo),
    ];
    return parts.join(' · ');
  }
}
