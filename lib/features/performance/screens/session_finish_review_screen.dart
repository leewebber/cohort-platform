import 'dart:async';

import 'package:flutter/material.dart';

import '../../../application/athlete_workout/athlete_workout_completion_application_service.dart';
import '../../../application/athlete_workout/home_workout_execution_context.dart';
import '../../../core/errors/user_facing_error_messages.dart';
import '../../../core/persistence/athlete_persistence.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../programme/models/athlete_programme_completion.dart';
import '../../programme/models/programme_execution_context.dart';
import '../../programme/models/programme_progress_summary.dart';
import '../controllers/performance_capture_controller.dart';
import '../mappers/workout_execution_outcome_mapper.dart';
import '../models/training_session_record_status.dart';
import '../services/performance_record_save_coordinator.dart';
import '../services/running_pace_plausibility.dart';
import '../widgets/implausible_running_pace_warning.dart';
import '../widgets/performance_capture_widgets.dart';
import '../../session/presentation/production_restore_athlete_copy.dart';
import '../../session/screens/session_complete_screen.dart';
import '../../session/controllers/session_execution_controller.dart';
import '../../session/services/production_restore_envelope_store.dart';

class SessionFinishReviewScreen extends StatefulWidget {
  const SessionFinishReviewScreen({
    super.key,
    required this.performanceController,
    required this.executionController,
    required this.trainingSessionId,
    required this.athleteId,
    this.programmeContext,
    this.programmeProgress,
    this.saveCoordinator,
    this.homeWorkoutExecution,
    this.flushPendingTree,
    this.onAuthoritativeReload,
  });

  final PerformanceCaptureController performanceController;
  final SessionExecutionController executionController;
  final int trainingSessionId;
  final String athleteId;
  final ProgrammeExecutionContext? programmeContext;
  final ProgrammeProgressSummary? programmeProgress;
  final PerformanceRecordSaveCoordinator? saveCoordinator;
  final HomeWorkoutExecutionContext? homeWorkoutExecution;
  final Future<bool> Function()? flushPendingTree;
  final Future<void>? Function()? onAuthoritativeReload;

  @override
  State<SessionFinishReviewScreen> createState() =>
      _SessionFinishReviewScreenState();
}

class _SessionFinishReviewScreenState extends State<SessionFinishReviewScreen> {
  late final PerformanceCaptureController _performanceController =
      widget.performanceController;
  final _noteController = TextEditingController();
  PerformanceSaveState _saveState = PerformanceSaveState.idle;
  String? _errorMessage;
  String? _frozenIdempotencyKey;

  late final PerformanceRecordSaveCoordinator _saveCoordinator =
      widget.saveCoordinator ?? PerformanceRecordSaveCoordinator();

  static const _domainCompletionService =
      AthleteWorkoutCompletionApplicationService();

