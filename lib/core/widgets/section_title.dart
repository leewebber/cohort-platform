import 'package:flutter/material.dart';

import '../theme/text_styles.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: CohortTextStyles.eyebrow,
    );
  }
}