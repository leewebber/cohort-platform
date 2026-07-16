import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../models/programme_vocabulary.dart';
import '../../../programme_builder/models/programme_version_draft_metadata.dart';
import '../controllers/programme_editor_controller.dart';

Future<void> showProgrammeEditorMetadataSheet({
  required BuildContext context,
  required ProgrammeEditorController controller,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => ProgrammeEditorMetadataSheet(controller: controller),
  );
}

class ProgrammeEditorMetadataSheet extends StatefulWidget {
  const ProgrammeEditorMetadataSheet({
    super.key,
    required this.controller,
  });

  final ProgrammeEditorController controller;

  @override
  State<ProgrammeEditorMetadataSheet> createState() =>
      _ProgrammeEditorMetadataSheetState();
}

class _ProgrammeEditorMetadataSheetState
    extends State<ProgrammeEditorMetadataSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _durationController;
  late final TextEditingController _goalController;
  late final TextEditingController _targetAthleteController;
  late final TextEditingController _difficultyController;
  late final TextEditingController _equipmentController;
  late final TextEditingController _sessionsPerWeekController;
  ProgrammeLibraryScope _libraryScope = ProgrammeLibraryScope.coachPrivate;

  @override
  void initState() {
    super.initState();
    final metadata = widget.controller.document!.metadata;
    _nameController = TextEditingController(text: metadata.name);
    _descriptionController =
        TextEditingController(text: metadata.description ?? '');
    _durationController = TextEditingController(
      text: metadata.durationWeeks?.toString() ?? '',
    );
    _goalController = TextEditingController(text: metadata.primaryGoal ?? '');
    _targetAthleteController =
        TextEditingController(text: metadata.targetAthlete ?? '');
    _difficultyController =
        TextEditingController(text: metadata.difficulty ?? '');
    _equipmentController =
        TextEditingController(text: metadata.equipmentRequirements ?? '');
    _sessionsPerWeekController = TextEditingController(
      text: metadata.sessionsPerWeek?.toString() ?? '',
    );
    _libraryScope = metadata.libraryScope;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _goalController.dispose();
    _targetAthleteController.dispose();
    _difficultyController.dispose();
    _equipmentController.dispose();
    _sessionsPerWeekController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metadata = widget.controller.document!.metadata;
    final readOnly = widget.controller.isReadOnly;

    return Padding(
      padding: EdgeInsets.only(
        left: CohortSpacing.lg,
        right: CohortSpacing.lg,
        top: CohortSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + CohortSpacing.lg,
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text('Programme details', style: CohortTextStyles.h2),
          const SizedBox(height: CohortSpacing.md),
          _field('Name', _nameController, enabled: !readOnly),
          if (metadata.isPersisted) ...[
            const SizedBox(height: CohortSpacing.md),
            Text('Lineage code', style: CohortTextStyles.body),
            Text(metadata.lineageCode, style: CohortTextStyles.cardTitle),
          ],
          const SizedBox(height: CohortSpacing.md),
          _field('Description', _descriptionController,
              enabled: !readOnly, maxLines: 3),
          const SizedBox(height: CohortSpacing.md),
          DropdownButtonFormField<ProgrammeLibraryScope>(
            value: _libraryScope,
            decoration: const InputDecoration(labelText: 'Library scope'),
            items: ProgrammeLibraryScope.values
                .map(
                  (scope) => DropdownMenuItem(
                    value: scope,
                    child: Text(scope.displayLabel),
                  ),
                )
                .toList(),
            onChanged: readOnly
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() => _libraryScope = value);
                  },
          ),
          const SizedBox(height: CohortSpacing.md),
          _field('Duration weeks', _durationController, enabled: !readOnly),
          const SizedBox(height: CohortSpacing.md),
          _field('Primary goal', _goalController, enabled: !readOnly),
          const SizedBox(height: CohortSpacing.md),
          _field('Target athlete', _targetAthleteController, enabled: !readOnly),
          const SizedBox(height: CohortSpacing.md),
          _field('Difficulty', _difficultyController, enabled: !readOnly),
          const SizedBox(height: CohortSpacing.md),
          _field('Equipment requirements', _equipmentController,
              enabled: !readOnly),
          const SizedBox(height: CohortSpacing.md),
          _field('Sessions per week', _sessionsPerWeekController,
              enabled: !readOnly),
          if (!readOnly) ...[
            const SizedBox(height: CohortSpacing.lg),
            FilledButton(
              onPressed: _save,
              child: const Text('Apply changes'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool enabled = true,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
    );
  }

  Future<void> _save() async {
    final current = widget.controller.document!.metadata;
    final updated = current.copyWith(
      name: _nameController.text.trim(),
      description: _nullable(_descriptionController.text),
      libraryScope: _libraryScope,
      durationWeeks: int.tryParse(_durationController.text.trim()),
      primaryGoal: _nullable(_goalController.text),
      targetAthlete: _nullable(_targetAthleteController.text),
      difficulty: _nullable(_difficultyController.text),
      equipmentRequirements: _nullable(_equipmentController.text),
      sessionsPerWeek: int.tryParse(_sessionsPerWeekController.text.trim()),
      clearDescription: _descriptionController.text.trim().isEmpty,
      clearDurationWeeks: _durationController.text.trim().isEmpty,
      clearPrimaryGoal: _goalController.text.trim().isEmpty,
      clearTargetAthlete: _targetAthleteController.text.trim().isEmpty,
      clearDifficulty: _difficultyController.text.trim().isEmpty,
      clearEquipmentRequirements: _equipmentController.text.trim().isEmpty,
      clearSessionsPerWeek: _sessionsPerWeekController.text.trim().isEmpty,
    );

    await widget.controller.updateMetadata(updated);
    if (mounted) Navigator.pop(context);
  }

  String? _nullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
