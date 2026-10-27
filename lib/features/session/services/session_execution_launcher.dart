import 'package:flutter/material.dart';
import '../../../domain/hyrox_base/programme_prescription.dart';

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
import '../models/structured_running_execution.dart';
import '../models/authored_timed_running_execution.dart';
import '../models/running_target_admission.dart';
import '../models/workout_session_launch_context.dart';
import '../presentation/production_restore_athlete_copy.dart';
import '../screens/active_session_screen.dart';
import '../screens/production_restore_blocked_screen.dart';
import 'circuit_block_timer_bridge.dart';
import 'production_restore_envelope_store.dart';
import 'production_restore_resolver.dart';
import 'session_execution_loader.dart';
import 'structured_running_controller.dart';

/// Optional destination owned by the surface that launched a session.
///
/// Calendar uses this to select athlete Home after a confirmed completion.
/// The callback changes only the shell destination; the completion route
/// remains the sole owner of Navigator stack unwinding.
class SessionCompletionDestinationScope extends InheritedWidget {
  const SessionCompletionDestinationScope({
    super.key,
    required this.onSessionCompleted,
    required super.child,
  });

  final VoidCallback onSessionCompleted;

  static VoidCallback? maybeOf(BuildContext context) {
    return context
        .getInheritedWidgetOfExactType<SessionCompletionDestinationScope>()
        ?.onSessionCompleted;
  }

