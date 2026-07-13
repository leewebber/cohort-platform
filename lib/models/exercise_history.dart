/// One performed set line in exercise history.
class ExerciseHistorySetLine {
  const ExerciseHistorySetLine({
    required this.setNumber,
    required this.isExtraSet,
    required this.displayLine,
  });

  final int setNumber;
  final bool isExtraSet;
  final String displayLine;
}

/// One completed session's notebook entry for an exercise.
class ExerciseHistorySession {
  const ExerciseHistorySession({
    required this.trainingSessionId,
    required this.performedAt,
    required this.protocolLabel,
    required this.setLines,
    required this.summaryLine,
    this.athleteNote,
    this.endedEarly = false,
    this.completionReason,
  });

  final int trainingSessionId;
  final DateTime? performedAt;
  final String protocolLabel;
  final List<ExerciseHistorySetLine> setLines;
  final String summaryLine;
  final String? athleteNote;
  final bool endedEarly;
  final String? completionReason;
}

/// Complete exercise history for one athlete and movement.
class ExerciseHistory {
  const ExerciseHistory({
    required this.exerciseId,
    required this.sessions,
  });

  final String exerciseId;
  final List<ExerciseHistorySession> sessions;

  bool get hasHistory => sessions.isNotEmpty;

  int get sessionCount => sessions.length;
}
