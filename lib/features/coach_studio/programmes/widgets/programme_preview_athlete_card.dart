import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../programme_builder/models/programme_builder_preview.dart';

class ProgrammePreviewAthleteCard extends StatelessWidget {
  const ProgrammePreviewAthleteCard({
    super.key,
    required this.preview,
  });

  final ProgrammeBuilderPreview preview;

  @override
  Widget build(BuildContext context) {
    final session = preview.initialAthletePreview;

    return Padding(
      padding: const EdgeInsets.all(CohortSpacing.lg),
      child: session == null
          ? Text(
              'Assign protocols to preview athlete-facing cards.',
              style: CohortTextStyles.body,
            )
          : Card(
              color: CohortColors.surfaceRaised,
              child: Padding(
                padding: const EdgeInsets.all(CohortSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.weekLabel, style: CohortTextStyles.small),
                    const SizedBox(height: CohortSpacing.sm),
                    Text(session.title, style: CohortTextStyles.h2),
                    const SizedBox(height: CohortSpacing.xs),
                    Text(session.subtitle, style: CohortTextStyles.body),
                    const SizedBox(height: CohortSpacing.md),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: CohortColors.oliveSoft,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        session.status,
                        style: CohortTextStyles.small.copyWith(
                          color: CohortColors.olive,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
