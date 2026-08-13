import 'package:cohort_platform/data/repositories/programme_slot_outcome_delete_result.dart';
import 'package:cohort_platform/data/repositories/programme_slot_outcome_store.dart';
import 'package:cohort_platform/data/repositories/training_session_repository.dart';
import 'package:cohort_platform/features/home/widgets/athlete_programme_today_section.dart';
import 'package:cohort_platform/features/plans/models/programmed_session_key.dart';
import 'package:cohort_platform/features/programme/models/athlete_programme_prepared_session.dart';
import 'package:cohort_platform/features/programme/models/programme_execution_context.dart';
import 'package:cohort_platform/features/programme/models/programme_progress_summary.dart';
import 'package:cohort_platform/features/programme/models/programme_progression_result.dart';
import 'package:cohort_platform/features/programme/models/resolved_today_session.dart';
import 'package:cohort_platform/features/programme/services/programme_progression_service.dart';
import 'package:cohort_platform/features/session/models/prepared_execution_package.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/models/workout_session_launch_context.dart';
import 'package:cohort_platform/features/session/services/programme_session_execution_launcher.dart';
import 'package:cohort_platform/features/session/services/programme_session_progression_coordinator.dart';
import 'package:cohort_platform/features/session/services/session_execution_launcher.dart';
import 'package:cohort_platform/features/workout_player/models/workout_session_brief.dart';
import 'package:cohort_platform/models/programme_slot_outcome.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/training_session.dart';
import 'package:cohort_platform/models/training_session_completion_context.dart';
import 'package:cohort_platform/models/training_session_status.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Home creates once, resumes occurrence, and launches block-aware route with stable id',
    (tester) async {
      final sessions = _FakeTrainingSessionRepository();
      final outcomes = _InMemorySlotOutcomeStore();
      final progression = _FakeProgressionService(outcomes);
      final activeLauncher = _RecordingSessionExecutionLauncher();
      final launcher = ProgrammeSessionExecutionLauncher(
        trainingSessionRepository: sessions,
        slotOutcomeStore: outcomes,
        progressionCoordinator: ProgrammeSessionProgressionCoordinator(
          progressionService: progression,
        ),
        sessionExecutionLauncher: activeLauncher,
      );
      final prepared = _prepared();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AthleteProgrammeTodaySection(
              athleteId: 'athlete-1',
              executionLauncher: launcher,
              prepareOverride: (_) async => prepared,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Begin'));
      await tester.pumpAndSettle();

      expect(sessions.createCount, 1);
      expect(activeLauncher.trainingSessionIds, [1]);
      expect(activeLauncher.plans.single.blocks.length, 3);
      expect(
        outcomes.outcome?.outcomeStatus,
        ProgrammeSlotOutcomeStatus.inProgress,
      );

      await tester.tap(find.text('Begin'));
      await tester.pumpAndSettle();

      expect(sessions.createCount, 1);
      expect(activeLauncher.trainingSessionIds, [1, 1]);
    },
  );

  testWidgets(
    'unsupported authored format fails visibly before session create',
    (tester) async {
      final sessions = _FakeTrainingSessionRepository();
      final launcher = ProgrammeSessionExecutionLauncher(
        trainingSessionRepository: sessions,
        slotOutcomeStore: _InMemorySlotOutcomeStore(),
        progressionCoordinator: ProgrammeSessionProgressionCoordinator(
          progressionService: _FakeProgressionService(
            _InMemorySlotOutcomeStore(),
          ),
        ),
        sessionExecutionLauncher: _RecordingSessionExecutionLauncher(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AthleteProgrammeTodaySection(
              athleteId: 'athlete-1',
              executionLauncher: launcher,
              prepareOverride: (_) async => _prepared(unsupported: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Begin'));
      await tester.pumpAndSettle();

      expect(sessions.createCount, 0);
      expect(find.textContaining('unsupportedAuthoredBlock'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    },
  );

  test('start persistence retry reuses pending training session', () async {
    final sessions = _FakeTrainingSessionRepository();
    final outcomes = _InMemorySlotOutcomeStore();
    final progression = _FakeProgressionService(outcomes)..failNext = true;
    final launcher = ProgrammeSessionExecutionLauncher(
      trainingSessionRepository: sessions,
      slotOutcomeStore: outcomes,
      progressionCoordinator: ProgrammeSessionProgressionCoordinator(
        progressionService: progression,
      ),
      sessionExecutionLauncher: _RecordingSessionExecutionLauncher(),
    );

    await expectLater(
      launcher.createOrResumeTrainingSession(
        athleteId: 'athlete-1',
        programmeContext: _context(),
      ),
      throwsA(
        isA<ProgrammeSessionExecutionException>().having(
          (error) => error.code,
          'code',
          ProgrammeSessionExecutionFailureCode.startPersistenceFailed,
        ),
      ),
    );

    final resumed = await launcher.createOrResumeTrainingSession(
      athleteId: 'athlete-1',
      programmeContext: _context(),
    );

    expect(resumed.id, 1);
    expect(sessions.createCount, 1);
    expect(outcomes.outcome?.trainingSessionId, 1);
  });
}

AthleteProgrammePrepareResult _prepared({bool unsupported = false}) {
  final context = _context();
  final plan = SessionExecutionPlan(
    sessionId: 'protocol-1',
    sessionTitle: 'Authored session',
    blocks: [
      const SessionExecutionBlock(
        blockId: 'strength',
        title: 'Strength',
        blockType: SessionBlockType.strength,
        content: 'Sets: 3\nReps: 5',
        workoutFormat: WorkoutFormat.none,
        position: 1,
        linkedExercises: [
          SessionExecutionExerciseSummary(
            exerciseId: 'exercise-1',
            displayName: 'Movement',
          ),
        ],
      ),
      const SessionExecutionBlock(
        blockId: 'circuit',
        title: 'Circuit',
        blockType: SessionBlockType.conditioning,
        content: 'Complete the authored circuit.',
        workoutFormat: WorkoutFormat.rounds,
        position: 2,
      ),
      SessionExecutionBlock(
        blockId: 'interval',
        title: 'Intervals',
        blockType: SessionBlockType.conditioning,
        content: 'Complete the authored intervals.',
        workoutFormat: unsupported
            ? WorkoutFormat.other
            : WorkoutFormat.intervals,
        position: 3,
      ),
    ],
  );
  final key = ProgrammedSessionKey.parse(context.programmedSessionKey!);
  final package = PreparedExecutionPackage(
    programmedSessionKey: key,
    plan: plan,
    brief: const WorkoutSessionBrief(sessionName: 'Authored session'),
    preparedAt: DateTime.utc(2026, 8, 13),
    assignmentId: context.assignmentId,
    programmeVersionId: context.programmeVersionId,
    packageContentHash: context.packageContentHash,
    dayKey: context.dayKey,
    slotOrder: context.sessionOrder,
    protocolId: context.effectiveProtocolId,
  );
  return AthleteProgrammePrepareResult(
    status: AthleteProgrammePrepareStatus.prepared,
    package: package,
    executionContext: context,
    programmedSessionKey: key,
  );
}

ProgrammeExecutionContext _context() {
  const key = ProgrammedSessionKey(
    planId: 'lineage-1',
    planVersion: 'version-1',
    week: 1,
    day: 1,
    dayKey: 'day_1',
    slotOrder: 1,
    protocolId: 'protocol-1',
    programmeAssignmentId: 'assignment-1',
    packageContentHash: 'hash-1',
  );
  return ProgrammeExecutionContext(
    assignmentId: 'assignment-1',
    programmeVersionId: 'version-1',
    sessionSlotId: 'slot-1',
    weekNumber: 1,
    dayKey: 'day_1',
    sessionOrder: 1,
    plannedProtocolId: 'protocol-1',
    effectiveProtocolId: 'protocol-1',
    programmeName: 'Programme',
    packageContentHash: 'hash-1',
    programmedSessionKey: key.value,
  );
}

class _FakeTrainingSessionRepository extends TrainingSessionRepository {
  int createCount = 0;
  final Map<int, TrainingSession> sessions = {};

  @override
  Future<TrainingSession> createSession({
    required String athleteId,
    required String protocolId,
    TrainingSessionStatus status = TrainingSessionStatus.planned,
    String? programmeId,
    int? weekNumber,
    String? day,
    DateTime? startedAt,
    DateTime? completedAt,
  }) async {
    createCount += 1;
    final session = TrainingSession(
      id: createCount,
      athleteId: athleteId,
      protocolId: protocolId,
      status: status,
      programmeId: programmeId,
      weekNumber: weekNumber,
      day: day,
      startedAt: startedAt ?? DateTime.utc(2026, 8, 13, 9),
      completedAt: completedAt,
    );
    sessions[session.id] = session;
    return session;
  }

  @override
  Future<TrainingSession?> getSessionById(int id) async => sessions[id];

  @override
  Future<TrainingSession?> completeSession(
    int id, {
    TrainingSessionCompletionContext? completion,
  }) async => sessions[id];
}

class _InMemorySlotOutcomeStore implements ProgrammeSlotOutcomeStore {
  ProgrammeSlotOutcome? outcome;

  @override
  Future<ProgrammeSlotOutcome?> getForSlot({
    required String assignmentId,
    required String sessionSlotId,
  }) async {
    final current = outcome;
    if (current?.assignmentId != assignmentId ||
        current?.sessionSlotId != sessionSlotId) {
      return null;
    }
    return current;
  }

  @override
  Future<ProgrammeSlotOutcome> upsert(ProgrammeSlotOutcome value) async {
    outcome = value;
    return value;
  }

  @override
  Future<List<ProgrammeSlotOutcome>> listForAssignment(
    String assignmentId,
  ) async {
    return outcome?.assignmentId == assignmentId ? [outcome!] : [];
  }

  @override
  Future<List<ProgrammeSlotOutcome>> listForDay({
    required String assignmentId,
    required int weekNumber,
    required String dayKey,
  }) async {
    return outcome?.assignmentId == assignmentId &&
            outcome?.weekNumber == weekNumber &&
            outcome?.dayKey == dayKey
        ? [outcome!]
        : [];
  }

  @override
  Future<ProgrammeSlotOutcomeDeleteResult> deleteOutcomesForAssignment({
    required String assignmentId,
  }) async {
    final deleted = outcome?.assignmentId == assignmentId ? 1 : 0;
    outcome = null;
    return ProgrammeSlotOutcomeDeleteResult(
      deletedCount: deleted,
      deletedIds: deleted == 0 ? const [] : const ['outcome-1'],
    );
  }
}

class _FakeProgressionService implements ProgrammeProgressionService {
  _FakeProgressionService(this.store);

  final _InMemorySlotOutcomeStore store;
  bool failNext = false;

  @override
  Future<ProgrammeProgressionResult> markSessionStarted({
    required String athleteId,
    required ResolvedTodaySession resolution,
    int? trainingSessionId,
  }) async {
    if (failNext) {
      failNext = false;
      throw StateError('start response unavailable');
    }
    final outcome = ProgrammeSlotOutcome(
      id: 'outcome-1',
      assignmentId: resolution.assignmentId!,
      sessionSlotId: resolution.slotId!,
      weekNumber: resolution.weekNumber!,
      dayKey: resolution.dayKey!,
      sessionOrder: resolution.slotOrder!,
      outcomeStatus: ProgrammeSlotOutcomeStatus.inProgress,
      trainingSessionId: trainingSessionId,
    );
    await store.upsert(outcome);
    return ProgrammeProgressionResult.partialSuccess(
      outcome: outcome,
      warnings: const [],
    );
  }

  @override
  Future<ProgrammeProgressionResult> completeSession({
    required String athleteId,
    required ResolvedTodaySession resolution,
    int? trainingSessionId,
    String? resolutionNote,
  }) => throw UnimplementedError();

  @override
  Future<ProgrammeProgressionResult> completeSessionPartial({
    required String athleteId,
    required ResolvedTodaySession resolution,
    int? trainingSessionId,
    String? resolutionNote,
  }) => throw UnimplementedError();

  @override
  Future<ProgrammeProgressionResult> replaceSession({
    required String athleteId,
    required ResolvedTodaySession resolution,
    required String replacementProtocolId,
    int? trainingSessionId,
    String? resolutionNote,
  }) => throw UnimplementedError();

  @override
  Future<ProgrammeProgressionResult> resolveAfterOutcome({
    required String athleteId,
    required ResolvedTodaySession resolution,
    required ProgrammeSlotOutcomeStatus outcomeStatus,
    int? trainingSessionId,
    String? replacementProtocolId,
    String? resolutionNote,
    bool advanceCursor = true,
  }) => throw UnimplementedError();

  @override
  Future<ProgrammeProgressionResult> skipSession({
    required String athleteId,
    required ResolvedTodaySession resolution,
    String? resolutionNote,
  }) => throw UnimplementedError();
}

class _RecordingSessionExecutionLauncher extends SessionExecutionLauncher {
  final List<int> trainingSessionIds = [];
  final List<SessionExecutionPlan> plans = [];

  @override
  Future<void> launchActiveSessionWithPlan({
    required BuildContext context,
    required SessionExecutionPlan plan,
    required String protocolId,
    required int trainingSessionId,
    required String athleteId,
    ProgrammeExecutionContext? programmeContext,
    ProgrammeProgressSummary? programmeProgress,
  }) async {
    trainingSessionIds.add(trainingSessionId);
    plans.add(plan);
  }

  @override
  Future<void> launchActiveSession({
    required BuildContext context,
    required String protocolId,
    required int trainingSessionId,
    required String athleteId,
    String? displayTitle,
    ProgrammeExecutionContext? programmeContext,
    String? programmeContextLabel,
    ProgrammeProgressSummary? programmeProgress,
    WorkoutSessionLaunchContext? workoutLaunchContext,
  }) async {
    throw UnimplementedError();
  }
}
