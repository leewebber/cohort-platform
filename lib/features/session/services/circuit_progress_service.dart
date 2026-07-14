import '../../../models/circuit_format.dart';
import '../../../models/circuit_performance_entry.dart';
import '../../../models/circuit_progress_result.dart';
import '../../../models/circuit_score_type.dart';
import '../../../models/circuit_session_plan.dart';
import '../../../models/previous_circuit_performance.dart';
import 'strength_load_parser.dart';

/// Compares today's circuit score against the latest prior comparable session.
class CircuitProgressService {
  const CircuitProgressService();

  static const _elapsedMatchToleranceSeconds = 5;
  static const _rpeImprovementThreshold = 1;

  CircuitProgressResult evaluate({
    required PreviousCircuitPerformance? previousPerformance,
    required CircuitPerformanceEntry todayPerformance,
    required CircuitSessionPlan plan,
  }) {
    if (previousPerformance == null || !previousPerformance.hasHistory) {
      return _firstPerformance(todayPerformance, plan);
    }

    if (previousPerformance.scoreType != plan.scoreType) {
      return _insufficientData(
        reasons: const [
          'Previous and today use different scoring methods.',
        ],
      );
    }

    if (!_hasComparableTodayScore(todayPerformance, plan.scoreType)) {
      return _insufficientData(
        reasons: const [
          'Today\'s score is not complete enough to compare yet.',
        ],
      );
    }

    final reasons = _buildReasons(
      previous: previousPerformance,
      today: todayPerformance,
      scoreType: plan.scoreType,
    );

    final primary = _primaryComparison(
      previous: previousPerformance,
      today: todayPerformance,
      scoreType: plan.scoreType,
    );

    if (primary == _ComparisonOutcome.incompatible) {
      return _insufficientData(
        reasons: [
          ...reasons,
          'Completion status differs too much for a reliable time comparison.',
        ],
      );
    }

    final scoreImproved = primary == _ComparisonOutcome.improved;
    final scoreDeclined = primary == _ComparisonOutcome.declined;
    final scoreMatched = primary == _ComparisonOutcome.matched;

    final effortImproved = _effortImproved(
      previous: previousPerformance,
      today: todayPerformance,
      scoreDeclined: scoreDeclined,
    );
    final effortDeclined = _effortDeclined(
      previous: previousPerformance,
      today: todayPerformance,
    );

    final heavierLoad = _heavierLoad(
      previous: previousPerformance,
      today: todayPerformance,
      scoreImproved: scoreImproved,
      scoreMatched: scoreMatched,
    );

    if (scoreImproved) {
      return CircuitProgressResult(
        progressType: _improvedTypeForScore(plan.scoreType),
        title: _improvedTitleForScore(plan.scoreType),
        message: _improvedMessageForScore(plan.scoreType),
        reasons: reasons,
      );
    }

    if (heavierLoad) {
      return CircuitProgressResult(
        progressType: CircuitProgressType.heavierLoad,
        title: 'Heavier load',
        message:
            'You used a heavier comparable load with an equal or better score.',
        reasons: reasons,
      );
    }

    if (effortImproved) {
      return CircuitProgressResult(
        progressType: CircuitProgressType.effortImproved,
        title: 'Effort improved',
        message: 'You matched or improved your score at a lower RPE.',
        reasons: reasons,
      );
    }

    if (scoreMatched) {
      return CircuitProgressResult(
        progressType: CircuitProgressType.matchedPerformance,
        title: 'Performance matched',
        message: 'Strong consistency with your last comparable session.',
        reasons: reasons,
      );
    }

    if (scoreDeclined || effortDeclined) {
      return CircuitProgressResult(
        progressType: CircuitProgressType.mixedResult,
        title: 'Mixed result',
        message:
            'Some metrics moved in a different direction from your last session.',
        reasons: reasons,
      );
    }

    return _insufficientData(reasons: reasons);
  }

