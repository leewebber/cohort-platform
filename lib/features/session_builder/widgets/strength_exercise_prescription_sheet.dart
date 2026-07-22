import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../models/exercise.dart';
import '../../../models/strength_exercise_prescription.dart';
import '../../../models/strength_prescription_formatter.dart';
import '../../exercises/services/exercise_catalogue_service.dart';
import '../../exercises/widgets/exercise_picker_field.dart';
import 'session_builder_form_widgets.dart';

Future<({Exercise exercise, StrengthExercisePrescription prescription})?>
    showStrengthExercisePrescriptionSheet({
  required BuildContext context,
  ExerciseCatalogueLoader? catalogueLoader,
  Exercise? initialExercise,
  String? initialExerciseId,
  StrengthExercisePrescription? initialPrescription,
  String title = 'Exercise prescription',
}) async {
  return showModalBottomSheet<({Exercise exercise, StrengthExercisePrescription prescription})>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _StrengthExercisePrescriptionSheet(
      catalogueLoader: catalogueLoader ?? ExerciseCatalogueService(),
      initialExercise: initialExercise,
      initialExerciseId: initialExerciseId,
      initialPrescription: initialPrescription,
      title: title,
    ),
  );
}

class _StrengthExercisePrescriptionSheet extends StatefulWidget {
  const _StrengthExercisePrescriptionSheet({
    required this.catalogueLoader,
    this.initialExercise,
    this.initialExerciseId,
    this.initialPrescription,
    required this.title,
  });

  final ExerciseCatalogueLoader catalogueLoader;
  final Exercise? initialExercise;
  final String? initialExerciseId;
  final StrengthExercisePrescription? initialPrescription;
  final String title;

  @override
  State<_StrengthExercisePrescriptionSheet> createState() =>
      _StrengthExercisePrescriptionSheetState();
}

