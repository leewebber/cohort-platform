import 'dart:io';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:test/test.dart';

const _packagePath = '../../tool/programmes/bali_hybrid_base_v1.plan-package.yaml';
const _hashPath =
    '../../content/programmes/bali_hybrid_base/v1/package.sha256';
const _expectedHash =
    'f5da4085c0ea8b4c6eec93859451db624aaa52cd4af79ca702278518ea227b5b';

void main() {
  const compiler = PlanPackageCompiler();
  late String yaml;
  late PlanPackageCompileResult first;
  late PlanPackageCompileResult second;

  setUpAll(() {
    yaml = File(_packagePath).readAsStringSync();
    first = compiler.compile(yaml);
    second = compiler.compile(yaml);
  });

  test('compiles Bali Hybrid Base deterministically', () {
    expect(first.isValid, isTrue, reason: first.issues.toString());
    expect(second.isValid, isTrue);
    expect(first.canonicalJson, second.canonicalJson);
    expect(first.contentHashSha256, _expectedHash);
    expect(second.contentHashSha256, _expectedHash);
    expect(
      File(_hashPath).readAsStringSync().trim(),
      _expectedHash,
    );
    expect(first.manifest!.programme.lineageCode, 'BALI-HYBRID-BASE');
    expect(first.manifest!.programme.versionNumber, 1);
    expect(first.manifest!.programme.libraryScope, ProgrammeLibraryScope.coachPrivate);
    expect(first.manifest!.programme.durationWeeks, 8);
    expect(first.manifest!.sessions, hasLength(71));
    expect(first.manifest!.weeks, hasLength(8));
  });

  test('import payload preserves all 71 slots and identities', () {
    final payload = const PlanPackageImportPayloadBuilder().build(
      compileResult: first,
      importedBy: 'bali-local-review',
    );
    expect(payload['package_content_hash'], _expectedHash);
    final sessions = payload['sessions'] as List<dynamic>;
    expect(sessions, hasLength(71));
    final weeks = payload['weeks'] as List<dynamic>;
    var slotCount = 0;
    for (final week in weeks) {
      final days = (week as Map)['days'] as List<dynamic>;
      for (final day in days) {
        slotCount += ((day as Map)['slots'] as List<dynamic>).length;
      }
    }
    expect(slotCount, 71);
    expect(
      (payload['programme'] as Map)['lineage_code'],
      'BALI-HYBRID-BASE',
    );
    expect(payload.containsKey('library_scope'), isFalse);
    expect(payload.containsKey('approved_for_global'), isFalse);
  });
}
