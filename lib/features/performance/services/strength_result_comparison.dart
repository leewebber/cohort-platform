import 'dart:math' as math;

import '../models/performance_snapshot.dart';
import '../models/training_session_record.dart';
import '../models/training_session_record_status.dart';

enum StrengthExerciseComparisonStatus {
  improved,
  maintained,
  belowPrevious,
  baseline,
  notComparable;

  String get label => switch (this) {
    StrengthExerciseComparisonStatus.improved => 'Improved',
    StrengthExerciseComparisonStatus.maintained => 'Maintained',
    StrengthExerciseComparisonStatus.belowPrevious => 'Below previous',
    StrengthExerciseComparisonStatus.baseline => 'Baseline',
    StrengthExerciseComparisonStatus.notComparable => 'Not comparable',
  };

  String get semanticLabel => switch (this) {
    StrengthExerciseComparisonStatus.improved =>
      'Improved compared with the previous completed session',
    StrengthExerciseComparisonStatus.maintained =>
      'Maintained compared with the previous completed session',
    StrengthExerciseComparisonStatus.belowPrevious =>
      'Below the previous completed session',
    StrengthExerciseComparisonStatus.baseline =>
      'Baseline — first completed result for this exercise',
    StrengthExerciseComparisonStatus.notComparable =>
      'Not comparable with the previous completed session',
  };
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
    final id = exerciseId.trim();
    if (id.isEmpty) return null;
    final currentAt = current.completedAt ?? current.startedAt;
    TrainingExerciseResult? latest;
    DateTime? latestAt;
    for (final record in athleteHistory) {
      if (record.athleteId != current.athleteId) continue;
      if (record.recordId == current.recordId) continue;
      if (record.status != TrainingSessionRecordStatus.completed) continue;
      final at = record.completedAt ?? record.startedAt;
      if (!at.isBefore(currentAt)) continue;
      for (final block in record.blockResults) {
        for (final exercise in block.exerciseResults) {
          if (exercise.sourceExerciseId != id) continue;
          if (exercise.setResults.isEmpty) continue;
          if (latestAt == null || at.isAfter(latestAt)) {
            latest = exercise;
            latestAt = at;
          }
        }
      }
    }
    return latest;
  }

  static StrengthExerciseComparisonStatus status({
    required TrainingExerciseResult current,
    required TrainingExerciseResult? previous,
  }) {
    if (previous == null) return StrengthExerciseComparisonStatus.baseline;
    final currentMetric = _primaryMetric(current);
    final previousMetric = _primaryMetric(previous);
    if (currentMetric == null || previousMetric == null) {
      return StrengthExerciseComparisonStatus.notComparable;
    }
    if (!_compatible(currentMetric, previousMetric)) {
      return StrengthExerciseComparisonStatus.notComparable;
    }
    final delta = currentMetric.value - previousMetric.value;
    final tolerance = math.max(
      absoluteTolerance,
      previousMetric.value.abs() * relativeTolerance,
    );
    if (delta > tolerance) return StrengthExerciseComparisonStatus.improved;
    if (delta < -tolerance) {
      return StrengthExerciseComparisonStatus.belowPrevious;
    }
    return StrengthExerciseComparisonStatus.maintained;
  }

  static String label({
    required TrainingExerciseResult current,
    required TrainingExerciseResult? previous,
  }) {
    return status(current: current, previous: previous).label;
  }

  static String? bestSetLabel(TrainingExerciseResult exercise) {
    final best = _bestCompletedSet(exercise);
    if (best == null) return null;
    final load = StrengthLoadDisplay.format(
      load: best.load,
      loadUnit: best.loadUnit,
      kind: exercise.exerciseSnapshot.loadKind,
    );
    final reps = best.reps == null ? null : '${best.reps} reps';
    final parts = <String>[?load, ?reps];
    if (parts.isEmpty) return null;
    return 'Best set ${best.setNumber}: ${parts.join(' · ')}';
  }

  static String? estimated1RmLabel(TrainingExerciseResult exercise) {
    final metric = _primaryMetric(exercise);
    if (metric == null || metric.kind != _PrimaryMetricKind.estimated1Rm) {
      return null;
    }
    return 'Est. 1RM ${StrengthLoadDisplay.formatNumber(metric.value)} ${metric.unit}';
  }

  static String? volumeLabel(TrainingExerciseResult exercise) {
    final volume = _volume(exercise);
    if (volume == null) return null;
    return 'Volume ${StrengthLoadDisplay.formatNumber(volume.value)} ${volume.unit}';
  }

  static List<String> secondaryDeltas({
    required TrainingExerciseResult current,
    required TrainingExerciseResult? previous,
  }) {
    if (previous == null) return const [];
    final parts = <String>[];
    final current1Rm = _primaryMetric(current);
    final previous1Rm = _primaryMetric(previous);
    if (current1Rm != null &&
        previous1Rm != null &&
        _compatible(current1Rm, previous1Rm)) {
      final delta = current1Rm.value - previous1Rm.value;
      if (delta != 0) {
        parts.add(
          '${_signed(delta)} ${current1Rm.unit} est. 1RM',
        );
      }
    }
    final currentReps = _totalReps(current);
    final previousReps = _totalReps(previous);
    if (currentReps != null && previousReps != null && currentReps != previousReps) {
      parts.add('${_signedInt(currentReps - previousReps)} reps');
    }
    final currentVolume = _volume(current);
    final previousVolume = _volume(previous);
    if (currentVolume != null &&
        previousVolume != null &&
        _sameUnit(currentVolume.unit, previousVolume.unit) &&
        currentVolume.value != previousVolume.value) {
      parts.add(
        '${_signed(currentVolume.value - previousVolume.value)} ${currentVolume.unit} volume',
      );
    }
    return parts;
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

  static bool _compatible(_PrimaryMetric current, _PrimaryMetric previous) {
    return current.kind == previous.kind && _sameUnit(current.unit, previous.unit);
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

  static int? _totalReps(TrainingExerciseResult exercise) {
    var total = 0;
    var any = false;
    for (final set in exercise.setResults) {
      if (!set.completed || set.reps == null) continue;
      any = true;
      total += set.reps!;
    }
    return any ? total : null;
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

  static String _signed(double value) {
    final formatted = StrengthLoadDisplay.formatNumber(value.abs());
    return value > 0 ? '+$formatted' : '-$formatted';
  }

  static String _signedInt(int value) => value > 0 ? '+$value' : '$value';
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
