import 'dart:convert';

import 'package:cohort_platform/domain/performance_tracking/performance_tracking.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tracking_fixtures.dart';

TrackingArtifact change(
  TrackingArtifact artifact,
  void Function(Map<String, dynamic>) update,
) {
  final json = jsonDecode(artifact.canonicalJson) as Map<String, dynamic>;
  update(json);
  return TrackingCodec.decode(jsonEncode(json));
}

List<String> issues(List<TrackingArtifact> artifacts) => TrackingValidator()
    .validate(artifacts)
    .map((issue) => issue.toString())
    .toList();

void rejects(List<TrackingArtifact> artifacts, String code) {
  expect(issues(artifacts), anyElement(endsWith(': $code')));
}

void main() {
  test(
    'incomplete coverage returns issues without throwing for every state',
    () {
      for (final state in TrackingEvidenceState.values) {
        for (final counts in [
          {'recorded_count': 1},
          {'required_count': 2},
          {'recorded_count': -1, 'required_count': 2},
          {'recorded_count': 1, 'required_count': 0},
        ]) {
          final malformed = change(TrackingFixtures.measurement(), (json) {
            json.remove('canonical_value');
            json['evidence'] = {
              'state': state.name,
              'reason': 'synthetic',
              ...counts,
            };
          });
          rejects([
            ...TrackingFixtures.definitions,
            malformed,
          ], 'invalid_coverage');
        }
      }
    },
  );

  test('conflicting dependency versions cannot choose the first artifact', () {
    final first = TrackingFixtures.method();
    final conflicting = change(first, (json) {
      json['kind'] = 'difference';
      json['input_units'] = ['seconds', 'seconds'];
    });
    final closure = [first, conflicting, TrackingFixtures.metric()];
    rejects(closure, 'ambiguous_method');
    expect(issues(closure), issues(closure.reversed.toList()));
  });

  test(
    'source alias ambiguity is diagnosed for both identities independent of order',
    () {
      final first = TrackingFixtures.measurement(fromHistory: true);
      final alias = change(first, (json) {
        json['id'] = 'synthetic.alias';
        json['source']['source_id'] = 'synthetic.alias-source';
      });
      final closure = [...TrackingFixtures.definitions, first, alias];
      expect(issues(closure), issues(closure.reversed.toList()));
      expect(
        issues(
          closure,
        ).where((i) => i.endsWith(': duplicate_source_measurement')),
        hasLength(2),
      );
    },
  );

  test(
    'History field cannot claim a set row and a running repetition together',
    () {
      final ambiguous = change(
        TrackingFixtures.measurement(fromHistory: true),
        (json) {
          final history = json['source']['history'];
          history['exercise_result_id'] = 'synthetic.exercise';
          history['set_result_id'] = 'synthetic.set';
          history['workout_id'] = 'synthetic.workout';
          history['step_id'] = 'synthetic.step';
          history['repeat_ordinal'] = 1;
        },
      );
      rejects([
        ...TrackingFixtures.definitions,
        ambiguous,
      ], 'ambiguous_history_row_scope');
    },
  );

  test('same History result ID cannot declare two parent records', () {
    final first = TrackingFixtures.measurement(fromHistory: true);
    final contradictory = change(first, (json) {
      json['id'] = 'synthetic.other';
      json['source']['history']['record_id'] = 'synthetic.other-record';
    });
    final closure = [...TrackingFixtures.definitions, first, contradictory];
    rejects(closure, 'history_parent_reference_conflict');
    expect(issues(closure), issues(closure.reversed.toList()));
  });

  test('exercise and set parent declarations must remain coherent', () {
    final first = change(TrackingFixtures.measurement(fromHistory: true), (
      json,
    ) {
      json['source']['history']['exercise_result_id'] = 'synthetic.exercise';
      json['source']['history']['set_result_id'] = 'synthetic.set';
    });
    for (final parentChange in ['block_result_id', 'exercise_result_id']) {
      final second = change(first, (json) {
        json['id'] = 'synthetic.other';
        json['source']['history'][parentChange] = 'synthetic.other-parent';
      });
      rejects([
        ...TrackingFixtures.definitions,
        first,
        second,
      ], 'history_parent_reference_conflict');
    }
  });

  test('one History record cannot declare contradictory programme origins', () {
    final first = change(TrackingFixtures.measurement(fromHistory: true), (
      json,
    ) {
      json['source']['programme_scope'] = TrackingFixtures.scope().toJson();
      json['source']['assignment_id'] = 'synthetic.assignment';
      json['source']['occurrence_id'] = 'synthetic.occurrence';
      json['source']['training_session_id'] = 'synthetic.session';
    });
    for (final link in [
      'assignment_id',
      'occurrence_id',
      'training_session_id',
      'slot_key',
    ]) {
      final second = change(first, (json) {
        json['id'] = 'synthetic.other';
        json['source']['history']['block_result_id'] = 'synthetic.other-block';
        if (link == 'slot_key') {
          json['source']['programme_scope'][link] = 'synthetic.other';
        } else {
          json['source'][link] = 'synthetic.other';
        }
      });
      rejects([
        ...TrackingFixtures.definitions,
        first,
        second,
      ], 'history_parent_reference_conflict');
    }
  });

  test('one audit can cover distinct fields and blocks in the same record', () {
    final first = TrackingFixtures.measurement(
      fromHistory: true,
      correctionId: 'synthetic.audit',
    );
    final otherBlock = change(first, (json) {
      json['id'] = 'synthetic.other';
      json['source']['history']['block_result_id'] = 'synthetic.other-block';
      json['source']['history']['source_block_id'] =
          'synthetic.other-source-block';
    });
    expect(
      issues([...TrackingFixtures.definitions, first, otherBlock]),
      isEmpty,
    );
  });

  test('one correction audit ID cannot belong to two records or athletes', () {
    final first = TrackingFixtures.measurement(
      fromHistory: true,
      correctionId: 'synthetic.audit',
    );
    for (final changeOwner in [false, true]) {
      final second = change(first, (json) {
        json['id'] = 'synthetic.other';
        if (changeOwner) {
          json['athlete_id'] = 'synthetic.other-athlete';
        } else {
          json['source']['history']['record_id'] = 'synthetic.other-record';
          json['source']['history']['block_result_id'] =
              'synthetic.other-block-result';
        }
      });
      rejects([
        ...TrackingFixtures.definitions,
        first,
        second,
      ], 'history_audit_reference_conflict');
    }
  });

  test(
    'profile ID cannot change owner or curated/custom authority across versions',
    () {
      final custom = TrackingFixtures.custom();
      final curated = change(
        TrackingFixtures.curated(version: 2),
        (json) => json['id'] = custom.id,
      );
      rejects([
        ...TrackingFixtures.definitions,
        custom,
        curated,
      ], 'profile_authority_changed');
    },
  );

  test(
    'absent optional History identities and unsupported capabilities stay honest',
    () {
      final first = TrackingFixtures.measurement(fromHistory: true);
      expect(issues([...TrackingFixtures.definitions, first]), isEmpty);
      expect(first.source.history!.canReconstructHistoricalInputs, isFalse);
      expect(first.grantsPrescriptionEligibility, isFalse);
    },
  );
}
