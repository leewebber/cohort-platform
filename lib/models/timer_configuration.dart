import 'workout_format.dart';

/// Typed timer settings for a Session block (M6).
///
/// Persisted as JSON; application code uses typed fields.
class TimerConfiguration {
  const TimerConfiguration({
    this.durationSeconds,
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
  });

  final int? durationSeconds;
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
  }) {
    return TimerConfiguration(
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
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
    };
  }

  factory TimerConfiguration.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const TimerConfiguration();
    }

    return TimerConfiguration(
      durationSeconds: _int(json['durationSeconds'] ?? json['duration_seconds']),
      totalDurationSeconds: _int(
        json['totalDurationSeconds'] ?? json['total_duration_seconds'],
      ),
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
        json['restSeconds'] ??
            json['rest_seconds'] ??
            json['recovery_seconds'],
      ),
      rounds: _int(json['rounds']),
      targetRounds: _int(json['targetRounds'] ?? json['target_rounds']),
      restBetweenRoundsSeconds: _int(
        json['restBetweenRoundsSeconds'] ??
            json['rest_between_rounds_seconds'] ??
            json['between_round_recovery_seconds'],
      ),
      timerNotes: (json['timerNotes'] ?? json['timer_notes'])?.toString(),
      tracking: _tracking(json['tracking'] ?? json['record']),
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
    if (format == WorkoutFormat.none) {
      return const TimerConfiguration();
    }

    final base = current ?? const TimerConfiguration();

    return switch (format) {
      WorkoutFormat.amrap => TimerConfiguration(
        durationSeconds: base.durationSeconds,
        timerNotes: base.timerNotes,
      ),
      WorkoutFormat.emom => TimerConfiguration(
        totalDurationSeconds: base.totalDurationSeconds,
        intervalSeconds: base.intervalSeconds,
        preparationSeconds: base.preparationSeconds,
        timerNotes: base.timerNotes,
      ),
      WorkoutFormat.forTime => TimerConfiguration(
        timeCapSeconds: base.timeCapSeconds,
        stopwatchEnabled: true,
        timerNotes: base.timerNotes,
      ),
      WorkoutFormat.steadyState => TimerConfiguration(
        durationSeconds: base.durationSeconds,
        timerNotes: base.timerNotes,
      ),
      WorkoutFormat.intervals => TimerConfiguration(
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
        targetRounds: base.targetRounds,
        restBetweenRoundsSeconds: base.restBetweenRoundsSeconds,
        timerNotes: base.timerNotes,
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

    switch (format) {
      case WorkoutFormat.none:
        break;
      case WorkoutFormat.amrap:
        if (durationSeconds == null || durationSeconds! <= 0) {
          messages.add('AMRAP requires a duration.');
        }
      case WorkoutFormat.emom:
        if (totalDurationSeconds == null || totalDurationSeconds! <= 0) {
          messages.add('EMOM requires a total duration.');
        }
        if (intervalSeconds == null || intervalSeconds! <= 0) {
          messages.add('EMOM requires an interval length.');
        }
      case WorkoutFormat.forTime:
        break;
      case WorkoutFormat.steadyState:
        if (durationSeconds == null || durationSeconds! <= 0) {
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
    return switch (format) {
      WorkoutFormat.none => 'No timer',
      WorkoutFormat.amrap =>
        durationSeconds != null
            ? '${durationSeconds! ~/ 60} min AMRAP'
            : 'AMRAP',
      WorkoutFormat.emom =>
        '${totalDurationSeconds != null ? '${totalDurationSeconds! ~/ 60} min' : 'EMOM'} · ${intervalSeconds ?? '?'}s intervals',
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
        targetRounds != null ? '$targetRounds rounds' : 'Rounds',
      WorkoutFormat.other =>
        durationSeconds != null ? '${durationSeconds! ~/ 60} min' : 'Timer',
    };
  }
}
