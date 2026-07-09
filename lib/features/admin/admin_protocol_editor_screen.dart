import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/text_styles.dart';
import '../../core/widgets/cohort_button.dart';
import '../../core/widgets/cohort_card.dart';
import '../../core/widgets/protocol_card.dart';
import '../../core/widgets/section_title.dart';
import '../../data/repositories/protocol_repository.dart';
import '../../models/protocol.dart';
import '../../models/protocol_metadata_update.dart';
import '../../models/protocol_metadata_vocabulary.dart';

class AdminProtocolEditorScreen extends StatefulWidget {
  const AdminProtocolEditorScreen({super.key});

  @override
  State<AdminProtocolEditorScreen> createState() =>
      _AdminProtocolEditorScreenState();
}

class _AdminProtocolEditorScreenState extends State<AdminProtocolEditorScreen> {
  final _repository = ProtocolRepository();

  late Future<List<Protocol>> _protocolsFuture;
  Protocol? _selectedProtocol;
  bool _isSaving = false;

  String? _primaryCapability;
  String? _sessionType;
  String? _environment;
  String? _physiologicalDemand;
  String? _recoveryCost;
  String? _durationCategory;
  String? _technicalComplexity;
  String? _secondaryCapability;
  int? _adaptability;
  bool? _runningRequired;
  bool? _runningReplaceable;
  bool? _hotelFriendly;
  bool? _indoorFriendly;
  bool? _noiseFriendly;
  Set<String> _selectedEquipment = {};
  Set<String> _selectedRequiredEquipment = {};
  Set<String> _selectedOptionalEquipment = {};
  Set<String> _selectedSuitableFor = {};

