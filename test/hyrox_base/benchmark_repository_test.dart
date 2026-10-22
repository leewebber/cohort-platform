import 'package:cohort_platform/application/hyrox_base/benchmark_repository.dart';
import 'package:cohort_platform/domain/hyrox_base/base_personalisation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'record sends raw declarations; server owns identity, conversion and hash',
    () async {
      final calls = <String>[];
      Map<String, Object?>? parameters;
      final repository = BaseBenchmarkRepository(
        rpc: (name, params) async {
          calls.add(name);
          parameters = params;
          return {'status': 'recorded', 'revision_id': 'server-issued'};
        },
      );
      final result = await repository.record(
        commandId: 'command',
        metric: BaseMetric.run10km,
        value: '40',
        unit: BaseInputUnit.minutes,
        testDate: '2026-10-22',
        sourceType: BaseSourceType.knownResult,
        sourceReference: 'declared-run',
      );
      expect(result['revision_id'], 'server-issued');
      expect(calls, ['record_hyrox_base_benchmark']);
      final payload = parameters!['payload']! as Map;
      expect(payload['value'], '40');
      expect(
        payload.keys,
        unorderedEquals([
          'command_id',
          'metric',
          'value',
          'unit',
          'test_date',
          'source_type',
          'source_reference',
          'previous_revision_id',
          'correction_reason',
        ]),
      );
    },
  );

  test(
    'selection and withdrawal carry explicit scope and expected head',
    () async {
      final payloads = <Map>[];
      final repository = BaseBenchmarkRepository(
        rpc: (name, params) async {
          expect(name, 'select_hyrox_base_benchmark');
          payloads.add(params['payload']! as Map);
          return {'status': 'refused', 'code': 'stale_selection'};
        },
      );
      final response = await repository.selectForFuturePreviews(
        commandId: 'select',
        metric: BaseMetric.row2km,
        revisionId: 'revision',
        expectedSelectionId: 'old-head',
      );
      expect(response['code'], 'stale_selection');
      await repository.selectForFuturePreviews(
        commandId: 'withdraw',
        metric: BaseMetric.row2km,
        revisionId: null,
        expectedSelectionId: 'current-head',
      );
      expect(
        payloads.first['consent'],
        'use_declared_benchmark_for_future_previews_only',
      );
      expect(payloads.first['expected_selection_id'], 'old-head');
      expect(payloads.last['selected_revision_id'], isNull);
    },
  );

  test('invalid input and synthetic provenance never reach transport', () {
    final repository = BaseBenchmarkRepository(
      rpc: (_, _) async => fail('transport'),
    );
    for (final source in [
      BaseSourceType.knownResult,
      BaseSourceType.syntheticExample,
    ]) {
      expect(
        () => repository.record(
          commandId: 'command',
          metric: BaseMetric.backSquat5rm,
          value: '0',
          unit: BaseInputUnit.kilograms,
          testDate: '2026-10-22',
          sourceType: source,
          sourceReference: 'declared',
        ),
        throwsFormatException,
      );
    }
  });

  test('read preserves unavailable state; malformed transport fails', () async {
    final repository = BaseBenchmarkRepository(
      rpc: (name, params) async {
        expect(name, 'read_hyrox_base_selections');
        expect(params, isEmpty);
        return {
          'status': 'read',
          'selections': [
            {'preview_state': 'unavailable_stale_selection'},
          ],
        };
      },
    );
    expect((await repository.readSelections())['selections'], [
      {'preview_state': 'unavailable_stale_selection'},
    ]);
    final malformed = BaseBenchmarkRepository(
      rpc: (_, _) async => {'selections': []},
    );
    await expectLater(malformed.readSelections(), throwsStateError);
  });
}
