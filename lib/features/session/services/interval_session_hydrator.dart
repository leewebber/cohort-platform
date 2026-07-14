import '../../../models/interval_metric_entry_source.dart';
import '../../../models/interval_performance.dart';
import '../../../models/interval_rep_entry.dart';
import '../../../models/interval_session_execution_state.dart';
import '../../../models/interval_session_plan.dart';
import 'interval_metric_calculator.dart';

/// Merges persisted interval rows into in-memory session execution state.
class IntervalSessionHydrator {
  const IntervalSessionHydrator({
    this.metricCalculator = const IntervalMetricCalculator(),
  });

  final IntervalMetricCalculator metricCalculator;

  IntervalSessionExecutionState hydrate({
    required IntervalSessionPlan plan,
    required List<IntervalRepEntry> baseEntries,
    required List<IntervalPerformance> persisted,
    required Set<String> preserveLocalIds,
    int? trainingSessionId,
  }) {
    final performanceByKey = {
      for (final row in persisted)
        _key(
          blockIndex: row.blockIndex,
          repNumber: row.repNumber,
          phaseType: row.phaseType.dbValue,
        ): row,
    };

    final entries = baseEntries.map((entry) {
      if (preserveLocalIds.contains(entry.localId)) {
        return entry;
      }

      final row = performanceByKey[_key(
        blockIndex: entry.blockIndex,
        repNumber: entry.repNumber,
        phaseType: entry.phaseType.dbValue,
      )];
      if (row == null) {
        return entry;
      }

      return _entryFromPerformance(
        baseEntry: entry,
        performance: row,
      );
    }).toList();

    final activeLocalId = _resolveActiveLocalId(entries);

    return IntervalSessionExecutionState(
      plan: plan,
      entries: entries,
      activeLocalId: activeLocalId,
      trainingSessionId: trainingSessionId,
    );
  }

  String _key({
    required int blockIndex,
    required int repNumber,
    required String phaseType,
  }) {
    return '$blockIndex|$repNumber|$phaseType';
  }

  IntervalRepEntry _entryFromPerformance({
    required IntervalRepEntry baseEntry,
    required IntervalPerformance performance,
  }) {
    final restored = baseEntry.copyWith(
      actualDistance: performance.actualDistanceMeters,
      actualDuration: performance.actualDurationSeconds == null
          ? null
          : Duration(seconds: performance.actualDurationSeconds!),
      actualPace: performance.actualPaceSecondsPerKm,
      averageHeartRate: performance.averageHeartRate,
      maxHeartRate: performance.maxHeartRate,
      rpe: performance.rpe,
      completed: performance.completed,
      skipped: performance.skipped,
      dataSource: performance.dataSource,
      athleteNote: performance.athleteNote,
      distanceSource: performance.actualDistanceMeters == null
          ? IntervalMetricEntrySource.unset
          : IntervalMetricEntrySource.manual,
      durationSource: performance.actualDurationSeconds == null
          ? IntervalMetricEntrySource.unset
          : IntervalMetricEntrySource.manual,
      paceSource: performance.actualPaceSecondsPerKm == null
          ? IntervalMetricEntrySource.unset
          : IntervalMetricEntrySource.manual,
    );

    return metricCalculator.applyToEntry(
      entry: restored,
      input: metricCalculator.inputFromEntry(restored),
    );
  }

  String? _resolveActiveLocalId(List<IntervalRepEntry> entries) {
    for (final entry in entries) {
      if (!entry.completed) {
        return entry.localId;
      }
    }

    return null;
  }
}
