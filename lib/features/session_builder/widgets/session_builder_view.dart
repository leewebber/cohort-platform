import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../../models/exercise.dart';
import '../../../models/protocol_draft.dart';
import '../../../models/protocol_metadata_vocabulary.dart';
import '../controllers/session_builder_editing_state.dart';
import '../models/session_builder_constants.dart';
import '../models/session_builder_display_context.dart';
import 'session_builder_form_widgets.dart';
import 'session_builder_step_editor_card.dart';

/// Route-independent shared authoring presentation for Protocol/Session drafts.
///
/// No Supabase, no Navigator, no save/publish — hosts provide callbacks.
class SessionBuilderView extends StatefulWidget {
  const SessionBuilderView({
    super.key,
    required this.draft,
    required this.exercises,
    required this.displayContext,
    required this.capabilities,
    required this.onDraftChanged,
    this.validationMessages = const [],
    this.protocolIdLocked = false,
  });

  final ProtocolDraft draft;
  final List<Exercise> exercises;
  final SessionBuilderDisplayContext displayContext;
  final SessionBuilderCapabilities capabilities;
  final ValueChanged<ProtocolDraft> onDraftChanged;
  final List<String> validationMessages;
  final bool protocolIdLocked;

  @override
  State<SessionBuilderView> createState() => _SessionBuilderViewState();
}

class _SessionBuilderViewState extends State<SessionBuilderView> {
  late SessionBuilderEditingState _editing;
  late final TextEditingController _protocolIdController;
  late final TextEditingController _nameController;
  late final TextEditingController _durationMinController;

  @override
  void initState() {
    super.initState();
    _editing = SessionBuilderEditingState(draft: widget.draft);
    _protocolIdController =
        TextEditingController(text: _editing.protocolId);
    _nameController = TextEditingController(text: _editing.name);
    _durationMinController = TextEditingController(
      text: _editing.durationMin?.toString() ?? '',
    );
    _protocolIdController.addListener(_syncTextFieldsToDraft);
    _nameController.addListener(_syncTextFieldsToDraft);
    _durationMinController.addListener(_syncTextFieldsToDraft);
  }

  void _syncTextFieldsToDraft() {
    _editing.protocolId = _protocolIdController.text;
    _editing.name = _nameController.text;
    _editing.durationMin =
        int.tryParse(_durationMinController.text.trim());
    _emitDraft();
  }

  @override
  void dispose() {
    _protocolIdController.removeListener(_syncTextFieldsToDraft);
    _nameController.removeListener(_syncTextFieldsToDraft);
    _durationMinController.removeListener(_syncTextFieldsToDraft);
    _protocolIdController.dispose();
    _nameController.dispose();
    _durationMinController.dispose();
    super.dispose();
  }

  void _emitDraft() {
    widget.onDraftChanged(_editing.buildDraft());
  }

  void _setStateAndEmit(VoidCallback fn) {
    setState(fn);
    _emitDraft();
  }

