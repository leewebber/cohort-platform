import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';

import 'journey_d_live_entrypoint.dart';
import 'journey_d_non_test_runtime.dart';
import 'journey_d_progress_ledger.dart';

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
    _persistTerminalIfMissing({
      'ok': false,
      'classification': 'B4D21D1_CREATE_OVERALL_TIMED_OUT',
      'detail': 'live_main_watchdog_500s',
      'further_mutation_prohibited': true,
      'hosted_writes_executed': 0,
      'current_status': 'timed_out',
    });
    code = 2;
  } catch (e, st) {
    final redacted = JourneyDNonTestRuntime.redactException(e, st);
    _persistTerminalIfMissing({
      'ok': false,
      'classification': 'B4D21D1_LIVE_ENTRY_EXCEPTION',
      'detail': 'unhandled_entry_exception',
      'further_mutation_prohibited': true,
      'hosted_writes_executed': 0,
      'current_status': 'failed',
      ...redacted,
    });
    code = 2;
  }
  // Force process exit; do not wait on lingering isolates/timers/HTTP.
  exit(code);
}

void _persistTerminalIfMissing(Map<String, Object?> payload) {
  final out = Platform.environment['S17_JD_LIVE_RESULT_FILE'];
  if (out == null || out.isEmpty) return;
  final progressPath =
      (Platform.environment['S17_JD_PROGRESS_FILE'] ?? '$out.progress.json')
          .trim();
  if (!File(out).existsSync()) {
    File(out).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
  }
  // Never leave initialize_supabase (or any stage) stuck in_progress.
  try {
    JourneyDProgressLedger(file: File(progressPath)).write({
      ...payload,
      'terminal': true,
      'current_stage':
          payload['current_stage'] ?? 'initialize_supabase_or_entry',
    });
  } on Object {
    // Best-effort; result file is primary.
  }
}
