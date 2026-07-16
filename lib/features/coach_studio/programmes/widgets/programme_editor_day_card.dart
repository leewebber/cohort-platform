import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../models/programme_day_draft.dart';
import '../../../../models/programme_vocabulary.dart';
import '../../../programme_builder/models/programme_builder_constants.dart';
import '../../../programme_builder/models/programme_builder_path.dart';
import '../controllers/programme_editor_controller.dart';

class ProgrammeEditorDayCard extends StatelessWidget {
  const ProgrammeEditorDayCard({
    super.key,
    required this.controller,
    required this.weekLocalId,
    required this.day,
    required this.onSelectSlot,
  });

  final ProgrammeEditorController controller;
  final String weekLocalId;
  final ProgrammeDayDraft day;
  final void Function(String slotLocalId) onSelectSlot;

  @override
  Widget build(BuildContext context) {
    final dayPath = ProgrammeBuilderDayPath(
      weekLocalId: weekLocalId,
      dayLocalId: day.localId,
    );
    final dayIssues = controller.issuesForPath(dayPath);
    final hasErrors = dayIssues.any((issue) => issue.isBlocking);

    return Card(
      margin: const EdgeInsets.only(bottom: CohortSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(CohortSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _dayTitle(day),
                    style: CohortTextStyles.cardTitle,
                  ),
                ),
                _DayTypeBadge(dayType: day.dayType),
                if (hasErrors)
                  const Padding(
                    padding: EdgeInsets.only(left: CohortSpacing.sm),
                    child: Icon(
                      Icons.error_outline,
                      color: CohortColors.danger,
                      size: 18,
                    ),
                  ),
                if (!controller.isReadOnly)
                  PopupMenuButton<String>(
                    onSelected: (value) => _handleMenu(context, value),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'training', child: Text('Training')),
                      PopupMenuItem(value: 'rest', child: Text('Rest')),
                      PopupMenuItem(value: 'remove', child: Text('Remove day')),
                    ],
                  ),
              ],
            ),
            if (day.intent != null) ...[
              const SizedBox(height: CohortSpacing.xs),
              Text(
                day.intent!.name,
                style: CohortTextStyles.small,
              ),
            ],
            const SizedBox(height: CohortSpacing.sm),
            if (day.isRestDay)
              Text('Rest day', style: CohortTextStyles.body)
            else
              ...day.slots.map((slot) {
                final slotPath = ProgrammeBuilderSlotPath(
                  weekLocalId: weekLocalId,
                  dayLocalId: day.localId,
                  slotLocalId: slot.localId,
                );
                final slotIssues = controller.issuesForPath(slotPath);
                final hasSlotError =
                    slotIssues.any((issue) => issue.isBlocking);
                final protocolLabel =
                    ProgrammeBuilderConstants.isUnassignedProtocolId(
                      slot.protocolId,
                    )
                        ? 'No protocol'
                        : slot.protocolId;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Slot ${slot.sessionOrder} · $protocolLabel',
                    style: CohortTextStyles.body,
                  ),
                  subtitle: Text(
                    [
                      if (slot.isOptional) 'Optional',
                      if (slot.displayTitle != null) slot.displayTitle!,
                    ].join(' • '),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasSlotError)
                        const Icon(
                          Icons.error_outline,
                          color: CohortColors.danger,
                          size: 16,
                        ),
                      TextButton(
                        onPressed: () => onSelectSlot(slot.localId),
                        child: const Text('Edit'),
                      ),
                    ],
                  ),
                  onTap: () => onSelectSlot(slot.localId),
                );
              }),
            if (!controller.isReadOnly && !day.isRestDay)
              TextButton(
                onPressed: () => controller.addSlot(day.localId),
                child: const Text('+ Slot'),
              ),
          ],
        ),
      ),
    );
  }

  String _dayTitle(ProgrammeDayDraft day) {
    final title = day.title?.trim();
    if (title != null && title.isNotEmpty) {
      return '${day.dayKey} · $title';
    }
    return day.dayKey.replaceAll('_', ' ');
  }

  Future<void> _handleMenu(BuildContext context, String value) async {
    switch (value) {
      case 'training':
        await controller.setDayType(
          dayLocalId: day.localId,
          dayType: ProgrammeDayType.training,
        );
      case 'rest':
        if (day.slots.isNotEmpty) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Convert to rest day?'),
              content: Text(
                'Converting to rest will remove ${day.slots.length} slot(s).',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Convert'),
                ),
              ],
            ),
          );
          if (confirmed != true) return;
        }
        await controller.setDayType(
          dayLocalId: day.localId,
          dayType: ProgrammeDayType.rest,
        );
      case 'remove':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remove day?'),
            content: const Text('This day will be removed from the week.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Remove'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await controller.removeDay(day.localId);
        }
    }
  }
}

class _DayTypeBadge extends StatelessWidget {
  const _DayTypeBadge({required this.dayType});

  final ProgrammeDayType dayType;

  @override
  Widget build(BuildContext context) {
    final label = switch (dayType) {
      ProgrammeDayType.training => 'Training',
      ProgrammeDayType.rest => 'Rest',
      ProgrammeDayType.optional => 'Optional',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: CohortColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: CohortTextStyles.small),
    );
  }
}
