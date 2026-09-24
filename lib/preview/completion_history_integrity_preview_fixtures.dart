import 'package:flutter/material.dart';

import '../features/programme/controllers/athlete_programme_controllers.dart';
import '../features/programme/models/fixed_programme_occurrence_projection.dart';
import '../features/programme/models/programme_catalog_entry.dart';
import '../features/programme/models/programme_template.dart';
import '../features/programme/screens/athlete_calendar_screen.dart';
import '../features/programme/screens/athlete_programme_screen.dart';
import '../features/progress/models/progress_summary.dart';
import '../features/progress/screens/progress_screen.dart';
import '../features/progress/services/athlete_progress_summary_builder.dart';
import '../models/programme_assignment.dart';
import '../models/programme_lineage.dart';
import '../models/programme_version.dart';
import '../models/programme_vocabulary.dart';
import 'athlete_shell_preview_fixture.dart';
import 'athlete_shell_preview_stores.dart';

/// Shared Sprint 3 preview fixtures. Tests must pump these exact widgets.
abstract final class CompletionHistoryPreviewFixtures {
  static ProgrammeAssignment completedAssignment() {
    return ProgrammeAssignment(
      id: previewAssignmentId,
      athleteId: previewAthleteId,
      programmeVersionId: previewVersionId,
      lineageCode: 'APOLLO-BUILD-12-WEEK',
      status: ProgrammeAssignmentStatus.completed,
      startedAt: DateTime.utc(2026, 8, 1),
      completedAt: DateTime.utc(2026, 9, 1),
      timezone: 'Atlantic/Canary',
      scheduleMode: 'fixed_schedule',
      materialisedAt: DateTime.utc(2026, 8, 1),
      materialisedPackageContentHash: previewPackageHash,
    );
  }

  static ProgrammeVersion apolloStrengthVersion() {
    return const ProgrammeVersion(
      id: previewVersionId,
      lineageId: 'lineage-preview',
      versionNumber: 2,
      lifecycleStatus: ProgrammeLifecycleStatus.published,
      libraryScope: ProgrammeLibraryScope.cohortGlobal,
      ownerType: ProgrammeOwnerType.global,
      name: 'Apollo Strength',
      durationWeeks: 12,
      approvedForGlobal: true,
      packageContentHash: previewPackageHash,
    );
  }

  static FixedProgrammeCalendarProjection completedCalendar(
    ProgrammeAssignment assignment,
  ) {
    return FixedProgrammeCalendarProjection(
      assignmentId: assignment.id,
      programmeName: 'Apollo Strength',
      timezone: 'Atlantic/Canary',
      scheduleMode: 'fixed_schedule',
      startDate: '2026-08-01',
      today: '2026-09-10',
      weekStart: '2026-09-07',
      weekEnd: '2026-09-13',
      assignmentStatus: 'completed',
      occurrences: [
        FixedProgrammeOccurrenceProjection(
          assignmentId: assignment.id,
          occurrenceId: 'occ-complete',
          sessionSlotId: previewSlotStrength,
          programmeVersionId: assignment.programmeVersionId,
          protocolId: 'BW-001',
          programmedSessionKey: 'psk-preview-complete',
          weekNumber: 1,
          dayKey: 'day_1',
          sessionOrder: 1,
          scheduledDate: '2026-09-10',
          originalScheduledDate: '2026-09-10',
          state: FixedProgrammeOccurrenceState.completed,
          sessionTitle: 'Strength',
        ),
      ],
      currentWeek: [
        for (var i = 0; i < 7; i++)
          FixedProgrammeCalendarDayProjection(
            date: '2026-09-${(7 + i).toString().padLeft(2, '0')}',
            state: i == 3
                ? FixedProgrammeOccurrenceState.completed
                : FixedProgrammeOccurrenceState.rest,
          ),
      ],
    );
  }

  static PreviewAssignmentStore completedAssignmentStore() {
    return PreviewAssignmentStore(completedAssignment());
  }

