import 'package:cohort_platform/features/home/widgets/athlete_programme_today_section.dart';
import 'package:cohort_platform/features/plans/models/programmed_session_key.dart';
import 'package:cohort_platform/features/programme/models/athlete_programme_prepared_session.dart';
import 'package:cohort_platform/features/programme/models/programme_execution_context.dart';
import 'package:cohort_platform/features/programme/models/programme_progress_summary.dart';
import 'package:cohort_platform/features/session/models/prepared_execution_package.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/models/workout_session_launch_context.dart';
import 'package:cohort_platform/features/session/services/programme_session_execution_launcher.dart';
import 'package:cohort_platform/features/session/services/programme_training_session_start_store.dart';
import 'package:cohort_platform/features/session/services/session_execution_launcher.dart';
import 'package:cohort_platform/features/workout_player/models/workout_session_brief.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _hashA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _hashB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

void main() {
  testWidgets(
    'Home atomically creates then resumes one stable training session',
    (tester) async {
      final starts = _InMemoryAtomicStartStore();
      final activeLauncher = _RecordingSessionExecutionLauncher();
      final launcher = ProgrammeSessionExecutionLauncher(
        startStore: starts,
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
      await tester.tap(find.text('Begin'));
      await tester.pumpAndSettle();

      expect(starts.calls, hasLength(2));
      expect(starts.createdCount, 1);
      expect(activeLauncher.trainingSessionIds, [1, 1]);
      expect(activeLauncher.plans.first.blocks.length, 3);
      expect(starts.calls[1], starts.calls[0]);
    },
  );

  testWidgets('unsupported authored format fails visibly before atomic start', (
    tester,
  ) async {
    final starts = _InMemoryAtomicStartStore();
    final launcher = ProgrammeSessionExecutionLauncher(
      startStore: starts,
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

    expect(starts.calls, isEmpty);
    expect(find.textContaining('unsupportedAuthoredBlock'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  test(
    'matching package provenance permits atomic create and resume',
    () async {
      final starts = _InMemoryAtomicStartStore();
      final launcher = ProgrammeSessionExecutionLauncher(startStore: starts);
      final prepared = _prepared();

      final first = await launcher.createOrResumeTrainingSession(
        athleteId: 'athlete-1',
        programmeContext: prepared.executionContext!,
        package: prepared.package!,
      );
      final second = await launcher.createOrResumeTrainingSession(
        athleteId: 'athlete-1',
        programmeContext: prepared.executionContext!,
        package: prepared.package!,
      );

      expect(first.id, 1);
      expect(first.programmeId, 'lineage-1');
      expect(second.id, 1);
      expect(starts.createdCount, 1);
    },
  );

  test('restart uses the same authoritative session identity', () async {
    final starts = _InMemoryAtomicStartStore();
    final prepared = _prepared();
    final firstLauncher = ProgrammeSessionExecutionLauncher(startStore: starts);
    final restartedLauncher = ProgrammeSessionExecutionLauncher(
      startStore: starts,
    );

    final first = await firstLauncher.createOrResumeTrainingSession(
      athleteId: 'athlete-1',
      programmeContext: prepared.executionContext!,
      package: prepared.package!,
    );
    final restored = await restartedLauncher.createOrResumeTrainingSession(
      athleteId: 'athlete-1',
      programmeContext: prepared.executionContext!,
      package: prepared.package!,
    );

    expect(restored.id, first.id);
    expect(starts.createdCount, 1);
  });

  test('missing prepared hash fails closed before persistence', () async {
    await _expectProvenanceFailure(
      prepared: _prepared(packageHash: null),
      expectedCode:
          ProgrammeSessionExecutionFailureCode.missingPreparedProvenance,
    );
  });

  test('missing execution hash fails closed before persistence', () async {
    await _expectProvenanceFailure(
      prepared: _prepared(contextHash: null),
      expectedCode:
          ProgrammeSessionExecutionFailureCode.missingExecutionProvenance,
    );
  });

  test('malformed prepared hash fails closed before persistence', () async {
    await _expectProvenanceFailure(
      prepared: _prepared(packageHash: 'not-a-canonical-hash'),
      expectedCode:
          ProgrammeSessionExecutionFailureCode.malformedPreparedProvenance,
    );
  });

  test('malformed execution hash fails closed before persistence', () async {
    await _expectProvenanceFailure(
      prepared: _prepared(contextHash: 'ABCDEF'),
      expectedCode:
          ProgrammeSessionExecutionFailureCode.malformedExecutionProvenance,
    );
  });

  test('mismatched hashes fail closed before persistence', () async {
    await _expectProvenanceFailure(
      prepared: _prepared(packageHash: _hashB),
      expectedCode:
          ProgrammeSessionExecutionFailureCode.preparedProvenanceMismatch,
    );
  });

  test(
    'correct re-preparation permits retry after provenance mismatch',
    () async {
      final starts = _InMemoryAtomicStartStore();
      final launcher = ProgrammeSessionExecutionLauncher(startStore: starts);
      final stale = _prepared(packageHash: _hashB);

      await expectLater(
        launcher.createOrResumeTrainingSession(
          athleteId: 'athlete-1',
          programmeContext: stale.executionContext!,
          package: stale.package!,
        ),
        throwsA(
          isA<ProgrammeSessionExecutionException>().having(
            (error) => error.code,
            'code',
            ProgrammeSessionExecutionFailureCode.preparedProvenanceMismatch,
          ),
        ),
      );

      final corrected = _prepared();
      final session = await launcher.createOrResumeTrainingSession(
        athleteId: 'athlete-1',
        programmeContext: corrected.executionContext!,
        package: corrected.package!,
      );

      expect(session.id, 1);
      expect(starts.calls, hasLength(1));
    },
  );

  testWidgets(
    'provenance mismatch is typed, visible, retryable, and never launches',
    (tester) async {
      final starts = _InMemoryAtomicStartStore();
      final activeLauncher = _RecordingSessionExecutionLauncher();
      final launcher = ProgrammeSessionExecutionLauncher(
        startStore: starts,
        sessionExecutionLauncher: activeLauncher,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AthleteProgrammeTodaySection(
              athleteId: 'athlete-1',
              executionLauncher: launcher,
              prepareOverride: (_) async => _prepared(packageHash: _hashB),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Begin'));
      await tester.pumpAndSettle();

      expect(find.textContaining('preparedProvenanceMismatch'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(starts.calls, isEmpty);
      expect(activeLauncher.trainingSessionIds, isEmpty);
    },
  );

  test('authoritative start failures remain typed', () async {
    final starts = _InMemoryAtomicStartStore(
      forcedResponse: const {
        'status': 'authorization_failure',
        'code': 'cross_athlete_assignment',
      },
    );
    final launcher = ProgrammeSessionExecutionLauncher(startStore: starts);
    final prepared = _prepared();

    await expectLater(
      launcher.createOrResumeTrainingSession(
        athleteId: 'athlete-1',
        programmeContext: prepared.executionContext!,
        package: prepared.package!,
      ),
      throwsA(
        isA<ProgrammeSessionExecutionException>().having(
          (error) => error.code,
          'code',
          ProgrammeSessionExecutionFailureCode.startAuthorizationFailed,
        ),
      ),
    );
  });
}

Future<void> _expectProvenanceFailure({
  required AthleteProgrammePrepareResult prepared,
  required ProgrammeSessionExecutionFailureCode expectedCode,
}) async {
  final starts = _InMemoryAtomicStartStore();
  final launcher = ProgrammeSessionExecutionLauncher(startStore: starts);

  await expectLater(
    launcher.createOrResumeTrainingSession(
      athleteId: 'athlete-1',
      programmeContext: prepared.executionContext!,
      package: prepared.package!,
    ),
    throwsA(
      isA<ProgrammeSessionExecutionException>().having(
        (error) => error.code,
        'code',
        expectedCode,
      ),
    ),
  );
  expect(starts.calls, isEmpty);
}

AthleteProgrammePrepareResult _prepared({
  String? packageHash = _hashA,
  String? contextHash = _hashA,
  bool unsupported = false,
}) {
  final context = _context(packageHash: contextHash);
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
    packageContentHash: packageHash,
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

ProgrammeExecutionContext _context({String? packageHash = _hashA}) {
  const key = ProgrammedSessionKey(
    planId: 'lineage-1',
    planVersion: 'version-1',
    week: 1,
    day: 1,
    dayKey: 'day_1',
    slotOrder: 1,
    protocolId: 'protocol-1',
    programmeAssignmentId: 'assignment-1',
    packageContentHash: _hashA,
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
    lineageCode: 'lineage-1',
    programmeName: 'Programme',
    packageContentHash: packageHash,
    programmedSessionKey: key.value,
  );
}

class _InMemoryAtomicStartStore implements ProgrammeTrainingSessionStartStore {
  _InMemoryAtomicStartStore({this.forcedResponse});

  final Map<String, dynamic>? forcedResponse;
  final calls = <Map<String, dynamic>>[];
  final Map<String, int> _ids = {};
  int createdCount = 0;

  @override
  Future<Map<String, dynamic>> createOrResume(
    Map<String, dynamic> payload,
  ) async {
    calls.add(Map<String, dynamic>.from(payload));
    if (forcedResponse case final response?) {
      return Map<String, dynamic>.from(response);
    }
    final key = '${payload['assignment_id']}:${payload['session_slot_id']}';
    final existing = _ids[key];
    final id = existing ?? ++createdCount;
    _ids[key] = id;
    return {
      'status': existing == null ? 'created' : 'resumed',
      'code': existing == null ? 'session_created' : 'existing_session',
      'training_session': {
        'id': id,
        'athlete_id': 'athlete-1',
        'protocol_id': payload['effective_protocol_id'],
        'status': 'in_progress',
        'programme_id': 'lineage-1',
        'week_number': payload['expected_week'],
        'day': payload['expected_day_key'],
        'started_at': DateTime.utc(2026, 8, 13, 9).toIso8601String(),
      },
    };
  }
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
