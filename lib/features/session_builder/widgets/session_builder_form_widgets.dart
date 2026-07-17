import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/section_title.dart';

class SessionBuilderSection extends StatelessWidget {
  const SessionBuilderSection({
    super.key,
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

class SessionBuilderTextField extends StatelessWidget {
  const SessionBuilderTextField({
    super.key,
    required this.label,
    required this.controller,
    this.keyboardType,
    this.readOnly = false,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool readOnly;
  final ValueChanged<String>? onChanged;

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
            onChanged: onChanged,
            style: CohortTextStyles.body.copyWith(
              color: readOnly
                  ? CohortColors.textSecondary
                  : CohortColors.textPrimary,
            ),
            decoration: const InputDecoration(isDense: true),
          ),
        ],
      ),
    );
  }
}

class SessionBuilderDropdown extends StatelessWidget {
  const SessionBuilderDropdown({
    super.key,
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

class SessionBuilderChecklist extends StatelessWidget {
  const SessionBuilderChecklist({
    super.key,
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
            SessionBuilderCheckbox(
              label: option,
              value: selected.contains(option),
              onChanged: (isSelected) => onChanged(option, isSelected),
            ),
        ],
      ),
    );
  }
}

class SessionBuilderCheckbox extends StatelessWidget {
  const SessionBuilderCheckbox({
    super.key,
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

class SessionBuilderStepTextField extends StatelessWidget {
  const SessionBuilderStepTextField({
    super.key,
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
