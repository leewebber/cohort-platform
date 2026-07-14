import '../../../models/interval_progress_result.dart';
import '../../../models/interval_rep_entry.dart';
import '../../../models/previous_interval_performance.dart';
import 'interval_metric_calculator.dart';

/// Compares today's completed interval work against the latest prior session.
class IntervalProgressService {
  const IntervalProgressService({
    this.metricCalculator = const IntervalMetricCalculator(),
  });

  final IntervalMetricCalculator metricCalculator;

  static const _paceImprovementThresholdSeconds = 3.0;
  static const _paceMatchToleranceSeconds = 5.0;
  static const _spreadImprovementMinimumSeconds = 1.0;
  static const _rpeImprovementThreshold = 0.5;

  IntervalProgressResult evaluate({
    required PreviousIntervalPerformance? previousPerformance,
    required List<IntervalRepEntry> todayCompletedWorkPhases,
  }) {
    final todayMeasurable = _measurableWorkPhases(todayCompletedWorkPhases);

    if (previousPerformance == null || !previousPerformance.hasHistory) {
      return _firstPerformance(todayMeasurable);
    }

    if (todayMeasurable.isEmpty) {
      return _insufficientData(
        reasons: const [
          'No completed work intervals were available to compare.',
        ],
      );
    }

    final todayMetrics = _metricsFromToday(todayMeasurable);
    final previousMetrics = _metricsFromPrevious(previousPerformance);
    final reasons = <String>[];

    _appendMetricReasons(
      todayMetrics: todayMetrics,
      previousMetrics: previousMetrics,
      reasons: reasons,
    );

    if (!todayMetrics.hasComparablePace || !previousMetrics.hasComparablePace) {
      if (_moreWorkCompleted(todayMetrics, previousMetrics)) {
        return IntervalProgressResult(
          progressType: IntervalProgressType.moreWorkCompleted,
          title: 'More work completed',
          message:
              'You completed more work intervals than your last recorded session.',
          reasons: reasons,
        );
      }

      return _insufficientData(
        reasons: [
          ...reasons,
          'Comparable pace data was not available for both sessions.',
        ],
      );
    }

    final paceImproved = _paceImproved(todayMetrics, previousMetrics);
    final paceDeclined = _paceDeclined(todayMetrics, previousMetrics);
    final consistencyImproved =
        _consistencyImproved(todayMetrics, previousMetrics);
    final consistencyDeclined =
        _consistencyDeclined(todayMetrics, previousMetrics);
    final effortImproved = _effortImproved(
      todayMetrics: todayMetrics,
      previousMetrics: previousMetrics,
      paceDeclined: paceDeclined,
    );
    final effortDeclined = _effortDeclined(todayMetrics, previousMetrics);
    final moreWork = _moreWorkCompleted(todayMetrics, previousMetrics);
    final matched = _matchedPerformance(todayMetrics, previousMetrics);

    final improvedSignals = <bool>[
      paceImproved,
      consistencyImproved,
      effortImproved,
      moreWork,
    ].where((value) => value).length;

    final declinedSignals = <bool>[
      paceDeclined,
      consistencyDeclined,
      effortDeclined,
    ].where((value) => value).length;

    if (paceImproved) {
      return IntervalProgressResult(
        progressType: IntervalProgressType.averagePaceImproved,
        title: 'Average pace improved',
        message:
            'Your average pace was faster than your last comparable session.',
        reasons: reasons,
      );
    }

    if (consistencyImproved) {
      return IntervalProgressResult(
        progressType: IntervalProgressType.consistencyImproved,
        title: 'Consistency improved',
        message: 'Your pacing spread was tighter across completed work intervals.',
        reasons: reasons,
      );
    }

    if (effortImproved) {
      return IntervalProgressResult(
        progressType: IntervalProgressType.effortImproved,
        title: 'Effort improved',
        message: 'You completed comparable work at a lower average RPE.',
        reasons: reasons,
      );
    }

    if (matched) {
      return IntervalProgressResult(
        progressType: IntervalProgressType.matchedPerformance,
        title: 'Performance matched',
        message: 'Strong consistency with your last comparable session.',
        reasons: reasons,
      );
    }

    if (moreWork && !paceDeclined) {
      return IntervalProgressResult(
        progressType: IntervalProgressType.moreWorkCompleted,
        title: 'More work completed',
        message:
            'You completed more work intervals than your last recorded session.',
        reasons: reasons,
      );
    }

    if (improvedSignals > 0 && declinedSignals > 0) {
      return IntervalProgressResult(
        progressType: IntervalProgressType.mixedResult,
        title: 'Mixed result',
        message:
            'Some interval metrics improved and others shifted from your last session.',
        reasons: reasons,
      );
    }

    if (moreWork) {
      return IntervalProgressResult(
        progressType: IntervalProgressType.moreWorkCompleted,
        title: 'More work completed',
        message:
            'You completed more work intervals, with some pacing differences from last time.',
        reasons: reasons,
      );
    }

    if (declinedSignals > 0) {
      return IntervalProgressResult(
        progressType: IntervalProgressType.mixedResult,
        title: 'Mixed result',
        message:
            'Today differed from your last comparable session across pace, consistency, or effort.',
        reasons: reasons,
      );
    }

    return _insufficientData(reasons: reasons);
  }