  final _durationMinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _protocolsFuture = _repository.getProtocols();
  }

  @override
  void dispose() {
    _durationMinController.dispose();
    super.dispose();
  }

  void _selectProtocol(Protocol protocol) {
    setState(() {
      _selectedProtocol = protocol;
      _primaryCapability = protocol.goal;
      _sessionType = protocol.sessionType;
      _environment = protocol.environment;
      _physiologicalDemand = protocol.demand;
      _recoveryCost = protocol.recovery;
      _durationCategory = protocol.durationCategory;
      _technicalComplexity = protocol.technicalComplexity;
      _secondaryCapability = protocol.secondaryCapability;
      _adaptability = protocol.adaptability;
      _runningRequired = protocol.runningRequired;
      _runningReplaceable = protocol.runningReplaceable;
      _hotelFriendly = protocol.hotelFriendly;
      _indoorFriendly = protocol.indoorFriendly;
      _noiseFriendly = protocol.noiseFriendly;
      _selectedEquipment =
          ProtocolMetadataVocabulary.parseCommaSeparated(protocol.equipment);
      _selectedRequiredEquipment = ProtocolMetadataVocabulary.parseCommaSeparated(
        protocol.requiredEquipment,
      );
      _selectedOptionalEquipment = ProtocolMetadataVocabulary.parseCommaSeparated(
        protocol.optionalEquipment,
      );
      _selectedSuitableFor =
          ProtocolMetadataVocabulary.parseCommaSeparated(protocol.suitableFor);
      _durationMinController.text = protocol.durationMin?.toString() ?? '';
    });
  }

  void _clearSelection() {
    setState(() => _selectedProtocol = null);
  }

  Future<void> _saveProtocol() async {
    final protocol = _selectedProtocol;
    if (protocol == null || _isSaving) return;

    final durationMin = int.tryParse(_durationMinController.text.trim());

    setState(() => _isSaving = true);

    try {
      final updatedProtocol = await _repository.updateProtocol(
        protocolId: protocol.protocolId,
        metadata: ProtocolMetadataUpdate(
          primaryCapability: _primaryCapability,
          sessionType: _sessionType,
          equipment: ProtocolMetadataVocabulary.formatCommaSeparated(
            _selectedEquipment,
            ProtocolMetadataVocabulary.equipment,
          ),
          environment: _environment,
          physiologicalDemand: _physiologicalDemand,
          recoveryCost: _recoveryCost,
          durationMin: durationMin,
          durationCategory: _durationCategory,
          technicalComplexity: _technicalComplexity,
          suitableFor: ProtocolMetadataVocabulary.formatCommaSeparated(
            _selectedSuitableFor,
            ProtocolMetadataVocabulary.suitableFor,
          ),
          secondaryCapability: _secondaryCapability,
          requiredEquipment: ProtocolMetadataVocabulary.formatCommaSeparated(
            _selectedRequiredEquipment,
            ProtocolMetadataVocabulary.equipment,
          ),
          optionalEquipment: ProtocolMetadataVocabulary.formatCommaSeparated(
            _selectedOptionalEquipment,
            ProtocolMetadataVocabulary.equipment,
          ),
          adaptability: _adaptability,
          runningRequired: _runningRequired,
          runningReplaceable: _runningReplaceable,
          hotelFriendly: _hotelFriendly,
          indoorFriendly: _indoorFriendly,
          noiseFriendly: _noiseFriendly,
        ),
      );

      if (!mounted) return;

      setState(() {
        _selectedProtocol = updatedProtocol;
        _selectedEquipment = ProtocolMetadataVocabulary.parseCommaSeparated(
          updatedProtocol.equipment,
        );
        _selectedSuitableFor = ProtocolMetadataVocabulary.parseCommaSeparated(
          updatedProtocol.suitableFor,
        );
        _selectedRequiredEquipment =
            ProtocolMetadataVocabulary.parseCommaSeparated(
          updatedProtocol.requiredEquipment,
        );
        _selectedOptionalEquipment =
            ProtocolMetadataVocabulary.parseCommaSeparated(
          updatedProtocol.optionalEquipment,
        );
        _secondaryCapability = updatedProtocol.secondaryCapability;
        _adaptability = updatedProtocol.adaptability;
        _runningRequired = updatedProtocol.runningRequired;
        _runningReplaceable = updatedProtocol.runningReplaceable;
        _hotelFriendly = updatedProtocol.hotelFriendly;
        _indoorFriendly = updatedProtocol.indoorFriendly;
        _noiseFriendly = updatedProtocol.noiseFriendly;
        _protocolsFuture = _repository.getProtocols();
      });

      debugPrint(
        '[Admin] saved protocol metadata for ${updatedProtocol.protocolId}',
      );
    } catch (error, stackTrace) {
      debugPrint('[Admin] save failed: $error');
      debugPrint('[Admin] stackTrace: $stackTrace');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _selectedProtocol == null
            ? _buildProtocolList()
            : _buildEditor(),
      ),
    );
  }

  Widget _buildProtocolList() {
    return FutureBuilder<List<Protocol>>(
      future: _protocolsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Loading protocols...',
              style: CohortTextStyles.body,
            ),
          );
        }

        final protocols = snapshot.data ?? [];

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
              const SectionTitle('Admin'),
              const SizedBox(height: CohortSpacing.md),
              const Text(
                'Protocol Editor',
                style: CohortTextStyles.h1,
              ),
              const SizedBox(height: CohortSpacing.lg),
              const Text(
                'Select a protocol to edit adaptation metadata.',
                style: CohortTextStyles.body,
              ),
              const SizedBox(height: CohortSpacing.xl),
              for (final protocol in protocols) ...[
                ProtocolCard(
                  protocol: protocol,
                  onTap: () => _selectProtocol(protocol),
                ),
                const SizedBox(height: CohortSpacing.md),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildEditor() {
    final protocol = _selectedProtocol!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final useSideBySide = constraints.maxWidth >= 760;

        final metadataEditor = _MetadataEditorSection(
          protocol: protocol,
          primaryCapability: _primaryCapability,
          sessionType: _sessionType,
          environment: _environment,
          physiologicalDemand: _physiologicalDemand,
          recoveryCost: _recoveryCost,
          durationCategory: _durationCategory,
          technicalComplexity: _technicalComplexity,
          secondaryCapability: _secondaryCapability,
          adaptability: _adaptability,
          runningRequired: _runningRequired,
          runningReplaceable: _runningReplaceable,
          hotelFriendly: _hotelFriendly,
          indoorFriendly: _indoorFriendly,
          noiseFriendly: _noiseFriendly,
          selectedEquipment: _selectedEquipment,
          selectedRequiredEquipment: _selectedRequiredEquipment,
          selectedOptionalEquipment: _selectedOptionalEquipment,
          selectedSuitableFor: _selectedSuitableFor,
          durationMinController: _durationMinController,
          onPrimaryCapabilityChanged: (value) =>
              setState(() => _primaryCapability = value),
          onSecondaryCapabilityChanged: (value) =>
              setState(() => _secondaryCapability = value),
          onSessionTypeChanged: (value) =>
              setState(() => _sessionType = value),
          onEnvironmentChanged: (value) => setState(() => _environment = value),
          onPhysiologicalDemandChanged: (value) =>
              setState(() => _physiologicalDemand = value),
          onRecoveryCostChanged: (value) =>
              setState(() => _recoveryCost = value),
          onDurationCategoryChanged: (value) =>
              setState(() => _durationCategory = value),
          onTechnicalComplexityChanged: (value) =>
              setState(() => _technicalComplexity = value),
          onAdaptabilityChanged: (value) =>
              setState(() => _adaptability = value),
          onRunningRequiredChanged: (value) =>
              setState(() => _runningRequired = value),
          onRunningReplaceableChanged: (value) =>
              setState(() => _runningReplaceable = value),
          onHotelFriendlyChanged: (value) =>
              setState(() => _hotelFriendly = value),
          onIndoorFriendlyChanged: (value) =>
              setState(() => _indoorFriendly = value),
          onNoiseFriendlyChanged: (value) =>
              setState(() => _noiseFriendly = value),
          onEquipmentChanged: (value, isSelected) {
            setState(() {
              if (isSelected) {
                _selectedEquipment.add(value);
              } else {
                _selectedEquipment.remove(value);
              }
            });
          },
          onRequiredEquipmentChanged: (value, isSelected) {
            setState(() {
              if (isSelected) {
                _selectedRequiredEquipment.add(value);
              } else {
                _selectedRequiredEquipment.remove(value);
              }
            });
          },
          onOptionalEquipmentChanged: (value, isSelected) {
            setState(() {
              if (isSelected) {
                _selectedOptionalEquipment.add(value);
              } else {
                _selectedOptionalEquipment.remove(value);
              }
            });
          },
          onSuitableForChanged: (value, isSelected) {
            setState(() {
              if (isSelected) {
                _selectedSuitableFor.add(value);
              } else {
                _selectedSuitableFor.remove(value);
              }
            });
          },
        );

        final quickReference = const _MetadataQuickReferenceSection();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton(
                onPressed: _clearSelection,
                child: const Text('← Protocols'),
              ),
              const SizedBox(height: CohortSpacing.sm),
              Text(
                protocol.protocolId,
                style: CohortTextStyles.small,
              ),
              const SizedBox(height: CohortSpacing.lg),
              _WorkoutSummarySection(protocol: protocol),
              if (useSideBySide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: metadataEditor),
                    const SizedBox(width: CohortSpacing.lg),
                    Expanded(flex: 2, child: quickReference),
                  ],
                )
              else ...[
                metadataEditor,
                quickReference,
              ],
              const SizedBox(height: CohortSpacing.lg),
              CohortButton(
                label: _isSaving ? 'Saving...' : 'Save',
                onPressed: _isSaving ? () {} : _saveProtocol,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EditorSection extends StatelessWidget {
  const _EditorSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title),
          const SizedBox(height: CohortSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class _WorkoutSummarySection extends StatelessWidget {
  const _WorkoutSummarySection({required this.protocol});

  final Protocol protocol;

  @override
  Widget build(BuildContext context) {
    final fields = <_ContextFieldData>[
      _ContextFieldData(label: 'Name', value: protocol.name),
      _ContextFieldData(label: 'Purpose', value: protocol.description),
      _ContextFieldData(label: 'Main Session', value: protocol.mainSession),
      _ContextFieldData(label: 'Coach Notes', value: protocol.coachingNotes),
    ];

    final visibleFields = fields
        .where((field) => field.value != null && field.value!.trim().isNotEmpty)
        .toList();

    if (visibleFields.isEmpty) {
      return const SizedBox.shrink();
    }

    return _EditorSection(
      title: 'Workout Summary',
      child: CohortCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < visibleFields.length; index++) ...[
              _ContextField(
                label: visibleFields[index].label,
                value: visibleFields[index].value!,
                compact: true,
              ),
              if (index < visibleFields.length - 1)
                const SizedBox(height: CohortSpacing.md),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetadataEditorSection extends StatelessWidget {
  const _MetadataEditorSection({
    required this.protocol,
    required this.primaryCapability,
    required this.secondaryCapability,
    required this.sessionType,
    required this.environment,
    required this.physiologicalDemand,
    required this.recoveryCost,
    required this.durationCategory,
    required this.technicalComplexity,
    required this.adaptability,
    required this.runningRequired,
    required this.runningReplaceable,
    required this.hotelFriendly,
    required this.indoorFriendly,
    required this.noiseFriendly,
    required this.selectedEquipment,
    required this.selectedRequiredEquipment,
    required this.selectedOptionalEquipment,
    required this.selectedSuitableFor,
    required this.durationMinController,
    required this.onPrimaryCapabilityChanged,
    required this.onSecondaryCapabilityChanged,
    required this.onSessionTypeChanged,
    required this.onEnvironmentChanged,
    required this.onPhysiologicalDemandChanged,
    required this.onRecoveryCostChanged,
    required this.onDurationCategoryChanged,
    required this.onTechnicalComplexityChanged,
    required this.onAdaptabilityChanged,
    required this.onRunningRequiredChanged,
    required this.onRunningReplaceableChanged,
    required this.onHotelFriendlyChanged,
    required this.onIndoorFriendlyChanged,
    required this.onNoiseFriendlyChanged,
    required this.onEquipmentChanged,
    required this.onRequiredEquipmentChanged,
    required this.onOptionalEquipmentChanged,
    required this.onSuitableForChanged,
  });

  final Protocol protocol;
  final String? primaryCapability;
  final String? secondaryCapability;
  final String? sessionType;
  final String? environment;
  final String? physiologicalDemand;
  final String? recoveryCost;
  final String? durationCategory;
  final String? technicalComplexity;
  final int? adaptability;
  final bool? runningRequired;
  final bool? runningReplaceable;
  final bool? hotelFriendly;
  final bool? indoorFriendly;
  final bool? noiseFriendly;
  final Set<String> selectedEquipment;
  final Set<String> selectedRequiredEquipment;
  final Set<String> selectedOptionalEquipment;
  final Set<String> selectedSuitableFor;
  final TextEditingController durationMinController;
  final ValueChanged<String?> onPrimaryCapabilityChanged;
  final ValueChanged<String?> onSecondaryCapabilityChanged;
  final ValueChanged<String?> onSessionTypeChanged;
  final ValueChanged<String?> onEnvironmentChanged;
  final ValueChanged<String?> onPhysiologicalDemandChanged;
  final ValueChanged<String?> onRecoveryCostChanged;
  final ValueChanged<String?> onDurationCategoryChanged;
  final ValueChanged<String?> onTechnicalComplexityChanged;
  final ValueChanged<int?> onAdaptabilityChanged;
  final ValueChanged<bool?> onRunningRequiredChanged;
  final ValueChanged<bool?> onRunningReplaceableChanged;
  final ValueChanged<bool?> onHotelFriendlyChanged;
  final ValueChanged<bool?> onIndoorFriendlyChanged;
  final ValueChanged<bool?> onNoiseFriendlyChanged;
  final void Function(String value, bool isSelected) onEquipmentChanged;
  final void Function(String value, bool isSelected) onRequiredEquipmentChanged;
  final void Function(String value, bool isSelected) onOptionalEquipmentChanged;
  final void Function(String value, bool isSelected) onSuitableForChanged;

  @override
  Widget build(BuildContext context) {
    return _EditorSection(
      title: 'Metadata Editor',
      child: CohortCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MetadataDropdown(
              label: 'primary_capability',
              value: primaryCapability,
              options: ProtocolMetadataVocabulary.optionsWithCurrent(
                primaryCapability,
                ProtocolMetadataVocabulary.primaryCapabilities,
              ),
              onChanged: onPrimaryCapabilityChanged,
              compact: true,
            ),
            _MetadataDropdown(
              label: 'secondary_capability',
              value: secondaryCapability,
              options:
                  ProtocolMetadataVocabulary.secondaryCapabilityOptionsWithCurrent(
                secondaryCapability,
              ),
              onChanged: onSecondaryCapabilityChanged,
              compact: true,
            ),
            _MetadataDropdown(
              label: 'session_type',
              value: sessionType,
              options: ProtocolMetadataVocabulary.optionsWithCurrent(
                sessionType,
                ProtocolMetadataVocabulary.sessionTypes,
              ),
              onChanged: onSessionTypeChanged,
              compact: true,
            ),
            _MetadataChecklist(
              label: 'equipment',
              selected: selectedEquipment,
              options: ProtocolMetadataVocabulary.equipmentOptionsWithCurrent(
                protocol.equipment,
              ),
              onChanged: onEquipmentChanged,
              compact: true,
            ),
            _MetadataChecklist(
              label: 'required_equipment',
              selected: selectedRequiredEquipment,
              options:
                  ProtocolMetadataVocabulary.requiredEquipmentOptionsWithCurrent(
                protocol.requiredEquipment,
              ),
              onChanged: onRequiredEquipmentChanged,
              compact: true,
            ),
            _MetadataChecklist(
              label: 'optional_equipment',
              selected: selectedOptionalEquipment,
              options:
                  ProtocolMetadataVocabulary.optionalEquipmentOptionsWithCurrent(
                protocol.optionalEquipment,
              ),
              onChanged: onOptionalEquipmentChanged,
              compact: true,
            ),
            _MetadataDropdown(
              label: 'environment',
              value: environment,
              options: ProtocolMetadataVocabulary.optionsWithCurrent(
                environment,
                ProtocolMetadataVocabulary.environments,
              ),
              onChanged: onEnvironmentChanged,
              compact: true,
            ),
            _MetadataDropdown(
              label: 'physiological_demand',
              value: physiologicalDemand,
              options: ProtocolMetadataVocabulary.optionsWithCurrent(
                physiologicalDemand,
                ProtocolMetadataVocabulary.physiologicalDemands,
              ),
              onChanged: onPhysiologicalDemandChanged,
              compact: true,
            ),
            _MetadataDropdown(
              label: 'recovery_cost',
              value: recoveryCost,
              options: ProtocolMetadataVocabulary.optionsWithCurrent(
                recoveryCost,
                ProtocolMetadataVocabulary.recoveryCosts,
              ),
              onChanged: onRecoveryCostChanged,
              compact: true,
            ),
            _MetadataField(
              label: 'duration_min',
              controller: durationMinController,
              keyboardType: TextInputType.number,
              compact: true,
            ),
            _MetadataDropdown(
              label: 'duration_category',
              value: durationCategory,
              options: ProtocolMetadataVocabulary.optionsWithCurrent(
                durationCategory,
                ProtocolMetadataVocabulary.durationCategories,
              ),
              onChanged: onDurationCategoryChanged,
              compact: true,
            ),
            _MetadataDropdown(
              label: 'technical_complexity',
              value: technicalComplexity,
              options: ProtocolMetadataVocabulary.optionsWithCurrent(
                technicalComplexity,
                ProtocolMetadataVocabulary.technicalComplexities,
              ),
              onChanged: onTechnicalComplexityChanged,
              compact: true,
            ),
            _MetadataIntDropdown(
              label: 'adaptability',
              value: adaptability,
              options: ProtocolMetadataVocabulary.adaptabilityOptionsWithCurrent(
                adaptability,
              ),
              onChanged: onAdaptabilityChanged,
              compact: true,
            ),
            _MetadataBoolDropdown(
              label: 'running_required',
              value: runningRequired,
              onChanged: onRunningRequiredChanged,
              compact: true,
            ),
            _MetadataBoolDropdown(
              label: 'running_replaceable',
              value: runningReplaceable,
              onChanged: onRunningReplaceableChanged,
              compact: true,
            ),
            _MetadataBoolDropdown(
              label: 'hotel_friendly',
              value: hotelFriendly,
              onChanged: onHotelFriendlyChanged,
              compact: true,
            ),
            _MetadataBoolDropdown(
              label: 'indoor_friendly',
              value: indoorFriendly,
              onChanged: onIndoorFriendlyChanged,
              compact: true,
            ),
            _MetadataBoolDropdown(
              label: 'noise_friendly',
              value: noiseFriendly,
              onChanged: onNoiseFriendlyChanged,
              compact: true,
            ),
            _MetadataChecklist(
              label: 'suitable_for',
              selected: selectedSuitableFor,
              options: ProtocolMetadataVocabulary.suitableForOptionsWithCurrent(
                protocol.suitableFor,
              ),
              onChanged: onSuitableForChanged,
              compact: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetadataQuickReferenceSection extends StatelessWidget {
  const _MetadataQuickReferenceSection();

  @override
  Widget build(BuildContext context) {
    return _EditorSection(
      title: 'Metadata Quick Reference',
      child: CohortCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ReferenceGroup(
              title: 'Duration Categories',
              rows: [
                _ReferenceRow(range: '0–15', label: 'Micro'),
                _ReferenceRow(range: '16–30', label: 'Short'),
                _ReferenceRow(range: '31–45', label: 'Medium'),
                _ReferenceRow(range: '46–75', label: 'Long'),
                _ReferenceRow(range: '76+', label: 'Extended'),
              ],
            ),
            const SizedBox(height: CohortSpacing.md),
            const _ReferenceGroup(
              title: 'Physiological Demand',
              rows: [
                _ReferenceRow(label: 'Low'),
                _ReferenceRow(label: 'Moderate'),
                _ReferenceRow(label: 'High'),
                _ReferenceRow(label: 'Very High'),
              ],
            ),
            const SizedBox(height: CohortSpacing.md),
            const _ReferenceGroup(
              title: 'Recovery Cost',
              rows: [
                _ReferenceRow(label: 'Low'),
                _ReferenceRow(label: 'Moderate'),
                _ReferenceRow(label: 'High'),
                _ReferenceRow(label: 'Very High'),
              ],
            ),
            const SizedBox(height: CohortSpacing.md),
            const _ReferenceGroup(
              title: 'Technical Complexity',
              rows: [
                _ReferenceRow(label: 'Beginner'),
                _ReferenceRow(label: 'Intermediate'),
                _ReferenceRow(label: 'Advanced'),
              ],
            ),
            const SizedBox(height: CohortSpacing.md),
            Text(
              'Adaptation changes the route, never the destination.',
              style: CohortTextStyles.small,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferenceGroup extends StatelessWidget {
  const _ReferenceGroup({
    required this.title,
    required this.rows,
  });

  final String title;
  final List<_ReferenceRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: CohortTextStyles.eyebrow),
        const SizedBox(height: CohortSpacing.xs),
        for (var index = 0; index < rows.length; index++) ...[
          rows[index],
          if (index < rows.length - 1) const SizedBox(height: CohortSpacing.xs),
        ],
      ],
    );
  }
}

class _ReferenceRow extends StatelessWidget {
  const _ReferenceRow({
    this.range,
    required this.label,
  });

  final String? range;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (range == null) {
      return Text(label, style: CohortTextStyles.small);
    }

    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(range!, style: CohortTextStyles.muted),
        ),
        Expanded(
          child: Text(label, style: CohortTextStyles.small),
        ),
      ],
    );
  }
}

class _ContextFieldData {
  const _ContextFieldData({
    required this.label,
    required this.value,
  });

  final String label;
  final String? value;
}

class _ContextField extends StatelessWidget {
  const _ContextField({
    required this.label,
    required this.value,
    this.compact = false,
  });

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: CohortTextStyles.eyebrow),
        SizedBox(height: compact ? CohortSpacing.xs : CohortSpacing.sm),
        Text(value, style: CohortTextStyles.body),
      ],
    );
  }
}

class _MetadataChecklist extends StatelessWidget {
  const _MetadataChecklist({
    required this.label,
    required this.selected,
    required this.options,
    required this.onChanged,
    this.compact = false,
  });

  final String label;
  final Set<String> selected;
  final List<String> options;
  final void Function(String value, bool isSelected) onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: compact ? CohortSpacing.md : CohortSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: CohortTextStyles.eyebrow),
          const SizedBox(height: CohortSpacing.xs),
          for (final option in options) ...[
            _MetadataCheckbox(
              label: option,
              value: selected.contains(option),
              onChanged: (isSelected) => onChanged(option, isSelected),
              compact: compact,
            ),
          ],
        ],
      ),
    );
  }
}