  CircuitProgressResult _firstPerformance(
    CircuitPerformanceEntry today,
    CircuitSessionPlan plan,
  ) {
    final reasons = <String>[];

    final summary = today.displayScoreSummary;
    if (summary != null) {
      reasons.add('Today: $summary.');
    } else {
      reasons.add('Score logged for ${plan.format.displayLabel}.');
    }

    return CircuitProgressResult(
      progressType: CircuitProgressType.firstPerformance,
      title: 'First recorded performance',
      message: 'A strong baseline to build from.',
      reasons: reasons,
    );
  }

  CircuitProgressResult _insufficientData({
    required List<String> reasons,
  }) {
    return CircuitProgressResult(
      progressType: CircuitProgressType.insufficientData,
      title: 'Logged successfully',
      message: 'Not enough comparable data to summarise progress yet.',
      reasons: reasons,
    );
  }

  bool _hasComparableTodayScore(
    CircuitPerformanceEntry today,
    CircuitScoreType scoreType,
  ) {
    return switch (scoreType) {
      CircuitScoreType.roundsAndReps => today.completedRounds != null,
      CircuitScoreType.elapsedTime =>
        today.elapsedDuration != null && today.elapsedDuration!.inSeconds > 0,
      CircuitScoreType.totalReps =>
        today.totalReps != null && today.totalReps! > 0,
      CircuitScoreType.roundsCompleted =>
        today.completedRounds != null && today.completedRounds! > 0,
      CircuitScoreType.movementsCompleted =>
        today.completedMovements != null && today.completedMovements! > 0,
      CircuitScoreType.benchmarkScore => today.hasRecordedScore,
    };
  }

  _ComparisonOutcome _primaryComparison({
    required PreviousCircuitPerformance previous,
    required CircuitPerformanceEntry today,
    required CircuitScoreType scoreType,
  }) {
    return switch (scoreType) {
      CircuitScoreType.roundsAndReps => _compareRoundsAndReps(previous, today),
      CircuitScoreType.elapsedTime => _compareElapsedTime(previous, today),
      CircuitScoreType.totalReps => _compareTotalReps(previous, today),
      CircuitScoreType.roundsCompleted =>
        _compareIntervals(previous, today),
      CircuitScoreType.movementsCompleted =>
        _compareMovements(previous, today),
      CircuitScoreType.benchmarkScore =>
        _compareElapsedTime(previous, today) ==
                _ComparisonOutcome.incompatible
            ? _compareRoundsAndReps(previous, today)
            : _compareElapsedTime(previous, today),
    };
  }

  _ComparisonOutcome _compareRoundsAndReps(
    PreviousCircuitPerformance previous,
    CircuitPerformanceEntry today,
  ) {
    final previousRounds = previous.completedRounds ?? 0;
    final previousReps = previous.additionalReps ?? 0;
    final todayRounds = today.completedRounds ?? 0;
    final todayReps = today.additionalReps ?? 0;

    if (todayRounds > previousRounds) {
      return _ComparisonOutcome.improved;
    }

    if (todayRounds < previousRounds) {
      return _ComparisonOutcome.declined;
    }

    if (todayReps > previousReps) {
      return _ComparisonOutcome.improved;
    }

    if (todayReps < previousReps) {
      return _ComparisonOutcome.declined;
    }

    return _ComparisonOutcome.matched;
  }

  _ComparisonOutcome _compareElapsedTime(
    PreviousCircuitPerformance previous,
    CircuitPerformanceEntry today,
  ) {
    if (previous.timeCapped || today.timeCapped) {
      return _ComparisonOutcome.incompatible;
    }

    final previousSeconds = previous.elapsedDuration?.inSeconds;
    final todaySeconds = today.elapsedDuration?.inSeconds;
    if (previousSeconds == null ||
        todaySeconds == null ||
        previousSeconds <= 0 ||
        todaySeconds <= 0) {
      return _ComparisonOutcome.incompatible;
    }

    if (todaySeconds <= previousSeconds - _elapsedMatchToleranceSeconds) {
      return _ComparisonOutcome.improved;
    }

    if (todaySeconds >= previousSeconds + _elapsedMatchToleranceSeconds) {
      return _ComparisonOutcome.declined;
    }

    return _ComparisonOutcome.matched;
  }