  @override
  Widget build(BuildContext context) {
    final display = widget.displayContext;
    final capabilities = widget.capabilities;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (display.programmeLocationLabel != null) ...[
          Text(
            display.programmeLocationLabel!,
            style: CohortTextStyles.body.copyWith(
              color: CohortColors.textSecondary,
            ),
          ),
          const SizedBox(height: CohortSpacing.md),
        ],
        SessionBuilderSection(
          title: display.detailsSectionTitle,
          child: CohortCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (capabilities.showProtocolIdField) ...[
                  SessionBuilderTextField(
                    label: display.useCoachFacingTerminology
                        ? 'Session code'
                        : 'protocol_id',
                    controller: _protocolIdController,
                    readOnly: !capabilities.allowProtocolIdEdit ||
                        widget.protocolIdLocked,
                  ),
                ],
                SessionBuilderTextField(
                  label: display.nameFieldLabel,
                  controller: _nameController,
                ),
                SessionBuilderDropdown(
                  label: display.sessionFormatFieldLabel,
                  value: _editing.sessionFormat,
                  options: SessionBuilderConstants.sessionFormats,
                  onChanged: (value) => _setStateAndEmit(
                    () => _editing.sessionFormat = value,
                  ),
                ),
                if (capabilities.showCohortMetadataFields) ...[
                  SessionBuilderDropdown(
                    label: 'session_type',
                    value: _editing.sessionType,
                    options: ProtocolMetadataVocabulary.optionsWithCurrent(
                      _editing.sessionType,
                      ProtocolMetadataVocabulary.sessionTypes,
                    ),
                    onChanged: (value) => _setStateAndEmit(
                      () => _editing.sessionType = value,
                    ),
                  ),
                  SessionBuilderDropdown(
                    label: 'primary_capability',
                    value: _editing.primaryCapability,
                    options: ProtocolMetadataVocabulary.optionsWithCurrent(
                      _editing.primaryCapability,
                      ProtocolMetadataVocabulary.primaryCapabilities,
                    ),
                    onChanged: (value) => _setStateAndEmit(
                      () => _editing.primaryCapability = value,
                    ),
                  ),
                  SessionBuilderDropdown(
                    label: 'secondary_capability',
                    value: _editing.secondaryCapability,
                    options: ProtocolMetadataVocabulary
                        .secondaryCapabilityOptionsWithCurrent(
                      _editing.secondaryCapability,
                    ),
                    onChanged: (value) => _setStateAndEmit(
                      () => _editing.secondaryCapability = value,
                    ),
                  ),
                ],
                SessionBuilderTextField(
                  label: display.durationFieldLabel,
                  controller: _durationMinController,
                  keyboardType: TextInputType.number,
                ),
                if (capabilities.showCohortMetadataFields) ...[
                  SessionBuilderDropdown(
                    label: 'physiological_demand',
                    value: _editing.physiologicalDemand,
                    options: ProtocolMetadataVocabulary.optionsWithCurrent(
                      _editing.physiologicalDemand,
                      ProtocolMetadataVocabulary.physiologicalDemands,
                    ),
                    onChanged: (value) => _setStateAndEmit(
                      () => _editing.physiologicalDemand = value,
                    ),
                  ),
                  SessionBuilderDropdown(
                    label: 'recovery_cost',
                    value: _editing.recoveryCost,
                    options: ProtocolMetadataVocabulary.optionsWithCurrent(
                      _editing.recoveryCost,
                      ProtocolMetadataVocabulary.recoveryCosts,
                    ),
                    onChanged: (value) => _setStateAndEmit(
                      () => _editing.recoveryCost = value,
                    ),
                  ),
                  SessionBuilderDropdown(
                    label: 'technical_complexity',
                    value: _editing.technicalComplexity,
                    options: ProtocolMetadataVocabulary.optionsWithCurrent(
                      _editing.technicalComplexity,
                      ProtocolMetadataVocabulary.technicalComplexities,
                    ),
                    onChanged: (value) => _setStateAndEmit(
                      () => _editing.technicalComplexity = value,
                    ),
                  ),
                  SessionBuilderDropdown(
                    label: 'environment',
                    value: _editing.environment,
                    options: ProtocolMetadataVocabulary.optionsWithCurrent(
                      _editing.environment,
                      ProtocolMetadataVocabulary.environments,
                    ),
                    onChanged: (value) => _setStateAndEmit(
                      () => _editing.environment = value,
                    ),
                  ),
                  SessionBuilderChecklist(
                    label: 'required_equipment',
                    selected: _editing.selectedRequiredEquipment,
                    options: ProtocolMetadataVocabulary
                        .requiredEquipmentOptionsWithCurrent(
                      ProtocolMetadataVocabulary.formatCommaSeparated(
                        _editing.selectedRequiredEquipment,
                        ProtocolMetadataVocabulary.equipment,
                      ),
                    ),
                    onChanged: (value, isSelected) => _setStateAndEmit(() {
                      if (isSelected) {
                        _editing.selectedRequiredEquipment.add(value);
                      } else {
                        _editing.selectedRequiredEquipment.remove(value);
                      }
                    }),
                  ),
                  SessionBuilderChecklist(
                    label: 'optional_equipment',
                    selected: _editing.selectedOptionalEquipment,
                    options: ProtocolMetadataVocabulary
                        .optionalEquipmentOptionsWithCurrent(
                      ProtocolMetadataVocabulary.formatCommaSeparated(
                        _editing.selectedOptionalEquipment,
                        ProtocolMetadataVocabulary.equipment,
                      ),
                    ),
                    onChanged: (value, isSelected) => _setStateAndEmit(() {
                      if (isSelected) {
                        _editing.selectedOptionalEquipment.add(value);
                      } else {
                        _editing.selectedOptionalEquipment.remove(value);
                      }
                    }),
                  ),
                  SessionBuilderChecklist(
                    label: 'suitable_for',
                    selected: _editing.selectedSuitableFor,
                    options: ProtocolMetadataVocabulary
                        .suitableForOptionsWithCurrent(
                      ProtocolMetadataVocabulary.formatCommaSeparated(
                        _editing.selectedSuitableFor,
                        ProtocolMetadataVocabulary.suitableFor,
                      ),
                    ),
                    onChanged: (value, isSelected) => _setStateAndEmit(() {
                      if (isSelected) {
                        _editing.selectedSuitableFor.add(value);
                      } else {
                        _editing.selectedSuitableFor.remove(value);
                      }
                    }),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: CohortSpacing.xl),
        SessionBuilderSection(
          title: display.stepsSectionTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_editing.steps.isEmpty)
                Text(
                  display.useCoachFacingTerminology
                      ? 'No blocks yet. Add your first exercise or instruction.'
                      : 'No steps yet. Add the first movement or instruction.',
                  style: CohortTextStyles.body,
                ),
              for (var index = 0; index < _editing.steps.length; index++) ...[
                if (index > 0) const SizedBox(height: CohortSpacing.md),
                SessionBuilderStepEditorCard(
                  key: ValueKey(_editing.steps[index].localId),
                  step: _editing.steps[index],
                  exercises: widget.exercises,
                  useCoachLabels: display.useCoachFacingTerminology,
                  canMoveUp: index > 0,
                  canMoveDown: index < _editing.steps.length - 1,
                  onChanged: (updated) => _setStateAndEmit(
                    () => _editing.updateStep(updated),
                  ),
                  onTitleCustomised: () => _editing.markTitleCustomised(
                    _editing.steps[index].localId,
                  ),
                  onExerciseSelected: (exercise, currentTitle) {
                    _setStateAndEmit(
                      () => _editing.onExerciseSelected(
                        localId: _editing.steps[index].localId,
                        exercise: exercise,
                        currentTitle: currentTitle,
                      ),
                    );
                  },
                  onMoveUp: () => _setStateAndEmit(
                    () => _editing.moveStep(_editing.steps[index].localId, -1),
                  ),
                  onMoveDown: () => _setStateAndEmit(
                    () => _editing.moveStep(_editing.steps[index].localId, 1),
                  ),
                  onDelete: () => _setStateAndEmit(
                    () => _editing.deleteStep(_editing.steps[index].localId),
                  ),
                ),
              ],
              const SizedBox(height: CohortSpacing.lg),
              CohortButton(
                label: display.addStepLabel,
                onPressed: () => _setStateAndEmit(_editing.addStep),
              ),
            ],
          ),
        ),
        if (widget.validationMessages.isNotEmpty) ...[
          const SizedBox(height: CohortSpacing.xl),
          CohortCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Validation',
                  style: CohortTextStyles.eyebrow.copyWith(
                    color: CohortColors.warning,
                  ),
                ),
                const SizedBox(height: CohortSpacing.sm),
                for (final message in widget.validationMessages)
                  Padding(
                    padding: const EdgeInsets.only(bottom: CohortSpacing.xs),
                    child: Text(message, style: CohortTextStyles.body),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
