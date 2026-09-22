import 'package:flutter/material.dart';

import '../../../core/accessibility/journey_interaction.dart';
import '../../../core/theme/colors.dart';
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
            media.size.width < _stackWidth ||
            media.textScaler.scale(16) > 16 * _stackTextScale;

        final dimensions = <(String, String?, String?)>[
          ('Goal', left.primaryGoal, right.primaryGoal),
          ('Duration', left.durationDisplay, right.durationDisplay),
          ('Sessions per week', left.frequencyDisplay, right.frequencyDisplay),
          ('Intended level', left.intendedLevel, right.intendedLevel),
          ('Equipment', left.equipment, right.equipment),
          ('Training emphasis', left.trainingEmphasis, right.trainingEmphasis),
          ('Session formats', left.sessionFormats, right.sessionFormats),
          ('Progression', left.progression, right.progression),
          ('Recovery', left.recovery, right.recovery),
          ('Status', left.statusLabel, right.statusLabel),
        ].where((row) => row.$2 != null || row.$3 != null).toList();

        return Scaffold(
          appBar: AppBar(title: const Text('Compare')),
          body: SafeArea(
            child: Column(
              children: [
                _ComparisonIdentityBar(
                  leftName: left.title,
                  rightName: right.title,
                  stacked: stacked,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      CohortSpacing.lg,
                      CohortSpacing.md,
                      CohortSpacing.lg,
                      CohortSpacing.xxl,
                    ),
                    children: [
                      for (final dimension in dimensions)
                        _ComparisonCategory(
                          label: dimension.$1,
                          leftName: left.title,
                          leftValue: AthleteProgrammeDecisionFacts.compareValue(
                            dimension.$2,
                          ),
                          rightName: right.title,
                          rightValue:
                              AthleteProgrammeDecisionFacts.compareValue(
                                dimension.$3,
                              ),
                          stacked: stacked,
                        ),
                      const SizedBox(height: CohortSpacing.lg),
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
                      const SizedBox(height: CohortSpacing.lg),
                      Align(
                        alignment: Alignment.center,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: JourneyInteraction.minTapSize,
                          ),
                          child: TextButton(
                            onPressed: () {
                              controller.clearComparison();
                              Navigator.of(context).pop();
                            },
                            child: const Text(
                              AthleteProgrammeDecisionCopy.clearCompare,
                              style: CohortTextStyles.muted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ComparisonIdentityBar extends StatelessWidget {
  const _ComparisonIdentityBar({
    required this.leftName,
    required this.rightName,
    required this.stacked,
  });

  final String leftName;
  final String rightName;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final names = stacked
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(leftName, style: CohortTextStyles.h2),
              const SizedBox(height: CohortSpacing.xs),
              Text(rightName, style: CohortTextStyles.h2),
            ],
          )
        : Row(
            children: [
              Expanded(child: Text(leftName, style: CohortTextStyles.h2)),
              const SizedBox(width: CohortSpacing.md),
              Expanded(child: Text(rightName, style: CohortTextStyles.h2)),
            ],
          );

    return Material(
      color: CohortColors.surface,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: CohortColors.border)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            CohortSpacing.lg,
            CohortSpacing.sm,
            CohortSpacing.lg,
            CohortSpacing.md,
          ),
          child: names,
        ),
      ),
    );
  }
}

class _ComparisonCategory extends StatelessWidget {
  const _ComparisonCategory({
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

    final values = stacked
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _NamedValue(name: leftName, value: leftValue),
              const SizedBox(height: CohortSpacing.sm),
              _NamedValue(name: rightName, value: rightValue),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _NamedValue(name: leftName, value: leftValue),
              ),
              const SizedBox(width: CohortSpacing.md),
              Expanded(
                child: _NamedValue(name: rightName, value: rightValue),
              ),
            ],
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.lg),
      child: Semantics(
        container: true,
        label: announcement,
        child: ExcludeSemantics(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: CohortColors.surfaceRaised,
              border: Border.all(color: CohortColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(CohortSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(label, style: CohortTextStyles.eyebrow),
                  const SizedBox(height: CohortSpacing.sm),
                  values,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NamedValue extends StatelessWidget {
  const _NamedValue({required this.name, required this.value});

  final String name;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: CohortTextStyles.small),
        const SizedBox(height: 2),
        Text(
          value,
          style: CohortTextStyles.body.copyWith(
            color: CohortColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
