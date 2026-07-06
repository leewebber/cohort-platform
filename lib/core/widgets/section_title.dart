import 'package:flutter/material.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFFA3E635),
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.3,
      ),
    );
  }
}