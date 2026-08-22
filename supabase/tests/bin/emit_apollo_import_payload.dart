import 'dart:convert';
import 'dart:io';

import 'package:cohort_plan_package/cohort_plan_package.dart';

/// Emits the exact trusted-import RPC payload for the approved Apollo YAML.
///
/// This is intentionally a test-harness bridge: compilation and payload
/// construction remain owned by the shared production package.
void main(List<String> arguments) {
  if (arguments.length != 1) {
    stderr.writeln('Usage: dart run supabase/tests/bin/emit_apollo_import_payload.dart <output-json>');
    exitCode = 64;
    return;
  }

  const source = 'tool/programmes/apollo_build_12_week_v1.plan-package.yaml';
  const expectedHash =
      '7264703a8db56edd6685e97e736405ffa99124fd4c419a676a1246653ea52b87';
  final compiled = const PlanPackageCompiler().compile(File(source).readAsStringSync());
  if (!compiled.isValid || compiled.contentHashSha256 != expectedHash) {
    stderr.writeln('Apollo package failed canonical compilation: ${compiled.issues}');
    exitCode = 1;
    return;
  }

  final payload = const PlanPackageImportPayloadBuilder().build(
    compileResult: compiled,
    importedBy: 'apollo-local-founder@example.invalid',
  );
  File(arguments.single).writeAsStringSync(jsonEncode(payload));
}
