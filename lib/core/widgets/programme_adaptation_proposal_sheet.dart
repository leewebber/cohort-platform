import 'package:flutter/material.dart';

import '../../features/adaptation/models/programme_adaptation_proposal.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';
import 'cohort_button.dart';
import 'cohort_card.dart';
import 'section_title.dart';

/// Athlete review for a programme adaptation proposal.
///
/// Accept is enabled only for [ProgrammeAdaptationProposal.isAcceptable]
/// reviewable proposals (Sprint 1.6C).
class ProgrammeAdaptationProposalSheet extends StatefulWidget {
  const ProgrammeAdaptationProposalSheet({
    super.key,
    required this.proposal,
  });

  final ProgrammeAdaptationProposal proposal;

  @override
  State<ProgrammeAdaptationProposalSheet> createState() =>
      _ProgrammeAdaptationProposalSheetState();
}

class _ProgrammeAdaptationProposalSheetState
    extends State<ProgrammeAdaptationProposalSheet> {
  bool _submitting = false;

  ProgrammeAdaptationProposal get proposal => widget.proposal;

  void _accept() {
    if (_submitting || !proposal.isAcceptable) return;
    setState(() => _submitting = true);
    // Pop true only after deliberate Accept tap; caller performs mutation.
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isReviewable = proposal.isReviewable;
    final isNoSafe = proposal.isNoSafeAdaptation;
    final canAccept = proposal.isAcceptable && !_submitting;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(CohortSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(
                isNoSafe
                    ? 'Unable to Adapt Safely'
                    : isReviewable
                    ? 'Review Adaptation Proposal'
                    : 'No Adaptation Needed',
              ),
              const SizedBox(height: CohortSpacing.md),
              Text(
                'Reason: ${_reasonLabel(proposal.reason.name)}',
                style: CohortTextStyles.body,
              ),
              const SizedBox(height: CohortSpacing.sm),
              Text(
                'Programmed session: ${proposal.programmedSessionKey.value}',
                style: CohortTextStyles.muted,
              ),
              const SizedBox(height: CohortSpacing.md),
              CohortCard(
                child: Text(
                  proposal.athleteFacingMessage,
                  style: CohortTextStyles.body,
                ),
              ),
              if (isReviewable) ...[
                const SizedBox(height: CohortSpacing.lg),
                Text('ORIGINAL PRESCRIPTION', style: CohortTextStyles.sectionLabel),
                const SizedBox(height: CohortSpacing.sm),
                Text(
                  'Protocol ${proposal.protocolId} · version '
                  '${proposal.programmeVersionId}',
                  style: CohortTextStyles.muted,
                ),
                if (proposal.sessionChanges.isNotEmpty) ...[
                  const SizedBox(height: CohortSpacing.lg),
                  Text(
                    'SESSION-LEVEL CHANGES',
                    style: CohortTextStyles.sectionLabel,
                  ),
                  const SizedBox(height: CohortSpacing.sm),
                  ...proposal.sessionChanges.map(_changeTile),
                ],
                if (proposal.exerciseChanges.isNotEmpty) ...[
                  const SizedBox(height: CohortSpacing.lg),
                  Text(
                    'EXERCISE-LEVEL CHANGES',
                    style: CohortTextStyles.sectionLabel,
                  ),
                  const SizedBox(height: CohortSpacing.sm),
                  ...proposal.exerciseChanges.map(_changeTile),
                ],
                const SizedBox(height: CohortSpacing.lg),
                Text('PRESERVED INTENT', style: CohortTextStyles.sectionLabel),
                const SizedBox(height: CohortSpacing.sm),
                Text(
                  proposal.preservedIntent ??
                      'Authored training intent retained as closely as policy allows.',
                  style: CohortTextStyles.body,
                ),
                const SizedBox(height: CohortSpacing.md),
                Text(
                  proposal.derivationExplanation,
                  style: CohortTextStyles.muted,
                ),
                const SizedBox(height: CohortSpacing.md),
                Text(
                  'Accepting changes only today’s prepared session. Your '
                  'authored programme, later sessions, progression, and '
                  'scheduling remain unchanged.',
                  style: CohortTextStyles.muted,
                ),
              ],
              if (isNoSafe) ...[
                const SizedBox(height: CohortSpacing.md),
                Text(
                  'Your current prepared session remains available exactly as '
                  'prescribed.',
                  style: CohortTextStyles.muted,
                ),
              ],
              const SizedBox(height: CohortSpacing.xl),
              if (canAccept) ...[
                CohortButton(
                  label: _submitting ? 'Applying…' : 'Accept Adaptation',
                  onPressed: _submitting ? () {} : _accept,
                ),
                const SizedBox(height: CohortSpacing.md),
              ],
              CohortButton(
                label: 'Keep Original Session',
                onPressed: _submitting
                    ? () {}
                    : () => Navigator.of(context).pop(false),
              ),
              const SizedBox(height: CohortSpacing.sm),
              TextButton(
                onPressed: _submitting
                    ? () {}
                    : () => Navigator.of(context).pop(null),
                child: Text('Cancel', style: CohortTextStyles.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _changeTile(ProgrammeAdaptationMaterialChange change) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.sm),
      child: CohortCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(change.summary, style: CohortTextStyles.body),
            if (change.beforeValue != null || change.afterValue != null) ...[
              const SizedBox(height: CohortSpacing.xs),
              Text(
                'Before: ${change.beforeValue ?? '—'}',
                style: CohortTextStyles.muted,
              ),
              Text(
                'After: ${change.afterValue ?? '—'}',
                style: CohortTextStyles.muted,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _reasonLabel(String raw) {
    if (raw.isEmpty) return raw;
    return '${raw[0].toUpperCase()}${raw.substring(1)}';
  }
}

Future<bool?> showProgrammeAdaptationProposalSheet(
  BuildContext context,
  ProgrammeAdaptationProposal proposal,
) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: CohortColors.surfaceRaised,
    isScrollControlled: true,
    builder: (_) => ProgrammeAdaptationProposalSheet(proposal: proposal),
  );
}
