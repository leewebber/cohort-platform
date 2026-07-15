import 'package:flutter/foundation.dart';

import '../../../data/repositories/athlete_state_supabase_store.dart';
import '../../../data/repositories/programme_assignment_store.dart';
import '../../../data/repositories/programme_assignment_supabase_store.dart';
import '../../../data/repositories/programme_slot_outcome_store.dart';
import '../../../data/repositories/programme_slot_outcome_supabase_store.dart';
import '../../../data/repositories/programme_store_exception.dart';
import '../../../data/repositories/programme_version_store.dart';
import '../../../data/repositories/programme_version_supabase_store.dart';
import '../../../models/programme_assignment.dart';
import '../../../models/programme_vocabulary.dart';
import '../models/resolved_today_session.dart';
import '../services/athlete_state_sync_service.dart';
import '../services/athlete_state_sync_service_impl.dart';
import '../services/programme_progression_service.dart';
import '../services/programme_progression_service_impl.dart';
import '../services/programme_schedule_resolver_impl.dart';
import '../services/programme_slot_outcome_service_impl.dart';
import '../services/today_session_service.dart';
import '../services/today_session_service_impl.dart';
import 'programme_dev_fixtures.dart';
import 'programme_debug_resolution_cache.dart';

/// Temporary Home debug helpers for programme service validation.
class ProgrammeDebugActions {
  ProgrammeDebugActions._();

  static const devAthleteId = 'lee';
  static const _devAssignmentId = 'aaaaaaaa-bbbb-cccc-dddd-000000000100';

  static TodaySessionService createTodaySessionService({
    ProgrammeAssignmentStore? assignmentStore,
    ProgrammeSlotOutcomeStore? slotOutcomeStore,
    ProgrammeVersionStore? versionStore,
  }) {
    return TodaySessionServiceImpl(
      assignmentStore:
          assignmentStore ?? const ProgrammeAssignmentSupabaseStore(),
      versionStore: versionStore ?? const ProgrammeVersionSupabaseStore(),
      slotOutcomeStore:
          slotOutcomeStore ?? const ProgrammeSlotOutcomeSupabaseStore(),
      scheduleResolver: const ProgrammeScheduleResolverImpl(),
    );
  }

  static AthleteStateSyncService createAthleteStateSyncService() {
    return AthleteStateSyncServiceImpl(
      athleteStateStore: const AthleteStateSupabaseStore(),
    );
  }

  static ProgrammeProgressionService createProgressionService({
    ProgrammeAssignmentStore? assignmentStore,
    ProgrammeSlotOutcomeStore? slotOutcomeStore,
  }) {
    final assignment =
        assignmentStore ?? const ProgrammeAssignmentSupabaseStore();
    final outcomes =
        slotOutcomeStore ?? const ProgrammeSlotOutcomeSupabaseStore();

    return ProgrammeProgressionServiceImpl(
      assignmentStore: assignment,
      slotOutcomeStore: outcomes,
      versionStore: const ProgrammeVersionSupabaseStore(),
      slotOutcomeService: ProgrammeSlotOutcomeServiceImpl(
        slotOutcomeStore: outcomes,
      ),
      scheduleResolver: const ProgrammeScheduleResolverImpl(),
      todaySessionService: createTodaySessionService(
        assignmentStore: assignment,
        slotOutcomeStore: outcomes,
      ),
      athleteStateSyncService: createAthleteStateSyncService(),
    );
  }

  /// Ensures `lee` has an active assignment pinned to the foundation test v1.
  ///
  /// Creates the assignment when missing and repairs version/lineage/status only.
  /// Never resets cursor position — use [resetTestProgrammeAssignment] for that.
  static Future<ProgrammeAssignment> ensureFoundationTestAssignment({
    ProgrammeAssignmentStore? assignmentStore,
  }) async {
    final store = assignmentStore ?? const ProgrammeAssignmentSupabaseStore();
    final existing = await store.getActiveAssignment(devAthleteId);

    if (existing != null) {
      final needsMetadataUpdate = existing.programmeVersionId !=
              ProgrammeDevFixtures.foundationTestVersionId ||
          existing.lineageCode !=
              ProgrammeDevFixtures.foundationTestLineageCode ||
          !existing.isActive;

      if (!needsMetadataUpdate) {
        return existing;
      }

      return store.update(
        existing.copyWith(
          programmeVersionId: ProgrammeDevFixtures.foundationTestVersionId,
          lineageCode: ProgrammeDevFixtures.foundationTestLineageCode,
          status: ProgrammeAssignmentStatus.active,
          clearPausedAt: true,
          clearCompletedAt: true,
        ),
      );
    }

    return store.insert(
      ProgrammeAssignment(
        id: _devAssignmentId,
        athleteId: devAthleteId,
        programmeVersionId: ProgrammeDevFixtures.foundationTestVersionId,
        lineageCode: ProgrammeDevFixtures.foundationTestLineageCode,
        status: ProgrammeAssignmentStatus.active,
        startedAt: DateTime.utc(2026, 7, 15),
        currentWeek: 1,
        currentDayKey: 'day_1',
        currentSessionOrder: 1,
      ),
    );
  }

