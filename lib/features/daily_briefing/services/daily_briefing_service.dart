import '../../adaptive_progression/models/session_completion.dart';
import '../../athlete_profile/services/athlete_profile_session.dart';
import '../../workout_player/models/workout_session_brief.dart';
import '../models/daily_briefing.dart';

/// Builds a calm daily briefing from existing session / plan / completion data.
///
/// No AI. No duplicated planning logic — reads Coach Brain brief fields only.
class DailyBriefingService {
  const DailyBriefingService();

  static const motivationLibrary = [
    'Consistency builds performance.',
    'Small wins compound.',
    'Show up. The work does the rest.',
    'Discipline in the present. Results in the future.',
    'Steady progress beats perfect intention.',
    'Today\'s session is another brick in the wall.',
    'Trust the plan. Execute the day.',
    'Recovery is part of the work.',
    'Quiet effort. Lasting capability.',
    'One focused session at a time.',
  ];

  static const defaultStandards = [
    BriefingStandard(
      id: 'hydration',
      label: 'Hydration',
      detail: 'Arrive topped up — water before you warm up.',
    ),
    BriefingStandard(
      id: 'nutrition',
      label: 'Nutrition',
      detail: 'Fuel simply; avoid training on empty if intensity is high.',
    ),
    BriefingStandard(
      id: 'sleep',
      label: 'Sleep',
      detail: 'Protect last night\'s sleep — it shapes today\'s quality.',
    ),
    BriefingStandard(
      id: 'recovery',
      label: 'Recovery',
      detail: 'Leave margin after the session; adaptation happens between days.',
    ),
  ];

  DailyBriefing build({
    DateTime? asOf,
    List<SessionCompletion>? completions,
    String? displayNameOverride,
  }) {
    final now = asOf ?? DateTime.now();
    final profile = AthleteProfileSession.profile;
    final programme = AthleteProfileSession.programme;
    final plan = AthleteProfileSession.activePlan;
    final assignment = AthleteProfileSession.activeAssignment;
    final brief = programme?.planBundle.brief;

    final name = _firstName(
      displayNameOverride ?? profile?.displayName ?? 'Athlete',
    );
    final greeting = '${_timeGreeting(now)}, $name.';

    final hasActivePlan =
        plan != null && assignment != null && programme != null;

    final focus = _resolveFocus(brief);
    final isRestDay = _isRestDay(
      focus: focus,
      sessionTitle: brief?.sessionName,
    );

    final sessionTitle = brief?.sessionName ?? 'Today\'s Training';
    final sessionHeadline = isRestDay
        ? 'Today is a Recovery day.'
        : 'Today is a ${_sessionTypeLabel(sessionTitle, focus)} session.';

    final yesterday = _yesterday(
      completions: completions ?? SessionCompletionStore.all,
      asOf: now,
    );

    return DailyBriefing(
      greeting: greeting,
      sessionHeadline: sessionHeadline,
      trainingFocus: focus,
      estimatedDurationMinutes: brief?.estimatedDurationMinutes,
      planName: plan?.name,
      weekDayLabel: assignment?.weekDayLabel,
      phaseLabel: assignment?.currentPhase,
      sessionTitle: sessionTitle,
      yesterday: yesterday,
      standards: defaultStandards,
      motivation: motivationFor(now),
      hasActivePlan: hasActivePlan,
      isRestDay: isRestDay,
    );
  }

  /// Deterministic rotation from the curated library (no LLM).
  String motivationFor(DateTime asOf) {
    final dayIndex = DateTime.utc(asOf.year, asOf.month, asOf.day)
        .difference(DateTime.utc(2020, 1, 1))
        .inDays;
    final index = dayIndex.abs() % motivationLibrary.length;
    return motivationLibrary[index];
  }

  String _resolveFocus(WorkoutSessionBrief? brief) {
    if (brief == null) return 'Training';
    final intent = brief.trainingIntent?.trim();
    if (intent != null && intent.isNotEmpty) {
      return _humanizeFocus(intent);
    }
    final primary = brief.primaryFocus?.trim();
    if (primary != null && primary.isNotEmpty) {
      return _humanizeFocus(primary);
    }
    final objective = brief.objective?.trim();
    if (objective != null && objective.isNotEmpty) {
      return _humanizeFocus(objective.split('.').first);
    }
    return 'General Preparation';
  }

  bool _isRestDay({required String focus, String? sessionTitle}) {
    final haystack =
        '${focus.toLowerCase()} ${(sessionTitle ?? '').toLowerCase()}';
    return haystack.contains('recovery') ||
        haystack.contains('rest day') ||
        haystack.contains('deload');
  }

  String _sessionTypeLabel(String sessionTitle, String focus) {
    final title = sessionTitle.trim();
    if (title.isNotEmpty &&
        title.toLowerCase() != "today's training" &&
        !title.toLowerCase().startsWith('session')) {
      return title;
    }
    return focus;
  }

  String _humanizeFocus(String raw) {
    final leaf = raw.contains('.') ? raw.split('.').last : raw;
    return leaf
        .replaceAll('_', ' ')
        .split(' ')
        .where((p) => p.isNotEmpty)
        .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
        .join(' ');
  }

  String _timeGreeting(DateTime now) {
    final hour = now.hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _firstName(String displayName) {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return 'Athlete';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  YesterdayBriefing? _yesterday({
    required List<SessionCompletion> completions,
    required DateTime asOf,
  }) {
    if (completions.isEmpty) return null;
    final today = DateTime(asOf.year, asOf.month, asOf.day);
    final yesterday = today.subtract(const Duration(days: 1));

    SessionCompletion? match;
    for (final c in completions) {
      final day = DateTime(
        c.completedAt.year,
        c.completedAt.month,
        c.completedAt.day,
      );
      if (day == yesterday) {
        match = c;
        break;
      }
    }
    match ??= () {
      final sorted = [...completions]
        ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
      final latest = sorted.first;
      final day = DateTime(
        latest.completedAt.year,
        latest.completedAt.month,
        latest.completedAt.day,
      );
      if (day == today) return null;
      return latest;
    }();

    return match == null ? null : YesterdayBriefing.fromCompletion(match);
  }
}
