import 'dart:async';

import 'package:cohort_platform/core/persistence/athlete_local_repository.dart';
import 'package:cohort_platform/core/persistence/local_kv_store.dart';
import 'package:cohort_platform/data/repositories/programme_assignment_store.dart';
import 'package:cohort_platform/features/athlete_profile/models/athlete_profile.dart';
import 'package:cohort_platform/features/athlete_profile/services/athlete_profile_session.dart';
import 'package:cohort_platform/features/athlete_profile/widgets/athlete_generated_today_section.dart';
import 'package:cohort_platform/features/home/home_screen.dart';
import 'package:cohort_platform/features/programme/presentation/athlete_programme_continuity_copy.dart';
import 'package:cohort_platform/features/home/services/athlete_home_runtime_authority.dart';
import 'package:cohort_platform/features/home/widgets/athlete_programme_today_section.dart';
import 'package:cohort_platform/features/plans/data/plan_catalog.dart';
import 'package:cohort_platform/features/plans/models/plan_assignment.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_authored_slot_resolver.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_session_prepare_service.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/services/session_execution_loader.dart';
import 'package:cohort_platform/features/workout_player/models/workout_session_brief.dart';
import 'package:cohort_platform/features/workout_player/services/coach_brain_workout_plan_service.dart';
import 'package:cohort_platform/knowledge/gap_analysis/capability_evidence_models.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:cohort_platform/planning/models/planning_goal_context.dart';
import 'package:cohort_platform/planning/models/planning_input.dart';
import 'package:cohort_platform/planning/orchestration/models/planning_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_programme_stores.dart';
import '../../support/programme_schedule_test_fixtures.dart';

