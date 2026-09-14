import '../../adaptive_progression/models/capability_timeline.dart';

/// Whether Training Discipline has any due-session evidence yet.
enum DisciplineAvailability {
  /// Assignment start is still in the athlete-local future.
  preStart,

  /// Programme has started, but no required session is due yet.
  noneDue,

  /// At least one required session is denominator-eligible.
  scored,
}

/// Compliance snapshot for Progress (memory only).
///
/// [completed] / [planned] are the time-eligible Discipline numerator and
/// denominator (sessions due so far), not total programme length.
class ProgressCompliance {
  const ProgressCompliance({
    required this.completed,
    required this.planned,
    required this.percentage,
    required this.currentStreak,
    required this.longestStreak,
    this.availability,
    this.asOfDate,
    this.timezone,
    this.futureExcluded = 0,
    this.incompleteCount = 0,
    this.skippedCount = 0,
    this.partialCompletedCount = 0,
    this.totalRequired = 0,
  });

  /// Eligible completed sessions (Discipline numerator).
  final int completed;

  /// Eligible sessions due so far (Discipline denominator).
  final int planned;
  final int percentage;
  final int currentStreak;
  final int longestStreak;

  /// When null, inferred from [planned] so injected test summaries stay scored.
  final DisciplineAvailability? availability;
  final String? asOfDate;
  final String? timezone;
  final int futureExcluded;
  final int incompleteCount;
  final int skippedCount;
  final int partialCompletedCount;
  final int totalRequired;

  DisciplineAvailability get resolvedAvailability {
    return availability ??
        (planned > 0
            ? DisciplineAvailability.scored
            : DisciplineAvailability.noneDue);
  }

  bool get hasScore =>
      resolvedAvailability == DisciplineAvailability.scored && planned > 0;

  String get athleteHeadline {
    if (!hasScore) return 'No sessions due yet';
    return '$completed of $planned sessions completed · $percentage%';
  }

  String get supportingLabel => 'Sessions due so far';

  String get semanticLabel {
    if (!hasScore) return athleteHeadline;
    return '$athleteHeadline. $supportingLabel';
  }
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

/// Evidence-backed exercise best for Progress cards.
class ProgressExerciseBest {
  const ProgressExerciseBest({
    required this.exerciseId,
    required this.displayName,
    required this.bestSetLabel,
    required this.comparisonLabel,
    required this.isFirstRecorded,
    this.comparisonImproved = false,
    this.personalBestLabel,
  });

  final String exerciseId;
  final String displayName;
  final String bestSetLabel;
  final String comparisonLabel;
  final bool isFirstRecorded;
  final bool comparisonImproved;
  final String? personalBestLabel;
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
    this.exerciseBests = const [],
    this.strengthSessionCount = 0,
    this.enduranceSessionCount = 0,
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
  final List<ProgressExerciseBest> exerciseBests;
  final int strengthSessionCount;
  final int enduranceSessionCount;
}