  @override
  void initState() {
    super.initState();
    _noteController.text = _performanceController.draft.athleteNote ?? '';
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveAndFinish() async {
    if (_saveState == PerformanceSaveState.saving ||
        _saveState == PerformanceSaveState.completing) {
      return;
    }

    _performanceController.updateSessionNote(_noteController.text);

    final runningWarning = RunningPacePlausibility.fromDraft(
      _performanceController.draft,
    );
    if (runningWarning != null) {
      final confirmed = await confirmImplausibleRunningPace(
        context: context,
        warning: runningWarning,
      );
      if (!confirmed) return;
    }

    setState(() {
      _saveState = PerformanceSaveState.completing;
      _errorMessage = null;
    });

    try {
      final flushed = await widget.flushPendingTree?.call();
      if (flushed == false) {
        throw StateError(
          'Could not save the latest station values while the session was still in progress.',
        );
      }
      final status = _performanceController.resolveCompletionStatus();
      final finishedAt = DateTime.now();
      var usedDomainCompletion = false;

      final launchContext = widget.executionController.workoutLaunchContext;
      final homeExecution =
          widget.homeWorkoutExecution ?? launchContext?.homeWorkoutExecution;
      final workoutPlayer = widget.executionController.workoutPlayer;

      if (widget.programmeContext?.isProgrammeBacked != true &&
          homeExecution != null &&
          launchContext != null &&
          workoutPlayer != null) {
        final outcomes = WorkoutExecutionOutcomeMapper.fromDraft(
          draft: _performanceController.draft,
          snapshot: launchContext.executionSnapshot,
          sessionStatus: status,
        );

        final domainCompletion = _domainCompletionService.complete(
          executionContext: homeExecution,
          athleteId: widget.athleteId,
          workoutPlayer: workoutPlayer,
          exerciseOutcomes: outcomes,
          finishedAt: finishedAt,
        );

        if (!domainCompletion.succeeded) {
          throw StateError(
            domainCompletion.domainResult.completionDetail ??
                'workout_completion_failed',
          );
        }
        usedDomainCompletion = true;
      }

      // Freeze request identity for retries; never mint a new key on resubmit.
      _frozenIdempotencyKey ??=
          'finish-${widget.trainingSessionId}-'
          '${DateTime.now().toUtc().microsecondsSinceEpoch}';

      final result = await _saveCoordinator.completeSession(
        controller: _performanceController,
        trainingSessionId: widget.trainingSessionId,
        athleteId: widget.athleteId,
        programmeContext: widget.programmeContext,
        forcedStatus: status,
        idempotencyKey: _frozenIdempotencyKey,
      );

      if (!mounted) return;

      final programmeCompletion = result.programmeCompletion;
      if (result.progressionFailed) {
        final alreadyCommitted =
            programmeCompletion?.status ==
            AthleteProgrammeCompletionStatus.alreadyCommitted;
        if (alreadyCommitted) {
          // Hosted truth won; fall through to cleanup.
        } else {
        final uncertain =
            programmeCompletion?.status ==
            AthleteProgrammeCompletionStatus.networkUncertain;
        setState(() {
          // Uncertain is retryable pending — not an in-flight lock.
          _saveState = PerformanceSaveState.error;
          _errorMessage = uncertain
              ? 'Completion pending. Your results are still saved on this phone.'
              : (programmeCompletion?.message ??
                    UserFacingErrorMessages.sessionProgressionWarning());
        });
        return;
        }
      }

      // Never show success from optimistic local state alone.
      if (widget.programmeContext?.isProgrammeBacked == true &&
          programmeCompletion?.isSuccess != true &&
          programmeCompletion?.status !=
              AthleteProgrammeCompletionStatus.alreadyCommitted) {
        setState(() {
          _saveState = PerformanceSaveState.error;
          _errorMessage = UserFacingErrorMessages.sessionProgressionWarning();
        });
        return;
      }

      if (usedDomainCompletion) {
        widget.executionController.applyDomainCompletionProjection(
          finishedAt: finishedAt,
        );
      } else {
        widget.executionController.completeSession(
          allowIncomplete: status != TrainingSessionRecordStatus.completed,
        );
      }

      final reload = widget.onAuthoritativeReload?.call();
      if (reload != null) await reload;

      ProductionRestoreEnvelopeStore.instance.clear(
        athleteId: widget.athleteId,
        trainingSessionId: widget.trainingSessionId,
      );
      AthleteSessionMemoryStore.instance.clear(
        AthleteSessionMemoryStore.sessionKey(
          protocolId: widget.executionController.state.plan.sessionId,
          trainingSessionId: widget.trainingSessionId,
        ),
      );
      if (AthletePersistence.isInitialized) {
        await AthletePersistence.repository.clearProductionRestoreEnvelope(
          athleteId: widget.athleteId,
          trainingSessionId: widget.trainingSessionId,
        );
      }

      if (!mounted) return;
      setState(() => _saveState = PerformanceSaveState.saved);

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SessionCompleteScreen(
            state: widget.executionController.state,
            savedRecord: result.record,
            adaptationMessage: result.adaptationResult?.athleteMessage,
            progressionResult: result.progressionResult,
            programmeProgress: widget.programmeProgress,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saveState = PerformanceSaveState.error;
        _errorMessage = UserFacingErrorMessages.sessionSaveFailure(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = _performanceController.draft;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Review Session', style: CohortTextStyles.h1),
              const SizedBox(height: CohortSpacing.lg),
              Text(
                '${draft.completedBlockCount} completed · '
                '${draft.skippedBlockCount} skipped · '
                '${draft.incompleteBlockCount} incomplete',
                style: CohortTextStyles.body,
              ),
              const SizedBox(height: CohortSpacing.lg),
              SessionRpeSelector(
                value: draft.overallRpe,
                onChanged: (value) {
                  setState(() {
                    _performanceController.updateSessionRpe(value);
                  });
                },
              ),
              const SizedBox(height: CohortSpacing.lg),
              TextField(
                controller: _noteController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Session note (optional)',
                ),
              ),
              const SizedBox(height: CohortSpacing.lg),
              if (_saveState == PerformanceSaveState.error) ...[
                Text(
                  ProductionRestoreAthleteCopy.completionPendingBody,
                  style: CohortTextStyles.body,
                ),
                const SizedBox(height: CohortSpacing.md),
              ],
              PerformanceSaveIndicator(
                state: _saveState,
                errorMessage: _errorMessage,
                pendingRetained: true,
                onRetry: _saveState == PerformanceSaveState.error ||
                        _saveState == PerformanceSaveState.completing
                    ? () => unawaited(_saveAndFinish())
                    : null,
              ),
              const SizedBox(height: CohortSpacing.lg),
              CohortButton(
                label: _saveState == PerformanceSaveState.completing
                    ? 'Completing…'
                    : 'Save and finish',
                onPressed:
                    _saveState == PerformanceSaveState.saving ||
                        _saveState == PerformanceSaveState.completing
                    ? null
                    : _saveAndFinish,
              ),
              const SizedBox(height: CohortSpacing.sm),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Return to session'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
