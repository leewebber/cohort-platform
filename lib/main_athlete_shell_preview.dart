import 'package:flutter/material.dart';

import 'preview/athlete_shell_preview_app.dart';

/// Full interactive local athlete-shell preview.
///
/// Loopback only. Disposable in-memory Apollo fixture. Does not contact hosted
/// Supabase, mutate repo `.env`, or install over a production device build.
///
/// Launch:
///   flutter run -d web-server --web-hostname 127.0.0.1 --web-port 4180 \
///     -t lib/main_athlete_shell_preview.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AthleteShellPreviewApp());
}
