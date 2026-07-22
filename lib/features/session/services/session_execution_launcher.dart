import 'package:flutter/material.dart';

import '../../adaptation/services/adaptation_prescription_service.dart';
import '../../performance/controllers/performance_capture_controller.dart';
import '../../performance/services/performance_record_save_coordinator.dart';
import '../../programme/models/programme_execution_context.dart';
import '../../programme/models/programme_progress_summary.dart';
import '../controllers/session_execution_controller.dart';
import '../models/session_execution_plan.dart';
import '../models/session_execution_status.dart';
import '../screens/active_session_screen.dart';
import 'session_execution_loader.dart';

/// Launches [ActiveSessionScreen] with the same wiring as session overview.
class SessionExecutionLauncher {
  SessionExecutionLauncher({
    SessionExecutionLoader? loader,
    PerformanceRecordSaveCoordinator? saveCoordinator,
    AdaptationPrescriptionService? prescriptionService,
  })  : _loader = loader ?? SessionExecutionLoader(),
        _saveCoordinator =
            saveCoordinator ?? PerformanceRecordSaveCoordinator(),
        _prescriptionService =
            prescriptionService ?? AdaptationPrescriptionService();

  final SessionExecutionLoader _loader;
  final PerformanceRecordSaveCoordinator _saveCoordinator;
  final AdaptationPrescriptionService _prescriptionService;

  Future<void> launchActiveSession({
    required BuildContext context,
    required String protocolId,
    required int trainingSessionId,
    required String athleteId,
    String? displayTitle,
    ProgrammeExecutionContext? programmeContext,
    String? programmeContextLabel,
    ProgrammeProgressSummary? programmeProgress,
  }) async {
    var loadOverrides = const <String, String>{};
    if (programmeContext != null && programmeContext.isProgrammeBacked) {
      loadOverrides = await _prescriptionService.loadLoadOverrides(
        assignmentId: programmeContext.assignmentId,
        sessionSlotId: programmeContext.sessionSlotId,
      );
    }

    final loadResult = await _loader.load(
      protocolId: protocolId,
      displayTitle: displayTitle,
      programmeContextLabel: programmeContextLabel,
      prescriptionLoadOverrides: loadOverrides,
    );

    if (!context.mounted) return;

    await _pushActiveSession(
      context: context,
      plan: loadResult.plan,
      protocolId: protocolId,
      trainingSessionId: trainingSessionId,
      athleteId: athleteId,
      programmeContext: programmeContext,
      programmeProgress: programmeProgress,
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
  }) async {
    final sessionKey = AthleteSessionMemoryStore.sessionKey(
      protocolId: protocolId,
      trainingSessionId: trainingSessionId,
    );
    final restored = AthleteSessionMemoryStore.instance.read(sessionKey);
    final controller = SessionExecutionController(
      plan: plan,
      sessionKey: sessionKey,
      restoredState: restored,
    );

    final continueSession =
        restored?.sessionStatus == SessionExecutionStatus.inProgress;

    PerformanceCaptureController performanceController;
    final existingRecord = await _saveCoordinator.loadInProgressDraftAsRecord(
      athleteId: athleteId,
      trainingSessionId: trainingSessionId,
    );

    if (existingRecord != null) {
      performanceController =
          _saveCoordinator.restoreControllerFromRecord(existingRecord);
    } else {
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
    }

    if (!continueSession) {
      controller.startSession();
    }

    if (!context.mounted) return;

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
        ),
      ),
    );
  }
}
