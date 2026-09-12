import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../presentation/athlete_calendar_agenda_presentation.dart';
import '../presentation/athlete_calendar_month_presentation.dart';

class AthleteCalendarMonthGrid extends StatelessWidget {
  const AthleteCalendarMonthGrid({
    super.key,
    required this.cells,
    required this.onSelectDate,
  });

  final List<AthleteCalendarMonthCell> cells;
  final ValueChanged<DateTime> onSelectDate;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            for (final label in _weekdays)
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: CohortTextStyles.tileLabel,
                ),
              ),
          ],
        ),
        const SizedBox(height: CohortSpacing.sm),
        for (var week = 0; week < 6; week++) ...[
          if (week > 0) const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var weekday = 0; weekday < 7; weekday++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _MonthDayCell(
                      cell: cells[week * 7 + weekday],
                      onTap: () => onSelectDate(cells[week * 7 + weekday].date),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _MonthDayCell extends StatelessWidget {
  const _MonthDayCell({required this.cell, required this.onTap});

  final AthleteCalendarMonthCell cell;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = !cell.isCurrentMonth;
    final borderColor = cell.isSelected
        ? CohortColors.phosphor
        : cell.isToday
        ? CohortColors.phosphor.withValues(alpha: 0.55)
        : CohortColors.border.withValues(alpha: muted ? 0.2 : 0.45);
    return Semantics(
      button: true,
      selected: cell.isSelected,
      label: cell.semanticsLabel,
      child: Material(
        key: ValueKey('calendar-month-day-${cell.isoDate}'),
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 78),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cell.isSelected
                    ? CohortColors.phosphor.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  width: cell.isToday || cell.isSelected ? 1.4 : 1,
                  color: borderColor,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 5, 4, 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cell.dateLabel,
                      style: CohortTextStyles.tileValue.copyWith(
                        fontSize: 13,
                        color: muted
                            ? CohortColors.textMuted.withValues(alpha: 0.55)
                            : CohortColors.textPrimary,
                      ),
                    ),
                    if (cell.isToday)
                      Text(
                        AthleteCalendarStatusCopy.today,
                        style: CohortTextStyles.tileLabel.copyWith(
                          color: CohortColors.phosphor,
                          fontSize: 8,
                        ),
                      ),
                    if (cell.compactTitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        cell.compactTitle!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: CohortTextStyles.tileLabel.copyWith(
                          fontSize: 9,
                          height: 1.15,
                          color: muted
                              ? CohortColors.textMuted
                              : CohortColors.textPrimary,
                        ),
                      ),
                    ],
                    if (cell.statusLabel != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        cell.statusLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CohortTextStyles.tileLabel.copyWith(
                          fontSize: 8,
                          color: CohortColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
