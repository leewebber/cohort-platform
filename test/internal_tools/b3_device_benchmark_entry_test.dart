import 'package:cohort_platform/core/config/internal_tools_policy.dart';
import 'package:cohort_platform/features/internal_tools/b3_device_benchmark_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(InternalToolsPolicy.reset);

  test('raw build defines enable internal tools only in development', () {
    expect(
      InternalToolsPolicy.enabledForBuild(
        environment: 'development',
        requested: true,
      ),
      isTrue,
    );
    for (final environment in ['production', 'loopbackPreview', '']) {
      expect(
        InternalToolsPolicy.enabledForBuild(
          environment: environment,
          requested: true,
        ),
        isFalse,
        reason: environment,
      );
      expect(
        InternalToolsPolicy.enabledForBuild(
          environment: environment,
          requested: false,
          manualOverride: true,
        ),
        isFalse,
        reason: '$environment manual override',
      );
    }
  });

  test('command sends only an explicit exact completed 5 km declaration', () {
    final command = B3DeviceBenchmarkCommand(
      commandId: 'b3d00000-0000-4000-8000-000000000099',
      localTestDate: DateTime(2026, 9, 29),
      elapsedDurationMilliseconds: 20 * 60 * 1000,
      surface: B3DeviceBenchmarkSurface.treadmill,
    );
    expect(command.toRpcPayload(), {
      'command_id': 'b3d00000-0000-4000-8000-000000000099',
      'source_reference': 'b3-device-validation:2026-09-29:1200000:treadmill',
      'source': 'manual',
      'declaration': 'completed_five_kilometre_test',
      'distance_metres': 5000,
      'elapsed_duration_milliseconds': 1200000,
      'duration_basis': 'elapsed_including_pauses',
      'local_test_date': '2026-09-29',
      'iana_timezone': 'Asia/Makassar',
      'surface_context': 'treadmill',
    });
  });

  testWidgets('tool is unavailable without explicit internal-tools build', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: B3DeviceBenchmarkEntryScreen()),
    );
    expect(find.text('This developer validation tool is disabled.'), findsOne);
    expect(find.text('Record completed 5 km test'), findsNothing);
  });

  testWidgets(
    'confirmation is required and authenticated store receives data',
    (tester) async {
      InternalToolsPolicy.enableForTesting();
      final store = _FakeStore();
      await tester.pumpWidget(
        MaterialApp(
          home: B3DeviceBenchmarkEntryScreen(
            store: store,
            initialDate: DateTime(2026, 9, 29),
            commandIdFactory: () => 'b3d00000-0000-4000-8000-000000000099',
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey('b3-benchmark-minutes')),
        '20',
      );
      await tester.enterText(
        find.byKey(const ValueKey('b3-benchmark-seconds')),
        '30',
      );
      final submit = find.text('Record completed 5 km test');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();
      expect(store.command, isNull);
      expect(find.textContaining('confirm the exact completed 5 km'), findsOne);

      final confirmation = find.byKey(
        const ValueKey('b3-benchmark-confirmation'),
      );
      await tester.ensureVisible(confirmation);
      await tester.tap(confirmation);
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(store.command, isNotNull);
      expect(store.calls, 1);
      expect(store.command!.elapsedDurationMilliseconds, 1230000);
      expect(store.command!.localTestDate, DateTime(2026, 9, 29));
      expect(
        find.text(
          'Eligible completed 5 km evidence recorded for this athlete.',
        ),
        findsOne,
      );
      expect(find.text('Recorded'), findsOne);
      await tester.tap(find.text('Recorded'), warnIfMissed: false);
      await tester.pump();
      expect(store.calls, 1);
    },
  );
}

class _FakeStore implements B3DeviceBenchmarkEvidenceStore {
  B3DeviceBenchmarkCommand? command;
  int calls = 0;

  @override
  Future<B3DeviceBenchmarkWriteResult> record(
    B3DeviceBenchmarkCommand command,
  ) async {
    calls += 1;
    this.command = command;
    return const B3DeviceBenchmarkWriteResult(isSuccess: true);
  }
}
