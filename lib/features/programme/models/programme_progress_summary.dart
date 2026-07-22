/// Athlete-facing programme progress for Home and completion screens.
class ProgrammeProgressSummary {
  const ProgrammeProgressSummary({
    required this.currentWeek,
    required this.totalWeeks,
    required this.completedSessions,
    required this.totalSessions,
  });

  final int currentWeek;
  final int totalWeeks;
  final int completedSessions;
  final int totalSessions;

  String get weekLabel => 'Week $currentWeek of $totalWeeks';

  String get sessionsLabel =>
      '$completedSessions / $totalSessions sessions completed';

  String get displayLabel => '$weekLabel • $sessionsLabel';
}
