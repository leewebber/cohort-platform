import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../domain/adaptation/adaptation_domain.dart';
import '../../../models/session_block.dart';
import '../models/adaptation_metadata_builder_vocabulary.dart';
import 'session_adaptation_metadata_section.dart';
import 'session_builder_form_widgets.dart';

enum BlockAdaptationPolicyMode { recommended, custom }

/// Block-level adaptation metadata controls for Session Builder.
class SessionBlockAdaptationMetadataSection extends StatelessWidget {
  const SessionBlockAdaptationMetadataSection({
    super.key,
    required this.block,
    required this.onChanged,
  });

  final SessionBlock block;
  final ValueChanged<SessionBlock> onChanged;

  BlockAdaptationPolicyMode get _policyMode =>
      block.adaptationPolicy == null
          ? BlockAdaptationPolicyMode.recommended
          : BlockAdaptationPolicyMode.custom;

  BlockAdaptationPolicy get _recommendedPolicy =>
      SessionBlockTypeAdaptationPolicy.defaultAdaptationPolicy(block.blockType);

  BlockAdaptationPolicy get _editablePolicy =>
      block.adaptationPolicy ?? _recommendedPolicy;

  @override
  Widget build(BuildContext context) {
    final recommendedPriority =
        AdaptationMetadataBuilderVocabulary.recommendedBlockPriorityLabel(
      block.blockType,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Adaptation',
          style: CohortTextStyles.eyebrow.copyWith(color: CohortColors.olive),
        ),
        const SizedBox(height: CohortSpacing.sm),
        SessionBuilderEnumDropdown<BlockPriority>(
          label: 'Block priority',
          value: block.blockPriority,
          options: BlockPriority.values,
          displayLabel: AdaptationMetadataBuilderVocabulary.blockPriorityDisplayLabel,
          nullOptionLabel:
              '$useRecommendedPrefix$recommendedPriority',
          onChanged: (value) {
            onChanged(
              block.copyWith(
                blockPriority: value,
                clearBlockPriority: value == null,
              ),
            );
          },
        ),
        Text('Adaptation policy', style: CohortTextStyles.eyebrow),
        const SizedBox(height: CohortSpacing.xs),
        SegmentedButton<BlockAdaptationPolicyMode>(
          segments: const [
            ButtonSegment(
              value: BlockAdaptationPolicyMode.recommended,
              label: Text('Recommended'),
            ),
            ButtonSegment(
              value: BlockAdaptationPolicyMode.custom,
              label: Text('Custom'),
            ),
          ],
          selected: {_policyMode},
          onSelectionChanged: (selection) {
            final mode = selection.first;
            if (mode == BlockAdaptationPolicyMode.recommended) {
              onChanged(
                block.copyWith(clearAdaptationPolicy: true),
              );
              return;
            }
            onChanged(
              block.copyWith(
                adaptationPolicy: BlockAdaptationPolicy.fromJson(
                  _recommendedPolicy.toJson(),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: CohortSpacing.sm),
        if (_policyMode == BlockAdaptationPolicyMode.recommended)
          _PolicySummary(policy: _recommendedPolicy, readOnly: true)
        else
          _PolicyEditor(
            policy: _editablePolicy,
            onChanged: (policy) => onChanged(
              block.copyWith(adaptationPolicy: policy),
            ),
          ),
      ],
    );
  }

  static const useRecommendedPrefix = 'Use recommended · ';
}

class _PolicySummary extends StatelessWidget {
  const _PolicySummary({
    required this.policy,
    required this.readOnly,
  });

  final BlockAdaptationPolicy policy;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (readOnly)
          Text(
            'Derived from block type — not saved until you choose Custom.',
            style: CohortTextStyles.small.copyWith(
              color: CohortColors.textSecondary,
            ),
          ),
        const SizedBox(height: CohortSpacing.xs),
        for (final entry in _policyFlags(policy))
          Text(
            '${entry.value ? 'Yes' : 'No'} · ${AdaptationMetadataBuilderVocabulary.policyFlagLabel(entry.key)}',
            style: CohortTextStyles.small,
          ),
      ],
    );
  }

  static List<MapEntry<String, bool>> _policyFlags(BlockAdaptationPolicy policy) {
    return [
      MapEntry('canRemove', policy.canRemove),
      MapEntry('canShorten', policy.canShorten),
      MapEntry('canReduceVolume', policy.canReduceVolume),
      MapEntry('canReduceIntensity', policy.canReduceIntensity),
      MapEntry('canIncreaseRest', policy.canIncreaseRest),
      MapEntry('canSuperset', policy.canSuperset),
      MapEntry('canReplaceExercises', policy.canReplaceExercises),
      MapEntry('canReplaceBlock', policy.canReplaceBlock),
    ];
  }
}

class _PolicyEditor extends StatelessWidget {
  const _PolicyEditor({
    required this.policy,
    required this.onChanged,
  });

  final BlockAdaptationPolicy policy;
  final ValueChanged<BlockAdaptationPolicy> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final entry in _PolicySummary._policyFlags(policy))
          SessionBuilderCheckbox(
            label: AdaptationMetadataBuilderVocabulary.policyFlagLabel(entry.key),
            value: entry.value,
            onChanged: (selected) {
              onChanged(_copyPolicy(policy, entry.key, selected));
            },
          ),
      ],
    );
  }

  BlockAdaptationPolicy _copyPolicy(
    BlockAdaptationPolicy source,
    String key,
    bool value,
  ) {
    return BlockAdaptationPolicy(
      canRemove: key == 'canRemove' ? value : source.canRemove,
      canShorten: key == 'canShorten' ? value : source.canShorten,
      canReduceVolume: key == 'canReduceVolume' ? value : source.canReduceVolume,
      canReduceIntensity:
          key == 'canReduceIntensity' ? value : source.canReduceIntensity,
      canIncreaseRest: key == 'canIncreaseRest' ? value : source.canIncreaseRest,
      canSuperset: key == 'canSuperset' ? value : source.canSuperset,
      canReplaceExercises:
          key == 'canReplaceExercises' ? value : source.canReplaceExercises,
      canReplaceBlock: key == 'canReplaceBlock' ? value : source.canReplaceBlock,
      minimumViablePrescription: source.minimumViablePrescription,
      dependsOnBlockIds: source.dependsOnBlockIds,
    );
  }
}
