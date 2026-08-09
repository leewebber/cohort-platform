import 'dart:io';

import 'package:cohort_platform/domain/exercise_knowledge/exercise_knowledge_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final seed = FounderApprovedIdentityMappingsPhase31F.allMappings;
  const publication = ExerciseIdentityMappingPublicationService();
  const firewall = ComparabilityFirewall();

  test('authors exactly 21 founder-approved published mappings', () {
    expect(seed.length, 21);
    expect(
      seed.every((m) => m.lifecycleStatus == ExerciseLifecycleStatus.published),
      isTrue,
    );
    expect(seed.every((m) => m.owner == 'founder'), isTrue);
    expect(
      seed.every((m) => m.provenance.contains('Founder-approved Phase 3.1F')),
      isTrue,
    );
  });

  test('each transitional id resolves exactly once to EX-*', () {
    final bridge = InMemoryTransitionalExerciseIdBridge(initial: seed);
    final yaml = File('knowledge/reference/exercises_reference.yaml')
        .readAsStringSync();
    final ids = RegExp(
      r'^\s+- id: (cohort\.exercise\.[a-z0-9_]+)',
      multiLine: true,
    ).allMatches(yaml).map((m) => m.group(1)!).toList();
    expect(ids.length, 21);

    final resolved = <String, String>{};
    for (final id in ids) {
      final outcome = bridge.resolve(id);
      expect(outcome, isA<TransitionalIdentityResolved>(), reason: id);
      final canonical = (outcome as TransitionalIdentityResolved).canonicalId.value;
      expect(canonical, matches(RegExp(r'^EX-\d+$')));
      resolved[id] = canonical;
    }
    expect(resolved.length, 21);
  });

  test('Batch A and F-02/F-03 targets match founder matrix exactly', () {
    final byTid = {
      for (final m in seed) m.transitionalId.value: m.canonicalId.value,
    };
    expect(byTid['cohort.exercise.back_squat'], 'EX-073');
    expect(byTid['cohort.exercise.front_squat'], 'EX-074');
    expect(byTid['cohort.exercise.goblet_squat'], 'EX-030');
    expect(byTid['cohort.exercise.romanian_deadlift'], 'EX-078');
    expect(byTid['cohort.exercise.walking_lunge'], 'EX-025');
    expect(byTid['cohort.exercise.pull_up'], 'EX-053');
    expect(byTid['cohort.exercise.bench_press'], 'EX-083');
    expect(byTid['cohort.exercise.strict_press'], 'EX-088');
    expect(byTid['cohort.exercise.push_up'], 'EX-012');
    expect(byTid['cohort.exercise.rowing'], 'EX-049');
    expect(byTid['cohort.exercise.farmer_carry'], 'EX-101');
    expect(byTid['cohort.exercise.plank'], 'EX-021');
    expect(byTid['cohort.exercise.dead_bug'], 'EX-022');
    expect(byTid['cohort.exercise.box_jump'], 'EX-059');
    expect(byTid['cohort.exercise.ski_erg'], 'EX-050');
    expect(byTid['cohort.exercise.wall_ball'], 'EX-052');
    expect(byTid['cohort.exercise.lat_pulldown'], 'EX-128');
    expect(byTid['cohort.exercise.running'], 'EX-129');
    expect(byTid['cohort.exercise.burpee_broad_jump'], 'EX-130');
    expect(byTid['cohort.exercise.sled_push'], 'EX-131');
    expect(byTid['cohort.exercise.sled_pull'], 'EX-132');
  });

  test('new canonical ids are unique and outside EX-001–EX-127', () {
    expect(FounderApprovedIdentityMappingsPhase31F.newCanonicalIds, {
      'EX-128',
      'EX-129',
      'EX-130',
      'EX-131',
      'EX-132',
    });
    for (final id in FounderApprovedIdentityMappingsPhase31F.newCanonicalIds) {
      final n = int.parse(id.substring(3));
      expect(n, greaterThan(127));
      expect(ExerciseId.parse(id).value, id);
    }
  });

  test('Running maps to generic EX-129 not intensity runs', () {
    final running = seed.singleWhere(
      (m) => m.transitionalId.value == 'cohort.exercise.running',
    );
    expect(running.canonicalId.value, 'EX-129');
    expect(running.canonicalId.value, isNot(anyOf('EX-001', 'EX-002', 'EX-003')));
    expect(running.notes, contains('Generic Running'));
  });

  test('SkiErg maps to EX-050 and notes banded-ski boundary', () {
    final ski = seed.singleWhere(
      (m) => m.transitionalId.value == 'cohort.exercise.ski_erg',
    );
    expect(ski.canonicalId.value, 'EX-050');
    expect(ski.notes, contains('Banded ski-pattern'));
  });

  test('Wall Ball maps to EX-052 with prescription/protocol boundary', () {
    final wb = seed.singleWhere(
      (m) => m.transitionalId.value == 'cohort.exercise.wall_ball',
    );
    expect(wb.canonicalId.value, 'EX-052');
    expect(wb.notes, contains('HYROX'));
    expect(wb.notes, contains('prescription'));
  });

  test('Sled Push and Sled Pull remain distinct identities', () {
    final push = seed.singleWhere(
      (m) => m.transitionalId.value == 'cohort.exercise.sled_push',
    );
    final pull = seed.singleWhere(
      (m) => m.transitionalId.value == 'cohort.exercise.sled_pull',
    );
    expect(push.canonicalId.value, 'EX-131');
    expect(pull.canonicalId.value, 'EX-132');
    expect(push.canonicalId, isNot(pull.canonicalId));
  });

  test('Burpee Broad Jump remains distinct from Burpee and Broad Jump', () {
    final bbj = seed.singleWhere(
      (m) => m.transitionalId.value == 'cohort.exercise.burpee_broad_jump',
    );
    expect(bbj.canonicalId.value, 'EX-130');
    expect(bbj.notes, contains('EX-009'));
    expect(bbj.notes, contains('EX-024'));
  });

  test('publication validates against known canonical targets', () {
    final bridge = InMemoryTransitionalExerciseIdBridge();
    final result = publication.publishMappings(
      bridge: bridge,
      draftMappings: seed,
      knownCanonicalIds:
          FounderApprovedIdentityMappingsPhase31F.knownCanonicalIds,
      actingOwner: 'founder',
      publishedAt: FounderApprovedIdentityMappingsPhase31F.publishedAt,
    );
    expect(result.isAccepted, isTrue);
    expect(result.mappings.length, 21);
  });

  test('unknown transitional id does not resolve heuristically', () {
    final bridge = InMemoryTransitionalExerciseIdBridge(initial: seed);
    final outcome = bridge.resolve('cohort.exercise.not_in_matrix');
    expect(outcome, isA<TransitionalIdentityUnmapped>());
  });

  test('mapping direction cannot be reversed through bridge', () {
    final bridge = InMemoryTransitionalExerciseIdBridge(initial: seed);
    expect(
      () => TransitionalExerciseId.parse('EX-073'),
      throwsA(isA<FormatException>()),
    );
    final forward = bridge.resolve('cohort.exercise.back_squat');
    expect(
      (forward as TransitionalIdentityResolved).canonicalId.value,
      'EX-073',
    );
  });

  test('mapping provenance forbids heuristic tokens', () {
    const validator = ExerciseIdentityMappingValidator();
    final issues = validator.validateCatalogue(
      mappings: seed,
      knownCanonicalIds:
          FounderApprovedIdentityMappingsPhase31F.knownCanonicalIds,
    );
    expect(issues, isEmpty);
    for (final m in seed) {
      final lower = m.provenance.toLowerCase();
      expect(lower.contains('heuristic'), isFalse);
      expect(lower.contains('name_match'), isFalse);
    }
  });

  test('bridge mapping never implies substitution or comparability', () {
    expect(firewall.bridgeMappingImpliesComparability(), isFalse);
    expect(firewall.substitutionEligibilityImpliesComparability(), isFalse);
    for (final m in seed) {
      expect(m.toJson().containsKey('grants_substitution'), isFalse);
      expect(m.toJson().containsKey('grants_comparability'), isFalse);
      expect(
        m.provenance.contains('does not grant substitution or comparability'),
        isTrue,
      );
    }
  });

  test('transitional ids cannot be parsed as canonical graph nodes', () {
    expect(
      ExerciseId.isCanonical('cohort.exercise.back_squat'),
      isFalse,
    );
    expect(
      TransitionalExerciseId.isTransitional('cohort.exercise.back_squat'),
      isTrue,
    );
    expect(
      () => ExerciseId.parse('cohort.exercise.back_squat'),
      throwsA(isA<FormatException>()),
    );
  });

  test('no live consumer outside exercise_knowledge imports founder seed', () {
    final root = _repoRoot(Directory.current);
    final lib = Directory('$root/lib');
    final offenders = <String>[];
    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final rel = entity.path.substring(root.length + 1);
      if (rel.startsWith('lib/domain/exercise_knowledge/')) continue;
      final source = entity.readAsStringSync();
      if (source.contains('FounderApprovedIdentityMappingsPhase31F') ||
          source.contains('founder_approved_identity_mappings_phase_3_1f')) {
        offenders.add(rel);
      }
    }
    expect(offenders, isEmpty, reason: 'Offenders: $offenders');
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
