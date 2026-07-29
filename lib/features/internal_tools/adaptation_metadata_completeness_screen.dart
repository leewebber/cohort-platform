import 'package:flutter/material.dart';

import '../../core/config/internal_tools_policy.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/text_styles.dart';
import '../../core/widgets/cohort_card.dart';
import '../../core/widgets/section_title.dart';
import '../adaptation_metadata_completeness/models/adaptation_metadata_completeness_models.dart';
import '../adaptation_metadata_completeness/services/adaptation_metadata_completeness_loader.dart';
import '../admin/protocol_builder_screen.dart';
import '../session_builder/models/adaptation_metadata_builder_vocabulary.dart';

/// Founder-only adaptation metadata backlog review (internal tools build).
class AdaptationMetadataCompletenessScreen extends StatefulWidget {
  const AdaptationMetadataCompletenessScreen({super.key, this.loader});

  final AdaptationMetadataCompletenessLoader? loader;

  @override
  State<AdaptationMetadataCompletenessScreen> createState() =>
      _AdaptationMetadataCompletenessScreenState();
}

class _AdaptationMetadataCompletenessScreenState
    extends State<AdaptationMetadataCompletenessScreen> {
  late final AdaptationMetadataCompletenessLoader _loader =
      widget.loader ?? AdaptationMetadataCompletenessLoader();

  AdaptationMetadataCompletenessReport? _report;
  AdaptationMetadataCompletenessFilters _filters =
      const AdaptationMetadataCompletenessFilters();
  String? _errorMessage;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final report = await _loader.load();
      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _loading = false;
      });
    }
  }

  void _openInProtocolBuilder(String protocolId) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ProtocolBuilderScreen(protocolId: protocolId),
          ),
        )
        .then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    if (!InternalToolsPolicy.enabled) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Enable ENABLE_INTERNAL_TOOLS to use adaptation metadata review.',
              style: CohortTextStyles.body,
            ),
          ),
        ),
      );
    }

    final report = _report;
    final visible = report == null
        ? const <AdaptationMetadataCompletenessItem>[]
        : report.filtered(_filters);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('← Back'),
              ),
              const SectionTitle('Internal tools'),
              const SizedBox(height: CohortSpacing.sm),
              Text(
                'Adaptation metadata completeness',
                style: CohortTextStyles.h1,
              ),
              const SizedBox(height: CohortSpacing.xs),
              Text(
                'Review gaps, then open Protocol Builder to confirm canonical '
                'intent and block metadata. Suggestions are never saved automatically.',
                style: CohortTextStyles.body,
              ),
              const SizedBox(height: CohortSpacing.md),
              if (_loading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorMessage != null)
                Expanded(
                  child: Text(_errorMessage!, style: CohortTextStyles.body),
                )
              else if (report != null) ...[
                _SummaryGrid(summary: report.summary),
                const SizedBox(height: CohortSpacing.md),
                _FilterBar(
                  report: report,
                  filters: _filters,
                  onChanged: (value) => setState(() => _filters = value),
                ),
                const SizedBox(height: CohortSpacing.md),
                Text(
                  '${visible.length} item(s) · confirm tagging in builder',
                  style: CohortTextStyles.small,
                ),
                const SizedBox(height: CohortSpacing.sm),
                Expanded(
                  child: ListView.separated(
                    itemCount: visible.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: CohortSpacing.sm),
                    itemBuilder: (context, index) {
                      final item = visible[index];
                      return _CompletenessTile(
                        item: item,
                        onOpenBuilder: () =>
                            _openInProtocolBuilder(item.protocolId),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});

  final AdaptationMetadataCompletenessSummary summary;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: CohortSpacing.sm,
      runSpacing: CohortSpacing.sm,
      children: [
        _StatChip(label: 'Sessions tagged', value: summary.sessionsTagged),
        _StatChip(label: 'Sessions untagged', value: summary.sessionsUntagged),
        _StatChip(label: 'Blocks explicit', value: summary.blocksExplicit),
        _StatChip(
          label: 'Blocks on defaults',
          value: summary.blocksDerivedDefaults,
        ),
        _StatChip(label: 'Blocks unresolved', value: summary.blocksUnresolved),
        _StatChip(label: 'Protocols tagged', value: summary.protocolsTagged),
        _StatChip(
          label: 'Protocols untagged',
          value: summary.protocolsUntagged,
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: CohortTextStyles.eyebrow),
          Text('$value', style: CohortTextStyles.h2),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.report,
    required this.filters,
    required this.onChanged,
  });

  final AdaptationMetadataCompletenessReport report;
  final AdaptationMetadataCompletenessFilters filters;
  final ValueChanged<AdaptationMetadataCompletenessFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButton<String?>(
          isExpanded: true,
          value: filters.programmeVersionId,
          hint: const Text('All programmes'),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All programmes'),
            ),
            for (final option in report.programmeOptions)
              DropdownMenuItem<String?>(
                value: option.versionId,
                child: Text(option.label),
              ),
          ],
          onChanged: (value) => onChanged(
            AdaptationMetadataCompletenessFilters(
              programmeVersionId: value,
              sessionType: filters.sessionType,
              missingCategory: filters.missingCategory,
              ownership: filters.ownership,
            ),
          ),
        ),
        DropdownButton<String?>(
          isExpanded: true,
          value: filters.sessionType,
          hint: const Text('All session types'),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All session types'),
            ),
            for (final type in report.sessionTypeOptions)
              DropdownMenuItem<String?>(value: type, child: Text(type)),
          ],
          onChanged: (value) => onChanged(
            AdaptationMetadataCompletenessFilters(
              programmeVersionId: filters.programmeVersionId,
              sessionType: value,
              missingCategory: filters.missingCategory,
              ownership: filters.ownership,
            ),
          ),
        ),
        DropdownButton<MissingMetadataCategory?>(
          isExpanded: true,
          value: filters.missingCategory,
          hint: const Text('Any missing category'),
          items: [
            const DropdownMenuItem<MissingMetadataCategory?>(
              value: null,
              child: Text('Any missing category'),
            ),
            for (final category in MissingMetadataCategory.values)
              DropdownMenuItem<MissingMetadataCategory?>(
                value: category,
                child: Text(_missingLabel(category)),
              ),
          ],
          onChanged: (value) => onChanged(
            AdaptationMetadataCompletenessFilters(
              programmeVersionId: filters.programmeVersionId,
              sessionType: filters.sessionType,
              missingCategory: value,
              ownership: filters.ownership,
            ),
          ),
        ),
        DropdownButton<AdaptationMetadataOwnershipFilter>(
          isExpanded: true,
          value: filters.ownership,
          items: const [
            DropdownMenuItem(
              value: AdaptationMetadataOwnershipFilter.all,
              child: Text('All ownership'),
            ),
            DropdownMenuItem(
              value: AdaptationMetadataOwnershipFilter.cohortEndorsed,
              child: Text('Cohort endorsed protocols'),
            ),
            DropdownMenuItem(
              value: AdaptationMetadataOwnershipFilter.coachAuthored,
              child: Text('Coach-authored sessions'),
            ),
            DropdownMenuItem(
              value: AdaptationMetadataOwnershipFilter.cohortGlobalProgramme,
              child: Text('Cohort global programmes'),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            onChanged(
              AdaptationMetadataCompletenessFilters(
                programmeVersionId: filters.programmeVersionId,
                sessionType: filters.sessionType,
                missingCategory: filters.missingCategory,
                ownership: value,
              ),
            );
          },
        ),
      ],
    );
  }

  static String _missingLabel(MissingMetadataCategory category) {
    return switch (category) {
      MissingMetadataCategory.missingPrimarySessionIntent =>
        'Missing primary session intent',
      MissingMetadataCategory.missingMinimumViableDuration =>
        'Missing minimum viable duration',
      MissingMetadataCategory.missingExplicitBlockMetadata =>
        'Blocks on derived defaults',
      MissingMetadataCategory.unresolvedBlockMetadata =>
        'Unresolved block metadata',
    };
  }
}

