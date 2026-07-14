import 'interval_data_source.dart';
import 'interval_metric_entry_source.dart';
import 'interval_phase_type.dart';

/// One executable phase unit in an interval session timeline.
///
/// A repeated block expands into alternating [IntervalPhaseType.work] and
/// [IntervalPhaseType.recovery] entries. Warm-up, cool-down, and instruction
/// steps each map to a single entry.
///
/// Targets are coach prescription snapshots (text). Actuals are normalized
/// numeric values where known; display formatting belongs in services/UI.
///
/// See `07 Documentation/37_Interval_Execution_Engine.md`.
class IntervalRepEntry {
  const IntervalRepEntry({
    required this.localId,
    required this.blockIndex,
    required this.repNumber,
    required this.phaseType,
    this.targetDistance,
    this.targetDuration,
    this.targetPace,
    this.targetIntensity,
    this.recoveryDuration,
    this.actualDistance,
    this.actualDuration,
    this.actualPace,
    this.averageHeartRate,
    this.maxHeartRate,
    this.rpe,
    this.completed = false,
    this.skipped = false,
    this.dataSource = IntervalDataSource.manual,
    this.distanceSource = IntervalMetricEntrySource.unset,
    this.durationSource = IntervalMetricEntrySource.unset,
    this.paceSource = IntervalMetricEntrySource.unset,
    this.athleteNote,
  });

  /// Client-stable identity for in-session state and resume hydration.
  final String localId;

  /// Index of the parent [IntervalBlock] within [IntervalSessionPlan.blocks].
  final int blockIndex;

  /// Repetition number within the block (1-based). Non-repeated phases use 1.
  final int repNumber;

  /// Whether this entry is warm-up, work, recovery, cool-down, or instruction.
  final IntervalPhaseType phaseType;

  /// Prescribed distance snapshot (e.g. `400 m`, `500 m`, `0.25 mi`).
  final String? targetDistance;

  /// Prescribed duration snapshot (e.g. `3:00`, `90 s`).
  final String? targetDuration;

  /// Prescribed pace snapshot (e.g. `4:30 / km`, `2:05 / 500 m`).
  final String? targetPace;

  /// Prescribed intensity snapshot (e.g. `RPE 8`, `Z4`, `85% FTP`).
  final String? targetIntensity;

  /// Prescribed recovery after a work rep (e.g. `90 s`, `2:00`).
  ///
  /// Populated on work entries when recovery follows inline in programming.
  /// Recovery-phase entries use [targetDuration] instead.
  final String? recoveryDuration;

  /// Performed distance in metres when known.
  final double? actualDistance;

  /// Performed duration when known.
  final Duration? actualDuration;

  /// Performed pace in seconds per kilometre when known.
  ///
  /// Modality-specific display (e.g. /500 m for rowing) is derived in services.
  final double? actualPace;

  final int? averageHeartRate;
  final int? maxHeartRate;

  /// Optional post-effort RPE (1–10).
  final int? rpe;

  final bool completed;

  /// True when the athlete skipped this phase without full execution.
  final bool skipped;

  /// Whether actual values were entered manually or imported from a device/app.
  final IntervalDataSource dataSource;

  /// Whether [actualDistance] was entered manually or auto-calculated.
  final IntervalMetricEntrySource distanceSource;

  /// Whether [actualDuration] was entered manually or auto-calculated.
  final IntervalMetricEntrySource durationSource;

  /// Whether [actualPace] was entered manually or auto-calculated.
  final IntervalMetricEntrySource paceSource;

  /// Optional free-text note for this phase row.
  final String? athleteNote;

  bool get isWorkPhase => phaseType == IntervalPhaseType.work;

  bool get isRecoveryPhase => phaseType == IntervalPhaseType.recovery;

  bool get hasStartedData {
    return actualDistance != null ||
        actualDuration != null ||
        actualPace != null ||
        averageHeartRate != null ||
        maxHeartRate != null ||
        rpe != null;
  }

  IntervalRepEntry copyWith({
    String? localId,
    int? blockIndex,
    int? repNumber,
    IntervalPhaseType? phaseType,
    String? targetDistance,
    String? targetDuration,
    String? targetPace,
    String? targetIntensity,
    String? recoveryDuration,
    double? actualDistance,
    Duration? actualDuration,
    double? actualPace,
    int? averageHeartRate,
    int? maxHeartRate,
    int? rpe,
    bool? completed,
    bool? skipped,
    IntervalDataSource? dataSource,
    IntervalMetricEntrySource? distanceSource,
    IntervalMetricEntrySource? durationSource,
    IntervalMetricEntrySource? paceSource,
    String? athleteNote,
    bool clearActualDistance = false,
    bool clearActualDuration = false,
    bool clearActualPace = false,
    bool clearAverageHeartRate = false,
    bool clearMaxHeartRate = false,
    bool clearRpe = false,
    bool clearAthleteNote = false,
  }) {
    return IntervalRepEntry(
      localId: localId ?? this.localId,
      blockIndex: blockIndex ?? this.blockIndex,
      repNumber: repNumber ?? this.repNumber,
      phaseType: phaseType ?? this.phaseType,
      targetDistance: targetDistance ?? this.targetDistance,
      targetDuration: targetDuration ?? this.targetDuration,
      targetPace: targetPace ?? this.targetPace,
      targetIntensity: targetIntensity ?? this.targetIntensity,
      recoveryDuration: recoveryDuration ?? this.recoveryDuration,
      actualDistance:
          clearActualDistance ? null : (actualDistance ?? this.actualDistance),
      actualDuration:
          clearActualDuration ? null : (actualDuration ?? this.actualDuration),
      actualPace: clearActualPace ? null : (actualPace ?? this.actualPace),
      averageHeartRate: clearAverageHeartRate
          ? null
          : (averageHeartRate ?? this.averageHeartRate),
      maxHeartRate:
          clearMaxHeartRate ? null : (maxHeartRate ?? this.maxHeartRate),
      rpe: clearRpe ? null : (rpe ?? this.rpe),
      completed: completed ?? this.completed,
      skipped: skipped ?? this.skipped,
      dataSource: dataSource ?? this.dataSource,
      distanceSource: distanceSource ?? this.distanceSource,
      durationSource: durationSource ?? this.durationSource,
      paceSource: paceSource ?? this.paceSource,
      athleteNote: clearAthleteNote ? null : (athleteNote ?? this.athleteNote),
    );
  }
}
