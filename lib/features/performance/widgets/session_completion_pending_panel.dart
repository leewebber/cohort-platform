import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../session/presentation/production_restore_athlete_copy.dart';

/// Hosted completion failed. Durable draft remains; retry reuses one identity.
class SessionCompletionPendingPanel extends StatelessWidget {
  const SessionCompletionPendingPanel({
    super.key,
    required this.onRetry,
    this.onReturnToSession,
    this.idempotencyKey,
  });

  final VoidCallback onRetry;
  final VoidCallback? onReturnToSession;
  final String? idempotencyKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ProductionRestoreAthleteCopy.completionPendingTitle,
          style: CohortTextStyles.h2,
        ),
        const SizedBox(height: CohortSpacing.md),
        Text(
          ProductionRestoreAthleteCopy.completionPendingBody,
          style: CohortTextStyles.body,
        ),
        const SizedBox(height: CohortSpacing.xl),
        CohortButton(
          key: const ValueKey('completion-pending-retry'),
          label: ProductionRestoreAthleteCopy.retry,
          onPressed: onRetry,
        ),
        if (onReturnToSession != null) ...[
          const SizedBox(height: CohortSpacing.sm),
          TextButton(
            key: const ValueKey('completion-pending-return'),
            onPressed: onReturnToSession,
            child: const Text(ProductionRestoreAthleteCopy.returnToSession),
          ),
        ],
        if (idempotencyKey != null)
          Opacity(
            opacity: 0,
            child: Text(
              idempotencyKey!,
              key: const ValueKey('completion-pending-idempotency'),
            ),
          ),
      ],
    );
  }
}
