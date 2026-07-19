import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../../models/block_performance_capture_mode.dart';
import '../../../models/exercise.dart';
import '../../../models/session_block.dart';
import '../../../models/session_block_type.dart';
import '../../../models/timer_configuration.dart';
import '../../../models/workout_format.dart';
import '../../../models/session_block_exercise_link.dart';
import 'session_builder_form_widgets.dart';
import 'workout_content_editor.dart';

class SessionBlockEditorCard extends StatefulWidget {
  const SessionBlockEditorCard({
    super.key,
    required this.block,
    required this.exercises,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onChanged,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDuplicate,
    required this.onDelete,
    required this.onWorkoutFormatChanged,
    required this.onTimerConfigurationChanged,
    required this.onAddExercise,
    required this.onRemoveExercise,
    required this.onMoveExerciseUp,
    required this.onMoveExerciseDown,
    required this.onExerciseLabelChanged,
    this.initiallyExpanded = true,
    this.useCoachLabels = false,
  });

  final SessionBlock block;
  final List<Exercise> exercises;
  final bool canMoveUp;
  final bool canMoveDown;
  final ValueChanged<SessionBlock> onChanged;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final ValueChanged<WorkoutFormat> onWorkoutFormatChanged;
  final ValueChanged<TimerConfiguration> onTimerConfigurationChanged;
  final ValueChanged<Exercise> onAddExercise;
  final ValueChanged<String> onRemoveExercise;
  final void Function(String linkLocalId) onMoveExerciseUp;
  final void Function(String linkLocalId) onMoveExerciseDown;
  final void Function(String linkLocalId, String? label) onExerciseLabelChanged;
  final bool initiallyExpanded;
  final bool useCoachLabels;

  @override
  State<SessionBlockEditorCard> createState() => _SessionBlockEditorCardState();
}

