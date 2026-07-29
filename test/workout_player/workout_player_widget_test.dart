import 'package:cohort_platform/features/athlete_profile/models/athlete_profile.dart';
import 'package:cohort_platform/core/theme/colors.dart';
import 'package:cohort_platform/features/home/models/home_today_session_state.dart';
import 'package:cohort_platform/features/home/widgets/home_today_session_section.dart';
import 'package:cohort_platform/features/programme/models/programme_execution_context.dart';
import 'package:cohort_platform/features/programme/models/programme_progress_summary.dart';
import 'package:cohort_platform/features/programme/models/resolved_today_session.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/workout_player/controllers/workout_player_controller.dart';
import 'package:cohort_platform/features/workout_player/models/workout_player_result.dart';
import 'package:cohort_platform/features/workout_player/models/workout_session_brief.dart';
import 'package:cohort_platform/features/workout_player/screens/workout_complete_screen.dart';
import 'package:cohort_platform/features/workout_player/screens/workout_overview_screen.dart';
import 'package:cohort_platform/features/workout_player/screens/workout_player_screen.dart';
import 'package:cohort_platform/features/workout_player/services/coach_brain_workout_plan_service.dart';
import 'package:cohort_platform/features/workout_player/services/workout_plan_from_planning_context.dart';
import 'package:cohort_platform/knowledge/gap_analysis/capability_evidence_models.dart';
import 'package:cohort_platform/knowledge/gap_analysis/capability_gap_analysis_service.dart';
import 'package:cohort_platform/knowledge/io/yaml_knowledge_ontology_loader.dart';
import 'package:cohort_platform/knowledge/read/in_memory_knowledge_graph_reader.dart';
import 'package:cohort_platform/knowledge/training_intent/training_intent_from_gaps_service.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:cohort_platform/models/protocol.dart';
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
import 'dart:io';

SessionExecutionPlan _uiPlan() {
  return SessionExecutionPlan(
    sessionId: 'ui.plan',
    sessionTitle: 'Generated Strength Session',
    durationMin: 40,
    coachNotes: 'Move with intent.',
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
            exerciseId: 'ex.a',
            displayName: 'Goblet Squat',
            prescription: StrengthExercisePrescription(
              sets: 1,
              reps: StrengthRepPrescription.exact(8),
              coachCue: 'Elbows inside knees.',
            ),
          ),
        ],
      ),
    ],
  );
}