  static Future<ResolvedTodaySession> resolveCurrentTestSession({
    ProgrammeAssignmentStore? assignmentStore,
    ProgrammeSlotOutcomeStore? slotOutcomeStore,
    ProgrammeVersionStore? versionStore,
  }) async {
    await ensureFoundationTestAssignment(assignmentStore: assignmentStore);
    final service = createTodaySessionService(
      assignmentStore: assignmentStore,
      slotOutcomeStore: slotOutcomeStore,
      versionStore: versionStore,
    );
    return service.resolveForAthlete(devAthleteId);
  }

  static Future<void> resetTestProgrammeAssignment({
    ProgrammeAssignmentStore? assignmentStore,
    ProgrammeSlotOutcomeStore? slotOutcomeStore,
    ProgrammeVersionStore? versionStore,
    AthleteStateSyncService? athleteStateSyncService,
  }) async {
    final assignmentStoreImpl =
        assignmentStore ?? const ProgrammeAssignmentSupabaseStore();
    final outcomeStoreImpl =
        slotOutcomeStore ?? const ProgrammeSlotOutcomeSupabaseStore();

    final assignment =
        await ensureFoundationTestAssignment(assignmentStore: assignmentStoreImpl);
    debugPrint(
      '[ProgrammeReset] assignment: ${assignment.id} '
      'week=${assignment.currentWeek} day=${assignment.currentDayKey} '
      'slot=${assignment.currentSessionOrder}',
    );

    final outcomesBefore =
        await outcomeStoreImpl.listForAssignment(assignment.id);
    debugPrint(
      '[ProgrammeReset] outcomes before delete: ${outcomesBefore.length}',
    );

    final deleteResult = await outcomeStoreImpl.deleteOutcomesForAssignment(
      assignmentId: assignment.id,
    );
    debugPrint(
      '[ProgrammeReset] outcomes deleted: ${deleteResult.deletedCount}',
    );

    final outcomesAfter =
        await outcomeStoreImpl.listForAssignment(assignment.id);
    debugPrint(
      '[ProgrammeReset] outcomes after delete: ${outcomesAfter.length}',
    );

    if (outcomesBefore.isNotEmpty && deleteResult.deletedCount == 0) {
      throw ProgrammeStoreException(
        'Programme reset aborted: ${outcomesBefore.length} slot outcome(s) '
        'were visible before delete but DELETE removed 0 rows — check '
        'programme_slot_outcomes RLS DELETE policy '
        '(dev_programme_slot_outcomes_delete)',
        operation: 'ProgrammeReset',
        tableName: 'programme_slot_outcomes',
      );
    }

    if (outcomesAfter.isNotEmpty) {
      throw ProgrammeStoreException(
        'Programme reset aborted: ${outcomesAfter.length} slot outcome(s) '
        'remain after delete for assignment ${assignment.id}',
        operation: 'ProgrammeReset',
        tableName: 'programme_slot_outcomes',
      );
    }

    await assignmentStoreImpl.update(
      assignment.copyWith(
        currentWeek: 1,
        currentDayKey: 'day_1',
        currentSessionOrder: 1,
        status: ProgrammeAssignmentStatus.active,
        clearCompletedAt: true,
        clearLastProgressedTrainingSessionId: true,
      ),
    );
    debugPrint('[ProgrammeReset] cursor reset');

    ProgrammeDebugResolutionCache.clear();

    final resolution = await resolveCurrentTestSession(
      assignmentStore: assignmentStoreImpl,
      slotOutcomeStore: outcomeStoreImpl,
      versionStore: versionStore,
    );
    debugPrint('[ProgrammeReset] fresh resolution: $resolution');

    ProgrammeDebugResolutionCache.store(resolution);
    await (athleteStateSyncService ?? createAthleteStateSyncService())
        .syncFromResolvedSession(
      athleteId: devAthleteId,
      resolution: resolution,
    );
  }
}
