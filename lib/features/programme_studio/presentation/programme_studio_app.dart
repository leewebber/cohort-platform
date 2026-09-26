import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../domain/programme_review_models.dart';
import 'programme_studio_athlete_view.dart';
import 'programme_studio_coach_review.dart';
import 'programme_studio_controller.dart';
import 'programme_studio_copy.dart';
import 'programme_studio_integrity_view.dart';
import 'programme_studio_labels.dart';
import 'programme_studio_quality.dart';
import 'programme_studio_quality_view.dart';

class ProgrammeStudioApp extends StatelessWidget {
  const ProgrammeStudioApp({
    super.key,
    required this.catalog,
    this.showDeveloperFixtures = false,
    this.previewStateLabel,
    this.initialSelection,
  });

  final ProgrammeReviewCatalog catalog;
  final bool showDeveloperFixtures;
  final String? previewStateLabel;
  final ProgrammeStudioSelection? initialSelection;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: cohortTheme,
      home: ProgrammeStudioScreen(
        catalog: catalog,
        showDeveloperFixtures: showDeveloperFixtures,
        previewStateLabel: previewStateLabel,
        initialSelection: initialSelection,
      ),
    );
  }
}

class ProgrammeStudioScreen extends StatefulWidget {
  const ProgrammeStudioScreen({
    super.key,
    required this.catalog,
    this.showDeveloperFixtures = false,
    this.previewStateLabel,
    this.initialSelection,
  });

  final ProgrammeReviewCatalog catalog;
  final bool showDeveloperFixtures;
  final String? previewStateLabel;
  final ProgrammeStudioSelection? initialSelection;

  @override
  State<ProgrammeStudioScreen> createState() => _ProgrammeStudioScreenState();
}

class _ProgrammeStudioScreenState extends State<ProgrammeStudioScreen> {
  late final ProgrammeStudioController controller = ProgrammeStudioController(
    catalog: widget.catalog,
    showDeveloperFixtures: widget.showDeveloperFixtures,
    initialSelection: widget.initialSelection,
  );

