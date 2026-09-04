import '../models/active_performance_draft.dart';
import '../models/performance_result_data.dart';
import '../models/training_session_record.dart';

/// Deterministic implausible-pace rule for **sustained running** only.
///
/// An average pace faster than **2:30 /km** (150 seconds per kilometre,
/// about 24.0 km/h) is treated as obviously implausible for logged
/// endurance-running distance. That bound sits ahead of elite sustained
/// road-racing pace and is used as a confirmation warning, not a hard block.
///
/// Distance units `km`, `m`, and `mi` are converted to kilometres.
/// The rule is **not** applied to cycling, rowing, skiing, swimming, or
/// other non-running modalities.
class RunningPacePlausibility {
  const RunningPacePlausibility._();

  static const implausibleFasterThanSecondsPerKm = 150;
  static const runningDistanceUnits = {'km', 'm', 'mi'};
  static const nonRunningTokens = {
    'bike',
    'cycle',
    'cycling',
    'row',
    'rowing',
    'erg',
    'ski',
    'skiing',
    'skate',
    'swim',
    'swimming',
    'watt',
    'watts',
  };

  static bool isSustainedRunningContext({
    required String distanceUnit,
    String? workoutFormat,
    String? blockTitle,
    String? modality,
  }) {
    final unit = distanceUnit.trim().toLowerCase();
    if (!runningDistanceUnits.contains(unit)) return false;
    final haystack = [
      workoutFormat,
      blockTitle,
      modality,
    ].whereType<String>().map((value) => value.toLowerCase()).join(' ');
    return !nonRunningTokens.any(haystack.contains);
  }

  static double? secondsPerKm({
    required double? distance,
    required String distanceUnit,
    required int? durationSeconds,
  }) {
    if (distance == null ||
        durationSeconds == null ||
        distance <= 0 ||
        durationSeconds <= 0) {
      return null;
    }
    final km = _toKilometres(distance, distanceUnit);
    if (km == null || km <= 0) return null;
    return durationSeconds / km;
  }

  static String? formatPaceClock(double? secondsPerKm) {
    if (secondsPerKm == null || secondsPerKm <= 0) return null;
    final total = secondsPerKm.round();
    final minutes = total ~/ 60;
    final seconds = total % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  static RunningPaceWarning? fromDraft(ActivePerformanceDraft draft) {
    for (final block in draft.blockDrafts) {
      final warning = fromResultData(
        resultData: block.resultData,
        workoutFormat: block.blockSnapshot.workoutFormat.name,
        blockTitle: block.blockSnapshot.title,
      );
      if (warning != null) return warning;
    }
    return null;
  }

  static RunningPaceWarning? fromRecord(TrainingSessionRecord record) {
    for (final block in record.blockResults) {
      final warning = fromResultData(
        resultData: block.resultData,
        workoutFormat: block.blockSnapshot.workoutFormat.name,
        blockTitle: block.blockSnapshot.title,
      );
      if (warning != null) return warning;
    }
    return null;
  }

  static RunningPaceWarning? fromResultData({
    required PerformanceResultData? resultData,
    String? workoutFormat,
    String? blockTitle,
    String? modality,
  }) {
    final distance = switch (resultData) {
      EnduranceResultData data => data.distance,
      DistanceResultData data => data.distance,
      _ => null,
    };
    final unit = switch (resultData) {
      EnduranceResultData data => data.distanceUnit,
      DistanceResultData data => data.distanceUnit,
      _ => null,
    };
    final duration = switch (resultData) {
      EnduranceResultData data => data.durationSeconds,
      DistanceResultData data => data.durationSeconds,
      _ => null,
    };
    if (unit == null) return null;
    return warning(
      distance: distance,
      distanceUnit: unit,
      durationSeconds: duration,
      workoutFormat: workoutFormat,
      blockTitle: blockTitle,
      modality: modality,
    );
  }

  static RunningPaceWarning? warning({
    required double? distance,
    required String distanceUnit,
    required int? durationSeconds,
    String? workoutFormat,
    String? blockTitle,
    String? modality,
  }) {
    if (!isSustainedRunningContext(
      distanceUnit: distanceUnit,
      workoutFormat: workoutFormat,
      blockTitle: blockTitle,
      modality: modality,
    )) {
      return null;
    }
    final pace = secondsPerKm(
      distance: distance,
      distanceUnit: distanceUnit,
      durationSeconds: durationSeconds,
    );
    if (pace == null || pace >= implausibleFasterThanSecondsPerKm) {
      return null;
    }
    final clock = formatPaceClock(pace)!;
    return RunningPaceWarning(
      secondsPerKm: pace,
      paceLabel: '$clock/km',
      message:
          'This result implies an average pace of $clock/km. '
          'Check your duration and distance.',
    );
  }

  static double? _toKilometres(double distance, String unit) {
    return switch (unit.trim().toLowerCase()) {
      'km' => distance,
      'm' => distance / 1000,
      'mi' => distance * 1.60934,
      _ => null,
    };
  }
}

class RunningPaceWarning {
  const RunningPaceWarning({
    required this.secondsPerKm,
    required this.paceLabel,
    required this.message,
  });

  final double secondsPerKm;
  final String paceLabel;
  final String message;
}
