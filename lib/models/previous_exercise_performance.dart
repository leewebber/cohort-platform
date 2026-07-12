import 'strength_set_performance.dart';

/// A single performed set line from a previous completed session.
class PreviousPerformedSet {
  const PreviousPerformedSet({
    required this.loadLabel,
    required this.reps,
    required this.displayLine,
    this.rpe,
  });

  final String? loadLabel;
  final String? reps;
  final String displayLine;
  final double? rpe;

  factory PreviousPerformedSet.fromPerformance(StrengthSetPerformance performance) {
    final loadLabel = _formatLoad(
      performance.loadValue,
      performance.loadUnit,
    );
    final reps = _nullableString(performance.actualReps) ??
        _nullableString(performance.targetReps);

    return PreviousPerformedSet(
      loadLabel: loadLabel,
      reps: reps,
      displayLine: _formatDisplayLine(loadLabel: loadLabel, reps: reps),
      rpe: performance.rpe?.toDouble(),
    );
  }

  static String _formatDisplayLine({
    required String? loadLabel,
    required String? reps,
  }) {
    if (loadLabel != null && reps != null) {
      return '$loadLabel × $reps';
    }

    if (loadLabel != null) {
      return loadLabel;
    }

    if (reps != null) {
      return '$reps reps';
    }

    return '—';
  }

  static String? _formatLoad(double? value, String? unit) {
    if (value == null) {
      return null;
    }

    final normalizedUnit = unit?.trim().toLowerCase();
    final formattedValue = _trimTrailingZero(value);

    if (normalizedUnit == null || normalizedUnit.isEmpty) {
      return formattedValue;
    }

    if (normalizedUnit == 'kg' || normalizedUnit == 'lb') {
      return '$formattedValue$normalizedUnit';
    }

    return '$formattedValue $normalizedUnit';
  }

  static String _trimTrailingZero(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toString();
  }

  static String? _nullableString(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }
}

/// Latest completed performance snapshot for one exercise.
class PreviousExercisePerformance {
  const PreviousExercisePerformance({
    required this.sets,
    required this.performedAt,
  });

  final List<PreviousPerformedSet> sets;
  final DateTime? performedAt;

  bool get hasHistory => sets.isNotEmpty;
}
