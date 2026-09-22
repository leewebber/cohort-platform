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
          appBar: AppBar(title: Text(facts.title)),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(CohortSpacing.lg),
              children: [
                Text(facts.title, style: CohortTextStyles.h1),
                const SizedBox(height: CohortSpacing.sm),
                AthleteProgrammeStatusChip(label: facts.statusLabel),
                if (controller.hasActiveAssignment &&
                    !facts.isCurrentProgramme) ...[
                  const SizedBox(height: CohortSpacing.md),
                  const Text(
                    AthleteProgrammeDecisionCopy.switchingUnavailable,
                    style: CohortTextStyles.body,
                  ),
                ],
                const SizedBox(height: CohortSpacing.xl),
                AthleteProgrammeFactList(facts: facts),
                const SizedBox(height: CohortSpacing.lg),
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
      return const CohortCard(
        child: Text(
          AthleteProgrammeDecisionCopy.currentProgramme,
          style: CohortTextStyles.body,
        ),
      );
    }

    if (controller.hasActiveAssignment) {
      return const CohortCard(
        child: Text(
          AthleteProgrammeDecisionCopy.switchingUnavailable,
          style: CohortTextStyles.body,
        ),
      );
    }

    if (!facts.catalogueAvailable) {
      return const CohortCard(
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
              Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => AthleteProgrammeEnrolmentReviewScreen(
                    controller: controller,
                    versionId: facts.versionId,
                    refreshController: refreshController,
                  ),
                ),
              ).then((enrolled) {
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
