import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/cohort_card.dart';
import '../../../../models/programme_vocabulary.dart';
import '../../../programme/models/programme_catalog_entry.dart';
import '../models/programme_catalogue_action.dart';
import '../models/programme_catalogue_tab.dart';

class ProgrammeCatalogueCard extends StatelessWidget {
  const ProgrammeCatalogueCard({
    super.key,
    required this.entry,
    required this.tab,
    required this.onTap,
    required this.onAction,
    this.disabled = false,
  });

  final ProgrammeCatalogEntry entry;
  final ProgrammeCatalogueTab tab;
  final VoidCallback onTap;
  final void Function(ProgrammeCatalogueAction action) onAction;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final metadata = <String>[
      'v${entry.versionNumber}',
      if (entry.durationWeeks != null) '${entry.durationWeeks} weeks',
      if (entry.sessionsPerWeek != null)
        '${entry.sessionsPerWeek} sessions/week',
    ].join(' · ');

    final dateLabel = _dateLabel(entry);

    return Opacity(
      opacity: disabled ? 0.6 : 1,
      child: CohortCard(
        onTap: disabled ? null : onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  tab.eyebrowLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: _eyebrowColor(),
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                PopupMenuButton<ProgrammeCatalogueAction>(
                  enabled: !disabled,
                  onSelected: onAction,
                  itemBuilder: (context) => _menuItems(),
                  child: const Icon(Icons.more_horiz, size: 20),
                ),
              ],
            ),
            const SizedBox(height: CohortSpacing.sm),
            Text(
              entry.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (metadata.isNotEmpty) ...[
              const SizedBox(height: CohortSpacing.xs),
              Text(
                metadata,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: CohortSpacing.xs),
            Text(
              entry.lineageCode,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CohortColors.textMuted,
                  ),
            ),
            const SizedBox(height: CohortSpacing.xs),
            Text(
              [
                entry.ownerDisplayLabel ?? entry.libraryScope.displayLabel,
                if (dateLabel != null) dateLabel,
              ].join(' · '),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: CohortColors.textMuted,
                  ),
            ),
            if (entry.hasBlockingValidationErrors &&
                tab == ProgrammeCatalogueTab.drafts) ...[
              const SizedBox(height: CohortSpacing.sm),
              Text(
                'Needs validation',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: CohortColors.warning,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<PopupMenuEntry<ProgrammeCatalogueAction>> _menuItems() {
    return switch (tab) {
      ProgrammeCatalogueTab.drafts => const [
          PopupMenuItem(
            value: ProgrammeCatalogueAction.validate,
            child: Text('Validate'),
          ),
          PopupMenuItem(
            value: ProgrammeCatalogueAction.publish,
            child: Text('Publish'),
          ),
          PopupMenuItem(
            value: ProgrammeCatalogueAction.duplicateProgramme,
            child: Text('Duplicate Programme'),
          ),
          PopupMenuItem(
            value: ProgrammeCatalogueAction.deleteDraft,
            child: Text('Delete Draft'),
          ),
        ],
      ProgrammeCatalogueTab.published => const [
          PopupMenuItem(
            value: ProgrammeCatalogueAction.preview,
            child: Text('Preview'),
          ),
          PopupMenuItem(
            value: ProgrammeCatalogueAction.cloneVersion,
            child: Text('Clone to New Version'),
          ),
          PopupMenuItem(
            value: ProgrammeCatalogueAction.duplicateProgramme,
            child: Text('Duplicate Programme'),
          ),
          PopupMenuItem(
            value: ProgrammeCatalogueAction.archive,
            child: Text('Archive'),
          ),
        ],
      ProgrammeCatalogueTab.cohortGlobal => const [
          PopupMenuItem(
            value: ProgrammeCatalogueAction.preview,
            child: Text('Preview'),
          ),
          PopupMenuItem(
            value: ProgrammeCatalogueAction.duplicateProgramme,
            child: Text('Duplicate Programme'),
          ),
        ],
      ProgrammeCatalogueTab.archived => const [
          PopupMenuItem(
            value: ProgrammeCatalogueAction.preview,
            child: Text('Preview'),
          ),
          PopupMenuItem(
            value: ProgrammeCatalogueAction.cloneVersion,
            child: Text('Clone'),
          ),
        ],
    };
  }

  Color _eyebrowColor() {
    return switch (tab) {
      ProgrammeCatalogueTab.drafts => CohortColors.olive,
      ProgrammeCatalogueTab.published => CohortColors.textMuted,
      ProgrammeCatalogueTab.cohortGlobal => CohortColors.olive,
      ProgrammeCatalogueTab.archived => CohortColors.textMuted,
    };
  }

  String? _dateLabel(ProgrammeCatalogEntry entry) {
    final stamp = entry.updatedAt ?? entry.publishedAt ?? entry.archivedAt;
    if (stamp == null) return null;

    final label = tab == ProgrammeCatalogueTab.published
        ? 'Published'
        : tab == ProgrammeCatalogueTab.archived
            ? 'Archived'
            : 'Updated';

    return '$label ${_formatDate(stamp)}';
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}
