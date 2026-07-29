import '../../adaptive_progression/models/session_completion.dart';

/// One coaching standard reminder for the day.
class BriefingStandard {
  const BriefingStandard({
    required this.id,
    required this.label,
    required this.detail,
  });

  final String id;
  final String label;
  final String detail;
}

/// Yesterday's completed session summary for the briefing.
class YesterdayBriefing {
  const YesterdayBriefing({
    required this.sessionName,
    required this.completedAt,
    this.duration,
    this.sessionRpe,
    this.completionRatio,
  });

  final String sessionName;
  final DateTime completedAt;
  final Duration? duration;
  final int? sessionRpe;
  final double? completionRatio;

  factory YesterdayBriefing.fromCompletion(SessionCompletion completion) {
    return YesterdayBriefing(
      sessionName: completion.sessionName ?? 'Training Session',
      completedAt: completion.completedAt,
      duration: completion.duration,
      sessionRpe: completion.sessionRpe,
      completionRatio: completion.completionRatio,
    );
  }
}

/// Deterministic daily coaching briefing for Home.
class DailyBriefing {
  const DailyBriefing({
    required this.greeting,
    required this.sessionHeadline,
    required this.trainingFocus,
    required this.motivation,
    required this.standards,
    required this.hasActivePlan,
    required this.isRestDay,
    this.estimatedDurationMinutes,
    this.planName,
    this.weekDayLabel,
    this.phaseLabel,
    this.yesterday,
    this.sessionTitle,
  });

  final String greeting;
  final String sessionHeadline;
  final String trainingFocus;
  final int? estimatedDurationMinutes;
  final String? planName;
  final String? weekDayLabel;
  final String? phaseLabel;
  final String? sessionTitle;
  final YesterdayBriefing? yesterday;
  final List<BriefingStandard> standards;
  final String motivation;
  final bool hasActivePlan;
  final bool isRestDay;

  String get durationLabel {
    final m = estimatedDurationMinutes;
    if (m == null || m <= 0) return 'Duration TBD';
    return '$m minutes';
  }
}
