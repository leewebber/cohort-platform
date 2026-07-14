import 'circuit_format.dart';
import 'circuit_movement_prescription.dart';
import 'circuit_score_type.dart';

/// Immutable programmed circuit session derived from protocol steps.
///
/// Built by a circuit plan builder service before execution starts. Actual
/// performance lives on [CircuitPerformanceEntry] inside
/// [CircuitSessionExecutionState].
///
/// See `07 Documentation/39_Circuit_Execution_Engine.md`.
class CircuitSessionPlan {
  const CircuitSessionPlan({
    required this.sessionTitle,
    required this.format,
    required this.scoreType,
    required this.movements,
    this.protocolId,
    this.prescribedRounds,
    this.timeCap,
    this.totalDuration,
    this.workInterval,
    this.restInterval,
    this.intervalCount,
    this.scoringMethodLabel,
    this.instructions,
    this.benchmarkName,
  });

  final String sessionTitle;
  final CircuitFormat format;
  final CircuitScoreType scoreType;
  final List<CircuitMovementPrescription> movements;
  final String? protocolId;

  /// Prescribed round count when the format uses fixed rounds.
  final int? prescribedRounds;

  /// Maximum allowed duration when a cap applies.
  final Duration? timeCap;

  /// Total programmed session duration when distinct from [timeCap].
  final Duration? totalDuration;

  /// Work interval for EMOM / interval-clock formats.
  final Duration? workInterval;

  /// Optional rest between rounds or intervals.
  final Duration? restInterval;

  /// Number of programmed intervals for EMOM / interval-clock formats.
  final int? intervalCount;

  /// Athlete-facing explanation of how today is scored.
  final String? scoringMethodLabel;

  /// Compiled session instructions from protocol or instruction steps.
  final String? instructions;

  /// Named benchmark identifier when [format] is [CircuitFormat.benchmark].
  final String? benchmarkName;

  int get movementCount => movements.length;

  String get resolvedScoringLabel =>
      scoringMethodLabel ?? scoreType.athleteSummary;

  CircuitMovementPrescription? movementByLocalId(String localId) {
    for (final movement in movements) {
      if (movement.localId == localId) {
        return movement;
      }
    }

    return null;
  }
}
