import '../../adaptive_progression/models/capability_timeline.dart';

/// Compliance snapshot for Progress (memory only).
class ProgressCompliance {
  const ProgressCompliance({
    required this.completed,
    required this.planned,
    required this.percentage,
    required this.currentStreak,
    required this.longestStreak,
  });

  final int completed;
  final int planned;
  final int percentage;
  final int currentStreak;
  final int longestStreak;
}

/// One row in session history.
class ProgressSessionHistoryItem {
  const ProgressSessionHistoryItem({
    required this.completedAt,
    required this.planName,
    required this.sessionName,
    required this.completionRatio,
    this.duration,
    this.sessionRpe,
  });

  final DateTime completedAt;
  final String planName;
  final String sessionName;
  final Duration? duration;
  final int? sessionRpe;
  final double completionRatio;

  String get completionLabel {
    final pct = (completionRatio * 100).round();
    return '$pct% complete';
  }
}

/// Upcoming cues (assessment / milestone) — product language, not engine data.
class ProgressUpcoming {
  const ProgressUpcoming({
    required this.nextAssessmentLabel,
    required this.nextMilestoneLabel,
    required this.currentPhase,
    required this.weekLabel,
  });

  final String nextAssessmentLabel;
  final String nextMilestoneLabel;
  final String currentPhase;
  final String weekLabel;
}

/// Full Progress screen model.
class ProgressSummary {
  const ProgressSummary({
    required this.hasActivePlan,
    required this.sessionsCompleted,
    required this.compliance,
    required this.recentImprovements,
    required this.timeline,
    required this.history,
    required this.upcoming,
    this.planName,
    this.weekLabel,
    this.phaseLabel,
  });

  final bool hasActivePlan;
  final String? planName;
  final String? weekLabel;
  final String? phaseLabel;
  final int sessionsCompleted;
  final ProgressCompliance compliance;
  final List<String> recentImprovements;
  final List<CapabilityTimelineEvent> timeline;
  final List<ProgressSessionHistoryItem> history;
  final ProgressUpcoming? upcoming;
}
