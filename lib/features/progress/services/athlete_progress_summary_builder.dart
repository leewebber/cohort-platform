import '../../../data/repositories/programme_assignment_store.dart';
import '../../../data/repositories/programme_assignment_supabase_store.dart';
import '../../../data/repositories/programme_slot_outcome_store.dart';
import '../../../data/repositories/programme_slot_outcome_supabase_store.dart';
import '../../../data/repositories/programme_version_store.dart';
import '../../../data/repositories/programme_version_supabase_store.dart';
import '../../../models/programme_assignment.dart';
import '../../../models/programme_slot_outcome.dart';
import '../../../models/programme_vocabulary.dart';
import '../../app_shell/presentation/athlete_time_aware_greeting.dart';
import '../../home/services/athlete_home_runtime_authority.dart';
import '../../performance/models/training_session_record.dart';
import '../../performance/repositories/performance_record_store.dart';
import '../../performance/repositories/supabase_performance_record_store.dart';
import '../../programme/domain/athlete_programme_context.dart';
import '../../programme/models/fixed_programme_occurrence_projection.dart';
import '../../programme/services/athlete_programme_context_resolver.dart';
import '../../programme/models/programme_progress_summary.dart';
import '../../programme/services/fixed_programme_occurrence_projection_store.dart';
import '../../programme/services/fixed_programme_occurrence_projection_supabase_store.dart';
import '../../programme/services/programme_progress_summary_service.dart';
import '../models/progress_summary.dart';
import 'athlete_progress_evidence_projection.dart';
import 'time_eligible_discipline.dart';

/// Resolves athlete Progress-tab authority (Phase 2.7 / 2.8).
///
/// Materialised programme athletes receive [ProgrammeProgressSummaryService]
/// evidence only. Legacy Plan Library state does not select Progress authority
/// (Phase 2.8 Home retirement alignment). Errors never fall back to legacy.
///
/// Training Discipline uses Calendar occurrence eligibility, not total
/// programme length.
class AthleteProgressEvidenceFailure implements Exception {
  const AthleteProgressEvidenceFailure(this.code, [this.cause]);

  final String code;
  final Object? cause;

  @override
  String toString() => 'AthleteProgressEvidenceFailure($code)';
}

class AthleteProgressSummaryBuilder {
  AthleteProgressSummaryBuilder({
    ProgrammeAssignmentStore? assignmentStore,
    ProgrammeVersionStore? versionStore,
    ProgrammeSlotOutcomeStore? slotOutcomeStore,
    ProgrammeProgressSummaryService? programmeProgressService,
    PerformanceRecordStore? performanceRecordStore,
    AthleteHomeRuntimeAuthorityResolver? authorityResolver,
    FixedProgrammeOccurrenceProjectionStore? occurrenceStore,
    this.utcNow,
  }) : _assignmentStore =
           assignmentStore ?? const ProgrammeAssignmentSupabaseStore(),
       _versionStore = versionStore ?? const ProgrammeVersionSupabaseStore(),
       _slotOutcomeStore =
           slotOutcomeStore ?? const ProgrammeSlotOutcomeSupabaseStore(),
       _programmeProgress =
           programmeProgressService ?? const ProgrammeProgressSummaryService(),
       _performanceRecordStore =
           performanceRecordStore ?? SupabasePerformanceRecordStore(),
       _authorityResolver =
           authorityResolver ?? const AthleteHomeRuntimeAuthorityResolver(),
       _occurrenceStore =
           occurrenceStore ??
           const FixedProgrammeOccurrenceProjectionSupabaseStore();

  final ProgrammeAssignmentStore _assignmentStore;
  final ProgrammeVersionStore _versionStore;
  final ProgrammeSlotOutcomeStore _slotOutcomeStore;
  final ProgrammeProgressSummaryService _programmeProgress;
  final PerformanceRecordStore _performanceRecordStore;
  final AthleteHomeRuntimeAuthorityResolver _authorityResolver;
  final FixedProgrammeOccurrenceProjectionStore _occurrenceStore;
  final DateTime Function()? utcNow;

  Future<ProgressSummary> build({required String athleteId}) async {
    if (athleteId.trim().isEmpty) {
      throw const AthleteProgressEvidenceFailure('athlete_required');
    }
    late final AthleteProgrammeContext context;
    try {
      context = await AthleteProgrammeContextResolver(
        _assignmentStore,
      ).resolve(athleteId);
    } catch (error) {
      throw AthleteProgressEvidenceFailure('assignment_unavailable', error);
    }

    final assignment = context.assignment;
    final materialised = context.isNone
        ? false
        : assignment?.isMaterialised ?? false;
    final authority = _authorityResolver.resolve(
      materialisedProgramme: materialised,
      programmeEvidenceUnavailable: false,
    );

    switch (authority) {
      case AthleteHomeRuntimeAuthority.programme:
        return _mergeEvidence(
          await _buildProgramme(assignment!),
          athleteId: athleteId,
        );
      case AthleteHomeRuntimeAuthority.loading:
      case AthleteHomeRuntimeAuthority.unavailable:
      case AthleteHomeRuntimeAuthority.none:
        return _mergeEvidence(emptySummary(), athleteId: athleteId);
    }
  }