  _ComparisonOutcome _compareTotalReps(
    PreviousCircuitPerformance previous,
    CircuitPerformanceEntry today,
  ) {
    final previousReps = previous.totalReps;
    final todayReps = today.totalReps;
    if (previousReps == null || todayReps == null) {
      return _ComparisonOutcome.incompatible;
    }

    if (todayReps > previousReps) {
      return _ComparisonOutcome.improved;
    }

    if (todayReps < previousReps) {
      return _ComparisonOutcome.declined;
    }

    return _ComparisonOutcome.matched;
  }

  _ComparisonOutcome _compareIntervals(
    PreviousCircuitPerformance previous,
    CircuitPerformanceEntry today,
  ) {
    final previousCount =
        previous.completedIntervals ?? previous.completedRounds;
    final todayCount = today.completedRounds;
    if (previousCount == null || todayCount == null) {
      return _ComparisonOutcome.incompatible;
    }

    if (todayCount > previousCount) {
      return _ComparisonOutcome.improved;
    }

    if (todayCount < previousCount) {
      return _ComparisonOutcome.declined;
    }

    return _ComparisonOutcome.matched;
  }

  _ComparisonOutcome _compareMovements(
    PreviousCircuitPerformance previous,
    CircuitPerformanceEntry today,
  ) {
    if (!previous.timeCapped && !today.timeCapped) {
      return _compareElapsedTime(previous, today) ==
              _ComparisonOutcome.incompatible
          ? _ComparisonOutcome.incompatible
          : _compareElapsedTime(previous, today);
    }

    final previousMovements = previous.completedMovements;
    final todayMovements = today.completedMovements;
    if (previousMovements == null || todayMovements == null) {
      return _ComparisonOutcome.incompatible;
    }

    if (!today.timeCapped && previous.timeCapped) {
      return _ComparisonOutcome.improved;
    }

    if (today.timeCapped && !previous.timeCapped) {
      return _ComparisonOutcome.declined;
    }

    if (todayMovements > previousMovements) {
      return _ComparisonOutcome.improved;
    }

    if (todayMovements < previousMovements) {
      return _ComparisonOutcome.declined;
    }

    return _ComparisonOutcome.matched;
  }

  bool _effortImproved({
    required PreviousCircuitPerformance previous,
    required CircuitPerformanceEntry today,
    required bool scoreDeclined,
  }) {
    final previousRpe = previous.averageRpe;
    final todayRpe = today.rpe;
    if (previousRpe == null || todayRpe == null || scoreDeclined) {
      return false;
    }

    final primary = _primaryComparison(
      previous: previous,
      today: today,
      scoreType: previous.scoreType,
    );

    if (primary == _ComparisonOutcome.declined ||
        primary == _ComparisonOutcome.incompatible) {
      return false;
    }

    return todayRpe <= previousRpe - _rpeImprovementThreshold;
  }

  bool _effortDeclined({
    required PreviousCircuitPerformance previous,
    required CircuitPerformanceEntry today,
  }) {
    final previousRpe = previous.averageRpe;
    final todayRpe = today.rpe;
    if (previousRpe == null || todayRpe == null) {
      return false;
    }

    return todayRpe >= previousRpe + _rpeImprovementThreshold;
  }

