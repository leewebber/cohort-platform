import '../../../data/repositories/training_session_interval_repository.dart';
import '../../../models/interval_performance.dart';
import '../../../models/interval_phase_type.dart';
import '../../../models/previous_interval_performance.dart';
import '../../../models/training_session.dart';
import 'interval_metric_calculator.dart';

/// Builds athlete-facing summaries from prior completed interval sessions.
class PreviousIntervalPerformanceService {
  const PreviousIntervalPerformanceService({
    this.intervalRepository = const TrainingSessionIntervalRepository(),
    this.metricCalculator = const IntervalMetricCalculator(),
  });

  final TrainingSessionIntervalRepository intervalRepository;
  final IntervalMetricCalculator metricCalculator;

  Future<PreviousIntervalPerformance?> load({
    required String athleteId,
    required String protocolId,
    int? excludeTrainingSessionId,
  }) async {
    final sessionData =
        await intervalRepository.getLatestCompletedComparableSession(
      athleteId: athleteId,
      protocolId: protocolId,
      excludeTrainingSessionId: excludeTrainingSessionId,
    );

    if (sessionData == null) {
      return null;
    }

    return buildFromSession(
      session: sessionData.session,
      intervals: sessionData.intervals,
    );
  }

  PreviousIntervalPerformance? buildFromSession({
    required TrainingSession session,
    required List<IntervalPerformance> intervals,
  }) {
    final workPhases = intervals
        .where(
          (row) =>
              row.phaseType == IntervalPhaseType.work &&
              row.completed,
        )
        .toList()
      ..sort((a, b) {
        final blockCompare = a.blockIndex.compareTo(b.blockIndex);
        if (blockCompare != 0) {
          return blockCompare;
        }

        return a.repNumber.compareTo(b.repNumber);
      });

    if (workPhases.isEmpty) {
      return null;
    }

    final reps = <PreviousIntervalRep>[];
    for (var index = 0; index < workPhases.length; index++) {
      final row = workPhases[index];
      reps.add(
        PreviousIntervalRep(
          repNumber: index + 1,
          actualDistanceMeters: row.actualDistanceMeters,
          actualDurationSeconds: row.actualDurationSeconds,
          actualPaceSecondsPerKm: row.actualPaceSecondsPerKm,
          averageHeartRate: row.averageHeartRate,
          maxHeartRate: row.maxHeartRate,
          rpe: row.rpe,
          skipped: row.skipped,
          displayLine: _displayLineForRep(row: row),
        ),
      );
    }

    final measurableReps = workPhases.where((row) => !row.skipped).toList();

    return PreviousIntervalPerformance(
      trainingSessionId: session.id,
      protocolId: session.protocolId,
      completedAt: session.completedAt,
      modality: measurableReps.firstOrNull?.modality ??
          workPhases.first.modality,
      reps: reps,
      averageDurationSeconds: _averageInt(
        measurableReps
            .map((row) => row.actualDurationSeconds)
            .whereType<int>(),
      ),
      averagePaceSecondsPerKm: _averageDouble(
        measurableReps
            .map((row) => row.actualPaceSecondsPerKm)
            .whereType<double>(),
      ),
      paceDropOffSeconds: _paceDropOffSeconds(
        measurableReps
            .map((row) => row.actualPaceSecondsPerKm)
            .whereType<double>(),
      ),
      averageRpe: _averageDouble(
        measurableReps.map((row) => row.rpe).whereType<int>().map(
              (value) => value.toDouble(),
            ),
      ),
      completedRepCount: measurableReps.length,
    );
  }

  String _displayLineForRep({
    required IntervalPerformance row,
  }) {
    if (row.skipped) {
      return 'Skipped';
    }

    final parts = <String>[];

    final distance = row.actualDistanceMeters;
    if (distance != null && distance > 0) {
      if (distance == distance.roundToDouble()) {
        parts.add('${distance.toInt()} m');
      } else {
        parts.add('${distance.toStringAsFixed(0)} m');
      }
    }

    final durationLabel =
        metricCalculator.formatDurationSeconds(row.actualDurationSeconds);
    if (durationLabel != null) {
      parts.add(durationLabel);
    }

    final paceLabel = metricCalculator.formatPaceSecondsPerKm(
      row.actualPaceSecondsPerKm,
      modality: row.modality,
    );
    if (paceLabel != null) {
      parts.add(paceLabel);
    }

    if (row.rpe != null) {
      parts.add('RPE ${row.rpe}');
    }

    if (parts.isEmpty) {
      return 'Recorded';
    }

    return parts.join(' · ');
  }

  double? _averageInt(Iterable<int> values) {
    final items = values.toList();
    if (items.isEmpty) {
      return null;
    }

    return items.reduce((sum, value) => sum + value) / items.length;
  }

  double? _averageDouble(Iterable<double> values) {
    final items = values.toList();
    if (items.isEmpty) {
      return null;
    }

    return items.reduce((sum, value) => sum + value) / items.length;
  }

  double? _paceDropOffSeconds(Iterable<double> paceValues) {
    final items = paceValues.toList();
    if (items.length < 2) {
      return null;
    }

    final slowest = items.reduce((max, value) => value > max ? value : max);
    final fastest = items.reduce((min, value) => value < min ? value : min);
    final spread = slowest - fastest;

    return spread > 0 ? spread : null;
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
