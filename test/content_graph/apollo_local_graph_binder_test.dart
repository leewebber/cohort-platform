import 'dart:io';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:cohort_platform/domain/content_graph/apollo_local_graph_binder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String yaml;
  late Map<String, String> weekSql;

  setUpAll(() {
    yaml = File(
      'tool/programmes/apollo_build_12_week_v1.plan-package.yaml',
    ).readAsStringSync();
    weekSql = {
      for (final file in Directory('supabase/migrations').listSync())
        if (file is File &&
            file.path.contains('apollo') &&
            file.path.endsWith('.sql') &&
            file.readAsStringSync().contains('EX-'))
          file.path: file.readAsStringSync(),
    };
  });

  test('Apollo Plan Package v1 hash is unchanged and graph regenerates identically', () {
    const packageCompiler = PlanPackageCompiler();
    final package = packageCompiler.compile(yaml);
    expect(package.isValid, isTrue);
    expect(
      package.contentHashSha256,
      ApolloLocalGraphBinder.expectedPlanPackageHash,
    );

    final first = ApolloLocalGraphBinder().bind(
      planPackageYaml: yaml,
      weekSqlByPath: weekSql,
    );
    final second = ApolloLocalGraphBinder().bind(
      planPackageYaml: yaml,
      weekSqlByPath: weekSql,
    );

    expect(first.packageHash, ApolloLocalGraphBinder.expectedPlanPackageHash);
    expect(first.manifest.canonicalJson, second.manifest.canonicalJson);
    expect(
      first.manifest.graphCanonicalSha256,
      second.manifest.graphCanonicalSha256,
    );
    expect(
      first.manifest.compositeContentIdentity,
      second.manifest.compositeContentIdentity,
    );
    expect(
      first.manifest.sourceCanonicalContentSha256,
      ApolloLocalGraphBinder.expectedPlanPackageHash,
    );
    expect(first.supplemental.exerciseIds.length, 58);
    expect(
      first.supplemental.exerciseIds.length,
      ApolloLocalGraphBinder.expectedCanonicalExerciseCount,
    );

    for (final id in first.supplemental.exerciseIds) {
      expect(id, matches(RegExp(r'^EX-\d+$')));
      expect(first.store.exercise(id), isNotNull);
      expect(first.store.exercise(id)!.unresolvedLegacy, isFalse);
    }

    expect(first.catalogueNames['EX-095'], isNot(first.catalogueNames['EX-137']));
    expect(first.supplemental.exerciseIds.contains('EX-095'), isTrue);
    expect(first.supplemental.exerciseIds.contains('EX-137'), isTrue);
    expect(first.supplemental.exerciseIds.contains('EX-129'), isTrue);
    if (first.supplemental.exerciseIds.contains('EX-149')) {
      expect(first.catalogueNames['EX-149'], isNot(first.catalogueNames['EX-095']));
    }

    expect(
      first.unresolved.any((item) => item.contains('guess') || item.contains('similar')),
      isFalse,
    );
    for (final item in first.unresolved) {
      expect(item.startsWith('legacy_tmp:') || item.startsWith('name_only_block:'), isTrue);
    }

    expect(first.manifest.compilerVersion, 'content-graph-compiler/v1');
    expect(
      first.service.compileDraft(first.manifest.programmeVersionId).sha256,
      first.manifest.graphCanonicalSha256,
    );
  });

  test('v1 runtime does not require a proposed Plan Package v2 schema', () {
    const compiler = PlanPackageCompiler();
    final result = compiler.compile(yaml);
    expect(result.manifest!.packageSchemaVersion, 1);
    expect(
      result.contentHashSha256,
      ApolloLocalGraphBinder.expectedPlanPackageHash,
    );
  });

  test('display-name similarity is not used as identity', () {
    final bound = ApolloLocalGraphBinder().bind(
      planPackageYaml: yaml,
      weekSqlByPath: weekSql,
    );
    expect(
      () => bound.service.assertDerivedUsedByEdge(
        bound.service.deriveStructuralGraph(bound.manifest.programmeVersionId).edges.first,
        bound.manifest.programmeVersionId,
      ),
      returnsNormally,
    );
    expect(bound.store.exercise('Weighted Pull-Up'), isNull);
  });
}
