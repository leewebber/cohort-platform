import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../../models/exercise.dart';
import '../../../models/protocol_step_draft.dart';
import '../models/session_builder_constants.dart';
import 'session_builder_form_widgets.dart';

/// Editable step/block card — shared between admin and embedded Session Builder.
class SessionBuilderStepEditorCard extends StatefulWidget {
  const SessionBuilderStepEditorCard({
    super.key,
    required this.step,
    required this.exercises,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onChanged,
    required this.onTitleCustomised,
    required this.onExerciseSelected,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
    this.useCoachLabels = false,
  });

  final ProtocolStepDraft step;
  final List<Exercise> exercises;
  final bool canMoveUp;
  final bool canMoveDown;
  final ValueChanged<ProtocolStepDraft> onChanged;
  final VoidCallback onTitleCustomised;
  final void Function(Exercise? exercise, String currentTitle) onExerciseSelected;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDelete;
  final bool useCoachLabels;

  @override
  State<SessionBuilderStepEditorCard> createState() =>
      _SessionBuilderStepEditorCardState();
}

class _SessionBuilderStepEditorCardState
    extends State<SessionBuilderStepEditorCard> {
  late final TextEditingController _titleController;
  late final TextEditingController _setsController;
  late final TextEditingController _repsController;
  late final TextEditingController _distanceController;
  late final TextEditingController _durationController;
  late final TextEditingController _restController;
  late final TextEditingController _tempoController;
  late final TextEditingController _loadController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    final step = widget.step;
    _titleController = TextEditingController(text: step.title);
    _setsController = TextEditingController(text: step.sets ?? '');
    _repsController = TextEditingController(text: step.reps ?? '');
    _distanceController = TextEditingController(text: step.distance ?? '');
    _durationController = TextEditingController(text: step.duration ?? '');
    _restController = TextEditingController(text: step.rest ?? '');
    _tempoController = TextEditingController(text: step.tempo ?? '');
    _loadController = TextEditingController(text: step.load ?? '');
    _notesController = TextEditingController(text: step.notes ?? '');
  }

  @override
  void didUpdateWidget(covariant SessionBuilderStepEditorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.step.localId != oldWidget.step.localId) {
      _titleController.text = widget.step.title;
      _setsController.text = widget.step.sets ?? '';
      _repsController.text = widget.step.reps ?? '';
      _distanceController.text = widget.step.distance ?? '';
      _durationController.text = widget.step.duration ?? '';
      _restController.text = widget.step.rest ?? '';
      _tempoController.text = widget.step.tempo ?? '';
      _loadController.text = widget.step.load ?? '';
      _notesController.text = widget.step.notes ?? '';
      return;
    }

    if (widget.step.title != oldWidget.step.title &&
        widget.step.title != _titleController.text.trim()) {
      _titleController.text = widget.step.title;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _setsController.dispose();
    _repsController.dispose();
    _distanceController.dispose();
    _durationController.dispose();
    _restController.dispose();
    _tempoController.dispose();
    _loadController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _emitChanged({
    String? section,
    String? stepType,
    String? displayStyle,
    String? exerciseId,
    String? title,
    String? sets,
    String? reps,
    String? distance,
    String? duration,
    String? rest,
    String? tempo,
    String? load,
    String? notes,
  }) {
    widget.onChanged(
      widget.step.copyWith(
        section: section ?? widget.step.section,
        stepType: stepType ?? widget.step.stepType,
        displayStyle: displayStyle ?? widget.step.displayStyle,
        exerciseId: exerciseId ?? widget.step.exerciseId,
        title: title ?? _titleController.text.trim(),
        sets: _emptyToNull(sets ?? _setsController.text),
        reps: _emptyToNull(reps ?? _repsController.text),
        distance: _emptyToNull(distance ?? _distanceController.text),
        duration: _emptyToNull(duration ?? _durationController.text),
        rest: _emptyToNull(rest ?? _restController.text),
        tempo: _emptyToNull(tempo ?? _tempoController.text),
        load: _emptyToNull(load ?? _loadController.text),
        notes: _emptyToNull(notes ?? _notesController.text),
      ),
    );
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Exercise? _selectedExercise() {
    final exerciseId = widget.step.exerciseId;
    if (exerciseId == null || exerciseId.isEmpty) return null;

    for (final exercise in widget.exercises) {
      if (exercise.exerciseId == exerciseId) return exercise;
    }

    return null;
  }

  String _label(String admin, String coach) {
    return widget.useCoachLabels ? coach : admin;
  }

  @override
  Widget build(BuildContext context) {
    return CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.useCoachLabels
                      ? 'BLOCK ${widget.step.stepOrder}'
                      : 'STEP ${widget.step.stepOrder}',
                  style: CohortTextStyles.eyebrow,
                ),
              ),
              IconButton(
                onPressed: widget.canMoveUp ? widget.onMoveUp : null,
                icon: const Icon(Icons.arrow_upward),
                color: CohortColors.textSecondary,
              ),
              IconButton(
                onPressed: widget.canMoveDown ? widget.onMoveDown : null,
                icon: const Icon(Icons.arrow_downward),
                color: CohortColors.textSecondary,
              ),
              IconButton(
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete_outline),
                color: CohortColors.danger,
              ),
            ],
          ),
          SessionBuilderDropdown(
            label: _label('section', 'Block'),
            value: widget.step.section,
            options: SessionBuilderConstants.sections,
            onChanged: (value) => _emitChanged(section: value),
          ),
          SessionBuilderDropdown(
            label: _label('step_type', 'Type'),
            value: widget.step.stepType,
            options: SessionBuilderConstants.stepTypes,
            onChanged: (value) => _emitChanged(stepType: value),
          ),
          SessionBuilderDropdown(
            label: _label('display_style', 'Display'),
            value: widget.step.displayStyle,
            options: SessionBuilderConstants.displayStyles,
            onChanged: (value) => _emitChanged(displayStyle: value),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: CohortSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _label('exercise', 'Exercise'),
                  style: CohortTextStyles.eyebrow,
                ),
                const SizedBox(height: CohortSpacing.xs),
                DropdownButton<Exercise?>(
                  isExpanded: true,
                  isDense: true,
                  value: _selectedExercise(),
                  style: CohortTextStyles.small,
                  items: [
                    const DropdownMenuItem<Exercise?>(
                      value: null,
                      child: Text('—', style: CohortTextStyles.small),
                    ),
                    ...widget.exercises.map(
                      (exercise) => DropdownMenuItem<Exercise?>(
                        value: exercise,
                        child: Text(
                          widget.useCoachLabels
                              ? exercise.name
                              : '${exercise.name} (${exercise.exerciseId})',
                          style: CohortTextStyles.small,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (exercise) {
                    widget.onExerciseSelected(
                      exercise,
                      _titleController.text.trim(),
                    );
                  },
                ),
              ],
            ),
          ),
          SessionBuilderStepTextField(
            label: _label('title', 'Title'),
            controller: _titleController,
            onChanged: (value) {
              widget.onTitleCustomised();
              _emitChanged(title: value);
            },
          ),
          Row(
            children: [
              Expanded(
                child: SessionBuilderStepTextField(
                  label: 'sets',
                  controller: _setsController,
                  onChanged: (_) => _emitChanged(),
                ),
              ),
              const SizedBox(width: CohortSpacing.md),
              Expanded(
                child: SessionBuilderStepTextField(
                  label: 'reps',
                  controller: _repsController,
                  onChanged: (_) => _emitChanged(),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: SessionBuilderStepTextField(
                  label: 'distance',
                  controller: _distanceController,
                  onChanged: (_) => _emitChanged(),
                ),
              ),
              const SizedBox(width: CohortSpacing.md),
              Expanded(
                child: SessionBuilderStepTextField(
                  label: 'duration',
                  controller: _durationController,
                  onChanged: (_) => _emitChanged(),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: SessionBuilderStepTextField(
                  label: 'rest',
                  controller: _restController,
                  onChanged: (_) => _emitChanged(),
                ),
              ),
              const SizedBox(width: CohortSpacing.md),
              Expanded(
                child: SessionBuilderStepTextField(
                  label: 'tempo',
                  controller: _tempoController,
                  onChanged: (_) => _emitChanged(),
                ),
              ),
            ],
          ),
          SessionBuilderStepTextField(
            label: 'load',
            controller: _loadController,
            onChanged: (_) => _emitChanged(),
          ),
          SessionBuilderStepTextField(
            label: 'notes',
            controller: _notesController,
            onChanged: (_) => _emitChanged(),
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}
