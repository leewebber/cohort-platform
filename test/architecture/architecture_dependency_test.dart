import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root = _repoRoot(Directory.current);

  final coachBrain = File('$root/lib/planning/orchestration/coach_brain_service.dart')
      .readAsStringSync();

  test('Coach Brain does not import knowledge YAML loaders', () {
    expect(coachBrain.contains('yaml_knowledge'), isFalse);
    expect(coachBrain.contains('YamlKnowledge'), isFalse);
  });

  test('Coach Brain does not embed gap or intent engine logic', () {
    const forbidden = [
      'CapabilityGapAnalysisService',
      'TrainingIntentFromGapsService',
      'rankTrainingPriorities',
      'YamlKnowledgeOntologyLoader',
    ];
    for (final token in forbidden) {
      expect(coachBrain.contains(token), isFalse, reason: token);
    }
  });

  test('Coach Brain depends only on application ports for engines', () {
    expect(coachBrain.contains('PlanningEngineReader'), isTrue);
    expect(coachBrain.contains('SessionBlueprintGenerator'), isTrue);
    expect(coachBrain.contains('ExercisePolicyEngine'), isTrue);
    expect(coachBrain.contains('PrescriptionEngine'), isTrue);
    expect(coachBrain.contains('PlanningEngineService('), isFalse);
  });

  test('planning engine does not depend on exercise policy or prescription', () {
    final planning = File('$root/lib/planning/planning_engine_service.dart')
        .readAsStringSync();
    expect(planning.contains('exercise_policy'), isFalse);
    expect(planning.contains('prescription'), isFalse);
    expect(planning.contains('CoachBrain'), isFalse);
  });

  test('exercise policy does not depend on prescription engine', () {
    final policy = File(
      '$root/lib/planning/exercise_policy/deterministic_exercise_policy_engine.dart',
    ).readAsStringSync();
    expect(policy.contains('PrescriptionEngine'), isFalse);
    expect(policy.contains('prescription_engine'), isFalse);
  });

  test('session blueprint generator does not call planning engine', () {
    final gen = File(
      '$root/lib/planning/session_blueprint/deterministic_session_blueprint_generator.dart',
    ).readAsStringSync();
    expect(gen.contains('PlanningEngineService'), isFalse);
    expect(gen.contains('PlanningEngineReader'), isFalse);
  });

  test('prescription engine does not call exercise policy', () {
    final rx = File(
      '$root/lib/planning/prescription/deterministic_prescription_engine.dart',
    ).readAsStringSync();
    expect(rx.contains('ExercisePolicyEngine'), isFalse);
    expect(rx.contains('PlanningEngine'), isFalse);
  });

  test('programme adaptation path does not import generative reauthoring', () {
    final files = [
      'lib/application/adaptation/plan_package_session_adaptation_adapter.dart',
      'lib/application/adaptation/programme_adaptation_proposal_service.dart',
      'lib/application/adaptation/programme_adaptation_acceptance_service.dart',
      'lib/features/home/services/programme_adapt_flow.dart',
    ];
    const forbiddenPathTokens = [
      'coach_decision_router',
      'adaptive_progression/',
      'athlete_programme_generation_service',
      'adaptive_progression_coordinator',
    ];
    const forbiddenCalls = [
      'commitDayOfAdaptation(',
      'attachAdaptation(',
      'CoachDecisionRouter(',
      'AdaptiveProgressionCoordinator(',
      'AthleteProgrammeGenerationService(',
    ];
    for (final path in files) {
      final source = File('$root/$path').readAsStringSync();
      final importLines = source
          .split('\n')
          .where((line) => line.trimLeft().startsWith('import '))
          .join('\n');
      for (final token in forbiddenPathTokens) {
        expect(
          importLines.contains(token),
          isFalse,
          reason: '$path must not import $token',
        );
      }
      for (final token in forbiddenCalls) {
        expect(
          source.contains(token),
          isFalse,
          reason: '$path must not call $token',
        );
      }
      // Propose/review paths must not mutate; acceptance service may call
      // withAcceptedAdaptation as the sole prepared-mutation entry.
      if (!path.endsWith('programme_adaptation_acceptance_service.dart')) {
        expect(
          source.contains('withAcceptedAdaptation('),
          isFalse,
          reason: '$path must not call withAcceptedAdaptation(',
        );
      }
      if (path.endsWith('plan_package_session_adaptation_adapter.dart')) {
        expect(source.contains('SessionAdaptationPipeline'), isTrue);
      }
    }
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
