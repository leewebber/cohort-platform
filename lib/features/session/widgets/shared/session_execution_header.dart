import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';

/// Shared session player header: execution mode eyebrow and optional title.
class SessionExecutionHeader extends StatelessWidget {
  const SessionExecutionHeader({
    super.key,
    required this.modeLabel,
    this.sessionTitle,
  });

  final String modeLabel;
  final String? sessionTitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          modeLabel,
          style: CohortTextStyles.eyebrow,
        ),
        if (sessionTitle != null) ...[
          const SizedBox(height: CohortSpacing.sm),
          Text(
            sessionTitle!,
            style: CohortTextStyles.h2,
          ),
        ],
      ],
    );
  }
}
