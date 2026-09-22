import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../home/controllers/home_today_session_refresh_controller.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/cohort_card.dart';
import '../controllers/athlete_programme_controllers.dart';
import '../presentation/athlete_programme_decision_copy.dart';
import '../presentation/athlete_programme_decision_facts.dart';
import '../widgets/athlete_programme_fact_list.dart';
import 'athlete_programme_enrolment_review_screen.dart';

class AthleteProgrammeDetailScreen extends StatelessWidget {
  const AthleteProgrammeDetailScreen({
    super.key,
    required this.controller,
    required this.versionId,
    this.refreshController,
  });

  final AthleteProgrammeSelectionController controller;
  final String versionId;
  final HomeTodaySessionRefreshController? refreshController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final entry = controller.entryByVersionId(versionId);
        if (entry == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Programme')),
            body: const SafeArea(
              child: Padding(
                padding: EdgeInsets.all(CohortSpacing.lg),
                child: CohortCard(
                  child: Text(
                    AthleteProgrammeDecisionCopy.detailUnavailable,
                    style: CohortTextStyles.body,
                  ),
                ),
              ),
            ),
          );
        }

        final facts = AthleteProgrammeDecisionFacts.fromEntry(
          entry,
          isCurrentProgramme: controller.isCurrentProgramme(entry),
        );

        return Scaffold(
          appBar: AppBar(title: const Text('Programme')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                CohortSpacing.lg,
                CohortSpacing.md,
                CohortSpacing.lg,
                CohortSpacing.xxl,
              ),
              children: [
                _ProgrammeHero(facts: facts),
                const SizedBox(height: CohortSpacing.xl),
                AthleteProgrammeGlanceTiles(facts: facts),
                if (facts.hasSupportingInformation) ...[
                  const SizedBox(height: CohortSpacing.xl),
                  _SupportingInformation(facts: facts),
                ],
                const SizedBox(height: CohortSpacing.xl),
                _DecisionArea(
                  controller: controller,
                  facts: facts,
                  refreshController: refreshController,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProgrammeHero extends StatelessWidget {
  const _ProgrammeHero({required this.facts});

  final AthleteProgrammeDecisionFacts facts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AthleteProgrammeStatusChip(label: facts.statusLabel),
        const SizedBox(height: CohortSpacing.md),
        Semantics(
          header: true,
          child: Text(facts.title, style: CohortTextStyles.h1),
        ),
        if (facts.primaryGoal != null) ...[
          const SizedBox(height: CohortSpacing.sm),
          Text(facts.primaryGoal!, style: CohortTextStyles.h2),
        ],
        if (facts.summary != null) ...[
          const SizedBox(height: CohortSpacing.md),
          Text(facts.summary!, style: CohortTextStyles.body),
        ],
      ],
    );
  }
}

class _SupportingInformation extends StatelessWidget {
  const _SupportingInformation({required this.facts});

  final AthleteProgrammeDecisionFacts facts;

  @override
  Widget build(BuildContext context) {
    final present = facts.supportingFacts
        .where((fact) => fact.$2 != null)
        .toList(growable: false);

    return CohortCard(
      padding: const EdgeInsets.all(CohortSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < present.length; i++) ...[
            if (i > 0) const SizedBox(height: CohortSpacing.md),
            Text(present[i].$1, style: CohortTextStyles.eyebrow),
            const SizedBox(height: CohortSpacing.xs),
            Text(present[i].$2!, style: CohortTextStyles.body),
          ],
        ],
      ),
    );
  }
}

class _DecisionArea extends StatelessWidget {
  const _DecisionArea({
    required this.controller,
    required this.facts,
    this.refreshController,
  });

  final AthleteProgrammeSelectionController controller;
  final AthleteProgrammeDecisionFacts facts;
  final HomeTodaySessionRefreshController? refreshController;

  @override
  Widget build(BuildContext context) {
    if (facts.isCurrentProgramme) {
      return const SizedBox.shrink();
    }

    if (controller.hasActiveAssignment) {
      return const CohortCard(
        padding: EdgeInsets.all(CohortSpacing.md),
        child: Text(
          AthleteProgrammeDecisionCopy.switchingUnavailable,
          style: CohortTextStyles.body,
        ),
      );
    }

    if (!facts.catalogueAvailable) {
      return const CohortCard(
        padding: EdgeInsets.all(CohortSpacing.md),
        child: Text(
          AthleteProgrammeDecisionCopy.detailUnavailable,
          style: CohortTextStyles.body,
        ),
      );
    }

    return CohortButton(
      label: AthleteProgrammeDecisionCopy.enrol,
      semanticHint: 'Review enrolment in ${facts.title}',
      onPressed: controller.isSubmitting
          ? null
          : () {
              final entry = controller.entryByVersionId(facts.versionId);
              if (entry == null) return;
              controller.selectProgramme(entry);
              Navigator.of(context)
                  .push<bool>(
                    MaterialPageRoute(
                      builder: (_) => AthleteProgrammeEnrolmentReviewScreen(
                        controller: controller,
                        versionId: facts.versionId,
                        refreshController: refreshController,
                      ),
                    ),
                  )
                  .then((enrolled) {
                    if (enrolled == true && context.mounted) {
                      Navigator.of(context).pop(true);
                    }
                  });
            },
    );
  }
}

class AthleteProgrammeDetailRoute {
  const AthleteProgrammeDetailRoute._();

  static Future<bool?> open({
    required BuildContext context,
    required AthleteProgrammeSelectionController controller,
    required String versionId,
    HomeTodaySessionRefreshController? refreshController,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AthleteProgrammeDetailScreen(
          controller: controller,
          versionId: versionId,
          refreshController: refreshController,
        ),
      ),
    );
  }
}
