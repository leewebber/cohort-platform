import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CohortColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(CohortSpacing.lg),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: CohortSpacing.lg),
                    Text(title, style: CohortTextStyles.h1),
                    const SizedBox(height: CohortSpacing.sm),
                    Text(
                      subtitle,
                      style: CohortTextStyles.body.copyWith(
                        color: CohortColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: CohortSpacing.xl),
                    child,
                    if (footer != null) ...[
                      const SizedBox(height: CohortSpacing.lg),
                      footer!,
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
