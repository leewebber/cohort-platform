import '../models/performance_snapshot.dart';
import '../models/training_session_record.dart';
import '../progression/progression_comparison.dart';
import '../progression/strength_progression.dart';

enum StrengthExerciseComparisonStatus {
  improved,
  maintained,
  belowPrevious,
  mixed,
  baseline,
  notComparable,
  insufficientEvidence;

  String get label => switch (this) {
    StrengthExerciseComparisonStatus.improved => 'Improved',
    StrengthExerciseComparisonStatus.maintained => 'Matched',
    StrengthExerciseComparisonStatus.belowPrevious => 'Below last performance',
    StrengthExerciseComparisonStatus.mixed => 'Mixed',
    StrengthExerciseComparisonStatus.baseline => 'First performance',
    StrengthExerciseComparisonStatus.notComparable => 'Not comparable',
    StrengthExerciseComparisonStatus.insufficientEvidence =>
      'Insufficient evidence',
  };

  String get semanticLabel => switch (this) {
    StrengthExerciseComparisonStatus.improved =>
      'Improved compared with the previous completed session',
    StrengthExerciseComparisonStatus.maintained =>
      'Matched the previous completed session',
    StrengthExerciseComparisonStatus.belowPrevious =>
      'Below last performance',
    StrengthExerciseComparisonStatus.mixed =>
      'Mixed compared with the previous completed session',
    StrengthExerciseComparisonStatus.baseline =>
      'First performance for this exercise',
    StrengthExerciseComparisonStatus.notComparable =>
      'Not comparable with the previous completed session',
    StrengthExerciseComparisonStatus.insufficientEvidence =>
      'Insufficient evidence for a comparison',
  };

  static StrengthExerciseComparisonStatus fromOutcome(ProgressionOutcome outcome) {
    return switch (outcome) {
      ProgressionOutcome.improved => StrengthExerciseComparisonStatus.improved,
      ProgressionOutcome.matched => StrengthExerciseComparisonStatus.maintained,
      ProgressionOutcome.belowLastPerformance =>
        StrengthExerciseComparisonStatus.belowPrevious,
      ProgressionOutcome.mixed => StrengthExerciseComparisonStatus.mixed,
      ProgressionOutcome.firstPerformance =>
        StrengthExerciseComparisonStatus.baseline,
      ProgressionOutcome.notComparable =>
        StrengthExerciseComparisonStatus.notComparable,
      ProgressionOutcome.insufficientEvidence =>
        StrengthExerciseComparisonStatus.insufficientEvidence,
    };
  }
}

class StrengthLoadDisplay {
  const StrengthLoadDisplay._();

  static String? format({
    required double? load,
    required String? loadUnit,
    required StrengthActualLoadKind kind,
  }) {
    if (kind == StrengthActualLoadKind.bodyweight) {
      return 'Bodyweight';
    }
    if (load == null || load == 0) {
      return null;
    }
    final unit = loadUnit?.trim();
    return '${formatNumber(load)}${unit == null || unit.isEmpty ? ' kg' : ' $unit'}';
  }

  static String formatNumber(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
  }

  static String formatQuantity(double value) {
    if (value != value.roundToDouble()) {
      return formatNumber(value);
    }
    final negative = value < 0;
    final digits = value.abs().toInt().toString();
    final grouped = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        grouped.write(',');
      }
      grouped.write(digits[i]);
    }
    return negative ? '-$grouped' : grouped.toString();
  }
}

class StrengthResultComparison {
  const StrengthResultComparison._();

  static const relativeTolerance = 0.01;
  static const absoluteTolerance = 0.5;

  static List<TrainingExerciseResult> authoredExercises(
    TrainingBlockResult block,
  ) {
    final snapshot = List<ExercisePerformanceSnapshot>.from(
      block.blockSnapshot.exercises,
    )..sort((a, b) => a.position.compareTo(b.position));
    if (snapshot.isNotEmpty) {
      final remaining = List<TrainingExerciseResult>.from(block.exerciseResults);
      final ordered = <TrainingExerciseResult>[];
      for (final authored in snapshot) {
        final index = remaining.indexWhere(
          (exercise) => exercise.sourceExerciseId == authored.sourceExerciseId,
        );
        if (index < 0) continue;
        ordered.add(remaining.removeAt(index));
      }
      remaining.sort(_byAuthoredPosition);
      return [...ordered, ...remaining];
    }
    return List<TrainingExerciseResult>.from(block.exerciseResults)
      ..sort(_byAuthoredPosition);
  }