  bool _heavierLoad({
    required PreviousCircuitPerformance previous,
    required CircuitPerformanceEntry today,
    required bool scoreImproved,
    required bool scoreMatched,
  }) {
    if (!scoreImproved && !scoreMatched) {
      return false;
    }

    final todayLoad = StrengthLoadParser.parse(today.actualLoad);
    final previousLoad = StrengthLoadParser.parse(previous.actualLoad);
    if (!_loadsComparable(todayLoad, previousLoad)) {
      return false;
    }

    return todayLoad.value! > previousLoad.value!;
  }

  bool _loadsComparable(ParsedLoad today, ParsedLoad previous) {
    return today.value != null &&
        previous.value != null &&
        today.unit != null &&
        today.unit == previous.unit &&
        today.unit != 'unknown';
  }

  CircuitProgressType _improvedTypeForScore(CircuitScoreType scoreType) {
    return switch (scoreType) {
      CircuitScoreType.roundsAndReps =>
        CircuitProgressType.moreRoundsOrReps,
      CircuitScoreType.elapsedTime => CircuitProgressType.fasterCompletion,
      CircuitScoreType.totalReps => CircuitProgressType.moreWorkCompleted,
      CircuitScoreType.roundsCompleted =>
        CircuitProgressType.moreWorkCompleted,
      CircuitScoreType.movementsCompleted =>
        CircuitProgressType.moreWorkCompleted,
      CircuitScoreType.benchmarkScore => CircuitProgressType.fasterCompletion,
    };
  }

  String _improvedTitleForScore(CircuitScoreType scoreType) {
    return switch (scoreType) {
      CircuitScoreType.roundsAndReps => 'More rounds or reps',
      CircuitScoreType.elapsedTime => 'Faster completion',
      CircuitScoreType.totalReps => 'More total reps',
      CircuitScoreType.roundsCompleted => 'More intervals completed',
      CircuitScoreType.movementsCompleted => 'More work before the cap',
      CircuitScoreType.benchmarkScore => 'Benchmark improved',
    };
  }

  String _improvedMessageForScore(CircuitScoreType scoreType) {
    return switch (scoreType) {
      CircuitScoreType.roundsAndReps =>
        'You completed more rounds or reps than your last comparable session.',
      CircuitScoreType.elapsedTime =>
        'You finished faster than your last comparable session.',
      CircuitScoreType.totalReps =>
        'You completed more total reps in the same planned duration.',
      CircuitScoreType.roundsCompleted =>
        'You completed more intervals or rounds than last time.',
      CircuitScoreType.movementsCompleted =>
        'You completed more work before the time cap than last time.',
      CircuitScoreType.benchmarkScore =>
        'Your benchmark result improved from your last comparable session.',
    };
  }

  List<String> _buildReasons({
    required PreviousCircuitPerformance previous,
    required CircuitPerformanceEntry today,
    required CircuitScoreType scoreType,
  }) {
    final reasons = <String>[
      'Previous: ${previous.displaySummary}.',
    ];

    final todaySummary = today.displayScoreSummary;
    if (todaySummary != null) {
      reasons.add('Today: $todaySummary.');
    }

    if (scoreType == CircuitScoreType.roundsAndReps) {
      reasons.add(
        'Rounds compared first, then additional reps into the next round.',
      );
    }

    if (scoreType == CircuitScoreType.elapsedTime &&
        (previous.timeCapped || today.timeCapped)) {
      reasons.add('Time-capped results were not treated as full completions.');
    }

    if (previous.averageRpe != null && today.rpe != null) {
      reasons.add('RPE moved from ${previous.averageRpe} to ${today.rpe}.');
    }

    final previousLoad = previous.actualLoad?.trim();
    final todayLoad = today.actualLoad?.trim();
    if (previousLoad != null &&
        previousLoad.isNotEmpty &&
        todayLoad != null &&
        todayLoad.isNotEmpty) {
      reasons.add('Load moved from $previousLoad to $todayLoad.');
    }

    return reasons;
  }
}

enum _ComparisonOutcome {
  improved,
  declined,
  matched,
  incompatible,
}
