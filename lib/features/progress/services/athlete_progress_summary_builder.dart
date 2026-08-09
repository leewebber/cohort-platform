import '../../../data/repositories/programme_assignment_store.dart';
import '../../../data/repositories/programme_assignment_supabase_store.dart';
import '../../../data/repositories/programme_slot_outcome_store.dart';
import '../../../data/repositories/programme_slot_outcome_supabase_store.dart';
import '../../../data/repositories/programme_version_store.dart';
import '../../../data/repositories/programme_version_supabase_store.dart';
import '../../../models/programme_assignment.dart';
import '../../athlete_profile/services/athlete_profile_session.dart';
import '../../home/services/athlete_home_runtime_authority.dart';
import '../../programme/models/programme_progress_summary.dart';
import '../../programme/services/programme_progress_summary_service.dart';
import '../models/progress_summary.dart';
import 'progress_summary_service.dart';

/// Resolves athlete Progress-tab authority (Phase 2.7).
///
/// Materialised programme athletes receive [ProgrammeProgressSummaryService]
/// evidence only. Legacy Plan Library summary is used only for pure-legacy
/// compatibility. Both-present and programme errors never fall back to legacy.
class AthleteProgressSummaryBuilder {
  AthleteProgressSummaryBuilder({
    ProgrammeAssignmentStore? assignmentStore,
    ProgrammeVersionStore? versionStore,
    ProgrammeSlotOutcomeStore? slotOutcomeStore,
    ProgrammeProgressSummaryService? programmeProgressService,
    ProgressSummaryService? legacySummaryService,
    AthleteHomeRuntimeAuthorityResolver? authorityResolver,
  })  : _assignmentStore =
            assignmentStore ?? const ProgrammeAssignmentSupabaseStore(),
        _versionStore = versionStore ?? const ProgrammeVersionSupabaseStore(),
        _slotOutcomeStore =
            slotOutcomeStore ?? const ProgrammeSlotOutcomeSupabaseStore(),
        _programmeProgress =
            programmeProgressService ?? const ProgrammeProgressSummaryService(),
        _legacySummary = legacySummaryService ?? const ProgressSummaryService(),
        _authorityResolver =
            authorityResolver ?? const AthleteHomeRuntimeAuthorityResolver();

  final ProgrammeAssignmentStore _assignmentStore;
  final ProgrammeVersionStore _versionStore;
  final ProgrammeSlotOutcomeStore _slotOutcomeStore;
  final ProgrammeProgressSummaryService _programmeProgress;
  final ProgressSummaryService _legacySummary;
  final AthleteHomeRuntimeAuthorityResolver _authorityResolver;

  Future<ProgressSummary> build({
    required String athleteId,
    bool? legacyActivePlan,
  }) async {
    final legacy = legacyActivePlan ?? AthleteProfileSession.hasActivePlan;
    bool? materialised;
    var unavailable = false;
    ProgrammeAssignment? assignment;

    try {
      assignment = await _assignmentStore.getActiveAssignment(athleteId);
      materialised = assignment?.isMaterialised ?? false;
    } catch (_) {
      unavailable = true;
      materialised = null;
    }

    final authority = _authorityResolver.resolve(
      materialisedProgramme: materialised,
      legacyActivePlan: legacy,
      programmeEvidenceUnavailable: unavailable,
    );

    switch (authority) {
      case AthleteHomeRuntimeAuthority.programme:
        return _buildProgramme(assignment!);
      case AthleteHomeRuntimeAuthority.legacyPlanCompatibility:
        return _legacySummary.build();
      case AthleteHomeRuntimeAuthority.loading:
      case AthleteHomeRuntimeAuthority.unavailable:
      case AthleteHomeRuntimeAuthority.none:
        return emptySummary();
    }
  }

  Future<ProgressSummary> _buildProgramme(ProgrammeAssignment assignment) async {
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
      return fromProgrammeSummary(
        assignment: assignment,
        programme: summary,
      );
    } catch (_) {
      // Fail closed: never fall back to Plan Library / hasActivePlan summary.
      return programmePlaceholder(assignment);
    }
  }

  /// Maps established programme progress facts into the Progress UI model.
  /// Does not invent Coach Brain capability metrics or Plan Library milestones.
  static ProgressSummary fromProgrammeSummary({
    required ProgrammeAssignment assignment,
    required ProgrammeProgressSummary programme,
  }) {
    final completed = programme.completedSessions;
    final planned = programme.totalSessions;
    final plannedSafe = planned < completed ? completed : planned;
    final percentage = plannedSafe == 0
        ? 0
        : ((completed / plannedSafe) * 100).round().clamp(0, 100);

    return ProgressSummary(
      hasActivePlan: true,
      planName: assignment.lineageCode,
      weekLabel: programme.weekLabel,
      phaseLabel: null,
      sessionsCompleted: completed,
      compliance: ProgressCompliance(
        completed: completed,
        planned: plannedSafe,
        percentage: percentage,
        currentStreak: 0,
        longestStreak: 0,
      ),
      recentImprovements: const [],
      timeline: const [],
      history: const [],
      upcoming: null,
    );
  }

  static ProgressSummary programmePlaceholder(ProgrammeAssignment assignment) {
    return ProgressSummary(
      hasActivePlan: true,
      planName: assignment.lineageCode,
      weekLabel: 'Week ${assignment.currentWeek}',
      phaseLabel: null,
      sessionsCompleted: 0,
      compliance: const ProgressCompliance(
        completed: 0,
        planned: 0,
        percentage: 0,
        currentStreak: 0,
        longestStreak: 0,
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
      ),
      recentImprovements: [],
      timeline: [],
      history: [],
      upcoming: null,
    );
  }
}
