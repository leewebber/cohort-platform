import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radius.dart';
import '../theme/text_styles.dart';

class CohortButton extends StatelessWidget {
  const CohortButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: CohortColors.olive,
          foregroundColor: CohortColors.background,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: CohortRadius.mediumRadius,
          ),
        ),
        child: Text(label, style: CohortTextStyles.button),
      ),
    );
  }
}