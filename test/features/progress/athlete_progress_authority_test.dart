import 'package:cohort_platform/data/repositories/programme_assignment_store.dart';
import 'package:cohort_platform/features/adaptive_progression/models/session_completion.dart';
import 'package:cohort_platform/features/athlete_profile/models/athlete_profile.dart';
import 'package:cohort_platform/features/athlete_profile/services/athlete_profile_session.dart';
import 'package:cohort_platform/features/plans/data/plan_catalog.dart';
import 'package:cohort_platform/features/plans/models/plan_assignment.dart';
import 'package:cohort_platform/features/progress/screens/progress_screen.dart';
import 'package:cohort_platform/features/progress/services/athlete_progress_summary_builder.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/workout_player/models/workout_session_brief.dart';
import 'package:cohort_platform/features/workout_player/services/coach_brain_workout_plan_service.dart';
import 'package:cohort_platform/knowledge/gap_analysis/capability_evidence_models.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:cohort_platform/models/programme_slot_outcome.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:cohort_platform/planning/models/planning_goal_context.dart';
import 'package:cohort_platform/planning/models/planning_input.dart';
import 'package:cohort_platform/planning/orchestration/models/planning_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_programme_stores.dart';
import '../../support/programme_schedule_test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    AthleteProfileSession.clear();
    SessionCompletionStore.clear();
  });

  group('AthleteProgressSummaryBuilder', () {
    test('programme-only uses canonical session counts, not Plan Library', () async {
      final tables = await _seedProgrammeTables(completedSessions: 1);
      _bindLegacyActivePlan(
        planName: 'Fat Loss Foundation',
        sessionsInStore: 9,
      );

      final builder = AthleteProgressSummaryBuilder(
        assignmentStore: InMemoryProgrammeAssignmentStore(tables),
        versionStore: InMemoryProgrammeVersionStore(tables),
        slotOutcomeStore: InMemoryProgrammeSlotOutcomeStore(tables),
      );

      // Clear legacy so this is programme-only for authority, but leave
      // SessionCompletionStore polluted to prove it is ignored.
      AthleteProfileSession.clear();

      final summary = await builder.build(athleteId: 'lee');

      expect(summary.hasActivePlan, isTrue);
      expect(summary.planName, 'PROG-TEST');
      expect(summary.sessionsCompleted, 1);
      expect(summary.compliance.planned, 4);
      expect(summary.recentImprovements, isEmpty);
      expect(summary.timeline, isEmpty);
      expect(summary.upcoming, isNull);
      expect(summary.history, isEmpty);
    });

    test('both-present ignores legacy Plan Library evidence', () async {
      final tables = await _seedProgrammeTables(completedSessions: 2);
      _bindLegacyActivePlan(sessionsInStore: 5);

      final builder = AthleteProgressSummaryBuilder(
        assignmentStore: InMemoryProgrammeAssignmentStore(tables),
        versionStore: InMemoryProgrammeVersionStore(tables),
        slotOutcomeStore: InMemoryProgrammeSlotOutcomeStore(tables),
      );

      final summary = await builder.build(athleteId: 'lee');

      expect(summary.sessionsCompleted, 2);
      expect(summary.planName, isNot('Fat Loss Foundation'));
      expect(summary.compliance.completed, 2);
      expect(summary.upcoming, isNull);
    });

    test('stale hasActivePlan alone does not contaminate programme progress',
        () async {
      final tables = await _seedProgrammeTables(completedSessions: 1);
      _bindLegacyActivePlan(sessionsInStore: 3);

      final builder = AthleteProgressSummaryBuilder(
        assignmentStore: InMemoryProgrammeAssignmentStore(tables),
        versionStore: InMemoryProgrammeVersionStore(tables),
        slotOutcomeStore: InMemoryProgrammeSlotOutcomeStore(tables),
      );

      final summary = await builder.build(athleteId: 'lee');

      expect(summary.sessionsCompleted, 1);
      expect(AthleteProfileSession.hasActivePlan, isTrue);
    });

    test('programme evidence unavailable does not fall back to legacy',
        () async {
      _bindLegacyActivePlan(sessionsInStore: 4);

      final builder = AthleteProgressSummaryBuilder(
        assignmentStore: const _ThrowingAssignmentStore(),
      );

      final summary = await builder.build(athleteId: 'lee');

      expect(summary.hasActivePlan, isFalse);
      expect(summary.sessionsCompleted, 0);
      expect(summary.planName, isNull);
    });

    test('pure legacy Progress resolves to empty/neutral (Phase 2.8)', () async {
      final tables = InMemoryProgrammeTables();
      _bindLegacyActivePlan(sessionsInStore: 2);

      final builder = AthleteProgressSummaryBuilder(
        assignmentStore: InMemoryProgrammeAssignmentStore(tables),
        versionStore: InMemoryProgrammeVersionStore(tables),
        slotOutcomeStore: InMemoryProgrammeSlotOutcomeStore(tables),
      );

      final summary = await builder.build(athleteId: 'athlete.local');

      expect(summary.hasActivePlan, isFalse);
      expect(summary.sessionsCompleted, 0);
      expect(summary.planName, isNull);
      expect(AthleteProfileSession.hasActivePlan, isTrue);
    });

    test('opening builder does not mutate legacy assignment', () async {
      final tables = await _seedProgrammeTables(completedSessions: 1);
      _bindLegacyActivePlan();
      final before = AthleteProfileSession.activeAssignment!;

      final builder = AthleteProgressSummaryBuilder(
        assignmentStore: InMemoryProgrammeAssignmentStore(tables),
        versionStore: InMemoryProgrammeVersionStore(tables),
        slotOutcomeStore: InMemoryProgrammeSlotOutcomeStore(tables),
      );
      await builder.build(athleteId: 'lee');

      expect(
        AthleteProfileSession.activeAssignment?.assignmentId,
        before.assignmentId,
      );
      expect(
        AthleteProfileSession.activeAssignment?.currentDay,
        before.currentDay,
      );
      expect(AthleteProfileSession.hasActivePlan, isTrue);
    });
  });

  group('ProgressScreen programme authority UI', () {
    testWidgets('programme summary shows lineage and session counts', (
      tester,
    ) async {
      final tables = await _seedProgrammeTables(completedSessions: 1);
      final builder = AthleteProgressSummaryBuilder(
        assignmentStore: InMemoryProgrammeAssignmentStore(tables),
        versionStore: InMemoryProgrammeVersionStore(tables),
        slotOutcomeStore: InMemoryProgrammeSlotOutcomeStore(tables),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProgressScreen(
            athleteIdOverride: 'lee',
            progressBuilder: builder,
            embeddedInShell: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PROG-TEST'), findsWidgets);
      expect(find.textContaining('1 sessions completed'), findsOneWidget);
      expect(find.text('Fat Loss Foundation'), findsNothing);
    });
  });
}

Future<InMemoryProgrammeTables> _seedProgrammeTables({
  required int completedSessions,
}) async {
  final tables = InMemoryProgrammeTables();
  final versionStore = InMemoryProgrammeVersionStore(tables);
  await versionStore.saveTemplateTree(
    version: ProgrammeScheduleTestFixtures.version(),
    tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(),
  );

  final assignment = ProgrammeScheduleTestFixtures.materialisedAssignment(
    athleteId: 'lee',
  ).copyWith(lineageCode: 'PROG-TEST');
  tables.assignments.add(assignment);

  final slotIds = [
    ProgrammeScheduleTestFixtures.slot1Id,
    ProgrammeScheduleTestFixtures.slot2Id,
    ProgrammeScheduleTestFixtures.slot4Id,
    ProgrammeScheduleTestFixtures.slot5Id,
  ];
  for (var i = 0; i < completedSessions && i < slotIds.length; i++) {
    tables.outcomes.add(
      ProgrammeSlotOutcome(
        id: 'outcome-$i',
        assignmentId: assignment.id,
        sessionSlotId: slotIds[i],
        weekNumber: 1,
        dayKey: 'day_${i + 1}',
        sessionOrder: 1,
        outcomeStatus: ProgrammeSlotOutcomeStatus.completed,
      ),
    );
  }
  return tables;
}

void _bindLegacyActivePlan({
  String planName = 'Fat Loss Foundation',
  int sessionsInStore = 0,
}) {
  final now = DateTime.utc(2026, 7, 29);
  final plan = PlanCatalog.byId('plan.fat_loss_foundation')!;
  expect(plan.name, planName);
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

  for (var i = 0; i < sessionsInStore; i++) {
    SessionCompletionStore.add(
      SessionCompletion(
        completionId: 'legacy-$i',
        athleteId: 'athlete.local',
        completedAt: now.add(Duration(days: i)),
        exercisesCompleted: 3,
        totalExercises: 3,
        planName: plan.name,
        sessionName: 'Legacy $i',
      ),
    );
  }
}

class _ThrowingAssignmentStore implements ProgrammeAssignmentStore {
  const _ThrowingAssignmentStore();

  @override
  Future<ProgrammeAssignment?> getActiveAssignment(String athleteId) async {
    throw StateError('programme evidence unavailable');
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
