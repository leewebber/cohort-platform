import 'package:flutter/material.dart';

import '../../../core/errors/user_facing_error_messages.dart';
import '../../../core/presentation/athlete_safe_error_presenter.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../features/exercises/exercise_detail/exercise_detail_screen.dart';
import '../../../features/programme/models/programme_execution_context.dart';
import '../../../features/programme/models/programme_progress_summary.dart';
import '../../performance/controllers/performance_capture_controller.dart';
import '../../performance/models/active_performance_draft.dart';
import '../../performance/models/performance_result_data.dart';
import '../../performance/screens/session_finish_review_screen.dart';
import '../../performance/services/circuit_capture_contract.dart';
import '../../performance/services/performance_record_save_coordinator.dart';
import '../../performance/widgets/performance_capture_widgets.dart';
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
  });

  final SessionExecutionController controller;
  final PerformanceCaptureController performanceController;
  final int? trainingSessionId;
  final ProgrammeExecutionContext? programmeContext;
  final ProgrammeProgressSummary? programmeProgress;
  final String? athleteId;
  final PerformanceRecordSaveCoordinator? saveCoordinator;
  final WorkoutSessionLaunchContext? workoutLaunchContext;

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

  @override
  void initState() {
    super.initState();
    _saveCoordinator =
        widget.saveCoordinator ?? PerformanceRecordSaveCoordinator();
    _persistDraft();
  }

  Future<bool> _persistDraft() {
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
      final latest = _blockDraft(block.blockId)?.resultData;
      if (latest is CircuitResultData) {
        _performanceController.updateBlockResultData(
          block.blockId,
          latest.copyWith(
            timerCursor: CircuitBlockTimerBridge.cursorFrom(popped),
          ),
        );
        _persistDraft();
      }
    }
    _refresh();
  }

  BlockPerformanceDraft? _blockDraft(String blockId) {
    return _performanceController.draft.blockDraftFor(blockId);
  }

  Future<void> _finishSession() async {
    final state = _controller.state;
    final eligibility = const SessionFinishEligibilityEvaluator().evaluate(
      incompleteBlockCount: state.incompleteCount,
      performanceDraft: _performanceController.draft,
    );
    if (!eligibility.canFinish) return;

    if (!mounted) return;
    final trainingSessionId = widget.trainingSessionId;
    if (trainingSessionId == null || widget.athleteId == null) {
      _controller.completeSession();
      if (!mounted) return;
      Navigator.pop(context);
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
        ),
      ),
    );
  }

  void _syncBlockComplete(String blockId) {
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
            padding: const EdgeInsets.all(24),
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
                      final performanceReplacesExerciseList =
                          blockDraft != null &&
                          BlockResultEditor.rendersExerciseRows(blockDraft);

                      return AthleteBlockCard(
                        block: block,
                        isExpanded: isExpanded,
                        isActive: isActive,
                        isComplete: state.isBlockComplete(block.blockId),
                        onToggleExpanded: () {
                          if (isActive) return;
                          _controller.toggleBlockExpanded(block.blockId);
                          _refresh();
                        },
                        onMarkComplete: () => _syncBlockComplete(block.blockId),
                        onReopen: () => _syncBlockReopen(block.blockId),
                        onLaunchTimer: block.hasTimer
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
                                !BlockResultEditor.showsCaptureFields(
                                  blockDraft,
                                )
                            ? null
                            : BlockResultEditor(
                                blockDraft: blockDraft,
                                linkedExercises: block.linkedExercises,
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
                  label: 'Finish Session',
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