  static PreviewVersionStore apolloStrengthVersionStore() {
    final version = apolloStrengthVersion();
    return PreviewVersionStore(
      lineage: const ProgrammeLineage(id: 'lineage-preview', code: 'APOLLO-V2'),
      version: version,
      tree: ProgrammeTemplateTree(
        template: ProgrammeTemplate(version: version),
        weekNodes: const [],
      ),
      catalogue: [
        ProgrammeCatalogEntry(
          versionId: version.id,
          lineageCode: 'APOLLO-V2',
          versionNumber: 2,
          name: version.name,
          lifecycleStatus: version.lifecycleStatus,
          libraryScope: version.libraryScope,
          ownerType: version.ownerType,
          description: version.description,
          durationWeeks: version.durationWeeks,
          approvedForGlobal: true,
        ),
      ],
    );
  }

  static Widget completedCalendarScreen() {
    final assignment = completedAssignment();
    return AthleteCalendarScreen(
      athleteId: previewAthleteId,
      assignmentStore: PreviewAssignmentStore(assignment),
      fixedOccurrenceStore: PreviewProjectionStore(
        completedCalendar(assignment),
      ),
    );
  }

  static ProgrammeAssignment activeAssignment() {
    return ProgrammeAssignment(
      id: previewAssignmentId,
      athleteId: previewAthleteId,
      programmeVersionId: previewVersionId,
      lineageCode: 'APOLLO-BUILD-12-WEEK',
      status: ProgrammeAssignmentStatus.active,
      startedAt: DateTime.utc(2026, 8, 1),
      timezone: 'Atlantic/Canary',
      scheduleMode: 'fixed_schedule',
      materialisedAt: DateTime.utc(2026, 8, 1),
      materialisedPackageContentHash: previewPackageHash,
    );
  }

  static ProgrammeAssignment laterActiveSpartanAssignment() {
    return ProgrammeAssignment(
      id: 'assignment-spartan-preview',
      athleteId: previewAthleteId,
      programmeVersionId: 'version-spartan-preview',
      lineageCode: 'SPARTAN',
      status: ProgrammeAssignmentStatus.active,
      startedAt: DateTime.utc(2026, 9, 8),
      timezone: 'Atlantic/Canary',
      scheduleMode: 'fixed_schedule',
      materialisedAt: DateTime.utc(2026, 9, 8),
      materialisedPackageContentHash: previewPackageHash,
    );
  }

  static ProgrammeVersion spartanVersion() {
    return const ProgrammeVersion(
      id: 'version-spartan-preview',
      lineageId: 'lineage-spartan-preview',
      versionNumber: 1,
      lifecycleStatus: ProgrammeLifecycleStatus.published,
      libraryScope: ProgrammeLibraryScope.cohortGlobal,
      ownerType: ProgrammeOwnerType.global,
      name: 'Spartan',
      durationWeeks: 8,
      approvedForGlobal: true,
      packageContentHash: previewPackageHash,
    );
  }

  static FixedProgrammeCalendarProjection activeCalendar(
    ProgrammeAssignment assignment, {
    String programmeName = 'Apollo Strength',
    int weekNumber = 1,
    String dayKey = 'day_1',
  }) {
    final calendar = completedCalendar(assignment);
    return FixedProgrammeCalendarProjection(
      assignmentId: assignment.id,
      programmeName: programmeName,
      timezone: calendar.timezone,
      scheduleMode: calendar.scheduleMode,
      startDate: calendar.startDate,
      today: calendar.today,
      weekStart: calendar.weekStart,
      weekEnd: calendar.weekEnd,
      assignmentStatus: 'active',
      occurrences: [
        FixedProgrammeOccurrenceProjection(
          assignmentId: assignment.id,
          occurrenceId: 'occ-today',
          sessionSlotId: previewSlotStrength,
          programmeVersionId: assignment.programmeVersionId,
          protocolId: 'BW-001',
          programmedSessionKey: 'psk-preview-today',
          weekNumber: weekNumber,
          dayKey: dayKey,
          sessionOrder: 1,
          scheduledDate: calendar.today,
          originalScheduledDate: calendar.today,
          state: FixedProgrammeOccurrenceState.today,
          sessionTitle: programmeName,
        ),
      ],
      currentWeek: calendar.currentWeek,
    );
  }

