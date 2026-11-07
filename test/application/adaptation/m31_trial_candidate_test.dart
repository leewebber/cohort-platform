import 'dart:convert';
import 'dart:io';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:cohort_platform/application/adaptation/m31_thursday_equipment_trial.dart';
import 'package:cohort_platform/features/private_programme/reviewed_protocol_graph_artifact.dart';
import 'package:flutter_test/flutter_test.dart';

const m31Candidate = 'docs/programmes/hybrid_10k/m31_thursday_trial';

Map<String, Object?> buildTrialPublication() {
  final compile = const PlanPackageCompiler().compile(
    File('$m31Candidate/programme.plan-package.yaml').readAsStringSync(),
  );
  expect(compile.isValid, isTrue, reason: compile.issues.toString());
  expect(compile.contentHashSha256, M31ThursdayEquipmentTrial.packageHash);
  final graph = File('$m31Candidate/protocol-graphs.json').readAsStringSync();
  return const PlanPackageImportPayloadBuilder().buildRetainedPublication(
      compileResult: compile,
      importedBy: 'm31-local-trial',
    )
    ..['protocol_graphs'] = const ReviewedProtocolGraphArtifact().decode(
      compileResult: compile,
      source: graph,
      expectedSha256:
          '7dd9eff7c49a00d92a003163935d71749a43247fd7a82fb271f83d326bd65a64',
    )
    ..['publication_kind'] = 'private_exact_version'
    ..['library_scope'] = 'coach_private';
}

void main() {
  test('the one-session private trial preserves the genuine Thursday blocks', () {
    final payload = buildTrialPublication();
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
      File(output).writeAsStringSync(jsonEncode(payload));
    }
  });
}
