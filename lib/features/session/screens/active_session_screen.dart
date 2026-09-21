import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/accessibility/journey_interaction.dart';
import '../../../core/errors/user_facing_error_messages.dart';
import '../../../core/persistence/athlete_persistence.dart';
import '../../../core/presentation/athlete_safe_error_presenter.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/cohort_button.dart';
import '../presentation/daily_journey_accessibility.dart';
import '../../../features/exercises/exercise_detail/exercise_detail_screen.dart';
import '../../../features/home/controllers/home_today_session_refresh_controller.dart';
import '../../../features/programme/models/programme_execution_context.dart';
import '../../../features/programme/models/programme_progress_summary.dart';
import '../../performance/controllers/performance_capture_controller.dart';
import '../../performance/models/active_performance_draft.dart';
import '../../performance/models/performance_result_data.dart';
import '../../performance/models/training_session_record_status.dart';
import '../../performance/screens/emom_result_screen.dart';
import '../../performance/screens/session_finish_review_screen.dart';
import '../../performance/services/circuit_capture_contract.dart';
import '../../performance/services/emom_score_contract.dart';
import '../../performance/services/performance_record_save_coordinator.dart';
import '../../performance/services/previous_strength_performance_service.dart';
import '../../performance/models/previous_strength_performance.dart';
import '../../performance/widgets/performance_capture_widgets.dart';
import '../../../models/workout_format.dart';
import '../controllers/session_execution_controller.dart';
import '../models/production_restore_envelope.dart';
import '../models/production_restore_outcome.dart';
import '../models/production_session_draft.dart';
import '../models/production_session_ui_cursor.dart';
import '../models/session_execution_plan.dart';
import '../models/workout_session_launch_context.dart';
import '../services/production_restore_envelope_store.dart';
import '../services/production_restore_resolver.dart';
import '../services/block_timer_controller.dart';
import '../services/circuit_block_timer_bridge.dart';
import '../services/session_finish_eligibility.dart';
import '../widgets/athlete/athlete_block_card.dart';
import '../widgets/athlete/athlete_session_components.dart';
import 'block_timer_screen.dart';

class ActiveSessionScreen extends StatefulWidget {
  const ActiveSessionScreen({
    super.key,
    required this.controller,
    required this.performanceController,
    this.trainingSessionId,
    this.programmeContext,
    this.programmeProgress,
    this.athleteId,
    this.saveCoordinator,
    this.workoutLaunchContext,
    this.refreshController,
    this.previousStrengthService,
    this.restoreEnvelopeStore,
    this.openRestoredTimer = false,
    this.restoredTimerOverride,
  });

