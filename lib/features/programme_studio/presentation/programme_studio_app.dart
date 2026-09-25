import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../features/programme/presentation/athlete_programme_decision_facts.dart';
import '../../../features/programme/widgets/athlete_programme_fact_list.dart';
import '../domain/programme_review_models.dart';
import 'programme_studio_controller.dart';
import 'programme_studio_copy.dart';

class ProgrammeStudioApp extends StatelessWidget {
  const ProgrammeStudioApp({
    super.key,
    required this.catalog,
    this.showDeveloperFixtures = false,
    this.previewStateLabel,
  });

  final ProgrammeReviewCatalog catalog;
  final bool showDeveloperFixtures;
  final String? previewStateLabel;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: cohortTheme,
      home: ProgrammeStudioScreen(
        catalog: catalog,
        showDeveloperFixtures: showDeveloperFixtures,
        previewStateLabel: previewStateLabel,
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
  });

  final ProgrammeReviewCatalog catalog;
  final bool showDeveloperFixtures;
  final String? previewStateLabel;

  @override
  State<ProgrammeStudioScreen> createState() => _ProgrammeStudioScreenState();
}

class _ProgrammeStudioScreenState extends State<ProgrammeStudioScreen> {
  late final ProgrammeStudioController controller = ProgrammeStudioController(
    catalog: widget.catalog,
    showDeveloperFixtures: widget.showDeveloperFixtures,
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
            SingleActivator(LogicalKeyboardKey.arrowUp): _MoveIntent(-1, _MoveAxis.session),
            SingleActivator(LogicalKeyboardKey.arrowDown): _MoveIntent(1, _MoveAxis.session),
            SingleActivator(LogicalKeyboardKey.arrowLeft): _MoveIntent(-1, _MoveAxis.day),
            SingleActivator(LogicalKeyboardKey.arrowRight): _MoveIntent(1, _MoveAxis.day),
            SingleActivator(LogicalKeyboardKey.keyJ): _MoveIntent(1, _MoveAxis.week),
            SingleActivator(LogicalKeyboardKey.keyK): _MoveIntent(-1, _MoveAxis.week),
            SingleActivator(LogicalKeyboardKey.digit1): _ViewIntent(ProgrammeStudioView.overview),
            SingleActivator(LogicalKeyboardKey.digit2): _ViewIntent(ProgrammeStudioView.structure),
            SingleActivator(LogicalKeyboardKey.digit3): _ViewIntent(ProgrammeStudioView.session),
            SingleActivator(LogicalKeyboardKey.digit4): _ViewIntent(ProgrammeStudioView.validation),
            SingleActivator(LogicalKeyboardKey.digit5): _ViewIntent(ProgrammeStudioView.athlete),
            SingleActivator(LogicalKeyboardKey.digit6): _ViewIntent(ProgrammeStudioView.readiness),
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
                        previewStateLabel: widget.previewStateLabel,
                        showFixtures: controller.showDeveloperFixtures,
                        onToggleFixtures: controller.setShowDeveloperFixtures,
                      ),
                      const Divider(height: 1, color: CohortColors.border),
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
  const _StudioHeader({
    required this.showFixtures,
    required this.onToggleFixtures,
    this.previewStateLabel,
  });

