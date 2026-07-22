import '../../../data/repositories/programme_assignment_store.dart';
import '../../../data/repositories/programme_slot_outcome_store.dart';
import '../../../data/repositories/programme_version_store.dart';
import '../../../features/home/services/home_today_session_loader.dart';
import '../../../features/performance/repositories/performance_record_store.dart';
import '../../../models/programme_assignment.dart';
import '../../../models/programme_slot_outcome.dart';
import '../../coach_athlete/models/coach_athlete_operation_result.dart';
import '../../coach_athlete/models/coach_athlete_roster_entry.dart';
import '../../coach_athlete/services/coach_athlete_service.dart';
import '../../programme/models/programme_template.dart';
import '../../programme/models/resolved_today_session.dart';
import '../../programme/services/programme_progress_summary_service.dart';
import '../../programme/services/programme_schedule_resolver.dart';
import '../models/coach_athlete_daily_snapshot.dart';
import 'coach_compliance_summary_service.dart';

/// Loads coach-facing daily operational snapshots for linked athletes.
class CoachAthleteDailyStatusService {
  CoachAthleteDailyStatusService({
    required CoachAthleteService coachAthleteService,
    required ProgrammeAssignmentStore assignmentStore,
    required ProgrammeVersionStore versionStore,
    required ProgrammeSlotOutcomeStore slotOutcomeStore,
    required ProgrammeScheduleResolver scheduleResolver,
    PerformanceRecordStore? performanceRecordStore,
    ProgrammeProgressSummaryService? progressSummaryService,
    CoachComplianceSummaryService? complianceSummaryService,
  })  : _coachAthleteService = coachAthleteService,
        _assignmentStore = assignmentStore,
        _versionStore = versionStore,
        _slotOutcomeStore = slotOutcomeStore,
        _scheduleResolver = scheduleResolver,
        _performanceRecordStore = performanceRecordStore,
        _progressSummaryService =
            progressSummaryService ?? const ProgrammeProgressSummaryService(),
        _complianceSummaryService =
            complianceSummaryService ?? const CoachComplianceSummaryService();

  final CoachAthleteService _coachAthleteService;
  final ProgrammeAssignmentStore _assignmentStore;
  final ProgrammeVersionStore _versionStore;
  final ProgrammeSlotOutcomeStore _slotOutcomeStore;
  final ProgrammeScheduleResolver _scheduleResolver;
  final PerformanceRecordStore? _performanceRecordStore;
  final ProgrammeProgressSummaryService _progressSummaryService;
  final CoachComplianceSummaryService _complianceSummaryService;

  Future<List<CoachAthleteDailySnapshot>> loadDashboardSnapshots() async {
    final rosterResult = await _coachAthleteService.listLinkedAthletes();
    if (!rosterResult.isSuccess) {
      throw CoachAthleteDailyStatusException(
        rosterResult.message ?? 'Unable to load athlete roster.',
        coachRoleRequired: rosterResult.status ==
            CoachAthleteOperationStatus.coachRoleRequired,
      );
    }

    final entries = rosterResult.value ?? const [];
    final snapshots = <CoachAthleteDailySnapshot>[];

    for (final entry in entries) {
      snapshots.add(await _loadSnapshot(entry));
    }

    return snapshots;
  }

  Future<CoachAthleteDailySnapshot> loadSnapshotForAthlete(
    String athleteId,
  ) async {
    final rosterResult = await _coachAthleteService.listLinkedAthletes();
    if (!rosterResult.isSuccess) {
      throw CoachAthleteDailyStatusException(
        rosterResult.message ?? 'Unable to load athlete roster.',
        coachRoleRequired: rosterResult.status ==
            CoachAthleteOperationStatus.coachRoleRequired,
      );
    }

    final entry = rosterResult.value!.firstWhere(
      (candidate) => candidate.athleteId == athleteId,
      orElse: () => throw CoachAthleteDailyStatusException(
        'Athlete is not linked to your roster.',
      ),
    );

    return _loadSnapshot(entry);
  }

