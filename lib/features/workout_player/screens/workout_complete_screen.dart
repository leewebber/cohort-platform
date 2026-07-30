import 'package:flutter/material.dart';

import '../../../core/persistence/athlete_persistence.dart';
import '../../../core/persistence/previous_performance_from_results.dart';
import '../../../core/persistence/workout_execution_capture.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../adaptive_progression/models/session_completion.dart';
import '../../adaptive_progression/services/adaptive_progression_coordinator.dart';
import '../../athlete_profile/services/athlete_profile_session.dart';
import '../../programme/models/programme_execution_context.dart';
import '../models/previous_performance_snapshot.dart';
import '../models/workout_player_result.dart';
import '../models/workout_player_state.dart';
import '../widgets/workout_player_widgets.dart';
import 'workout_overview_screen.dart';

class WorkoutCompleteScreen extends StatefulWidget {
  const WorkoutCompleteScreen({
    super.key,
    required this.state,
    required this.athleteId,
    this.trainingSessionId,
    this.programmeContext,
    this.completionService,
    this.progressionCoordinator,
  });

  final WorkoutPlayerState state;
  final String athleteId;
  final int? trainingSessionId;
  final ProgrammeExecutionContext? programmeContext;
  final WorkoutCompletionService? completionService;
  final AdaptiveProgressionCoordinator? progressionCoordinator;

  @override
  State<WorkoutCompleteScreen> createState() => _WorkoutCompleteScreenState();
}

