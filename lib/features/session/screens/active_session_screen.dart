import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../features/exercises/exercise_detail/exercise_detail_screen.dart';
import '../../../features/programme/models/programme_execution_context.dart';
import '../../../features/programme/models/programme_progress_summary.dart';
import '../../performance/controllers/performance_capture_controller.dart';
import '../../performance/models/active_performance_draft.dart';
import '../../performance/screens/session_finish_review_screen.dart';
import '../../performance/services/performance_record_save_coordinator.dart';
import '../../performance/widgets/performance_capture_widgets.dart';
import '../controllers/session_execution_controller.dart';
import '../models/session_execution_plan.dart';
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
  });

  final SessionExecutionController controller;
  final PerformanceCaptureController performanceController;
  final int? trainingSessionId;
  final ProgrammeExecutionContext? programmeContext;
  final ProgrammeProgressSummary? programmeProgress;
  final String? athleteId;
  final PerformanceRecordSaveCoordinator? saveCoordinator;

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
  late SessionExecutionController _controller = widget.controller;
  late PerformanceCaptureController _performanceController =
      widget.performanceController;
  final _saveCoordinator =
      PerformanceRecordSaveCoordinator();
  PerformanceSaveState _saveState = PerformanceSaveState.idle;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _persistDraft();
  }

  Future<void> _persistDraft() async {
    if (widget.trainingSessionId == null || widget.athleteId == null) return;
    setState(() {
      _saveState = PerformanceSaveState.saving;
      _saveError = null;
    });
    try {
      await _saveCoordinator.saveDraft(controller: _performanceController);
      if (!mounted) return;
      setState(() => _saveState = PerformanceSaveState.saved);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saveState = PerformanceSaveState.error;
        _saveError = error.toString();
      });
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
        const SnackBar(content: Text('Timer is not configured for this block.')),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlockTimerScreen(
          blockTitle: block.title,
          format: block.workoutFormat,
          configuration: block.timerConfiguration!,
        ),
      ),
    );
    _refresh();
  }

  BlockPerformanceDraft? _blockDraft(String blockId) {
    return _performanceController.draft.blockDraftFor(blockId);
  }

  Future<void> _finishSession() async {
    final state = _controller.state;
    final endedEarly = state.incompleteCount > 0;

    if (endedEarly) {
      final finishAnyway = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Finish with incomplete blocks?'),
          content: Text(
            '${state.incompleteCount} block${state.incompleteCount == 1 ? '' : 's'} '
            'are not marked complete.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep training'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Review and finish'),
            ),
          ],
        ),
      );
      if (finishAnyway != true) return;
    }

    final trainingSessionId = widget.trainingSessionId;
    if (trainingSessionId == null || widget.athleteId == null) {
      _controller.completeSession(allowIncomplete: endedEarly);
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
          saveCoordinator: widget.saveCoordinator ?? _saveCoordinator,
        ),
      ),
    );
  }

  void _syncBlockComplete(String blockId) {
    _controller.markBlockComplete(blockId);
    _performanceController.markBlockComplete(blockId);
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

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              for (var index = 0; index < state.plan.blocks.length; index++) ...[
                if (index > 0) const SizedBox(height: CohortSpacing.md),
                Builder(
                  builder: (context) {
                    final block = state.plan.blocks[index];
                    final isActive = index == activeIndex;
                    final isExpanded =
                        isActive || state.isBlockExpanded(block.blockId);
                    final blockDraft =
                        isActive ? _blockDraft(block.blockId) : null;

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
                      onNext: !isSingleBlock &&
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
                      performanceSection: blockDraft == null ||
                              !BlockResultEditor.showsCaptureFields(blockDraft)
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
                            ),
                    );
                  },
                ),
              ],
              const SizedBox(height: CohortSpacing.xl),
              CohortButton(label: 'Finish Session', onPressed: _finishSession),
            ],
          ),
        ),
      ),
    );
  }
}