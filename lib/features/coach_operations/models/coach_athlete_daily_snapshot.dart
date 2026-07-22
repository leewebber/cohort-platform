import '../../programme/models/resolved_today_session.dart';
import '../../coach_athlete/models/coach_athlete_roster_entry.dart';

/// Operational today status for coach dashboard cards.
enum CoachAthleteTodayStatus {
  noActiveProgramme,
  trainingToday,
  completedToday,
  restDay,
  behindSchedule,
  paused,
  programmeComplete,
  dayComplete,
}

enum CoachDashboardFilter {
  all,
  needsAttention,
  trainingToday,
  completedToday,
  noProgramme,
}

extension CoachDashboardFilterLabels on CoachDashboardFilter {
  String get label {
    return switch (this) {
      CoachDashboardFilter.all => 'All',
      CoachDashboardFilter.needsAttention => 'Needs Attention',
      CoachDashboardFilter.trainingToday => 'Training Today',
      CoachDashboardFilter.completedToday => 'Completed Today',
      CoachDashboardFilter.noProgramme => 'No Programme',
    };
  }
}

/// Coach-facing daily snapshot for one linked athlete.
class CoachAthleteDailySnapshot {
  const CoachAthleteDailySnapshot({
    required this.rosterEntry,
    required this.todayStatus,
    required this.complianceLabel,
    required this.sessionsBehind,
    required this.needsAttention,
    this.resolution,
    this.weekDayLabel,
    this.progressLabel,
    this.lastActivityLabel,
    this.programmeName,
  });

  final CoachAthleteRosterEntry rosterEntry;
  final CoachAthleteTodayStatus todayStatus;
  final String complianceLabel;
  final int sessionsBehind;
  final bool needsAttention;
  final ResolvedTodaySession? resolution;
  final String? weekDayLabel;
  final String? progressLabel;
  final String? lastActivityLabel;
  final String? programmeName;

  String get todayStatusLabel => todayStatus.displayLabel;

  String get athleteId => rosterEntry.athleteId;

  String get displayName => rosterEntry.displayName;

  bool matchesFilter(CoachDashboardFilter filter) {
    return switch (filter) {
      CoachDashboardFilter.all => true,
      CoachDashboardFilter.needsAttention => needsAttention,
      CoachDashboardFilter.trainingToday =>
        todayStatus == CoachAthleteTodayStatus.trainingToday,
      CoachDashboardFilter.completedToday =>
        todayStatus == CoachAthleteTodayStatus.completedToday ||
        todayStatus == CoachAthleteTodayStatus.dayComplete,
      CoachDashboardFilter.noProgramme =>
        todayStatus == CoachAthleteTodayStatus.noActiveProgramme,
    };
  }
}

extension CoachAthleteTodayStatusLabels on CoachAthleteTodayStatus {
  String get displayLabel {
    return switch (this) {
      CoachAthleteTodayStatus.noActiveProgramme => 'No active programme',
      CoachAthleteTodayStatus.trainingToday => 'Training today',
      CoachAthleteTodayStatus.completedToday => 'Completed today',
      CoachAthleteTodayStatus.restDay => 'Rest day',
      CoachAthleteTodayStatus.behindSchedule => 'Behind schedule',
      CoachAthleteTodayStatus.paused => 'Programme paused',
      CoachAthleteTodayStatus.programmeComplete => 'Programme complete',
      CoachAthleteTodayStatus.dayComplete => 'Day complete',
    };
  }
}
