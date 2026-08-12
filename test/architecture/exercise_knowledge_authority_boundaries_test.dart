import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Phase 3.1B/3.1C — Exercise Knowledge Authority boundary protections.
///
/// Proves contracts and repository boundary exist under the canonical domain
/// package, use EX-* only, and expose only the authorised application read
/// projection outside the domain package.
void main() {
  final root = _repoRoot(Directory.current);
  final domainDir = Directory('$root/lib/domain/exercise_knowledge');

  test('Exercise Knowledge Authority domain package exists', () {
    expect(domainDir.existsSync(), isTrue);
    expect(
      File('${domainDir.path}/exercise_knowledge_domain.dart').existsSync(),
      isTrue,
    );
  });

  test('canonical identity in new contracts is EX-* only', () {
    final idSource = File(
      '${domainDir.path}/value_objects/exercise_id.dart',
    ).readAsStringSync();
    expect(idSource.contains(r'^EX-\d+$'), isTrue);
    expect(idSource.contains('cohort.exercise'), isTrue);
    expect(
      idSource.contains('Transitional knowledge id is not a canonical'),
      isTrue,
    );
    // No third identity system introduced in the value object.
    expect(idSource.contains('ExerciseUuid'), isFalse);
    expect(idSource.contains('exercise_uuid'), isFalse);
    expect(idSource.contains('platform_exercise_slug'), isFalse);
  });

  test('ExerciseDefinition forbids prescription and evidence fields', () {
    final def = File(
      '${domainDir.path}/models/exercise_definition.dart',
    ).readAsStringSync();
    expect(RegExp(r'\bfinal\s+\w+\s+sets\b').hasMatch(def), isFalse);
    expect(RegExp(r'\bfinal\s+\w+\s+reps\b').hasMatch(def), isFalse);
    expect(RegExp(r'\bfinal\s+\w+\s+tempo\b').hasMatch(def), isFalse);
    expect(def.contains('athleteResult'), isFalse);
    expect(def.contains('completedLoad'), isFalse);
    expect(def.contains("'sets'"), isFalse);
    expect(def.contains("'reps'"), isFalse);
    expect(
      def.contains('Does **not** store sets, reps, load, tempo'),
      isTrue,
    );
  });

  test('authority does not implement adaptation application or progression', () {
    for (final entity in domainDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      const forbidden = [
        'applyAdaptation',
        'selectSubstitution',
        'ProgressCalculator',
        'computeProgression',
        'bypassAthleteAgreement',
        'PreviousPerformanceService',
        'CompletionEvidence',
      ];
      for (final token in forbidden) {
        expect(
          source.contains(token),
          isFalse,
          reason: '${entity.path} must not contain $token',
        );
      }
    }
  });

  test(
    'only the authorised application projection imports exercise knowledge',
    () {
      final lib = Directory('$root/lib');
      final offenders = <String>[];
      for (final entity in lib.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final rel = entity.path.substring(root.length + 1);
        if (rel.startsWith('lib/domain/exercise_knowledge/')) continue;
        if (rel.startsWith('lib/application/exercise_knowledge/')) continue;
        final source = entity.readAsStringSync();
        if (source.contains('domain/exercise_knowledge') ||
            source.contains('exercise_knowledge_domain')) {
          offenders.add(rel);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'Exercise Knowledge must not enter feature or production consumers. '
            'Offenders: $offenders',
      );
    },
  );

  test(
    'application projection remains text-only, local, and authority-neutral',
    () {
      final applicationDir = Directory(
        '$root/lib/application/exercise_knowledge',
      );
      expect(applicationDir.existsSync(), isTrue);

      final offenders = <String>[];
      const forbidden = [
        'video_reference.dart',
        'package:supabase',
        '/features/',
        'workout_player',
        'plan_package',
        'TransitionalExerciseIdBridge',
        'applyAdaptation',
        'selectSubstitution',
        'CompletionEvidence',
        'PreviousPerformanceService',
      ];
      for (final entity in applicationDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();
        for (final token in forbidden) {
          if (source.contains(token)) {
            offenders.add(
              '${entity.path.substring(root.length + 1)} contains $token',
            );
          }
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    },
  );

  test('Plan Package and features do not consume Exercise Knowledge', () {
    final offenders = <String>[];
    for (final path in [
      '$root/packages/cohort_plan_package',
      '$root/server/trusted_plan_package_import',
      '$root/lib/features',
    ]) {
      final directory = Directory(path);
      if (!directory.existsSync()) continue;
      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();
        if (source.contains('domain/exercise_knowledge') ||
            source.contains('exercise_knowledge_domain') ||
            source.contains('application/exercise_knowledge')) {
          offenders.add(entity.path.substring(root.length + 1));
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('transitional cohort.exercise.* knowledge paths remain present', () {
    expect(
      File('$root/knowledge/reference/exercises_reference.yaml').existsSync(),
      isTrue,
    );
    expect(Directory('$root/lib/knowledge').existsSync(), isTrue);
    final yaml = File('$root/knowledge/reference/exercises_reference.yaml')
        .readAsStringSync();
    expect(yaml.contains('cohort.exercise.'), isTrue);
  });

  test('relationship types never imply comparability by default', () {
    final source = File(
      '${domainDir.path}/vocabulary/exercise_relationship_type.dart',
    ).readAsStringSync();
    expect(
      source.contains('impliesComparabilityByDefault => false'),
      isTrue,
    );
    expect(source.contains('directly_comparable_variant'), isTrue);
  });

  test('repository port exists without Supabase or display-name identity', () {
    final port = File(
      '${domainDir.path}/ports/exercise_knowledge_repository.dart',
    ).readAsStringSync();
    expect(port.contains('abstract interface class ExerciseKnowledgeRepository'),
        isTrue);
    expect(port.contains('supabase'), isFalse);
    expect(port.contains('Supabase'), isFalse);
    expect(port.contains('resolveByDisplayName'), isFalse);
    expect(port.contains('getByName'), isFalse);

    final memory = File(
      '${domainDir.path}/in_memory/in_memory_exercise_knowledge_repository.dart',
    ).readAsStringSync();
    expect(memory.contains('supabase'), isFalse);
    expect(memory.contains('package:supabase'), isFalse);
  });

  test('draft cannot be operational; publication requires founder', () {
    final lookup = File(
      '${domainDir.path}/models/exercise_definition_lookup.dart',
    ).readAsStringSync();
    expect(lookup.contains('isRuntimeAuthoritative'), isTrue);

    final publication = File(
      '${domainDir.path}/services/exercise_knowledge_publication_service.dart',
    ).readAsStringSync();
    expect(publication.contains("founderOwner = 'founder'"), isTrue);
    expect(publication.contains('founder_authority_required'), isTrue);
  });

  test('identity bridge is one-way into EX-* and non-authoritative for transitional', () {
    final bridge = File(
      '${domainDir.path}/ports/transitional_exercise_id_bridge.dart',
    ).readAsStringSync();
    expect(bridge.contains('TransitionalExerciseIdBridge'), isTrue);
    expect(bridge.contains('One-way bridge'), isTrue);
    expect(bridge.contains('Does not resolve search aliases'), isTrue);
    expect(bridge.contains('supabase'), isFalse);

    final impl = File(
      '${domainDir.path}/in_memory/in_memory_transitional_exercise_id_bridge.dart',
    ).readAsStringSync();
    expect(impl.contains('package:supabase'), isFalse);
    expect(impl.contains('applyAdaptation'), isFalse);
    expect(impl.contains('selectSubstitution'), isFalse);

    final mapping = File(
      '${domainDir.path}/models/exercise_identity_mapping.dart',
    ).readAsStringSync();
    expect(mapping.contains('Does **not** imply substitution'), isTrue);

    final adapter = File(
      '${domainDir.path}/adapters/canonicalised_exercise_knowledge_adapter.dart',
    ).readAsStringSync();
    expect(adapter.contains('grantsComparability => false'), isTrue);
    expect(adapter.contains('grantsSubstitutionPermission => false'), isTrue);
  });

  test('heuristic name identity matching is rejected by mapping validator', () {
    final validator = File(
      '${domainDir.path}/validation/exercise_identity_mapping_validator.dart',
    ).readAsStringSync();
    expect(validator.contains('heuristic_mapping_provenance'), isTrue);
    expect(validator.contains('name_match'), isTrue);
  });

  test('relationship graph is derived read model without selection authority', () {
    final graph = File(
      '${domainDir.path}/graph/exercise_relationship_graph.dart',
    ).readAsStringSync();
    expect(graph.contains('Derived read-model graph'), isTrue);
    expect(graph.contains('selectSubstitution'), isFalse);
    expect(graph.contains('applyAdaptation'), isFalse);
    expect(graph.contains('supabase'), isFalse);
    expect(graph.contains('package:supabase'), isFalse);

    final eligibility = File(
      '${domainDir.path}/graph/relationship_eligibility.dart',
    ).readAsStringSync();
    expect(eligibility.contains('isSelected => false'), isTrue);
    expect(eligibility.contains('may be considered'), isTrue);

    final firewall = File(
      '${domainDir.path}/graph/comparability_firewall.dart',
    ).readAsStringSync();
    expect(firewall.contains('adjacencyImpliesComparability'), isTrue);
    expect(firewall.contains('traversalImpliesComparability'), isTrue);
    expect(
      firewall.contains('sameExerciseComparisonRequiresGraphEdge'),
      isTrue,
    );
    expect(
      firewall.contains('Not** a competing comparison authority'),
      isTrue,
    );
    // Must not independently resolve full comparability.
    expect(firewall.contains('areDirectlyComparable'), isFalse);
    expect(firewall.contains('protocolAppliesTo'), isFalse);

    final semantics = File(
      '${domainDir.path}/vocabulary/exercise_relationship_semantics.dart',
    ).readAsStringSync();
    expect(semantics.contains('isExplicitlySymmetric => false'), isTrue);
    expect(semantics.contains('inverseMustBeAuthoredSeparately => true'), isTrue);
  });
}

String _repoRoot(Directory start) {
  var dir = start;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return dir.path;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Could not locate repo root from ${start.path}');
    }
    dir = parent;
  }
}
