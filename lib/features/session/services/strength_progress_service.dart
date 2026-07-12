import '../../../models/exercise_progress_result.dart';
import '../../../models/previous_exercise_performance.dart';
import '../models/strength_set_entry.dart';
import 'strength_load_parser.dart';

/// Compares today's completed sets against the latest prior performance.
class StrengthProgressService {
  const StrengthProgressService();

  static const _loadTolerance = 0.01;

  ExerciseProgressResult evaluate({
    required PreviousExercisePerformance? previousPerformance,
    required List<StrengthSetEntry> todayCompletedSets,
  }) {
    final completedToday = todayCompletedSets.where((set) => set.completed).toList();

    if (previousPerformance == null || !previousPerformance.hasHistory) {
      return _firstPerformance(completedToday);
    }

    if (completedToday.isEmpty) {
      return _insufficientData(
        reasons: const ['No completed sets were available to compare.'],
      );
    }

    final previousMetrics = _metricsFromPrevious(previousPerformance.sets);
    final todayMetrics = _metricsFromToday(completedToday);

    final reasons = <String>[];
    _appendExtraSetReason(todayMetrics, reasons);

    if (!previousMetrics.isComparable || !todayMetrics.isComparable) {
      return _insufficientData(
        reasons: [
          ...reasons,
          'Comparable load and rep values were not available for both sessions.',
        ],
      );
    }

    if (!_unitsComparable(previousMetrics.loadUnit, todayMetrics.loadUnit)) {
      return _insufficientData(
        reasons: [
          ...reasons,
          'Load units differ between sessions, so load could not be compared reliably.',
        ],
      );
    }

    final loadComparison = _compareValues(
      previousMetrics.topLoad,
      todayMetrics.topLoad,
    );
    final repComparison = _compareValues(
      previousMetrics.totalReps?.toDouble(),
      todayMetrics.totalReps?.toDouble(),
    );
    final volumeComparison = _compareValues(
      previousMetrics.totalVolume,
      todayMetrics.totalVolume,
    );

    _appendMetricReasons(
      previousMetrics: previousMetrics,
      todayMetrics: todayMetrics,
      reasons: reasons,
    );

    final loadProgress = loadComparison > 0 &&
        (repComparison >= 0) &&
        previousMetrics.topLoad != null &&
        todayMetrics.topLoad != null;

    final repProgress = loadComparison == 0 &&
        repComparison > 0 &&
        previousMetrics.topLoad != null &&
        todayMetrics.topLoad != null;

    final volumeProgress = volumeComparison > 0;

    final rpeProgress = _hasRpeProgress(
      previousMetrics: previousMetrics,
      todayMetrics: todayMetrics,
      loadComparison: loadComparison,
      repComparison: repComparison,
      volumeComparison: volumeComparison,
    );

    final matchedPerformance = loadComparison == 0 &&
        repComparison == 0 &&
        previousMetrics.topLoad != null &&
        todayMetrics.topLoad != null;

    final matchedWithImprovedEfficiency = matchedPerformance &&
        previousMetrics.averageRpe != null &&
        todayMetrics.averageRpe != null &&
        todayMetrics.averageRpe! < previousMetrics.averageRpe!;

    final improvedSignals = <bool>[
      loadProgress,
      repProgress,
      volumeProgress,
      rpeProgress,
    ].where((value) => value).length;

    final declinedSignals = [
      loadComparison < 0,
      repComparison < 0,
      volumeComparison < 0,
    ].where((value) => value).length;

    if (loadProgress) {
      return ExerciseProgressResult(
        progressType: ExerciseProgressType.loadProgress,
        title: 'Progress achieved',
        message: 'You moved more load while matching or exceeding your previous total reps.',
        reasons: reasons,
      );
    }

    if (repProgress) {
      return ExerciseProgressResult(
        progressType: ExerciseProgressType.repProgress,
        title: 'Progress achieved',
        message: 'You completed more total reps at a comparable load.',
        reasons: reasons,
      );
    }

    if (volumeProgress && improvedSignals == 1 && declinedSignals == 0) {
      return ExerciseProgressResult(
        progressType: ExerciseProgressType.volumeProgress,
        title: 'Progress achieved',
        message: 'Total volume increased.',
        reasons: reasons,
      );
    }

    if (matchedWithImprovedEfficiency) {
      return ExerciseProgressResult(
        progressType: ExerciseProgressType.matchedPerformance,
        title: 'Performance matched',
        message: 'Performance matched with improved efficiency.',
        reasons: reasons,
      );
    }

    if (rpeProgress) {
      return ExerciseProgressResult(
        progressType: ExerciseProgressType.rpeProgress,
        title: 'Progress achieved',
        message: 'Same work at lower effort.',
        reasons: reasons,
      );
    }

    if (matchedPerformance) {
      return ExerciseProgressResult(
        progressType: ExerciseProgressType.matchedPerformance,
        title: 'Performance matched',
        message: 'Strong consistency with your last session.',
        reasons: reasons,
      );
    }

    if (improvedSignals > 0 && declinedSignals > 0) {
      return ExerciseProgressResult(
        progressType: ExerciseProgressType.mixedResult,
        title: 'Mixed result',
        message: 'Some metrics improved and others shifted from your last session.',
        reasons: reasons,
      );
    }

    if (volumeProgress) {
      return ExerciseProgressResult(
        progressType: ExerciseProgressType.volumeProgress,
        title: 'Progress achieved',
        message: 'Total volume increased.',
        reasons: reasons,
      );
    }

    if (declinedSignals > 0 && improvedSignals == 0) {
      return ExerciseProgressResult(
        progressType: ExerciseProgressType.mixedResult,
        title: 'Mixed result',
        message: 'Today differed from your last session across load, reps, or volume.',
        reasons: reasons,
      );
    }

    return _insufficientData(reasons: reasons);
  }

