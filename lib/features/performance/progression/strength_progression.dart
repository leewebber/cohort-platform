import '../models/performance_snapshot.dart';
import '../models/training_session_record.dart';
import '../services/strength_result_comparison.dart';
import 'eligible_performance_evidence.dart';
import 'progression_comparison.dart';

class StrengthProgressionFacts {
  const StrengthProgressionFacts({
    required this.exerciseId,
    required this.loadKind,
    required this.sets,
    this.prescribedSetCount,
  });

  final String exerciseId;
  final StrengthActualLoadKind loadKind;
  final List<TrainingSetResult> sets;
  final int? prescribedSetCount;

  factory StrengthProgressionFacts.fromExercise(
    TrainingExerciseResult exercise, {
    int? prescribedSetCount,
  }) {
    return StrengthProgressionFacts(
      exerciseId: exercise.sourceExerciseId.trim(),
      loadKind: exercise.exerciseSnapshot.loadKind,
      sets: EligiblePerformanceEvidence.completedActualSets(exercise),
      prescribedSetCount: prescribedSetCount ?? exercise.setResults.length,
    );
  }

  TrainingSetResult? get topSet {
    TrainingSetResult? best;
    for (final set in sets) {
      if (best == null) {
        best = set;
        continue;
      }
      final bestLoad = best.load ?? 0;
      final load = set.load ?? 0;
      if (load > bestLoad) {
        best = set;
        continue;
      }
      if (load == bestLoad && (set.reps ?? 0) > (best.reps ?? 0)) {
        best = set;
      }
    }
    return best;
  }

  double? get volume {
    if (loadKind != StrengthActualLoadKind.external) return null;
    var total = 0.0;
    var any = false;
    for (final set in sets) {
      if (set.load == null || set.load == 0 || set.reps == null) continue;
      any = true;
      total += set.load! * set.reps!;
    }
    return any ? total : null;
  }

  int? get completedSetCount => sets.isEmpty ? null : sets.length;

  int? rpeFor(TrainingSetResult? set) => set?.rpe;
}

abstract final class StrengthProgressionComparison {
  static const relativeTolerance = StrengthResultComparison.relativeTolerance;
  static const absoluteTolerance = StrengthResultComparison.absoluteTolerance;