  @override
  void didUpdateWidget(covariant ProgrammeStudioScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.catalog != widget.catalog ||
        oldWidget.showDeveloperFixtures != widget.showDeveloperFixtures) {
      controller.replaceCatalog(widget.catalog);
      controller.setShowDeveloperFixtures(widget.showDeveloperFixtures);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.arrowUp): _MoveIntent(
              -1,
              _MoveAxis.session,
            ),
            SingleActivator(LogicalKeyboardKey.arrowDown): _MoveIntent(
              1,
              _MoveAxis.session,
            ),
            SingleActivator(LogicalKeyboardKey.arrowLeft): _MoveIntent(
              -1,
              _MoveAxis.day,
            ),
            SingleActivator(LogicalKeyboardKey.arrowRight): _MoveIntent(
              1,
              _MoveAxis.day,
            ),
            SingleActivator(LogicalKeyboardKey.keyJ): _MoveIntent(
              1,
              _MoveAxis.week,
            ),
            SingleActivator(LogicalKeyboardKey.keyK): _MoveIntent(
              -1,
              _MoveAxis.week,
            ),
            SingleActivator(LogicalKeyboardKey.digit1): _ViewIntent(
              ProgrammeStudioView.coachReview,
            ),
            SingleActivator(LogicalKeyboardKey.digit2): _ViewIntent(
              ProgrammeStudioView.qualityGate,
            ),
            SingleActivator(LogicalKeyboardKey.digit3): _ViewIntent(
              ProgrammeStudioView.athletePreview,
            ),
            SingleActivator(LogicalKeyboardKey.digit4): _ViewIntent(
              ProgrammeStudioView.technicalIntegrity,
            ),
          },
          child: Actions(
            actions: {
              _MoveIntent: CallbackAction<_MoveIntent>(
                onInvoke: (intent) {
                  switch (intent.axis) {
                    case _MoveAxis.week:
                      controller.moveWeek(intent.delta);
                    case _MoveAxis.day:
                      controller.moveDay(intent.delta);
                    case _MoveAxis.session:
                      controller.moveSession(intent.delta);
                  }
                  return null;
                },
              ),
              _ViewIntent: CallbackAction<_ViewIntent>(
                onInvoke: (intent) {
                  controller.selectView(intent.view);
                  return null;
                },
              ),
            },
            child: Focus(
              autofocus: true,
              child: Scaffold(
                backgroundColor: CohortColors.background,
                body: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _StudioHeader(
                        controller: controller,
                        previewStateLabel: widget.previewStateLabel,
                      ),
                      Expanded(child: _StudioBody(controller: controller)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _MoveAxis { week, day, session }

class _MoveIntent extends Intent {
  const _MoveIntent(this.delta, this.axis);
  final int delta;
  final _MoveAxis axis;
}

class _ViewIntent extends Intent {
  const _ViewIntent(this.view);
  final ProgrammeStudioView view;
}

class _StudioHeader extends StatelessWidget {
  const _StudioHeader({required this.controller, this.previewStateLabel});

  final ProgrammeStudioController controller;
  final String? previewStateLabel;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 900;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CohortSpacing.lg,
        CohortSpacing.md,
        CohortSpacing.lg,
        CohortSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: CohortSpacing.md,
            runSpacing: CohortSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (narrow)
                IconButton(
                  tooltip: 'Programmes',
                  onPressed: controller.toggleSidebar,
                  icon: const Icon(Icons.menu),
                ),
              Text(
                ProgrammeStudioCopy.appTitle,
                style: CohortTextStyles.h2,
                softWrap: true,
              ),
              Semantics(
                label: ProgrammeStudioCopy.internalBadge,
                child: Text(
                  ProgrammeStudioCopy.internalBadge,
                  style: CohortTextStyles.eyebrow,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: ProgrammeStudioCopy.developerMenu,
                itemBuilder: (context) => [
                  if (previewStateLabel != null)
                    PopupMenuItem(
                      enabled: false,
                      child: Text(previewStateLabel!),
                    ),
                  CheckedPopupMenuItem(
                    value: 'fixtures',
                    checked: controller.showDeveloperFixtures,
                    child: const Text(ProgrammeStudioCopy.fixturesToggle),
                  ),
                ],
                onSelected: (_) {
                  controller.setShowDeveloperFixtures(
                    !controller.showDeveloperFixtures,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: CohortSpacing.md),
          Semantics(
            label: 'Review mode navigation',
            container: true,
            child: Wrap(
              spacing: CohortSpacing.sm,
              runSpacing: CohortSpacing.sm,
              children: [
                for (final view in ProgrammeStudioView.values)
                  ChoiceChip(
                    label: Text(_viewLabel(view)),
                    selected: controller.selection.view == view,
                    selectedColor: CohortColors.oliveSoft,
                    onSelected: (_) => controller.selectView(view),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioBody extends StatelessWidget {
  const _StudioBody({required this.controller});

  final ProgrammeStudioController controller;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 900;
    if (controller.inventory.isEmpty &&
        controller.catalog.plannedFamilies.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(CohortSpacing.lg),
        child: Text(
          ProgrammeStudioCopy.emptyInventory,
          style: CohortTextStyles.body,
        ),
      );
    }
    final sidebar = _ProgrammeSidebar(controller: controller);
    final workspace = _Workspace(controller: controller);
    if (narrow) {
      return ListView(
        padding: const EdgeInsets.all(CohortSpacing.lg),
        children: [
          if (controller.narrowSidebarOpen) sidebar,
          workspace,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
            width: 300,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                CohortSpacing.lg,
                0,
                CohortSpacing.md,
                CohortSpacing.lg,
              ),
              children: [sidebar],
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              CohortSpacing.lg,
              0,
              CohortSpacing.lg,
              CohortSpacing.xl,
            ),
            children: [workspace],
          ),
        ),
      ],
    );
  }
}

class _ProgrammeSidebar extends StatelessWidget {
  const _ProgrammeSidebar({required this.controller});

  final ProgrammeStudioController controller;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Programme navigation',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ProgrammeStudioCopy.existingProgrammes,
            style: CohortTextStyles.sectionLabel,
          ),
          const SizedBox(height: CohortSpacing.sm),
          for (final item in controller.inventory)
            _ProgrammeCard(
              programme: item,
              selected:
                  controller.selectedPlannedFamily == null &&
                  item.catalogId == controller.selectedProgramme?.catalogId,
              onTap: () => controller.selectProgramme(item.catalogId),
            ),
          const SizedBox(height: CohortSpacing.xl),
          Text(
            ProgrammeStudioCopy.plannedTitle,
            style: CohortTextStyles.sectionLabel,
          ),
          const SizedBox(height: CohortSpacing.sm),
          for (final family in controller.catalog.plannedFamilies)
            _PlannedCard(
              family: family,
              selected: family.id == controller.selectedPlannedFamily?.id,
              onTap: () => controller.selectPlannedFamily(family.id),
            ),
        ],
      ),
    );
  }
}

class _ProgrammeCard extends StatelessWidget {
  const _ProgrammeCard({
    required this.programme,
    required this.selected,
    required this.onTap,
  });

  final ProgrammeReviewProgramme programme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.sm),
      child: Material(
        color: selected ? CohortColors.oliveSoft : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(CohortSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(programme.title, style: CohortTextStyles.cardTitle),
                const SizedBox(height: 4),
                Text(
                  classificationLabel(programme.classification),
                  style: CohortTextStyles.small,
                ),
                Text(
                  [
                    if (programme.durationWeeks != null)
                      '${programme.durationWeeks} weeks',
                    if (programme.sessionsPerWeek != null)
                      '${programme.sessionsPerWeek} sessions / week',
                  ].join(' · '),
                  style: CohortTextStyles.small,
                ),
                Text(
                  programmeCardStatus(programme),
                  style: CohortTextStyles.eyebrow,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlannedCard extends StatelessWidget {
  const _PlannedCard({
    required this.family,
    required this.selected,
    required this.onTap,
  });

  final ProgrammeReviewPlannedFamily family;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: selected ? CohortColors.olive : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(CohortSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    family.title,
                    style: CohortTextStyles.small.copyWith(
                      color: CohortColors.textSecondary,
                    ),
                  ),
                  const Text(
                    ProgrammeStudioCopy.plannedBadge,
                    style: CohortTextStyles.eyebrow,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Workspace extends StatelessWidget {
  const _Workspace({required this.controller});

  final ProgrammeStudioController controller;

  @override
  Widget build(BuildContext context) {
    final family = controller.selectedPlannedFamily;
    final programme = controller.selectedProgramme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (family != null)
          _PlannedHeader(family: family)
        else if (programme != null)
          _ProgrammeHeader(programme: programme),
        const SizedBox(height: CohortSpacing.xl),
        _SelectedDestination(controller: controller),
      ],
    );
  }
}

class _ProgrammeHeader extends StatelessWidget {
  const _ProgrammeHeader({required this.programme});

  final ProgrammeReviewProgramme programme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(programme.title, style: CohortTextStyles.h1),
        const SizedBox(height: CohortSpacing.sm),
        Text(
          classificationLabel(programme.classification),
          style: CohortTextStyles.eyebrow.copyWith(color: CohortColors.olive),
        ),
        const SizedBox(height: CohortSpacing.md),
        Text(
          [
            '${programme.durationWeeks ?? ProgrammeStudioCopy.notSpecified} weeks',
            '${programme.sessionsPerWeek ?? ProgrammeStudioCopy.notSpecified} sessions / week',
            'Level ${authoredOrUnspecified(programme.intendedLevel)}',
            'Equipment ${authoredOrUnspecified(programme.equipment)}',
          ].join('  ·  '),
          style: CohortTextStyles.small,
        ),
        const SizedBox(height: CohortSpacing.sm),
        Text(
          authoredOrUnspecified(programme.primaryGoal),
          style: CohortTextStyles.body,
        ),
        if (programme.catalogId == 'bali-hybrid-base-v1') ...[
          const SizedBox(height: CohortSpacing.lg),
          Text(
            ProgrammeStudioCopy.baliSummaryTitle,
            style: CohortTextStyles.sectionLabel,
          ),
          const SizedBox(height: CohortSpacing.sm),
          for (final line in [
            ProgrammeStudioCopy.baliDurationLabel,
            ProgrammeStudioCopy.baliCalendarSpan,
            ProgrammeStudioCopy.baliSessionCount,
            ProgrammeStudioCopy.baliStandardWeek,
            ProgrammeStudioCopy.baliWeek4,
            ProgrammeStudioCopy.baliWeek8,
            ProgrammeStudioCopy.baliNoRunning,
            ProgrammeStudioCopy.baliPrivate,
          ])
            Text(line, style: CohortTextStyles.small),
        ],
      ],
    );
  }
}

class _PlannedHeader extends StatelessWidget {
  const _PlannedHeader({required this.family});

  final ProgrammeReviewPlannedFamily family;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(family.title, style: CohortTextStyles.h1),
        const SizedBox(height: CohortSpacing.sm),
        Text(ProgrammeStudioCopy.plannedBadge, style: CohortTextStyles.eyebrow),
      ],
    );
  }
}