class _StrengthExercisePrescriptionSheetState
    extends State<_StrengthExercisePrescriptionSheet> {
  final GlobalKey<ExercisePickerFieldState> _pickerKey =
      GlobalKey<ExercisePickerFieldState>();
  Exercise? _selectedExercise;
  late final TextEditingController _setsController;
  late StrengthRepType _repType;
  late final TextEditingController _exactRepsController;
  late final TextEditingController _minRepsController;
  late final TextEditingController _maxRepsController;
  late final TextEditingController _repTextController;
  late StrengthLoadType _loadType;
  late final TextEditingController _kgController;
  late final TextEditingController _percentController;
  late final TextEditingController _rpeController;
  late final TextEditingController _rirController;
  late final TextEditingController _loadTextController;
  late final TextEditingController _restController;
  late final TextEditingController _tempoController;
  late final TextEditingController _cueController;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedExercise = widget.initialExercise;
    final prescription = widget.initialPrescription;
    _setsController = TextEditingController(
      text: prescription?.sets.toString() ?? '',
    );
    _repType = prescription?.reps.type ?? StrengthRepType.exact;
    _exactRepsController = TextEditingController(
      text: prescription?.reps.exactReps?.toString() ?? '',
    );
    _minRepsController = TextEditingController(
      text: prescription?.reps.minReps?.toString() ?? '',
    );
    _maxRepsController = TextEditingController(
      text: prescription?.reps.maxReps?.toString() ?? '',
    );
    _repTextController = TextEditingController(
      text: prescription?.reps.text ?? '',
    );
    _loadType = prescription?.load?.type ?? StrengthLoadType.bodyweight;
    _kgController = TextEditingController(
      text: prescription?.load?.kg?.toString() ?? '',
    );
    _percentController = TextEditingController(
      text: prescription?.load?.percent1rm?.toString() ?? '',
    );
    _rpeController = TextEditingController(
      text: prescription?.load?.rpe?.toString() ?? '',
    );
    _rirController = TextEditingController(
      text: prescription?.load?.rir?.toString() ?? '',
    );
    _loadTextController = TextEditingController(
      text: prescription?.load?.text ?? '',
    );
    _restController = TextEditingController(
      text: prescription?.restSeconds?.toString() ?? '',
    );
    _tempoController = TextEditingController(text: prescription?.tempo ?? '');
    _cueController = TextEditingController(text: prescription?.coachCue ?? '');
  }

  @override
  void dispose() {
    _setsController.dispose();
    _exactRepsController.dispose();
    _minRepsController.dispose();
    _maxRepsController.dispose();
    _repTextController.dispose();
    _kgController.dispose();
    _percentController.dispose();
    _rpeController.dispose();
    _rirController.dispose();
    _loadTextController.dispose();
    _restController.dispose();
    _tempoController.dispose();
    _cueController.dispose();
    super.dispose();
  }

  StrengthRepPrescription _buildReps() {
    return switch (_repType) {
      StrengthRepType.exact => StrengthRepPrescription.exact(
          int.tryParse(_exactRepsController.text.trim()) ?? 0,
        ),
      StrengthRepType.range => StrengthRepPrescription.range(
          min: int.tryParse(_minRepsController.text.trim()) ?? 0,
          max: int.tryParse(_maxRepsController.text.trim()) ?? 0,
        ),
      StrengthRepType.duration ||
      StrengthRepType.distance ||
      StrengthRepType.maxEffort ||
      StrengthRepType.freeText =>
        StrengthRepPrescription(
          type: _repType,
          text: _repTextController.text.trim(),
        ),
    };
  }

  StrengthLoadPrescription? _buildLoad() {
    return switch (_loadType) {
      StrengthLoadType.bodyweight =>
        const StrengthLoadPrescription(type: StrengthLoadType.bodyweight),
      StrengthLoadType.fixedKg => StrengthLoadPrescription(
          type: StrengthLoadType.fixedKg,
          kg: double.tryParse(_kgController.text.trim()),
        ),
      StrengthLoadType.percent1rm => StrengthLoadPrescription(
          type: StrengthLoadType.percent1rm,
          percent1rm: double.tryParse(_percentController.text.trim()),
        ),
      StrengthLoadType.rpe => StrengthLoadPrescription(
          type: StrengthLoadType.rpe,
          rpe: int.tryParse(_rpeController.text.trim()),
        ),
      StrengthLoadType.rir => StrengthLoadPrescription(
          type: StrengthLoadType.rir,
          rir: int.tryParse(_rirController.text.trim()),
        ),
      StrengthLoadType.athleteSelected =>
        const StrengthLoadPrescription(type: StrengthLoadType.athleteSelected),
      StrengthLoadType.freeText => StrengthLoadPrescription(
          type: StrengthLoadType.freeText,
          text: _loadTextController.text.trim(),
        ),
    };
  }

  void _save() {
    final selected = _selectedExercise ?? _pickerKey.currentState?.selectedExercise;
    if (selected == null) {
      _pickerKey.currentState?.showSelectionRequiredError();
      setState(() => _errorMessage = 'Select an exercise from the library.');
      return;
    }

    final prescription = StrengthExercisePrescription(
      sets: int.tryParse(_setsController.text.trim()) ?? 0,
      reps: _buildReps(),
      load: _buildLoad(),
      restSeconds: int.tryParse(_restController.text.trim()),
      tempo: _tempoController.text.trim(),
      coachCue: _cueController.text.trim(),
    );

    final errors = prescription.validate(requireComplete: true);
    if (errors.isNotEmpty) {
      setState(() => _errorMessage = errors.first);
      return;
    }

    Navigator.of(context).pop((
      exercise: selected,
      prescription: prescription,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: CohortSpacing.lg,
        right: CohortSpacing.lg,
        top: CohortSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + CohortSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title, style: CohortTextStyles.h2),
            const SizedBox(height: CohortSpacing.md),
            ExercisePickerField(
              key: _pickerKey,
              catalogueLoader: widget.catalogueLoader,
              initialExercise: widget.initialExercise,
              initialExerciseId: widget.initialExerciseId,
              onSelected: (exercise) {
                setState(() {
                  _selectedExercise = exercise;
                  _errorMessage = null;
                });
              },
            ),
            const SizedBox(height: CohortSpacing.sm),
            SessionBuilderTextField(
              label: 'Sets',
              controller: _setsController,
              keyboardType: TextInputType.number,
            ),
            SessionBuilderDropdown(
              label: 'Reps type',
              value: _repTypeLabel(_repType),
              options: const [
                'Exact reps',
                'Rep range',
                'Duration',
                'Distance',
                'Max effort / AMRAP',
                'Free text',
              ],
              onChanged: (value) {
                setState(() {
                  _repType = switch (value) {
                    'Rep range' => StrengthRepType.range,
                    'Duration' => StrengthRepType.duration,
                    'Distance' => StrengthRepType.distance,
                    'Max effort / AMRAP' => StrengthRepType.maxEffort,
                    'Free text' => StrengthRepType.freeText,
                    _ => StrengthRepType.exact,
                  };
                });
              },
            ),
            if (_repType == StrengthRepType.exact)
              SessionBuilderTextField(
                label: 'Reps',
                controller: _exactRepsController,
                keyboardType: TextInputType.number,
              ),
            if (_repType == StrengthRepType.range) ...[
              SessionBuilderTextField(
                label: 'Min reps',
                controller: _minRepsController,
                keyboardType: TextInputType.number,
              ),
              SessionBuilderTextField(
                label: 'Max reps',
                controller: _maxRepsController,
                keyboardType: TextInputType.number,
              ),
            ],
            if (_repType == StrengthRepType.duration ||
                _repType == StrengthRepType.distance ||
                _repType == StrengthRepType.maxEffort ||
                _repType == StrengthRepType.freeText)
              SessionBuilderTextField(
                label: 'Reps description',
                controller: _repTextController,
              ),
            SessionBuilderDropdown(
              label: 'Load',
              value: _loadTypeLabel(_loadType),
              options: const [
                'Bodyweight',
                'Fixed load (kg)',
                'Percentage of 1RM',
                'RPE',
                'RIR',
                'Athlete selected',
                'Free text',
              ],
              onChanged: (value) {
                setState(() {
                  _loadType = switch (value) {
                    'Fixed load (kg)' => StrengthLoadType.fixedKg,
                    'Percentage of 1RM' => StrengthLoadType.percent1rm,
                    'RPE' => StrengthLoadType.rpe,
                    'RIR' => StrengthLoadType.rir,
                    'Athlete selected' => StrengthLoadType.athleteSelected,
                    'Free text' => StrengthLoadType.freeText,
                    _ => StrengthLoadType.bodyweight,
                  };
                });
              },
            ),
            if (_loadType == StrengthLoadType.fixedKg)
              SessionBuilderTextField(
                label: 'Load (kg)',
                controller: _kgController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            if (_loadType == StrengthLoadType.percent1rm)
              SessionBuilderTextField(
                label: 'Percentage of 1RM',
                controller: _percentController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            if (_loadType == StrengthLoadType.rpe)
              SessionBuilderTextField(
                label: 'RPE',
                controller: _rpeController,
                keyboardType: TextInputType.number,
              ),
            if (_loadType == StrengthLoadType.rir)
              SessionBuilderTextField(
                label: 'RIR',
                controller: _rirController,
                keyboardType: TextInputType.number,
              ),
            if (_loadType == StrengthLoadType.freeText)
              SessionBuilderTextField(
                label: 'Load description',
                controller: _loadTextController,
              ),
            SessionBuilderTextField(
              label: 'Rest (seconds)',
              controller: _restController,
              keyboardType: TextInputType.number,
            ),
            SessionBuilderTextField(
              label: 'Tempo',
              controller: _tempoController,
            ),
            SessionBuilderTextField(
              label: 'Coach cue',
              controller: _cueController,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: CohortSpacing.sm),
              Text(
                _errorMessage!,
                style: CohortTextStyles.small.copyWith(color: CohortColors.danger),
              ),
            ],
            const SizedBox(height: CohortSpacing.lg),
            CohortButton(label: 'Save exercise', onPressed: _save),
          ],
        ),
      ),
    );
  }

  String _repTypeLabel(StrengthRepType type) {
    return switch (type) {
      StrengthRepType.exact => 'Exact reps',
      StrengthRepType.range => 'Rep range',
      StrengthRepType.duration => 'Duration',
      StrengthRepType.distance => 'Distance',
      StrengthRepType.maxEffort => 'Max effort / AMRAP',
      StrengthRepType.freeText => 'Free text',
    };
  }

  String _loadTypeLabel(StrengthLoadType type) {
    return switch (type) {
      StrengthLoadType.bodyweight => 'Bodyweight',
      StrengthLoadType.fixedKg => 'Fixed load (kg)',
      StrengthLoadType.percent1rm => 'Percentage of 1RM',
      StrengthLoadType.rpe => 'RPE',
      StrengthLoadType.rir => 'RIR',
      StrengthLoadType.athleteSelected => 'Athlete selected',
      StrengthLoadType.freeText => 'Free text',
    };
  }
}

