import 'dart:async';
import 'dart:convert';
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
  var code = 2;
  try {
    code = await runJourneyDLiveEntrypoint(
      ensureFlutterBinding: false,
    ).timeout(const Duration(seconds: 500));
  } on TimeoutException {
    final out = Platform.environment['S17_JD_LIVE_RESULT_FILE'];
    if (out != null && out.isNotEmpty && !File(out).existsSync()) {
      File(out).writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'ok': false,
          'classification': 'B4D21D1_CREATE_OVERALL_TIMED_OUT',
          'detail': 'live_main_watchdog_500s',
          'further_mutation_prohibited': true,
          'hosted_writes_executed': 0,
        }),
      );
    }
    code = 2;
  } catch (e) {
    final out = Platform.environment['S17_JD_LIVE_RESULT_FILE'];
    if (out != null && out.isNotEmpty && !File(out).existsSync()) {
      File(out).writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'ok': false,
          'classification': 'B4D21D1_LIVE_ENTRY_EXCEPTION',
          'detail': e.runtimeType.toString(),
          'further_mutation_prohibited': true,
          'hosted_writes_executed': 0,
        }),
      );
    }
    code = 2;
  }
  // Force process exit; do not wait on lingering isolates/timers/HTTP.
  exit(code);
}
