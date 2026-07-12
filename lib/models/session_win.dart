/// A single observational highlight from a completed strength session.
class SessionWin {
  const SessionWin({
    required this.title,
    required this.message,
    required this.type,
    this.exerciseName,
    this.supportingDetail,
  });

  final String title;
  final String message;
  final SessionWinType type;
  final String? exerciseName;
  final String? supportingDetail;
}

enum SessionWinType {
  loadProgress,
  repProgress,
  volumeProgress,
  rpeProgress,
  matchedPerformance,
  firstPerformance,
  completedAsPlanned,
  consistency,
  recoveryDecision,
}
