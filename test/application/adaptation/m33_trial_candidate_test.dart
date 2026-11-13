import 'dart:convert';
import 'dart:io';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:cohort_platform/features/private_programme/reviewed_protocol_graph_artifact.dart';
import 'package:flutter_test/flutter_test.dart';

import 'm32_trial_candidate_test.dart' show m32Candidate;

const recoveryVersion = '7e1d15e7-20ee-46d4-b5e9-0d6449010330';
const recoveryPackageHash =
    'f7a402a26fd4738cc6b1cc99add4c20a87ce1087b934ab197220a3c05379faed';

void main() {
  test(
    'Recovery publishes a distinct identity with the exact Time workout',
    () {
      const draft = 'docs/programmes/m33_recovery_trial/proposed_source';
      final compiled = const PlanPackageCompiler().compile(
        File('$draft/programme.plan-package.yaml').readAsStringSync(),
      );
      expect(compiled.isValid, isTrue, reason: compiled.issues.toString());
      expect(compiled.contentHashSha256, recoveryPackageHash);
      final graphs = const ReviewedProtocolGraphArtifact().decode(
        compileResult: compiled,
        source: File('$draft/protocol-graphs.json').readAsStringSync(),
        expectedSha256:
            '7a127971ad36d301928ab2cc39ef4eca8b61df6da6ef44b218547af2cc51abdf',
      );
      final original =
          (jsonDecode(
                        File(
                          '$m32Candidate/protocol-graphs.json',
                        ).readAsStringSync(),
                      )
                      as List)
                  .single
              as Map;
      expect(graphs.single['protocol_id'], isNot(original['protocol_id']));
      expect(graphs.single['blocks'], original['blocks']);

      final payload =
          const PlanPackageImportPayloadBuilder().buildRetainedPublication(
              compileResult: compiled,
              importedBy: 'm33-disposable-review',
            )
            ..['programme_version_id'] = recoveryVersion
            ..['protocol_graphs'] = graphs
            ..['publication_kind'] = 'private_exact_version'
            ..['library_scope'] = 'coach_private';
      expect(payload['adaptation_permissions'], isEmpty);
      final output = Platform.environment['M33_LOCAL_PAYLOAD'];
      if (output != null) File(output).writeAsStringSync(jsonEncode(payload));
    },
  );
}
