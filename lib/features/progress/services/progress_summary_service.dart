import '../../adaptive_progression/models/capability_timeline.dart';
import '../../adaptive_progression/models/session_completion.dart';
import '../../athlete_profile/services/athlete_profile_session.dart';
import '../../plans/data/plan_catalog.dart';
import '../../plans/models/plan_assignment.dart';
import '../../plans/models/plan_definition.dart';
import '../models/progress_summary.dart';

/// Builds Progress summaries from in-memory completion + evidence data.
class ProgressSummaryService {
  const ProgressSummaryService();

  ProgressSummary build({
    List<SessionCompletion>? completions,
    List<CapabilityTimelineEvent>? timeline,
    PlanDefinition? activePlan,
    PlanAssignment? assignment,
    DateTime? asOf,
  }) {
    final now = asOf ?? DateTime.now().toUtc();
    final plan = activePlan ?? AthleteProfileSession.activePlan;
    final active = assignment ?? AthleteProfileSession.activeAssignment;
    final sessions = [...(completions ?? SessionCompletionStore.all)]
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    final events = [...(timeline ?? CapabilityTimelineStore.all)]
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    final compliance = computeCompliance(
      completions: sessions,
      assignment: active,
      plan: plan,
      asOf: now,
    );

    final history = sessions
        .map(
          (c) => ProgressSessionHistoryItem(
            completedAt: c.completedAt,
            planName: c.planName ??
                PlanCatalog.byId(c.planId ?? '')?.name ??
                'Plan',
            sessionName: c.sessionName ?? 'Training Session',
            duration: c.duration,
            sessionRpe: c.sessionRpe,
            completionRatio: c.completionRatio,
          ),
        )
        .toList(growable: false);

    final improvements = recentImprovements(
      timeline: events,
      compliance: compliance,
      completions: sessions,
    );

    final upcoming = plan == null || active == null
        ? null
        : buildUpcoming(plan: plan, assignment: active);

    return ProgressSummary(
      hasActivePlan: plan != null && active != null,
      planName: plan?.name,
      weekLabel: active?.weekDayLabel,
      phaseLabel: active?.currentPhase,
      sessionsCompleted: sessions.length,
      compliance: compliance,
      recentImprovements: improvements,
      timeline: events.take(12).toList(growable: false),
      history: history,
      upcoming: upcoming,
    );
  }

  ProgressCompliance computeCompliance({
    required List<SessionCompletion> completions,
    PlanAssignment? assignment,
    PlanDefinition? plan,
    DateTime? asOf,
  }) {
    final completed = completions.length;
    final planned = _plannedToDate(assignment: assignment, plan: plan);
    final plannedSafe = planned < completed ? completed : planned;
    final percentage = plannedSafe == 0
        ? 0
        : ((completed / plannedSafe) * 100).round().clamp(0, 100);

    final streaks = _streaks(completions, asOf: asOf);
    return ProgressCompliance(
      completed: completed,
      planned: plannedSafe,
      percentage: percentage,
      currentStreak: streaks.current,
      longestStreak: streaks.longest,
    );
  }

  List<String> recentImprovements({
    required List<CapabilityTimelineEvent> timeline,
    required ProgressCompliance compliance,
    required List<SessionCompletion> completions,
    int limit = 6,
  }) {
    final lines = <String>[];
    final seen = <String>{};

    for (final event in timeline) {
      if (event.direction != CapabilityChangeDirection.up) continue;
      if (!seen.add(event.label)) continue;
      lines.add(event.summaryLine);
      if (lines.length >= limit) break;
    }

    if (compliance.currentStreak >= 2 &&
        seen.add('Training Consistency')) {
      lines.add('Training Consistency ↑');
    }

    final recent = completions.take(3).toList();
    final midRpe = recent.where((c) {
      final r = c.sessionRpe;
      return r != null && r >= 5 && r <= 7;
    }).length;
    if (midRpe >= 2 && seen.add('Recovery Compliance')) {
      lines.add('Recovery Compliance ↑');
    }

    return lines.take(limit).toList(growable: false);
  }

  ProgressUpcoming buildUpcoming({
    required PlanDefinition plan,
    required PlanAssignment assignment,
  }) {
    final assessmentEvery = 4;
    final nextAssessmentWeek =
        ((assignment.currentWeek - 1) ~/ assessmentEvery + 1) * assessmentEvery;
    final clampedAssessment = nextAssessmentWeek.clamp(1, plan.durationWeeks);

    final nextMilestone = _nextMilestone(
      plan: plan,
      assignment: assignment,
    );

    return ProgressUpcoming(
      nextAssessmentLabel: 'Week $clampedAssessment check-in',
      nextMilestoneLabel: nextMilestone,
      currentPhase: assignment.currentPhase,
      weekLabel: assignment.weekDayLabel,
    );
  }

  int _plannedToDate({
    PlanAssignment? assignment,
    PlanDefinition? plan,
  }) {
    if (assignment == null || plan == null) return 0;
    final days = plan.recommendedDaysPerWeek.clamp(1, 7);
    final priorWeeks = (assignment.currentWeek - 1).clamp(0, 520);
    final dayOffset = (assignment.currentDay - 1).clamp(0, days);
    return priorWeeks * days + dayOffset;
  }

  String _nextMilestone({
    required PlanDefinition plan,
    required PlanAssignment assignment,
  }) {
    final total = plan.durationWeeks.clamp(1, 52);
    final block = (total / 3).ceil().clamp(1, total);
    if (assignment.currentWeek <= block) {
      return 'Enter Build phase (Week ${block + 1})';
    }
    if (assignment.currentWeek <= block * 2) {
      return 'Enter Peak phase (Week ${block * 2 + 1})';
    }
    return 'Complete $total-week plan';
  }

  ({int current, int longest}) _streaks(
    List<SessionCompletion> completions, {
    DateTime? asOf,
  }) {
    if (completions.isEmpty) return (current: 0, longest: 0);

    final days = completions
        .map(
          (c) => DateTime.utc(
            c.completedAt.year,
            c.completedAt.month,
            c.completedAt.day,
          ),
        )
        .toSet()
        .toList()
      ..sort();

    var longest = 1;
    var run = 1;
    for (var i = 1; i < days.length; i++) {
      final gap = days[i].difference(days[i - 1]).inDays;
      if (gap == 1) {
        run += 1;
        if (run > longest) longest = run;
      } else {
        run = 1;
      }
    }

    final anchor = asOf == null
        ? days.last
        : DateTime.utc(asOf.year, asOf.month, asOf.day);
    var current = 0;
    var cursor = days.contains(anchor) ? anchor : days.last;
    // If last session older than yesterday relative to asOf, streak is 0.
    if (asOf != null && anchor.difference(days.last).inDays > 1) {
      return (current: 0, longest: longest);
    }

    final daySet = days.toSet();
    while (daySet.contains(cursor)) {
      current += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return (current: current, longest: longest < current ? current : longest);
  }
}