  static Widget activeProgrammesScreen() {
    final assignment = activeAssignment();
    final assignments = PreviewAssignmentStore(assignment);
    final versions = apolloStrengthVersionStore();
    return AthleteProgrammeScreen(
      athleteId: previewAthleteId,
      assignmentStore: assignments,
      controller: AthleteProgrammeScreenController(
        athleteId: previewAthleteId,
        assignmentStore: assignments,
        versionStore: versions,
      ),
      fixedOccurrenceStore: PreviewProjectionStore(activeCalendar(assignment)),
    );
  }

  static Widget completedPlusNewActiveProgrammesScreen() {
    final completed = completedAssignment();
    final active = laterActiveSpartanAssignment();
    final assignments = PreviewAssignmentStore(active, others: [completed]);
    final apollo = apolloStrengthVersion();
    final spartan = spartanVersion();
    final versions = PreviewVersionStore(
      lineage: const ProgrammeLineage(id: 'lineage-spartan-preview', code: 'SPARTAN'),
      version: spartan,
      tree: ProgrammeTemplateTree(
        template: ProgrammeTemplate(version: spartan),
        weekNodes: const [],
      ),
      catalogue: [
        ProgrammeCatalogEntry(
          versionId: spartan.id,
          lineageCode: 'SPARTAN',
          versionNumber: 1,
          name: spartan.name,
          lifecycleStatus: spartan.lifecycleStatus,
          libraryScope: spartan.libraryScope,
          ownerType: spartan.ownerType,
          durationWeeks: spartan.durationWeeks,
          approvedForGlobal: true,
        ),
      ],
      extraVersions: [apollo],
    );
    return AthleteProgrammeScreen(
      athleteId: previewAthleteId,
      assignmentStore: assignments,
      controller: AthleteProgrammeScreenController(
        athleteId: previewAthleteId,
        assignmentStore: assignments,
        versionStore: versions,
      ),
      fixedOccurrenceStore: PreviewProjectionStore(
        activeCalendar(
          active,
          programmeName: 'Spartan',
          weekNumber: 2,
          dayKey: 'day_1',
        ),
      ),
    );
  }

  static Widget completedProgrammesScreen() {
    final assignment = completedAssignment();
    final assignments = PreviewAssignmentStore(assignment);
    final versions = apolloStrengthVersionStore();
    return AthleteProgrammeScreen(
      athleteId: previewAthleteId,
      assignmentStore: assignments,
      controller: AthleteProgrammeScreenController(
        athleteId: previewAthleteId,
        assignmentStore: assignments,
        versionStore: versions,
      ),
      fixedOccurrenceStore: PreviewProjectionStore(
        completedCalendar(assignment),
      ),
    );
  }

  static ProgressSummary lastGoodProgress() {
    return const ProgressSummary(
      hasActivePlan: true,
      planName: 'Apollo Strength',
      sessionsCompleted: 8,
      compliance: ProgressCompliance(
        completed: 8,
        planned: 12,
        percentage: 67,
        currentStreak: 0,
        longestStreak: 0,
      ),
      recentImprovements: [],
      timeline: [],
      history: [],
      upcoming: null,
    );
  }

  static Widget progressRefreshFailed({
    String athleteId = previewAthleteId,
    AthleteProgressSummaryBuilder? progressBuilder,
  }) {
    return ProgressScreen(
      athleteIdOverride: athleteId,
      summary: lastGoodProgress(),
      progressBuilder: progressBuilder ?? RefreshFailingProgressBuilder(),
    );
  }
}

class RefreshFailingProgressBuilder extends AthleteProgressSummaryBuilder {
  RefreshFailingProgressBuilder({this.onBuild});

  final void Function(String athleteId)? onBuild;
  int builds = 0;

  @override
  Future<ProgressSummary> build({required String athleteId}) {
    builds += 1;
    onBuild?.call(athleteId);
    throw const AthleteProgressEvidenceFailure('history_unavailable');
  }
}