class _WorkoutCompleteScreenState extends State<WorkoutCompleteScreen> {
  late final TextEditingController _notesController;
  int? _rpe;
  bool _finishing = false;
  _AdaptStatus _adaptStatus = _AdaptStatus.idle;
  String? _adaptError;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.state.notes ?? '');
    _rpe = widget.state.sessionRpe;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '—';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes <= 0) return '${seconds}s';
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() {
      _finishing = true;
      _adaptError = null;
    });

    final result = WorkoutPlayerResult(
      completed: true,
      trainingSessionId: widget.trainingSessionId,
      duration: widget.state.elapsed,
      exercisesCompleted: widget.state.completedExerciseCount,
      totalExercises: widget.state.totalExercises,
      sessionRpe: _rpe,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    final completionService =
        widget.completionService ?? WorkoutCompletionService();
    try {
      await completionService.complete(
        athleteId: widget.athleteId,
        trainingSessionId: widget.trainingSessionId,
        programmeContext: widget.programmeContext,
        result: result,
      );
    } catch (error) {
      debugPrint('[WorkoutComplete] bookkeeping failed: $error');
    }

    final coordinator =
        widget.progressionCoordinator ?? AdaptiveProgressionCoordinator();
    final sessionCompletion = coordinator.buildCompletion(
      result: result,
      athleteId: widget.athleteId,
    );
    if (!AthleteProfileSession.hasActivePlan) {
      SessionCompletionStore.add(sessionCompletion);
    }

    const capture = WorkoutExecutionCapture();
    final executionResults = capture.captureCompletedSteps(
      state: widget.state,
      completionId: sessionCompletion.completionId,
      completedAt: sessionCompletion.completedAt,
    );
    final derived = const PreviousPerformanceFromResults()
        .derive(executionResults);
    PreviousPerformanceStore.recordAll(derived);

    final shouldAdapt = AthleteProfileSession.hasActivePlan;
    if (shouldAdapt) {
      try {
        setState(() => _adaptStatus = _AdaptStatus.analysing);
        await Future<void>.delayed(const Duration(milliseconds: 450));
        if (!mounted) return;

        setState(() => _adaptStatus = _AdaptStatus.updating);
        await coordinator.runAfterCompletion(
          result: result,
          athleteId: widget.athleteId,
        );

        if (!mounted) return;
        setState(() => _adaptStatus = _AdaptStatus.ready);
        await Future<void>.delayed(const Duration(milliseconds: 650));
      } catch (error) {
        debugPrint('[WorkoutComplete] adaptive progression failed: $error');
        if (!mounted) return;
        setState(() {
          _adaptStatus = _AdaptStatus.idle;
          _adaptError = 'Could not update your plan. Your session is still saved.';
          _finishing = false;
        });
        return;
      }
    }

    if (AthletePersistence.isInitialized) {
      try {
        await AthletePersistence.hydrator.persistExerciseResults(
          widget.athleteId,
          executionResults,
        );
        await AthletePersistence.hydrator.persistPreviousPerformance(
          widget.athleteId,
        );
        await AthletePersistence.hydrator.persistCompletions(
          widget.athleteId,
        );
        await AthletePersistence.hydrator.discardWorkoutProgress(
          widget.athleteId,
        );
        if (!shouldAdapt) {
          await AthletePersistence.persistBoundSession();
        }
      } catch (error) {
        debugPrint('[WorkoutComplete] local persist failed: $error');
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final adapting = _adaptStatus != _AdaptStatus.idle;

    return Scaffold(
      backgroundColor: CohortColors.background,
      appBar: AppBar(
        backgroundColor: CohortColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('COMPLETE', style: CohortTextStyles.eyebrow),
        centerTitle: false,
      ),
      body: SafeArea(
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
                child: adapting
                    ? _AdaptTransition(status: _adaptStatus)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Workout Complete',
                            style: CohortTextStyles.h1,
                          ),
                          const SizedBox(height: CohortSpacing.sm),
                          Text(
                            state.brief.sessionName,
                            style: CohortTextStyles.body,
                          ),
                          const SizedBox(height: CohortSpacing.xl),
                          WorkoutMetaRow(
                            label: 'Duration',
                            value: _formatDuration(state.elapsed),
                          ),
                          WorkoutMetaRow(
                            label: 'Exercises completed',
                            value:
                                '${state.completedExerciseCount} of ${state.totalExercises}',
                          ),
                          const SizedBox(height: CohortSpacing.md),
                          Text(
                            'SESSION RPE',
                            style: CohortTextStyles.sectionLabel,
                          ),
                          const SizedBox(height: CohortSpacing.sm),
                          Wrap(
                            spacing: CohortSpacing.sm,
                            runSpacing: CohortSpacing.sm,
                            children: List.generate(10, (index) {
                              final value = index + 1;
                              final selected = _rpe == value;
                              return ChoiceChip(
                                label: Text('$value'),
                                selected: selected,
                                onSelected: _finishing
                                    ? null
                                    : (_) => setState(() => _rpe = value),
                                selectedColor: CohortColors.phosphorDeep,
                                labelStyle: TextStyle(
                                  color: selected
                                      ? const Color(0xFF0C0E0B)
                                      : CohortColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                                backgroundColor: CohortColors.surfaceRaised,
                              );
                            }),
                          ),
                          const SizedBox(height: CohortSpacing.xl),
                          Text(
                            'NOTES (OPTIONAL)',
                            style: CohortTextStyles.sectionLabel,
                          ),
                          const SizedBox(height: CohortSpacing.sm),
                          TextField(
                            controller: _notesController,
                            enabled: !_finishing,
                            maxLines: 3,
                            style: CohortTextStyles.body.copyWith(
                              color: CohortColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'How did the session feel?',
                              hintStyle: CohortTextStyles.body,
                              filled: true,
                              fillColor: CohortColors.surfaceRaised,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: CohortColors.border,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: CohortColors.border,
                                ),
                              ),
                            ),
                          ),
                          if (_adaptError != null) ...[
                            const SizedBox(height: CohortSpacing.lg),
                            Text(
                              _adaptError!,
                              style: CohortTextStyles.small.copyWith(
                                color: CohortColors.danger,
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
            if (!adapting)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  CohortSpacing.xl,
                  CohortSpacing.md,
                  CohortSpacing.xl,
                  CohortSpacing.xl,
                ),
                child: CohortButton(
                  label: _finishing ? 'FINISHING...' : 'FINISH',
                  showTrailingArrow: true,
                  onPressed: _finishing ? () {} : _finish,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _AdaptStatus { idle, analysing, updating, ready }

class _AdaptTransition extends StatelessWidget {
  const _AdaptTransition({required this.status});

  final _AdaptStatus status;

  @override
  Widget build(BuildContext context) {
    final message = switch (status) {
      _AdaptStatus.analysing => 'Saving today\'s session…',
      _AdaptStatus.updating => 'Preparing your next programmed session…',
      _AdaptStatus.ready => 'Next programmed session is ready.',
      _AdaptStatus.idle => '',
    };

    return Padding(
      padding: const EdgeInsets.only(top: CohortSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('COHORT', style: CohortTextStyles.eyebrow),
          const SizedBox(height: CohortSpacing.lg),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: Text(
              message,
              key: ValueKey(message),
              style: CohortTextStyles.h1,
            ),
          ),
          const SizedBox(height: CohortSpacing.md),
          Text(
            status == _AdaptStatus.ready
                ? 'Your next coach-authored session is waiting on Home.'
                : 'Calendar advances to the next programmed day — loads and '
                    'exercises are not changed automatically.',
            style: CohortTextStyles.body,
          ),
        ],
      ),
    );
  }
}