  final String? previewStateLabel;
  final bool showFixtures;
  final ValueChanged<bool> onToggleFixtures;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CohortSpacing.lg,
        CohortSpacing.md,
        CohortSpacing.lg,
        CohortSpacing.md,
      ),
      child: Wrap(
        spacing: CohortSpacing.lg,
        runSpacing: CohortSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(ProgrammeStudioCopy.appTitle, style: CohortTextStyles.h2),
          Semantics(
            label: ProgrammeStudioCopy.internalBadge,
            child: Text(
              ProgrammeStudioCopy.internalBadge,
              style: CohortTextStyles.eyebrow,
            ),
          ),
          if (previewStateLabel != null)
            Text(previewStateLabel!, style: CohortTextStyles.small),
          FilterChip(
            label: const Text(ProgrammeStudioCopy.fixturesToggle),
            selected: showFixtures,
            onSelected: onToggleFixtures,
          ),
          Text(
            ProgrammeStudioCopy.plannedTitle,
            style: CohortTextStyles.small,
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
    if (controller.inventory.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(CohortSpacing.lg),
        child: Text(ProgrammeStudioCopy.emptyInventory, style: CohortTextStyles.body),
      );
    }
    if (narrow) {
      return ListView(
        padding: const EdgeInsets.all(CohortSpacing.lg),
        children: [
          _InventoryPanel(controller: controller, compact: true),
          const SizedBox(height: CohortSpacing.lg),
          _StructureNav(controller: controller),
          const SizedBox(height: CohortSpacing.lg),
          _ViewTabs(controller: controller),
          const SizedBox(height: CohortSpacing.md),
          _SelectedView(controller: controller),
          const SizedBox(height: CohortSpacing.xl),
          _PlannedFamilies(families: controller.catalog.plannedFamilies),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 320,
          child: ListView(
            padding: const EdgeInsets.all(CohortSpacing.lg),
            children: [
              _InventoryPanel(controller: controller, compact: false),
              const SizedBox(height: CohortSpacing.xl),
              _PlannedFamilies(families: controller.catalog.plannedFamilies),
            ],
          ),
        ),
        const VerticalDivider(width: 1, color: CohortColors.border),
        SizedBox(
          width: 280,
          child: ListView(
            padding: const EdgeInsets.all(CohortSpacing.lg),
            children: [_StructureNav(controller: controller)],
          ),
        ),
        const VerticalDivider(width: 1, color: CohortColors.border),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(CohortSpacing.lg),
            children: [
              _ViewTabs(controller: controller),
              const SizedBox(height: CohortSpacing.md),
              _SelectedView(controller: controller),
            ],
          ),
        ),
      ],
    );
  }
}

class _InventoryPanel extends StatelessWidget {
  const _InventoryPanel({required this.controller, required this.compact});