  static List<TrainingSetResult> authoredSets(TrainingExerciseResult exercise) {
    return List<TrainingSetResult>.from(exercise.setResults)
      ..sort((a, b) {
        final byNumber = a.setNumber.compareTo(b.setNumber);
        if (byNumber != 0) return byNumber;
        return a.position.compareTo(b.position);
      });
  }

  static TrainingExerciseResult? previousExercise({
    required String exerciseId,
    required TrainingSessionRecord current,
    required List<TrainingSessionRecord> athleteHistory,
  }) {
    return previousOccurrence(
      exerciseId: exerciseId,
      current: current,
      athleteHistory: athleteHistory,
    )?.exercise;
  }

  static ({TrainingExerciseResult exercise, DateTime completedAt})?
  previousOccurrence({
    required String exerciseId,
    required TrainingSessionRecord current,
    required List<TrainingSessionRecord> athleteHistory,
  }) {
    return StrengthProgressionComparison.previousOccurrence(
      exerciseId: exerciseId,
      current: current,
      athleteHistory: athleteHistory,
    );
  }

  static StrengthExerciseComparisonStatus status({
    required TrainingExerciseResult current,
    required TrainingExerciseResult? previous,
  }) {
    return StrengthExerciseComparisonStatus.fromOutcome(
      compareProgression(current: current, previous: previous).outcome,
    );
  }

  static ProgressionComparison compareProgression({
    required TrainingExerciseResult current,
    required TrainingExerciseResult? previous,
    DateTime? previousPerformedAt,
  }) {
    return StrengthProgressionComparison.compare(
      current: StrengthProgressionFacts.fromExercise(current),
      previous: previous == null
          ? null
          : StrengthProgressionFacts.fromExercise(previous),
      previousPerformedAt: previousPerformedAt,
    );
  }

  static String label({
    required TrainingExerciseResult current,
    required TrainingExerciseResult? previous,
  }) {
    return status(current: current, previous: previous).label;
  }

  static TrainingSetResult? bestCompletedSet(TrainingExerciseResult exercise) {
    return _bestCompletedSet(exercise);
  }

  static String? bestSetValue(TrainingExerciseResult exercise) {
    final best = _bestCompletedSet(exercise);
    if (best == null) return null;
    final load = StrengthLoadDisplay.format(
      load: best.load,
      loadUnit: best.loadUnit,
      kind: exercise.exerciseSnapshot.loadKind,
    );
    if (best.reps != null && load != null) {
      return '${best.reps} × $load';
    }
    if (load != null) return load;
    if (best.reps != null) return '${best.reps} reps';
    return null;
  }

  static String? bestSetLabel(TrainingExerciseResult exercise) {
    final value = bestSetValue(exercise);
    if (value == null) return null;
    final best = _bestCompletedSet(exercise);
    if (best == null) return null;
    return 'Best set ${best.setNumber}: $value';
  }

  static ({double value, String unit})? estimated1RmMetric(
    TrainingExerciseResult exercise,
  ) {
    final metric = _primaryMetric(exercise);
    if (metric == null || metric.kind != _PrimaryMetricKind.estimated1Rm) {
      return null;
    }
    return (value: metric.value, unit: metric.unit);
  }

  static ({double value, String unit})? volumeMetric(
    TrainingExerciseResult exercise,
  ) {
    final volume = _volume(exercise);
    if (volume == null) return null;
    return (value: volume.value, unit: volume.unit);
  }

  static String? estimated1RmLabel(TrainingExerciseResult exercise) {
    final metric = _primaryMetric(exercise);
    if (metric == null || metric.kind != _PrimaryMetricKind.estimated1Rm) {
      return null;
    }
    return 'Est. 1RM ${StrengthLoadDisplay.formatQuantity(metric.value)} ${metric.unit}';
  }

