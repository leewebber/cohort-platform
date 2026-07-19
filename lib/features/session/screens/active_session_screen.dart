import 'package:flutter/material.dart';

import '../../../models/training_session_completion_context.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../data/repositories/training_session_repository.dart';
import '../../../features/exercises/exercise_detail/exercise_detail_screen.dart';
import '../../../features/programme/models/programme_execution_context.dart';
import '../controllers/session_execution_controller.dart';
import '../models/session_execution_plan.dart';
import '../services/programme_session_progression_coordinator.dart';
import '../widgets/athlete/athlete_block_card.dart';
import '../widgets/athlete/athlete_session_components.dart';
import 'block_timer_screen.dart';
import 'session_complete_screen.dart';

class ActiveSessionScreen extends StatefulWidget {
  const ActiveSessionScreen({
    super.key,
    required this.controller,
    this.trainingSessionId,
    this.programmeContext,
    this.athleteId,
  });

  final SessionExecutionController controller;
  final int? trainingSessionId;
  final ProgrammeExecutionContext? programmeContext;
  final String? athleteId;

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
  late SessionExecutionController _controller = widget.controller;
  final _trainingSessionRepository = const TrainingSessionRepository();
  final _progressionCoordinator = ProgrammeSessionProgressionCoordinator();

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
              child: const Text('Finish anyway'),
            ),
          ],
        ),
      );
      if (finishAnyway != true) return;
    }

    _controller.completeSession(allowIncomplete: endedEarly);

    final trainingSessionId = widget.trainingSessionId;
    if (trainingSessionId != null) {
      await _trainingSessionRepository.completeSession(
        trainingSessionId,
        completion: endedEarly
            ? const TrainingSessionCompletionContext(endedEarly: true)
            : null,
      );

      if (widget.programmeContext != null && widget.athleteId != null) {
        await _progressionCoordinator.handleSessionCompleted(
          athleteId: widget.athleteId!,
          programmeContext: widget.programmeContext,
          trainingSessionId: trainingSessionId,
          endedEarly: endedEarly,
        );
      }
    }

    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SessionCompleteScreen(
          state: _controller.state,
          onDone: () => Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final activeIndex = state.activeBlockIndex;
    final activeBlock = state.activeBlock;

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
              SessionProgressIndicator(
                current: activeIndex + 1,
                total: state.totalBlocks,
                completed: state.completedCount,
              ),
              const SizedBox(height: CohortSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: CohortButton(
                      label: 'Previous',
                      onPressed: activeIndex > 0
                          ? () {
                              _controller.goToPreviousBlock();
                              _refresh();
                            }
                          : () {},
                    ),
                  ),
                  const SizedBox(width: CohortSpacing.sm),
                  Expanded(
                    child: CohortButton(
                      label: 'Next',
                      onPressed: activeIndex < state.totalBlocks - 1
                          ? () {
                              _controller.goToNextBlock();
                              _refresh();
                            }
                          : () {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CohortSpacing.xl),
              Text('CURRENT BLOCK', style: CohortTextStyles.eyebrow),
              const SizedBox(height: CohortSpacing.md),
              if (activeBlock != null)
                AthleteBlockCard(
                  block: activeBlock,
                  isExpanded: true,
                  isActive: true,
                  isComplete: state.isBlockComplete(activeBlock.blockId),
                  onToggleExpanded: () {},
                  onMarkComplete: () {
                    _controller.markBlockComplete(activeBlock.blockId);
                    _refresh();
                  },
                  onReopen: () {
                    _controller.reopenBlock(activeBlock.blockId);
                    _refresh();
                  },
                  onLaunchTimer: activeBlock.hasTimer
                      ? () => _launchTimer(activeBlock)
                      : null,
                  onOpenExercise: _openExercise,
                ),
              const SizedBox(height: CohortSpacing.xl),
              Text('ALL BLOCKS', style: CohortTextStyles.eyebrow),
              const SizedBox(height: CohortSpacing.md),
              for (var index = 0; index < state.plan.blocks.length; index++) ...[
                if (index > 0) const SizedBox(height: CohortSpacing.md),
                Builder(
                  builder: (context) {
                    final block = state.plan.blocks[index];
                    final isActive = index == activeIndex;
                    return AthleteBlockCard(
                      block: block,
                      isExpanded:
                          state.isBlockExpanded(block.blockId) || isActive,
                      isActive: isActive,
                      isComplete: state.isBlockComplete(block.blockId),
                      onToggleExpanded: () {
                        _controller.toggleBlockExpanded(block.blockId);
                        if (!isActive) _controller.goToBlock(index);
                        _refresh();
                      },
                      onMarkComplete: () {
                        _controller.markBlockComplete(block.blockId);
                        _refresh();
                      },
                      onReopen: () {
                        _controller.reopenBlock(block.blockId);
                        _refresh();
                      },
                      onLaunchTimer: block.hasTimer
                          ? () => _launchTimer(block)
                          : null,
                      onOpenExercise: _openExercise,
                      showActions: isActive,
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
