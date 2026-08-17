import 'dart:io';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_prescription_mapper.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_yaml_parser.dart';

void main() {
  late String founderYaml;

  setUpAll(() {
    founderYaml = File(
      'tool/programmes/spartan_physique_block1_week1.yaml',
    ).readAsStringSync();
  });

  test('Upper Strength carries the exact structured warm-up correction', () {
    final document = const FounderProgrammeYamlParser().parse(founderYaml);
    final upper = document.weeks.single.days.first.sessions.single;
    expect(upper.blocks, hasLength(6));

    final warmUp = upper.blocks.first;
    expect(warmUp.exercises.map((exercise) => exercise.exerciseSlug), [
      'easy-bike',
      'band-pull-apart',
      'scapular-push-up',
      'dead-hang',
    ]);
    expect(warmUp.coachNotes, isNull);
    expect(warmUp.exercises.first.executionGroup, isNull);

    final circuit = warmUp.exercises.skip(1).toList(growable: false);
    for (final exercise in circuit) {
      expect(exercise.executionGroup?.key, 'upper-strength-warm-up-circuit');
      expect(exercise.executionGroup?.label, 'Warm-Up Circuit');
      expect(exercise.executionGroup?.rounds, 2);
    }

    expect(warmUp.exercises[0].prescription?['sets'], 1);
    expect(warmUp.exercises[0].prescription?['notes'], contains('cadence'));
    expect(warmUp.exercises[1].prescription?['sets'], 2);
    expect(warmUp.exercises[1].prescription?['reps'], 20);
    expect(warmUp.exercises[2].prescription?['sets'], 2);
    expect(warmUp.exercises[3].prescription?['sets'], 2);
    expect(warmUp.exercises[3].prescription?['rest_seconds'], 30);
  });

  test('Farmer Carry declares blank-actual capture semantics', () {
    final document = const FounderProgrammeYamlParser().parse(founderYaml);
    final carry = document
        .weeks
        .single
        .days
        .first
        .sessions
        .single
        .blocks
        .last
        .exercises
        .single;
    final mapped = const FounderProgrammePrescriptionMapper().mapPrescription(
      carry.prescription,
    );

    expect(mapped?.sets, 4);
    expect(mapped?.reps.type.name, 'distance');
    expect(mapped?.performanceCapture?.loadUnit, 'kg');
    expect(mapped?.performanceCapture?.loadLabel, 'Load per hand');
    expect(mapped?.performanceCapture?.distanceUnit, 'm');
    expect(mapped?.performanceCapture?.durationOptional, isTrue);
    expect(mapped?.load, isNull);
  });

  test('canonical Spartan package v3 compiles deterministically', () {
    final source = File(
      'tool/programmes/spartan_physique_block1_week1.plan-package.yaml',
    ).readAsStringSync();
    final first = const PlanPackageCompiler().compile(source);
    final second = const PlanPackageCompiler().compile(source);

    expect(first.isValid, isTrue, reason: first.issues.join('\n'));
    expect(first.manifest?.programme.versionNumber, 3);
    expect(first.manifest?.sessions.first.revisionNumber, 2);
    expect(
      first.manifest?.sessions.first.protocolId,
      'founder-spartan-physique-v1-w1-d1-s1-rev-2',
    );
    expect(first.canonicalJson, second.canonicalJson);
    expect(first.contentHashSha256, second.contentHashSha256);
    expect(first.contentHashSha256, matches(RegExp(r'^[0-9a-f]{64}$')));
  });
}
