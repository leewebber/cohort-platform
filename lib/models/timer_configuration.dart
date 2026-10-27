import '../core/utils/frozen_json.dart';
import '../domain/running_workout/running_workout_model.dart';
import '../domain/running_workout/running_workout_codec.dart';
import '../domain/running_workout/running_workout_validation.dart';
import 'authored_int_range.dart';
import 'circuit_capture_strategy.dart';
import 'workout_format.dart';

/// Typed timer settings for a Session block (M6).
///
/// Persisted as JSON; application code uses typed fields.
class TimerConfiguration {
  const TimerConfiguration({
    this.durationSeconds,
    this.durationSecondsRange,
    this.omitFinalRecovery = false,
    this.totalDurationSeconds,
    this.intervalSeconds,
    this.preparationSeconds,
    this.timeCapSeconds,
    this.stopwatchEnabled = false,
    this.workSeconds,
    this.restSeconds,
    this.rounds,
    this.targetRounds,
    this.restBetweenRoundsSeconds,
    this.timerNotes,
    this.tracking = const [],
    this.stations = const [],
    this.captureStrategy,
    this.runningWorkout,
  });

  final int? durationSeconds;
  final AuthoredIntRange? durationSecondsRange;
  final bool omitFinalRecovery;
  final int? totalDurationSeconds;
  final int? intervalSeconds;
  final int? preparationSeconds;
  final int? timeCapSeconds;
  final bool stopwatchEnabled;
  final int? workSeconds;
  final int? restSeconds;
  final int? rounds;
  final int? targetRounds;
  final int? restBetweenRoundsSeconds;
  final String? timerNotes;
  final List<String> tracking;
  final List<TimerStationSpec> stations;
  final CircuitCaptureStrategy? captureStrategy;

  /// Exact authored body, distinct from the optional B2 advisory policy.
  final RunningWorkout? runningWorkout;

  int? get emomTotalSeconds =>
      totalDurationSeconds ??
      (durationSeconds != null && durationSeconds! > 0
          ? durationSeconds
          : null);

  int? get effectiveTargetRounds =>
      targetRounds ?? (rounds != null && rounds! > 0 ? rounds : null);

  TimerConfiguration copyWith({
    int? durationSeconds,
    int? totalDurationSeconds,
    int? intervalSeconds,
    int? preparationSeconds,
    int? timeCapSeconds,
    bool? stopwatchEnabled,
    int? workSeconds,
    int? restSeconds,
    int? rounds,
    int? targetRounds,
    int? restBetweenRoundsSeconds,
    String? timerNotes,
    List<String>? tracking,
    List<TimerStationSpec>? stations,
    CircuitCaptureStrategy? captureStrategy,
  }) {
    return TimerConfiguration(
      omitFinalRecovery: omitFinalRecovery,
      durationSecondsRange: durationSecondsRange,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      intervalSeconds: intervalSeconds ?? this.intervalSeconds,
      preparationSeconds: preparationSeconds ?? this.preparationSeconds,
      timeCapSeconds: timeCapSeconds ?? this.timeCapSeconds,
      stopwatchEnabled: stopwatchEnabled ?? this.stopwatchEnabled,
      workSeconds: workSeconds ?? this.workSeconds,
      restSeconds: restSeconds ?? this.restSeconds,
      rounds: rounds ?? this.rounds,
      targetRounds: targetRounds ?? this.targetRounds,
      restBetweenRoundsSeconds:
          restBetweenRoundsSeconds ?? this.restBetweenRoundsSeconds,
      timerNotes: timerNotes ?? this.timerNotes,
      tracking: tracking ?? this.tracking,
      stations: stations ?? this.stations,
      captureStrategy: captureStrategy ?? this.captureStrategy,
      runningWorkout: runningWorkout,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (omitFinalRecovery) 'omitFinalRecovery': true,
      if (durationSecondsRange != null)
        'durationRangeSeconds': durationSecondsRange!.toJson(),
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
      if (totalDurationSeconds != null)
        'totalDurationSeconds': totalDurationSeconds,
      if (intervalSeconds != null) 'intervalSeconds': intervalSeconds,
      if (preparationSeconds != null) 'preparationSeconds': preparationSeconds,
      if (timeCapSeconds != null) 'timeCapSeconds': timeCapSeconds,
      'stopwatchEnabled': stopwatchEnabled,
      if (workSeconds != null) 'workSeconds': workSeconds,
      if (restSeconds != null) 'restSeconds': restSeconds,
      if (rounds != null) 'rounds': rounds,
      if (targetRounds != null) 'targetRounds': targetRounds,
      if (restBetweenRoundsSeconds != null)
        'restBetweenRoundsSeconds': restBetweenRoundsSeconds,
      if (timerNotes != null && timerNotes!.trim().isNotEmpty)
        'timerNotes': timerNotes!.trim(),
      if (tracking.isNotEmpty) 'tracking': tracking,
      if (stations.isNotEmpty)
        'stations': stations.map((station) => station.toJson()).toList(),
      if (captureStrategy != null) 'capture_strategy': captureStrategy!.dbValue,
      if (runningWorkout != null)
        'running_workout': const RunningWorkoutCodec().toJson(runningWorkout!),
    };
  }

