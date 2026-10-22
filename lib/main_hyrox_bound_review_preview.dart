import 'package:flutter/material.dart';
import 'features/programme_studio/bound_personalisation/bound_review_screen.dart';

void main() => runApp(
  MaterialApp(
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
    home: const BoundStudioReviewScreen(),
  ),
);
