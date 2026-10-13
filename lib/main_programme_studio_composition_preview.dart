import 'package:flutter/material.dart';

import 'app/theme.dart';
import 'features/programme_studio/composition/synthetic_composition_screen.dart';

/// Dedicated transient synthetic preview; no production or hosted entry.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(theme: cohortTheme, home: const SyntheticCompositionScreen()),
  );
}