  IntervalProgressResult _firstPerformance(List<IntervalRepEntry> todayMeasurable) {
    final reasons = <String>[];

    if (todayMeasurable.isNotEmpty) {
      reasons.add(
        '${todayMeasurable.length} work interval${todayMeasurable.length == 1 ? '' : 's'} completed.',
      );
    } else {
      reasons.add('No completed work intervals were logged yet.');
    }

    return IntervalProgressResult(
      progressType: IntervalProgressType.firstPerformance,
      title: 'First recorded performance',
      message: 'A strong baseline to build from.',
      reasons: reasons,
    );
  }

  IntervalProgressResult _insufficientData({
    required List<String> reasons,
  }) {
    return IntervalProgressResult(
      progressType: IntervalProgressType.insufficientData,
      title: 'Logged successfully',
      message: 'Not enough comparable data to summarise progress yet.',
      reasons: reasons,
    );
  }

  List<IntervalRepEntry> _measurableWorkPhases(
    List<IntervalRepEntry> todayCompletedWorkPhases,
  ) {
    final workPhases = todayCompletedWorkPhases
        .where((entry) => entry.isWorkPhase && entry.completed && !entry.skipped)
        .toList()
      ..sort((left, right) {
        final blockCompare = left.blockIndex.compareTo(right.blockIndex);
        if (blockCompare != 0) {
          return blockCompare;
        }

        return left.repNumber.compareTo(right.repNumber);
      });

    return workPhases;
  }

  _IntervalSessionMetrics _metricsFromToday(List<IntervalRepEntry> entries) {
    return _IntervalSessionMetrics(
      validRepCount: entries.length,
      averageDurationSeconds: _averageInt(
        entries.map((entry) => entry.actualDuration?.inSeconds).whereType<int>(),
      ),
      averagePaceSecondsPerKm: _averageDouble(
        entries.map((entry) => entry.actualPace).whereType<double>(),
      ),
      paceSpreadSeconds: _paceSpread(
        entries.map((entry) => entry.actualPace).whereType<double>(),
      ),
      averageRpe: _averageDouble(
        entries.map((entry) => entry.rpe).whereType<int>().map(
              (value) => value.toDouble(),
            ),
      ),
    );
  }

  _IntervalSessionMetrics _metricsFromPrevious(
    PreviousIntervalPerformance previous,
  ) {
    return _IntervalSessionMetrics(
      validRepCount: previous.completedRepCount,
      averageDurationSeconds: previous.averageDurationSeconds,
      averagePaceSecondsPerKm: previous.averagePaceSecondsPerKm,
      paceSpreadSeconds: previous.paceDropOffSeconds,
      averageRpe: previous.averageRpe,
    );
  }

  bool _paceImproved(
    _IntervalSessionMetrics today,
    _IntervalSessionMetrics previous,
  ) {
    final todayPace = today.averagePaceSecondsPerKm;
    final previousPace = previous.averagePaceSecondsPerKm;
    if (todayPace == null || previousPace == null) {
      return false;
    }

    if (today.validRepCount < previous.validRepCount) {
      return false;
    }

    return todayPace <= previousPace - _paceImprovementThresholdSeconds;
  }

  bool _paceDeclined(
    _IntervalSessionMetrics today,
    _IntervalSessionMetrics previous,
  ) {
    final todayPace = today.averagePaceSecondsPerKm;
    final previousPace = previous.averagePaceSecondsPerKm;
    if (todayPace == null || previousPace == null) {
      return false;
    }

    return todayPace >= previousPace + _paceImprovementThresholdSeconds;
  }

  bool _consistencyImproved(
    _IntervalSessionMetrics today,
    _IntervalSessionMetrics previous,
  ) {
    final todaySpread = today.paceSpreadSeconds;
    final previousSpread = previous.paceSpreadSeconds;
    if (todaySpread == null || previousSpread == null) {
      return false;
    }

    if (today.validRepCount < previous.validRepCount) {
      return false;
    }

    return todaySpread <= previousSpread - _spreadImprovementMinimumSeconds;
  }

