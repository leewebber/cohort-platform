import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_card.dart';
import '../models/fixed_programme_occurrence_projection.dart';

class FixedProgrammeWeekView extends StatelessWidget {
  const FixedProgrammeWeekView({
    super.key,
    required this.projection,
    this.onOccurrenceTap,
  });

  final FixedProgrammeCalendarProjection projection;
  final ValueChanged<FixedProgrammeOccurrenceProjection>? onOccurrenceTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final day in projection.currentWeek) ...[
          _FixedProgrammeDayCard(day: day, onTap: onOccurrenceTap),
          if (day != projection.currentWeek.last)
            const SizedBox(height: CohortSpacing.sm),
        ],
      ],
    );
  }
}

class _FixedProgrammeDayCard extends StatelessWidget {
  const _FixedProgrammeDayCard({required this.day, this.onTap});

  final FixedProgrammeCalendarDayProjection day;
  final ValueChanged<FixedProgrammeOccurrenceProjection>? onTap;

  @override
  Widget build(BuildContext context) {
    final occurrence = day.occurrence;
    final date = DateTime.parse(day.date);
    final content = CohortCard(
      child: Row(
        children: [
          SizedBox(
            width: 104,
            child: Text(
              '${_weekday(date.weekday)} ${_month(date.month)} ${date.day}',
              style: CohortTextStyles.small,
            ),
          ),
          Expanded(
            child: Text(
              occurrence?.sessionTitle ?? 'Rest',
              style: CohortTextStyles.body,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!day.isRest) ...[
            const SizedBox(width: CohortSpacing.sm),
            Text(day.state.displayLabel, style: CohortTextStyles.small),
          ],
        ],
      ),
    );
    if (occurrence == null || onTap == null) return content;
    return Semantics(
      button: true,
      label: 'View ${occurrence.sessionTitle} on ${day.date}',
      child: InkWell(onTap: () => onTap!(occurrence), child: content),
    );
  }

  String _weekday(int weekday) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];

  String _month(int month) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month - 1];
}
