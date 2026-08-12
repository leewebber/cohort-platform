import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root = _repoRoot(Directory.current);

  test('founder tool adapter consumes identity contracts only', () {
    final source = File(
      '$root/tool/founder_programme_import/'
      'repository_transitional_identity_adapter.dart',
    ).readAsStringSync();
    expect(source, contains('TransitionalExerciseIdBridge'));
    for (final forbidden in const [
      'MovementStandard',
      'CoachingContent',
      'VideoReference',
      'ExerciseMovementKnowledge',
      'FounderApprovedMovementKnowledgePhase32d',
      'exercise_knowledge_domain.dart',
    ]) {
      expect(source.contains(forbidden), isFalse, reason: forbidden);
    }
  });

  test(
    'runtime, Plan Package, and knowledge content do not consume bridge',
    () {
      final roots = [
        '$root/lib/features/workout_player',
        '$root/lib/application/adaptation',
        '$root/lib/features/programme_comparison',
        '$root/lib/domain/workout_execution_record',
        '$root/packages/cohort_plan_package',
        '$root/server/trusted_plan_package_import',
      ];
      final offenders = <String>[];
      for (final path in roots) {
        final directory = Directory(path);
        if (!directory.existsSync()) continue;
        for (final entity in directory.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final source = entity.readAsStringSync();
          if (source.contains('TransitionalExerciseIdBridge') ||
              source.contains('FounderApprovedIdentityMappingsPhase31F')) {
            offenders.add(entity.path.substring(root.length + 1));
          }
        }
      }
      expect(offenders, isEmpty);
    },
  );

  test('importer port has no dependency on the application package', () {
    final source = File(
      '$root/tool/importer/lib/features/founder_programme_import/'
      'founder_programme_identity_resolution.dart',
    ).readAsStringSync();
    expect(source.contains('package:cohort_platform'), isFalse);
    expect(source.contains('domain/exercise_knowledge'), isFalse);
  });

  test('founder-approved mapping collection remains single-owned', () {
    final definitions = <String>[];
    for (final directory in [
      Directory('$root/lib'),
      Directory('$root/tool'),
      Directory('$root/packages'),
    ]) {
      if (!directory.existsSync()) continue;
      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.readAsStringSync().contains(
          'class FounderApprovedIdentityMappingsPhase31F',
        )) {
          definitions.add(entity.path.substring(root.length + 1));
        }
      }
    }
    expect(definitions, [
      'lib/domain/exercise_knowledge/seed/'
          'founder_approved_identity_mappings_phase_3_1f.dart',
    ]);
  });

  test('production code does not load historical catalogue review export', () {
    final offenders = <String>[];
    for (final directory in [Directory('$root/lib'), Directory('$root/tool')]) {
      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.readAsStringSync().contains(
          'exercises_v2_published_export_phase_3_1f',
        )) {
          offenders.add(entity.path.substring(root.length + 1));
        }
      }
    }
    expect(offenders, isEmpty);
  });
}

String _repoRoot(Directory start) {
  var directory = start.absolute;
  while (directory.parent.path != directory.path) {
    if (File('${directory.path}/pubspec.yaml').existsSync()) {
      return directory.path;
    }
    directory = directory.parent;
  }
  throw StateError('Could not locate repository root.');
}
