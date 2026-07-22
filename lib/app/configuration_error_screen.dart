import 'package:flutter/material.dart';

import '../core/errors/user_facing_error_messages.dart';
import '../core/theme/spacing.dart';
import '../core/theme/text_styles.dart';
import '../core/widgets/cohort_card.dart';
import '../core/widgets/section_title.dart';

class ConfigurationErrorScreen extends StatelessWidget {
  const ConfigurationErrorScreen({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(CohortSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Cohort'),
              const SizedBox(height: CohortSpacing.lg),
              Text('Configuration required', style: CohortTextStyles.h1),
              const SizedBox(height: CohortSpacing.md),
              CohortCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      UserFacingErrorMessages.missingSupabaseConfiguration(),
                      style: CohortTextStyles.body,
                    ),
                    if (message.trim().isNotEmpty) ...[
                      const SizedBox(height: CohortSpacing.sm),
                      Text(message, style: CohortTextStyles.small),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
