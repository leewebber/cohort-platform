import 'package:flutter/material.dart';

import '../../../core/accessibility/journey_interaction.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../models/production_restore_outcome.dart';
import '../presentation/production_restore_athlete_copy.dart';
import '../services/production_restore_resolver.dart';

/// Production-facing recovery actions for a fail-closed restore decision.
class ProductionRestoreBlockedScreen extends StatelessWidget {
  const ProductionRestoreBlockedScreen({
    super.key,
    required this.decision,
    this.onReturnHome,
    this.onOpenCalendar,
    this.onSwitchAccount,
    this.onContinueSafely,
    this.onDiscardDraft,
    this.unsafeLegacy = false,
  });

  final ProductionRestoreDecision decision;
  final VoidCallback? onReturnHome;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onSwitchAccount;
  final VoidCallback? onContinueSafely;
  final Future<void> Function()? onDiscardDraft;
  final bool unsafeLegacy;

  ProductionRestoreOutcome get outcome => decision.outcome;

  @override
  Widget build(BuildContext context) {
    final title = unsafeLegacy
        ? ProductionRestoreAthleteCopy.unsafeLegacyTitle
        : ProductionRestoreAthleteCopy.title(outcome);
    final body = unsafeLegacy
        ? ProductionRestoreAthleteCopy.unsafeLegacyBody
        : ProductionRestoreAthleteCopy.body(outcome);
    final continueSafely = unsafeLegacy
        ? false
        : ProductionRestoreAthleteCopy.mayContinueSafely(outcome) &&
            onContinueSafely != null;
    final calendar =
        ProductionRestoreAthleteCopy.offersCalendar(outcome) &&
        onOpenCalendar != null;
    final switchAccount =
        ProductionRestoreAthleteCopy.offersSwitchAccount(outcome) &&
        onSwitchAccount != null;
    final discard = (unsafeLegacy ||
            ProductionRestoreAthleteCopy.offersDiscard(outcome)) &&
        onDiscardDraft != null;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Semantics(
              liveRegion: true,
              header: true,
              label: title,
              child: Text(title, style: CohortTextStyles.h2),
            ),
            const SizedBox(height: CohortSpacing.md),
            Text(body, style: CohortTextStyles.body),
            const SizedBox(height: CohortSpacing.xl),
            if (continueSafely)
              CohortButton(
                key: const ValueKey('restore-continue-safely'),
                label: ProductionRestoreAthleteCopy.continueSafely,
                onPressed: onContinueSafely,
              )
            else
              CohortButton(
                key: const ValueKey('restore-return-home'),
                label: ProductionRestoreAthleteCopy.returnHome,
                onPressed: onReturnHome ?? () => Navigator.of(context).pop(),
              ),
            if (calendar) ...[
              const SizedBox(height: CohortSpacing.sm),
              CohortButton(
                key: const ValueKey('restore-open-calendar'),
                label: ProductionRestoreAthleteCopy.openCalendar,
                variant: CohortButtonVariant.secondary,
                onPressed: onOpenCalendar,
              ),
            ],
            if (switchAccount) ...[
              const SizedBox(height: CohortSpacing.sm),
              CohortButton(
                key: const ValueKey('restore-switch-account'),
                label: ProductionRestoreAthleteCopy.switchAccount,
                variant: CohortButtonVariant.secondary,
                onPressed: onSwitchAccount,
              ),
            ],
            if (discard) ...[
              const SizedBox(height: CohortSpacing.sm),
              CohortButton(
                key: const ValueKey('restore-discard-draft'),
                label: ProductionRestoreAthleteCopy.discardDraft,
                variant: CohortButtonVariant.secondary,
                semanticHint: 'Opens a confirmation dialog',
                onPressed: () => _confirmDiscard(context),
              ),
            ],
            if (continueSafely) ...[
              const SizedBox(height: CohortSpacing.sm),
              TextButton(
                key: const ValueKey('restore-return-home-secondary'),
                onPressed: onReturnHome ?? () => Navigator.of(context).pop(),
                child: const Text(ProductionRestoreAthleteCopy.returnHome),
              ),
            ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDiscard(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const ProductionRestoreDiscardDialog(),
    );
    if (confirmed == true) {
      await onDiscardDraft?.call();
    }
  }
}

class ProductionRestoreDiscardDialog extends StatelessWidget {
  const ProductionRestoreDiscardDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(ProductionRestoreAthleteCopy.discardDraft),
      content: const Text(ProductionRestoreAthleteCopy.discardDraftConfirm),
      actions: [
        JourneyMinTap(
          child: TextButton(
            key: const ValueKey('restore-discard-cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
        ),
        JourneyMinTap(
          child: TextButton(
            key: const ValueKey('restore-discard-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(ProductionRestoreAthleteCopy.discardDraft),
          ),
        ),
      ],
    );
  }
}
