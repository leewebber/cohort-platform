import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/text_styles.dart';
import '../../core/widgets/cohort_button.dart';
import '../../core/widgets/cohort_card.dart';
import '../../core/widgets/section_title.dart';
import '../../data/repositories/exercise_repository.dart';
import '../../models/exercise.dart';
import '../../models/protocol_builder_save_result.dart';
import '../../models/protocol_draft.dart';
import '../../models/protocol_metadata_vocabulary.dart';
import '../../models/protocol_step_draft.dart';
import 'services/protocol_builder_service.dart';

/// Coach-facing protocol authoring screen.
///
/// See `07 Documentation/34_Protocol_Builder.md`. Save persists via
/// [ProtocolBuilderService]; preview remains in-memory only.
class ProtocolBuilderScreen extends StatefulWidget {
  const ProtocolBuilderScreen({
    super.key,
    this.protocolId,
  });

  final String? protocolId;

  @override
  State<ProtocolBuilderScreen> createState() => _ProtocolBuilderScreenState();
}

class _ProtocolBuilderScreenState extends State<ProtocolBuilderScreen> {
  static const _sessionFormats = [
    'circuit',
    'structured_strength',
    'intervals',
    'recovery_flow',
  ];

  static const _stepTypes = [
    'Exercise',
    'Rest',
    'Run',
    'Instruction',
    'Superset',
    'Circuit',
  ];

  static const _displayStyles = [
    'exercise',
    'instruction',
    'rest',
    'run',
  ];

  static const _sections = [
    'Warm Up',
    'Main Set',
    'Accessory',
    'Cool Down',
  ];

  final _exerciseRepository = ExerciseRepository();
  final _builderService = ProtocolBuilderService();
  final _protocolIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _durationMinController = TextEditingController();

  late final Future<List<Exercise>> _bootstrapFuture;

  String? _sessionFormat;
  String? _sessionType;
  String? _primaryCapability;
  String? _secondaryCapability;
  String? _physiologicalDemand;
  String? _recoveryCost;
  String? _technicalComplexity;
  String? _environment;
  Set<String> _selectedRequiredEquipment = {};
  Set<String> _selectedOptionalEquipment = {};
  Set<String> _selectedSuitableFor = {};

  List<ProtocolStepDraft> _steps = [];
  final Set<String> _customisedTitles = {};

  List<String> _validationMessages = [];
  bool _isSaving = false;
  bool _isPublishing = false;
  bool _protocolIdLocked = false;
  ProtocolBuilderSaveResult? _saveSuccessResult;
  String? _saveErrorMessage;

  bool get _isBusy => _isSaving || _isPublishing;

  @override
  void initState() {
    super.initState();
    _protocolIdLocked = widget.protocolId != null;
    _bootstrapFuture = _loadBootstrap();
  }

  Future<List<Exercise>> _loadBootstrap() async {
    final exercises = await _exerciseRepository.getExercises();

    if (widget.protocolId != null) {
      final draft = await _builderService.loadDraft(widget.protocolId!);
      if (mounted) {
        setState(() => _applyDraft(draft));
      }
    }

    return exercises;
  }

  void _applyDraft(ProtocolDraft draft) {
    _protocolIdController.text = draft.protocolId;
    _nameController.text = draft.name;
    _durationMinController.text =
        draft.durationMin?.toString() ?? '';
    _sessionFormat = draft.sessionFormat;
    _sessionType = draft.sessionType;
    _primaryCapability = draft.primaryCapability;
    _secondaryCapability = draft.secondaryCapability;
    _physiologicalDemand = draft.physiologicalDemand;
    _recoveryCost = draft.recoveryCost;
    _technicalComplexity = draft.technicalComplexity;
    _environment = draft.environment;
    _selectedRequiredEquipment = ProtocolMetadataVocabulary.parseCommaSeparated(
      draft.requiredEquipment,
    );
    _selectedOptionalEquipment = ProtocolMetadataVocabulary.parseCommaSeparated(
      draft.optionalEquipment,
    );
    _selectedSuitableFor = ProtocolMetadataVocabulary.parseCommaSeparated(
      draft.suitableFor,
    );
    _steps = List<ProtocolStepDraft>.from(draft.steps);
    _customisedTitles
      ..clear()
      ..addAll(draft.steps.map((step) => step.localId));
    _protocolIdLocked = true;
    _validationMessages = [];
    _saveSuccessResult = null;
    _saveErrorMessage = null;
  }

