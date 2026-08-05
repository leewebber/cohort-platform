import 'package:cohort_platform/staging_tooling/journey_d/journey_d_live_entrypoint.dart';
import 'package:flutter_test/flutter_test.dart';

/// Supported Journey D live entrypoint launcher (B4d.21d.3).
///
/// Invoked by `tool/staging/run_s17_journey_d_live_dart.sh` via `flutter test`.
/// Plain `dart run` cannot compile the Flutter-bound live graph.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'journey_d_live_entrypoint_harness',
    () async {
      final code = await runJourneyDLiveEntrypoint(ensureFlutterBinding: false);
      // Propagate non-zero to the shell: failing the test yields exit != 0.
      expect(
        code,
        0,
        reason:
            'Journey D live entrypoint returned $code '
            '(see S17_JD_LIVE_RESULT_FILE)',
      );
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
