import 'dart:convert';
import 'dart:io';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:cohort_platform/features/private_programme/reviewed_protocol_graph_artifact.dart';
import 'package:flutter_test/flutter_test.dart';

import 'm31_thursday_trial_fixture.dart';

const m31Candidate = 'docs/programmes/hybrid_10k/m31_thursday_trial';

const gobletCandidate = 'test/fixtures/m31_goblet_approval';
const gobletVersion = '8104b7ef-f09f-43cc-9815-97b279f186d0';

Map<String, Object?> buildTrialPublication(String directory, String graphHash) {
  final compile = const PlanPackageCompiler().compile(
    File('$directory/programme.plan-package.yaml').readAsStringSync(),
  );
  expect(compile.isValid, isTrue, reason: compile.issues.toString());
  final graph = File('$directory/protocol-graphs.json').readAsStringSync();
  return const PlanPackageImportPayloadBuilder().buildRetainedPublication(
      compileResult: compile,
      importedBy: 'm31-local-trial',
    )
    ..['protocol_graphs'] = const ReviewedProtocolGraphArtifact().decode(
      compileResult: compile,
      source: graph,
      expectedSha256: graphHash,
    )
    ..['publication_kind'] = 'private_exact_version'
    ..['library_scope'] = 'coach_private';
}

void main() {
  test('the one-session private trial preserves the genuine Thursday blocks', () {
    final payload = buildTrialPublication(
      m31Candidate,
      '7dd9eff7c49a00d92a003163935d71749a43247fd7a82fb271f83d326bd65a64',
    );
    expect(
      payload['package_content_hash'],
      M31ThursdayEquipmentTrial.packageHash,
    );
    final goblet = buildTrialPublication(
      gobletCandidate,
      'ee85a6b76110d5c6e42a0ecc2e7bbaf4a07533c03dd44783f76af0c34ff894e4',
    );
    final trial = (payload['protocol_graphs'] as List).single as Map;
    final source =
        jsonDecode(
              File(
                'docs/programmes/hybrid_10k/release_candidate_2026_11_04/protocol-graphs.json',
              ).readAsStringSync(),
            )
            as List;
    final thursday =
        source.singleWhere(
              (g) =>
                  g['protocol_id'] ==
                  'protocol-2bf58279-08c7-4498-a4ad-c8256ac589fb',
            )
            as Map;
    expect(trial['blocks'], thursday['blocks']);
    expect(trial['protocol_id'], M31ThursdayEquipmentTrial.protocolId);
    final permission =
        (payload['adaptation_permissions'] as List).single as Map;
    expect(permission['id'], M31ThursdayEquipmentTrial.permissionId);
    expect(permission['target_ref'], M31ThursdayEquipmentTrial.slotKey);
    expect(permission['change_kind'], 'substitute_approved_equipment');
    expect(permission['athlete_agreement_required'], isTrue);
    // Emit only when explicitly preparing the disposable local publication fixture.
    final output = Platform.environment['M31_LOCAL_PAYLOAD'];
    if (output != null) {
      final fixtures = {
        M31ThursdayEquipmentTrial.versionId: (m31Candidate, payload),
        gobletVersion: (gobletCandidate, goblet),
      };
      File(output).writeAsStringSync(
        jsonEncode([
          for (final entry in fixtures.entries)
            {
              'payload': {...entry.value.$2, 'programme_version_id': entry.key},
              'approval': jsonDecode(
                File(
                  '${entry.value.$1}/equipment-approval.json',
                ).readAsStringSync(),
              ),
            },
        ]),
      );
    }
  });
}
