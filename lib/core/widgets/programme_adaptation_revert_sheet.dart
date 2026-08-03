import 'package:flutter/material.dart';

import '../../features/adaptation/models/accepted_adaptation_decision.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';
import 'cohort_button.dart';
import 'cohort_card.dart';
import 'section_title.dart';

/// Explicit confirmation before reverting an accepted adaptation (Sprint 1.6D).
///
/// Returns `true` only after a deliberate Confirm Revert tap. Opening, cancel,
/// dismiss, and back navigation do not mutate prepared state.
class ProgrammeAdaptationRevertSheet extends StatefulWidget {
  const ProgrammeAdaptationRevertSheet({
    super.key,
    required this.decision,
    required this.sessionTitle,
  });

  final AcceptedAdaptationDecision decision;
  final String sessionTitle;

  @override
  State<ProgrammeAdaptationRevertSheet> createState() =>
      _ProgrammeAdaptationRevertSheetState();
}

class _ProgrammeAdaptationRevertSheetState
    extends State<ProgrammeAdaptationRevertSheet> {
  bool _submitting = false;

  void _confirm() {
    if (_submitting) return;
    setState(() => _submitting = true);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final decision = widget.decision;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(CohortSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Revert to Original'),
              const SizedBox(height: CohortSpacing.md),
              Text(
                widget.sessionTitle,
                style: CohortTextStyles.body,
              ),
              const SizedBox(height: CohortSpacing.md),
              CohortCard(
                child: Text(
                  'This prepared session is currently adapted. Confirming '
                  'restores the original programmed prescription for today '
                  'only. Accepted execution changes will no longer be active.',
                  style: CohortTextStyles.body,
                ),
              ),
              const SizedBox(height: CohortSpacing.md),
              Text(
                'Your authored programme itself has never changed. Later '
                'sessions, scheduling, and progression will not change.',
                style: CohortTextStyles.muted,
              ),
              if (decision.changeSummary.isNotEmpty) ...[
                const SizedBox(height: CohortSpacing.lg),
                Text(
                  'ACTIVE ADAPTATION CHANGES',
                  style: CohortTextStyles.sectionLabel,
                ),
                const SizedBox(height: CohortSpacing.sm),
                ...decision.changeSummary.map(
                  (summary) => Padding(
                    padding: const EdgeInsets.only(bottom: CohortSpacing.xs),
                    child: Text('• $summary', style: CohortTextStyles.muted),
                  ),
                ),
              ],
              const SizedBox(height: CohortSpacing.xl),
              CohortButton(
                label: _submitting ? 'Reverting…' : 'Confirm Revert to Original',
                onPressed: _submitting ? () {} : _confirm,
              ),
              const SizedBox(height: CohortSpacing.md),
              CohortButton(
                label: 'Keep Adapted Session',
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
}

Future<bool?> showProgrammeAdaptationRevertSheet(
  BuildContext context, {
  required AcceptedAdaptationDecision decision,
  required String sessionTitle,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: CohortColors.surfaceRaised,
    isScrollControlled: true,
    builder: (_) => ProgrammeAdaptationRevertSheet(
      decision: decision,
      sessionTitle: sessionTitle,
    ),
  );
}
