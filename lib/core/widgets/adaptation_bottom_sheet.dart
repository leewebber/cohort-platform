import 'package:flutter/material.dart';

import '../../models/adaptation_option.dart';
import '../../models/adaptation_reason.dart';
import '../../models/adaptation_request.dart';
import '../../models/adaptation_session_environment.dart';
import '../../models/protocol_metadata_vocabulary.dart';
import '../../models/recovery_state.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';
import 'cohort_button.dart';
import 'cohort_card.dart';

class AdaptationBottomSheet extends StatefulWidget {
  const AdaptationBottomSheet({super.key});

  @override
  State<AdaptationBottomSheet> createState() => _AdaptationBottomSheetState();
}

class _AdaptationBottomSheetState extends State<AdaptationBottomSheet> {
  AdaptationReason? _selectedReason;
  final Set<String> _selectedEquipment = {};

  void _selectReason(AdaptationReason reason) {
    setState(() {
      _selectedReason = reason;
      _selectedEquipment.clear();
    });
  }

  void _goBack() {
    setState(() {
      _selectedReason = null;
      _selectedEquipment.clear();
    });
  }

  void _complete(AdaptationRequest request) {
    Navigator.of(context).pop(request);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(CohortSpacing.lg),
        child: _selectedReason == null
            ? _ReasonStep(onReasonSelected: _selectReason)
            : _buildConstraintStep(),
      ),
    );
  }

  Widget _buildConstraintStep() {
    switch (_selectedReason!) {
      case AdaptationReason.recovery:
        return _RecoveryStep(
          onBack: _goBack,
          onSelected: (recoveryState) => _complete(
            AdaptationRequest(
              reason: AdaptationReason.recovery,
              recoveryState: recoveryState,
            ),
          ),
        );
      case AdaptationReason.environment:
        return _EnvironmentStep(
          onBack: _goBack,
          onSelected: (environment) => _complete(
            AdaptationRequest(
              reason: AdaptationReason.environment,
              environment: environment,
            ),
          ),
        );
      case AdaptationReason.equipment:
        return _EquipmentStep(
          selectedEquipment: _selectedEquipment,
          onBack: _goBack,
          onToggleEquipment: (equipment, isSelected) {
            setState(() {
              if (isSelected) {
                _selectedEquipment.add(equipment);
              } else {
                _selectedEquipment.remove(equipment);
              }
            });
          },
          onContinue: () => _complete(
            AdaptationRequest(
              reason: AdaptationReason.equipment,
              availableEquipment: Set<String>.from(_selectedEquipment),
            ),
          ),
        );
      case AdaptationReason.time:
        return _TimeStep(
          onBack: _goBack,
          onSelected: (minutes) => _complete(
            AdaptationRequest(
              reason: AdaptationReason.time,
              availableMinutes: minutes,
            ),
          ),
        );
    }
  }
}

class _ReasonStep extends StatelessWidget {
  const _ReasonStep({required this.onReasonSelected});

  final ValueChanged<AdaptationReason> onReasonSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Adjust Today\'s Session',
          style: CohortTextStyles.h2,
        ),
        const SizedBox(height: CohortSpacing.sm),
        const Text(
          'What is affecting today’s session?',
          style: CohortTextStyles.body,
        ),
        const SizedBox(height: CohortSpacing.lg),
        for (var index = 0; index < AdaptationOption.options.length; index++) ...[
          if (index > 0) const SizedBox(height: CohortSpacing.md),
          CohortCard(
            onTap: () => onReasonSelected(AdaptationOption.options[index].reason),
            child: _AdaptationOptionRow(
              option: AdaptationOption.options[index],
            ),
          ),
        ],
      ],
    );
  }
}

class _RecoveryStep extends StatelessWidget {
  const _RecoveryStep({
    required this.onBack,
    required this.onSelected,
  });

  final VoidCallback onBack;
  final ValueChanged<RecoveryState> onSelected;

  static const _options = RecoveryState.values;

  @override
  Widget build(BuildContext context) {
    return _ConstraintStepLayout(
      title: 'Recovery',
      subtitle: 'How are you feeling today?',
      onBack: onBack,
      child: Column(
        children: [
          for (var index = 0; index < _options.length; index++) ...[
            if (index > 0) const SizedBox(height: CohortSpacing.md),
            CohortCard(
              onTap: () => onSelected(_options[index]),
              child: Text(_options[index].label, style: CohortTextStyles.cardTitle),
            ),
          ],
        ],
      ),
    );
  }
}

class _EnvironmentStep extends StatelessWidget {
  const _EnvironmentStep({
    required this.onBack,
    required this.onSelected,
  });