  @override
  void dispose() {
    _protocolIdController.dispose();
    _nameController.dispose();
    _durationMinController.dispose();
    super.dispose();
  }

  String _newLocalId() {
    return 'step-${DateTime.now().microsecondsSinceEpoch}';
  }

  void _addStep() {
    setState(() {
      final localId = _newLocalId();
      _steps = [
        ..._steps,
        ProtocolStepDraft(
          localId: localId,
          stepOrder: _steps.length + 1,
          title: 'New Step',
          section: 'Main Set',
          stepType: 'Exercise',
          displayStyle: 'exercise',
        ),
      ];
    });
  }

  void _updateStep(ProtocolStepDraft updated) {
    setState(() {
      _steps = _steps
          .map((step) => step.localId == updated.localId ? updated : step)
          .toList();
    });
  }

  void _deleteStep(String localId) {
    setState(() {
      _steps = _steps.where((step) => step.localId != localId).toList();
      _customisedTitles.remove(localId);
      _renumberSteps();
    });
  }

  void _moveStep(String localId, int direction) {
    final index = _steps.indexWhere((step) => step.localId == localId);
    if (index < 0) return;

    final targetIndex = index + direction;
    if (targetIndex < 0 || targetIndex >= _steps.length) return;

    setState(() {
      final reordered = List<ProtocolStepDraft>.from(_steps);
      final item = reordered.removeAt(index);
      reordered.insert(targetIndex, item);
      _steps = reordered;
      _renumberSteps();
    });
  }

  void _renumberSteps() {
    _steps = [
      for (var i = 0; i < _steps.length; i++)
        _steps[i].copyWith(stepOrder: i + 1),
    ];
  }

  void _markTitleCustomised(String localId) {
    _customisedTitles.add(localId);
  }

  void _onExerciseSelected({
    required String localId,
    required Exercise? exercise,
    required String currentTitle,
  }) {
    final index = _steps.indexWhere((step) => step.localId == localId);
    if (index < 0) return;

    final step = _steps[index];
    final titleCustomised = _customisedTitles.contains(localId);
    final nextTitle = exercise == null
        ? step.title
        : titleCustomised
            ? currentTitle
            : exercise.name;

    _updateStep(
      ProtocolStepDraft(
        localId: step.localId,
        persistedId: step.persistedId,
        stepOrder: step.stepOrder,
        section: step.section,
        stepType: step.stepType,
        displayStyle: step.displayStyle,
        exerciseId: exercise?.exerciseId,
        title: nextTitle,
        notes: step.notes,
        sets: step.sets,
        reps: step.reps,
        distance: step.distance,
        duration: step.duration,
        rest: step.rest,
        tempo: step.tempo,
        load: step.load,
      ),
    );
  }

  ProtocolDraft _buildDraft() {
    return ProtocolDraft(
      protocolId: _protocolIdController.text.trim(),
      name: _nameController.text.trim(),
      sessionFormat: _sessionFormat,
      sessionType: _sessionType,
      primaryCapability: _primaryCapability,
      secondaryCapability: _secondaryCapability,
      durationMin: int.tryParse(_durationMinController.text.trim()),
      physiologicalDemand: _physiologicalDemand,
      recoveryCost: _recoveryCost,
      technicalComplexity: _technicalComplexity,
      environment: _environment,
      requiredEquipment: ProtocolMetadataVocabulary.formatCommaSeparated(
        _selectedRequiredEquipment,
        ProtocolMetadataVocabulary.equipment,
      ),
      optionalEquipment: ProtocolMetadataVocabulary.formatCommaSeparated(
        _selectedOptionalEquipment,
        ProtocolMetadataVocabulary.equipment,
      ),
      suitableFor: ProtocolMetadataVocabulary.formatCommaSeparated(
        _selectedSuitableFor,
        ProtocolMetadataVocabulary.suitableFor,
      ),
      steps: _steps,
    );
  }