  static ProgressionComparison compare({
    required StrengthProgressionFacts current,
    StrengthProgressionFacts? previous,
    DateTime? previousPerformedAt,
  }) {
    if (current.exerciseId.isEmpty) return ProgressionComparison.insufficient;
    if (previous == null || previous.sets.isEmpty) {
      return ProgressionComparison.first;
    }
    if (current.exerciseId != previous.exerciseId) {
      return ProgressionComparison.notComparable;
    }
    if (current.loadKind != previous.loadKind) {
      return ProgressionComparison.notComparable;
    }
    if (current.sets.isEmpty) return ProgressionComparison.insufficient;

    final currentTop = current.topSet;
    final previousTop = previous.topSet;
    if (currentTop == null || previousTop == null) {
      return ProgressionComparison.insufficient;
    }

    final prescriptionChanged = _prescriptionChanged(current, previous);
    final loadDelta = _delta(currentTop.load, previousTop.load);
    final repsDelta = _intDelta(currentTop.reps, previousTop.reps);
    final volumeDelta = _delta(current.volume, previous.volume);
    final rpeDelta = _intDelta(currentTop.rpe, previousTop.rpe);
    final extraSetsPrescribed = _extraSetsFromPrescription(current, previous);
    final extraSetsCompleted =
        (current.completedSetCount ?? 0) > (previous.completedSetCount ?? 0);

    final deltas = <MetricDelta>[
      if (loadDelta != null && loadDelta != 0)
        MetricDelta(
          key: 'load',
          label: '${_signed(loadDelta)} kg at ${currentTop.reps ?? previousTop.reps} reps',
        ),
      if (loadDelta == 0 && repsDelta != null && repsDelta != 0)
        MetricDelta(
          key: 'reps',
          label: _moreRepsLabel(repsDelta),
        ),
      if (rpeDelta != null && rpeDelta != 0 && loadDelta == 0 && repsDelta == 0)
        MetricDelta(
          key: 'rpe',
          label:
              'Same result at RPE ${currentTop.rpe} vs ${previousTop.rpe}',
        ),
      if (extraSetsPrescribed)
        const MetricDelta(
          key: 'prescription',
          label: 'Prescription changed — comparison limited',
        ),
    ];

    final loadImproved = loadDelta != null && loadDelta > _tolerance(previousTop.load);
    final loadBelow = loadDelta != null && loadDelta < -_tolerance(previousTop.load);
    final loadSame = loadDelta == null
        ? currentTop.load == previousTop.load
        : loadDelta.abs() <= _tolerance(previousTop.load);
    final repsImproved = repsDelta != null && repsDelta > 0;
    final repsBelow = repsDelta != null && repsDelta < 0;
    final repsSame = repsDelta == 0 || (currentTop.reps == previousTop.reps);
    final rpeLower = rpeDelta != null && rpeDelta <= -1;
    final rpeHigher = rpeDelta != null && rpeDelta >= 2;
    final volumeUp = volumeDelta != null && volumeDelta > 0;
    final topWeaker = loadBelow || (loadSame && repsBelow);

    if (current.loadKind != StrengthActualLoadKind.external) {
      if (repsSame && !repsImproved && !repsBelow) {
        return ProgressionComparison(
          outcome: ProgressionOutcome.matched,
          confidence: EvidenceConfidence.moderate,
          summary: 'Matched last performance',
          deltas: deltas,
          previousPerformedAt: previousPerformedAt,
          comparisonKey: current.exerciseId,
        );
      }
      if (repsImproved && !rpeHigher) {
        return ProgressionComparison(
          outcome: ProgressionOutcome.improved,
          confidence: EvidenceConfidence.moderate,
          summary: '+$repsDelta reps at bodyweight',
          deltas: deltas,
          previousPerformedAt: previousPerformedAt,
          comparisonKey: current.exerciseId,
        );
      }
      if (repsBelow) {
        return ProgressionComparison(
          outcome: ProgressionOutcome.belowLastPerformance,
          confidence: EvidenceConfidence.moderate,
          summary: 'Below last performance',
          deltas: deltas,
          previousPerformedAt: previousPerformedAt,
          comparisonKey: current.exerciseId,
        );
      }
      return ProgressionComparison.notComparable;
    }

    if (current.loadKind == StrengthActualLoadKind.external &&
        (currentTop.load == null ||
            currentTop.load == 0 ||
            previousTop.load == null ||
            previousTop.load == 0)) {
      return ProgressionComparison.notComparable;
    }

    if (loadImproved && (repsSame || repsImproved) && !rpeHigher) {
      return ProgressionComparison(
        outcome: ProgressionOutcome.improved,
        confidence: prescriptionChanged
            ? EvidenceConfidence.moderate
            : EvidenceConfidence.high,
        summary: '${_signed(loadDelta)} kg at the same reps',
        deltas: deltas,
        previousPerformedAt: previousPerformedAt,
        comparisonKey: current.exerciseId,
        prescriptionChanged: prescriptionChanged,
      );
    }
    if (loadSame && repsImproved && !rpeHigher) {
      return ProgressionComparison(
        outcome: ProgressionOutcome.improved,
        confidence: EvidenceConfidence.high,
        summary: _moreRepsLabel(repsDelta),
        deltas: deltas,
        previousPerformedAt: previousPerformedAt,
        comparisonKey: current.exerciseId,
      );
    }
    if ((extraSetsPrescribed || extraSetsCompleted) &&
        volumeUp &&
        loadSame &&
        repsSame &&
        !rpeLower) {
      return ProgressionComparison(
        outcome: ProgressionOutcome.mixed,
        confidence: EvidenceConfidence.moderate,
        summary: extraSetsPrescribed
            ? 'More work completed; this week prescribed an additional set'
            : 'Greater volume but equivalent top-set performance',
        deltas: deltas,
        previousPerformedAt: previousPerformedAt,
        comparisonKey: current.exerciseId,
        prescriptionChanged: extraSetsPrescribed,
      );
    }
    if (loadSame && repsSame && rpeLower) {
      return ProgressionComparison(
        outcome: ProgressionOutcome.improved,
        confidence: EvidenceConfidence.high,
        summary: 'Same result at RPE ${currentTop.rpe} vs ${previousTop.rpe}',
        deltas: deltas,
        previousPerformedAt: previousPerformedAt,
        comparisonKey: current.exerciseId,
      );
    }
    if (loadSame && repsSame && !rpeHigher && !rpeLower) {
      return ProgressionComparison(
        outcome: ProgressionOutcome.matched,
        confidence: EvidenceConfidence.high,
        summary: 'Matched last performance',
        deltas: deltas,
        previousPerformedAt: previousPerformedAt,
        comparisonKey: current.exerciseId,
      );
    }
    if (loadImproved && repsBelow) {
      return ProgressionComparison(
        outcome: ProgressionOutcome.mixed,
        confidence: EvidenceConfidence.moderate,
        summary: 'Heavier load with fewer reps',
        deltas: deltas,
        previousPerformedAt: previousPerformedAt,
        comparisonKey: current.exerciseId,
        prescriptionChanged: prescriptionChanged,
      );
    }
    if (rpeHigher && (loadImproved || repsImproved)) {
      return ProgressionComparison(
        outcome: ProgressionOutcome.mixed,
        confidence: EvidenceConfidence.moderate,
        summary: 'Improved result with materially higher RPE',
        deltas: deltas,
        previousPerformedAt: previousPerformedAt,
        comparisonKey: current.exerciseId,
      );
    }
    if ((extraSetsPrescribed || extraSetsCompleted) &&
        volumeUp &&
        topWeaker) {
      return ProgressionComparison(
        outcome: ProgressionOutcome.mixed,
        confidence: EvidenceConfidence.moderate,
        summary: extraSetsPrescribed
            ? 'More work completed; this week prescribed an additional set'
            : 'Greater volume but lower top-set performance',
        deltas: deltas,
        previousPerformedAt: previousPerformedAt,
        comparisonKey: current.exerciseId,
        prescriptionChanged: extraSetsPrescribed,
      );
    }
    if (volumeUp && topWeaker) {
      return ProgressionComparison(
        outcome: ProgressionOutcome.mixed,
        confidence: EvidenceConfidence.moderate,
        summary: 'Greater volume but lower top-set performance',
        deltas: deltas,
        previousPerformedAt: previousPerformedAt,
        comparisonKey: current.exerciseId,
      );
    }
    if (loadBelow || (loadSame && repsBelow)) {
      return ProgressionComparison(
        outcome: ProgressionOutcome.belowLastPerformance,
        confidence: prescriptionChanged
            ? EvidenceConfidence.moderate
            : EvidenceConfidence.high,
        summary: 'Below last performance',
        deltas: deltas,
        previousPerformedAt: previousPerformedAt,
        comparisonKey: current.exerciseId,
        prescriptionChanged: prescriptionChanged,
      );
    }
    if (prescriptionChanged) {
      return ProgressionComparison(
        outcome: ProgressionOutcome.mixed,
        confidence: EvidenceConfidence.moderate,
        summary: 'Prescription changed — comparison limited',
        deltas: deltas,
        previousPerformedAt: previousPerformedAt,
        comparisonKey: current.exerciseId,
        prescriptionChanged: true,
      );
    }
    return ProgressionComparison(
      outcome: ProgressionOutcome.mixed,
      confidence: EvidenceConfidence.low,
      summary: 'Last performance available, but comparison is limited',
      deltas: deltas,
      previousPerformedAt: previousPerformedAt,
      comparisonKey: current.exerciseId,
    );
  }

