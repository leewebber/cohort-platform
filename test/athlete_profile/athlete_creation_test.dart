import 'dart:io';

import 'package:cohort_platform/features/athlete_profile/models/athlete_profile.dart';
import 'package:cohort_platform/features/athlete_profile/onboarding/athlete_onboarding_draft.dart';
import 'package:cohort_platform/features/athlete_profile/onboarding/athlete_onboarding_flow.dart';
import 'package:cohort_platform/features/athlete_profile/services/athlete_planning_input_builder.dart';
import 'package:cohort_platform/features/athlete_profile/services/athlete_profile_session.dart';
import 'package:cohort_platform/features/athlete_profile/services/athlete_programme_generation_service.dart';
import 'package:cohort_platform/features/athlete_profile/widgets/athlete_generated_today_section.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/workout_player/models/workout_session_brief.dart';
import 'package:cohort_platform/features/workout_player/services/coach_brain_workout_plan_service.dart';
import 'package:cohort_platform/knowledge/gap_analysis/capability_evidence_models.dart';
import 'package:cohort_platform/knowledge/gap_analysis/capability_gap_analysis_service.dart';
import 'package:cohort_platform/knowledge/io/yaml_knowledge_ontology_loader.dart';
import 'package:cohort_platform/knowledge/read/in_memory_knowledge_graph_reader.dart';
import 'package:cohort_platform/knowledge/training_intent/training_intent_from_gaps_service.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/strength_exercise_prescription.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:cohort_platform/planning/exercise_policy/deterministic_exercise_policy_engine.dart';
import 'package:cohort_platform/planning/models/planning_goal_context.dart';
import 'package:cohort_platform/planning/models/planning_input.dart';
import 'package:cohort_platform/planning/orchestration/coach_brain_service.dart';
import 'package:cohort_platform/planning/orchestration/models/planning_context.dart';
import 'package:cohort_platform/planning/planning_engine_service.dart';
import 'package:cohort_platform/planning/prescription/deterministic_prescription_engine.dart';
import 'package:cohort_platform/planning/session_blueprint/deterministic_session_blueprint_generator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(AthleteProfileSession.clear);

  group('AthleteProfile + PlanningInput', () {
    test('draft builds profile and PlanningInput without scenarios', () {
      final draft = AthleteOnboardingDraft(
        displayName: 'Alex',
        primaryGoal: AthleteGoalCatalog.byId('hyrox'),
        selectedEquipmentPresetIds: const {'commercial_gym'},
        trainingDaysPerWeek: 4,
        preferredSessionDurationMinutes: 60,
        experienceLevel: AthleteExperienceLevel.intermediate,
        currentActivity: 'Recreational running',
      );

      final profile = draft.toProfile(athleteId: 'athlete.alex');
      expect(profile.displayName, 'Alex');
      expect(profile.planningGoalId, 'cohort.goal.hyrox_sub_60');
      expect(profile.availableEquipment, contains('cohort.equipment.barbell'));
      expect(profile.environmentId, 'cohort.environment.commercial_gym');
      expect(profile.assessmentComplete, isTrue);

      final input = const AthletePlanningInputBuilder().build(
        profile: profile,
        knowledgeOntologyVersion: '1.3.0',
      );
      expect(input.athleteId, 'athlete.alex');
      expect(input.goalContext.goalId, 'cohort.goal.hyrox_sub_60');
      expect(input.capabilityEvidence.items, isNotEmpty);
      expect(
        input.capabilityEvidence.items.any(
          (e) => e.source == 'athlete_onboarding_self_report',
        ),
        isTrue,
      );
      expect(input.equipmentContext?.availableEquipmentIds, isNotEmpty);
      expect(input.asOf, isNotNull);
    });

    test('general fitness maps to ontology goal with preference tag', () {
      final goal = AthleteGoalCatalog.byId('general_fitness');
      expect(goal.ontologyGoalId, 'cohort.goal.general_fat_loss');
      expect(goal.preferenceTag, 'general_fitness');
    });

    test('no reference scenario ids in planning input', () {
      final profile = AthleteOnboardingDraft(
        displayName: 'Alex',
        primaryGoal: AthleteGoalCatalog.byId('fat_loss'),
        selectedEquipmentPresetIds: const {'home_gym'},
        experienceLevel: AthleteExperienceLevel.beginner,
      ).toProfile(athleteId: 'athlete.x');

      final input = const AthletePlanningInputBuilder().build(
        profile: profile,
        knowledgeOntologyVersion: '1.3.0',
      );
      expect(input.goalContext.goalId, isNot(contains('scenario')));
      for (final item in input.capabilityEvidence.items) {
        expect(item.source, isNot(contains('scenario')));
      }
    });
  });

  group('Coach Brain from AthleteProfile', () {
    test('generates SessionExecutionPlan without reference scenario', () async {
      final knowledgeRoot = _findKnowledgeRoot(Directory.current);
      final bundle = await const YamlKnowledgeOntologyLoader()
          .loadFromDirectory(knowledgeRoot);
      final knowledge = InMemoryKnowledgeGraphReader(bundle);
      final brain = CoachBrainService(
        planningEngine: PlanningEngineService(
          knowledge: knowledge,
          gapAnalysis: CapabilityGapAnalysisService(knowledge),
          intentResolution: TrainingIntentFromGapsService(knowledge),
        ),
        blueprintGenerator: DeterministicSessionBlueprintGenerator(
          knowledge: knowledge,
        ),
        exercisePolicy: DeterministicExercisePolicyEngine(knowledge: knowledge),
        prescriptionEngine: DeterministicPrescriptionEngine(
          knowledge: knowledge,
        ),
      );
      final planService = CoachBrainWorkoutPlanService(
        coachBrain: brain,
        knowledgeRoot: knowledgeRoot,
      );
      final generation = AthleteProgrammeGenerationService(
        planService: planService,
      );

      final now = DateTime.utc(2026, 7, 29);
      final profile = AthleteProfile(
        athleteId: 'athlete.onboard',
        displayName: 'Jordan',
        primaryGoal: AthleteGoalCatalog.byId('military'),
        availableEquipment: AthleteEquipmentCatalog.byId(
          'commercial_gym',
        ).equipmentIds,
        environmentId: 'cohort.environment.commercial_gym',
        trainingDaysPerWeek: 5,
        preferredSessionDurationMinutes: 45,
        experienceLevel: AthleteExperienceLevel.beginner,
        assessmentComplete: true,
        createdAt: now,
        updatedAt: now,
      );

      final programme = await generation.generate(profile);
      expect(AthleteProfileSession.hasCompletedOnboarding, isTrue);
      expect(programme.planBundle.plan.blocks, isNotEmpty);
      expect(
        programme.planBundle.planningContext.input.goalContext.goalId,
        'cohort.goal.military_selection',
      );
      expect(
        programme.planBundle.planningContext.input.athleteId,
        'athlete.onboard',
      );
    });
  });

  group('Onboarding UI', () {
    testWidgets('welcome screen collects name', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(
        const MaterialApp(home: AthleteOnboardingFlow()),
      );
      await tester.pump();

      expect(find.text('Welcome to Cohort'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('onboarding_display_name')),
        'Sam',
      );
      await tester.pump();
      expect(find.text('CONTINUE'), findsOneWidget);
      await tester.tap(find.text('CONTINUE'));
      await tester.pump();
      expect(find.text('What are you training for?'), findsOneWidget);
      expect(find.text('HYROX'), findsOneWidget);
      expect(find.text('Fat Loss'), findsOneWidget);
    });

    testWidgets('generated today section shows athlete programme', (
      tester,
    ) async {
      final now = DateTime.utc(2026, 7, 29);
      final plan = SessionExecutionPlan(
        sessionId: 'home.plan',
        sessionTitle: 'Personal Strength Session',
        durationMin: 45,
        blocks: [
          SessionExecutionBlock(
            blockId: 'b1',
            title: 'Primary',
            blockType: SessionBlockType.strength,
            content: '',
            workoutFormat: WorkoutFormat.none,
            position: 1,
            linkedExercises: [
              SessionExecutionExerciseSummary(
                exerciseId: 'ex.1',
                displayName: 'Goblet Squat',
                prescription: StrengthExercisePrescription(
                  sets: 3,
                  reps: StrengthRepPrescription.exact(8),
                ),
              ),
            ],
          ),
        ],
      );
      final context = PlanningContext(
        orchestrationId: 'orch.home',
        startedAt: now,
        completedAt: now,
        orchestrationStatus: OrchestrationStatus.complete,
        input: PlanningInput(
          athleteId: 'athlete.home',
          goalContext: const PlanningGoalContext(
            goalId: 'cohort.goal.general_fat_loss',
          ),
          capabilityEvidence: const AthleteCapabilityEvidenceProfile(items: []),
          knowledgeOntologyVersion: '1.3.0',
          asOf: now,
        ),
        sessionExecutionPlan: plan,
      );

      AthleteProfileSession.bind(
        profile: AthleteProfile(
          athleteId: 'athlete.home',
          displayName: 'Casey',
          primaryGoal: AthleteGoalCatalog.byId('fat_loss'),
          availableEquipment: const ['cohort.equipment.bodyweight'],
          environmentId: 'cohort.environment.home',
          trainingDaysPerWeek: 3,
          preferredSessionDurationMinutes: 45,
          experienceLevel: AthleteExperienceLevel.intermediate,
          assessmentComplete: true,
          createdAt: now,
          updatedAt: now,
        ),
        programme: AthleteGeneratedProgramme(
          planBundle: CoachBrainWorkoutPlan(
            planningContext: context,
            plan: plan,
            brief: const WorkoutSessionBrief(
              sessionName: 'Personal Strength Session',
              estimatedDurationMinutes: 45,
              trainingIntent: 'Strength',
            ),
          ),
          programmeName: 'Fat Loss Programme',
          phaseLabel: 'General Preparation',
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AthleteGeneratedTodaySection()),
        ),
      );
      await tester.pump();

      expect(find.byType(AthleteGeneratedTodaySection), findsOneWidget);
      expect(find.textContaining('Casey'), findsWidgets);
      expect(find.text('EXECUTE TODAY\'S TRAINING'), findsOneWidget);
      expect(find.textContaining('FAT LOSS PROGRAMME'), findsOneWidget);
      expect(find.textContaining('PERSONAL STRENGTH SESSION'), findsOneWidget);
    });
  });
}

String _findKnowledgeRoot(Directory start) {
  var dir = start;
  while (true) {
    final manifest = File('${dir.path}/knowledge/manifest.yaml');
    if (manifest.existsSync()) return '${dir.path}/knowledge';
    if (dir.parent.path == dir.path) fail('knowledge root not found');
    dir = dir.parent;
  }
}
