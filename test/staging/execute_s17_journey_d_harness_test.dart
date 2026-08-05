import 'package:cohort_platform/staging_tooling/journey_d/journey_d_execute_entrypoint.dart';
import 'package:flutter_test/flutter_test.dart';

/// Supported Journey D execute entrypoint launcher.
///
/// Invoked by `tool/staging/run_s17_journey_d_execute_dart.sh` via `flutter test`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'journey_d_execute_entrypoint_harness',
    () async {
      final code = await runJourneyDExecuteEntrypoint(
        ensureFlutterBinding: false,
      );
      expect(
        code,
        0,
        reason:
            'Journey D execute entrypoint returned $code '
            '(see S17_JD_EXECUTE_RESULT_FILE)',
      );
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
