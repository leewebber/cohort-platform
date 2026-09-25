import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../domain/programme_review_models.dart';
import 'programme_studio_controller.dart';
import 'programme_studio_copy.dart';
import 'programme_studio_labels.dart';

class ProgrammeStudioCoachReview extends StatelessWidget {
  const ProgrammeStudioCoachReview({super.key, required this.controller});

  final ProgrammeStudioController controller;

  @override
  Widget build(BuildContext context) {
    final family = controller.selectedPlannedFamily;
    if (family != null) {
      return _PlannedEmptyState(family: family);
    }
    final programme = controller.selectedProgramme;
    final week = controller.selectedWeek;
    if (programme == null || week == null) {
      return const Text(
        ProgrammeStudioCopy.emptyInventory,
        style: CohortTextStyles.body,
      );
    }
    final weekCount = programme.weeks.length;
    final narrow = MediaQuery.sizeOf(context).width < 1100;
    final schedule = _WeekSchedule(
      week: week,
      selectedDayKey: controller.selectedDay?.dayKey,
      onSelectDay: controller.selectDay,
    );
    final detail = _SessionDetail(controller: controller);
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WeekSelector(
            week: week,
            weekCount: weekCount,
            onPrevious: () => controller.moveWeek(-1),
            onNext: () => controller.moveWeek(1),
          ),
          const SizedBox(height: CohortSpacing.lg),
          schedule,
          const SizedBox(height: CohortSpacing.xl),
          detail,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WeekSelector(
          week: week,
          weekCount: weekCount,
          onPrevious: () => controller.moveWeek(-1),
          onNext: () => controller.moveWeek(1),
        ),
        const SizedBox(height: CohortSpacing.lg),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: schedule),
              const SizedBox(width: CohortSpacing.xl),
              Expanded(flex: 6, child: detail),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlannedEmptyState extends StatelessWidget {
  const _PlannedEmptyState({required this.family});

  final ProgrammeReviewPlannedFamily family;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: CohortSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(family.title, style: CohortTextStyles.h2),
          const SizedBox(height: CohortSpacing.sm),
          Text(
            ProgrammeStudioCopy.plannedBadge,
            style: CohortTextStyles.eyebrow,
          ),
          const SizedBox(height: CohortSpacing.md),
          Text(
            'Intended duration: ${family.durationWeeks} weeks',
            style: CohortTextStyles.body,
          ),
          const SizedBox(height: CohortSpacing.sm),
          const Text(
            ProgrammeStudioCopy.plannedEmptySessions,
            style: CohortTextStyles.body,
          ),
          const SizedBox(height: CohortSpacing.sm),
          const Text(
            ProgrammeStudioCopy.plannedAuthoringClosed,
            style: CohortTextStyles.body,
          ),
        ],
      ),
    );
  }
}

class _WeekSelector extends StatelessWidget {
  const _WeekSelector({
    required this.week,
    required this.weekCount,
    required this.onPrevious,
    required this.onNext,
  });

  final ProgrammeReviewWeek week;
  final int weekCount;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final label = weekLabel(weekNumber: week.weekNumber, weekCount: weekCount);
    return Semantics(
      label: 'Week navigation, $label',
      container: true,
      child: Wrap(
        spacing: CohortSpacing.md,
        runSpacing: CohortSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          TextButton(
            onPressed: week.weekNumber <= 1 ? null : onPrevious,
            child: const Text(ProgrammeStudioCopy.previousWeek),
          ),
          Text(label, style: CohortTextStyles.h2),
          TextButton(
            onPressed: week.weekNumber >= weekCount ? null : onNext,
            child: const Text(ProgrammeStudioCopy.nextWeek),
          ),
          if (week.phaseKey != null || week.intent != null)
            Text(
              [week.phaseKey, week.intent].whereType<String>().join(' · '),
              style: CohortTextStyles.small,
            ),
        ],
      ),
    );
  }
}

class _WeekSchedule extends StatelessWidget {
  const _WeekSchedule({
    required this.week,
    required this.selectedDayKey,
    required this.onSelectDay,
  });

