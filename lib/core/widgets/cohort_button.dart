import 'package:flutter/material.dart';

import '../accessibility/journey_interaction.dart';
import '../theme/cohort_lighting.dart';
import '../theme/colors.dart';
import '../theme/radius.dart';
import '../theme/text_styles.dart';

enum CohortButtonVariant { primary, secondary }

class CohortButton extends StatefulWidget {
  const CohortButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = CohortButtonVariant.primary,
    this.showTrailingArrow = false,
    this.semanticLabel,
    this.semanticHint,
  });

  final String label;
  final VoidCallback? onPressed;
  final CohortButtonVariant variant;
  final bool showTrailingArrow;
  final String? semanticLabel;
  final String? semanticHint;

  @override
  State<CohortButton> createState() => _CohortButtonState();
}

class _CohortButtonState extends State<CohortButton> {
  final _once = JourneyOnceTap();

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final isPrimary = widget.variant == CohortButtonVariant.primary;
    final semanticsLabel = widget.semanticLabel ?? widget.label;

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticsLabel,
      hint: widget.semanticHint ?? (enabled ? null : 'Unavailable'),
      child: ExcludeSemantics(
        child: SizedBox(
          width: double.infinity,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: JourneyInteraction.minPrimaryHeight,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: enabled
                    ? () {
                        if (!_once.tryAcquire()) return;
                        widget.onPressed!();
                        _once.releaseNextFrame(() {});
                      }
                    : null,
                borderRadius: CohortRadius.mediumRadius,
                splashColor: Colors.white.withValues(alpha: 0.06),
                highlightColor: Colors.white.withValues(alpha: 0.04),
                child: Ink(
                  decoration: _decoration(
                    isPrimary: isPrimary,
                    enabled: enabled,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            widget.label,
                            textAlign: TextAlign.center,
                            softWrap: true,
                            style: isPrimary && enabled
                                ? CohortTextStyles.button.copyWith(
                                    color: const Color(0xFF0C0E0B),
                                  )
                                : CohortTextStyles.button.copyWith(
                                    color: enabled
                                        ? CohortColors.olive
                                        : CohortColors.textSecondary,
                                    letterSpacing: 1.0,
                                  ),
                          ),
                        ),
                        if (widget.showTrailingArrow && isPrimary && enabled) ...[
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: CohortColors.phosphorDeep.withValues(
                                alpha: 0.45,
                              ),
                              borderRadius: CohortRadius.smallRadius,
                              border: Border.all(
                                color: CohortColors.edgeHighlight.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                              boxShadow: CohortLighting.emissive(
                                opacity: 0.08,
                                blurRadius: 6,
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              color: Color(0xFF0C0E0B),
                              size: 20,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _decoration({
    required bool isPrimary,
    required bool enabled,
  }) {
    if (!enabled) {
      return BoxDecoration(
        color: CohortColors.surfaceRaised,
        borderRadius: CohortRadius.mediumRadius,
        border: Border.all(color: CohortColors.borderStrong),
      );
    }
    if (isPrimary) {
      return CohortLighting.primaryButton();
    }
    return BoxDecoration(
      color: CohortColors.surfaceRaised,
      borderRadius: CohortRadius.mediumRadius,
      border: CohortLighting.standardBorder(),
      boxShadow: CohortLighting.depthLift(opacity: 0.22),
    );
  }
}