  final VoidCallback onBack;
  final ValueChanged<AdaptationSessionEnvironment> onSelected;

  static const _options = AdaptationSessionEnvironment.values;

  @override
  Widget build(BuildContext context) {
    return _ConstraintStepLayout(
      title: 'Environment',
      subtitle: 'Where can you train today?',
      onBack: onBack,
      child: Column(
        children: [
          for (var index = 0; index < _options.length; index++) ...[
            if (index > 0) const SizedBox(height: CohortSpacing.md),
            CohortCard(
              onTap: () => onSelected(_options[index]),
              child: Text(_options[index].label, style: CohortTextStyles.cardTitle),
            ),
          ],
        ],
      ),
    );
  }
}

class _EquipmentStep extends StatelessWidget {
  const _EquipmentStep({
    required this.selectedEquipment,
    required this.onBack,
    required this.onToggleEquipment,
    required this.onContinue,
  });

  final Set<String> selectedEquipment;
  final VoidCallback onBack;
  final void Function(String equipment, bool isSelected) onToggleEquipment;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return _ConstraintStepLayout(
      title: 'Equipment',
      subtitle: 'What do you have available?',
      onBack: onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final equipment in ProtocolMetadataVocabulary.equipment) ...[
            _EquipmentCheckbox(
              label: equipment,
              value: selectedEquipment.contains(equipment),
              onChanged: (isSelected) => onToggleEquipment(equipment, isSelected),
            ),
          ],
          const SizedBox(height: CohortSpacing.lg),
          CohortButton(
            label: 'Continue',
            onPressed: onContinue,
          ),
        ],
      ),
    );
  }
}

class _TimeStep extends StatelessWidget {
  const _TimeStep({
    required this.onBack,
    required this.onSelected,
  });

  final VoidCallback onBack;
  final ValueChanged<int> onSelected;

  static const _options = <({String label, int minutes})>[
    (label: '15', minutes: 15),
    (label: '30', minutes: 30),
    (label: '45', minutes: 45),
    (label: '60+', minutes: 60),
  ];

  @override
  Widget build(BuildContext context) {
    return _ConstraintStepLayout(
      title: 'Time',
      subtitle: 'How long can you train?',
      onBack: onBack,
      child: Column(
        children: [
          for (var index = 0; index < _options.length; index++) ...[
            if (index > 0) const SizedBox(height: CohortSpacing.md),
            CohortCard(
              onTap: () => onSelected(_options[index].minutes),
              child: Text(_options[index].label, style: CohortTextStyles.cardTitle),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConstraintStepLayout extends StatelessWidget {
  const _ConstraintStepLayout({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.child,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton(
            onPressed: onBack,
            child: const Text('← Back'),
          ),
          const SizedBox(height: CohortSpacing.sm),
          const Text(
            'Adjust Today\'s Session',
            style: CohortTextStyles.h2,
          ),
          const SizedBox(height: CohortSpacing.sm),
          Text(title, style: CohortTextStyles.eyebrow),
          const SizedBox(height: CohortSpacing.xs),
          Text(subtitle, style: CohortTextStyles.body),
          const SizedBox(height: CohortSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class _AdaptationOptionRow extends StatelessWidget {
  const _AdaptationOptionRow({required this.option});

  final AdaptationOption option;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(option.icon, size: 24, color: CohortColors.textPrimary),
        const SizedBox(width: CohortSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(option.title, style: CohortTextStyles.cardTitle),
              const SizedBox(height: CohortSpacing.sm),
              Text(option.subtitle, style: CohortTextStyles.small),
            ],
          ),
        ),
      ],
    );
  }
}

class _EquipmentCheckbox extends StatelessWidget {
  const _EquipmentCheckbox({
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: CohortSpacing.xs),
        child: Row(
          children: [
            Checkbox(
              value: value,
              activeColor: CohortColors.olive,
              checkColor: CohortColors.textPrimary,
              side: const BorderSide(color: CohortColors.borderStrong),
              onChanged: (isSelected) {
                if (isSelected != null) {
                  onChanged(isSelected);
                }
              },
            ),
            Expanded(
              child: Text(label, style: CohortTextStyles.body),
            ),
          ],
        ),
      ),
    );
  }
}

Future<AdaptationRequest?> showAdaptationBottomSheet(BuildContext context) {
  return showModalBottomSheet<AdaptationRequest>(
    context: context,
    backgroundColor: CohortColors.surfaceRaised,
    isScrollControlled: true,
    builder: (_) => const AdaptationBottomSheet(),
  );
}
