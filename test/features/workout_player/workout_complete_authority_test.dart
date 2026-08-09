import 'package:cohort_platform/features/adaptive_progression/models/session_completion.dart';
import 'package:cohort_platform/features/athlete_profile/models/athlete_profile.dart';
import 'package:cohort_platform/features/athlete_profile/services/athlete_profile_session.dart';
import 'package:cohort_platform/features/plans/data/plan_catalog.dart';
import 'package:cohort_platform/features/plans/models/plan_assignment.dart';
import 'package:cohort_platform/features/programme/models/programme_execution_context.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/workout_player/models/workout_player_result.dart';
import 'package:cohort_platform/features/workout_player/models/workout_player_state.dart';
import 'package:cohort_platform/features/workout_player/models/workout_session_brief.dart';
import 'package:cohort_platform/features/workout_player/screens/workout_complete_screen.dart';
import 'package:cohort_platform/features/workout_player/screens/workout_overview_screen.dart';
import 'package:cohort_platform/features/workout_player/services/coach_brain_workout_plan_service.dart';
import 'package:cohort_platform/knowledge/gap_analysis/capability_evidence_models.dart';
import 'package:cohort_platform/planning/models/planning_goal_context.dart';
import 'package:cohort_platform/planning/models/planning_input.dart';
import 'package:cohort_platform/planning/orchestration/models/planning_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    AthleteProfileSession.clear();
    SessionCompletionStore.clear();
  });

  group('Phase 2.9 WorkoutCompleteScreen AdaptiveProgression retired', () {
    testWidgets(
      'programme-backed completion records shared completion without legacy mutation',
      (tester) async {
        _bindLegacyActivePlan();
        final assignmentBefore = AthleteProfileSession.activeAssignment!;
        final completion = _RecordingCompletionService();

        await tester.pumpWidget(
          MaterialApp(
            home: WorkoutCompleteScreen(
              state: _completeState(),
              athleteId: 'athlete.local',
              trainingSessionId: 42,
              programmeContext: _programmeContext(),
              completionService: completion,
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.text('FINISH'));
        await tester.pumpAndSettle();

        expect(completion.calls, 1);
        expect(completion.lastProgrammeBacked, isTrue);
        expect(SessionCompletionStore.all, isNotEmpty);
        expect(
          AthleteProfileSession.activeAssignment?.assignmentId,
          assignmentBefore.assignmentId,
        );
        expect(
          AthleteProfileSession.activeAssignment?.currentDay,
          assignmentBefore.currentDay,
        );
        expect(AthleteProfileSession.hasActivePlan, isTrue);
        expect(find.text('Preparing your next programmed session…'), findsNothing);
      },
    );

    testWidgets(
      'no-programme-context completion never mutates PlanAssignment',
      (tester) async {
        _bindLegacyActivePlan();
        final assignmentBefore = AthleteProfileSession.activeAssignment!;
        final completion = _RecordingCompletionService();

        await tester.pumpWidget(
          MaterialApp(
            home: WorkoutCompleteScreen(
              state: _completeState(),
              athleteId: 'athlete.local',
              completionService: completion,
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.text('FINISH'));
        await tester.pumpAndSettle();

        expect(completion.calls, 1);
        expect(completion.lastProgrammeBacked, isFalse);
        expect(SessionCompletionStore.all, isNotEmpty);
        expect(
          AthleteProfileSession.activeAssignment?.assignmentId,
          assignmentBefore.assignmentId,
        );
        expect(
          AthleteProfileSession.activeAssignment?.currentDay,
          assignmentBefore.currentDay,
        );
        expect(AthleteProfileSession.hasActivePlan, isTrue);
        expect(find.text('Preparing your next programmed session…'), findsNothing);
      },
    );

  });
}

ProgrammeExecutionContext _programmeContext() {
  return const ProgrammeExecutionContext(
    assignmentId: 'assignment.programme',
    programmeVersionId: 'version-1',
    sessionSlotId: 'slot-1',
    weekNumber: 1,
    dayKey: 'day_1',
    sessionOrder: 1,
    plannedProtocolId: 'BW-001',
    effectiveProtocolId: 'BW-001',
    lineageCode: 'PROG-S14B',
  );
}

WorkoutPlayerState _completeState() {
  final now = DateTime.utc(2026, 7, 29, 10);
  return WorkoutPlayerState(
    plan: SessionExecutionPlan(
      sessionId: 'session.test',
      sessionTitle: 'Test Session',
      durationMin: 40,
      blocks: const [],
    ),
    brief: const WorkoutSessionBrief(
      sessionName: 'Test Session',
      estimatedDurationMinutes: 40,
    ),
    steps: const [],
    phase: WorkoutPlayerPhase.complete,
    currentExerciseIndex: 0,
    currentSet: 1,
    completedExerciseIndexes: const {},
    startedAt: now.subtract(const Duration(minutes: 30)),
    completedAt: now,
  );
}

void _bindLegacyActivePlan() {
  final now = DateTime.utc(2026, 7, 29);
  final plan = PlanCatalog.byId('plan.fat_loss_foundation')!;
  final assignment = PlanAssignment(
    assignmentId: 'assignment.legacy',
    athleteId: 'athlete.local',
    planId: plan.planId,
    assignedAt: now,
    startedAt: now,
    currentPhase: 'Foundation',
    currentWeek: 1,
    currentDay: 1,
  );
  final execution = SessionExecutionPlan(
    sessionId: 'session.legacy',
    sessionTitle: 'Legacy Session',
    durationMin: 40,
    blocks: const [],
  );
  AthleteProfileSession.bind(
    profile: AthleteProfile(
      athleteId: 'athlete.local',
      displayName: 'Casey',
      primaryGoal: plan.primaryGoal,
      availableEquipment: const ['cohort.equipment.bodyweight'],
      environmentId: 'cohort.environment.home',
      trainingDaysPerWeek: 3,
      preferredSessionDurationMinutes: 45,
      experienceLevel: AthleteExperienceLevel.beginner,
      assessmentComplete: true,
      createdAt: now,
      updatedAt: now,
    ),
    programme: AthleteGeneratedProgramme(
      planBundle: CoachBrainWorkoutPlan(
        planningContext: PlanningContext(
          orchestrationId: 'orch.legacy',
          startedAt: now,
          completedAt: now,
          orchestrationStatus: OrchestrationStatus.complete,
          input: PlanningInput(
            athleteId: 'athlete.local',
            goalContext: const PlanningGoalContext(
              goalId: 'cohort.goal.general_fat_loss',
            ),
            capabilityEvidence:
                const AthleteCapabilityEvidenceProfile(items: []),
            knowledgeOntologyVersion: '1.3.0',
            asOf: now,
          ),
        ),
        plan: execution,
        brief: const WorkoutSessionBrief(
          sessionName: 'Legacy Session',
          estimatedDurationMinutes: 40,
        ),
      ),
      programmeName: plan.name,
      phaseLabel: 'Foundation',
    ),
    activePlan: plan,
    assignment: assignment,
  );
}

class _RecordingCompletionService extends WorkoutCompletionService {
  int calls = 0;
  bool lastProgrammeBacked = false;

  @override
  Future<void> complete({
    required String athleteId,
    required int? trainingSessionId,
    required ProgrammeExecutionContext? programmeContext,
    required WorkoutPlayerResult result,
  }) async {
    calls += 1;
    lastProgrammeBacked = programmeContext?.isProgrammeBacked ?? false;
  }
}
