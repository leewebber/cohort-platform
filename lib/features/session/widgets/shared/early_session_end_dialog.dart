import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../models/early_session_end_reason.dart';
import '../../models/early_session_end_result.dart';

/// Shared early-finish confirmation dialog for session execution views.
class EarlySessionEndDialog extends StatefulWidget {
  const EarlySessionEndDialog({
    super.key,
    required this.completedCount,
    required this.totalCount,
    required this.unitLabel,
    this.reasons = EarlySessionEndReason.values,
    this.emphasizeConfirmButton = false,
  });

  final int completedCount;
  final int totalCount;

  /// Unit noun in the progress sentence, e.g. `exercises` or `work intervals`.
  final String unitLabel;
  final List<EarlySessionEndReason> reasons;
  final bool emphasizeConfirmButton;

  @override
  State<EarlySessionEndDialog> createState() => _EarlySessionEndDialogState();
}

class _EarlySessionEndDialogState extends State<EarlySessionEndDialog> {
  EarlySessionEndReason? _selectedReason;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: CohortColors.surfaceRaised,
      title: Text(
        'End session early?',
        style: CohortTextStyles.cardTitle,
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You have completed ${widget.completedCount} of '
              '${widget.totalCount} ${widget.unitLabel}. End this session now?',
              style: CohortTextStyles.body,
            ),
            const SizedBox(height: CohortSpacing.lg),
            Text(
              'Reason (optional)',
              style: CohortTextStyles.muted,
            ),
            const SizedBox(height: CohortSpacing.sm),
            for (final reason in widget.reasons)
              Padding(
                padding: const EdgeInsets.only(bottom: CohortSpacing.xs),
                child: InkWell(
                  onTap: () => setState(() {
                    _selectedReason =
                        _selectedReason == reason ? null : reason;
                  }),
                  borderRadius: CohortRadius.smallRadius,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: CohortSpacing.md,
                      vertical: CohortSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedReason == reason
                          ? CohortColors.oliveSoft
                          : Colors.transparent,
                      borderRadius: CohortRadius.smallRadius,
                      border: Border.all(
                        color: _selectedReason == reason
                            ? CohortColors.olive
                            : CohortColors.border,
                      ),
                    ),
                    child: Text(
                      reason.label,
                      style: CohortTextStyles.small,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: CohortTextStyles.body,
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            EarlySessionEndResult(reason: _selectedReason),
          ),
          child: widget.emphasizeConfirmButton
              ? Text(
                  'End session',
                  style: CohortTextStyles.body.copyWith(
                    color: CohortColors.warning,
                  ),
                )
              : const Text('End session'),
        ),
      ],
    );
  }
}
