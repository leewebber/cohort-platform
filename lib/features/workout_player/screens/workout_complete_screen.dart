import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../programme/models/programme_execution_context.dart';
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
  });

  final WorkoutPlayerState state;
  final String athleteId;
  final int? trainingSessionId;
  final ProgrammeExecutionContext? programmeContext;
  final WorkoutCompletionService? completionService;

  @override
  State<WorkoutCompleteScreen> createState() => _WorkoutCompleteScreenState();
}

class _WorkoutCompleteScreenState extends State<WorkoutCompleteScreen> {
  late final TextEditingController _notesController;
  int? _rpe;
  bool _finishing = false;

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
    setState(() => _finishing = true);

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

    final completion =
        widget.completionService ?? WorkoutCompletionService();
    try {
      await completion.complete(
        athleteId: widget.athleteId,
        trainingSessionId: widget.trainingSessionId,
        programmeContext: widget.programmeContext,
        result: result,
      );
    } catch (error) {
      debugPrint('[WorkoutComplete] bookkeeping failed: $error');
    }

    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Workout Complete', style: CohortTextStyles.h1),
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
                    Text('SESSION RPE', style: CohortTextStyles.sectionLabel),
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
                          onSelected: (_) => setState(() => _rpe = value),
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
                    Text('NOTES (OPTIONAL)', style: CohortTextStyles.sectionLabel),
                    const SizedBox(height: CohortSpacing.sm),
                    TextField(
                      controller: _notesController,
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
                          borderSide: const BorderSide(color: CohortColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: CohortColors.border),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
