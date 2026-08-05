import 'dart:io';

import 'package:cohort_platform/staging_tooling/journey_d/journey_d_execute_entrypoint.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake-only Journey D execute harness.
///
/// Invoked by `tool/staging/run_s17_journey_d_execute_dart.sh` only when
/// `S17_JD_EXECUTE_PORTS=fake` and `S17_JD_ALLOW_FAKE_PORTS=1`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'journey_d_execute_entrypoint_fake_harness',
    () async {
      final ports = Platform.environment['S17_JD_EXECUTE_PORTS'] ?? '';
      final allow = Platform.environment['S17_JD_ALLOW_FAKE_PORTS'] ?? '';
      expect(ports, 'fake');
      expect(allow, '1');
      final code = await runJourneyDExecuteEntrypoint(
        ensureFlutterBinding: false,
      );
      expect(
        code,
        0,
        reason:
            'Journey D fake execute entrypoint returned $code '
            '(see S17_JD_EXECUTE_RESULT_FILE)',
      );
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
