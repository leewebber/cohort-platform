import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/cohort_card.dart';
import '../../../../core/widgets/section_title.dart';
import '../../../exercise_relationship/models/exercise_usage_models.dart';
import '../../../training_library/screens/library_session_builder_screen.dart';
import '../../../training_library/services/session_library_authoring_services.dart';
import '../governance_copy.dart';
import 'governance_count_row.dart';

class ExerciseUsagePanel extends StatefulWidget {
  const ExerciseUsagePanel({
    super.key,
    required this.exerciseId,
    required this.loadUsage,
    this.maxSessionReferences = 4,
    this.onOpenSessionRevision,
  });

  final String exerciseId;
  final Future<ExerciseUsageLookupResult> Function(String exerciseId) loadUsage;
  final int maxSessionReferences;
  final void Function(String protocolId)? onOpenSessionRevision;

  @override
  State<ExerciseUsagePanel> createState() => _ExerciseUsagePanelState();
}

class _ExerciseUsagePanelState extends State<ExerciseUsagePanel> {
  late Future<ExerciseUsageLookupResult> _usageFuture;

  @override
  void initState() {
    super.initState();
    _usageFuture = widget.loadUsage(widget.exerciseId);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Used by'),
        const SizedBox(height: CohortSpacing.md),
        FutureBuilder<ExerciseUsageLookupResult>(
          future: _usageFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CohortCard(
                child: Padding(
                  padding: EdgeInsets.all(CohortSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (snapshot.hasError) {
              return CohortCard(
                child: Text(
                  GovernanceCopy.exerciseUsageLookupFailedMessage,
                  style: CohortTextStyles.body.copyWith(
                    color: CohortColors.warning,
                  ),
                ),
              );
            }

            final lookup = snapshot.data!;
            return CohortCard(child: _buildLookupBody(context, lookup));
          },
        ),
      ],
    );
  }

  Widget _buildLookupBody(
    BuildContext context,
    ExerciseUsageLookupResult lookup,
  ) {
    switch (lookup.status) {
      case ExerciseUsageLookupStatus.success:
        return _SuccessBody(
          summary: lookup.summary!,
          maxSessionReferences: widget.maxSessionReferences,
          onOpenSessionRevision: widget.onOpenSessionRevision ??
              (protocolId) => _defaultOpenSessionRevision(context, protocolId),
        );
      case ExerciseUsageLookupStatus.exerciseNotFound:
        return const Text(
          'This exercise could not be found.',
          style: CohortTextStyles.body,
        );
      case ExerciseUsageLookupStatus.lookupFailed:
        return Text(
          lookup.message ?? GovernanceCopy.exerciseUsageLookupFailedMessage,
          style: CohortTextStyles.body.copyWith(color: CohortColors.warning),
        );
    }
  }

  Future<void> _defaultOpenSessionRevision(
    BuildContext context,
    String protocolId,
  ) async {
    final coordinator = SessionLibraryAuthoringServices.createCoordinator();
    try {
      final draft = await coordinator.loadSession(protocolId);
      if (!context.mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => LibrarySessionBuilderScreen(
            coordinator: coordinator,
            initialDraft: draft,
            isEdit: true,
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This session revision could not be opened.')),
      );
    }
  }
}

class _SuccessBody extends StatelessWidget {
  const _SuccessBody({
    required this.summary,
    required this.maxSessionReferences,
    required this.onOpenSessionRevision,
  });

  final ExerciseUsageSummary summary;
  final int maxSessionReferences;
  final void Function(String protocolId) onOpenSessionRevision;

  @override
  Widget build(BuildContext context) {
    if (summary.isUnused) {
      return Text(
        GovernanceCopy.exerciseUnusedMessage,
        style: CohortTextStyles.body.copyWith(color: CohortColors.textSecondary),
      );
    }

    final distinctSessions = _distinctSessionReferences(summary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (summary.directSessionRevisionCount > 0)
          GovernanceCountRow(
            label: GovernanceCopy.sessionRevisionCountLabel(
              summary.directSessionRevisionCount,
            ),
          ),
        if (summary.sessionLineageCount > 0)
          GovernanceCountRow(
            label: GovernanceCopy.sessionLineageCountLabel(
              summary.sessionLineageCount,
            ),
          ),
        if (summary.programmeVersionCount > 0)
          GovernanceCountRow(
            label: GovernanceCopy.programmeVersionCountLabel(
              summary.programmeVersionCount,
            ),
          ),
        if (summary.activeAssignmentCount > 0)
          GovernanceCountRow(
            label: GovernanceCopy.activeAssignmentCountLabel(
              summary.activeAssignmentCount,
            ),
          ),
        if (summary.historicalRecordCount > 0)
          GovernanceCountRow(
            label: GovernanceCopy.historicalPerformanceCountLabel(
              summary.historicalRecordCount,
            ),
          ),
        if (summary.directBlockReferenceCount > 0) ...[
          const SizedBox(height: CohortSpacing.sm),
          Text(
            GovernanceCopy.blockLinkSummary(
              blockCount: summary.directBlockReferenceCount,
              revisionCount: summary.directSessionRevisionCount,
            ),
            style: CohortTextStyles.small.copyWith(
              color: CohortColors.textSecondary,
            ),
          ),
        ],
        if (distinctSessions.isNotEmpty) ...[
          const SizedBox(height: CohortSpacing.md),
          ...distinctSessions.take(maxSessionReferences).map(
                (ref) => Padding(
                  padding: const EdgeInsets.only(bottom: CohortSpacing.xs),
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                    ),
                    onPressed: () => onOpenSessionRevision(ref.protocolId),
                    child: Text(
                      GovernanceCopy.sessionRevisionReference(ref),
                      style: CohortTextStyles.body.copyWith(
                        color: CohortColors.olive,
                      ),
                    ),
                  ),
                ),
              ),
          if (distinctSessions.length > maxSessionReferences)
            TextButton(
              onPressed: () => _showAllSessions(context, distinctSessions),
              child: const Text('View all'),
            ),
        ],
      ],
    );
  }

  List<ExerciseRevisionReference> _distinctSessionReferences(
    ExerciseUsageSummary summary,
  ) {
    final seen = <String>{};
    final results = <ExerciseRevisionReference>[];
    for (final ref in summary.directSessionReferences) {
      if (seen.add(ref.protocolId)) {
        results.add(ref);
      }
    }
    return results;
  }

  void _showAllSessions(
    BuildContext context,
    List<ExerciseRevisionReference> references,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(CohortSpacing.lg),
            children: [
              const Text('Session revisions', style: CohortTextStyles.h2),
              const SizedBox(height: CohortSpacing.md),
              ...references.map(
                (ref) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(GovernanceCopy.sessionRevisionReference(ref)),
                  onTap: () {
                    Navigator.pop(context);
                    onOpenSessionRevision(ref.protocolId);
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
