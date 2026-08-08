import 'dart:convert';
import 'dart:io';

import 'package:cohort_platform/staging_tooling/journey_d/journey_d_hosted_live_ports.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pin RPC alone must not classify as schedule materialisation success.
void main() {
  test('zero occurrences after ensure fails closed', () {
    final r = classifyJourneyDEnsureProjectionResult(
      {
        'status': 'initialised',
        'code': 'projection_initialised',
        'projection': {'occurrences': <Object>[]},
      },
      pinStatus: 'materialised',
    );
    expect(r.isApplied, isFalse);
    expect(r.detail, contains('ensure_zero_occurrences'));
  });

  test('pin-only success shape without ensure projection is refused', () {
    // Historical defect: creator reported materialised from pin status alone.
    final pinOnly = {'status': 'materialised', 'assignment_id': 'x'};
    final r = classifyJourneyDEnsureProjectionResult(
      pinOnly,
      pinStatus: 'materialised',
    );
    expect(r.isApplied, isFalse);
    expect(r.detail, contains('ensure_status'));
  });

  test('CURRENT+LATER occurrence pair is accepted with count evidence', () {
    final r = classifyJourneyDEnsureProjectionResult(
      {
        'status': 'initialised',
        'code': 'projection_initialised',
        'projection': {
          'occurrences': [
            {
              'id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
              'protocol_id': 'PROT-S17-JD-ADAPT-CURRENT',
            },
            {
              'id': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
              'protocol_id': 'PROT-S17-JD-ADAPT-LATER',
            },
          ],
        },
      },
      pinStatus: 'materialised',
    );
    expect(r.isApplied, isTrue);
    expect(r.detail, contains('occurrence_count=2'));
    expect(r.detail, contains('ensure=initialised'));
    expect(r.detail, contains('aaaaaaaa…'));
    expect(r.detail, contains('bbbbbbbb…'));
  });

  test('wrong protocol pair fails closed', () {
    final r = classifyJourneyDEnsureProjectionResult(
      {
        'status': 'already_exists',
        'projection': {
          'occurrences': [
            {'id': '1', 'protocol_id': 'PROT-OTHER'},
            {'id': '2', 'protocol_id': 'PROT-S17-JD-ADAPT-LATER'},
          ],
        },
      },
      pinStatus: 'already_materialised',
    );
    expect(r.isApplied, isFalse);
    expect(r.detail, contains('ensure_occurrence_mismatch'));
  });

  test('hosted materialise port chains ensure after pin', () {
    final src = File(
      '${Directory.current.path}/lib/staging_tooling/journey_d/'
      'journey_d_hosted_live_ports.dart',
    ).readAsStringSync();
    expect(src, contains('materialise_athlete_plan_from_enrolment'));
    expect(src, contains('ensure_programme_schedule_projection'));
    expect(src, contains('classifyJourneyDEnsureProjectionResult'));
    // Must not return applied on pin alone.
    expect(
      src.contains("return JourneyDLiveStageOutcome.applied(detail: 'materialised');"),
      isFalse,
    );
    final iface = File(
      '${Directory.current.path}/tool/staging/lib/s17_journey_d_fixture.py',
    ).readAsStringSync();
    expect(iface, contains('ensure_programme_schedule_projection'));
    // Local decode of fixture package still expects two executable slots.
    final yaml = File(
      '${Directory.current.path}/tool/staging/fixtures/journey_d/'
      'prog_s17_journey_d_adaptation.yaml',
    );
    if (yaml.existsSync()) {
      final text = yaml.readAsStringSync();
      expect(text, contains('PROT-S17-JD-ADAPT-CURRENT'));
      expect(text, contains('PROT-S17-JD-ADAPT-LATER'));
    }
    // Classifier round-trip JSON (local proof of expected pair).
    final encoded = jsonEncode({
      'status': 'initialised',
      'projection': {
        'occurrences': [
          {'id': 'o1', 'protocol_id': 'PROT-S17-JD-ADAPT-CURRENT'},
          {'id': 'o2', 'protocol_id': 'PROT-S17-JD-ADAPT-LATER'},
        ],
      },
    });
    final ok = classifyJourneyDEnsureProjectionResult(
      jsonDecode(encoded),
      pinStatus: 'materialised',
    );
    expect(ok.isApplied, isTrue);
    expect(ok.detail, contains('occurrence_count=2'));
  });
}
