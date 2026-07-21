import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../models/session_revision_vocabulary.dart';
import '../governance_copy.dart';
import 'governance_status_badge.dart';

class SessionRevisionIdentityHeader extends StatelessWidget {
  const SessionRevisionIdentityHeader({
    super.key,
    required this.sessionDisplayName,
    required this.revisionNumber,
    required this.lifecycleStatus,
  });

  final String sessionDisplayName;
  final int revisionNumber;
  final SessionRevisionLifecycleStatus lifecycleStatus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sessionDisplayName,
          style: CohortTextStyles.h2,
        ),
        const SizedBox(height: CohortSpacing.xs),
        Wrap(
          spacing: CohortSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Session Revision',
              style: CohortTextStyles.small.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              GovernanceCopy.compactRevisionLine(
                revisionNumber: revisionNumber,
                lifecycleStatus: lifecycleStatus,
              ),
              style: CohortTextStyles.body,
            ),
            GovernanceStatusBadge(lifecycleStatus: lifecycleStatus),
          ],
        ),
      ],
    );
  }
}
