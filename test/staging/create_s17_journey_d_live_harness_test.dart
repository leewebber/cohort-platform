@Tags(['harness'])
library;

import 'dart:io';

import 'package:cohort_platform/staging_tooling/journey_d/journey_d_live_entrypoint.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake-only Journey D live harness.
///
/// Invoked by `tool/staging/run_s17_journey_d_live_dart.sh` or
/// `tool/testing/run_phase2_harness_tests.sh` when `S17_JD_LIVE_PORTS=fake` and
/// `S17_JD_ALLOW_FAKE_PORTS=1`. Skipped in the default `flutter test` suite.
/// Hosted live traffic must use the non-test executable
/// (`journey_d_live_main.dart`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'journey_d_live_entrypoint_fake_harness',
    () async {
      final ports = Platform.environment['S17_JD_LIVE_PORTS'] ?? '';
      final allow = Platform.environment['S17_JD_ALLOW_FAKE_PORTS'] ?? '';
      expect(ports, 'fake');
      expect(allow, '1');
      final code = await runJourneyDLiveEntrypoint(ensureFlutterBinding: false);
      expect(
        code,
        0,
        reason:
            'Journey D fake live entrypoint returned $code '
            '(see S17_JD_LIVE_RESULT_FILE)',
      );
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