class _MetadataCheckbox extends StatelessWidget {
  const _MetadataCheckbox({
    required this.label,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: compact ? 0 : CohortSpacing.xs,
        ),
        child: Row(
          children: [
            SizedBox(
              height: compact ? 36 : null,
              width: compact ? 36 : null,
              child: Checkbox(
                value: value,
                materialTapTargetSize: compact
                    ? MaterialTapTargetSize.shrinkWrap
                    : MaterialTapTargetSize.padded,
                visualDensity:
                    compact ? VisualDensity.compact : VisualDensity.standard,
                activeColor: CohortColors.olive,
                checkColor: CohortColors.textPrimary,
                side: const BorderSide(color: CohortColors.borderStrong),
                onChanged: (isSelected) {
                  if (isSelected != null) {
                    onChanged(isSelected);
                  }
                },
              ),
            ),
            Expanded(
              child: Text(
                label,
                style: compact ? CohortTextStyles.small : CohortTextStyles.body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetadataDropdown extends StatelessWidget {
  const _MetadataDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.compact = false,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final bool compact;

  String? _resolvedValue(String? value, List<String> options) {
    if (value == null) return null;
    if (options.contains(value)) return value;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: compact ? CohortSpacing.md : CohortSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: CohortTextStyles.eyebrow),
          const SizedBox(height: CohortSpacing.xs),
          DropdownButton<String>(
            isExpanded: true,
            isDense: compact,
            value: _resolvedValue(value, options),
            style: compact ? CohortTextStyles.small : CohortTextStyles.body,
            items: [
              DropdownMenuItem<String>(
                value: null,
                child: Text(
                  '—',
                  style: compact
                      ? CohortTextStyles.small
                      : CohortTextStyles.body,
                ),
              ),
              ...options.map(
                (option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(
                    option,
                    style: compact
                        ? CohortTextStyles.small
                        : CohortTextStyles.body,
                  ),
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

class _MetadataIntDropdown extends StatelessWidget {
  const _MetadataIntDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.compact = false,
  });

  final String label;
  final int? value;
  final List<int> options;
  final ValueChanged<int?> onChanged;
  final bool compact;

  int? _resolvedValue(int? value, List<int> options) {
    if (value == null) return null;
    if (options.contains(value)) return value;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = compact ? CohortTextStyles.small : CohortTextStyles.body;

    return Padding(
      padding: EdgeInsets.only(
        bottom: compact ? CohortSpacing.md : CohortSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: CohortTextStyles.eyebrow),
          const SizedBox(height: CohortSpacing.xs),
          DropdownButton<int?>(
            isExpanded: true,
            isDense: compact,
            value: _resolvedValue(value, options),
            style: textStyle,
            items: [
              DropdownMenuItem<int?>(
                value: null,
                child: Text('—', style: textStyle),
              ),
              ...options.map(
                (option) => DropdownMenuItem<int?>(
                  value: option,
                  child: Text(option.toString(), style: textStyle),
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

class _MetadataBoolDropdown extends StatelessWidget {
  const _MetadataBoolDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  final String label;
  final bool? value;
  final ValueChanged<bool?> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textStyle = compact ? CohortTextStyles.small : CohortTextStyles.body;

    return Padding(
      padding: EdgeInsets.only(
        bottom: compact ? CohortSpacing.md : CohortSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: CohortTextStyles.eyebrow),
          const SizedBox(height: CohortSpacing.xs),
          DropdownButton<bool?>(
            isExpanded: true,
            isDense: compact,
            value: value,
            style: textStyle,
            items: [
              DropdownMenuItem<bool?>(
                value: null,
                child: Text('—', style: textStyle),
              ),
              DropdownMenuItem<bool?>(
                value: true,
                child: Text('Yes', style: textStyle),
              ),
              DropdownMenuItem<bool?>(
                value: false,
                child: Text('No', style: textStyle),
              ),
            ],
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _MetadataField extends StatelessWidget {
  const _MetadataField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.compact = false,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: compact ? CohortSpacing.md : CohortSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: CohortTextStyles.eyebrow),
          const SizedBox(height: CohortSpacing.xs),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: compact ? CohortTextStyles.small : CohortTextStyles.body,
            decoration: const InputDecoration(
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}
