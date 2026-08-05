import 'dart:io';

import 'package:cohort_platform/staging_tooling/journey_d/journey_d_live_entrypoint.dart';

/// Thin CLI wrapper — not the supported production launcher.
///
/// Supported path: `tool/staging/run_s17_journey_d_live_dart.sh` which invokes
/// the Flutter test harness. Plain `dart run` of this file is known to crash
/// during FFI NativeCallable compilation on the Flutter-bound dependency graph.
Future<void> main(List<String> args) async {
  final code = await runJourneyDLiveEntrypoint();
  exit(code);
}
