import 'package:flutter/material.dart';

import '../../../core/persistence/athlete_persistence.dart';

import '../../adaptation/services/adaptation_prescription_service.dart';
import '../../performance/controllers/performance_capture_controller.dart';
import '../../performance/models/active_performance_draft.dart';
import '../../performance/models/training_block_result_status.dart';
import '../../performance/models/training_session_record_status.dart';
import '../../performance/services/performance_record_save_coordinator.dart';
import '../../programme/models/programme_execution_context.dart';
import '../../programme/models/programme_progress_summary.dart';
import '../controllers/session_execution_controller.dart';
import '../models/production_restore_envelope.dart';
import '../models/production_restore_outcome.dart';
import '../models/production_session_draft.dart';
import '../models/session_execution_plan.dart';
import '../models/workout_session_launch_context.dart';
import '../presentation/production_restore_athlete_copy.dart';
import '../screens/active_session_screen.dart';
import '../screens/production_restore_blocked_screen.dart';
import 'circuit_block_timer_bridge.dart';
import 'production_restore_envelope_store.dart';
import 'production_restore_resolver.dart';
import 'session_execution_loader.dart';

/// Launches [ActiveSessionScreen] with the same wiring as session overview.
class SessionExecutionLauncher {
  SessionExecutionLauncher({
    SessionExecutionLoader? loader,
    PerformanceRecordSaveCoordinator? saveCoordinator,
    AdaptationPrescriptionService? prescriptionService,
    ProductionRestoreResolver? restoreResolver,
    ProductionRestoreEnvelopeStore? restoreEnvelopeStore,
  }) : _loader = loader ?? SessionExecutionLoader(),
       _saveCoordinator = saveCoordinator ?? PerformanceRecordSaveCoordinator(),
       _prescriptionService =
           prescriptionService ?? AdaptationPrescriptionService(),
       _restoreResolver = restoreResolver ?? const ProductionRestoreResolver(),
       _restoreEnvelopeStore =
           restoreEnvelopeStore ?? ProductionRestoreEnvelopeStore.instance;

  final SessionExecutionLoader _loader;
  final PerformanceRecordSaveCoordinator _saveCoordinator;
  final AdaptationPrescriptionService _prescriptionService;
  final ProductionRestoreResolver _restoreResolver;
  final ProductionRestoreEnvelopeStore _restoreEnvelopeStore;

  Future<void> launchActiveSession({
    required BuildContext context,
    required String protocolId,
    required int trainingSessionId,
    required String athleteId,
    String? displayTitle,
    ProgrammeExecutionContext? programmeContext,
    String? programmeContextLabel,
    ProgrammeProgressSummary? programmeProgress,
    WorkoutSessionLaunchContext? workoutLaunchContext,
  }) async {
    final resolvedProtocolId =
        workoutLaunchContext?.legacyProtocolId.trim().isNotEmpty == true
        ? workoutLaunchContext!.legacyProtocolId.trim()
        : protocolId;
    var loadOverrides = const <String, String>{};
    if (programmeContext != null && programmeContext.isProgrammeBacked) {
      loadOverrides = await _prescriptionService.loadLoadOverrides(
        assignmentId: programmeContext.assignmentId,
        sessionSlotId: programmeContext.sessionSlotId,
      );
    }

    final loadResult = await _loader.load(
      protocolId: resolvedProtocolId,
      displayTitle: displayTitle,
      programmeContextLabel: programmeContextLabel,
      prescriptionLoadOverrides: loadOverrides,
    );

    if (!context.mounted) return;

    await _pushActiveSession(
      context: context,
      plan: loadResult.plan,
      protocolId: resolvedProtocolId,
      trainingSessionId: trainingSessionId,
      athleteId: athleteId,
      programmeContext: programmeContext,
      programmeProgress: programmeProgress,
      workoutLaunchContext: workoutLaunchContext,
    );
  }

  Future<void> launchActiveSessionWithPlan({
    required BuildContext context,
    required SessionExecutionPlan plan,
    required String protocolId,
    required int trainingSessionId,
    required String athleteId,
    ProgrammeExecutionContext? programmeContext,
    ProgrammeProgressSummary? programmeProgress,
  }) {
    return _pushActiveSession(
      context: context,
      plan: plan,
      protocolId: protocolId,
      trainingSessionId: trainingSessionId,
      athleteId: athleteId,
      programmeContext: programmeContext,
      programmeProgress: programmeProgress,
    );
  }