  final ProgrammeReviewWeek week;
  final String? selectedDayKey;
  final ValueChanged<String> onSelectDay;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Day navigation',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final day in week.days)
            _DayRow(
              day: day,
              selected: day.dayKey == selectedDayKey,
              onTap: () => onSelectDay(day.dayKey),
            ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final ProgrammeReviewDay day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final session = day.sessions.firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.sm),
      child: Material(
        color: selected ? CohortColors.oliveSoft : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CohortSpacing.md,
              vertical: CohortSpacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selected)
                  const Padding(
                    padding: EdgeInsets.only(right: CohortSpacing.sm, top: 4),
                    child: Icon(
                      Icons.circle,
                      size: 8,
                      color: CohortColors.olive,
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        weekdayLabel(day),
                        style: CohortTextStyles.cardTitle,
                      ),
                      const SizedBox(height: 4),
                      if (session == null)
                        const Text(
                          ProgrammeStudioCopy.restDay,
                          style: CohortTextStyles.small,
                        )
                      else ...[
                        Text(
                          session.displayTitle ?? session.title,
                          style: CohortTextStyles.body,
                        ),
                        Text(
                          [
                            trainingDomain(session),
                            ?safeWorkloadSummary(session),
                          ].join(' · '),
                          style: CohortTextStyles.small,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionDetail extends StatelessWidget {
  const _SessionDetail({required this.controller});

  final ProgrammeStudioController controller;

  @override
  Widget build(BuildContext context) {
    final session = controller.selectedSession;
    final day = controller.selectedDay;
    if (session == null || day == null) {
      return const Text(
        ProgrammeStudioCopy.restDay,
        style: CohortTextStyles.body,
      );
    }
    final grouped = [...session.blocks]
      ..sort((a, b) {
        final section = blockSectionOrder(
          a.blockType,
        ).compareTo(blockSectionOrder(b.blockType));
        return section != 0 ? section : a.position.compareTo(b.position);
      });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(session.displayTitle ?? session.title, style: CohortTextStyles.h2),
        const SizedBox(height: CohortSpacing.xs),
        Text(
          weekdayLabel(day),
          style: CohortTextStyles.eyebrow.copyWith(color: CohortColors.olive),
        ),
        if (coachFacingNote(session.coachNote) != null) ...[
          const SizedBox(height: CohortSpacing.sm),
          Text(coachFacingNote(session.coachNote)!, style: CohortTextStyles.body),
        ],
        if (!session.bodiesResolved) ...[
          const SizedBox(height: CohortSpacing.md),
          const Text(
            ProgrammeStudioCopy.missingProtocol,
            style: CohortTextStyles.body,
          ),
        ],
        const SizedBox(height: CohortSpacing.lg),
        for (final block in grouped) _BlockSection(block: block),
      ],
    );
  }
}

class _BlockSection extends StatelessWidget {
  const _BlockSection({required this.block});

  final ProgrammeReviewBlock block;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            blockSectionLabel(block.blockType),
            style: CohortTextStyles.eyebrow,
          ),
          const SizedBox(height: 6),
          Text(block.title, style: CohortTextStyles.cardTitle),
          if (block.coachNotes != null) ...[
            const SizedBox(height: 6),
            Text(block.coachNotes!, style: CohortTextStyles.body),
          ],
          if (humanTimerSummary(block.timerConfiguration) != null) ...[
            const SizedBox(height: 6),
            Text(
              humanTimerSummary(block.timerConfiguration)!,
              style: CohortTextStyles.small,
            ),
          ],
          if (block.unsupportedReason != null) ...[
            const SizedBox(height: CohortSpacing.sm),
            Semantics(
              label: ProgrammeStudioCopy.unsupportedBlock,
              child: Text(
                ProgrammeStudioCopy.unsupportedBlock,
                style: CohortTextStyles.body.copyWith(
                  color: CohortColors.warning,
                ),
              ),
            ),
          ],
          for (final movement in block.movements) ...[
            const SizedBox(height: CohortSpacing.md),
            Padding(
              padding: const EdgeInsets.only(left: CohortSpacing.md),
              child: _MovementLines(movement: movement),
            ),
          ],
        ],
      ),
    );
  }
}

class _MovementLines extends StatelessWidget {
  const _MovementLines({required this.movement});

  final ProgrammeReviewMovement movement;

  @override
  Widget build(BuildContext context) {
    final dose = [
      if (movement.sets != null) '${movement.sets} sets',
      if (movement.reps != null) '${movement.reps} reps',
      if (movement.duration != null) movement.duration,
      if (movement.distance != null) movement.distance,
      if (movement.recovery != null) 'Rest ${movement.recovery}',
    ].join(' · ');
    final load = movementLoadInstruction(movement);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(movement.name, style: CohortTextStyles.body),
        if (dose.isNotEmpty) Text(dose, style: CohortTextStyles.small),
        if (load != null) Text(load, style: CohortTextStyles.small),
        if (movement.notes != null)
          Text(movement.notes!, style: CohortTextStyles.small),
        if (movement.unsupportedReason != null)
          Text(
            ProgrammeStudioCopy.unsupportedMovement,
            style: CohortTextStyles.small.copyWith(color: CohortColors.warning),
          ),
      ],
    );
  }
}
