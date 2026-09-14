import 'package:flutter/material.dart';

import '../../../core/errors/user_facing_error_messages.dart';
import '../../../core/presentation/athlete_safe_error_presenter.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../features/exercises/exercise_detail/exercise_detail_screen.dart';
import '../../../features/home/controllers/home_today_session_refresh_controller.dart';
import '../../../features/programme/models/programme_execution_context.dart';
import '../../../features/programme/models/programme_progress_summary.dart';
import '../../performance/controllers/performance_capture_controller.dart';
import '../../performance/models/active_performance_draft.dart';
import '../../performance/models/performance_result_data.dart';
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
import '../models/session_execution_plan.dart';
import '../models/workout_session_launch_context.dart';
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

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
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
  PreviousStrengthHistoryState _previousStrengthHistory =
      const PreviousStrengthHistoryState.loading();
  late final PreviousStrengthPerformanceService _previousStrengthService;

  @override
  void initState() {
    super.initState();
    _saveCoordinator =
        widget.saveCoordinator ?? PerformanceRecordSaveCoordinator();
    _previousStrengthService =
        widget.previousStrengthService ?? PreviousStrengthPerformanceService();
    _persistDraft();
    _loadPreviousStrength();
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
    final cursor = existing is CircuitResultData ? existing.timerCursor : null;
    final popped = await Navigator.of(context).push<BlockTimerState>(
      MaterialPageRoute(
        builder: (_) => BlockTimerScreen(
          blockTitle: block.title,
          format: block.workoutFormat,
          configuration: block.timerConfiguration!,
          stationLabels: labels,
          onCheckpoint: (state) => _persistTimerCursor(block, state),
          initialState: cursor == null
              ? null
              : CircuitBlockTimerBridge.stateFrom(
                  cursor: cursor,
                  format: block.workoutFormat,
                  configuration: block.timerConfiguration!,
                  stationLabels: labels,
                ),
        ),
      ),
    );
    if (popped != null &&
        CircuitCaptureContract.isCircuitFormat(block.workoutFormat)) {
      _persistTimerCursor(block, popped);
      if (block.workoutFormat == WorkoutFormat.emom) {
        await _openEmomResult(block, timer: popped);
        return;
      }
    }
    _refresh();
  }

  void _persistTimerCursor(SessionExecutionBlock block, BlockTimerState state) {
    final latest = _blockDraft(block.blockId)?.resultData;
    if (latest is! CircuitResultData) return;
    _performanceController.updateBlockResultData(
      block.blockId,
      latest.copyWith(timerCursor: CircuitBlockTimerBridge.cursorFrom(state)),
    );
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
                TextButton.icon(
                  key: const ValueKey('active-session-back-to-home'),
                  onPressed: _isLeaving ? null : _returnToHome,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Back to Home'),
                ),
                const SizedBox(height: CohortSpacing.md),
                AthleteSessionHeader(
                  title: state.plan.sessionTitle,
                  subtitle: state.plan.programmeContextLabel,
                ),
                const SizedBox(height: CohortSpacing.lg),
                PerformanceSaveIndicator(
                  state: _saveState,
                  errorMessage: _saveError,
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

                      return AthleteBlockCard(
                        block: block,
                        isExpanded: isExpanded,
                        isActive: isActive,
                        isComplete: state.isBlockComplete(block.blockId),
                        stackActions: isEmom,
                        timerActionLabel: 'Start timer',
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
                      ? 'Completing…'
                      : 'Finish Session',
                  onPressed: finishEligibility.canFinish
                      ? _finishSession
                      : null,
                ),
                const SizedBox(height: CohortSpacing.sm),
                Text(
                  finishEligibility.reason,
                  key: const ValueKey('finish-session-reason'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