  @override
  bool updateShouldNotify(SessionCompletionDestinationScope oldWidget) {
    return onSessionCompleted != oldWidget.onSessionCompleted;
  }
}

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
    VerifiedStructuredRunningExecution? structuredRunningExecution,
  }) {
    return _pushActiveSession(
      context: context,
      plan: plan,
      protocolId: protocolId,
      trainingSessionId: trainingSessionId,
      athleteId: athleteId,
      programmeContext: programmeContext,
      programmeProgress: programmeProgress,
      structuredRunningExecution: structuredRunningExecution,
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
    VerifiedStructuredRunningExecution? structuredRunningExecution,
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
    var envelopeCorrupt = false;
    var hasSteadyStateTimerData =
        (envelope?.cursor?.steadyStateTimers.isNotEmpty == true ||
        envelope?.cursor?.timedRunning.isNotEmpty == true);
    if (envelope == null && AthletePersistence.isInitialized) {
      final payload = await AthletePersistence.repository
          .readProductionRestoreEnvelope(
            athleteId: athleteId,
            trainingSessionId: trainingSessionId,
          );
      if (payload != null) {
        final rawCursor = payload['cursor'];
        hasSteadyStateTimerData =
            rawCursor is Map &&
            (rawCursor.containsKey('steady_state_timers') ||
                rawCursor.containsKey('authored_timed_runs'));
        try {
          envelope = ProductionRestoreEnvelope.fromJson(payload);
          _restoreEnvelopeStore.write(envelope);
        } catch (_) {
          envelope = null;
          envelopeCorrupt = true;
        }
      }
    }
    if (envelope?.cursor?.hasInvalidStructuredScope == true ||
        envelope?.cursor?.hasInvalidSteadyStateScope == true ||
        envelope?.cursor?.hasInvalidTimedRunningScope == true) {
      envelopeCorrupt = true;
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

    if (existingRecord != null &&
        (!samePrescription(
              existingRecord.sessionSnapshot.boundPrescription?.json,
              plan.boundPrescriptionSnapshot,
            ) ||
            !samePrescription(
              existingRecord.sessionSnapshot.runningTargetAdmissionSnapshot,
              plan.runningTargetAdmissionSnapshot,
            ) ||
            !samePrescription(
              existingRecord.sessionSnapshot.durationChoiceSnapshot,
              plan.durationChoiceSnapshot,
            ) ||
            !samePrescription(
              existingRecord.sessionSnapshot.authoredSource,
              plan.authoredSource,
            ))) {
      throw const FormatException(
        'Saved prescription or duration choice does not match the started session. Reopen this session online.',
      );
    }

    if (plan.runningTargetAdmissionSnapshot case final admitted?) {
      if (programmeContext?.occurrenceId == null ||
          admitted['training_session_id'] != trainingSessionId) {
        throw const FormatException(
          'Frozen running targets do not match this session.',
        );
      }
      validateRunningTargetDocument(
        plan,
        admitted,
        athleteId: athleteId,
        occurrenceId: programmeContext!.occurrenceId!,
        assignmentId: programmeContext.assignmentId,
        versionId: programmeContext.programmeVersionId,
        packageHash: programmeContext.packageContentHash!,
      );
    }

    // Pin the complete authored body independently of the disposable UI cursor.
    // Discarding a damaged timer must never admit a changed prescription.
    for (final block in plan.blocks) {
      if (block.timerConfiguration?.runningWorkout != null) {
        AuthoredTimedRunningExecution.fromBlock(
          block,
          admission: plan.runningTargetAdmissionSnapshot,
        );
        if (structuredRunningExecution?.sessionBlockId == block.blockId) {
          throw const FormatException(
            'Conflicting running execution authorities.',
          );
        }
      }
    }
    if (existingRecord != null &&
        !samePrescription(
          {
            for (final block in existingRecord.sessionSnapshot.blocks)
              if (block.timedRunningWorkout != null)
                block.sourceBlockId: block.timedRunningWorkout,
          },
          {
            for (final block in plan.blocks)
              if (block.timerConfiguration?.runningWorkout != null)
                block.blockId: block.timerConfiguration!
                    .toJson()['running_workout'],
          },
        )) {
      throw const FormatException(
        'The saved running workout has changed. Reopen the original session.',
      );
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
      envelopeCorrupt: envelopeCorrupt,
    );
    _applyRestorePolicy(
      sessionKey: sessionKey,
      memoryPresent: memory != null,
      decision: decision,
    );

    final structuredCursor = decision.cursor?.structuredRunning;
    final steadyTimers = decision.cursor?.steadyStateTimers ?? const {};
    final timedRuns = decision.cursor?.timedRunning ?? const {};
    try {
      if ((steadyTimers.isNotEmpty || timedRuns.isNotEmpty) &&
          !plan.blocks.any(
            (block) => block.blockId == decision.cursor?.activeBlockId,
          )) {
        throw const FormatException('The saved active block is unavailable.');
      }
      for (final cursor in timedRuns.values) {
        final blocks = plan.blocks
            .where((block) => block.blockId == cursor.sessionBlockId)
            .toList();
        if (blocks.length != 1) {
          throw const FormatException('The saved run is unavailable.');
        }
        final block = blocks.single;
        try {
          StructuredRunningController.restore(
            execution: AuthoredTimedRunningExecution.fromBlock(
              block,
              admission: plan.runningTargetAdmissionSnapshot,
            ),
            cursor: cursor,
          ).dispose();
        } on StructuredRunningExecutionException {
          throw const FormatException(
            'The saved run no longer matches its source.',
          );
        }
      }
      for (final timer in steadyTimers.values) {
        final blocks = plan.blocks.where(
          (block) => block.blockId == timer.blockId,
        );
        if (blocks.length != 1 ||
            !blocks.single.hasTimer ||
            blocks.single.timerConfiguration?.runningWorkout != null) {
          throw const FormatException('The saved timer block is unavailable.');
        }
        CircuitBlockTimerBridge.restoredState(
          block: blocks.single,
          result: null,
          steadyStateTimer: timer,
        );
      }
    } on FormatException {
      if (!context.mounted) return;
      await _showSteadyStateRecovery(
        context: context,
        athleteId: athleteId,
        trainingSessionId: trainingSessionId,
        decision: ProductionRestoreDecision(
          outcome: ProductionRestoreOutcome.conflict,
          athleteMessage: ProductionRestoreAthleteCopy.message(
            ProductionRestoreOutcome.conflict,
          ),
        ),
      );
      return;
    }
    if (structuredCursor != null) {
      if (structuredRunningExecution == null) {
        throw _structuredRestoreFailure();
      }
      try {
        StructuredRunningController.restore(
          execution: structuredRunningExecution,
          cursor: structuredCursor,
        ).dispose();
      } on StructuredRunningExecutionException {
        throw _structuredRestoreFailure();
      }
    }

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
      if (structuredRunningExecution != null) {
        performanceController.bindStructuredRunning(
          execution: structuredRunningExecution,
          allowInitialize: false,
        );
      }
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
      if (structuredRunningExecution != null) {
        performanceController.bindStructuredRunning(
          execution: structuredRunningExecution,
          allowInitialize: true,
        );
      }
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
      if (hasSteadyStateTimerData &&
          ProductionRestoreAthleteCopy.offersDiscard(decision.outcome)) {
        await _showSteadyStateRecovery(
          context: context,
          athleteId: athleteId,
          trainingSessionId: trainingSessionId,
          decision: decision,
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProductionRestoreBlockedScreen(decision: decision),
        ),
      );
      return;
    }

    if (!context.mounted) return;
    final onSessionCompleted = SessionCompletionDestinationScope.maybeOf(
      context,
    );

    var openRestoredTimer = false;
    if (decision.mayEnterWithRestoredActuals) {
      // Prior blocks may also have timer evidence. Open only the active step.
      final activeBlock = controller.state.activeBlock;
      if (activeBlock != null) {
        final block = activeBlock;
        if (performanceController.draft.blockDraftFor(block.blockId)?.status ==
            TrainingBlockResultStatus.completed) {
          openRestoredTimer = false;
        } else {
          final result = performanceController.draft
              .blockDraftFor(block.blockId)
              ?.resultData;
          if (timedRuns.containsKey(block.blockId) ||
              structuredCursor?.sessionBlockId == block.blockId ||
              CircuitBlockTimerBridge.restoredState(
                    block: block,
                    result: result,
                    steadyStateTimer: steadyTimers[block.blockId],
                  ) !=
                  null) {
            openRestoredTimer = true;
          }
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
          structuredRunningExecution: structuredRunningExecution,
          restoredStructuredRunningCursor: structuredCursor,
          restoredSteadyStateTimers: steadyTimers,
          restoredTimedRunning: timedRuns,
          onSessionCompleted: onSessionCompleted,
        ),
      ),
    );
  }

  Future<void> _showSteadyStateRecovery({
    required BuildContext context,
    required String athleteId,
    required int trainingSessionId,
    required ProductionRestoreDecision decision,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (recoveryContext) => ProductionRestoreBlockedScreen(
        decision: decision,
        onDiscardDraft: () async {
          try {
            if (AthletePersistence.isInitialized) {
              await AthletePersistence.repository
                  .clearProductionRestoreEnvelope(
                    athleteId: athleteId,
                    trainingSessionId: trainingSessionId,
                  );
            }
            _restoreEnvelopeStore.clear(
              athleteId: athleteId,
              trainingSessionId: trainingSessionId,
            );
            if (recoveryContext.mounted) Navigator.of(recoveryContext).pop();
          } catch (_) {
            if (recoveryContext.mounted) {
              ScaffoldMessenger.of(recoveryContext).showSnackBar(
                const SnackBar(
                  content: Text('Could not clear saved timer. Retry.'),
                ),
              );
            }
          }
        },
      ),
    ),
  );

  ProductionRestoreDecision _decideRestore({
    required String athleteId,
    required int trainingSessionId,
    required ProgrammeExecutionContext? programmeContext,
    required ActivePerformanceDraft? actuals,
    required ProductionRestoreEnvelope? envelope,
    required bool hostedCompleted,
    bool envelopeCorrupt = false,
  }) {
    if (envelopeCorrupt && !hostedCompleted) {
      return ProductionRestoreDecision(
        outcome: ProductionRestoreOutcome.corrupt,
        athleteMessage: ProductionRestoreAthleteCopy.message(
          ProductionRestoreOutcome.corrupt,
        ),
      );
    }
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

  ProductionRestoreException _structuredRestoreFailure() {
    return ProductionRestoreException(
      ProductionRestoreOutcome.conflict,
      ProductionRestoreAthleteCopy.message(ProductionRestoreOutcome.conflict),
    );
  }
}
