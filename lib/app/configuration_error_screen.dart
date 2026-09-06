import 'package:flutter/material.dart';

import '../core/config/app_build_provenance.dart';
import '../core/config/release_configuration_code.dart';
import '../core/theme/spacing.dart';
import '../core/theme/text_styles.dart';
import '../core/widgets/cohort_card.dart';
import '../core/widgets/section_title.dart';

class ConfigurationErrorScreen extends StatelessWidget {
  const ConfigurationErrorScreen({
    super.key,
    required this.message,
    this.code,
    this.provenance,
  });

  final String message;
  final ReleaseConfigurationCode? code;
  final AppBuildProvenance? provenance;

  @override
  Widget build(BuildContext context) {
    final build = provenance ?? AppBuildProvenance.current;
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
                    Text(message, style: CohortTextStyles.body),
                    const SizedBox(height: CohortSpacing.md),
                    Text(
                      'Cohort ${build.displayVersion}',
                      style: CohortTextStyles.small,
                    ),
                    Text(
                      'Commit ${build.shortCommit}',
                      style: CohortTextStyles.small,
                    ),
                    Text(
                      'Environment ${build.environmentLabel}',
                      style: CohortTextStyles.small,
                    ),
                    if (code != null) ...[
                      const SizedBox(height: CohortSpacing.sm),
                      Text(code!.name, style: CohortTextStyles.small),
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
