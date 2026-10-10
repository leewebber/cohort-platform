import 'package:flutter/material.dart';

import 'app/theme.dart';
import 'features/programme_studio/authoring/programme_authoring_screen.dart';

/// Local synthetic D1 preview. Unreachable from production main.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(theme: cohortTheme, home: const ProgrammeAuthoringScreen()),
  );
}
