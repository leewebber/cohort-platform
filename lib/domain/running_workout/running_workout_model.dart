/// Immutable RunningWorkout v1. Not execution or calculation authority.

enum RunningWorkoutProvenanceKind { authored, projected, unsupported }

enum RunningStepRole { warmUp, work, recovery, rest, coolDown, open }

enum RunningDurationKind { time, distance, manualLap }

enum RunningTargetKind {
  none,
  pace,
  paceRange,
  heartRate,
  heartRateRange,
  heartRateZoneRef,
  power,
  powerRange,
  cadenceRange,
  rpe,
  rpeRange,
}

/// Canonical distance: millimetres. Canonical pace: ms / km.
/// Cadence: steps per minute. RPE: CR10 integer 1–10.
class RunningDuration {
  const RunningDuration._({required this.kind, this.milliseconds, this.millimetres});

  const RunningDuration.time(int milliseconds)
    : this._(kind: RunningDurationKind.time, milliseconds: milliseconds);

  const RunningDuration.distance(int millimetres)
    : this._(kind: RunningDurationKind.distance, millimetres: millimetres);

  const RunningDuration.manualLap() : this._(kind: RunningDurationKind.manualLap);

  final RunningDurationKind kind;
  final int? milliseconds;
  final int? millimetres;

  @override
  bool operator ==(Object other) {
    return other is RunningDuration &&
        other.kind == kind &&
        other.milliseconds == milliseconds &&
        other.millimetres == millimetres;
  }

  @override
  int get hashCode => Object.hash(kind, milliseconds, millimetres);
}

class RunningTarget {
  const RunningTarget._({
    required this.kind,
    this.paceMillisecondsPerKilometre,
    this.paceMillisecondsPerKilometreLow,
    this.paceMillisecondsPerKilometreHigh,
    this.heartRateBpm,
    this.heartRateBpmLow,
    this.heartRateBpmHigh,
    this.heartRateZoneRef,
    this.powerWatts,
    this.powerWattsLow,
    this.powerWattsHigh,
    this.cadenceStepsPerMinuteLow,
    this.cadenceStepsPerMinuteHigh,
    this.rpeCr10,
    this.rpeCr10Low,
    this.rpeCr10High,
  });

  const RunningTarget.none() : this._(kind: RunningTargetKind.none);

  const RunningTarget.pace(int paceMillisecondsPerKilometre)
    : this._(
        kind: RunningTargetKind.pace,
        paceMillisecondsPerKilometre: paceMillisecondsPerKilometre,
      );

  const RunningTarget.paceRange({
    required int low,
    required int high,
  }) : this._(
         kind: RunningTargetKind.paceRange,
         paceMillisecondsPerKilometreLow: low,
         paceMillisecondsPerKilometreHigh: high,
       );

  const RunningTarget.heartRate(int heartRateBpm)
    : this._(kind: RunningTargetKind.heartRate, heartRateBpm: heartRateBpm);

  const RunningTarget.heartRateRange({required int low, required int high})
    : this._(
        kind: RunningTargetKind.heartRateRange,
        heartRateBpmLow: low,
        heartRateBpmHigh: high,
      );

  const RunningTarget.heartRateZoneRef(String heartRateZoneRef)
    : this._(
        kind: RunningTargetKind.heartRateZoneRef,
        heartRateZoneRef: heartRateZoneRef,
      );

  const RunningTarget.power(int powerWatts)
    : this._(kind: RunningTargetKind.power, powerWatts: powerWatts);

  const RunningTarget.powerRange({required int low, required int high})
    : this._(
        kind: RunningTargetKind.powerRange,
        powerWattsLow: low,
        powerWattsHigh: high,
      );

  const RunningTarget.cadenceRange({required int low, required int high})
    : this._(
        kind: RunningTargetKind.cadenceRange,
        cadenceStepsPerMinuteLow: low,
        cadenceStepsPerMinuteHigh: high,
      );

  const RunningTarget.rpe(int rpeCr10)
    : this._(kind: RunningTargetKind.rpe, rpeCr10: rpeCr10);

  const RunningTarget.rpeRange({required int low, required int high})
    : this._(
        kind: RunningTargetKind.rpeRange,
        rpeCr10Low: low,
        rpeCr10High: high,
      );

  final RunningTargetKind kind;
  final int? paceMillisecondsPerKilometre;
  final int? paceMillisecondsPerKilometreLow;
  final int? paceMillisecondsPerKilometreHigh;
  final int? heartRateBpm;
  final int? heartRateBpmLow;
  final int? heartRateBpmHigh;
  final String? heartRateZoneRef;
  final int? powerWatts;
  final int? powerWattsLow;
  final int? powerWattsHigh;
  final int? cadenceStepsPerMinuteLow;
  final int? cadenceStepsPerMinuteHigh;
  final int? rpeCr10;
  final int? rpeCr10Low;
  final int? rpeCr10High;