CoachBrainWorkoutPlan _preloaded() {
  final now = DateTime.utc(2026, 7, 29);
  final plan = _uiPlan();
  final context = PlanningContext(
    orchestrationId: 'orch.test',
    startedAt: now,
    completedAt: now,
    orchestrationStatus: OrchestrationStatus.complete,
    input: PlanningInput(
      athleteId: 'athlete.test',
      goalContext: const PlanningGoalContext(goalId: 'goal.test'),
      capabilityEvidence: const AthleteCapabilityEvidenceProfile(items: []),
      knowledgeOntologyVersion: '1.3.0',
      asOf: now,
    ),
    sessionExecutionPlan: plan,
  );

  return CoachBrainWorkoutPlan(
    planningContext: context,
    plan: plan,
    brief: const WorkoutSessionBrief(
      sessionName: 'Generated Strength Session',
      objective: 'Build lower-body capacity',
      estimatedDurationMinutes: 40,
      primaryFocus: 'Squat pattern',
      trainingIntent: 'Strength development',
      sessionDifficulty: 'Moderate intensity · Moderate volume',
      sessionNotes: 'Derived from planning explainability.',
      coachNotes: 'Move with intent.',
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('overview loads SessionExecutionPlan fields', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: CohortColors.background,
        ),
        home: WorkoutOverviewScreen(
          athleteId: 'athlete.test',
          preloadedPlan: _preloaded(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Generated Strength Session'), findsOneWidget);
    expect(find.text('Build lower-body capacity'), findsOneWidget);
    expect(find.text('START SESSION'), findsOneWidget);
    expect(find.text('Air Squat'), findsNothing);
  });

  testWidgets('exercise navigation and complete set progress', (tester) async {
    final controller = WorkoutPlayerController(
      plan: _uiPlan(),
      brief: const WorkoutSessionBrief(
        sessionName: 'Generated Strength Session',
        estimatedDurationMinutes: 40,
      ),
    );
    controller.startSession();

    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutPlayerScreen(
          controller: controller,
          athleteId: 'athlete.test',
          completionService: _NoopCompletion(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Goblet Squat'), findsOneWidget);
    expect(find.text('COMPLETE SET'), findsOneWidget);
    await tester.tap(find.text('COMPLETE SET'));
    await tester.pumpAndSettle();

    expect(find.text('Workout Complete'), findsOneWidget);
    expect(find.text('FINISH'), findsOneWidget);
    await tester.tap(find.text('FINISH'));
    await tester.pumpAndSettle();
  });

  testWidgets('home shows execute CTA for programme day', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeTodaySessionSection(
            athleteId: 'lee',
            loadOverride: (_) async {
              return HomeTodaySessionProgrammeExecutable(
                resolution: ResolvedTodaySession(
                  kind: ResolvedTodaySessionKind.executable,
                  assignment: ProgrammeAssignment(
                    id: 'a1',
                    athleteId: 'lee',
                    programmeVersionId: 'v1',
                    lineageCode: 'LINE',
                    status: ProgrammeAssignmentStatus.active,
                    startedAt: DateTime.utc(2026, 7, 15),
                    currentWeek: 1,
                    currentDayKey: 'day_1',
                    currentSessionOrder: 1,
                  ),
                  assignmentId: 'a1',
                  programmeVersionId: 'v1',
                  lineageCode: 'LINE',
                  programmeName: 'Foundation',
                  weekNumber: 1,
                  dayKey: 'day_1',
                  dayIntent: ProgrammeIntent.build,
                  slotTitle: 'Lower',
                  plannedProtocolId: 'P1',
                  effectiveProtocolId: 'P1',
                  isOptional: false,
                  isRestDay: false,
                  programmeComplete: false,
                ),
                protocol: Protocol(
                  protocolId: 'P1',
                  name: 'Lower Strength',
                  durationMin: 40,
                ),
                executionContext: const ProgrammeExecutionContext(
                  assignmentId: 'a1',
                  programmeVersionId: 'v1',
                  weekNumber: 1,
                  dayKey: 'day_1',
                  sessionOrder: 1,
                  sessionSlotId: 'slot-1',
                  plannedProtocolId: 'P1',
                  effectiveProtocolId: 'P1',
                ),
                progressSummary: const ProgrammeProgressSummary(
                  currentWeek: 1,
                  totalWeeks: 8,
                  completedSessions: 0,
                  totalSessions: 12,
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('EXECUTE TODAY\'S TRAINING'), findsOneWidget);
  });

  test(
    'Coach Brain plan service returns non-hardcoded SessionExecutionPlan',
    () async {
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

      final service = CoachBrainWorkoutPlanService(
        coachBrain: brain,
        knowledgeRoot: knowledgeRoot,
      );
      final now = DateTime.utc(2026, 7, 29);
      final profile = AthleteProfile(
        athleteId: 'athlete.mvp',
        displayName: 'Lee',
        primaryGoal: AthleteGoalCatalog.byId('fat_loss'),
        availableEquipment: const [
          'cohort.equipment.barbell',
          'cohort.equipment.dumbbell',
          'cohort.equipment.bodyweight',
        ],
        environmentId: 'cohort.environment.commercial_gym',
        trainingDaysPerWeek: 4,
        preferredSessionDurationMinutes: 45,
        experienceLevel: AthleteExperienceLevel.intermediate,
        assessmentComplete: true,
        createdAt: now,
        updatedAt: now,
      );
      final resolved = await service.resolveFromProfile(profile: profile);
      expect(resolved.plan.sessionId, isNotEmpty);
      expect(resolved.plan.blocks, isNotEmpty);
      expect(
        resolved.plan.sessionTitle.toLowerCase(),
        isNot(contains('air squat')),
      );
      final brief = const WorkoutPlanFromPlanningContext().briefFrom(
        resolved.planningContext,
      );
      expect(brief.sessionName, isNotEmpty);
    },
  );
}

class _NoopCompletion extends WorkoutCompletionService {
  @override
  Future<void> complete({
    required String athleteId,
    required int? trainingSessionId,
    required dynamic programmeContext,
    required WorkoutPlayerResult result,
  }) async {}
}

String _findKnowledgeRoot(Directory start) {
  var dir = start;
  while (true) {
    final manifest = File('${dir.path}/knowledge/manifest.yaml');
    if (manifest.existsSync()) return '${dir.path}/knowledge';
    if (dir.parent.path == dir.path) {
      fail('knowledge root not found');
    }
    dir = dir.parent;
  }
}
