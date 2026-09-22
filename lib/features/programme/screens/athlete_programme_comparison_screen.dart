import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../home/controllers/home_today_session_refresh_controller.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/cohort_card.dart';
import '../controllers/athlete_programme_controllers.dart';
import '../presentation/athlete_programme_decision_copy.dart';
import '../presentation/athlete_programme_decision_facts.dart';
import 'athlete_programme_detail_screen.dart';

class AthleteProgrammeComparisonScreen extends StatelessWidget {
  const AthleteProgrammeComparisonScreen({
    super.key,
    required this.controller,
    this.refreshController,
  });

  final AthleteProgrammeSelectionController controller;
  final HomeTodaySessionRefreshController? refreshController;

  static const _stackWidth = 390.0;
  static const _stackTextScale = 1.3;

  Future<void> _openDetail(BuildContext context, String versionId) async {
    final enrolled = await AthleteProgrammeDetailRoute.open(
      context: context,
      controller: controller,
      versionId: versionId,
      refreshController: refreshController,
    );
    if (enrolled == true && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final selections = controller.comparisonSelections;
        if (selections.length < 2) {
          return Scaffold(
            appBar: AppBar(title: const Text('Compare')),
            body: const SafeArea(
              child: Padding(
                padding: EdgeInsets.all(CohortSpacing.lg),
                child: CohortCard(
                  child: Text(
                    AthleteProgrammeDecisionCopy.compareNeedTwo,
                    style: CohortTextStyles.body,
                  ),
                ),
              ),
            ),
          );
        }

        if (selections.length != controller.comparisonVersionIds.length) {
          return Scaffold(
            appBar: AppBar(title: const Text('Compare')),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(CohortSpacing.lg),
                child: CohortCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        AthleteProgrammeDecisionCopy.compareUnavailable,
                        style: CohortTextStyles.body,
                      ),
                      const SizedBox(height: CohortSpacing.md),
                      CohortButton(
                        label: AthleteProgrammeDecisionCopy.clearCompare,
                        variant: CohortButtonVariant.secondary,
                        onPressed: controller.clearComparison,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final left = AthleteProgrammeDecisionFacts.fromEntry(
          selections[0],
          isCurrentProgramme: controller.isCurrentProgramme(selections[0]),
        );
        final right = AthleteProgrammeDecisionFacts.fromEntry(
          selections[1],
          isCurrentProgramme: controller.isCurrentProgramme(selections[1]),
        );

        final media = MediaQuery.of(context);
        final stacked =
            media.size.width < _stackWidth || media.textScaler.scale(16) > 16 * _stackTextScale;

        final dimensions = <(String, String, String)>[
          ('Goal', left.goalLabel, right.goalLabel),
          ('Intended level', left.levelLabel, right.levelLabel),
          ('Duration', left.durationLabel, right.durationLabel),
          ('Sessions per week', left.frequencyLabel, right.frequencyLabel),
          ('Training emphasis', left.emphasisLabel, right.emphasisLabel),
          ('Equipment', left.equipmentLabel, right.equipmentLabel),
          ('Session formats', left.formatsLabel, right.formatsLabel),
          ('Progression', left.progressionLabel, right.progressionLabel),
          ('Recovery', left.recoveryLabel, right.recoveryLabel),
          ('Status', left.statusLabel, right.statusLabel),
        ];

        return Scaffold(
          appBar: AppBar(title: const Text('Compare')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(CohortSpacing.lg),
              children: [
                Text(
                  '${left.title} and ${right.title}',
                  style: CohortTextStyles.h2,
                ),
                const SizedBox(height: CohortSpacing.lg),
                for (final dimension in dimensions)
                  _ComparisonRow(
                    label: dimension.$1,
                    leftName: left.title,
                    leftValue: dimension.$2,
                    rightName: right.title,
                    rightValue: dimension.$3,
                    stacked: stacked,
                  ),
                const SizedBox(height: CohortSpacing.xl),
                CohortButton(
                  label: 'View ${left.title}',
                  variant: CohortButtonVariant.secondary,
                  onPressed: () => _openDetail(context, left.versionId),
                ),
                const SizedBox(height: CohortSpacing.md),
                CohortButton(
                  label: 'View ${right.title}',
                  variant: CohortButtonVariant.secondary,
                  onPressed: () => _openDetail(context, right.versionId),
                ),
                const SizedBox(height: CohortSpacing.md),
                CohortButton(
                  label: AthleteProgrammeDecisionCopy.clearCompare,
                  variant: CohortButtonVariant.secondary,
                  onPressed: () {
                    controller.clearComparison();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.label,
    required this.leftName,
    required this.leftValue,
    required this.rightName,
    required this.rightValue,
    required this.stacked,
  });

  final String label;
  final String leftName;
  final String leftValue;
  final String rightName;
  final String rightValue;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final announcement = AthleteProgrammeDecisionCopy.comparisonAnnouncement(
      dimension: label,
      leftName: leftName,
      leftValue: leftValue,
      rightName: rightName,
      rightValue: rightValue,
    );

    final content = stacked
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label, style: CohortTextStyles.eyebrow),
              const SizedBox(height: CohortSpacing.xs),
              Text('$leftName: $leftValue', style: CohortTextStyles.body),
              const SizedBox(height: CohortSpacing.xs),
              Text('$rightName: $rightValue', style: CohortTextStyles.body),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label, style: CohortTextStyles.eyebrow),
              const SizedBox(height: CohortSpacing.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(leftValue, style: CohortTextStyles.body),
                  ),
                  const SizedBox(width: CohortSpacing.md),
                  Expanded(
                    child: Text(rightValue, style: CohortTextStyles.body),
                  ),
                ],
              ),
            ],
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.lg),
      child: Semantics(
        container: true,
        label: announcement,
        child: ExcludeSemantics(child: content),
      ),
    );
  }
}
