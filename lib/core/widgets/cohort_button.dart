import 'package:flutter/material.dart';

import '../theme/cohort_lighting.dart';
import '../theme/colors.dart';
import '../theme/radius.dart';
import '../theme/text_styles.dart';

enum CohortButtonVariant { primary, secondary }

class CohortButton extends StatelessWidget {
  const CohortButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = CohortButtonVariant.primary,
    this.showTrailingArrow = false,
  });

  final String label;
  final VoidCallback onPressed;
  final CohortButtonVariant variant;
  final bool showTrailingArrow;

  @override
  Widget build(BuildContext context) {
    final isPrimary = variant == CohortButtonVariant.primary;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: CohortRadius.mediumRadius,
          splashColor: Colors.white.withValues(alpha: 0.06),
          highlightColor: Colors.white.withValues(alpha: 0.04),
          child: Ink(
            decoration: isPrimary
                ? CohortLighting.primaryButton()
                : BoxDecoration(
                    color: CohortColors.surfaceRaised,
                    borderRadius: CohortRadius.mediumRadius,
                    border: CohortLighting.standardBorder(),
                    boxShadow: CohortLighting.depthLift(opacity: 0.22),
                  ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: isPrimary
                          ? CohortTextStyles.button.copyWith(
                              color: const Color(0xFF0C0E0B),
                            )
                          : CohortTextStyles.button.copyWith(
                              color: CohortColors.olive,
                              letterSpacing: 1.0,
                            ),
                    ),
                  ),
                  if (showTrailingArrow && isPrimary) ...[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: CohortColors.phosphorDeep.withValues(alpha: 0.45),
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
    );
  }
}
