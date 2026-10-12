import 'package:flutter/material.dart';

import 'app/theme.dart';
import 'features/programme_studio/protocol_authoring/protocol_authoring_screen.dart';

/// Isolated synthetic D2 preview. No production, hosted or athlete entry.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(theme: cohortTheme, home: const ProtocolAuthoringScreen()),
  );
}