  factory TimerConfiguration.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const TimerConfiguration();
    }

    final duration = _int(json['durationSeconds'] ?? json['duration_seconds']);
    final explicitTotal = _int(
      json['totalDurationSeconds'] ?? json['total_duration_seconds'],
    );
    final authoredRounds = _int(json['rounds']);
    final runningRaw = json['running_workout'];
    if (json.containsKey('running_workout') && runningRaw is! Map) {
      throw const FormatException('Invalid authored running workout.');
    }
    return TimerConfiguration(
      omitFinalRecovery: json['omitFinalRecovery'] == true,
      durationSecondsRange: json['durationRangeSeconds'] == null
          ? null
          : AuthoredIntRange.fromJson(json['durationRangeSeconds']),
      durationSeconds: duration,
      totalDurationSeconds: explicitTotal ?? duration,
      intervalSeconds: _int(
        json['intervalSeconds'] ?? json['interval_seconds'],
      ),
      preparationSeconds: _int(
        json['preparationSeconds'] ?? json['preparation_seconds'],
      ),
      timeCapSeconds: _int(json['timeCapSeconds'] ?? json['time_cap_seconds']),
      stopwatchEnabled:
          json['stopwatchEnabled'] == true || json['stopwatch_enabled'] == true,
      workSeconds: _int(json['workSeconds'] ?? json['work_seconds']),
      restSeconds: _int(
        json['restSeconds'] ?? json['rest_seconds'] ?? json['recovery_seconds'],
      ),
      rounds: authoredRounds,
      targetRounds:
          _int(json['targetRounds'] ?? json['target_rounds']) ?? authoredRounds,
      restBetweenRoundsSeconds: _int(
        json['restBetweenRoundsSeconds'] ??
            json['rest_between_rounds_seconds'] ??
            json['between_round_recovery_seconds'],
      ),
      timerNotes: (json['timerNotes'] ?? json['timer_notes'])?.toString(),
      tracking: _tracking(json['tracking'] ?? json['record']),
      stations: TimerStationSpec.listFromJson(json),
      captureStrategy: CircuitCaptureStrategyDb.tryParse(
        (json['capture_strategy'] ?? json['captureStrategy'])?.toString(),
      ),
      runningWorkout: runningRaw is Map
          ? const RunningWorkoutCodec().decodeMap(
              Map<String, dynamic>.from(runningRaw),
            )
          : null,
    );
  }

  static int? _int(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static List<String> _tracking(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    final single = value?.toString().trim();
    if (single == null || single.isEmpty) return const [];
    return [single];
  }

  /// Clears fields incompatible with [format].
  static TimerConfiguration normalizedForFormat(
    WorkoutFormat format,
    TimerConfiguration? current,
  ) {
    final base = current ?? const TimerConfiguration();
    if (base.runningWorkout != null) {
      if (format != WorkoutFormat.steadyState) {
        throw const FormatException(
          'Authored running cannot be converted to this timer format.',
        );
      }
      return base;
    }
    if (format == WorkoutFormat.none) {
      return const TimerConfiguration();
    }

    return switch (format) {
      WorkoutFormat.amrap => TimerConfiguration(
        durationSeconds: base.durationSeconds,
        timerNotes: base.timerNotes,
      ),
      WorkoutFormat.emom => TimerConfiguration(
        totalDurationSeconds: base.emomTotalSeconds,
        durationSeconds: base.durationSeconds,
        intervalSeconds: base.intervalSeconds,
        preparationSeconds: base.preparationSeconds,
        timerNotes: base.timerNotes,
        stations: base.stations,
        captureStrategy: base.captureStrategy,
      ),
      WorkoutFormat.forTime => TimerConfiguration(
        timeCapSeconds: base.timeCapSeconds,
        stopwatchEnabled: true,
        timerNotes: base.timerNotes,
      ),
      WorkoutFormat.steadyState => TimerConfiguration(
        durationSecondsRange: base.durationSecondsRange,
        durationSeconds: base.durationSeconds,
        timerNotes: base.timerNotes,
      ),
      WorkoutFormat.intervals => TimerConfiguration(
        omitFinalRecovery: base.omitFinalRecovery,
        workSeconds: base.workSeconds,
        restSeconds: base.restSeconds,
        rounds: base.rounds,
        preparationSeconds: base.preparationSeconds,
        timerNotes: base.timerNotes,
        tracking: base.tracking,
      ),
      WorkoutFormat.tabata => TimerConfiguration(
        workSeconds: base.workSeconds ?? 20,
        restSeconds: base.restSeconds ?? 10,
        rounds: base.rounds ?? 8,
        timerNotes: base.timerNotes,
      ),
      WorkoutFormat.rounds => TimerConfiguration(
        targetRounds: base.effectiveTargetRounds,
        rounds: base.rounds,
        restBetweenRoundsSeconds: base.restBetweenRoundsSeconds,
        timerNotes: base.timerNotes,
        stations: base.stations,
        captureStrategy: base.captureStrategy,
      ),
      WorkoutFormat.other => TimerConfiguration(
        durationSeconds: base.durationSeconds,
        timerNotes: base.timerNotes,
      ),
      WorkoutFormat.none => const TimerConfiguration(),
    };
  }

  List<String> validateForFormat(WorkoutFormat format) {
    final messages = <String>[];
    if (runningWorkout case final workout?) {
      messages.addAll(
        const RunningWorkoutValidator()
            .validate(workout)
            .errors
            .map((e) => e.message),
      );
      var total = 0;
      var frames = 0;
      void step(RunningAtomicStep step, int count) {
        final ms = step.duration.milliseconds;
        if (step.duration.kind != RunningDurationKind.time ||
            ms == null ||
            ms <= 0 ||
            ms % 1000 != 0) {
          messages.add(
            'Only positive whole-second time-ended running steps are supported.',
          );
        } else {
          total += ms * count;
          frames += count;
        }
      }

      for (final node in workout.steps) {
        switch (node) {
          case RunningAtomicStep():
            step(node, 1);
          case RunningRepeatGroup():
            for (final child in node.steps) {
              step(child, node.count);
            }
        }
      }
      if (format != WorkoutFormat.steadyState ||
          durationSeconds == null ||
          durationSeconds! * 1000 != total ||
          frames > 512 ||
          durationSecondsRange != null ||
          omitFinalRecovery ||
          workSeconds != null ||
          restSeconds != null ||
          rounds != null ||
          preparationSeconds != null ||
          timeCapSeconds != null ||
          intervalSeconds != null ||
          stations.isNotEmpty ||
          captureStrategy != null ||
          restBetweenRoundsSeconds != null ||
          targetRounds != null ||
          stopwatchEnabled ||
          (totalDurationSeconds != null &&
              totalDurationSeconds != durationSeconds)) {
        messages.add(
          'Authored running requires one exact total duration and no conflicting timer settings.',
        );
      }
      return messages;
    }

    switch (format) {
      case WorkoutFormat.none:
        break;
      case WorkoutFormat.amrap:
        if (durationSeconds == null || durationSeconds! <= 0) {
          messages.add('AMRAP requires a duration.');
        }
      case WorkoutFormat.emom:
        if (emomTotalSeconds == null || emomTotalSeconds! <= 0) {
          messages.add('EMOM requires a total duration.');
        }
        if (intervalSeconds == null || intervalSeconds! <= 0) {
          messages.add('EMOM requires an interval length.');
        }
      case WorkoutFormat.forTime:
        break;
      case WorkoutFormat.steadyState:
        if (durationSecondsRange != null &&
            (!durationSecondsRange!.isValid ||
                durationSecondsRange!.min <= 0 ||
                (durationSeconds != null &&
                    !durationSecondsRange!.contains(durationSeconds!)))) {
          messages.add('Invalid duration choice window.');
        }
        if ((durationSeconds == null || durationSeconds! <= 0) &&
            durationSecondsRange == null) {
          messages.add('Steady state requires a duration.');
        }
      case WorkoutFormat.intervals:
        if (workSeconds == null || workSeconds! <= 0) {
          messages.add('Intervals require work duration.');
        }
        if (restSeconds == null || restSeconds! < 0) {
          messages.add('Intervals require rest duration.');
        }
        if (rounds == null || rounds! <= 0) {
          messages.add('Intervals require rounds.');
        }
      case WorkoutFormat.tabata:
        if (rounds == null || rounds! <= 0) {
          messages.add('Tabata requires rounds.');
        }
      case WorkoutFormat.rounds:
      case WorkoutFormat.other:
        break;
    }

    return messages;
  }

  bool isValidForFormat(WorkoutFormat format) =>
      validateForFormat(format).isEmpty;

  String summaryForFormat(WorkoutFormat format) {
    if (runningWorkout != null) {
      return 'Structured timed run · ${durationSeconds ?? 0}s total';
    }
    return switch (format) {
      WorkoutFormat.none => 'No timer',
      WorkoutFormat.amrap =>
        durationSeconds != null
            ? '${durationSeconds! ~/ 60} min AMRAP'
            : 'AMRAP',
      WorkoutFormat.emom =>
        '${emomTotalSeconds != null ? '${emomTotalSeconds! ~/ 60} min' : 'EMOM'} · ${intervalSeconds ?? '?'}s intervals',
      WorkoutFormat.forTime =>
        timeCapSeconds != null
            ? 'For Time · ${timeCapSeconds! ~/ 60} min cap'
            : 'For Time · Stopwatch',
      WorkoutFormat.steadyState =>
        durationSeconds != null
            ? '${durationSeconds! ~/ 60} min continuous'
            : 'Steady state',
      WorkoutFormat.intervals =>
        '${rounds ?? '?'} rounds · ${workSeconds ?? '?'}s work / ${restSeconds ?? '?'}s rest',
      WorkoutFormat.tabata =>
        '${rounds ?? 8} rounds · ${workSeconds ?? 20}s / ${restSeconds ?? 10}s',
      WorkoutFormat.rounds =>
        effectiveTargetRounds != null
            ? '$effectiveTargetRounds rounds'
            : 'Rounds',
      WorkoutFormat.other =>
        durationSeconds != null ? '${durationSeconds! ~/ 60} min' : 'Timer',
    };
  }
}