  List<String> _validateDraft() {
    final messages = <String>[];

    if (_protocolIdController.text.trim().isEmpty) {
      messages.add('Protocol ID is required.');
    }

    if (_nameController.text.trim().isEmpty) {
      messages.add('Protocol name is required.');
    }

    if (_sessionFormat == null || _sessionFormat!.trim().isEmpty) {
      messages.add('Session format is required.');
    }

    if (_steps.isEmpty) {
      messages.add('Add at least one session step.');
    }

    return messages;
  }

  void _saveDraft() async {
    if (_isBusy) return;

    setState(() {
      _isSaving = true;
      _validationMessages = [];
      _saveSuccessResult = null;
      _saveErrorMessage = null;
    });

    try {
      final result = await _builderService.saveDraft(_buildDraft());

      if (!mounted) return;

      setState(() {
        _saveSuccessResult = result;
        _isSaving = false;
        _protocolIdLocked = true;
      });

      await _showSaveSuccessDialog(result);
    } on ProtocolBuilderException catch (error) {
      if (!mounted) return;

      setState(() {
        _validationMessages = [error.message];
        _isSaving = false;
      });
    } catch (error, stackTrace) {
      debugPrint('[ProtocolBuilder] save failed: $error');
      debugPrint(stackTrace.toString());

      if (!mounted) return;

      setState(() {
        _saveErrorMessage =
            'We could not save your protocol right now. Please try again.';
        _isSaving = false;
      });
    }
  }

  void _publishDraft() async {
    if (_isBusy) return;

    setState(() {
      _isPublishing = true;
      _validationMessages = [];
      _saveSuccessResult = null;
      _saveErrorMessage = null;
    });

    try {
      final result = await _builderService.publishDraft(_buildDraft());

      if (!mounted) return;

      setState(() {
        _saveSuccessResult = result;
        _isPublishing = false;
        _protocolIdLocked = true;
      });

      await _showPublishSuccessDialog(result);
    } on ProtocolBuilderException catch (error) {
      if (!mounted) return;

      setState(() {
        _validationMessages = [error.message];
        _isPublishing = false;
      });
    } catch (error, stackTrace) {
      debugPrint('[ProtocolBuilder] publish failed: $error');
      debugPrint(stackTrace.toString());

      if (!mounted) return;

      setState(() {
        _saveErrorMessage =
            'We could not publish your protocol right now. Please try again.';
        _isPublishing = false;
      });
    }
  }

  Future<void> _showSaveSuccessDialog(ProtocolBuilderSaveResult result) async {
    final startNewDraft = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: CohortColors.surface,
          title: Text(
            'Draft saved',
            style: CohortTextStyles.h2,
          ),
          content: Text(
            '${result.message}\n\nStart a new draft?',
            style: CohortTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Keep editing',
                style: CohortTextStyles.body.copyWith(
                  color: CohortColors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'New draft',
                style: CohortTextStyles.body.copyWith(
                  color: CohortColors.olive,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (startNewDraft == true && mounted) {
      _clearDraft();
    }
  }

  Future<void> _showPublishSuccessDialog(
    ProtocolBuilderSaveResult result,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: CohortColors.surface,
          title: Text(
            'Protocol published',
            style: CohortTextStyles.h2,
          ),
          content: Text(
            result.message,
            style: CohortTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Continue',
                style: CohortTextStyles.body.copyWith(
                  color: CohortColors.olive,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _clearDraft() {
    setState(() {
      _protocolIdController.clear();
      _nameController.clear();
      _durationMinController.clear();
      _sessionFormat = null;
      _sessionType = null;
      _primaryCapability = null;
      _secondaryCapability = null;
      _physiologicalDemand = null;
      _recoveryCost = null;
      _technicalComplexity = null;
      _environment = null;
      _selectedRequiredEquipment = {};
      _selectedOptionalEquipment = {};
      _selectedSuitableFor = {};
      _steps = [];
      _customisedTitles.clear();
      _protocolIdLocked = false;
      _validationMessages = [];
      _saveSuccessResult = null;
      _saveErrorMessage = null;
    });
  }

  void _previewDraft() {
    final messages = _validateDraft();
    setState(() => _validationMessages = messages);

    if (messages.isNotEmpty) return;

    final draft = _buildDraft();
    debugPrint('[ProtocolBuilder] preview draft: $draft');
    debugPrint('[ProtocolBuilder] steps: ${draft.steps.length}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<Exercise>>(
          future: _bootstrapFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  widget.protocolId != null
                      ? 'Loading draft...'
                      : 'Loading exercises...',
                  style: CohortTextStyles.body,
                ),
              );
            }

            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('← Back'),
                    ),
                    const SizedBox(height: CohortSpacing.md),
                    Text(
                      snapshot.error is ProtocolBuilderException
                          ? (snapshot.error! as ProtocolBuilderException)
                              .message
                          : 'We could not open this draft right now.',
                      style: CohortTextStyles.body,
                    ),
                  ],
                ),
              );
            }

