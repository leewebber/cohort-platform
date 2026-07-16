import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../models/programme_catalogue_tab.dart';

class ProgrammeCatalogueEmptyState extends StatelessWidget {
  const ProgrammeCatalogueEmptyState({
    super.key,
    required this.tab,
    this.onCreate,
  });

  final ProgrammeCatalogueTab tab;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final message = switch (tab) {
      ProgrammeCatalogueTab.drafts => 'No drafts yet.',
      ProgrammeCatalogueTab.published => 'No published programmes.',
      ProgrammeCatalogueTab.cohortGlobal =>
        'No global programmes approved yet.',
      ProgrammeCatalogueTab.archived => 'No archived programmes.',
    };

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: CohortTextStyles.body),
          if (tab == ProgrammeCatalogueTab.drafts && onCreate != null) ...[
            const SizedBox(height: CohortSpacing.md),
            TextButton(
              onPressed: onCreate,
              child: Text(
                'Create programme',
                style: CohortTextStyles.body.copyWith(color: CohortColors.olive),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
