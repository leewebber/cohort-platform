import 'package:flutter/foundation.dart';

import '../../../core/constants/programme_dev_identity.dart';
import '../../../data/repositories/athlete_state_supabase_store.dart';
import '../../../data/repositories/programme_assignment_store.dart';
import '../../../data/repositories/programme_assignment_supabase_store.dart';
import '../../../data/repositories/programme_slot_outcome_store.dart';
import '../../../data/repositories/programme_slot_outcome_supabase_store.dart';
import '../../../data/repositories/programme_version_store.dart';
import '../../../data/repositories/programme_version_supabase_store.dart';
import '../models/programme_assignment_operation_result.dart';
import '../models/resolved_today_session.dart';
import '../services/athlete_state_sync_service.dart';
import '../services/athlete_state_sync_service_impl.dart';
import '../services/programme_assignment_development_service.dart';
import '../services/programme_assignment_development_service_impl.dart';
import '../services/programme_assignment_service.dart';
import '../services/programme_assignment_service_impl.dart';
import '../services/programme_progression_service.dart';
import '../services/programme_progression_service_impl.dart';
import '../services/programme_schedule_resolver_impl.dart';
import '../services/programme_slot_outcome_service_impl.dart';
import '../services/today_session_service.dart';
import '../services/today_session_service_impl.dart';
import 'programme_debug_resolution_cache.dart';
import 'programme_dev_fixtures.dart';

/// Temporary Home debug helpers for programme service validation.
class ProgrammeDebugActions {
  ProgrammeDebugActions._();

  static const devAthleteId = ProgrammeDevIdentity.athleteId;

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

  static ProgrammeAssignmentService createAssignmentService({
    ProgrammeAssignmentStore? assignmentStore,
    ProgrammeVersionStore? versionStore,
    ProgrammeSlotOutcomeStore? slotOutcomeStore,
    AthleteStateSyncService? athleteStateSyncService,
  }) {
    final assignment =
        assignmentStore ?? const ProgrammeAssignmentSupabaseStore();
    final versions = versionStore ?? const ProgrammeVersionSupabaseStore();
    final outcomes =
        slotOutcomeStore ?? const ProgrammeSlotOutcomeSupabaseStore();
    final sync = athleteStateSyncService ??
        AthleteStateSyncServiceImpl(
          athleteStateStore: const AthleteStateSupabaseStore(),
        );

    return ProgrammeAssignmentServiceImpl(
      assignmentStore: assignment,
      versionStore: versions,
      scheduleResolver: const ProgrammeScheduleResolverImpl(),
      todaySessionService: createTodaySessionService(
        assignmentStore: assignment,
        slotOutcomeStore: outcomes,
        versionStore: versions,
      ),
      athleteStateSyncService: sync,
    );
  }

  static ProgrammeAssignmentDevelopmentService createDevelopmentService({
    ProgrammeAssignmentStore? assignmentStore,
    ProgrammeSlotOutcomeStore? slotOutcomeStore,
    ProgrammeVersionStore? versionStore,
    AthleteStateSyncService? athleteStateSyncService,
  }) {
    final assignment =
        assignmentStore ?? const ProgrammeAssignmentSupabaseStore();
    final versions = versionStore ?? const ProgrammeVersionSupabaseStore();
    final outcomes =
        slotOutcomeStore ?? const ProgrammeSlotOutcomeSupabaseStore();
    final sync = athleteStateSyncService ??
        AthleteStateSyncServiceImpl(
          athleteStateStore: const AthleteStateSupabaseStore(),
        );

    return ProgrammeAssignmentDevelopmentServiceImpl(
      assignmentStore: assignment,
      slotOutcomeStore: outcomes,
      versionStore: versions,
      scheduleResolver: const ProgrammeScheduleResolverImpl(),
      todaySessionService: createTodaySessionService(
        assignmentStore: assignment,
        slotOutcomeStore: outcomes,
        versionStore: versions,
      ),
      athleteStateSyncService: sync,
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

  /// Assigns the foundation test programme to the dev athlete.
  static Future<ProgrammeAssignmentOperationResult> assignTestProgramme({
    ProgrammeAssignmentService? assignmentService,
    bool replaceExistingActive = false,
  }) {
    final service =
        assignmentService ?? createAssignmentService();

    return service.assignByLineageVersion(
      athleteId: devAthleteId,
      lineageCode: ProgrammeDevFixtures.foundationTestLineageCode,
      versionNumber: 1,
      startedAt: DateTime.utc(2026, 7, 15),
      timezone: 'UTC',
      replaceExistingActive: replaceExistingActive,
      allowUnpublishedVersion: true,
    );
  }

  /// Resolves today's session only — never creates or repairs assignments.
  static Future<ResolvedTodaySession> resolveCurrentTestSession({
    ProgrammeAssignmentStore? assignmentStore,
    ProgrammeSlotOutcomeStore? slotOutcomeStore,
    ProgrammeVersionStore? versionStore,
  }) async {
    final service = createTodaySessionService(
      assignmentStore: assignmentStore,
      slotOutcomeStore: slotOutcomeStore,
      versionStore: versionStore,
    );
    return service.resolveForAthlete(devAthleteId);
  }

  static Future<ProgrammeAssignmentOperationResult> resetTestProgrammeAssignment({
    ProgrammeAssignmentStore? assignmentStore,
    ProgrammeSlotOutcomeStore? slotOutcomeStore,
    ProgrammeVersionStore? versionStore,
    ProgrammeAssignmentDevelopmentService? developmentService,
  }) async {
    final assignmentStoreImpl =
        assignmentStore ?? const ProgrammeAssignmentSupabaseStore();
    final service = developmentService ??
        createDevelopmentService(
          assignmentStore: assignmentStoreImpl,
          slotOutcomeStore:
              slotOutcomeStore ?? const ProgrammeSlotOutcomeSupabaseStore(),
          versionStore: versionStore ?? const ProgrammeVersionSupabaseStore(),
        );

    final active =
        await assignmentStoreImpl.getActiveAssignment(devAthleteId);
    if (active == null) {
      return ProgrammeAssignmentOperationResult.noAssignment(
        message: 'No active assignment for $devAthleteId — run Assign Test Programme first',
      );
    }

    debugPrint(
      '[ProgrammeReset] assignment: ${active.id} '
      'week=${active.currentWeek} day=${active.currentDayKey} '
      'slot=${active.currentSessionOrder}',
    );

    final result = await service.resetAssignment(
      assignmentId: active.id,
      weekNumber: 1,
      dayKey: 'day_1',
      slotOrder: 1,
      clearOutcomes: true,
    );

    if (result.resolvedTodaySession != null) {
      ProgrammeDebugResolutionCache.store(result.resolvedTodaySession!);
    } else {
      ProgrammeDebugResolutionCache.clear();
    }

    debugPrint('[ProgrammeReset] result: $result');
    return result;
  }
}
