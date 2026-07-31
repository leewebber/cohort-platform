import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root = _repoRoot(Directory.current);
  final importDir = Directory(
    '$root/lib/features/authored_plan_package/import',
  );

  test('import module does not depend on PlanDefinition or Coach Brain', () {
    expect(importDir.existsSync(), isTrue);
    final forbiddenImport = RegExp(
      r'''^import\s+['"][^'"]*(features/plans/|plan_definition|coach_brain|planning/orchestration)''',
      multiLine: true,
    );
    for (final file in importDir.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      expect(forbiddenImport.hasMatch(source), isFalse, reason: file.path);
      expect(source.contains('PlanDefinition'), isFalse, reason: file.path);
      expect(source.contains('CoachBrain'), isFalse, reason: file.path);
    }
  });

  test('import module does not embed service-role credentials', () {
    for (final file in importDir.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      expect(source.contains('SERVICE_ROLE'), isFalse, reason: file.path);
      expect(source.contains('service_role_key'), isFalse, reason: file.path);
      expect(
        source.contains('supabaseServiceRole'),
        isFalse,
        reason: file.path,
      );
    }
  });

  test('supabase store documents injected-client-only service role boundary', () {
    final store = File(
      '$root/lib/features/authored_plan_package/import/plan_package_import_supabase_store.dart',
    ).readAsStringSync();
    expect(store.contains('Never constructs a service-role client'), isTrue);
    expect(store.contains('import_authored_plan_package'), isTrue);
    expect(store.contains('publish_cohort_global_programme_version'), isTrue);
    expect(store.contains('approve_cohort_global_programme_version'), isTrue);
  });

  test('compiler foundation remains free of import RPC side effects', () {
    final compiler = File(
      '$root/lib/features/authored_plan_package/plan_package_compiler.dart',
    ).readAsStringSync();
    expect(compiler.contains('import_authored_plan_package'), isFalse);
    expect(compiler.contains('Supabase'), isFalse);
  });
}

String _repoRoot(Directory start) {
  var dir = start;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return dir.path;
    if (dir.parent.path == dir.path) return start.path;
    dir = dir.parent;
  }
}