class _SelectedDestination extends StatelessWidget {
  const _SelectedDestination({required this.controller});

  final ProgrammeStudioController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.selectedPlannedFamily != null) {
      if (controller.selection.view == ProgrammeStudioView.coachReview) {
        return ProgrammeStudioCoachReview(controller: controller);
      }
      return const Text(
        ProgrammeStudioCopy.plannedEmptySessions,
        style: CohortTextStyles.body,
      );
    }
    final programme = controller.selectedProgramme;
    if (programme == null) {
      return const Text(
        ProgrammeStudioCopy.emptyInventory,
        style: CohortTextStyles.body,
      );
    }
    return switch (controller.selection.view) {
      ProgrammeStudioView.coachReview => ProgrammeStudioCoachReview(
        controller: controller,
      ),
      ProgrammeStudioView.qualityGate => ProgrammeStudioQualityView(
        programme: programme,
        onOpenIntegrity: () {
          controller.selectView(ProgrammeStudioView.technicalIntegrity);
        },
      ),
      ProgrammeStudioView.athletePreview => ProgrammeStudioAthleteView(
        programme: programme,
      ),
      ProgrammeStudioView.technicalIntegrity => ProgrammeStudioIntegrityView(
        programme: programme,
        sourceInputs: controller.catalog.sourceInputs,
        authority: controller.catalog.authority,
      ),
    };
  }
}

String _viewLabel(ProgrammeStudioView view) {
  return switch (view) {
    ProgrammeStudioView.coachReview => ProgrammeStudioCopy.coachReview,
    ProgrammeStudioView.qualityGate => ProgrammeStudioCopy.qualityGate,
    ProgrammeStudioView.athletePreview => ProgrammeStudioCopy.athletePreview,
    ProgrammeStudioView.technicalIntegrity =>
      ProgrammeStudioCopy.technicalIntegrity,
  };
}