  Future<CoachAthleteDailySnapshot> _loadSnapshot(
    CoachAthleteRosterEntry entry,
  ) async {
    final assignment =
        await _assignmentStore.getActiveAssignment(entry.athleteId);

    if (assignment == null) {
      return CoachAthleteDailySnapshot(
        rosterEntry: entry,
        todayStatus: CoachAthleteTodayStatus.noActiveProgramme,
        complianceLabel: 'No Programme',
        sessionsBehind: 0,
        needsAttention: true,
        programmeName: entry.activeProgrammeName,
      );
    }

    final tree = await _versionStore.loadTemplateTree(
      assignment.programmeVersionId,
    );
    if (tree == null) {
      return CoachAthleteDailySnapshot(
        rosterEntry: entry,
        todayStatus: CoachAthleteTodayStatus.noActiveProgramme,
        complianceLabel: 'No Programme',
        sessionsBehind: 0,
        needsAttention: true,
        programmeName: entry.activeProgrammeName,
      );
    }

    final outcomes = await _slotOutcomeStore.listForAssignment(assignment.id);
    final resolution = _resolve(assignment, tree, outcomes);
    final compliance = _complianceSummaryService.summarize(
      tree: tree,
      outcomes: outcomes,
      assignment: assignment,
      resolution: resolution,
    );
    final progress = _progressSummaryService.summarize(
      tree: tree,
      outcomes: outcomes,
      currentWeek: resolution.weekNumber ?? assignment.currentWeek,
    );
    final lastActivity = await _loadLastActivityLabel(
      athleteId: entry.athleteId,
      outcomes: outcomes,
    );

    return CoachAthleteDailySnapshot(
      rosterEntry: entry,
      todayStatus: _mapTodayStatus(resolution, compliance),
      complianceLabel: compliance.label,
      sessionsBehind: compliance.sessionsBehind,
      needsAttention: compliance.needsAttention,
      resolution: resolution,
      weekDayLabel: HomeTodaySessionLabels.weekLabel(resolution),
      progressLabel: progress == null
          ? null
          : HomeTodaySessionLabels.progressLabel(progress),
      lastActivityLabel: lastActivity,
      programmeName: resolution.programmeName ??
          entry.activeProgrammeName ??
          assignment.lineageCode,
    );
  }

  ResolvedTodaySession _resolve(
    ProgrammeAssignment assignment,
    ProgrammeTemplateTree tree,
    List<ProgrammeSlotOutcome> outcomes,
  ) {
    if (assignment.isPaused) {
      return ResolvedTodaySession.paused(
        assignment: assignment,
        programmeName: tree.template.version.name,
        versionNumber: tree.template.version.versionNumber,
      );
    }

    final resolution = _scheduleResolver.resolve(
      assignment: assignment,
      tree: tree,
      outcomes: outcomes,
    );

    return ResolvedTodaySession.fromResolution(resolution);
  }

  CoachAthleteTodayStatus _mapTodayStatus(
    ResolvedTodaySession resolution,
    CoachComplianceResult compliance,
  ) {
    if (compliance.sessionsBehind > 0 &&
        !compliance.completedToday &&
        resolution.kind != ResolvedTodaySessionKind.restDay &&
        resolution.kind != ResolvedTodaySessionKind.noActiveProgramme) {
      return CoachAthleteTodayStatus.behindSchedule;
    }

    return switch (resolution.kind) {
      ResolvedTodaySessionKind.noActiveProgramme =>
        CoachAthleteTodayStatus.noActiveProgramme,
      ResolvedTodaySessionKind.paused => CoachAthleteTodayStatus.paused,
      ResolvedTodaySessionKind.executable =>
        CoachAthleteTodayStatus.trainingToday,
      ResolvedTodaySessionKind.restDay => CoachAthleteTodayStatus.restDay,
      ResolvedTodaySessionKind.dayComplete =>
        CoachAthleteTodayStatus.completedToday,
      ResolvedTodaySessionKind.programmeComplete =>
        CoachAthleteTodayStatus.programmeComplete,
    };
  }

  Future<String?> _loadLastActivityLabel({
    required String athleteId,
    required List<ProgrammeSlotOutcome> outcomes,
  }) async {
    DateTime? latest;

    for (final outcome in outcomes) {
      if (!outcome.isTerminal) continue;
      final resolvedAt = outcome.resolvedAt;
      if (resolvedAt == null) continue;
      if (latest == null || resolvedAt.isAfter(latest)) {
        latest = resolvedAt;
      }
    }

    final store = _performanceRecordStore;
    if (store != null) {
      final records = await store.listHistory(athleteId: athleteId, limit: 1);
      if (records.isNotEmpty) {
        final completedAt = records.first.completedAt;
        if (completedAt != null &&
            (latest == null || completedAt.isAfter(latest))) {
          latest = completedAt;
        }
      }
    }

    if (latest == null) return null;
    return _formatRelativeDate(latest.toLocal());
  }

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    }

    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Yesterday';
    }

    return '${date.day}/${date.month}/${date.year}';
  }
}

class CoachAthleteDailyStatusException implements Exception {
  CoachAthleteDailyStatusException(
    this.message, {
    this.coachRoleRequired = false,
  });

  final String message;
  final bool coachRoleRequired;

  @override
  String toString() => message;
}