/// Authored station inside an EMOM or rounds timer_config payload.
class TimerStationSpec {
  const TimerStationSpec({
    required this.exerciseId,
    required this.position,
    this.minute,
    this.workSeconds,
    this.isRest = false,
    this.authoredDetails,
    this.calories,
    this.reps,
    this.distanceMeters,
    this.distanceText,
  });

  final String exerciseId;
  final int position;
  final int? minute;
  final int? workSeconds;
  final bool isRest;
  final Map<String, dynamic>? authoredDetails;
  final int? calories;
  final int? reps;
  final double? distanceMeters;
  final String? distanceText;

  Map<String, dynamic> toJson() => {
    if (!isRest) 'exercise': exerciseId,
    if (isRest) 'kind': 'rest',
    if (workSeconds != null) 'work_seconds': workSeconds,
    if (authoredDetails != null) 'authored_details': authoredDetails,
    'position': position,
    if (minute != null) 'minute': minute,
    if (calories != null) 'calories': calories,
    if (reps != null) 'reps': reps,
    if (distanceMeters != null) 'distance_m': distanceMeters,
    if (distanceMeters == null && distanceText != null)
      'distance_m': distanceText,
  };

  static List<TimerStationSpec> listFromJson(Map<String, dynamic> json) {
    final explicit = json['stations'];
    if (explicit is List) {
      return [
            for (var i = 0; i < explicit.length; i++)
              if (explicit[i] is Map)
                fromMap(Map<String, dynamic>.from(explicit[i] as Map), i + 1),
          ]
          .where((station) => (station.isRest || station.exerciseId.isNotEmpty))
          .toList(growable: false);
    }

    final alternating = json['alternating'];
    if (alternating is List) {
      return [
            for (var i = 0; i < alternating.length; i++)
              if (alternating[i] is Map)
                fromMap(
                  Map<String, dynamic>.from(alternating[i] as Map),
                  i + 1,
                ),
          ]
          .where((station) => (station.isRest || station.exerciseId.isNotEmpty))
          .toList(growable: false);
    }

    final sequence = json['round_sequence'];
    if (sequence is List) {
      return [
            for (var i = 0; i < sequence.length; i++)
              TimerStationSpec(
                exerciseId: sequence[i].toString().trim(),
                position: i + 1,
              ),
          ]
          .where((station) => (station.isRest || station.exerciseId.isNotEmpty))
          .toList(growable: false);
    }
    return const [];
  }

  static TimerStationSpec fromMap(
    Map<String, dynamic> json,
    int fallbackPosition,
  ) {
    final distance = json['distance_m'] ?? json['distanceMeters'];
    return TimerStationSpec(
      isRest: json['kind'] == 'rest',
      workSeconds: json['work_seconds'] as int?,
      authoredDetails: json['authored_details'] == null
          ? null
          : freezePrescriptionJson(json['authored_details'])
                as Map<String, dynamic>,
      exerciseId:
          (json['exercise'] ?? json['exercise_id'] ?? json['exerciseId'] ?? '')
              .toString()
              .trim(),
      position:
          TimerConfiguration._int(json['position'] ?? json['minute']) ??
          fallbackPosition,
      minute: TimerConfiguration._int(json['minute']),
      calories: TimerConfiguration._int(json['calories']),
      reps: TimerConfiguration._int(json['reps']),
      distanceMeters: distance is num
          ? distance.toDouble()
          : double.tryParse(distance?.toString() ?? ''),
      distanceText: distance is num
          ? null
          : (double.tryParse(distance?.toString() ?? '') == null
                ? distance?.toString().trim()
                : null),
    );
  }
}
