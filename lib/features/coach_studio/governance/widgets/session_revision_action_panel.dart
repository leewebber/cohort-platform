import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/cohort_card.dart';
import '../../../../core/widgets/section_title.dart';
import '../../../session_revision/models/session_revision_action_decision.dart';
import '../../../session_revision/models/session_revision_action_vocabulary.dart';

typedef SessionRevisionActionHandler = Future<void> Function(
  SessionRevisionAction action,
  SessionRevisionActionDecision decision,
);

class SessionRevisionActionPanel extends StatelessWidget {
  const SessionRevisionActionPanel({
    super.key,
    required this.policy,
    required this.onAction,
    this.isExecuting = false,
  });

  final SessionRevisionActionPolicySummary policy;
  final SessionRevisionActionHandler onAction;
  final bool isExecuting;

  static const _actionOrder = [
    SessionRevisionAction.edit,
    SessionRevisionAction.createNewRevision,
    SessionRevisionAction.publish,
    SessionRevisionAction.archive,
    SessionRevisionAction.delete,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Session actions'),
        const SizedBox(height: CohortSpacing.md),
        CohortCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < _actionOrder.length; i++) ...[
                if (i > 0) const Divider(height: 24),
                _ActionRow(
                  decision: policy.decisionFor(_actionOrder[i]),
                  onAction: onAction,
                  isExecuting: isExecuting,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.decision,
    required this.onAction,
    required this.isExecuting,
  });

  final SessionRevisionActionDecision decision;
  final SessionRevisionActionHandler onAction;
  final bool isExecuting;

  @override
  Widget build(BuildContext context) {
    final enabled = decision.allowed && !isExecuting;
    final isWarning =
        decision.allowed && decision.severity == SessionRevisionActionSeverity.warning;

    final buttonStyle = isWarning
        ? OutlinedButton.styleFrom(
            foregroundColor: CohortColors.warning,
            side: const BorderSide(color: CohortColors.warning),
          )
        : null;

    final actionButton = OutlinedButton(
      style: buttonStyle,
      onPressed: enabled ? () => onAction(decision.action, decision) : null,
      child: Text(decision.action.displayLabel),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (!decision.allowed)
              Tooltip(
                message: _tooltipMessage(decision),
                child: actionButton,
              )
            else
              actionButton,
          ],
        ),
        if (!decision.allowed || isWarning) ...[
          const SizedBox(height: CohortSpacing.xs),
          Text(
            decision.userMessage,
            style: CohortTextStyles.small.copyWith(
              color: decision.allowed
                  ? CohortColors.warning
                  : CohortColors.textSecondary,
            ),
          ),
        ],
        if (decision.recommendedAlternative != null &&
            decision.recommendedAlternative!.trim().isNotEmpty) ...[
          const SizedBox(height: CohortSpacing.xs),
          Text(
            decision.recommendedAlternative!,
            style: CohortTextStyles.small.copyWith(
              color: CohortColors.olive,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  String _tooltipMessage(SessionRevisionActionDecision decision) {
    final parts = <String>[decision.userMessage];
    if (decision.recommendedAlternative != null &&
        decision.recommendedAlternative!.trim().isNotEmpty) {
      parts.add(decision.recommendedAlternative!);
    }
    return parts.join('\n');
  }
}