  final ProgrammeStudioController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(ProgrammeStudioCopy.inventoryTitle, style: CohortTextStyles.sectionLabel),
        const SizedBox(height: CohortSpacing.sm),
        for (final item in controller.inventory)
          _InventoryCard(
            programme: item,
            selected: item.catalogId == controller.selectedProgramme?.catalogId,
            compact: compact,
            onTap: () => controller.selectProgramme(item.catalogId),
          ),
      ],
    );
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({
    required this.programme,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final ProgrammeReviewProgramme programme;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.sm),
      child: Material(
        color: selected ? CohortColors.oliveSoft : CohortColors.surface,
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
                  _classificationLabel(programme.classification),
                  style: CohortTextStyles.small,
                ),
                if (!compact) ...[
                  const SizedBox(height: CohortSpacing.sm),
                  Text(
                    _inventoryFacts(programme),
                    style: CohortTextStyles.small,
                  ),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text(ProgrammeStudioCopy.sourceDetails),
                    children: [
                      SelectableText(
                        programme.sourcePaths.join('\n'),
                        style: CohortTextStyles.small,
                      ),
                      Text(
                        '${programme.lineageCode} · v${programme.versionNumber}',
                        style: CohortTextStyles.small,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlannedFamilies extends StatelessWidget {
  const _PlannedFamilies({required this.families});

  final List<ProgrammeReviewPlannedFamily> families;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(ProgrammeStudioCopy.plannedTitle, style: CohortTextStyles.sectionLabel),
        const SizedBox(height: CohortSpacing.sm),
        for (final family in families)
          Padding(
            padding: const EdgeInsets.only(bottom: CohortSpacing.sm),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: CohortColors.border),
                color: CohortColors.surfaceRaised,
              ),
              child: Padding(
                padding: const EdgeInsets.all(CohortSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(family.title, style: CohortTextStyles.cardTitle),
                    Text(
                      '${family.durationWeeks} weeks · planned family',
                      style: CohortTextStyles.small,
                    ),
                    Text(
                      ProgrammeStudioCopy.plannedEmptySessions,
                      style: CohortTextStyles.small,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StructureNav extends StatelessWidget {
  const _StructureNav({required this.controller});

  final ProgrammeStudioController controller;

  @override
  Widget build(BuildContext context) {
    final programme = controller.selectedProgramme;
    if (programme == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Training structure', style: CohortTextStyles.sectionLabel),
        const SizedBox(height: CohortSpacing.sm),
        for (final week in programme.weeks)
          ExpansionTile(
            initiallyExpanded: week.weekNumber == controller.selectedWeek?.weekNumber,
            title: Text(week.title ?? 'Week ${week.weekNumber}'),
            onExpansionChanged: (open) {
              if (open) {
                controller.selectWeek(week.weekNumber);
              }
            },
            children: [
              for (final day in week.days)
                ListTile(
                  dense: true,
                  selected: day.dayKey == controller.selectedDay?.dayKey,
                  title: Text(day.title ?? 'Day ${day.dayOrder}'),
                  subtitle: Text(day.dayType),
                  onTap: () {
                    controller.selectWeek(week.weekNumber);
                    controller.selectDay(day.dayKey);
                    controller.selectView(ProgrammeStudioView.structure);
                  },
                ),
            ],
          ),
      ],
    );
  }
}

class _ViewTabs extends StatelessWidget {
  const _ViewTabs({required this.controller});

  final ProgrammeStudioController controller;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: CohortSpacing.sm,
      children: [
        for (final view in ProgrammeStudioView.values)
          ChoiceChip(
            label: Text(_viewLabel(view)),
            selected: controller.selection.view == view,
            onSelected: (_) => controller.selectView(view),
          ),
      ],
    );
  }
}

class _SelectedView extends StatelessWidget {
  const _SelectedView({required this.controller});

  final ProgrammeStudioController controller;

  @override
  Widget build(BuildContext context) {
    final programme = controller.selectedProgramme;
    if (programme == null) {
      return const Text(ProgrammeStudioCopy.emptyInventory);
    }
    return switch (controller.selection.view) {
      ProgrammeStudioView.overview => _OverviewPanel(programme: programme),
      ProgrammeStudioView.structure => _WeekPanel(controller: controller),
      ProgrammeStudioView.session => _SessionPanel(controller: controller),
      ProgrammeStudioView.validation => _ValidationPanel(programme: programme),
      ProgrammeStudioView.athlete => _AthletePreviewPanel(programme: programme),
      ProgrammeStudioView.readiness => _ReadinessPanel(programme: programme),
    };
  }
}

class _OverviewPanel extends StatelessWidget {
  const _OverviewPanel({required this.programme});

  final ProgrammeReviewProgramme programme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(programme.title, style: CohortTextStyles.h2),
        const SizedBox(height: CohortSpacing.sm),
        Text(_classificationLabel(programme.classification)),
        const SizedBox(height: CohortSpacing.md),
        Text(programme.description ?? 'No description authored.'),
        const SizedBox(height: CohortSpacing.md),
        Text('Goal: ${programme.primaryGoal ?? 'Not provided'}'),
        Text(
          'Duration: ${programme.durationWeeks ?? 'Not provided'} weeks · '
          'Schedule: ${programme.scheduledWeekCount ?? 0} week(s) · '
          '${programme.sessionsPerWeek ?? 'Not provided'} sessions / week',
        ),
        Text('Intended level: ${programme.intendedLevel ?? 'Not provided on Plan Package'}'),
        Text('Equipment: ${programme.equipment ?? 'Not provided on Plan Package'}'),
        Text('Lineage ${programme.lineageCode} · version ${programme.versionNumber}'),
        Text('Hash: ${programme.compile.contentHashSha256 ?? 'None'}'),
        Text(
          'Publication: ${programme.publication.detail ?? 'Not established locally'}',
        ),
        const SizedBox(height: CohortSpacing.md),
        const Text(ProgrammeStudioCopy.comparisonUnavailable),
        const SizedBox(height: CohortSpacing.md),
        const Text(
          ProgrammeStudioCopy.futureLifecycle,
          style: CohortTextStyles.small,
        ),
        const SizedBox(height: CohortSpacing.md),
        _FindingsList(findings: programme.findings),
      ],
    );
  }
}

class _WeekPanel extends StatelessWidget {
  const _WeekPanel({required this.controller});

  final ProgrammeStudioController controller;

  @override
  Widget build(BuildContext context) {
    final week = controller.selectedWeek;
    final day = controller.selectedDay;
    if (week == null || day == null) {
      return const Text('No scheduled week is available.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(week.title ?? 'Week ${week.weekNumber}', style: CohortTextStyles.h2),
        if (week.coachNote != null) Text(week.coachNote!),
        const SizedBox(height: CohortSpacing.md),
        Text(day.title ?? 'Day ${day.dayOrder}', style: CohortTextStyles.cardTitle),
        Text(day.dayType),
        if (day.coachNote != null) Text(day.coachNote!),
        const SizedBox(height: CohortSpacing.md),
        for (final session in day.sessions)
          ListTile(
            title: Text(session.displayTitle ?? session.title),
            subtitle: Text(session.protocolId),
            onTap: () => controller.selectSession(session.sessionKey),
          ),
      ],
    );
  }
}

class _SessionPanel extends StatelessWidget {
  const _SessionPanel({required this.controller});

  final ProgrammeStudioController controller;

  @override
  Widget build(BuildContext context) {
    final session = controller.selectedSession;
    if (session == null) {
      return const Text('No session selected.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(session.displayTitle ?? session.title, style: CohortTextStyles.h2),
        Text(
          '${session.protocolId} · ${session.sessionLineageId} · '
          'rev ${session.revisionNumber}',
        ),
        if (session.coachNote != null) Text(session.coachNote!),
        if (!session.bodiesResolved)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: CohortSpacing.sm),
            child: Text(ProgrammeStudioCopy.missingProtocol),
          ),
        if (session.prescriptionSummary != null)
          Text(session.prescriptionSummary!),
        const SizedBox(height: CohortSpacing.md),
        for (final block in session.blocks) _BlockCard(block: block),
        _FindingsList(findings: session.findings),
      ],
    );
  }
}