            final exercises = snapshot.data ?? [];

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('← Back'),
                  ),
                  const SizedBox(height: CohortSpacing.md),
                  const SectionTitle('Coach Studio'),
                  const SizedBox(height: CohortSpacing.md),
                  const Text(
                    'Protocol Builder',
                    style: CohortTextStyles.h1,
                  ),
                  const SizedBox(height: CohortSpacing.sm),
                  const Text(
                    'Create structured sessions with metadata and ordered steps. '
                    'Save keeps unpublished drafts; publish makes them live.',
                    style: CohortTextStyles.body,
                  ),
                  const SizedBox(height: CohortSpacing.xl),
                  _BuilderSection(
                    title: 'Protocol Details',
                    child: CohortCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _BuilderTextField(
                            label: 'protocol_id',
                            controller: _protocolIdController,
                            readOnly: _protocolIdLocked,
                          ),
                          _BuilderTextField(
                            label: 'name',
                            controller: _nameController,
                          ),
                          _BuilderDropdown(
                            label: 'session_format',
                            value: _sessionFormat,
                            options: _sessionFormats,
                            onChanged: (value) =>
                                setState(() => _sessionFormat = value),
                          ),
                          _BuilderDropdown(
                            label: 'session_type',
                            value: _sessionType,
                            options: ProtocolMetadataVocabulary.optionsWithCurrent(
                              _sessionType,
                              ProtocolMetadataVocabulary.sessionTypes,
                            ),
                            onChanged: (value) =>
                                setState(() => _sessionType = value),
                          ),
                          _BuilderDropdown(
                            label: 'primary_capability',
                            value: _primaryCapability,
                            options: ProtocolMetadataVocabulary.optionsWithCurrent(
                              _primaryCapability,
                              ProtocolMetadataVocabulary.primaryCapabilities,
                            ),
                            onChanged: (value) =>
                                setState(() => _primaryCapability = value),
                          ),
                          _BuilderDropdown(
                            label: 'secondary_capability',
                            value: _secondaryCapability,
                            options: ProtocolMetadataVocabulary
                                .secondaryCapabilityOptionsWithCurrent(
                              _secondaryCapability,
                            ),
                            onChanged: (value) =>
                                setState(() => _secondaryCapability = value),
                          ),
                          _BuilderTextField(
                            label: 'duration_min',
                            controller: _durationMinController,
                            keyboardType: TextInputType.number,
                          ),
                          _BuilderDropdown(
                            label: 'physiological_demand',
                            value: _physiologicalDemand,
                            options: ProtocolMetadataVocabulary.optionsWithCurrent(
                              _physiologicalDemand,
                              ProtocolMetadataVocabulary.physiologicalDemands,
                            ),
                            onChanged: (value) =>
                                setState(() => _physiologicalDemand = value),
                          ),
                          _BuilderDropdown(
                            label: 'recovery_cost',
                            value: _recoveryCost,
                            options: ProtocolMetadataVocabulary.optionsWithCurrent(
                              _recoveryCost,
                              ProtocolMetadataVocabulary.recoveryCosts,
                            ),
                            onChanged: (value) =>
                                setState(() => _recoveryCost = value),
                          ),
                          _BuilderDropdown(
                            label: 'technical_complexity',
                            value: _technicalComplexity,
                            options: ProtocolMetadataVocabulary.optionsWithCurrent(
                              _technicalComplexity,
                              ProtocolMetadataVocabulary.technicalComplexities,
                            ),
                            onChanged: (value) =>
                                setState(() => _technicalComplexity = value),
                          ),
                          _BuilderDropdown(
                            label: 'environment',
                            value: _environment,
                            options: ProtocolMetadataVocabulary.optionsWithCurrent(
                              _environment,
                              ProtocolMetadataVocabulary.environments,
                            ),
                            onChanged: (value) =>
                                setState(() => _environment = value),
                          ),
                          _BuilderChecklist(
                            label: 'required_equipment',
                            selected: _selectedRequiredEquipment,
                            options: ProtocolMetadataVocabulary
                                .requiredEquipmentOptionsWithCurrent(
                              ProtocolMetadataVocabulary.formatCommaSeparated(
                                _selectedRequiredEquipment,
                                ProtocolMetadataVocabulary.equipment,
                              ),
                            ),
                            onChanged: (value, isSelected) {
                              setState(() {
                                if (isSelected) {
                                  _selectedRequiredEquipment.add(value);
                                } else {
                                  _selectedRequiredEquipment.remove(value);
                                }
                              });
                            },
                          ),
                          _BuilderChecklist(
                            label: 'optional_equipment',
                            selected: _selectedOptionalEquipment,
                            options: ProtocolMetadataVocabulary
                                .optionalEquipmentOptionsWithCurrent(
                              ProtocolMetadataVocabulary.formatCommaSeparated(
                                _selectedOptionalEquipment,
                                ProtocolMetadataVocabulary.equipment,
                              ),
                            ),
                            onChanged: (value, isSelected) {
                              setState(() {
                                if (isSelected) {
                                  _selectedOptionalEquipment.add(value);
                                } else {
                                  _selectedOptionalEquipment.remove(value);
                                }
                              });
                            },
                          ),
                          _BuilderChecklist(
                            label: 'suitable_for',
                            selected: _selectedSuitableFor,
                            options: ProtocolMetadataVocabulary
                                .suitableForOptionsWithCurrent(
                              ProtocolMetadataVocabulary.formatCommaSeparated(
                                _selectedSuitableFor,
                                ProtocolMetadataVocabulary.suitableFor,
                              ),
                            ),
                            onChanged: (value, isSelected) {
                              setState(() {
                                if (isSelected) {
                                  _selectedSuitableFor.add(value);
                                } else {
                                  _selectedSuitableFor.remove(value);
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: CohortSpacing.xl),
                  _BuilderSection(
                    title: 'Session Steps',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_steps.isEmpty)
                          const Text(
                            'No steps yet. Add the first movement or instruction.',
                            style: CohortTextStyles.body,
                          ),
                        for (var index = 0; index < _steps.length; index++) ...[
                          if (index > 0) const SizedBox(height: CohortSpacing.md),
                          _ProtocolStepEditorCard(
                            key: ValueKey(_steps[index].localId),
                            step: _steps[index],
                            exercises: exercises,
                            stepTypes: _stepTypes,
                            displayStyles: _displayStyles,
                            sections: _sections,
                            canMoveUp: index > 0,
                            canMoveDown: index < _steps.length - 1,
                            onChanged: _updateStep,
                            onTitleCustomised: () =>
                                _markTitleCustomised(_steps[index].localId),
                            onExerciseSelected: (exercise, currentTitle) {
                              _onExerciseSelected(
                                localId: _steps[index].localId,
                                exercise: exercise,
                                currentTitle: currentTitle,
                              );
                            },
                            onMoveUp: () => _moveStep(_steps[index].localId, -1),
                            onMoveDown: () => _moveStep(_steps[index].localId, 1),
                            onDelete: () => _deleteStep(_steps[index].localId),
                          ),
                        ],
                        const SizedBox(height: CohortSpacing.lg),
                        CohortButton(
                          label: 'Add Step',
                          onPressed: _addStep,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: CohortSpacing.xl),
                  if (_saveSuccessResult != null) ...[
                    CohortCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _saveSuccessResult!.published
                                ? 'Published'
                                : 'Draft saved',
                            style: CohortTextStyles.eyebrow.copyWith(
                              color: CohortColors.success,
                            ),
                          ),
                          const SizedBox(height: CohortSpacing.sm),
                          Text(
                            _saveSuccessResult!.message,
                            style: CohortTextStyles.body,
                          ),
                          const SizedBox(height: CohortSpacing.xs),
                          Text(
                            'Protocol ID: ${_saveSuccessResult!.protocolId}',
                            style: CohortTextStyles.small,
                          ),
                          Text(
                            'Steps saved: ${_saveSuccessResult!.stepCount}',
                            style: CohortTextStyles.small,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: CohortSpacing.lg),
                  ],
                  if (_saveErrorMessage != null) ...[
                    CohortCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Save failed',
                            style: CohortTextStyles.eyebrow.copyWith(
                              color: CohortColors.danger,
                            ),
                          ),
                          const SizedBox(height: CohortSpacing.sm),
                          Text(
                            _saveErrorMessage!,
                            style: CohortTextStyles.body,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: CohortSpacing.lg),
                  ],
                  if (_validationMessages.isNotEmpty) ...[
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
                          for (final message in _validationMessages)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: CohortSpacing.xs,
                              ),
                              child: Text(
                                message,
                                style: CohortTextStyles.body,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: CohortSpacing.lg),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CohortButton(
                              label: _isSaving ? 'Saving...' : 'Save Draft',
                              onPressed: _isBusy ? () {} : _saveDraft,
                            ),
                            if (_isSaving)
                              const Positioned(
                                right: CohortSpacing.lg,
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: CohortColors.background,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: CohortSpacing.md),
                      Expanded(
                        child: CohortButton(
                          label: 'Preview',
                          onPressed: _isBusy ? () {} : _previewDraft,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: CohortSpacing.md),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      CohortButton(
                        label: _isPublishing ? 'Publishing...' : 'Publish',
                        onPressed: _isBusy ? () {} : _publishDraft,
                      ),
                      if (_isPublishing)
                        const Positioned(
                          right: CohortSpacing.lg,
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: CohortColors.background,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BuilderSection extends StatelessWidget {
  const _BuilderSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title),
        const SizedBox(height: CohortSpacing.md),
        child,
      ],
    );
  }
}

class _BuilderTextField extends StatelessWidget {
  const _BuilderTextField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.readOnly = false,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: CohortTextStyles.eyebrow),
          const SizedBox(height: CohortSpacing.xs),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            readOnly: readOnly,
            style: CohortTextStyles.body.copyWith(
              color: readOnly
                  ? CohortColors.textSecondary
                  : CohortColors.textPrimary,
            ),
            decoration: const InputDecoration(
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _BuilderDropdown extends StatelessWidget {
  const _BuilderDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  String? _resolvedValue() {
    if (value == null) return null;
    if (options.contains(value)) return value;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: CohortTextStyles.eyebrow),
          const SizedBox(height: CohortSpacing.xs),
          DropdownButton<String>(
            isExpanded: true,
            isDense: true,
            value: _resolvedValue(),
            style: CohortTextStyles.small,
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('—', style: CohortTextStyles.small),
              ),
              ...options.map(
                (option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(option, style: CohortTextStyles.small),
                ),
              ),
            ],
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _BuilderChecklist extends StatelessWidget {
  const _BuilderChecklist({
    required this.label,
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final Set<String> selected;
  final List<String> options;
  final void Function(String value, bool isSelected) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: CohortTextStyles.eyebrow),
          const SizedBox(height: CohortSpacing.xs),
          for (final option in options)
            _BuilderCheckbox(
              label: option,
              value: selected.contains(option),
              onChanged: (isSelected) => onChanged(option, isSelected),
            ),
        ],
      ),
    );
  }
}