  final SessionExecutionController controller;
  final PerformanceCaptureController performanceController;
  final int? trainingSessionId;
  final ProgrammeExecutionContext? programmeContext;
  final ProgrammeProgressSummary? programmeProgress;
  final String? athleteId;
  final PerformanceRecordSaveCoordinator? saveCoordinator;
  final WorkoutSessionLaunchContext? workoutLaunchContext;
  final HomeTodaySessionRefreshController? refreshController;
  final PreviousStrengthPerformanceService? previousStrengthService;
  final ProductionRestoreEnvelopeStore? restoreEnvelopeStore;
  final bool openRestoredTimer;
  final BlockTimerState? restoredTimerOverride;

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen>
    with WidgetsBindingObserver {
  late final SessionExecutionController _controller = widget.controller;
  late final PerformanceCaptureController _performanceController =
      widget.performanceController;
  late final PerformanceRecordSaveCoordinator _saveCoordinator;
  PerformanceSaveState _saveState = PerformanceSaveState.idle;
  String? _saveError;
  Future<void>? _saveInFlight;
  int _saveRevision = 0;
  int _savedRevision = 0;
  bool _lastSaveSucceeded = true;
  bool _isLeaving = false;
  bool _completionLocked = false;
  String? _journeyAnnouncement;
  PreviousStrengthHistoryState _previousStrengthHistory =
      const PreviousStrengthHistoryState.loading();
  late final PreviousStrengthPerformanceService _previousStrengthService;
  late final ProductionRestoreEnvelopeStore _restoreEnvelopeStore;

  @override
  void initState() {
    super.initState();
    _saveCoordinator =
        widget.saveCoordinator ?? PerformanceRecordSaveCoordinator();
    _previousStrengthService =
        widget.previousStrengthService ?? PreviousStrengthPerformanceService();
    _restoreEnvelopeStore =
        widget.restoreEnvelopeStore ?? ProductionRestoreEnvelopeStore.instance;
    WidgetsBinding.instance.addObserver(this);
    _persistDraft();
    _loadPreviousStrength();
    final restoredDraft = widget.openRestoredTimer ||
        _performanceController.draft.blockDrafts.any(
          (block) => block.exerciseResults.any(
            (exercise) => exercise.sets.any(
              (set) =>
                  set.completed ||
                  set.reps != null ||
                  set.load != null ||
                  set.distance != null,
            ),
          ),
        );
    if (restoredDraft) {
      _journeyAnnouncement =
          'Draft restored. Your entered results are on this phone.';
    }
    if (widget.openRestoredTimer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final block = _controller.state.activeBlock ??
            _controller.state.plan.blocks.firstOrNull;
        if (block != null && block.hasTimer) {
          unawaited(_launchTimer(block));
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      unawaited(_persistDraft());
    }
    if (state == AppLifecycleState.resumed) {
      unawaited(_reconcileForeground());
    }
  }

  Future<void> _loadPreviousStrength() async {
    final athleteId = widget.athleteId?.trim();
    final ids = _controller.state.plan.blocks
        .expand((block) => block.linkedExercises)
        .map((exercise) => exercise.exerciseId.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (athleteId == null || athleteId.isEmpty || ids.isEmpty) {
      setState(() {
        _previousStrengthHistory = const PreviousStrengthHistoryState.idle();
      });
      return;
    }
    setState(() {
      _previousStrengthHistory = const PreviousStrengthHistoryState.loading();
    });
    try {
      final result = await _previousStrengthService.latestForExercises(
        athleteId: athleteId,
        exerciseIds: ids,
        excludeRecordId: _performanceController.draft.recordId,
        currentChronologyAt: _performanceController.draft.startedAt.toUtc(),
      );
      if (!mounted) return;
      setState(() {
        _previousStrengthHistory = PreviousStrengthHistoryState.ready(result);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _previousStrengthHistory = const PreviousStrengthHistoryState.failed();
      });
    }
  }

  Future<bool> _persistDraft() {
    if (_completionLocked) return Future.value(true);
    if (widget.trainingSessionId == null || widget.athleteId == null) {
      return Future.value(true);
    }
    _saveRevision++;
    return _ensureLatestDraftSaved();
  }

  Future<bool> _ensureLatestDraftSaved() async {
    while (_savedRevision < _saveRevision) {
      final running = _saveInFlight;
      if (running != null) {
        await running;
      } else {
        final requestedRevision = _saveRevision;
        final operation = _runSave(requestedRevision);
        _saveInFlight = operation;
        await operation;
        if (identical(_saveInFlight, operation)) {
          _saveInFlight = null;
        }
      }
      if (!_lastSaveSucceeded) return false;
    }
    return true;
  }

  Future<void> _runSave(int requestedRevision) async {
    setState(() {
      _saveState = PerformanceSaveState.saving;
      _saveError = null;
    });
    try {
      await _saveCoordinator.saveDraft(controller: _performanceController);
      await _persistRestoreEnvelope();
      _savedRevision = requestedRevision;
      _lastSaveSucceeded = true;
      if (!mounted) return;
      setState(() => _saveState = PerformanceSaveState.saved);
    } catch (error) {
      _lastSaveSucceeded = false;
      if (!mounted) return;
      setState(() {
        _saveState = PerformanceSaveState.error;
        _saveError = AthleteSafeErrorPresenter.message(
          error,
          fallback: UserFacingErrorMessages.saveFailure,
          logTag: 'session_draft_save',
        );
      });
    }
  }

  Future<void> _persistRestoreEnvelope() async {
    final athleteId = widget.athleteId;
    final trainingSessionId = widget.trainingSessionId;
    final programmeContext = widget.programmeContext;
    if (athleteId == null ||
        trainingSessionId == null ||
        programmeContext == null ||
        !programmeContext.isProgrammeBacked) {
      return;
    }
    final state = _controller.state;
    final envelope = ProductionRestoreEnvelope(
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
        startedAt: _performanceController.draft.startedAt,
        lastDurableSaveAt: DateTime.now().toUtc(),
      ),
      cursor: ProductionSessionUiCursor(
        schemaVersion: ProductionSessionUiCursor.currentSchemaVersion,
        athleteId: athleteId,
        assignmentId: programmeContext.assignmentId,
        trainingSessionId: trainingSessionId,
        occurrenceId: programmeContext.occurrenceId,
        activeBlockId: state.activeBlock?.blockId ??
            _performanceController.draft.activeBlockId,
        activeBlockIndex: state.activeBlockIndex,
        expandedBlockIds: state.expandedBlockIds,
        savedAt: DateTime.now().toUtc(),
      ),
    );
    _restoreEnvelopeStore.write(envelope);
    if (AthletePersistence.isInitialized) {
      await AthletePersistence.repository.saveProductionRestoreEnvelope(
        athleteId: athleteId,
        trainingSessionId: trainingSessionId,
        payload: envelope.toJson(),
      );
    }
  }

  Future<void> _reconcileForeground() async {
    final athleteId = widget.athleteId;
    final trainingSessionId = widget.trainingSessionId;
    final programmeContext = widget.programmeContext;
    if (athleteId == null || trainingSessionId == null || _completionLocked) {
      return;
    }
    try {
      final inProgress = await _saveCoordinator.loadInProgressDraftAsRecord(
        athleteId: athleteId,
        trainingSessionId: trainingSessionId,
      );
      final terminal = inProgress == null
          ? await _saveCoordinator.store.getTerminalForTrainingSession(
              athleteId: athleteId,
              trainingSessionId: trainingSessionId,
            )
          : null;
      final hostedCompleted =
          terminal?.status == TrainingSessionRecordStatus.completed;
      if (programmeContext != null && programmeContext.isProgrammeBacked) {
        final envelope = _restoreEnvelopeStore.read(
          athleteId: athleteId,
          trainingSessionId: trainingSessionId,
        );
        final decision = const ProductionRestoreResolver().resolve(
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
            actuals: inProgress == null
                ? null
                : _saveCoordinator
                      .restoreControllerFromRecord(inProgress)
                      .draft,
          ),
        );
        if (decision.outcome == ProductionRestoreOutcome.completedHosted &&
            mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session already completed')),
          );
        }
      } else if (hostedCompleted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session already completed')),
        );
      }
    } catch (_) {
      // Network loss keeps the local draft; do not treat as revocation.
    }
  }

  Future<void> _returnToHome() async {
    if (_isLeaving) return;
    _isLeaving = true;
    try {
      while (mounted) {
        if (await _persistDraft()) {
          if (mounted) Navigator.of(context).pop();
          return;
        }
        if (!mounted) return;
        final retry = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Could not save session'),
            content: Text(
              _saveError ??
                  'Your session remains open. Retry saving before returning Home.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Stay'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
        if (retry != true) return;
      }
    } finally {
      _isLeaving = false;
    }
  }

  void _refresh() => setState(() {});

  Future<void> _openExercise(SessionExecutionExerciseSummary summary) async {
    final exercise = summary.exercise;
    if (exercise == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExerciseDetailScreen(
          exercise: exercise,
          athleteId: widget.athleteId,
        ),
      ),
    );
    _refresh();
  }

  Future<void> _launchTimer(SessionExecutionBlock block) async {
    if (!block.hasTimer || block.timerConfiguration == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Timer is not configured for this block.'),
        ),
      );
      return;
    }

    final labels = {
      for (final exercise in block.linkedExercises)
        exercise.exerciseId: exercise.displayName,
    };
    final draft = _blockDraft(block.blockId);
    final existing = draft?.resultData;
    final initialState = widget.restoredTimerOverride ??
        CircuitBlockTimerBridge.restoredState(
          block: block,
          result: existing,
          stationLabels: labels,
        );
    final popped = await Navigator.of(context).push<BlockTimerState>(
      MaterialPageRoute(
        builder: (_) => BlockTimerScreen(
          blockTitle: block.title,
          format: block.workoutFormat,
          configuration: block.timerConfiguration!,
          stationLabels: labels,
          prescriptionLines: block.content
              .split('\n')
              .where((line) => line.trim().isNotEmpty)
              .toList(),
          restoredWorkNote: existing is ForTimeResultData
              ? existing.remainingWorkNote
              : null,
          onCheckpoint: (state) => _persistTimerEvidence(block, state),
          initialState: initialState,
        ),
      ),
    );
    if (popped != null) {
      _persistTimerEvidence(block, popped);
      if (block.workoutFormat == WorkoutFormat.emom) {
        await _openEmomResult(block, timer: popped);
        return;
      }
    }
    _refresh();
  }

  void _persistTimerEvidence(
    SessionExecutionBlock block,
    BlockTimerState state,
  ) {
    final latest = _blockDraft(block.blockId)?.resultData;
    if (latest is CircuitResultData) {
      _performanceController.updateBlockResultData(
        block.blockId,
        latest.copyWith(timerCursor: CircuitBlockTimerBridge.cursorFrom(state)),
      );
    } else if (latest is ForTimeResultData) {
      _performanceController.updateBlockResultData(
        block.blockId,
        latest.copyWith(elapsedSeconds: state.primarySeconds),
      );
    } else if (latest is IntervalResultData) {
      _performanceController.updateBlockResultData(
        block.blockId,
        latest.copyWith(
          workSeconds: state.primarySeconds,
          intervalsCompleted: (state.currentRound - 1).clamp(0, 999),
          entered: true,
        ),
      );
    } else if (latest is AmrapResultData) {
      _performanceController.updateBlockResultData(
        block.blockId,
        latest.copyWith(remainingSeconds: state.primarySeconds),
      );
    } else {
      return;
    }
    _persistDraft();
  }

  Future<void> _openEmomResult(
    SessionExecutionBlock block, {
    BlockTimerState? timer,
  }) async {
    final draft = _blockDraft(block.blockId);
    final result = draft?.resultData;
    if (result is! CircuitResultData) return;
    final saved = await openEmomResultCapture(
      context,
      result: result,
      timer: timer,
    );
    if (!mounted) return;
    if (saved == null) {
      _refresh();
      return;
    }
    _performanceController.updateBlockResultData(block.blockId, saved);
    _commitBlockComplete(block.blockId);
  }

  BlockPerformanceDraft? _blockDraft(String blockId) {
    return _performanceController.draft.blockDraftFor(blockId);
  }

  Future<void> _finishSession() async {
    if (_completionLocked || _saveState == PerformanceSaveState.completing) {
      return;
    }
    final state = _controller.state;
    final eligibility = const SessionFinishEligibilityEvaluator().evaluate(
      incompleteBlockCount: state.incompleteCount,
      performanceDraft: _performanceController.draft,
    );
    if (!eligibility.canFinish) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(eligibility.reason)));
      return;
    }

    if (!mounted) return;
    final trainingSessionId = widget.trainingSessionId;
    if (trainingSessionId == null || widget.athleteId == null) {
      _controller.completeSession();
      if (!mounted) return;
      Navigator.pop(context);
      return;
    }

    setState(() {
      _saveState = PerformanceSaveState.completing;
      _saveError = null;
    });
    final flushed = await _ensureLatestDraftSaved();
    if (!flushed) {
      if (!mounted) return;
      setState(() {
        _saveState = PerformanceSaveState.error;
        _saveError =
            _saveError ??
            'Could not save the latest station values. The session is still in progress.';
      });
      return;
    }
    _completionLocked = true;
    if (!mounted) {
      _completionLocked = false;
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionFinishReviewScreen(
          performanceController: _performanceController,
          executionController: _controller,
          trainingSessionId: trainingSessionId,
          athleteId: widget.athleteId!,
          programmeContext: widget.programmeContext,
          programmeProgress: widget.programmeProgress,
          saveCoordinator: _saveCoordinator,
          homeWorkoutExecution:
              widget.workoutLaunchContext?.homeWorkoutExecution,
          flushPendingTree: _ensureLatestDraftSaved,
          onAuthoritativeReload: () {
            return (AthleteProgrammeSurfaceRefreshScope.maybeOf(context) ??
                    widget.refreshController)
                ?.reloadAuthoritativeSurfaces(source: 'session_completed');
          },
        ),
      ),
    );
    if (!mounted) return;
    _completionLocked = false;
    setState(() {
      if (_saveState == PerformanceSaveState.completing) {
        _saveState = PerformanceSaveState.saved;
      }
    });
  }

  void _syncBlockComplete(String blockId) {
    SessionExecutionBlock? block;
    for (final item in _controller.state.plan.blocks) {
      if (item.blockId == blockId) {
        block = item;
        break;
      }
    }
    final result = _blockDraft(blockId)?.resultData;
    if (block != null &&
        block.workoutFormat == WorkoutFormat.emom &&
        result is CircuitResultData &&
        !result.scoreEntered) {
      _openEmomResult(block);
      return;
    }
    _commitBlockComplete(blockId);
  }

  void _commitBlockComplete(String blockId) {
    _performanceController.markBlockComplete(blockId);
    final validation = _performanceController.validateForCompletion();
    final blockErrors = validation.fieldErrors.entries
        .where((entry) => entry.key.startsWith('block:$blockId'))
        .map((entry) => entry.value)
        .toList(growable: false);
    final blockError = blockErrors.isEmpty ? null : blockErrors.first;
    if (blockError != null) {
      _performanceController.reopenBlock(blockId);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(blockError)));
      _refresh();
      return;
    }
    _controller.markBlockComplete(blockId);
    _performanceController.setActiveBlock(
      _controller.state.activeBlock?.blockId,
    );
    _journeyAnnouncement = 'Block completed';
    _persistDraft();
    _refresh();
  }

  void _syncBlockReopen(String blockId) {
    _controller.reopenBlock(blockId);
    _performanceController.reopenBlock(blockId);
    _persistDraft();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final activeIndex = state.activeBlockIndex;
    final isSingleBlock = state.totalBlocks <= 1;

    final finishEligibility = const SessionFinishEligibilityEvaluator()
        .evaluate(
          incompleteBlockCount: state.incompleteCount,
          performanceDraft: _performanceController.draft,
        );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) await _returnToHome();
      },
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                JourneyMinTap(
                  child: TextButton.icon(
                    key: const ValueKey('active-session-back-to-home'),
                    onPressed: _isLeaving ? null : _returnToHome,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Back to Home'),
                  ),
                ),
                JourneyAnnouncement(message: _journeyAnnouncement),
                const SizedBox(height: CohortSpacing.md),
                AthleteSessionHeader(
                  title: state.plan.sessionTitle,
                  subtitle: state.plan.programmeContextLabel,
                ),
                const SizedBox(height: CohortSpacing.lg),
                PerformanceSaveIndicator(
                  state: _saveState,
                  errorMessage: _saveError ?? 'Couldn’t save — Retry',
                  onRetry: _saveState == PerformanceSaveState.error
                      ? () => unawaited(_persistDraft())
                      : null,
                ),
                const SizedBox(height: CohortSpacing.lg),
                SessionProgressIndicator(
                  current: activeIndex + 1,
                  total: state.totalBlocks,
                  completed: state.completedCount,
                ),
                const SizedBox(height: CohortSpacing.lg),
                for (
                  var index = 0;
                  index < state.plan.blocks.length;
                  index++
                ) ...[
                  if (index > 0) const SizedBox(height: CohortSpacing.md),
                  Builder(
                    builder: (context) {
                      final block = state.plan.blocks[index];
                      final isActive = index == activeIndex;
                      final isExpanded =
                          isActive || state.isBlockExpanded(block.blockId);
                      final blockDraft = isActive
                          ? _blockDraft(block.blockId)
                          : null;
                      final isEmom = block.workoutFormat == WorkoutFormat.emom;
                      final emomResult = blockDraft?.resultData
                              is CircuitResultData
                          ? blockDraft!.resultData as CircuitResultData
                          : null;
                      final timerStarted = emomResult?.usedInAppTimer == true;
                      final performanceReplacesExerciseList =
                          CircuitCaptureContract.isFixedWork(block) ||
                          (blockDraft != null &&
                              BlockResultEditor.rendersExerciseRows(
                                blockDraft,
                              ));
                      final restoredTimer =
                          CircuitBlockTimerBridge.restoredState(
                            block: block,
                            result: blockDraft?.resultData,
                            stationLabels: {
                              for (final exercise in block.linkedExercises)
                                exercise.exerciseId: exercise.displayName,
                            },
                          );

                      return AthleteBlockCard(
                        block: block,
                        isExpanded: isExpanded,
                        isActive: isActive,
                        isComplete: state.isBlockComplete(block.blockId),
                        stackActions: isEmom,
                        timerActionLabel:
                            restoredTimer != null ? 'Resume' : 'Start timer',
                        completeActionLabel: isEmom
                            ? (timerStarted
                                  ? 'End and record result'
                                  : 'Record result without timer')
                            : null,
                        recordedResultSummary:
                            state.isBlockComplete(block.blockId) &&
                                emomResult != null &&
                                emomResult.isEmomScore
                            ? EmomScoreContract.completedSummary(emomResult)
                            : null,
                        onToggleExpanded: () {
                          if (isActive) return;
                          _controller.toggleBlockExpanded(block.blockId);
                          _refresh();
                        },
                        onMarkComplete: () => _syncBlockComplete(block.blockId),
                        onReopen: () => _syncBlockReopen(block.blockId),
                        onLaunchTimer:
                            block.hasTimer &&
                                !CircuitCaptureContract.isFixedWork(block)
                            ? () => _launchTimer(block)
                            : null,
                        onOpenExercise: _openExercise,
                        exerciseInfoOpensDetail: true,
                        performanceReplacesExerciseList:
                            performanceReplacesExerciseList,
                        showActions: isActive,
                        showBlockNavigation: !isSingleBlock && isActive,
                        onPrevious: !isSingleBlock && activeIndex > 0
                            ? () {
                                _controller.goToPreviousBlock();
                                _performanceController.setActiveBlock(
                                  _controller.state.activeBlock?.blockId,
                                );
                                _persistDraft();
                                _refresh();
                              }
                            : null,
                        onNext:
                            !isSingleBlock &&
                                activeIndex < state.totalBlocks - 1
                            ? () {
                                _controller.goToNextBlock();
                                _performanceController.setActiveBlock(
                                  _controller.state.activeBlock?.blockId,
                                );
                                _persistDraft();
                                _refresh();
                              }
                            : null,
                        performanceSection:
                            blockDraft == null ||
                                isEmom ||
                                !BlockResultEditor.showsCaptureFields(
                                  blockDraft,
                                )
                            ? null
                            : BlockResultEditor(
                                blockDraft: blockDraft,
                                linkedExercises: block.linkedExercises,
                                previousStrengthHistory:
                                    _previousStrengthHistory,
                                onRetryPreviousStrength: _loadPreviousStrength,
                                onApplyElapsedSeconds: (seconds) {
                                  final current = blockDraft.resultData;
                                  if (current is ForTimeResultData) {
                                    _performanceController
                                        .updateBlockResultData(
                                      block.blockId,
                                      current.copyWith(
                                        elapsedSeconds: seconds,
                                      ),
                                    );
                                    _persistDraft();
                                    _refresh();
                                  }
                                },
                                onResultChanged: (result) {
                                  _performanceController.updateBlockResultData(
                                    block.blockId,
                                    result,
                                  );
                                  _persistDraft();
                                  _refresh();
                                },
                                onAddSet: (exerciseId) {
                                  _performanceController.addSet(
                                    block.blockId,
                                    exerciseId,
                                  );
                                  _persistDraft();
                                  _refresh();
                                },
                                onUpdateSet: (exerciseId, setResultId, update) {
                                  _performanceController.updateSet(
                                    block.blockId,
                                    exerciseId,
                                    setResultId,
                                    update,
                                  );
                                  _persistDraft();
                                  _refresh();
                                },
                                onDuplicateSet: (exerciseId, setResultId) {
                                  _performanceController.duplicateSet(
                                    block.blockId,
                                    exerciseId,
                                    setResultId,
                                  );
                                  _persistDraft();
                                  _refresh();
                                },
                                onRemoveSet: (exerciseId, setResultId) {
                                  _performanceController.removeSet(
                                    block.blockId,
                                    exerciseId,
                                    setResultId,
                                  );
                                  _persistDraft();
                                  _refresh();
                                },
                                onOpenExercise: _openExercise,
                              ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: CohortSpacing.xl),
                CohortButton(
                  label: _saveState == PerformanceSaveState.completing
                      ? 'Completion pending'
                      : 'Finish Session',
                  semanticLabel: finishEligibility.canFinish
                      ? 'Finish session'
                      : finishEligibility.reason,
                  semanticHint: finishEligibility.canFinish
                      ? null
                      : 'Unavailable',
                  onPressed: finishEligibility.canFinish
                      ? _finishSession
                      : null,
                ),
                const SizedBox(height: CohortSpacing.sm),
                Text(
                  finishEligibility.reason,
                  key: const ValueKey('finish-session-reason'),
                  softWrap: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
