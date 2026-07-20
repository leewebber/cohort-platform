import 'package:flutter/foundation.dart';

import '../../../core/constants/programme_dev_identity.dart';
import '../../../data/repositories/athlete_state_supabase_store.dart';
import '../../../data/repositories/programme_assignment_store.dart';
import '../../../data/repositories/programme_assignment_supabase_store.dart';
import '../../../data/repositories/programme_slot_outcome_store.dart';
import '../../../data/repositories/programme_slot_outcome_supabase_store.dart';
import '../../../data/repositories/programme_version_store.dart';
import '../../../data/repositories/programme_version_supabase_store.dart';
import '../../../models/programme_assignment.dart';
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
import '../../founder_acceptance/founder_acceptance_installer.dart';
import '../../founder_acceptance/founder_acceptance_install_result.dart';
import '../../founder_acceptance/founder_acceptance_runtime_reset_service.dart';
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

  /// Installs or updates the Founder Acceptance Programme and canonical session.
  static Future<FounderAcceptanceInstallResult> installFounderAcceptanceProgramme({
    FounderAcceptanceInstaller? installer,
  }) {
    return (installer ?? FounderAcceptanceInstaller()).install();
  }

  /// Assigns the Founder Acceptance Programme to the dev athlete.
  ///
  /// Developer-only: replaces any other active debug assignment and is
  /// idempotent when Founder Acceptance v1 is already active.
  static Future<ProgrammeAssignmentOperationResult> assignFounderAcceptanceProgramme({
    ProgrammeAssignmentService? assignmentService,
    ProgrammeAssignmentStore? assignmentStore,
    ProgrammeSlotOutcomeStore? slotOutcomeStore,
    ProgrammeVersionStore? versionStore,
    AthleteStateSyncService? athleteStateSyncService,
  }) async {
    final store = assignmentStore ?? const ProgrammeAssignmentSupabaseStore();
    final existing = await store.getActiveAssignment(devAthleteId);

    if (_isFounderAcceptanceAssignment(existing)) {
      return _syncExistingFounderAcceptanceAssignment(
        assignment: existing!,
        assignmentStore: store,
        slotOutcomeStore: slotOutcomeStore,
        versionStore: versionStore,
        athleteStateSyncService: athleteStateSyncService,
      );
    }

    final service = assignmentService ??
        createAssignmentService(
          assignmentStore: store,
          slotOutcomeStore: slotOutcomeStore,
          versionStore: versionStore,
          athleteStateSyncService: athleteStateSyncService,
        );

    final result = await service.assignByLineageVersion(
      athleteId: devAthleteId,
      lineageCode: ProgrammeDevFixtures.founderAcceptanceLineageCode,
      versionNumber: 1,
      startedAt: DateTime.utc(2026, 7, 15),
      timezone: 'UTC',
      replaceExistingActive: existing != null,
      allowUnpublishedVersion: true,
    );

    if (result.resolvedTodaySession != null) {
      ProgrammeDebugResolutionCache.store(result.resolvedTodaySession!);
    }

    debugPrint('[FounderAcceptanceAssign] result: $result');
    return result;
  }

  static bool _isFounderAcceptanceAssignment(ProgrammeAssignment? assignment) {
    return assignment != null &&
        assignment.lineageCode ==
            ProgrammeDevFixtures.founderAcceptanceLineageCode &&
        assignment.programmeVersionId ==
            ProgrammeDevFixtures.founderAcceptanceVersionId;
  }

  static Future<ProgrammeAssignmentOperationResult>
      _syncExistingFounderAcceptanceAssignment({
    required ProgrammeAssignment assignment,
    required ProgrammeAssignmentStore assignmentStore,
    ProgrammeSlotOutcomeStore? slotOutcomeStore,
    ProgrammeVersionStore? versionStore,
    AthleteStateSyncService? athleteStateSyncService,
  }) async {
    debugPrint(
      '[FounderAcceptanceAssign] idempotent: active founder assignment '
      '${assignment.id}',
    );

    final todayService = createTodaySessionService(
      assignmentStore: assignmentStore,
      slotOutcomeStore: slotOutcomeStore,
      versionStore: versionStore,
    );
    final sync =
        athleteStateSyncService ?? createAthleteStateSyncService();

    try {
      final resolution = await todayService.resolveForAthlete(devAthleteId);
      var synced = true;
      try {
        await sync.syncFromResolvedSession(
          athleteId: devAthleteId,
          resolution: resolution,
        );
      } catch (error) {
        synced = false;
        debugPrint(
          '[FounderAcceptanceAssign] projectionSynced=false error=$error',
        );
      }

      ProgrammeDebugResolutionCache.store(resolution);

      final result = ProgrammeAssignmentOperationResult(
        status: synced
            ? ProgrammeAssignmentOperationStatus.assigned
            : ProgrammeAssignmentOperationStatus.partialSuccess,
        assignment: assignment,
        resolvedTodaySession: resolution,
        athleteStateSynced: synced,
        warnings: synced
            ? const []
            : const ['athlete_state projection sync failed'],
      );
      debugPrint('[FounderAcceptanceAssign] result: $result');
      return result;
    } catch (error) {
      final result = ProgrammeAssignmentOperationResult.failed(
        message: error.toString(),
      );
      debugPrint('[FounderAcceptanceAssign] result: $result');
      return result;
    }
  }

  /// Resolves today's Founder Acceptance session only.
  static Future<ResolvedTodaySession> resolveFounderAcceptanceProgramme({
    ProgrammeAssignmentStore? assignmentStore,
    ProgrammeSlotOutcomeStore? slotOutcomeStore,
    ProgrammeVersionStore? versionStore,
  }) {
    return resolveProgrammeSessionForLineage(
      lineageCode: ProgrammeDevFixtures.founderAcceptanceLineageCode,
      assignmentStore: assignmentStore,
      slotOutcomeStore: slotOutcomeStore,
      versionStore: versionStore,
    );
  }

  /// Resets the active Founder Acceptance assignment cursor and outcomes.
  static Future<ProgrammeAssignmentOperationResult>
      resetFounderAcceptanceProgrammeAssignment({
    ProgrammeAssignmentStore? assignmentStore,
    ProgrammeSlotOutcomeStore? slotOutcomeStore,
    ProgrammeVersionStore? versionStore,
    ProgrammeAssignmentDevelopmentService? developmentService,
    FounderAcceptanceRuntimeResetService? runtimeResetService,
  }) async {
    final result = await resetProgrammeAssignmentForLineage(
      lineageCode: ProgrammeDevFixtures.founderAcceptanceLineageCode,
      assignmentStore: assignmentStore,
      slotOutcomeStore: slotOutcomeStore,
      versionStore: versionStore,
      developmentService: developmentService,
    );

    if (!result.isSuccess || result.assignment == null) {
      return result;
    }

    try {
      await (runtimeResetService ?? FounderAcceptanceRuntimeResetService())
          .clearFounderRuntimeState(
        athleteId: devAthleteId,
        assignmentId: result.assignment!.id,
      );
    } catch (error) {
      debugPrint('[FounderAcceptanceReset] runtime cleanup failed: $error');
      return ProgrammeAssignmentOperationResult(
        status: ProgrammeAssignmentOperationStatus.partialSuccess,
        assignment: result.assignment,
        resolvedTodaySession: result.resolvedTodaySession,
        athleteStateSynced: result.athleteStateSynced,
        warnings: [
          ...result.warnings,
          'Founder runtime cleanup failed: $error',
        ],
      );
    }

    return result;
  }

  static Future<ResolvedTodaySession> resolveProgrammeSessionForLineage({
    required String lineageCode,
    ProgrammeAssignmentStore? assignmentStore,
    ProgrammeSlotOutcomeStore? slotOutcomeStore,
    ProgrammeVersionStore? versionStore,
  }) async {
    final service = createTodaySessionService(
      assignmentStore: assignmentStore,
      slotOutcomeStore: slotOutcomeStore,
      versionStore: versionStore,
    );
    final assignmentStoreImpl =
        assignmentStore ?? const ProgrammeAssignmentSupabaseStore();
    final active = await assignmentStoreImpl.getActiveAssignment(devAthleteId);
    if (active == null || active.lineageCode != lineageCode) {
      return ResolvedTodaySession.noActiveProgramme();
    }
    return service.resolveForAthlete(devAthleteId);
  }

  static Future<ProgrammeAssignmentOperationResult>
      resetProgrammeAssignmentForLineage({
    required String lineageCode,
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

    final active = await assignmentStoreImpl.getActiveAssignment(devAthleteId);
    if (active == null || active.lineageCode != lineageCode) {
      return ProgrammeAssignmentOperationResult.noAssignment(
        message:
            'No active $lineageCode assignment for $devAthleteId — assign first',
      );
    }

    debugPrint(
      '[ProgrammeReset] assignment: ${active.id} '
      'lineage=$lineageCode week=${active.currentWeek} '
      'day=${active.currentDayKey} slot=${active.currentSessionOrder}',
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
