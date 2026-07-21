import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/cohort_card.dart';
import '../../../../core/widgets/section_title.dart';
import '../../../session_revision/models/session_revision_action_decision.dart';
import '../../../session_revision/models/session_revision_usage_models.dart';
import '../../programmes/programme_editor_screen.dart';
import '../governance_copy.dart';
import 'governance_count_row.dart';

class SessionRevisionUsagePanel extends StatelessWidget {
  const SessionRevisionUsagePanel({
    super.key,
    required this.usageLookup,
    this.maxReferences = 3,
    this.onOpenProgrammeVersion,
  });

  final SessionRevisionUsageLookupResult usageLookup;
  final int maxReferences;
  final void Function(String programmeVersionId)? onOpenProgrammeVersion;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Used by'),
        const SizedBox(height: CohortSpacing.md),
        CohortCard(child: _buildBody(context)),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (usageLookup.status) {
      case SessionRevisionUsageLookupStatus.success:
        return _SuccessBody(
          summary: usageLookup.summary!,
          maxReferences: maxReferences,
          onOpenProgrammeVersion: onOpenProgrammeVersion ??
              (versionId) => _defaultOpenProgramme(context, versionId),
        );
      case SessionRevisionUsageLookupStatus.revisionNotFound:
        return const Text(
          'This session revision could not be found.',
          style: CohortTextStyles.body,
        );
      case SessionRevisionUsageLookupStatus.lookupFailed:
        return Text(
          usageLookup.message ?? GovernanceCopy.sessionUsageLookupFailedMessage,
          style: CohortTextStyles.body.copyWith(color: CohortColors.warning),
        );
    }
  }

  void _defaultOpenProgramme(BuildContext context, String versionId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProgrammeEditorScreen(versionId: versionId),
      ),
    );
  }
}

class _SuccessBody extends StatelessWidget {
  const _SuccessBody({
    required this.summary,
    required this.maxReferences,
    required this.onOpenProgrammeVersion,
  });

  final SessionRevisionUsageSummary summary;
  final int maxReferences;
  final void Function(String programmeVersionId) onOpenProgrammeVersion;

  @override
  Widget build(BuildContext context) {
    if (summary.isUnused) {
      return Text(
        GovernanceCopy.unusedSessionRevisionMessage,
        style: CohortTextStyles.body.copyWith(color: CohortColors.textSecondary),
      );
    }

    final isHistoricalOnly = summary.hasHistoricalUsage &&
        !summary.hasDirectAuthoredUsage &&
        !summary.hasActiveOperationalUsage;

    final distinctProgrammes = _distinctProgrammeReferences(summary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (summary.programmeReferenceCount > 0)
          GovernanceCountRow(
            label: GovernanceCopy.programmeVersionCountLabel(
              summary.programmeReferenceCount,
            ),
          ),
        if (summary.slotReferenceCount > 0)
          GovernanceCountRow(
            label: GovernanceCopy.slotCountLabel(summary.slotReferenceCount),
          ),
        if (summary.activeAssignmentReferences.isNotEmpty)
          GovernanceCountRow(
            label: GovernanceCopy.activeAssignmentCountLabel(
              summary.activeAssignmentReferences.length,
            ),
          ),
        if (summary.historicalUsage.hasUsage)
          GovernanceCountRow(
            label: GovernanceCopy.historicalPerformanceCountLabel(
              summary.historicalUsage.recordCount,
            ),
          ),
        if (summary.classifications.isNotEmpty) ...[
          const SizedBox(height: CohortSpacing.sm),
          Wrap(
            spacing: CohortSpacing.sm,
            runSpacing: CohortSpacing.xs,
            children: summary.classifications
                .map(
                  (classification) => Text(
                    GovernanceCopy.classificationLabel(classification),
                    style: CohortTextStyles.small.copyWith(
                      color: CohortColors.textSecondary,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
        if (isHistoricalOnly) ...[
          const SizedBox(height: CohortSpacing.md),
          Text(
            GovernanceCopy.historicalOnlySessionRevisionMessage,
            style: CohortTextStyles.small.copyWith(
              color: CohortColors.textSecondary,
            ),
          ),
        ],
        if (distinctProgrammes.isNotEmpty) ...[
          const SizedBox(height: CohortSpacing.md),
          ...distinctProgrammes.take(maxReferences).map(
                (ref) => Padding(
                  padding: const EdgeInsets.only(bottom: CohortSpacing.xs),
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                    ),
                    onPressed: () =>
                        onOpenProgrammeVersion(ref.programmeVersionId),
                    child: Text(
                      GovernanceCopy.programmeVersionReference(ref),
                      style: CohortTextStyles.body.copyWith(
                        color: CohortColors.olive,
                      ),
                    ),
                  ),
                ),
              ),
          if (distinctProgrammes.length > maxReferences)
            TextButton(
              onPressed: () => _showAllReferences(context, distinctProgrammes),
              child: const Text('View all'),
            ),
        ],
      ],
    );
  }

  List<SessionRevisionProgrammeReference> _distinctProgrammeReferences(
    SessionRevisionUsageSummary summary,
  ) {
    final seen = <String>{};
    final results = <SessionRevisionProgrammeReference>[];
    for (final ref in summary.programmeReferences) {
      if (seen.add(ref.programmeVersionId)) {
        results.add(ref);
      }
    }
    return results;
  }

  void _showAllReferences(
    BuildContext context,
    List<SessionRevisionProgrammeReference> references,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(CohortSpacing.lg),
            children: [
              const Text('Programme references', style: CohortTextStyles.h2),
              const SizedBox(height: CohortSpacing.md),
              ...references.map(
                (ref) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(GovernanceCopy.programmeVersionReference(ref)),
                  onTap: () {
                    Navigator.pop(context);
                    onOpenProgrammeVersion(ref.programmeVersionId);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
