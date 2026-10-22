import 'package:flutter/material.dart';
import 'internal_review/hyrox_base/base_review_screen.dart';

void main() => runApp(
  MaterialApp(
    title: 'HYROX Base local review',
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
    home: const BaseReviewScreen(),
  ),
);
