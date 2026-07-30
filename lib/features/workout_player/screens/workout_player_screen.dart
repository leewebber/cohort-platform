import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../programme/models/programme_execution_context.dart';
import '../controllers/workout_player_controller.dart';
import '../models/previous_performance_snapshot.dart';
import '../models/workout_player_exercise_step.dart';
import '../models/workout_player_result.dart';
import '../models/workout_player_state.dart';
import '../services/previous_performance_resolver.dart';
import '../widgets/workout_player_widgets.dart';
import 'workout_complete_screen.dart';
import 'workout_overview_screen.dart';

/// Calm, focused exercise execution screen.
class WorkoutPlayerScreen extends StatefulWidget {
  const WorkoutPlayerScreen({
    super.key,
    required this.controller,
    required this.athleteId,
    this.trainingSessionId,
    this.programmeContext,
    this.completionService,
    this.previousPerformanceResolver = const PreviousPerformanceResolver(),
  });

  final WorkoutPlayerController controller;
  final String athleteId;
  final int? trainingSessionId;
  final ProgrammeExecutionContext? programmeContext;
  final WorkoutCompletionService? completionService;
  final PreviousPerformanceResolver previousPerformanceResolver;

  @override
  State<WorkoutPlayerScreen> createState() => _WorkoutPlayerScreenState();
}

class _WorkoutPlayerScreenState extends State<WorkoutPlayerScreen> {
  late final WorkoutPlayerController _controller = widget.controller;
  bool _openingComplete = false;

  @override
  void initState() {
    super.initState();
    _controller.attachLifecycleObserver();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.detachLifecycleObserver();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    final state = _controller.state;
    if (state.phase == WorkoutPlayerPhase.complete) {
      _openComplete(state);
      return;
    }
    setState(() {});
  }

  void _openComplete(WorkoutPlayerState state) {
    if (_openingComplete) return;
    _openingComplete = true;
    // Replaces this route; Overview awaits the result when Complete pops.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<WorkoutPlayerResult>(
        builder: (_) => WorkoutCompleteScreen(
          state: state,
          athleteId: widget.athleteId,
          trainingSessionId: widget.trainingSessionId,
          programmeContext: widget.programmeContext,
          completionService: widget.completionService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final step = state.currentStep;

    return Scaffold(
      backgroundColor: CohortColors.background,
      appBar: AppBar(
        backgroundColor: CohortColors.background,
        elevation: 0,
        title: Text(
          'EXERCISE ${state.currentExerciseIndex + 1} OF ${state.totalExercises}',
          style: CohortTextStyles.eyebrow,
        ),
        centerTitle: false,
      ),
      body: step == null
          ? const Center(child: Text('No exercises in this session.'))
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        CohortSpacing.xl,
                        CohortSpacing.md,
                        CohortSpacing.xl,
                        CohortSpacing.xl,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          WorkoutProgressBar(
                            progress: state.sessionProgress,
                            label:
                                'Session · ${((state.sessionProgress) * 100).round()}%',
                          ),
                          const SizedBox(height: CohortSpacing.md),
                          WorkoutProgressBar(
                            progress: state.exerciseProgress,
                            label:
                                'This exercise · set ${state.currentSet} of ${step.totalSets}',
                          ),
                          if (state.estimatedRemainingMinutes != null) ...[
                            const SizedBox(height: CohortSpacing.sm),
                            Text(
                              '~${state.estimatedRemainingMinutes} min remaining',
                              style: CohortTextStyles.small,
                            ),
                          ],
                          const SizedBox(height: CohortSpacing.xl),
                          Builder(
                            builder: (context) {
                              final media =
                                  step.exercise.exercise?.videoUrl ??
                                  step.exercise.exercise?.imageUrl;
                              final slot = ExerciseMediaSlot(mediaUrl: media);
                              if (!slot.hasMedia) {
                                return Text(step.name, style: CohortTextStyles.h1);
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  slot,
                                  const SizedBox(height: CohortSpacing.xl),
                                  Text(step.name, style: CohortTextStyles.h1),
                                ],
                              );
                            },
                          ),
                          if (step.movementCategory != null) ...[
                            const SizedBox(height: CohortSpacing.sm),
                            Text(
                              step.movementCategory!.toUpperCase(),
                              style: CohortTextStyles.sectionLabel,
                            ),
                          ],
                          if (step.description != null) ...[
                            const SizedBox(height: CohortSpacing.lg),
                            Text(step.description!, style: CohortTextStyles.body),
                          ],
                          WorkoutMetaRow(
                            label: 'Programmed',
                            value: step.prescriptionSummary,
                          ),
                          if (_previousFor(step) != null)
                            PreviousPerformanceSection(
                              snapshot: _previousFor(step)!,
                            ),
                          if (step.coachingCues != null) ...[
                            WorkoutMetaRow(
                              label: 'Coaching cues',
                              value: step.coachingCues!,
                            ),
                          ],
                          if (step.restGuidance != null)
                            WorkoutMetaRow(
                              label: 'Rest',
                              value: step.restGuidance!,
                            ),
                          if (step.rpeGuidance != null)
                            WorkoutMetaRow(
                              label: 'Effort / RPE',
                              value: step.rpeGuidance!,
                            ),
                          WorkoutMetaRow(
                            label: 'Current set',
                            value:
                                '${state.currentSet} · ${state.remainingSetsInExercise} remaining',
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      CohortSpacing.xl,
                      CohortSpacing.sm,
                      CohortSpacing.xl,
                      CohortSpacing.xl,
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: CohortButton(
                                label: 'PREVIOUS',
                                variant: CohortButtonVariant.secondary,
                                onPressed: _controller.goToPrevious,
                              ),
                            ),
                            const SizedBox(width: CohortSpacing.md),
                            Expanded(
                              child: CohortButton(
                                label: 'NEXT',
                                variant: CohortButtonVariant.secondary,
                                onPressed: _controller.goToNext,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: CohortSpacing.md),
                        CohortButton(
                          label: 'COMPLETE SET',
                          showTrailingArrow: true,
                          onPressed: _controller.completeSet,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  PreviousPerformanceSnapshot? _previousFor(WorkoutPlayerExerciseStep step) {
    return widget.previousPerformanceResolver.resolveLatest(
      exerciseId: step.exercise.exerciseId,
    );
  }
}