class _BuilderCheckbox extends StatelessWidget {
  const _BuilderCheckbox({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          SizedBox(
            height: 36,
            width: 36,
            child: Checkbox(
              value: value,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              activeColor: CohortColors.olive,
              checkColor: CohortColors.textPrimary,
              side: const BorderSide(color: CohortColors.borderStrong),
              onChanged: (isSelected) {
                if (isSelected != null) onChanged(isSelected);
              },
            ),
          ),
          Expanded(
            child: Text(label, style: CohortTextStyles.small),
          ),
        ],
      ),
    );
  }
}

class _ProtocolStepEditorCard extends StatefulWidget {
  const _ProtocolStepEditorCard({
    super.key,
    required this.step,
    required this.exercises,
    required this.stepTypes,
    required this.displayStyles,
    required this.sections,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onChanged,
    required this.onTitleCustomised,
    required this.onExerciseSelected,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
  });

  final ProtocolStepDraft step;
  final List<Exercise> exercises;
  final List<String> stepTypes;
  final List<String> displayStyles;
  final List<String> sections;
  final bool canMoveUp;
  final bool canMoveDown;
  final ValueChanged<ProtocolStepDraft> onChanged;
  final VoidCallback onTitleCustomised;
  final void Function(Exercise? exercise, String currentTitle) onExerciseSelected;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDelete;

