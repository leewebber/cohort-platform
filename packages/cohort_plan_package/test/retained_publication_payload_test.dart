import 'dart:convert';
import 'dart:io';
import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:test/test.dart';

void main() {
  for (final name in ['minimal_plan_package', 'minimal_plan_package_v2']) {
    test(
      '$name retention transport preserves canonical bytes/hash and import API',
      () {
        final compiled = const PlanPackageCompiler().compile(
          File('test/fixtures/$name.yaml').readAsStringSync(),
        );
        final builder = const PlanPackageImportPayloadBuilder();
        final ordinary = builder.build(
          compileResult: compiled,
          importedBy: 'synthetic',
        );
        final retained = builder.buildRetainedPublication(
          compileResult: compiled,
          importedBy: 'synthetic',
        );
        final tree = jsonDecode(compiled.canonicalJson!) as Map;
        expect(
          compiled.contentHashSha256,
          File('test/fixtures/$name.sha256').readAsStringSync().trim(),
        );
        expect(retained['package_canonical_json'], compiled.canonicalJson);
        expect(
          retained['package_content_hash'],
          ordinary['package_content_hash'],
        );
        for (final k in tree.keys.where((k) => k != 'programme')) {
          expect(retained[k], tree[k]);
        }
        expect(
          ordinary.containsKey('package_canonical_json'),
          compiled.manifest!.packageSchemaVersion == 2,
        );
      },
    );
  }
  test(
    'canonical artifact verifier checks generated digest without relaxing authored input',
    () {
      final compiler = const PlanPackageCompiler();
      final compiled = compiler.compile(
        File(
          'test/fixtures/minimal_plan_package_v2_b3.yaml',
        ).readAsStringSync(),
      );
      final text = compiled.canonicalJson!;
      expect(compiler.compile(text).isValid, false);
      final verified = compiler.verifyCanonicalArtifact(text);
      expect(verified.isValid, true, reason: verified.issues.toString());
      expect(verified.contentHashSha256, compiled.contentHashSha256);
      expect(compiler.verifyCanonicalArtifact('$text ').isValid, false);
      final tree = jsonDecode(text) as Map;
      tree['weeks'][0]['days'][0]['slots'][0]['authored_running_v1']['execution_mapping_sha256'] =
          'a' * 64;
      expect(compiler.verifyCanonicalArtifact(jsonEncode(tree)).isValid, false);
      expect(compiler.verifyCanonicalArtifact('{bad').isValid, false);
    },
  );
}
