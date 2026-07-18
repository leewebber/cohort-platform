import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radius.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

/// Standard screen padding for Coach Studio flows.
const coachStudioScreenPadding = EdgeInsets.all(24);

/// Consistent coach-facing success and info messages.
class CoachStudioFeedback {
  CoachStudioFeedback._();

  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  static const sessionSaved = 'Session saved';
  static const sessionUpdated = 'Session updated';
  static const sessionAddedToProgramme = 'Session added to programme';
  static const sessionCopiedToLibrary = 'Session copied to Session Library';
  static const programmeUpdated = 'Programme updated';
}

class CoachStudioPageHeader extends StatelessWidget {
  const CoachStudioPageHeader({
    super.key,
    required this.backLabel,
    required this.onBack,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String backLabel;
  final VoidCallback onBack;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton(
          onPressed: onBack,
          child: Text(backLabel),
        ),
        const SizedBox(height: CohortSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: CohortTextStyles.h1),
                  if (subtitle != null) ...[
                    const SizedBox(height: CohortSpacing.sm),
                    Text(
                      subtitle!,
                      style: CohortTextStyles.body.copyWith(
                        color: CohortColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ],
    );
  }
}

class CoachStudioEmptyState extends StatelessWidget {
  const CoachStudioEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CohortSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: CohortTextStyles.h2),
          const SizedBox(height: CohortSpacing.sm),
          Text(message, style: CohortTextStyles.body),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: CohortSpacing.lg),
            CohortSecondaryButton(label: actionLabel!, onPressed: onAction!),
          ],
        ],
      ),
    );
  }
}

class CohortSecondaryButton extends StatelessWidget {
  const CohortSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: CohortColors.textPrimary,
        side: const BorderSide(color: CohortColors.border),
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(
          borderRadius: CohortRadius.mediumRadius,
        ),
      ),
      child: Text(label, style: CohortTextStyles.button),
    );

    if (!expanded) return button;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: button,
    );
  }
}

class CoachStudioLoadingState extends StatelessWidget {
  const CoachStudioLoadingState({
    super.key,
    this.message,
  });

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: CohortSpacing.md),
            Text(
              message!,
              style: CohortTextStyles.body,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