  static ({TrainingExerciseResult exercise, DateTime completedAt})?
  previousOccurrence({
    required String exerciseId,
    required TrainingSessionRecord current,
    required List<TrainingSessionRecord> athleteHistory,
  }) {
    final id = exerciseId.trim();
    if (id.isEmpty) return null;
    for (final record in EligiblePerformanceEvidence.priorsNewestFirst(
      current: current,
      athleteHistory: athleteHistory,
    )) {
      for (final block in record.blockResults) {
        for (final exercise in StrengthResultComparison.authoredExercises(
          block,
        )) {
          if (exercise.sourceExerciseId != id) continue;
          if (EligiblePerformanceEvidence.completedActualSets(
            exercise,
          ).isEmpty) {
            continue;
          }
          return (
            exercise: exercise,
            completedAt: record.performanceChronologyAt,
          );
        }
      }
    }
    return null;
  }

  static bool _prescriptionChanged(
    StrengthProgressionFacts current,
    StrengthProgressionFacts previous,
  ) {
    final a = current.prescribedSetCount;
    final b = previous.prescribedSetCount;
    if (a == null || b == null) return false;
    return a != b;
  }

  static bool _extraSetsFromPrescription(
    StrengthProgressionFacts current,
    StrengthProgressionFacts previous,
  ) {
    final a = current.prescribedSetCount;
    final b = previous.prescribedSetCount;
    if (a == null || b == null) return false;
    return a > b;
  }

  static double _tolerance(double? previous) {
    final value = previous ?? 0;
    final relative = value.abs() * relativeTolerance;
    return relative > absoluteTolerance ? relative : absoluteTolerance;
  }

  static double? _delta(double? current, double? previous) {
    if (current == null || previous == null) return null;
    return current - previous;
  }

  static int? _intDelta(int? current, int? previous) {
    if (current == null || previous == null) return null;
    return current - previous;
  }

  static String _signed(double value) {
    final formatted = StrengthLoadDisplay.formatNumber(value.abs());
    return value > 0 ? '+$formatted' : '-$formatted';
  }

  static String _moreRepsLabel(int repsDelta) {
    final count = repsDelta.abs();
    final noun = count == 1 ? 'rep' : 'reps';
    if (repsDelta > 0) return '$count more $noun at the same load';
    return '$count fewer $noun at the same load';
  }
}
