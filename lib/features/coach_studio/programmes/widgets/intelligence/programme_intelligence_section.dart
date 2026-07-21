import 'package:flutter/material.dart';

import '../../../../../core/theme/spacing.dart';
import '../../../../../core/theme/text_styles.dart';
import '../../../../../core/widgets/cohort_card.dart';
import '../../../../../core/widgets/section_title.dart';
import '../../controllers/programme_intelligence_controller.dart';
import '../../intelligence/programme_intelligence_copy.dart';
import '../../models/programme_intelligence_view_state.dart';
import 'programme_comparison_card.dart';
import 'programme_impact_card.dart';
import 'programme_migration_card.dart';
import 'version_overview_card.dart';

class ProgrammeIntelligenceSection extends StatefulWidget {
  const ProgrammeIntelligenceSection({
    super.key,
    required this.controller,
  });

  final ProgrammeIntelligenceController controller;

  @override
  State<ProgrammeIntelligenceSection> createState() =>
      _ProgrammeIntelligenceSectionState();
}

class _ProgrammeIntelligenceSectionState extends State<ProgrammeIntelligenceSection> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    widget.controller.load();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    final impact = state.impactSummary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CohortSpacing.lg,
        CohortSpacing.lg,
        CohortSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ProgrammeIntelligenceCopy.sectionTitle,
            style: CohortTextStyles.h2,
          ),
          const SizedBox(height: CohortSpacing.md),
          if (state.impactStatus == ProgrammeIntelligenceCardStatus.loading &&
              impact == null)
            const Center(child: CircularProgressIndicator())
          else ...[
            if (impact != null) VersionOverviewCard(summary: impact),
            const SizedBox(height: CohortSpacing.md),
            ProgrammeImpactCard(
              status: state.impactStatus,
              summary: impact,
              errorMessage: state.impactError,
              onRetry: widget.controller.loadImpact,
            ),
            const SizedBox(height: CohortSpacing.md),
            ProgrammeComparisonCard(
              currentVersionId: widget.controller.versionId,
              currentVersionNumber: impact?.versionNumber ?? 0,
              lineageVersions: state.lineageVersions,
              status: state.comparisonStatus,
              summary: state.comparisonSummary,
              isPartial: state.comparisonPartial,
              errorMessage: state.comparisonError,
              selectedTargetVersionId: state.selectedComparisonTargetVersionId,
              onTargetChanged: widget.controller.selectComparisonTarget,
              onRetry: () {
                final target = state.selectedComparisonTargetVersionId;
                if (target != null) {
                  widget.controller.selectComparisonTarget(target);
                }
              },
            ),
            const SizedBox(height: CohortSpacing.md),
            CohortCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('Migration planner'),
                  const SizedBox(height: CohortSpacing.sm),
                  ProgrammeMigrationCard(
                    status: state.migrationStatus,
                    plan: state.migrationPlan,
                    isPartial: state.migrationPartial,
                    errorMessage: state.migrationError,
                    hasComparisonTarget: state.hasComparisonTarget,
                    onRetry: () {
                      final target = state.selectedComparisonTargetVersionId;
                      if (target != null) {
                        widget.controller.selectComparisonTarget(target);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: CohortSpacing.lg),
        ],
      ),
    );
  }
}