  @override
  bool operator ==(Object other) {
    return other is RunningTarget &&
        other.kind == kind &&
        other.paceMillisecondsPerKilometre == paceMillisecondsPerKilometre &&
        other.paceMillisecondsPerKilometreLow ==
            paceMillisecondsPerKilometreLow &&
        other.paceMillisecondsPerKilometreHigh ==
            paceMillisecondsPerKilometreHigh &&
        other.heartRateBpm == heartRateBpm &&
        other.heartRateBpmLow == heartRateBpmLow &&
        other.heartRateBpmHigh == heartRateBpmHigh &&
        other.heartRateZoneRef == heartRateZoneRef &&
        other.powerWatts == powerWatts &&
        other.powerWattsLow == powerWattsLow &&
        other.powerWattsHigh == powerWattsHigh &&
        other.cadenceStepsPerMinuteLow == cadenceStepsPerMinuteLow &&
        other.cadenceStepsPerMinuteHigh == cadenceStepsPerMinuteHigh &&
        other.rpeCr10 == rpeCr10 &&
        other.rpeCr10Low == rpeCr10Low &&
        other.rpeCr10High == rpeCr10High;
  }

  @override
  int get hashCode => Object.hashAll([
    kind,
    paceMillisecondsPerKilometre,
    paceMillisecondsPerKilometreLow,
    paceMillisecondsPerKilometreHigh,
    heartRateBpm,
    heartRateBpmLow,
    heartRateBpmHigh,
    heartRateZoneRef,
    powerWatts,
    powerWattsLow,
    powerWattsHigh,
    cadenceStepsPerMinuteLow,
    cadenceStepsPerMinuteHigh,
    rpeCr10,
    rpeCr10Low,
    rpeCr10High,
  ]);
}

sealed class RunningWorkoutNode {
  const RunningWorkoutNode();
}

class RunningAtomicStep extends RunningWorkoutNode {
  const RunningAtomicStep({
    required this.stepId,
    required this.role,
    required this.duration,
    this.target = const RunningTarget.none(),
    this.notes,
  });

  final String stepId;
  final RunningStepRole role;
  final RunningDuration duration;
  final RunningTarget target;
  final String? notes;

  @override
  bool operator ==(Object other) {
    return other is RunningAtomicStep &&
        other.stepId == stepId &&
        other.role == role &&
        other.duration == duration &&
        other.target == target &&
        other.notes == notes;
  }

  @override
  int get hashCode => Object.hash(stepId, role, duration, target, notes);
}

class RunningRepeatGroup extends RunningWorkoutNode {
  const RunningRepeatGroup({
    required this.groupId,
    required this.count,
    required this.steps,
  });

  final String groupId;
  final int count;
  final List<RunningAtomicStep> steps;

  @override
  bool operator ==(Object other) {
    return other is RunningRepeatGroup &&
        other.groupId == groupId &&
        other.count == count &&
        _listEquals(other.steps, steps);
  }

  @override
  int get hashCode => Object.hash(groupId, count, Object.hashAll(steps));
}

class RunningWorkoutProvenance {
  const RunningWorkoutProvenance({
    required this.kind,
    required this.sourceKind,
    this.sourceFormat,
    required this.idDerivation,
  });

  final RunningWorkoutProvenanceKind kind;
  final String sourceKind;
  final String? sourceFormat;
  final String idDerivation;

  @override
  bool operator ==(Object other) {
    return other is RunningWorkoutProvenance &&
        other.kind == kind &&
        other.sourceKind == sourceKind &&
        other.sourceFormat == sourceFormat &&
        other.idDerivation == idDerivation;
  }

  @override
  int get hashCode => Object.hash(kind, sourceKind, sourceFormat, idDerivation);
}

class RunningWorkout {
  const RunningWorkout({
    this.schemaVersion = 1,
    required this.workoutId,
    required this.steps,
    this.title,
    this.intent,
    this.notes,
    this.provenance,
  });

  final int schemaVersion;
  final String workoutId;
  final String? title;
  final String? intent;
  final String? notes;
  final RunningWorkoutProvenance? provenance;
  final List<RunningWorkoutNode> steps;

  @override
  bool operator ==(Object other) {
    return other is RunningWorkout &&
        other.schemaVersion == schemaVersion &&
        other.workoutId == workoutId &&
        other.title == title &&
        other.intent == intent &&
        other.notes == notes &&
        other.provenance == provenance &&
        _listEquals(other.steps, steps);
  }

  @override
  int get hashCode => Object.hash(
    schemaVersion,
    workoutId,
    title,
    intent,
    notes,
    provenance,
    Object.hashAll(steps),
  );
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