class _CompletenessTile extends StatelessWidget {
  const _CompletenessTile({required this.item, required this.onOpenBuilder});

  final AdaptationMetadataCompletenessItem item;
  final VoidCallback onOpenBuilder;

  @override
  Widget build(BuildContext context) {
    final suggestion = item.suggestedPrimarySessionIntent;
    final confirmed = item.confirmedPrimarySessionIntent;

    return CohortCard(
      onTap: onOpenBuilder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.name, style: CohortTextStyles.cardTitle),
          const SizedBox(height: CohortSpacing.xs),
          Text(
            item.slotLocationLabel ?? '${item.scope.name} · ${item.protocolId}',
            style: CohortTextStyles.small,
          ),
          if (item.programmeName != null) ...[
            const SizedBox(height: CohortSpacing.xs),
            Text(item.programmeName!, style: CohortTextStyles.small),
          ],
          const SizedBox(height: CohortSpacing.sm),
          Wrap(
            spacing: CohortSpacing.xs,
            runSpacing: CohortSpacing.xs,
            children: [
              for (final gap in item.missingCategories)
                Chip(
                  label: Text(
                    _FilterBar._missingLabel(gap),
                    style: CohortTextStyles.small,
                  ),
                  backgroundColor: CohortColors.warning.withValues(alpha: 0.15),
                ),
            ],
          ),
          const SizedBox(height: CohortSpacing.sm),
          if (confirmed != null)
            Text(
              'Confirmed intent: '
              '${AdaptationMetadataBuilderVocabulary.sessionIntentDisplayLabel(confirmed)}',
              style: CohortTextStyles.small.copyWith(
                color: CohortColors.success,
              ),
            )
          else if (suggestion != null)
            Text(
              'Suggestion (not saved): '
              '${AdaptationMetadataBuilderVocabulary.sessionIntentDisplayLabel(suggestion.intent)} · '
              '${suggestion.reason}',
              style: CohortTextStyles.small.copyWith(
                color: CohortColors.textSecondary,
              ),
            ),
          const SizedBox(height: CohortSpacing.xs),
          Text(
            'Blocks — explicit: ${item.blocks.where((b) => b.mode == BlockAdaptationMetadataMode.explicit).length}, '
            'defaults: ${item.blocks.where((b) => b.mode == BlockAdaptationMetadataMode.derivedDefaults).length}, '
            'unresolved: ${item.blocks.where((b) => b.mode == BlockAdaptationMetadataMode.unresolved).length}',
            style: CohortTextStyles.small,
          ),
          const SizedBox(height: CohortSpacing.sm),
          Text(
            'Open in Protocol Builder →',
            style: CohortTextStyles.eyebrow.copyWith(color: CohortColors.olive),
          ),
        ],
      ),
    );
  }
}