  static String? volumeLabel(TrainingExerciseResult exercise) {
    final volume = _volume(exercise);
    if (volume == null) return null;
    return 'Volume ${StrengthLoadDisplay.formatQuantity(volume.value)} ${volume.unit}';
  }

  static List<String> secondaryDeltas({
    required TrainingExerciseResult current,
    required TrainingExerciseResult? previous,
  }) {
    if (previous == null) return const [];
    return [
      for (final delta in compareProgression(
        current: current,
        previous: previous,
      ).deltas)
        delta.label,
    ];
  }

  static _PrimaryMetric? _primaryMetric(TrainingExerciseResult exercise) {
    final kind = exercise.exerciseSnapshot.loadKind;
    if (kind == StrengthActualLoadKind.bodyweight ||
        kind == StrengthActualLoadKind.none) {
      return null;
    }
    TrainingSetResult? best;
    double? bestEstimate;
    String? unit;
    for (final set in exercise.setResults) {
      if (!set.completed) continue;
      final estimate = estimated1Rm(set);
      if (estimate == null) continue;
      final setUnit = _canonicalUnit(set.loadUnit);
      if (setUnit == null) continue;
      if (bestEstimate == null || estimate > bestEstimate) {
        best = set;
        bestEstimate = estimate;
        unit = setUnit;
      }
    }
    if (best == null || bestEstimate == null || unit == null) return null;
    return _PrimaryMetric(
      kind: _PrimaryMetricKind.estimated1Rm,
      value: bestEstimate,
      unit: unit,
    );
  }

  static double? estimated1Rm(TrainingSetResult set) {
    final load = set.load;
    final reps = set.reps;
    if (!set.completed || load == null || load <= 0 || reps == null || reps <= 0) {
      return null;
    }
    if (reps == 1) return load;
    return load * (1 + (reps / 30));
  }

  static int _byAuthoredPosition(
    TrainingExerciseResult a,
    TrainingExerciseResult b,
  ) {
    final byResult = a.position.compareTo(b.position);
    if (byResult != 0) return byResult;
    return a.exerciseSnapshot.position.compareTo(b.exerciseSnapshot.position);
  }

  static bool _sameUnit(String left, String right) =>
      left.toLowerCase() == right.toLowerCase();

  static String? _canonicalUnit(String? unit) {
    final trimmed = unit?.trim();
    if (trimmed == null || trimmed.isEmpty) return 'kg';
    return trimmed;
  }

  static TrainingSetResult? _bestCompletedSet(TrainingExerciseResult exercise) {
    TrainingSetResult? best;
    double? bestEstimate;
    for (final set in exercise.setResults) {
      if (!set.completed) continue;
      final estimate = estimated1Rm(set);
      if (estimate != null) {
        if (bestEstimate == null || estimate > bestEstimate) {
          best = set;
          bestEstimate = estimate;
        }
        continue;
      }
      if (exercise.exerciseSnapshot.loadKind == StrengthActualLoadKind.bodyweight &&
          set.reps != null) {
        if (best == null || (set.reps ?? 0) > (best.reps ?? 0)) {
          best = set;
        }
      }
    }
    return best;
  }

  static _PrimaryMetric? _volume(TrainingExerciseResult exercise) {
    if (exercise.exerciseSnapshot.loadKind != StrengthActualLoadKind.external) {
      return null;
    }
    var total = 0.0;
    var any = false;
    String? unit;
    for (final set in exercise.setResults) {
      if (!set.completed) continue;
      if (set.load == null || set.load == 0 || set.reps == null) continue;
      final setUnit = _canonicalUnit(set.loadUnit);
      if (setUnit == null) continue;
      if (unit != null && !_sameUnit(unit, setUnit)) return null;
      unit = setUnit;
      any = true;
      total += set.load! * set.reps!;
    }
    if (!any || unit == null) return null;
    return _PrimaryMetric(
      kind: _PrimaryMetricKind.volume,
      value: total,
      unit: unit,
    );
  }
}

enum _PrimaryMetricKind { estimated1Rm, volume }

class _PrimaryMetric {
  const _PrimaryMetric({
    required this.kind,
    required this.value,
    required this.unit,
  });

  final _PrimaryMetricKind kind;
  final double value;
  final String unit;
}
