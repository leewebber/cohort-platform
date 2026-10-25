import 'strength_exercise_prescription.dart';
import 'timer_configuration.dart';

/// Generic athlete-facing labels for authored station / strength targets.
///
/// Values come from stored prescription fields. This does not invent Apollo
/// copy or coerce calories into repetitions.
class AuthoredStationTargetFormatter {
  const AuthoredStationTargetFormatter._();

  static String? fromTimerSpec(TimerStationSpec spec) {
    if (spec.isRest) return 'Rest';
    final target = spec.workSeconds != null
        ? '${spec.workSeconds} s · recover remainder'
        : spec.calories != null
        ? '${spec.calories} cal'
        : spec.reps != null
        ? '${spec.reps} reps'
        : formatDistance(meters: spec.distanceMeters, text: spec.distanceText);
    final details = spec.authoredDetails;
    if (details?['guidance_semantics'] == 'advisory_only') {
      return '${target ?? ''} · Guidance: ${details!['guidance']}';
    }
    return target;
  }

  static String? formatDistance({double? meters, String? text}) {
    if (meters != null) {
      final whole = meters == meters.roundToDouble();
      final value = whole ? meters.toInt().toString() : meters.toString();
      return '$value m';
    }
    final trimmed = text?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();
    if (lower.endsWith('m') ||
        lower.endsWith('metre') ||
        lower.endsWith('metres') ||
        lower.endsWith('meter') ||
        lower.endsWith('meters')) {
      return trimmed;
    }
    return '$trimmed m';
  }

  static String? nextStationLine({
    required String? label,
    required String? target,
  }) {
    final name = label?.trim();
    if (name == null || name.isEmpty) return null;
    final authored = target?.trim();
    if (authored == null || authored.isEmpty) return 'Next: $name';
    return 'Next: $name · $authored';
  }
}

extension StrengthDistanceDisplay on StrengthExercisePrescription {
  String? get authoredDistanceLabel {
    return AuthoredStationTargetFormatter.formatDistance(
      meters: prescribedDistanceMeters,
      text: prescribedDistanceText,
    );
  }

  bool get hasAuthoredDistance =>
      prescribedDistanceMeters != null ||
      (prescribedDistanceText?.trim().isNotEmpty == true);
}