  ExerciseProgressResult _firstPerformance(List<StrengthSetEntry> completedToday) {
    final reasons = <String>[];
    final todayMetrics = _metricsFromToday(completedToday);
    _appendExtraSetReason(todayMetrics, reasons);

    if (completedToday.isNotEmpty) {
      reasons.add('${todayMetrics.prescribedCompletedCount} prescribed sets completed.');
      if (todayMetrics.extraCompletedCount > 0) {
        reasons.add('${todayMetrics.extraCompletedCount} extra sets completed.');
      }
    }

    return ExerciseProgressResult(
      progressType: ExerciseProgressType.firstPerformance,
      title: 'First recorded performance',
      message: 'A strong baseline to build from.',
      reasons: reasons,
    );
  }

  ExerciseProgressResult _insufficientData({
    required List<String> reasons,
  }) {
    return ExerciseProgressResult(
      progressType: ExerciseProgressType.insufficientData,
      title: 'Logged successfully',
      message: 'Not enough comparable data to summarise progress yet.',
      reasons: reasons,
    );
  }

  bool _hasRpeProgress({
    required _SessionMetrics previousMetrics,
    required _SessionMetrics todayMetrics,
    required int loadComparison,
    required int repComparison,
    required int volumeComparison,
  }) {
    final previousRpe = previousMetrics.averageRpe;
    final todayRpe = todayMetrics.averageRpe;

    if (previousRpe == null || todayRpe == null) {
      return false;
    }

    final workMaintainedOrImproved =
        loadComparison >= 0 && repComparison >= 0 && volumeComparison >= 0;

    return workMaintainedOrImproved && todayRpe < previousRpe;
  }

  _SessionMetrics _metricsFromPrevious(List<PreviousPerformedSet> sets) {
    final parsedSets = sets
        .map(
          (set) => _ParsedSet(
            load: StrengthLoadParser.parse(set.loadLabel),
            reps: _parseReps(set.reps),
            rpe: set.rpe,
            isExtraSet: false,
            displayLoad: set.loadLabel,
            displayReps: set.reps,
          ),
        )
        .toList();

    return _metricsFromParsedSets(parsedSets);
  }

  _SessionMetrics _metricsFromToday(List<StrengthSetEntry> sets) {
    final parsedSets = sets
        .map(
          (set) => _ParsedSet(
            load: StrengthLoadParser.parse(set.load),
            reps: _parseReps(set.actualReps),
            rpe: set.rpe?.toDouble(),
            isExtraSet: set.isExtraSet,
            displayLoad: set.load,
            displayReps: set.actualReps,
          ),
        )
        .toList();

    return _metricsFromParsedSets(parsedSets);
  }

  _SessionMetrics _metricsFromParsedSets(List<_ParsedSet> sets) {
    if (sets.isEmpty) {
      return const _SessionMetrics();
    }

    double? topLoad;
    String? loadUnit;
    var totalReps = 0;
    var hasReps = false;
    double totalVolume = 0;
    var hasVolume = false;
    final rpeValues = <double>[];

    for (final set in sets) {
      final loadValue = set.load.value;
      final unit = _normalizeUnit(set.load.unit);

      if (loadValue != null && _isMassUnit(unit)) {
        if (topLoad == null || loadValue > topLoad) {
          topLoad = loadValue;
          loadUnit = unit;
        }
      }

      if (set.reps != null) {
        totalReps += set.reps!;
        hasReps = true;
      }

      if (loadValue != null && set.reps != null && _isMassUnit(unit)) {
        totalVolume += loadValue * set.reps!;
        hasVolume = true;
      }

      if (set.rpe != null) {
        rpeValues.add(set.rpe!);
      }
    }

    final prescribedCompletedCount =
        sets.where((set) => !set.isExtraSet).length;
    final extraCompletedCount = sets.where((set) => set.isExtraSet).length;

    return _SessionMetrics(
      topLoad: topLoad,
      loadUnit: loadUnit,
      totalReps: hasReps ? totalReps : null,
      totalVolume: hasVolume ? totalVolume : null,
      averageRpe: rpeValues.isEmpty
          ? null
          : rpeValues.reduce((a, b) => a + b) / rpeValues.length,
      prescribedCompletedCount: prescribedCompletedCount,
      extraCompletedCount: extraCompletedCount,
      isComparable: hasReps && (topLoad != null || hasVolume),
    );
  }

