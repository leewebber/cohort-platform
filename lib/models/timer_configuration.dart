import 'workout_format.dart';

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
    );
  }

  Map<String, dynamic> toJson() => {
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
        if (totalDurationSeconds != null)
          'totalDurationSeconds': totalDurationSeconds,
        if (intervalSeconds != null) 'intervalSeconds': intervalSeconds,
        if (preparationSeconds != null)
          'preparationSeconds': preparationSeconds,
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
      };

  factory TimerConfiguration.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return const TimerConfiguration();
    return TimerConfiguration(
      durationSeconds: _int(json['durationSeconds']),
      totalDurationSeconds: _int(json['totalDurationSeconds']),
      intervalSeconds: _int(json['intervalSeconds']),
      preparationSeconds: _int(json['preparationSeconds']),
      timeCapSeconds: _int(json['timeCapSeconds']),
      stopwatchEnabled: json['stopwatchEnabled'] == true,
      workSeconds: _int(json['workSeconds']),
      restSeconds: _int(json['restSeconds']),
      rounds: _int(json['rounds']),
      targetRounds: _int(json['targetRounds']),
      restBetweenRoundsSeconds: _int(json['restBetweenRoundsSeconds']),
      timerNotes: json['timerNotes']?.toString(),
    );
  }

  static int? _int(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  List<String> validateForFormat(WorkoutFormat format) {
    return switch (format) {
      WorkoutFormat.amrap when durationSeconds == null || durationSeconds! <= 0 =>
        ['AMRAP requires a duration.'],
      WorkoutFormat.emom when totalDurationSeconds == null ||
              totalDurationSeconds! <= 0 =>
        ['EMOM requires a total duration.'],
      WorkoutFormat.emom when intervalSeconds == null || intervalSeconds! <= 0 =>
        ['EMOM requires an interval length.'],
      WorkoutFormat.intervals when workSeconds == null || workSeconds! <= 0 =>
        ['Intervals require work duration.'],
      WorkoutFormat.intervals when restSeconds == null || restSeconds! < 0 =>
        ['Intervals require rest duration.'],
      WorkoutFormat.intervals when rounds == null || rounds! <= 0 =>
        ['Intervals require rounds.'],
      WorkoutFormat.tabata when rounds == null || rounds! <= 0 =>
        ['Tabata requires rounds.'],
      _ => const [],
    };
  }

  String summaryForFormat(WorkoutFormat format) => switch (format) {
        WorkoutFormat.none => 'No timer',
        WorkoutFormat.amrap => durationSeconds != null
            ? '${durationSeconds! ~/ 60} min AMRAP'
            : 'AMRAP',
        WorkoutFormat.emom =>
          '${totalDurationSeconds != null ? '${totalDurationSeconds! ~/ 60} min' : 'EMOM'} · ${intervalSeconds ?? '?'}s intervals',
        WorkoutFormat.forTime => timeCapSeconds != null
            ? 'For Time · ${timeCapSeconds! ~/ 60} min cap'
            : 'For Time · Stopwatch',
        WorkoutFormat.intervals =>
          '${rounds ?? '?'} rounds · ${workSeconds ?? '?'}s work / ${restSeconds ?? '?'}s rest',
        WorkoutFormat.tabata =>
          '${rounds ?? 8} rounds · ${workSeconds ?? 20}s / ${restSeconds ?? 10}s',
        WorkoutFormat.rounds => targetRounds != null
            ? '$targetRounds rounds'
            : 'Rounds',
        WorkoutFormat.other => durationSeconds != null
            ? '${durationSeconds! ~/ 60} min'
            : 'Timer',
      };

  bool isValidForFormat(WorkoutFormat format) =>
      validateForFormat(format).isEmpty;
}
