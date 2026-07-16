import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../models/programme_week_draft.dart';
import '../../../programme_builder/models/programme_builder_path.dart';
import '../../../programme_builder/models/programme_validation_result.dart';
import '../controllers/programme_editor_controller.dart';

class ProgrammeEditorWeekNav extends StatelessWidget {
  const ProgrammeEditorWeekNav({
    super.key,
    required this.controller,
    required this.isCompact,
  });

  final ProgrammeEditorController controller;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final document = controller.document;
    if (document == null) return const SizedBox.shrink();

    final weeks = document.template.allWeeks;
    final selectedWeekId = controller.selection.weekLocalId;

    if (isCompact) {
      return _CompactWeekNav(
        controller: controller,
        weeks: weeks,
        selectedWeekId: selectedWeekId,
      );
    }

    return Container(
      width: 240,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: CohortColors.border)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(CohortSpacing.md),
        children: [
          Text('Weeks', style: CohortTextStyles.body),
          const SizedBox(height: CohortSpacing.sm),
          for (final week in weeks)
            _WeekTile(
              weekNumber: week.weekNumber,
              title: week.title,
              selected: week.localId == selectedWeekId,
              hasIssues: _hasWeekIssues(controller, week.localId),
              onTap: () => controller.selectWeek(week.localId),
              onDuplicate: controller.isReadOnly
                  ? null
                  : () => controller.duplicateWeek(week.localId),
              onDelete: controller.isReadOnly
                  ? null
                  : () => _confirmRemoveWeek(context, week.localId),
            ),
          if (!controller.isReadOnly)
            TextButton(
              onPressed: controller.addWeek,
              child: const Text('+ Week'),
            ),
        ],
      ),
    );
  }

  bool _hasWeekIssues(ProgrammeEditorController controller, String weekLocalId) {
    return controller
        .issuesForPath(ProgrammeBuilderWeekPath(weekLocalId: weekLocalId))
        .any((issue) => issue.isBlocking);
  }

  Future<void> _confirmRemoveWeek(BuildContext context, String weekLocalId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove week?'),
        content: const Text(
          'Removing the last week will replace it with an empty Week 1.',
        ),
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
      await controller.removeWeek(weekLocalId);
    }
  }
}

class _CompactWeekNav extends StatelessWidget {
  const _CompactWeekNav({
    required this.controller,
    required this.weeks,
    required this.selectedWeekId,
  });

  final ProgrammeEditorController controller;
  final List<ProgrammeWeekDraft> weeks;
  final String? selectedWeekId;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: CohortSpacing.md,
        vertical: CohortSpacing.sm,
      ),
      child: Row(
        children: [
          for (final week in weeks)
            Padding(
              padding: const EdgeInsets.only(right: CohortSpacing.sm),
              child: ChoiceChip(
                label: Text('Week ${week.weekNumber}'),
                selected: week.localId == selectedWeekId,
                onSelected: (_) => controller.selectWeek(week.localId),
              ),
            ),
          if (!controller.isReadOnly)
            ActionChip(
              label: const Text('+ Week'),
              onPressed: controller.addWeek,
            ),
        ],
      ),
    );
  }
}

class _WeekTile extends StatelessWidget {
  const _WeekTile({
    required this.weekNumber,
    required this.title,
    required this.selected,
    required this.hasIssues,
    required this.onTap,
    this.onDuplicate,
    this.onDelete,
  });

  final int weekNumber;
  final String? title;
  final bool selected;
  final bool hasIssues;
  final VoidCallback onTap;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: selected,
      title: Text(title == null || title!.isEmpty
          ? 'Week $weekNumber'
          : 'Week $weekNumber — $title'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasIssues)
            const Icon(Icons.error_outline, color: CohortColors.danger, size: 16),
          if (onDuplicate != null || onDelete != null)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'duplicate') onDuplicate?.call();
                if (value == 'delete') onDelete?.call();
              },
              itemBuilder: (context) => [
                if (onDuplicate != null)
                  const PopupMenuItem(
                    value: 'duplicate',
                    child: Text('Duplicate week'),
                  ),
                if (onDelete != null)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Remove week'),
                  ),
              ],
            ),
        ],
      ),
      onTap: onTap,
    );
  }
}