  @override
  State<_ProtocolStepEditorCard> createState() =>
      _ProtocolStepEditorCardState();
}

class _ProtocolStepEditorCardState extends State<_ProtocolStepEditorCard> {
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
  void didUpdateWidget(covariant _ProtocolStepEditorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
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
                  'STEP ${widget.step.stepOrder}',
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
          _BuilderDropdown(
            label: 'section',
            value: widget.step.section,
            options: widget.sections,
            onChanged: (value) => _emitChanged(section: value),
          ),
          _BuilderDropdown(
            label: 'step_type',
            value: widget.step.stepType,
            options: widget.stepTypes,
            onChanged: (value) => _emitChanged(stepType: value),
          ),
          _BuilderDropdown(
            label: 'display_style',
            value: widget.step.displayStyle,
            options: widget.displayStyles,
            onChanged: (value) => _emitChanged(displayStyle: value),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: CohortSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('exercise', style: CohortTextStyles.eyebrow),
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
                          '${exercise.name} (${exercise.exerciseId})',
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
          _StepTextField(
            label: 'title',
            controller: _titleController,
            onChanged: (value) {
              widget.onTitleCustomised();
              _emitChanged(title: value);
            },
          ),
          Row(
            children: [
              Expanded(
                child: _StepTextField(
                  label: 'sets',
                  controller: _setsController,
                  onChanged: (_) => _emitChanged(),
                ),
              ),
              const SizedBox(width: CohortSpacing.md),
              Expanded(
                child: _StepTextField(
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
                child: _StepTextField(
                  label: 'distance',
                  controller: _distanceController,
                  onChanged: (_) => _emitChanged(),
                ),
              ),
              const SizedBox(width: CohortSpacing.md),
              Expanded(
                child: _StepTextField(
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
                child: _StepTextField(
                  label: 'rest',
                  controller: _restController,
                  onChanged: (_) => _emitChanged(),
                ),
              ),
              const SizedBox(width: CohortSpacing.md),
              Expanded(
                child: _StepTextField(
                  label: 'tempo',
                  controller: _tempoController,
                  onChanged: (_) => _emitChanged(),
                ),
              ),
            ],
          ),
          _StepTextField(
            label: 'load',
            controller: _loadController,
            onChanged: (_) => _emitChanged(),
          ),
          _StepTextField(
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

class _StepTextField extends StatelessWidget {
  const _StepTextField({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: CohortTextStyles.eyebrow),
          const SizedBox(height: CohortSpacing.xs),
          TextField(
            controller: controller,
            maxLines: maxLines,
            style: CohortTextStyles.body,
            onChanged: onChanged,
            decoration: const InputDecoration(isDense: true),
          ),
        ],
      ),
    );
  }
}
