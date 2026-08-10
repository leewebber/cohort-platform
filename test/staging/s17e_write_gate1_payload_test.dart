import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cohort_platform/features/authored_plan_package/authored_plan_package.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Published Staging session lineages for PROT-S15A-STAGING-1/2/3.
const _stagingLineageBySymbolic = <String, String>{
  'SL-S17E-G1-A': '02374e34-28bb-5b7e-972a-b61a7afc919f',
  'SL-S17E-G1-B': '761b2d0b-7dc8-5445-8cb8-614abbf2dedf',
  'SL-S17E-G1-C': '1460a878-68eb-5c2d-92fb-4319dd72063b',
};

/// Test-only helper: compile Gate 1 YAML, rebind lineages, write import payload.
void main() {
  test('write s17e gate1 import payload', () {
    final root = Directory.current.path;
    final yamlPath = '$root/tool/staging/fixtures/athlete_e/prog_s17e_gate1.yaml';
    final outPath =
        Platform.environment['S17E_PAYLOAD_OUT'] ??
        '${Directory.systemTemp.path}/s17e_gate1_import_payload.json';
    final yaml = File(yamlPath).readAsStringSync();
    final compile = const PlanPackageCompiler().compile(yaml);
    expect(compile.isValid, isTrue, reason: compile.issues.toString());

    final original = compile.manifest!;
    final reboundSessions = <PlanPackageSessionRevisionRef>[
      for (final s in original.sessions)
        PlanPackageSessionRevisionRef(
          sessionKey: s.sessionKey,
          protocolId: s.protocolId,
          sessionLineageId: _stagingLineageBySymbolic[s.sessionLineageId]!,
          revisionNumber: s.revisionNumber,
          title: s.title,
        ),
    ];
    final rebound = PlanPackageManifest(
      packageSchemaVersion: original.packageSchemaVersion,
      programme: original.programme,
      sessions: List.unmodifiable(reboundSessions),
      phases: original.phases,
      weeks: original.weeks,
      adaptationPermissions: original.adaptationPermissions,
      protectedInvariants: original.protectedInvariants,
      assessments: original.assessments,
      performanceEvidenceRequirements: original.performanceEvidenceRequirements,
      comparisonIdentities: original.comparisonIdentities,
    );

    final issues = const PlanPackageValidator().validate(rebound);
    expect(issues, isEmpty, reason: issues.toString());

    final bytes = const PlanPackageCanonicaliser().canonicalBytes(rebound);
    final hash = sha256.convert(bytes).toString();
    final reboundCompile = PlanPackageCompileResult.valid(
      manifest: rebound,
      canonicalBytes: Uint8List.fromList(bytes),
      contentHashSha256: hash,
    );

    final payload = const PlanPackageImportPayloadBuilder().build(
      compileResult: reboundCompile,
      importedBy: 's17e-gate1-importer',
    );
    final programme = payload['programme'] as Map<String, Object?>;
    expect(programme['lineage_code'], 'PROG-S17E-GATE1');
    expect(programme['version_number'], 2);

    for (final session in payload['sessions'] as List) {
      final map = session as Map;
      final lineage = map['session_lineage_id'] as String;
      expect(lineage.startsWith('SL-'), isFalse);
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        ).hasMatch(lineage),
        isTrue,
      );
    }

    File(outPath).writeAsStringSync(
      jsonEncode({
        'content_hash': hash,
        'pre_rebind_hash': compile.contentHashSha256,
        'payload': payload,
      }),
    );
  });
}
