/// Execution style for a Session block (M6).
enum WorkoutFormat {
  none,
  amrap,
  emom,
  forTime,
  intervals,
  tabata,
  rounds,
  other,
}

extension WorkoutFormatDb on WorkoutFormat {
  String get dbValue {
    return switch (this) {
      WorkoutFormat.none => 'none',
      WorkoutFormat.amrap => 'amrap',
      WorkoutFormat.emom => 'emom',
      WorkoutFormat.forTime => 'for_time',
      WorkoutFormat.intervals => 'intervals',
      WorkoutFormat.tabata => 'tabata',
      WorkoutFormat.rounds => 'rounds',
      WorkoutFormat.other => 'other',
    };
  }

  String get displayLabel {
    return switch (this) {
      WorkoutFormat.none => 'None',
      WorkoutFormat.amrap => 'AMRAP',
      WorkoutFormat.emom => 'EMOM',
      WorkoutFormat.forTime => 'For Time',
      WorkoutFormat.intervals => 'Intervals',
      WorkoutFormat.tabata => 'Tabata',
      WorkoutFormat.rounds => 'Rounds',
      WorkoutFormat.other => 'Other',
    };
  }

  bool get supportsTimer {
    return this != WorkoutFormat.none;
  }

  static WorkoutFormat fromDb(String? value) {
    return switch (value?.trim()) {
      'amrap' => WorkoutFormat.amrap,
      'emom' => WorkoutFormat.emom,
      'for_time' => WorkoutFormat.forTime,
      'intervals' => WorkoutFormat.intervals,
      'tabata' => WorkoutFormat.tabata,
      'rounds' => WorkoutFormat.rounds,
      'other' => WorkoutFormat.other,
      _ => WorkoutFormat.none,
    };
  }
}
