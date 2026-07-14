import 'circuit_format.dart';
import 'circuit_score_type.dart';

/// Summarised performance from the athlete's latest completed comparable circuit.
class PreviousCircuitPerformance {
  const PreviousCircuitPerformance({
    required this.circuitFormat,
    required this.scoreType,
    required this.displaySummary,
    required this.todayOpportunities,
    this.completedAt,
    this.elapsedDuration,
    this.completedRounds,
    this.additionalReps,
    this.totalReps,
    this.completedIntervals,
    this.actualLoad,
    this.averageRpe,
    this.athleteNote,
    this.timeCapped = false,
    this.completedMovements,
  });

  final DateTime? completedAt;
  final CircuitFormat circuitFormat;
  final CircuitScoreType scoreType;
  final Duration? elapsedDuration;
  final int? completedRounds;
  final int? additionalReps;
  final int? totalReps;
  final int? completedIntervals;
  final String? actualLoad;
  final int? averageRpe;
  final String? athleteNote;
  final bool timeCapped;
  final int? completedMovements;

  /// Primary athlete-facing score line, e.g. `8 rounds + 12 reps` or `18:42`.
  final String displaySummary;

  /// Observational prompts for today's effort — never exact score targets.
  final List<String> todayOpportunities;

  bool get hasHistory => displaySummary.trim().isNotEmpty;

  static const defaultTodayOpportunities = [
    'More consistent pacing',
    'Complete one additional round',
    'Lower effort',
    'Cleaner movement quality',
    'Better consistency',
  ];
}