  Future<void> _pushActiveSession({
    required BuildContext context,
    required SessionExecutionPlan plan,
    required String protocolId,
    required int trainingSessionId,
    required String athleteId,
    ProgrammeExecutionContext? programmeContext,
    ProgrammeProgressSummary? programmeProgress,
    WorkoutSessionLaunchContext? workoutLaunchContext,
  }) async {
    final sessionKey = AthleteSessionMemoryStore.sessionKey(
      protocolId: protocolId,
      trainingSessionId: trainingSessionId,
    );
    final memory = AthleteSessionMemoryStore.instance.read(sessionKey);
    var envelope = _restoreEnvelopeStore.read(
      athleteId: athleteId,
      trainingSessionId: trainingSessionId,
    );
    if (envelope == null && AthletePersistence.isInitialized) {
      final payload = await AthletePersistence.repository
          .readProductionRestoreEnvelope(
            athleteId: athleteId,
            trainingSessionId: trainingSessionId,
          );
      if (payload != null) {
        try {
          envelope = ProductionRestoreEnvelope.fromJson(payload);
          _restoreEnvelopeStore.write(envelope);
        } catch (_) {
          envelope = null;
        }
      }
    }

    var hostedCompleted = false;
    var existingRecord = await _saveCoordinator.loadInProgressDraftAsRecord(
      athleteId: athleteId,
      trainingSessionId: trainingSessionId,
    );
    if (existingRecord == null) {
      final terminal = await _saveCoordinator.store
          .getTerminalForTrainingSession(
            athleteId: athleteId,
            trainingSessionId: trainingSessionId,
          );
      hostedCompleted =
          terminal?.status == TrainingSessionRecordStatus.completed;
    }

    final actuals = existingRecord == null
        ? null
        : _saveCoordinator.restoreControllerFromRecord(existingRecord).draft;

    final decision = _decideRestore(
      athleteId: athleteId,
      trainingSessionId: trainingSessionId,
      programmeContext: programmeContext,
      actuals: actuals,
      envelope: envelope,
      hostedCompleted: hostedCompleted,
    );
    _applyRestorePolicy(
      sessionKey: sessionKey,
      memoryPresent: memory != null,
      decision: decision,
    );

    final controller = SessionExecutionController(
      plan: plan,
      sessionKey: sessionKey,
      restoredState: null,
      workoutLaunchContext: workoutLaunchContext,
    );

    late final PerformanceCaptureController performanceController;
    if (decision.mayEnterWithRestoredActuals && decision.actuals != null) {
      performanceController = PerformanceCaptureController(
        draft: decision.actuals!,
      );
      final durableDraft = performanceController.draft;
      controller.restoreFromDurableDraft(
        completedBlockIds: durableDraft.blockDrafts
            .where(
              (block) => block.status == TrainingBlockResultStatus.completed,
            )
            .map((block) => block.sourceBlockId)
            .toSet(),
        activeBlockId:
            decision.cursor?.activeBlockId ?? durableDraft.activeBlockId,
        expandedBlockIds: decision.cursor?.expandedBlockIds,
      );
    } else if (decision.mayBeginFresh) {
      performanceController =
          PerformanceCaptureController.initializeFromExecutionPlan(
            plan: plan,
            athleteId: athleteId,
            trainingSessionId: trainingSessionId,
            programmeContext: programmeContext,
          );
      await _saveCoordinator.createOrResumeInProgress(
        controller: performanceController,
      );
      _writeIdentityEnvelope(
        athleteId: athleteId,
        trainingSessionId: trainingSessionId,
        programmeContext: programmeContext,
        performanceController: performanceController,
      );
      controller.startSession();
    } else if (decision.outcome == ProductionRestoreOutcome.completedHosted) {
      throw _restoreFailure(decision);
    } else {
      if (!context.mounted) throw _restoreFailure(decision);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProductionRestoreBlockedScreen(decision: decision),
        ),
      );
      return;
    }

    if (!context.mounted) return;

    var openRestoredTimer = false;
    if (decision.mayEnterWithRestoredActuals) {
      for (final block in plan.blocks) {
        final result = performanceController.draft
            .blockDraftFor(block.blockId)
            ?.resultData;
        if (CircuitBlockTimerBridge.restoredState(
              block: block,
              result: result,
            ) !=
            null) {
          openRestoredTimer = true;
          break;
        }
      }
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActiveSessionScreen(
          controller: controller,
          performanceController: performanceController,
          trainingSessionId: trainingSessionId,
          programmeContext: programmeContext,
          programmeProgress: programmeProgress,
          athleteId: athleteId,
          saveCoordinator: _saveCoordinator,
          workoutLaunchContext: workoutLaunchContext,
          restoreEnvelopeStore: _restoreEnvelopeStore,
          openRestoredTimer: openRestoredTimer,
        ),
      ),
    );
  }

  ProductionRestoreDecision _decideRestore({
    required String athleteId,
    required int trainingSessionId,
    required ProgrammeExecutionContext? programmeContext,
    required ActivePerformanceDraft? actuals,
    required ProductionRestoreEnvelope? envelope,
    required bool hostedCompleted,
  }) {
    if (programmeContext == null || !programmeContext.isProgrammeBacked) {
      if (hostedCompleted) {
        return ProductionRestoreDecision(
          outcome: ProductionRestoreOutcome.completedHosted,
          athleteMessage: ProductionRestoreAthleteCopy.message(
            ProductionRestoreOutcome.completedHosted,
          ),
        );
      }
      if (actuals != null && actuals.athleteId == athleteId) {
        return ProductionRestoreDecision(
          outcome: ProductionRestoreOutcome.resumable,
          athleteMessage: ProductionRestoreAthleteCopy.message(
            ProductionRestoreOutcome.resumable,
          ),
          mayEnterWithRestoredActuals: true,
          actuals: actuals,
          cursor: envelope?.cursor,
          restoreCursor: envelope?.cursor != null,
        );
      }
      if (actuals != null && actuals.athleteId != athleteId) {
        return ProductionRestoreDecision(
          outcome: ProductionRestoreOutcome.foreignAthlete,
          athleteMessage: ProductionRestoreAthleteCopy.message(
            ProductionRestoreOutcome.foreignAthlete,
          ),
          actuals: actuals,
        );
      }
      return ProductionRestoreDecision(
        outcome: ProductionRestoreOutcome.noDraft,
        athleteMessage: ProductionRestoreAthleteCopy.message(
          ProductionRestoreOutcome.noDraft,
        ),
        mayBeginFresh: true,
      );
    }

    return _restoreResolver.resolve(
      ProductionRestoreRequest(
        athleteId: athleteId,
        assignmentId: programmeContext.assignmentId,
        programmeVersionId: programmeContext.programmeVersionId,
        programmedSessionKey: programmeContext.programmedSessionKey ?? '',
        packageContentHash: programmeContext.packageContentHash ?? '',
        occurrenceId: programmeContext.occurrenceId,
        trainingSessionId: trainingSessionId,
        hostedCompleted: hostedCompleted,
        persistedIdentity: envelope?.identity,
        actuals: actuals,
        cursor: envelope?.cursor,
        memoryState: null,
      ),
    );
  }

  void _applyRestorePolicy({
    required String sessionKey,
    required bool memoryPresent,
    required ProductionRestoreDecision decision,
  }) {
    if (decision.discardMemory || memoryPresent) {
      AthleteSessionMemoryStore.instance.clear(sessionKey);
    }
  }

  void _writeIdentityEnvelope({
    required String athleteId,
    required int trainingSessionId,
    required ProgrammeExecutionContext? programmeContext,
    required PerformanceCaptureController performanceController,
  }) {
    if (programmeContext == null || !programmeContext.isProgrammeBacked) {
      return;
    }
    _restoreEnvelopeStore.write(
      ProductionRestoreEnvelope(
        identity: ProductionSessionDraft(
          schemaVersion: ProductionSessionDraft.currentSchemaVersion,
          athleteId: athleteId,
          assignmentId: programmeContext.assignmentId,
          programmeVersionId: programmeContext.programmeVersionId,
          programmedSessionKey: programmeContext.programmedSessionKey ?? '',
          packageContentHash: programmeContext.packageContentHash ?? '',
          trainingSessionId: trainingSessionId,
          entryMode: 'live',
          occurrenceId: programmeContext.occurrenceId,
          startedAt: performanceController.draft.startedAt,
        ),
      ),
    );
  }

  Exception _restoreFailure(ProductionRestoreDecision decision) {
    return ProductionRestoreException(
      decision.outcome,
      decision.athleteMessage,
    );
  }
}
