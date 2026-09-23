import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../home/controllers/home_today_session_refresh_controller.dart';
import '../controllers/athlete_programme_controllers.dart';
import '../models/programme_catalog_entry.dart';
import '../presentation/athlete_programme_decision_copy.dart';
import '../presentation/athlete_programme_decision_facts.dart';
import '../services/athlete_catalogue_enrolment_services.dart';
import '../widgets/athlete_programme_fact_list.dart';
import 'athlete_programme_comparison_screen.dart';
import 'athlete_programme_detail_screen.dart';

/// Athlete catalogue: discover, inspect, compare, and enrol when unassigned.
class AthleteProgrammeSelectionScreen extends StatefulWidget {
  const AthleteProgrammeSelectionScreen({
    super.key,
    required this.athleteId,
    this.refreshController,
    this.controller,
  });

  final String athleteId;
  final HomeTodaySessionRefreshController? refreshController;
  final AthleteProgrammeSelectionController? controller;

  @override
  State<AthleteProgrammeSelectionScreen> createState() =>
      _AthleteProgrammeSelectionScreenState();
}

class _AthleteProgrammeSelectionScreenState
    extends State<AthleteProgrammeSelectionScreen> {
  late final AthleteProgrammeSelectionController _controller =
      widget.controller ??
      AthleteCatalogueEnrolmentServices.createSelectionController(
        athleteId: widget.athleteId,
      );

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _controller.load();
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _openDetail(ProgrammeCatalogEntry entry) async {
    final enrolled = await AthleteProgrammeDetailRoute.open(
      context: context,
      controller: _controller,
      versionId: entry.versionId,
      refreshController: widget.refreshController,
    );
    if (enrolled == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _openComparison() async {
    final enrolled = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AthleteProgrammeComparisonScreen(
          controller: _controller,
          refreshController: widget.refreshController,
        ),
      ),
    );
    if (enrolled == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AthleteProgrammeDecisionCopy.catalogueTitle),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(CohortSpacing.lg),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.isLoading) {
      return Center(
        child: Semantics(
          liveRegion: true,
          label: AthleteProgrammeDecisionCopy.catalogueLoading,
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_controller.errorMessage != null) {
      return CohortCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              AthleteProgrammeDecisionCopy.catalogueUnavailable,
              style: CohortTextStyles.body,
            ),
            const SizedBox(height: CohortSpacing.md),
            Text(_controller.errorMessage!, style: CohortTextStyles.muted),
            const SizedBox(height: CohortSpacing.md),
            CohortButton(
              label: AthleteProgrammeDecisionCopy.retry,
              onPressed: _controller.isSubmitting ? null : _controller.load,
            ),
          ],
        ),
      );
    }

    if (_controller.programmes.isEmpty) {
      return const CohortCard(
        child: Text(
          AthleteProgrammeDecisionCopy.catalogueEmpty,
          style: CohortTextStyles.body,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          AthleteProgrammeDecisionCopy.catalogueIntro,
          style: CohortTextStyles.body,
        ),
        const SizedBox(height: CohortSpacing.lg),
        if (_controller.comparisonVersionIds.length == 2) ...[
          CohortButton(
            label: AthleteProgrammeDecisionCopy.compareNow,
            onPressed: _openComparison,
          ),
          const SizedBox(height: CohortSpacing.md),
        ],
        Expanded(
          child: ListView.separated(
            itemCount: _controller.programmes.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: CohortSpacing.sm),
            itemBuilder: (context, index) {
              final entry = _controller.programmes[index];
              return _AthleteProgrammeCatalogCard(
                facts: AthleteProgrammeDecisionFacts.fromEntry(
                  entry,
                  isCurrentProgramme: _controller.isCurrentProgramme(entry),
                  catalogueDefaultVersionId: _controller
                      .catalogueDefaultVersionId(entry.lineageCode),
                ),
                selectedForCompare: _controller.isSelectedForCompare(entry),
                onViewDetails: () => _openDetail(entry),
                onToggleCompare: () => _controller.toggleCompare(entry),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AthleteProgrammeCatalogCard extends StatelessWidget {
  const _AthleteProgrammeCatalogCard({
    required this.facts,
    required this.selectedForCompare,
    required this.onViewDetails,
    required this.onToggleCompare,
  });

  final AthleteProgrammeDecisionFacts facts;
  final bool selectedForCompare;
  final VoidCallback onViewDetails;
  final VoidCallback onToggleCompare;

  @override
  Widget build(BuildContext context) {
    return CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(facts.title, style: CohortTextStyles.cardTitle),
              ),
              AthleteProgrammeStatusChip(label: facts.statusLabel),
            ],
          ),
          const SizedBox(height: CohortSpacing.sm),
          Text(facts.goalLabel, style: CohortTextStyles.body),
          const SizedBox(height: CohortSpacing.xs),
          Text(
            [
              facts.durationLabel,
              facts.frequencyLabel,
              facts.levelLabel,
            ].join(' · '),
            style: CohortTextStyles.small.copyWith(
              color: CohortColors.textMuted,
            ),
          ),
          if (facts.summary != null) ...[
            const SizedBox(height: CohortSpacing.xs),
            Text(
              facts.summary!,
              style: CohortTextStyles.small,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: CohortSpacing.md),
          CohortButton(
            label: AthleteProgrammeDecisionCopy.viewDetails,
            variant: CohortButtonVariant.secondary,
            onPressed: onViewDetails,
          ),
          const SizedBox(height: CohortSpacing.sm),
          CohortButton(
            label: selectedForCompare
                ? AthleteProgrammeDecisionCopy.selectedForCompare
                : AthleteProgrammeDecisionCopy.compare,
            variant: CohortButtonVariant.secondary,
            semanticHint: selectedForCompare
                ? 'Remove ${facts.title} from comparison'
                : 'Add ${facts.title} to comparison',
            onPressed: onToggleCompare,
          ),
        ],
      ),
    );
  }
}
