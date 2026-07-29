import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../domain/adaptation/adaptation_domain.dart';
import '../../../models/session_adaptation_metadata_codec.dart';
import '../controllers/session_builder_editing_state.dart';
import '../models/adaptation_metadata_builder_vocabulary.dart';
import 'session_builder_form_widgets.dart';

/// Session-level adaptation metadata controls (coach / founder builder).
class SessionAdaptationMetadataSection extends StatelessWidget {
  const SessionAdaptationMetadataSection({
    super.key,
    required this.editing,
    required this.minimumViableDurationController,
    required this.onChanged,
  });

  final SessionBuilderEditingState editing;
  final TextEditingController minimumViableDurationController;
  final VoidCallback onChanged;

  List<String> get _adaptationValidationMessages {
    return SessionAdaptationMetadataValidation.validate(
      primarySessionIntent: editing.primarySessionIntent,
      secondarySessionIntents: editing.secondarySessionIntents,
      minimumViableDurationMin: editing.minimumViableDurationMin,
      plannedDurationMin: editing.durationMin,
    );
  }

  @override
  Widget build(BuildContext context) {
    final validationMessages = _adaptationValidationMessages;
    final primary = editing.primarySessionIntent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Adaptation metadata',
          style: CohortTextStyles.eyebrow.copyWith(color: CohortColors.olive),
        ),
        const SizedBox(height: CohortSpacing.sm),
        SessionBuilderEnumDropdown<SessionIntent>(
          label: 'Primary session intent',
          value: primary,
          options: AdaptationMetadataBuilderVocabulary.orderedSessionIntents,
          displayLabel:
              AdaptationMetadataBuilderVocabulary.sessionIntentDisplayLabel,
          onChanged: (value) {
            editing.setPrimarySessionIntent(value);
            onChanged();
          },
        ),
        SessionBuilderIntentMultiSelect(
          label: 'Secondary session intents',
          selected: editing.secondarySessionIntents,
          disabled: primary,
          onChanged: (intents) {
            editing.setSecondarySessionIntents(intents);
            onChanged();
          },
        ),
        SessionBuilderTextField(
          label: 'Minimum viable duration (min)',
          controller: minimumViableDurationController,
          keyboardType: TextInputType.number,
          helperText:
              AdaptationMetadataBuilderVocabulary.minimumViableDurationHelper,
          onChanged: (_) {
            final parsed = int.tryParse(
              minimumViableDurationController.text.trim(),
            );
            editing.setMinimumViableDurationMin(parsed);
            onChanged();
          },
        ),
        if (validationMessages.isNotEmpty) ...[
          const SizedBox(height: CohortSpacing.xs),
          for (final message in validationMessages)
            Padding(
              padding: const EdgeInsets.only(bottom: CohortSpacing.xs),
              child: Text(
                message,
                style: CohortTextStyles.small.copyWith(
                  color: CohortColors.warning,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class SessionBuilderEnumDropdown<T> extends StatelessWidget {
  const SessionBuilderEnumDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.displayLabel,
    required this.onChanged,
    this.nullOptionLabel = '—',
  });

  final String label;
  final T? value;
  final List<T> options;
  final String Function(T value) displayLabel;
  final ValueChanged<T?> onChanged;
  final String nullOptionLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: CohortTextStyles.eyebrow),
          const SizedBox(height: CohortSpacing.xs),
          DropdownButton<T?>(
            isExpanded: true,
            isDense: true,
            value: value,
            style: CohortTextStyles.small,
            items: [
              DropdownMenuItem<T?>(
                value: null,
                child: Text(nullOptionLabel, style: CohortTextStyles.small),
              ),
              ...options.map(
                (option) => DropdownMenuItem<T?>(
                  value: option,
                  child: Text(
                    displayLabel(option),
                    style: CohortTextStyles.small,
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

class SessionBuilderIntentMultiSelect extends StatelessWidget {
  const SessionBuilderIntentMultiSelect({
    super.key,
    required this.label,
    required this.selected,
    required this.onChanged,
    this.disabled,
  });

  final String label;
  final List<SessionIntent> selected;
  final SessionIntent? disabled;
  final ValueChanged<List<SessionIntent>> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = AdaptationMetadataBuilderVocabulary.orderedSessionIntents
        .where((intent) => intent != disabled)
        .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: CohortTextStyles.eyebrow),
          const SizedBox(height: CohortSpacing.xs),
          Wrap(
            spacing: CohortSpacing.xs,
            runSpacing: CohortSpacing.xs,
            children: [
              for (final intent in options)
                FilterChip(
                  label: Text(
                    AdaptationMetadataBuilderVocabulary.sessionIntentDisplayLabel(
                      intent,
                    ),
                    style: CohortTextStyles.small,
                  ),
                  selected: selected.contains(intent),
                  onSelected: (isSelected) {
                    final updated = List<SessionIntent>.from(selected);
                    if (isSelected) {
                      if (!updated.contains(intent)) {
                        updated.add(intent);
                      }
                    } else {
                      updated.remove(intent);
                    }
                    onChanged(
                      SessionAdaptationMetadataCodec.canonicalizeSecondaries(
                        primary: disabled,
                        secondary: updated,
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