class _SessionBlockEditorCardState extends State<SessionBlockEditorCard> {
  late bool _expanded;
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _coachNotesController;
  Exercise? _selectedExerciseToAdd;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _titleController = TextEditingController(text: widget.block.title);
    _contentController = TextEditingController(text: widget.block.content);
    _coachNotesController =
        TextEditingController(text: widget.block.coachNotes ?? '');
  }

  @override
  void didUpdateWidget(covariant SessionBlockEditorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.block.localId != oldWidget.block.localId) {
      _titleController.text = widget.block.title;
      _contentController.text = widget.block.content;
      _coachNotesController.text = widget.block.coachNotes ?? '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _coachNotesController.dispose();
    super.dispose();
  }

  void _emitChanged({
    SessionBlockType? blockType,
    String? title,
    String? content,
    String? coachNotes,
  }) {
    widget.onChanged(
      widget.block.copyWith(
        blockType: blockType,
        title: title ?? _titleController.text.trim(),
        content: content ?? _contentController.text,
        coachNotes: coachNotes ?? _emptyToNull(_coachNotesController.text),
      ),
    );
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  IconData _iconForType(SessionBlockType type) {
    return switch (type) {
      SessionBlockType.warmUp => Icons.self_improvement_outlined,
      SessionBlockType.strength => Icons.fitness_center_outlined,
      SessionBlockType.skill => Icons.sports_gymnastics_outlined,
      SessionBlockType.accessory => Icons.add_circle_outline,
      SessionBlockType.conditioning => Icons.timer_outlined,
      SessionBlockType.core => Icons.center_focus_strong_outlined,
      SessionBlockType.coolDown => Icons.air_outlined,
      SessionBlockType.custom => Icons.widgets_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    final formatBadge = block.workoutFormat == WorkoutFormat.none
        ? null
        : block.workoutFormat.displayLabel;

    return CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_iconForType(block.blockType), color: CohortColors.olive),
              const SizedBox(width: CohortSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      block.title.trim().isEmpty
                          ? block.blockType.defaultTitle
                          : block.title.trim(),
                      style: CohortTextStyles.cardTitle,
                    ),
                    Text(
                      block.blockType.displayLabel,
                      style: CohortTextStyles.small.copyWith(
                        color: CohortColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (formatBadge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CohortSpacing.sm,
                    vertical: CohortSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: CohortColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(formatBadge, style: CohortTextStyles.small),
                ),
              IconButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'duplicate':
                      widget.onDuplicate();
                    case 'delete':
                      widget.onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          if (_expanded) ...[
            const SizedBox(height: CohortSpacing.md),
            Row(
              children: [
                IconButton(
                  onPressed: widget.canMoveUp ? widget.onMoveUp : null,
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  onPressed: widget.canMoveDown ? widget.onMoveDown : null,
                  icon: const Icon(Icons.arrow_downward),
                ),
              ],
            ),
            SessionBuilderTextField(
              label: 'Block title',
              controller: _titleController,
              onChanged: (_) => _emitChanged(),
            ),
            SessionBuilderDropdown(
              label: 'Block type',
              value: block.blockType.displayLabel,
              options: SessionBlockType.values
                  .map((type) => type.displayLabel)
                  .toList(growable: false),
              onChanged: (value) {
                final type = SessionBlockType.values.firstWhere(
                  (item) => item.displayLabel == value,
                  orElse: () => block.blockType,
                );
                _emitChanged(blockType: type);
              },
            ),
            SessionBuilderDropdown(
              label: 'Workout format',
              value: block.workoutFormat.displayLabel,
              options: WorkoutFormat.values
                  .map((format) => format.displayLabel)
                  .toList(growable: false),
              onChanged: (value) {
                final format = WorkoutFormat.values.firstWhere(
                  (item) => item.displayLabel == value,
                  orElse: () => block.workoutFormat,
                );
                widget.onWorkoutFormatChanged(format);
              },
            ),
            SessionBuilderDropdown(
              label: 'Performance capture',
              value: block.performanceCaptureMode.coachLabel,
              options: BlockPerformanceCaptureMode.values
                  .map((mode) => mode.coachLabel)
                  .toList(growable: false),
              onChanged: (value) {
                final mode = BlockPerformanceCaptureMode.values.firstWhere(
                  (item) => item.coachLabel == value,
                  orElse: () => block.performanceCaptureMode,
                );
                widget.onChanged(block.copyWith(performanceCaptureMode: mode));
              },
            ),
            WorkoutContentEditor(
              label: 'Workout content',
              controller: _contentController,
              onChanged: (value) => _emitChanged(content: value),
            ),
            if (block.workoutFormat.supportsTimer) ...[
              Text('Timer settings', style: CohortTextStyles.eyebrow),
              const SizedBox(height: CohortSpacing.sm),
              _TimerFields(
                workoutFormat: block.workoutFormat,
                configuration:
                    block.timerConfiguration ?? const TimerConfiguration(),
                onChanged: widget.onTimerConfigurationChanged,
              ),
            ],
            Text('Exercises used', style: CohortTextStyles.eyebrow),
            const SizedBox(height: CohortSpacing.sm),
            for (var index = 0; index < block.linkedExercises.length; index++) ...[
              _ExerciseLinkRow(
                link: block.linkedExercises[index],
                exercises: widget.exercises,
                canMoveUp: index > 0,
                canMoveDown: index < block.linkedExercises.length - 1,
                onRemove: () =>
                    widget.onRemoveExercise(block.linkedExercises[index].localId),
                onMoveUp: () =>
                    widget.onMoveExerciseUp(block.linkedExercises[index].localId),
                onMoveDown: () => widget.onMoveExerciseDown(
                  block.linkedExercises[index].localId,
                ),
                onLabelChanged: (label) => widget.onExerciseLabelChanged(
                  block.linkedExercises[index].localId,
                  label,
                ),
              ),
              const SizedBox(height: CohortSpacing.sm),
            ],
            Row(
              children: [
                Expanded(
                  child: DropdownButton<Exercise?>(
                    isExpanded: true,
                    value: _selectedExerciseToAdd,
                    hint: const Text('Select exercise to link'),
                    items: widget.exercises
                        .map(
                          (exercise) => DropdownMenuItem<Exercise?>(
                            value: exercise,
                            child: Text(exercise.name),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (exercise) =>
                        setState(() => _selectedExerciseToAdd = exercise),
                  ),
                ),
                const SizedBox(width: CohortSpacing.sm),
                TextButton(
                  onPressed: _selectedExerciseToAdd == null
                      ? null
                      : () {
                          widget.onAddExercise(_selectedExerciseToAdd!);
                          setState(() => _selectedExerciseToAdd = null);
                        },
                  child: const Text('Link'),
                ),
              ],
            ),
            SessionBuilderTextField(
              label: 'Coach notes',
              controller: _coachNotesController,
              onChanged: (_) => _emitChanged(),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimerFields extends StatelessWidget {
  const _TimerFields({
    required this.workoutFormat,
    required this.configuration,
    required this.onChanged,
  });

  final WorkoutFormat workoutFormat;
  final TimerConfiguration configuration;
  final ValueChanged<TimerConfiguration> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget field(String label, int? value, ValueChanged<int?> setter) {
      final controller = TextEditingController(text: value?.toString() ?? '');
      return SessionBuilderTextField(
        label: label,
        controller: controller,
        keyboardType: TextInputType.number,
        onChanged: (text) {
          final trimmed = text.trim();
          setter(trimmed.isEmpty ? null : int.tryParse(trimmed));
        },
      );
    }

    return Column(
      children: [
        switch (workoutFormat) {
          WorkoutFormat.amrap => field(
              'Duration (seconds)',
              configuration.durationSeconds,
              (value) => onChanged(configuration.copyWith(durationSeconds: value)),
            ),
          WorkoutFormat.emom => Column(
              children: [
                field(
                  'Total duration (seconds)',
                  configuration.totalDurationSeconds,
                  (value) => onChanged(
                    configuration.copyWith(totalDurationSeconds: value),
                  ),
                ),
                field(
                  'Interval (seconds)',
                  configuration.intervalSeconds,
                  (value) =>
                      onChanged(configuration.copyWith(intervalSeconds: value)),
                ),
              ],
            ),
          WorkoutFormat.forTime => field(
              'Time cap (seconds, optional)',
              configuration.timeCapSeconds,
              (value) => onChanged(
                configuration.copyWith(
                  timeCapSeconds: value,
                  stopwatchEnabled: true,
                ),
              ),
            ),
          WorkoutFormat.intervals => Column(
              children: [
                field(
                  'Work (seconds)',
                  configuration.workSeconds,
                  (value) =>
                      onChanged(configuration.copyWith(workSeconds: value)),
                ),
                field(
                  'Rest (seconds)',
                  configuration.restSeconds,
                  (value) =>
                      onChanged(configuration.copyWith(restSeconds: value)),
                ),
                field(
                  'Rounds',
                  configuration.rounds,
                  (value) => onChanged(configuration.copyWith(rounds: value)),
                ),
              ],
            ),
          WorkoutFormat.tabata => Column(
              children: [
                field(
                  'Work (seconds)',
                  configuration.workSeconds,
                  (value) =>
                      onChanged(configuration.copyWith(workSeconds: value)),
                ),
                field(
                  'Rest (seconds)',
                  configuration.restSeconds,
                  (value) =>
                      onChanged(configuration.copyWith(restSeconds: value)),
                ),
                field(
                  'Rounds',
                  configuration.rounds,
                  (value) => onChanged(configuration.copyWith(rounds: value)),
                ),
              ],
            ),
          WorkoutFormat.rounds => Column(
              children: [
                field(
                  'Target rounds',
                  configuration.targetRounds,
                  (value) =>
                      onChanged(configuration.copyWith(targetRounds: value)),
                ),
                field(
                  'Rest between rounds (seconds)',
                  configuration.restBetweenRoundsSeconds,
                  (value) => onChanged(
                    configuration.copyWith(restBetweenRoundsSeconds: value),
                  ),
                ),
              ],
            ),
          WorkoutFormat.other => field(
              'Duration (seconds, optional)',
              configuration.durationSeconds,
              (value) =>
                  onChanged(configuration.copyWith(durationSeconds: value)),
            ),
          WorkoutFormat.none => const SizedBox.shrink(),
        },
      ],
    );
  }
}

class _ExerciseLinkRow extends StatefulWidget {
  const _ExerciseLinkRow({
    required this.link,
    required this.exercises,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onLabelChanged,
  });

  final SessionBlockExerciseLink link;
  final List<Exercise> exercises;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onRemove;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final ValueChanged<String?> onLabelChanged;

  @override
  State<_ExerciseLinkRow> createState() => _ExerciseLinkRowState();
}

class _ExerciseLinkRowState extends State<_ExerciseLinkRow> {
  late final TextEditingController _labelController;

  @override
  void initState() {
    super.initState();
    _labelController =
        TextEditingController(text: widget.link.displayLabelOverride ?? '');
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  String _exerciseName() {
    for (final exercise in widget.exercises) {
      if (exercise.exerciseId == widget.link.exerciseId) {
        return exercise.name;
      }
    }
    return widget.link.exerciseId;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_exerciseName(), style: CohortTextStyles.body),
              TextField(
                controller: _labelController,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Athlete-facing label override (optional)',
                ),
                onChanged: (value) => widget.onLabelChanged(
                  value.trim().isEmpty ? null : value.trim(),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: widget.canMoveUp ? widget.onMoveUp : null,
          icon: const Icon(Icons.arrow_upward, size: 18),
        ),
        IconButton(
          onPressed: widget.canMoveDown ? widget.onMoveDown : null,
          icon: const Icon(Icons.arrow_downward, size: 18),
        ),
        IconButton(
          onPressed: widget.onRemove,
          icon: const Icon(Icons.close, size: 18),
          color: CohortColors.danger,
        ),
      ],
    );
  }
}