  Future<ProgressSummary> _buildProgramme(
    ProgrammeAssignment assignment,
  ) async {
    try {
      final tree = await _versionStore.loadTemplateTree(
        assignment.programmeVersionId,
      );
      if (tree == null) {
        return programmePlaceholder(assignment);
      }

      final outcomes = await _slotOutcomeStore.listForAssignment(assignment.id);
      final summary = _programmeProgress.summarize(
        tree: tree,
        outcomes: outcomes,
        currentWeek: assignment.currentWeek,
      );
      if (summary == null) {
        return programmePlaceholder(assignment);
      }
      final calendar = await _tryLoadCalendar(assignment);
      return fromProgrammeSummary(
        assignment: assignment,
        programme: summary,
        calendar: calendar,
        outcomes: outcomes,
        utcNow: utcNow?.call(),
      );
    } catch (_) {
      // Fail closed: never fall back to Plan Library / hasActivePlan summary.
      return programmePlaceholder(assignment);
    }
  }

  Future<FixedProgrammeCalendarProjection?> _tryLoadCalendar(
    ProgrammeAssignment assignment,
  ) async {
    try {
      if (!assignment.isActive) {
        return await _occurrenceStore.resolveForAssignment(assignment.id);
      }
      return await _occurrenceStore.resolveActive();
    } catch (_) {
      return null;
    }
  }

  /// Maps established programme progress facts into the Progress UI model.
  /// Does not invent Coach Brain capability metrics or Plan Library milestones.
  ///
  /// [sessionsCompleted] remains the factual completed-session count.
  /// Discipline uses time-eligible Calendar occurrences when present.
  static ProgressSummary fromProgrammeSummary({
    required ProgrammeAssignment assignment,
    required ProgrammeProgressSummary programme,
    FixedProgrammeCalendarProjection? calendar,
    List<ProgrammeSlotOutcome> outcomes = const [],
    DateTime? utcNow,
  }) {
    final completed = programme.completedSessions;
    final discipline = _disciplineFor(
      assignment: assignment,
      calendar: calendar,
      outcomes: outcomes,
      utcNow: utcNow,
    );

    return ProgressSummary(
      hasActivePlan: true,
      planName: assignment.lineageCode,
      weekLabel: programme.weekLabel,
      phaseLabel: null,
      sessionsCompleted: completed,
      compliance: discipline,
      recentImprovements: const [],
      timeline: const [],
      history: const [],
      upcoming: null,
    );
  }

  static ProgressCompliance _disciplineFor({
    required ProgrammeAssignment assignment,
    required FixedProgrammeCalendarProjection? calendar,
    required List<ProgrammeSlotOutcome> outcomes,
    DateTime? utcNow,
  }) {
    final timezone = calendar?.timezone ?? assignment.timezone;
    final today =
        calendar?.today ?? AthleteIanaClock.dateOnly(timezone, utcNow: utcNow);
    final startDate = calendar?.startDate;
    final occurrences = calendar?.occurrences ?? const [];
    final overlay = <String, ProgrammeSlotOutcomeStatus>{
      for (final outcome in outcomes)
        '${outcome.sessionSlotId}|${outcome.weekNumber}|'
                '${outcome.dayKey}|${outcome.sessionOrder}':
            outcome.outcomeStatus,
      for (final outcome in outcomes)
        outcome.sessionSlotId: outcome.outcomeStatus,
    };
    return TimeEligibleDiscipline.score(
      occurrences: occurrences,
      athleteLocalToday: today,
      programmeStartDate: startDate,
      slotOutcomes: overlay,
    ).toCompliance(timezone: timezone);
  }

  Future<ProgressSummary> _mergeEvidence(
    ProgressSummary base, {
    required String athleteId,
  }) async {
    List<TrainingSessionRecord> history = const [];
    try {
      history = await _performanceRecordStore.listHistory(
        athleteId: athleteId,
        limit: 40,
      );
    } catch (error) {
      throw AthleteProgressEvidenceFailure('history_unavailable', error);
    }
    final completed = AthleteProgressEvidenceProjection.completedRecords(
      history,
    );
    if (completed.isEmpty) return base;

    final fromRecords = completed.length;
    final sessions = base.sessionsCompleted >= fromRecords
        ? base.sessionsCompleted
        : fromRecords;
    return ProgressSummary(
      hasActivePlan: base.hasActivePlan || sessions > 0,
      planName: base.planName,
      weekLabel: base.weekLabel,
      phaseLabel: base.phaseLabel,
      sessionsCompleted: sessions,
      compliance: base.compliance,
      recentImprovements: base.recentImprovements,
      timeline: base.timeline,
      history: AthleteProgressEvidenceProjection.historyItems(completed),
      upcoming: base.upcoming,
      exerciseBests: AthleteProgressEvidenceProjection.exerciseBests(completed),
      strengthSessionCount:
          AthleteProgressEvidenceProjection.strengthSessionCount(completed),
      enduranceSessionCount:
          AthleteProgressEvidenceProjection.enduranceSessionCount(completed),
    );
  }

  static ProgressSummary programmePlaceholder(ProgrammeAssignment assignment) {
    return ProgressSummary(
      hasActivePlan: true,
      planName: assignment.lineageCode,
      weekLabel: 'Week ${assignment.currentWeek}',
      phaseLabel: null,
      sessionsCompleted: 0,
      compliance: ProgressCompliance(
        completed: 0,
        planned: 0,
        percentage: 0,
        currentStreak: 0,
        longestStreak: 0,
        availability: DisciplineAvailability.noneDue,
        timezone: assignment.timezone,
      ),
      recentImprovements: const [],
      timeline: const [],
      history: const [],
      upcoming: null,
    );
  }

  static ProgressSummary emptySummary() {
    return const ProgressSummary(
      hasActivePlan: false,
      sessionsCompleted: 0,
      compliance: ProgressCompliance(
        completed: 0,
        planned: 0,
        percentage: 0,
        currentStreak: 0,
        longestStreak: 0,
        availability: DisciplineAvailability.noneDue,
      ),
      recentImprovements: [],
      timeline: [],
      history: [],
      upcoming: null,
    );
  }
}
