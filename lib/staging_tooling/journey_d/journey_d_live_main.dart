import 'dart:io';

import 'package:flutter/widgets.dart';

import 'journey_d_live_entrypoint.dart';
import 'journey_d_non_test_runtime.dart';

/// Non-test Flutter executable entry for Journey D live fixture creation.
///
/// Launched by `tool/staging/run_s17_journey_d_live_dart.sh` via
/// `flutter run --no-pub` (never `flutter test`).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  JourneyDNonTestRuntime.refuseTestBinding(surface: 'journey_d_live_main');
  final code = await runJourneyDLiveEntrypoint(ensureFlutterBinding: false);
  exit(code);
}