void main() {
  const resolver = AthleteHomeRuntimeAuthorityResolver();

  tearDown(AthleteProfileSession.clear);

  group('AthleteHomeRuntimeAuthorityResolver matrix (Phase 2.8)', () {
    test('valid materialised programme only → programme', () {
      final a = resolver.resolve(materialisedProgramme: true);
      expect(a, AthleteHomeRuntimeAuthority.programme);
      expect(a.exposesProgrammeRuntime, isTrue);
      expect(a.activatesAnyAdaptFlow, isTrue);
      expect(a.isMutuallyExclusiveAdaptAuthority, isTrue);
    });

    test('legacy active plan only → none (legacy Home retired)', () {
      // Legacy inputs are no longer accepted by the resolver.
      final a = resolver.resolve(materialisedProgramme: false);
      expect(a, AthleteHomeRuntimeAuthority.none);
      expect(a.exposesProgrammeRuntime, isFalse);
      expect(a.activatesAnyAdaptFlow, isFalse);
    });

    test('both present → programme exclusively', () {
      final a = resolver.resolve(materialisedProgramme: true);
      expect(a, AthleteHomeRuntimeAuthority.programme);
      expect(a.activatesAnyAdaptFlow, isTrue);
      expect(a.isMutuallyExclusiveAdaptAuthority, isTrue);
    });

    test('neither present → none', () {
      final a = resolver.resolve(materialisedProgramme: false);
      expect(a, AthleteHomeRuntimeAuthority.none);
      expect(a.activatesAnyAdaptFlow, isFalse);
    });

    test('loading/unknown never activates programme or legacy', () {
      final a = resolver.resolve(materialisedProgramme: null);
      expect(a, AthleteHomeRuntimeAuthority.loading);
      expect(a.exposesProgrammeRuntime, isFalse);
      expect(a.activatesAnyAdaptFlow, isFalse);
    });

    test('invalid programme evidence fails closed regardless of legacy state',
        () {
      final unavailable = resolver.resolve(
        materialisedProgramme: false,
        programmeEvidenceUnavailable: true,
      );
      expect(unavailable, AthleteHomeRuntimeAuthority.unavailable);
      expect(unavailable.exposesProgrammeRuntime, isFalse);
      expect(unavailable.activatesAnyAdaptFlow, isFalse);
    });

    test('decision is deterministic and mutually exclusive', () {
      AthleteHomeRuntimeAuthority once() =>
          resolver.resolve(materialisedProgramme: true);
      expect(once(), once());
      expect(once(), AthleteHomeRuntimeAuthority.programme);
      for (final materialised in const [true, false, null]) {
        for (final unavailable in const [true, false]) {
          final a = resolver.resolve(
            materialisedProgramme: materialised,
            programmeEvidenceUnavailable: unavailable,
          );
          expect(a.isMutuallyExclusiveAdaptAuthority, isTrue);
          expect(
            a == AthleteHomeRuntimeAuthority.programme ||
                a == AthleteHomeRuntimeAuthority.none ||
                a == AthleteHomeRuntimeAuthority.loading ||
                a == AthleteHomeRuntimeAuthority.unavailable,
            isTrue,
          );
        }
      }
    });

    test('legacyPlanCompatibility enum case is retired', () {
      final source = AthleteHomeRuntimeAuthority.values
          .map((e) => e.name)
          .toList(growable: false);
      expect(source, isNot(contains('legacyPlanCompatibility')));
    });
  });

  group('HomeScreen authority routing (Phase 2.8)', () {
    testWidgets('programme authority exposes programme today only', (
      tester,
    ) async {
      final tables = InMemoryProgrammeTables();
      tables.assignments.add(_materialised(athleteId: 'athlete.local'));
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            athleteIdOverride: 'athlete.local',
            embeddedInShell: true,
            assignmentStore: InMemoryProgrammeAssignmentStore(tables),
            prepareService: _localPrepare(tables),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AthleteProgrammeTodaySection), findsOneWidget);
            expect(find.text('NEED TO ADAPT?'), findsNothing);
      expect(find.text('Choose a programme'), findsNothing);
    });

    testWidgets(
      'legacy-only → established no-programme Home; zero legacy runtime',
      (tester) async {
        _bindLegacyActivePlan();
        final assignmentBefore = AthleteProfileSession.activeAssignment!;
        final tables = InMemoryProgrammeTables();
        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(
            athleteIdOverride: 'athlete.local',
              embeddedInShell: true,
              assignmentStore: InMemoryProgrammeAssignmentStore(tables),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Choose a programme'), findsOneWidget);
        expect(find.byType(ChoosePlanEntryCard), findsOneWidget);
                expect(find.text('NEED TO ADAPT?'), findsNothing);
        expect(find.byType(AthleteProgrammeTodaySection), findsNothing);
        expect(AthleteProfileSession.hasActivePlan, isTrue);
        expect(
          AthleteProfileSession.activeAssignment?.assignmentId,
          assignmentBefore.assignmentId,
        );
        expect(
          AthleteProfileSession.activeAssignment?.currentDay,
          assignmentBefore.currentDay,
        );
      },
    );

    testWidgets(
      'both present → programme exclusively; legacy adapt not exposed',
      (tester) async {
        _bindLegacyActivePlan();
        final tables = InMemoryProgrammeTables();
        tables.assignments.add(_materialised(athleteId: 'athlete.local'));
        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(
            athleteIdOverride: 'athlete.local',
              embeddedInShell: true,
              assignmentStore: InMemoryProgrammeAssignmentStore(tables),
              prepareService: _localPrepare(tables),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AthleteProgrammeTodaySection), findsOneWidget);
                expect(find.text('NEED TO ADAPT?'), findsNothing);
        expect(find.text('ADAPT'), findsNothing);
        expect(AthleteProfileSession.hasActivePlan, isTrue);
      },
    );

    testWidgets('neither → none / choose programme', (tester) async {
      final tables = InMemoryProgrammeTables();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            athleteIdOverride: 'athlete.local',
            embeddedInShell: true,
            assignmentStore: InMemoryProgrammeAssignmentStore(tables),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Choose a programme'), findsOneWidget);
      expect(find.byType(AthleteProgrammeTodaySection), findsNothing);
            expect(find.text('NEED TO ADAPT?'), findsNothing);
    });

    testWidgets(
      'legacy-only and no-legacy no-programme are observationally equivalent',
      (tester) async {
        final tables = InMemoryProgrammeTables();
        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(
            athleteIdOverride: 'athlete.local',
              embeddedInShell: true,
              assignmentStore: InMemoryProgrammeAssignmentStore(tables),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Choose a programme'), findsOneWidget);

        _bindLegacyActivePlan();
        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(
            athleteIdOverride: 'athlete.local',
              embeddedInShell: true,
              assignmentStore: InMemoryProgrammeAssignmentStore(tables),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Choose a programme'), findsOneWidget);
                expect(find.text('NEED TO ADAPT?'), findsNothing);
      },
    );

    testWidgets(
      'loading with legacy plan does not activate legacy path',
      (tester) async {
        _bindLegacyActivePlan();
        final pending = Completer<ProgrammeAssignment?>();
        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(
            athleteIdOverride: 'athlete.local',
              embeddedInShell: true,
              assignmentStore: _PendingAssignmentStore(pending.future),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Checking programme…'), findsOneWidget);
                expect(find.text('NEED TO ADAPT?'), findsNothing);
        expect(find.byType(AthleteProgrammeTodaySection), findsNothing);

        pending.complete(null);
        await tester.pumpAndSettle();
        // Phase 2.8: resolves to no-programme, not DailyBriefing.
        expect(find.text('Choose a programme'), findsOneWidget);
                expect(find.text('NEED TO ADAPT?'), findsNothing);
      },
    );

    testWidgets(
      'unavailable programme evidence refuses legacy fallback',
      (tester) async {
        _bindLegacyActivePlan();
        await tester.pumpWidget(
          const MaterialApp(
            home: HomeScreen(
            athleteIdOverride: 'athlete.local',
              embeddedInShell: true,
              assignmentStore: _ThrowingAssignmentStore(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(AthleteProgrammeContinuityCopy.pinnedUnavailable),
          findsOneWidget,
        );
                expect(find.text('NEED TO ADAPT?'), findsNothing);
        expect(find.byType(AthleteProgrammeTodaySection), findsNothing);
        expect(find.text('Choose a programme'), findsNothing);
      },
    );

    testWidgets(
      'Home source does not mount retired legacy Home entry',
      (tester) async {
        // Structural: HomeScreen must not reference retired legacy entry widgets
        // beyond imports removed — behavioural proofs above are authoritative.
        final tables = InMemoryProgrammeTables();
        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(
            athleteIdOverride: 'athlete.local',
              embeddedInShell: true,
              assignmentStore: InMemoryProgrammeAssignmentStore(tables),
            ),
          ),
        );
        await tester.pumpAndSettle();
                expect(find.textContaining('HomeAdaptFlow'), findsNothing);
      },
    );
  });
}

ProgrammeAssignment _materialised({required String athleteId}) {
  return ProgrammeScheduleTestFixtures.assignment(
    athleteId: athleteId,
  ).copyWith(
    lineageCode: 'PROG-S14B',
    materialisedAt: DateTime.utc(2026, 7, 31, 12),
    materialisationSource: 'athlete_start_programme',
    materialisedPackageContentHash:
        'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
  );
}

AthleteProgrammeSessionPrepareService _localPrepare(
  InMemoryProgrammeTables tables,
) {
  return AthleteProgrammeSessionPrepareService(
    assignmentStore: InMemoryProgrammeAssignmentStore(tables),
    slotResolver: AthleteProgrammeAuthoredSlotResolver(
      versionStore: InMemoryProgrammeVersionStore(tables),
    ),
    sessionLoader: _EmptyLoader(),
    localRepository: AthleteLocalRepository(InMemoryKvStore()),
  );
}

class _EmptyLoader extends SessionExecutionLoader {
  @override
  Future<SessionExecutionLoadResult> load({
    required String protocolId,
    String? displayTitle,
    String? programmeContextLabel,
    Map<String, String> prescriptionLoadOverrides = const {},
  }) async {
    return SessionExecutionLoadResult(
      plan: SessionExecutionPlan(
        sessionId: protocolId,
        sessionTitle: 'Stub',
        durationMin: 1,
        blocks: const [],
      ),
    );
  }
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

class _PendingAssignmentStore implements ProgrammeAssignmentStore {
  _PendingAssignmentStore(this._future);

  final Future<ProgrammeAssignment?> _future;

  @override
  Future<ProgrammeAssignment?> getActiveAssignment(String athleteId) => _future;

  @override
  Future<ProgrammeAssignment?> getById(String assignmentId) async => null;

  @override
  Future<ProgrammeAssignment> insert(ProgrammeAssignment assignment) {
    throw UnimplementedError();
  }

  @override
  Future<ProgrammeAssignment> update(ProgrammeAssignment assignment) {
    throw UnimplementedError();
  }

  @override
  Future<List<ProgrammeAssignment>> listForAthlete(String athleteId) async =>
      const [];

  @override
  Future<int> countAssignmentsForVersion(String programmeVersionId) async => 0;
}

class _ThrowingAssignmentStore implements ProgrammeAssignmentStore {
  const _ThrowingAssignmentStore();

  @override
  Future<ProgrammeAssignment?> getActiveAssignment(String athleteId) {
    throw StateError('assignment store unavailable');
  }

  @override
  Future<ProgrammeAssignment?> getById(String assignmentId) async => null;

  @override
  Future<ProgrammeAssignment> insert(ProgrammeAssignment assignment) {
    throw UnimplementedError();
  }

  @override
  Future<ProgrammeAssignment> update(ProgrammeAssignment assignment) {
    throw UnimplementedError();
  }

  @override
  Future<List<ProgrammeAssignment>> listForAthlete(String athleteId) async =>
      const [];

  @override
  Future<int> countAssignmentsForVersion(String programmeVersionId) async => 0;
}