class StrengthExercisePrescriptionCard extends StatelessWidget {
  const StrengthExercisePrescriptionCard({
    super.key,
    required this.exerciseName,
    required this.prescription,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onEdit,
    required this.onDuplicate,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final String exerciseName;
  final StrengthExercisePrescription? prescription;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onRemove;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    final summary = prescription?.hasStructuredData == true
        ? StrengthPrescriptionFormatter.summaryLine(prescription!)
        : 'Prescription incomplete';
    final details = prescription?.hasStructuredData == true
        ? StrengthPrescriptionFormatter.detailLine(prescription!)
        : '';

    return Container(
      padding: const EdgeInsets.all(CohortSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: CohortColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(exerciseName, style: CohortTextStyles.cardTitle),
          const SizedBox(height: CohortSpacing.xs),
          Text(summary, style: CohortTextStyles.body),
          if (details.isNotEmpty) ...[
            const SizedBox(height: CohortSpacing.xs),
            Text(details, style: CohortTextStyles.small),
          ],
          if (prescription?.coachCue?.trim().isNotEmpty == true) ...[
            const SizedBox(height: CohortSpacing.xs),
            Text(prescription!.coachCue!.trim(), style: CohortTextStyles.small),
          ],
          const SizedBox(height: CohortSpacing.sm),
          Wrap(
            spacing: CohortSpacing.sm,
            runSpacing: CohortSpacing.xs,
            children: [
              TextButton(onPressed: onEdit, child: const Text('Edit')),
              TextButton(onPressed: onDuplicate, child: const Text('Duplicate')),
              TextButton(onPressed: onRemove, child: const Text('Remove')),
              IconButton(
                onPressed: canMoveUp ? onMoveUp : null,
                icon: const Icon(Icons.arrow_upward, size: 18),
              ),
              IconButton(
                onPressed: canMoveDown ? onMoveDown : null,
                icon: const Icon(Icons.arrow_downward, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
