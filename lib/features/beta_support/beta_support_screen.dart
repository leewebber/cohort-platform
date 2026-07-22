import 'package:flutter/material.dart';

import '../../core/theme/spacing.dart';
import '../../core/theme/text_styles.dart';
import '../../core/widgets/cohort_button.dart';
import '../../core/widgets/cohort_card.dart';
import '../../core/widgets/section_title.dart';
import 'beta_diagnostic_summary.dart';

class BetaSupportScreen extends StatelessWidget {
  const BetaSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final summary = BetaDiagnosticSummary.build(
      screenContext: 'Beta support',
    );

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(CohortSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('← Back'),
              ),
              const SectionTitle('Help & feedback'),
              const SizedBox(height: CohortSpacing.sm),
              Text('Share feedback during beta', style: CohortTextStyles.h1),
              const SizedBox(height: CohortSpacing.lg),
              CohortCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('App version', style: CohortTextStyles.cardTitle),
                    const SizedBox(height: CohortSpacing.xs),
                    Text(summary.appVersion, style: CohortTextStyles.body),
                    const SizedBox(height: CohortSpacing.sm),
                    Text('Platform', style: CohortTextStyles.cardTitle),
                    const SizedBox(height: CohortSpacing.xs),
                    Text(summary.platform, style: CohortTextStyles.body),
                  ],
                ),
              ),
              const SizedBox(height: CohortSpacing.lg),
              CohortButton(
                label: 'Copy diagnostic summary',
                onPressed: () async {
                  await BetaSupportActions.copyDiagnosticSummary(
                    screenContext: 'Beta support',
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Diagnostic summary copied'),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: CohortSpacing.sm),
              CohortButton(
                label: 'Report a problem',
                onPressed: () async {
                  await BetaSupportActions.copyReportTemplate(
                    screenContext: 'Beta support',
                    issueDescription: '',
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Report template copied. Paste it into your beta feedback channel.',
                        ),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: CohortSpacing.lg),
              Text(
                'Diagnostic summaries never include tokens, secrets, health notes, '
                'or private athlete data.',
                style: CohortTextStyles.small,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
