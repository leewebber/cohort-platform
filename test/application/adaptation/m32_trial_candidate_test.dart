import 'dart:convert';
import 'dart:io';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:cohort_platform/features/private_programme/reviewed_protocol_graph_artifact.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

const m32Candidate = 'docs/programmes/m32_time_trial';
const m32Version = 'd0576566-e080-4e6f-9428-6bb10d82826a';

void main() {
  test('the M3.2 publication envelope pins the exact approved trial', () {
    final pins = _json('TRIAL_PINS.json');
    expect(pins['version_id'], m32Version);
    for (final file in [
      'programme.plan-package.yaml',
      'protocol-graphs.json',
      'time-approval.json',
      'catalogue-pins.json',
    ]) {
      expect(
        sha256
            .convert(File('$m32Candidate/$file').readAsBytesSync())
            .toString(),
        pins['${file}_sha256'],
      );
    }
    final compile = const PlanPackageCompiler().compile(
      File('$m32Candidate/programme.plan-package.yaml').readAsStringSync(),
    );
    expect(compile.isValid, isTrue, reason: compile.issues.toString());
    final graphs = const ReviewedProtocolGraphArtifact().decode(
      compileResult: compile,
      source: File('$m32Candidate/protocol-graphs.json').readAsStringSync(),
      expectedSha256: pins['protocol-graphs.json_sha256'] as String,
    );
    final graph = graphs.single;
    expect(graph['protocol_id'], pins['protocol_id']);
    final blocks = (graph['blocks'] as List).cast<Map>();
    expect(blocks.map((b) => b['timer_config']['duration_seconds']), [
      300,
      1500,
      900,
    ]);
    final exercises = blocks
        .map((b) => (b['exercises'] as List).single as Map)
        .toList();
    expect(exercises.map((e) => e['exercise_id']), [
      'EX-008',
      'EX-083',
      'EX-044',
    ]);
    for (final (i, sets, reps, rest) in [(1, 4, 8, 120), (2, 3, 12, 60)]) {
      expect(exercises[i]['prescription'], {
        'sets': sets,
        'reps': {'type': 'exact', 'exact_reps': reps},
        'rest_seconds': rest,
        'load': {'type': 'athleteSelected'},
      });
    }
    final catalogue = _json('catalogue-pins.json');
    final source = File(catalogue['source'] as String);
    expect(
      sha256.convert(source.readAsBytesSync()).toString(),
      catalogue['source_sha256'],
    );
    final retained =
        (jsonDecode(source.readAsStringSync()) as List)
                .single['jsonb_build_object']['rows']
            as List;
    for (final row in (catalogue['rows'] as List).cast<Map>()) {
      final match =
          retained.singleWhere((r) => r['exercise_id'] == row['exercise_id'])
              as Map;
      expect({for (final key in row.keys) key: match[key]}, row);
      expect(row['published'], isTrue);
    }
    final approval = _json('time-approval.json');
    expect(approval['slot_key'], pins['slot_key']);
    expect(approval['protocol_id'], graph['protocol_id']);
    expect(
      [
        approval['full_minutes'],
        approval['short_minutes'],
        approval['omitted_block_position'],
      ],
      [45, 30, 3],
    );
    final payload =
        const PlanPackageImportPayloadBuilder().buildRetainedPublication(
            compileResult: compile,
            importedBy: 'm32-trial-review',
          )
          ..['programme_version_id'] = m32Version
          ..['protocol_graphs'] = graphs
          ..['publication_kind'] = 'private_exact_version'
          ..['library_scope'] = 'coach_private';
    expect(payload['adaptation_permissions'], isEmpty);
    if (pins['package_content_hash'] case final String expected) {
      expect(payload['package_content_hash'], expected);
    }
    final output = Platform.environment['M32_LOCAL_PAYLOAD'];
    if (output != null) {
      File(output).writeAsStringSync(
        jsonEncode({'payload': payload, 'approval': approval}),
      );
    }
  });
}

Map<String, dynamic> _json(String file) =>
    jsonDecode(File('$m32Candidate/$file').readAsStringSync())
        as Map<String, dynamic>;
