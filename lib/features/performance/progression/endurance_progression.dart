import '../models/performance_result_data.dart';
import 'progression_comparison.dart';

/// Steady-state endurance: facts without a false intensity verdict.
abstract final class EnduranceProgressionComparison {
  static ProgressionComparison compare({
    required EnduranceResultData current,
    EnduranceResultData? previous,
    int? currentRpe,
    int? previousRpe,
    DateTime? previousPerformedAt,
  }) {
    if (!current.completed && current.durationSeconds == null) {
      return ProgressionComparison.insufficient;
    }
    if (previous == null) return ProgressionComparison.first;
    if (current.distanceUnit != previous.distanceUnit) {
      return ProgressionComparison.notComparable;
    }

    final deltas = <MetricDelta>[];
    final currentPace = _pace(current);
    final previousPace = _pace(previous);
    if (currentPace != null && previousPace != null) {
      final faster = previousPace - currentPace;
      if (faster.abs() >= 1) {
        deltas.add(
          MetricDelta(
            key: 'pace',
            label:
                '${faster.round().abs()} sec/km ${faster > 0 ? 'faster' : 'slower'}'
                '${currentRpe != null && currentRpe == previousRpe ? ' at the same reported RPE' : ''}',
          ),
        );
      }
    }
    if (current.completed) {
      deltas.add(
        const MetricDelta(
          key: 'completion',
          label: 'Completed the full prescribed duration',
        ),
      );
    } else {
      deltas.add(
        const MetricDelta(
          key: 'completion',
          label: 'Partial completion',
        ),
      );
    }

    final sameRpe =
        currentRpe != null && previousRpe != null && currentRpe == previousRpe;
    final fasterAtSameRpe =
        currentPace != null &&
        previousPace != null &&
        previousPace - currentPace >= 1 &&
        sameRpe;

    if (fasterAtSameRpe) {
      return ProgressionComparison(
        outcome: ProgressionOutcome.mixed,
        confidence: EvidenceConfidence.low,
        summary: deltas.first.label,
        deltas: deltas,
        previousPerformedAt: previousPerformedAt,
        comparisonKey: 'endurance:${current.distanceUnit}',
      );
    }

    return ProgressionComparison(
      outcome: ProgressionOutcome.insufficientEvidence,
      confidence: EvidenceConfidence.low,
      summary: 'Insufficient intensity evidence for a progression verdict',
      deltas: deltas,
      previousPerformedAt: previousPerformedAt,
      comparisonKey: 'endurance:${current.distanceUnit}',
    );
  }

  static double? _pace(EnduranceResultData data) {
    final duration = data.durationSeconds;
    final distance = data.distance;
    if (duration == null || duration <= 0 || distance == null || distance <= 0) {
      return null;
    }
    return duration / distance;
  }
}