  bool _consistencyDeclined(
    _IntervalSessionMetrics today,
    _IntervalSessionMetrics previous,
  ) {
    final todaySpread = today.paceSpreadSeconds;
    final previousSpread = previous.paceSpreadSeconds;
    if (todaySpread == null || previousSpread == null) {
      return false;
    }

    return todaySpread >= previousSpread + _spreadImprovementMinimumSeconds;
  }

  bool _effortImproved({
    required _IntervalSessionMetrics todayMetrics,
    required _IntervalSessionMetrics previousMetrics,
    required bool paceDeclined,
  }) {
    final todayRpe = todayMetrics.averageRpe;
    final previousRpe = previousMetrics.averageRpe;
    if (todayRpe == null || previousRpe == null) {
      return false;
    }

    if (todayMetrics.validRepCount < previousMetrics.validRepCount) {
      return false;
    }

    if (paceDeclined) {
      return false;
    }

    return todayRpe <= previousRpe - _rpeImprovementThreshold;
  }

  bool _effortDeclined(
    _IntervalSessionMetrics today,
    _IntervalSessionMetrics previous,
  ) {
    final todayRpe = today.averageRpe;
    final previousRpe = previous.averageRpe;
    if (todayRpe == null || previousRpe == null) {
      return false;
    }

    return todayRpe >= previousRpe + _rpeImprovementThreshold;
  }

  bool _moreWorkCompleted(
    _IntervalSessionMetrics today,
    _IntervalSessionMetrics previous,
  ) {
    return today.validRepCount > previous.validRepCount;
  }

  bool _matchedPerformance(
    _IntervalSessionMetrics today,
    _IntervalSessionMetrics previous,
  ) {
    if (today.validRepCount != previous.validRepCount) {
      return false;
    }

    final todayPace = today.averagePaceSecondsPerKm;
    final previousPace = previous.averagePaceSecondsPerKm;
    if (todayPace == null || previousPace == null) {
      return false;
    }

    final paceDelta = (todayPace - previousPace).abs();
    return paceDelta <= _paceMatchToleranceSeconds;
  }

  void _appendMetricReasons({
    required _IntervalSessionMetrics todayMetrics,
    required _IntervalSessionMetrics previousMetrics,
    required List<String> reasons,
  }) {
    reasons.add(
      'Today: ${todayMetrics.validRepCount} completed work interval'
      '${todayMetrics.validRepCount == 1 ? '' : 's'}.',
    );
    reasons.add(
      'Previous: ${previousMetrics.validRepCount} completed work interval'
      '${previousMetrics.validRepCount == 1 ? '' : 's'}.',
    );

    final todayPaceLabel = metricCalculator.formatPaceSecondsPerKm(
      todayMetrics.averagePaceSecondsPerKm,
    );
    final previousPaceLabel = metricCalculator.formatPaceSecondsPerKm(
      previousMetrics.averagePaceSecondsPerKm,
    );
    if (todayPaceLabel != null && previousPaceLabel != null) {
      reasons.add('Average pace moved from $previousPaceLabel to $todayPaceLabel.');
    }

    if (todayMetrics.paceSpreadSeconds != null &&
        previousMetrics.paceSpreadSeconds != null) {
      reasons.add(
        'Pacing spread moved from ${previousMetrics.paceSpreadSeconds!.round()} sec '
        'to ${todayMetrics.paceSpreadSeconds!.round()} sec.',
      );
    }

    if (todayMetrics.averageRpe != null && previousMetrics.averageRpe != null) {
      reasons.add(
        'Average RPE moved from ${previousMetrics.averageRpe!.toStringAsFixed(1)} '
        'to ${todayMetrics.averageRpe!.toStringAsFixed(1)}.',
      );
    }
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

  double? _paceSpread(Iterable<double> paceValues) {
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

class _IntervalSessionMetrics {
  const _IntervalSessionMetrics({
    required this.validRepCount,
    this.averageDurationSeconds,
    this.averagePaceSecondsPerKm,
    this.paceSpreadSeconds,
    this.averageRpe,
  });

  final int validRepCount;
  final double? averageDurationSeconds;
  final double? averagePaceSecondsPerKm;
  final double? paceSpreadSeconds;
  final double? averageRpe;

  bool get hasComparablePace =>
      validRepCount > 0 && averagePaceSecondsPerKm != null;
}