class _BlockCard extends StatelessWidget {
  const _BlockCard({required this.block});

  final ProgrammeReviewBlock block;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CohortColors.surface,
          border: Border.all(color: CohortColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(CohortSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(block.title, style: CohortTextStyles.cardTitle),
              Text('${block.blockType} · ${block.workoutFormat ?? 'no format'}'),
              if (block.content != null) Text(block.content!),
              if (block.timerConfiguration != null)
                Text('Timer: ${block.timerConfiguration}'),
              if (block.coachNotes != null) Text(block.coachNotes!),
              if (block.unsupportedReason != null)
                Semantics(
                  label: '${ProgrammeStudioCopy.unsupportedWarning}: ${block.unsupportedReason}',
                  child: Text(
                    '${ProgrammeStudioCopy.unsupportedWarning}: ${block.unsupportedReason}',
                    style: CohortTextStyles.small.copyWith(
                      color: CohortColors.warning,
                    ),
                  ),
                ),
              for (final movement in block.movements) ...[
                const SizedBox(height: CohortSpacing.sm),
                Text(movement.name, style: CohortTextStyles.body),
                Text(
                  [
                    if (movement.sets != null) 'sets ${movement.sets}',
                    if (movement.reps != null) 'reps ${movement.reps}',
                    if (movement.duration != null) 'duration ${movement.duration}',
                    if (movement.distance != null) 'distance ${movement.distance}',
                    if (movement.recovery != null) 'recovery ${movement.recovery}',
                  ].join(' · '),
                  style: CohortTextStyles.small,
                ),
                if (movement.notes != null) Text(movement.notes!),
                if (movement.unsupportedReason != null)
                  Text(
                    '${ProgrammeStudioCopy.unsupportedWarning}: ${movement.unsupportedReason}',
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ValidationPanel extends StatelessWidget {
  const _ValidationPanel({required this.programme});

  final ProgrammeReviewProgramme programme;

  @override
  Widget build(BuildContext context) {
    final compile = programme.compile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Parse: ${compile.parseOk ? 'passed' : 'failed'}'),
        Text('Validation: ${compile.validationOk ? 'passed' : 'failed'}'),
        Text(
          'Canonicalisation: ${compile.canonicalisationOk ? 'passed' : 'failed'}',
        ),
        Text('Package identity: ${programme.lineageCode} v${programme.versionNumber}'),
        Text('SHA-256: ${compile.contentHashSha256 ?? 'None'}'),
        Text(
          'Version UUID: ${programme.programmeVersionId ?? 'Not available locally'}',
        ),
        const SizedBox(height: CohortSpacing.md),
        const Text(ProgrammeStudioCopy.compilerNotLaunch),
        const SizedBox(height: CohortSpacing.md),
        _FindingsList(findings: [...compile.issues, ...programme.findings]),
      ],
    );
  }
}

class _AthletePreviewPanel extends StatelessWidget {
  const _AthletePreviewPanel({required this.programme});

  final ProgrammeReviewProgramme programme;

  @override
  Widget build(BuildContext context) {
    final facts = AthleteProgrammeDecisionFacts(
      versionId: programme.programmeVersionId ?? programme.catalogId,
      title: programme.title,
      catalogueAvailable: false,
      isCurrentProgramme: false,
      primaryGoal: programme.primaryGoal,
      intendedLevel: programme.intendedLevel,
      durationWeeks: programme.durationWeeks,
      sessionsPerWeek: programme.sessionsPerWeek,
      equipment: programme.equipment,
      summary: programme.description,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(ProgrammeStudioCopy.athletePreviewBanner),
        const SizedBox(height: CohortSpacing.md),
        AthleteProgrammeGlanceTiles(facts: facts),
        const SizedBox(height: CohortSpacing.md),
        Text(facts.summaryLabel, style: CohortTextStyles.body),
      ],
    );
  }
}

class _ReadinessPanel extends StatelessWidget {
  const _ReadinessPanel({required this.programme});

  final ProgrammeReviewProgramme programme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(ProgrammeStudioCopy.compilerNotLaunch),
        const SizedBox(height: CohortSpacing.md),
        for (final check in programme.readiness)
          Padding(
            padding: const EdgeInsets.only(bottom: CohortSpacing.sm),
            child: Semantics(
              label: '${check.label}: ${_statusLabel(check.status)}. ${check.detail}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${check.label} — ${_statusLabel(check.status)}',
                    style: CohortTextStyles.cardTitle,
                  ),
                  Text(check.detail, style: CohortTextStyles.small),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _FindingsList extends StatelessWidget {
  const _FindingsList({required this.findings});

  final List<ProgrammeReviewFinding> findings;

  @override
  Widget build(BuildContext context) {
    if (findings.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Findings', style: CohortTextStyles.sectionLabel),
        const SizedBox(height: CohortSpacing.sm),
        for (final finding in findings)
          Padding(
            padding: const EdgeInsets.only(bottom: CohortSpacing.sm),
            child: Text(
              '${finding.severity.name}: ${finding.message}'
              '${finding.sourceContext == null ? '' : ' (${finding.sourceContext})'}',
            ),
          ),
      ],
    );
  }
}

String _classificationLabel(ProgrammeReviewClassification value) {
  return switch (value) {
    ProgrammeReviewClassification.productionPublished => 'Production-published',
    ProgrammeReviewClassification.internalPersonal => 'Internal / personal',
    ProgrammeReviewClassification.legacyWithheld => 'Legacy / withheld',
    ProgrammeReviewClassification.fixtureTestExample => 'Fixture / test / example',
    ProgrammeReviewClassification.plannedFamily => 'Approved planned family',
  };
}

String _inventoryFacts(ProgrammeReviewProgramme programme) {
  return [
    if (programme.durationWeeks != null) '${programme.durationWeeks} weeks',
    if (programme.sessionsPerWeek != null)
      '${programme.sessionsPerWeek} sessions / week',
    if (programme.compile.contentHashSha256 != null)
      'hash ${programme.compile.contentHashSha256!.substring(0, 8)}…',
    programme.compile.validationOk ? 'compiler passed' : 'compiler failed',
  ].join(' · ');
}

String _viewLabel(ProgrammeStudioView view) {
  return switch (view) {
    ProgrammeStudioView.overview => ProgrammeStudioCopy.overview,
    ProgrammeStudioView.structure => ProgrammeStudioCopy.structure,
    ProgrammeStudioView.session => ProgrammeStudioCopy.session,
    ProgrammeStudioView.validation => ProgrammeStudioCopy.validation,
    ProgrammeStudioView.athlete => ProgrammeStudioCopy.athlete,
    ProgrammeStudioView.readiness => ProgrammeStudioCopy.readiness,
  };
}

String _statusLabel(ProgrammeReviewCheckStatus status) {
  return switch (status) {
    ProgrammeReviewCheckStatus.passed => 'Passed',
    ProgrammeReviewCheckStatus.failed => 'Failed',
    ProgrammeReviewCheckStatus.notImplemented => 'Not implemented',
    ProgrammeReviewCheckStatus.notAssessed => 'Not assessed',
  };
}
