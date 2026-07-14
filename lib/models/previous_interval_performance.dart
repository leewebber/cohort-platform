import 'interval_modality.dart';

/// One completed work rep from a prior comparable interval session.
class PreviousIntervalRep {
  const PreviousIntervalRep({
    required this.repNumber,
    required this.displayLine,
    this.actualDistanceMeters,
    this.actualDurationSeconds,
    this.actualPaceSecondsPerKm,
    this.averageHeartRate,
    this.maxHeartRate,
    this.rpe,
    this.skipped = false,
  });

  final int repNumber;
  final double? actualDistanceMeters;
  final int? actualDurationSeconds;
  final double? actualPaceSecondsPerKm;
  final int? averageHeartRate;
  final int? maxHeartRate;
  final int? rpe;
  final bool skipped;

  /// Compact athlete-facing summary, e.g. `800 m · 3:08 · 3:55/km · RPE 7`.
  final String displayLine;
}

/// Summarised performance from the athlete's latest completed comparable session.
class PreviousIntervalPerformance {
  const PreviousIntervalPerformance({
    required this.trainingSessionId,
    required this.protocolId,
    required this.modality,
    required this.reps,
    required this.completedRepCount,
    this.completedAt,
    this.averageDurationSeconds,
    this.averagePaceSecondsPerKm,
    this.paceDropOffSeconds,
    this.averageRpe,
  });

  final int trainingSessionId;
  final String protocolId;
  final DateTime? completedAt;
  final IntervalModality modality;
  final List<PreviousIntervalRep> reps;
  final double? averageDurationSeconds;
  final double? averagePaceSecondsPerKm;
  final double? paceDropOffSeconds;
  final double? averageRpe;
  final int completedRepCount;

  bool get hasHistory => reps.isNotEmpty;

  static const todayOpportunities = [
    'More consistent pacing',
    'Faster average pace',
    'Smaller drop-off',
    'Lower effort',
    'Better control',
  ];
}