  void _appendExtraSetReason(_SessionMetrics todayMetrics, List<String> reasons) {
    if (todayMetrics.extraCompletedCount > 0) {
      reasons.add(
        '${todayMetrics.extraCompletedCount} extra set'
        '${todayMetrics.extraCompletedCount == 1 ? '' : 's'} '
        'contributed to today\'s totals.',
      );
    }
  }

  void _appendMetricReasons({
    required _SessionMetrics previousMetrics,
    required _SessionMetrics todayMetrics,
    required List<String> reasons,
  }) {
    if (previousMetrics.topLoad != null &&
        todayMetrics.topLoad != null &&
        previousMetrics.loadUnit == todayMetrics.loadUnit) {
      reasons.add(
        'Top load: ${_formatLoad(previousMetrics.topLoad, previousMetrics.loadUnit)}'
        ' → ${_formatLoad(todayMetrics.topLoad, todayMetrics.loadUnit)}.',
      );
    }

    if (previousMetrics.totalReps != null && todayMetrics.totalReps != null) {
      reasons.add(
        'Total reps: ${previousMetrics.totalReps} → ${todayMetrics.totalReps}.',
      );
    }

    if (previousMetrics.totalVolume != null && todayMetrics.totalVolume != null) {
      reasons.add(
        'Total volume: ${_trimTrailingZero(previousMetrics.totalVolume!)}'
        ' → ${_trimTrailingZero(todayMetrics.totalVolume!)}.',
      );
    }

    if (previousMetrics.averageRpe != null && todayMetrics.averageRpe != null) {
      reasons.add(
        'Average RPE: ${_trimTrailingZero(previousMetrics.averageRpe!)}'
        ' → ${_trimTrailingZero(todayMetrics.averageRpe!)}.',
      );
    }
  }

  int _compareValues(double? previous, double? today) {
    if (previous == null || today == null) {
      return 0;
    }

    final delta = today - previous;
    if (delta.abs() <= _loadTolerance) {
      return 0;
    }

    return delta > 0 ? 1 : -1;
  }

  bool _unitsComparable(String? previousUnit, String? todayUnit) {
    if (previousUnit == null || todayUnit == null) {
      return true;
    }

    return previousUnit == todayUnit;
  }

  bool _isMassUnit(String? unit) {
    return unit == 'kg' || unit == 'lb';
  }

  String? _normalizeUnit(String? unit) {
    final normalized = unit?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  int? _parseReps(String? raw) {
    if (raw == null) {
      return null;
    }

    final match = RegExp(r'(\d+)').firstMatch(raw.trim());
    if (match == null) {
      return null;
    }

    return int.tryParse(match.group(1)!);
  }

  String _formatLoad(double? value, String? unit) {
    if (value == null) {
      return '—';
    }

    final formatted = _trimTrailingZero(value);
    if (unit == 'kg' || unit == 'lb') {
      return '$formatted$unit';
    }

    if (unit == null) {
      return formatted;
    }

    return '$formatted $unit';
  }

  String _trimTrailingZero(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toString();
  }
}

class _SessionMetrics {
  const _SessionMetrics({
    this.topLoad,
    this.loadUnit,
    this.totalReps,
    this.totalVolume,
    this.averageRpe,
    this.prescribedCompletedCount = 0,
    this.extraCompletedCount = 0,
    this.isComparable = false,
  });

  final double? topLoad;
  final String? loadUnit;
  final int? totalReps;
  final double? totalVolume;
  final double? averageRpe;
  final int prescribedCompletedCount;
  final int extraCompletedCount;
  final bool isComparable;
}

class _ParsedSet {
  const _ParsedSet({
    required this.load,
    required this.reps,
    required this.isExtraSet,
    this.rpe,
    this.displayLoad,
    this.displayReps,
  });

  final ParsedLoad load;
  final int? reps;
  final double? rpe;
  final bool isExtraSet;
  final String? displayLoad;
  final String? displayReps;
}
