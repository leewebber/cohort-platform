import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root = _repoRoot(Directory.current);
  final packageDir = Directory('$root/lib/features/authored_plan_package');
  final sharedPackageDir = Directory('$root/packages/cohort_plan_package/lib');

  test('Plan Package Dart files do not import plans or Coach Brain modules', () {
    expect(packageDir.existsSync(), isTrue);
    expect(sharedPackageDir.existsSync(), isTrue);
    final importPattern = RegExp(
      r'''^import\s+['"][^'"]*(features/plans/|plan_definition|coach_brain|planning/orchestration|supabase)''',
      multiLine: true,
    );

    for (final file in [
      ...packageDir.listSync().whereType<File>(),
      ...sharedPackageDir.listSync(recursive: true).whereType<File>(),
    ]) {
      if (!file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      expect(
        importPattern.hasMatch(source),
        isFalse,
        reason: '${file.path} must not import legacy generative / DB modules',
      );
    }
  });

  test('Plan Package compiler has no async or persistence surface', () {
    final compiler = File(
      '$root/packages/cohort_plan_package/lib/src/plan_package_compiler.dart',
    ).readAsStringSync();
    expect(compiler.contains('Future<'), isFalse);
    expect(compiler.contains('compile(String'), isTrue);
    expect(RegExp(r'''import\s+['"].*supabase''').hasMatch(compiler), isFalse);
    expect(
      RegExp(r'''import\s+['"].*features/plans/''').hasMatch(compiler),
      isFalse,
    );
  });

  test(
    'Flutter package consumes the single shared compiler implementation',
    () {
      final wrapper = File(
        '$root/lib/features/authored_plan_package/plan_package_compiler.dart',
      ).readAsStringSync();
      expect(
        wrapper.trim(),
        "export 'package:cohort_plan_package/plan_package_compiler.dart';",
      );

      final implementations =
          [
                Directory('$root/lib'),
                Directory('$root/packages/cohort_plan_package/lib'),
                Directory('$root/server/trusted_plan_package_import/lib'),
              ]
              .expand((directory) => directory.listSync(recursive: true))
              .whereType<File>()
              .where((file) => file.path.endsWith('.dart'))
              .where(
                (file) => file.readAsStringSync().contains(
                  'class PlanPackageCompiler',
                ),
              )
              .map((file) => file.path.substring(root.length + 1))
              .toList();
      expect(implementations, [
        'packages/cohort_plan_package/lib/src/plan_package_compiler.dart',
      ]);
    },
  );

  test(
    'compiler behavioural authority: no PlanDefinition types in compile path',
    () {
      // Type-level: compile only accepts String YAML and returns package types.
      // Import graph already checked above; this asserts the public API shape.
      final manifest = File(
        '$root/packages/cohort_plan_package/lib/src/plan_package_manifest.dart',
      ).readAsStringSync();
      expect(
        RegExp(r'''import\s+['"].*plan_definition''').hasMatch(manifest),
        isFalse,
      );
      expect(manifest.contains('class PlanPackageManifest'), isTrue);
    },
  );
}

String _repoRoot(Directory start) {
  var dir = start;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return dir.path;
    if (dir.parent.path == dir.path) return start.path;
    dir = dir.parent;
  }
}
