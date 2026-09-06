import 'package:cohort_platform/core/persistence/athlete_local_repository.dart';
import 'package:cohort_platform/core/persistence/local_kv_store.dart';
import 'package:cohort_platform/features/home/home_screen.dart';
import 'package:cohort_platform/features/home/widgets/athlete_programme_today_section.dart';
import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/models/performance_result_data.dart';
import 'package:cohort_platform/features/performance/repositories/in_memory_performance_record_store.dart';
import 'package:cohort_platform/features/performance/models/training_session_record_status.dart';
import 'package:cohort_platform/features/programme/models/fixed_programme_occurrence_projection.dart';
import 'package:cohort_platform/features/programme/models/programme_execution_context.dart';
import 'package:cohort_platform/features/programme/models/programme_progress_summary.dart';
import 'package:cohort_platform/features/programme/controllers/athlete_programme_controllers.dart';
import 'package:cohort_platform/features/programme/presentation/athlete_programme_lifecycle_presentation.dart';
import 'package:cohort_platform/features/programme/screens/athlete_programme_schedule_screen.dart';
import 'package:cohort_platform/features/programme/screens/athlete_calendar_screen.dart';
import 'package:cohort_platform/features/programme/screens/athlete_programme_screen.dart';
import 'package:cohort_platform/features/programme/screens/scheduled_programme_session_preview_screen.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_authored_slot_resolver.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_session_prepare_service.dart';
import 'package:cohort_platform/features/programme/services/fixed_programme_occurrence_projection_store.dart';
import 'package:cohort_platform/features/programme/services/scheduled_programme_session_preview_service.dart';
import 'package:cohort_platform/features/programme/widgets/fixed_programme_week_view.dart';
import 'package:cohort_platform/features/exercises/exercise_detail/exercise_detail_screen.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/services/programme_session_execution_launcher.dart';
import 'package:cohort_platform/features/session/services/programme_training_session_start_store.dart';
import 'package:cohort_platform/features/session/services/session_execution_loader.dart';
import 'package:cohort_platform/features/session/services/session_execution_launcher.dart';
import 'package:cohort_platform/models/exercise.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:cohort_platform/models/programme_version.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:cohort_platform/models/protocol.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/strength_exercise_prescription.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_programme_stores.dart';
import '../support/programme_schedule_test_fixtures.dart';

const _hash =
    'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';

class _ProjectionStore implements FixedProgrammeOccurrenceProjectionStore {
  _ProjectionStore(this.projection);

  final FixedProgrammeCalendarProjection? projection;
  int calls = 0;

  @override
  Future<FixedProgrammeCalendarProjection?> resolveActive() async {
    calls++;
    return projection;
  }
}

class _SequenceProjectionStore
    implements FixedProgrammeOccurrenceProjectionStore {
  _SequenceProjectionStore(this.results);

  final List<Object?> results;
  int calls = 0;

  @override
  Future<FixedProgrammeCalendarProjection?> resolveActive() async {
    final result =
        results[calls < results.length ? calls++ : results.length - 1];
    if (result is! FixedProgrammeCalendarProjection && result != null) {
      throw result;
    }
    return result as FixedProgrammeCalendarProjection?;
  }
}

class _ThrowingProjectionStore
    implements FixedProgrammeOccurrenceProjectionStore {
  @override
  Future<FixedProgrammeCalendarProjection?> resolveActive() {
    throw StateError('legacy path must not resolve fixed projection');
  }
}

class _EchoLoader extends SessionExecutionLoader {
  int calls = 0;
  String? lastProtocolId;

  @override
  Future<SessionExecutionLoadResult> load({
    required String protocolId,
    String? displayTitle,
    String? programmeContextLabel,
    Map<String, String> prescriptionLoadOverrides = const {},
  }) async {
    calls++;
    lastProtocolId = protocolId;
    return SessionExecutionLoadResult(
      plan: SessionExecutionPlan(
        sessionId: protocolId,
        sessionTitle: 'Session $protocolId',
        durationMin: 45,
        blocks: const [
          SessionExecutionBlock(
            blockId: 'block-1',
            title: 'Training',
            blockType: SessionBlockType.strength,
            content: 'Work',
            workoutFormat: WorkoutFormat.none,
            position: 0,
            linkedExercises: [
              SessionExecutionExerciseSummary(
                exerciseId: 'EX-001',
                displayName: 'Exercise',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewLoader extends SessionExecutionLoader {
  int calls = 0;
  String? lastProtocolId;

  @override
  Future<SessionExecutionLoadResult> load({
    required String protocolId,
    String? displayTitle,
    String? programmeContextLabel,
    Map<String, String> prescriptionLoadOverrides = const {},
  }) async {
    calls++;
    lastProtocolId = protocolId;
    return SessionExecutionLoadResult(
      plan: SessionExecutionPlan(
        sessionId: protocolId,
        sessionTitle: 'Strength Foundation',
        programmeContextLabel: programmeContextLabel,
        durationMin: 60,
        coachNotes: 'Move with control and preserve quality.',
        protocol: Protocol(
          protocolId: protocolId,
          name: 'Strength Foundation',
          sessionType: 'Strength',
          goal: 'Full-body strength',
          durationMin: 60,
        ),
        blocks: [
          SessionExecutionBlock(
            blockId: 'warm-up',
            title: 'Structured warm-up',
            blockType: SessionBlockType.warmUp,
            content: 'Prepare the thoracic spine and shoulder girdle.',
            workoutFormat: WorkoutFormat.none,
            position: 1,
            coachNotes: 'Use smooth, controlled repetitions.',
            linkedExercises: _warmUpExercises(),
          ),
          const SessionExecutionBlock(
            blockId: 'main-strength',
            title: 'Main strength',
            blockType: SessionBlockType.strength,
            content: 'Build quality strength through the full range.',
            workoutFormat: WorkoutFormat.emom,
            position: 2,
            timerSummary: '12 min · 60s intervals',
            linkedExercises: [
              SessionExecutionExerciseSummary(
                exerciseId: 'EX-001',
                displayName: 'Goblet Squat',
                prescription: StrengthExercisePrescription(
                  sets: 3,
                  reps: StrengthRepPrescription(
                    type: StrengthRepType.range,
                    minReps: 8,
                    maxReps: 10,
                  ),
                  restSeconds: 90,
                  tempo: '3-1-1',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static List<SessionExecutionExerciseSummary> _warmUpExercises() {
    return [
      _exercise(
        id: 'EX-150',
        name: 'Thoracic Extension Over Foam Roller',
        sets: 1,
        reps: const {'type': 'exact', 'exact_reps': 5},
        tempo: 'slow',
        cue: 'Use 2–3 positions.',
      ),
      _exercise(
        id: 'EX-151',
        name: 'Open-Book Rotation',
        sets: 1,
        reps: const {'type': 'exact', 'exact_reps': 6},
        cue: 'Complete each side.',
      ),
      _exercise(
        id: 'EX-152',
        name: 'Serratus Wall Slide and Reach',
        sets: 2,
        reps: const {'type': 'exact', 'exact_reps': 8},
      ),
      _exercise(
        id: 'EX-153',
        name: 'Wall Y / Lower-Trap Raise',
        sets: 2,
        reps: const {'type': 'range', 'min_reps': 8, 'max_reps': 10},
        load: const {'type': 'freeText', 'text': 'Very light'},
      ),
      _exercise(
        id: 'EX-154',
        name: 'Single-Arm Cable/Band Row With Reach',
        sets: 2,
        reps: const {'type': 'exact', 'exact_reps': 10},
        cue: 'Complete each side.',
      ),
    ];
  }

  static SessionExecutionExerciseSummary _exercise({
    required String id,
    required String name,
    required int sets,
    required Map<String, dynamic> reps,
    Map<String, dynamic>? load,
    String? tempo,
    String? cue,
  }) {
    return SessionExecutionExerciseSummary(
      exerciseId: id,
      displayName: name,
      exercise: Exercise(
        exerciseId: id,
        name: name,
        published: true,
        movementPattern: 'Mobility',
        equipment: 'Minimal',
        bodyRegion: 'Upper body',
        technicalComplexity: 'Low',
        purpose: 'Prepare for the authored session.',
        execution: 'Move through a controlled range.',
        coachingCues: cue,
      ),
      prescription: StrengthExercisePrescription.fromJson({
        'sets': sets,
        'reps': reps,
        'load': ?load,
        'tempo': ?tempo,
        'coach_cue': ?cue,
      }),
    );
  }
}

class _PlanPreviewLoader extends SessionExecutionLoader {
  _PlanPreviewLoader(this.plan);

  final SessionExecutionPlan plan;

  @override
  Future<SessionExecutionLoadResult> load({
    required String protocolId,
    String? displayTitle,
    String? programmeContextLabel,
    Map<String, String> prescriptionLoadOverrides = const {},
  }) async => SessionExecutionLoadResult(plan: plan);
}

class _NoopSessionExecutionLauncher extends SessionExecutionLauncher {
  int calls = 0;
  String? lastOccurrenceId;

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
    calls++;
    lastOccurrenceId = programmeContext?.occurrenceId;
  }
}

class _StartStore implements ProgrammeTrainingSessionStartStore {
  final calls = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> createOrResume(
    Map<String, dynamic> payload,
  ) async {
    calls.add(Map<String, dynamic>.from(payload));
    return {
      'status': calls.length == 1 ? 'created' : 'resumed',
      'training_session': {
        'id': 91,
        'athlete_id': 'athlete-1',
        'protocol_id': payload['effective_protocol_id'],
        'programme_id': 'PROG-FIXED',
        'week_number': payload['expected_week'],
        'day': payload['expected_day_key'],
        'status': 'in_progress',
      },
    };
  }
}

ProgrammeVersion _version() => ProgrammeVersion(
  id: ProgrammeScheduleTestFixtures.versionId,
  lineageId: ProgrammeScheduleTestFixtures.lineageId,
  versionNumber: 1,
  lifecycleStatus: ProgrammeLifecycleStatus.published,
  libraryScope: ProgrammeLibraryScope.cohortGlobal,
  ownerType: ProgrammeOwnerType.global,
  name: 'Apollo Build — 12-Week Initial Block',
  durationWeeks: 12,
  sessionsPerWeek: 7,
  approvedForGlobal: true,
  packageContentHash: _hash,
);

ProgrammeAssignment _assignment({
  String athleteId = 'athlete-1',
  bool fixed = true,
}) =>
    ProgrammeScheduleTestFixtures.materialisedAssignment(
      athleteId: athleteId,
      packageContentHash: _hash,
    ).copyWith(
      lineageCode: 'PROG-FIXED',
      startedAt: DateTime.utc(2026, 9, 1),
      timezone: 'Atlantic/Canary',
      scheduleMode: fixed ? 'fixed_schedule' : 'legacy_cursor',
      currentWeek: 1,
      currentDayKey: 'day_1',
      currentSessionOrder: 1,
    );

FixedProgrammeOccurrenceProjection _occurrence({
  required ProgrammeAssignment assignment,
  required String id,
  required String slotId,
  required String protocolId,
  required String dayKey,
  required String date,
  required FixedProgrammeOccurrenceState state,
  int? trainingSessionId,
  String? sessionTitle,
}) => FixedProgrammeOccurrenceProjection(
  assignmentId: assignment.id,
  occurrenceId: id,
  sessionSlotId: slotId,
  programmeVersionId: assignment.programmeVersionId,
  protocolId: protocolId,
  programmedSessionKey:
      'prog:${assignment.id}@${assignment.programmeVersionId}:w1:$dayKey:s1:$protocolId',
  weekNumber: 1,
  dayKey: dayKey,
  sessionOrder: 1,
  scheduledDate: date,
  originalScheduledDate: date,
  state: state,
  sessionTitle:
      sessionTitle ?? (dayKey == 'day_1' ? 'Apollo Monday' : 'Apollo Tuesday'),
  sessionLineageId: '00000000-0000-4000-8000-000000000099',
  sessionRevisionNumber: 1,
  trainingSessionId: trainingSessionId,
);

FixedProgrammeCalendarProjection _calendar({
  required ProgrammeAssignment assignment,
  required String today,
  required List<FixedProgrammeOccurrenceProjection> occurrences,
}) {
  final todayDate = DateTime.parse(today);
  final monday = todayDate.subtract(Duration(days: todayDate.weekday - 1));
  final week = <FixedProgrammeCalendarDayProjection>[];
  for (var index = 0; index < 7; index++) {
    final date = monday.add(Duration(days: index));
    final iso = date.toIso8601String().substring(0, 10);
    FixedProgrammeOccurrenceProjection? occurrence;
    for (final candidate in occurrences) {
      if (candidate.scheduledDate == iso) occurrence = candidate;
    }
    week.add(
      FixedProgrammeCalendarDayProjection(
        date: iso,
        state: occurrence?.state ?? FixedProgrammeOccurrenceState.rest,
        occurrence: occurrence,
      ),
    );
  }
  return FixedProgrammeCalendarProjection(
    assignmentId: assignment.id,
    programmeName: 'Apollo Build — 12-Week Initial Block',
    timezone: 'Atlantic/Canary',
    scheduleMode: 'fixed_schedule',
    startDate: '2026-09-01',
    today: today,
    weekStart: week.first.date,
    weekEnd: week.last.date,
    occurrences: List.unmodifiable(occurrences),
    currentWeek: List.unmodifiable(week),
  );
}

List<FixedProgrammeOccurrenceProjection> _firstWeekOccurrences({
  required ProgrammeAssignment assignment,
  FixedProgrammeOccurrenceState firstState =
      FixedProgrammeOccurrenceState.planned,
}) {
  return List.generate(7, (index) {
    final date = DateTime.utc(2026, 9, 1).add(Duration(days: index));
    final iso = date.toIso8601String().substring(0, 10);
    return _occurrence(
      assignment: assignment,
      id: '00000000-0000-4000-8000-${(201 + index).toString().padLeft(12, '0')}',
      slotId: index.isEven
          ? ProgrammeScheduleTestFixtures.slot1Id
          : ProgrammeScheduleTestFixtures.slot2Id,
      protocolId: index.isEven ? 'BW-001' : 'RN-006',
      dayKey: 'day_${index + 1}',
      date: iso,
      state: index == 0 ? firstState : FixedProgrammeOccurrenceState.planned,
    );
  }, growable: false);
}

Future<InMemoryProgrammeTables> _tablesWith(
  ProgrammeAssignment assignment,
) async {
  final tables = InMemoryProgrammeTables();
  final version = _version();
  await InMemoryProgrammeVersionStore(tables).saveTemplateTree(
    version: version,
    tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(
      programmeVersionId: version.id,
    ),
  );
  final versionIndex = tables.versions.indexWhere(
    (row) => row.id == version.id,
  );
  if (versionIndex >= 0) {
    tables.versions[versionIndex] = version;
  } else {
    tables.versions.add(version);
  }
  tables.assignments.add(assignment);
  return tables;
}

AthleteProgrammeSessionPrepareService _prepareService({
  required InMemoryProgrammeTables tables,
  required _EchoLoader loader,
  required FixedProgrammeOccurrenceProjectionStore projectionStore,
}) => AthleteProgrammeSessionPrepareService(
  assignmentStore: InMemoryProgrammeAssignmentStore(tables),
  slotResolver: AthleteProgrammeAuthoredSlotResolver(
    versionStore: InMemoryProgrammeVersionStore(tables),
  ),
  sessionLoader: loader,
  localRepository: AthleteLocalRepository(InMemoryKvStore()),
  fixedOccurrenceStore: projectionStore,
);

void main() {
  group('fixed occurrence preparation authority', () {
    test(
      'Sep 2 prepares Day 2 while compatibility cursor remains Day 1',
      () async {
        final assignment = _assignment();
        final day1 = _occurrence(
          assignment: assignment,
          id: '00000000-0000-4000-8000-000000000201',
          slotId: ProgrammeScheduleTestFixtures.slot1Id,
          protocolId: 'BW-001',
          dayKey: 'day_1',
          date: '2026-09-01',
          state: FixedProgrammeOccurrenceState.missed,
        );
        final day2 = _occurrence(
          assignment: assignment,
          id: '00000000-0000-4000-8000-000000000202',
          slotId: ProgrammeScheduleTestFixtures.slot2Id,
          protocolId: 'RN-006',
          dayKey: 'day_2',
          date: '2026-09-02',
          state: FixedProgrammeOccurrenceState.today,
        );
        final projection = _calendar(
          assignment: assignment,
          today: '2026-09-02',
          occurrences: [day1, day2],
        );
        final tables = await _tablesWith(assignment);
        final loader = _EchoLoader();
        final projectionStore = _ProjectionStore(projection);
        final result = await _prepareService(
          tables: tables,
          loader: loader,
          projectionStore: projectionStore,
        ).prepareForAssignment(assignment);

        expect(result.isReady, isTrue);
        expect(result.executionContext?.occurrenceId, day2.occurrenceId);
        expect(result.executionContext?.dayKey, 'day_2');
        expect(result.executionContext?.effectiveProtocolId, 'RN-006');
        expect(result.package?.dayKey, 'day_2');
        expect(assignment.currentDayKey, 'day_1');
        expect(loader.lastProtocolId, 'RN-006');
        expect(projectionStore.calls, 1);
      },
    );

    test(
      'overdue occurrence prepares for resume and preserves identity',
      () async {
        final assignment = _assignment();
        final overdue = _occurrence(
          assignment: assignment,
          id: '00000000-0000-4000-8000-000000000201',
          slotId: ProgrammeScheduleTestFixtures.slot1Id,
          protocolId: 'BW-001',
          dayKey: 'day_1',
          date: '2026-09-01',
          state: FixedProgrammeOccurrenceState.inProgressOverdue,
          trainingSessionId: 44,
        );
        final tables = await _tablesWith(assignment);
        final result = await _prepareService(
          tables: tables,
          loader: _EchoLoader(),
          projectionStore: _ProjectionStore(null),
        ).prepareFixedOccurrence(assignment, overdue);

        expect(result.isReady, isTrue);
        expect(result.executionContext?.occurrenceId, overdue.occurrenceId);
        expect(overdue.trainingSessionId, 44);
        expect(result.programmedSessionKey?.scheduleDate, DateTime(2026, 9, 1));
      },
    );

    test('future occurrence cannot be prepared', () async {
      final assignment = _assignment();
      final future = _occurrence(
        assignment: assignment,
        id: '00000000-0000-4000-8000-000000000203',
        slotId: ProgrammeScheduleTestFixtures.slot2Id,
        protocolId: 'RN-006',
        dayKey: 'day_2',
        date: '2026-09-03',
        state: FixedProgrammeOccurrenceState.planned,
      );
      final tables = await _tablesWith(assignment);
      final loader = _EchoLoader();
      final result = await _prepareService(
        tables: tables,
        loader: loader,
        projectionStore: _ProjectionStore(null),
      ).prepareFixedOccurrence(assignment, future);

      expect(result.isReady, isFalse);
      expect(result.code, 'fixed_occurrence_not_executable');
      expect(loader.calls, 0);
    });

    test(
      'missing fixed projection fails closed without cursor fallback',
      () async {
        final assignment = _assignment();
        final tables = await _tablesWith(assignment);
        final loader = _EchoLoader();
        final result = await _prepareService(
          tables: tables,
          loader: loader,
          projectionStore: _ProjectionStore(null),
        ).prepareForAssignment(assignment);

        expect(result.isReady, isFalse);
        expect(result.code, 'prepare_failed');
        expect(result.message, contains('projection is missing'));
        expect(loader.calls, 0);
      },
    );

    test('legacy assignment retains cursor compatibility path', () async {
      final assignment = _assignment(fixed: false);
      final tables = await _tablesWith(assignment);
      final loader = _EchoLoader();
      final result = await _prepareService(
        tables: tables,
        loader: loader,
        projectionStore: _ThrowingProjectionStore(),
      ).prepareForAssignment(assignment);

      expect(result.isReady, isTrue);
      expect(result.executionContext?.occurrenceId, isNull);
      expect(result.executionContext?.dayKey, 'day_1');
      expect(loader.lastProtocolId, 'BW-001');
    });

    test('Begin forwards the authoritative occurrence identity', () async {
      final assignment = _assignment();
      final today = _occurrence(
        assignment: assignment,
        id: '00000000-0000-4000-8000-000000000201',
        slotId: ProgrammeScheduleTestFixtures.slot1Id,
        protocolId: 'BW-001',
        dayKey: 'day_1',
        date: '2026-09-01',
        state: FixedProgrammeOccurrenceState.today,
      );
      final tables = await _tablesWith(assignment);
      final prepared = await _prepareService(
        tables: tables,
        loader: _EchoLoader(),
        projectionStore: _ProjectionStore(null),
      ).prepareFixedOccurrence(assignment, today);
      final startStore = _StartStore();
      final launcher = ProgrammeSessionExecutionLauncher(
        startStore: startStore,
      );

      final first = await launcher.createOrResumeTrainingSession(
        athleteId: 'athlete-1',
        programmeContext: prepared.executionContext!,
        package: prepared.package!,
      );
      final retry = await launcher.createOrResumeTrainingSession(
        athleteId: 'athlete-1',
        programmeContext: prepared.executionContext!,
        package: prepared.package!,
      );

      expect(first.id, 91);
      expect(retry.id, first.id);
      expect(startStore.calls, hasLength(2));
      expect(startStore.calls.first['occurrence_id'], today.occurrenceId);
      expect(startStore.calls.last['occurrence_id'], today.occurrenceId);
    });
  });

  group('fixed Home and Plans projection parity', () {
    testWidgets(
      'Home refreshes Begin to Resume after execution returns without duplicating the session',
      (tester) async {
        final assignment = _assignment();
        final today = _occurrence(
          assignment: assignment,
          id: '00000000-0000-4000-8000-000000000201',
          slotId: ProgrammeScheduleTestFixtures.slot1Id,
          protocolId: 'BW-001',
          dayKey: 'day_1',
          date: '2026-09-01',
          state: FixedProgrammeOccurrenceState.today,
        );
        final inProgress = _occurrence(
          assignment: assignment,
          id: today.occurrenceId,
          slotId: today.sessionSlotId,
          protocolId: today.protocolId,
          dayKey: today.dayKey,
          date: today.scheduledDate,
          state: FixedProgrammeOccurrenceState.inProgress,
          trainingSessionId: 91,
        );
        final store = _SequenceProjectionStore([
          _calendar(
            assignment: assignment,
            today: today.scheduledDate,
            occurrences: [today],
          ),
          _calendar(
            assignment: assignment,
            today: today.scheduledDate,
            occurrences: [inProgress],
          ),
        ]);
        final tables = await _tablesWith(assignment);
        final startStore = _StartStore();

        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(
              embeddedInShell: true,
              athleteIdOverride: 'athlete-1',
              assignmentStore: InMemoryProgrammeAssignmentStore(tables),
              fixedOccurrenceStore: store,
              prepareService: _prepareService(
                tables: tables,
                loader: _EchoLoader(),
                projectionStore: store,
              ),
              executionLauncher: ProgrammeSessionExecutionLauncher(
                startStore: startStore,
                sessionExecutionLauncher: _NoopSessionExecutionLauncher(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Begin'), findsOneWidget);
        await tester.tap(find.text('Begin'));
        await tester.pumpAndSettle();

        expect(find.text('Resume'), findsOneWidget);
        expect(find.text('Begin'), findsNothing);
        expect(startStore.calls, hasLength(1));
        expect(store.calls, 2);

        await tester.tap(find.text('Resume'));
        await tester.pumpAndSettle();

        expect(find.text('Resume'), findsOneWidget);
        expect(startStore.calls, hasLength(2));
        expect(startStore.calls.first['occurrence_id'], today.occurrenceId);
        expect(startStore.calls.last['occurrence_id'], today.occurrenceId);
      },
    );

    testWidgets('Home refreshes fixed occurrence authority when app resumes', (
      tester,
    ) async {
      final assignment = _assignment(athleteId: 'athlete.local');
      final today = _occurrence(
        assignment: assignment,
        id: '00000000-0000-4000-8000-000000000201',
        slotId: ProgrammeScheduleTestFixtures.slot1Id,
        protocolId: 'BW-001',
        dayKey: 'day_1',
        date: '2026-09-01',
        state: FixedProgrammeOccurrenceState.today,
      );
      final inProgress = _occurrence(
        assignment: assignment,
        id: today.occurrenceId,
        slotId: today.sessionSlotId,
        protocolId: today.protocolId,
        dayKey: today.dayKey,
        date: today.scheduledDate,
        state: FixedProgrammeOccurrenceState.inProgress,
        trainingSessionId: 91,
      );
      final store = _SequenceProjectionStore([
        _calendar(
          assignment: assignment,
          today: today.scheduledDate,
          occurrences: [today],
        ),
        _calendar(
          assignment: assignment,
          today: today.scheduledDate,
          occurrences: [inProgress],
        ),
      ]);
      final tables = await _tablesWith(assignment);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            embeddedInShell: true,
            assignmentStore: InMemoryProgrammeAssignmentStore(tables),
            fixedOccurrenceStore: store,
            prepareService: _prepareService(
              tables: tables,
              loader: _EchoLoader(),
              projectionStore: store,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Begin'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Begin'), findsNothing);
      expect(store.calls, 2);
    });

    testWidgets(
      'completed today retains result, next preview, and overdue Resume after relaunch',
      (tester) async {
        final assignment = _assignment();
        final overdue = _occurrence(
          assignment: assignment,
          id: '00000000-0000-4000-8000-000000000301',
          slotId: '00000000-0000-4000-8000-000000000401',
          protocolId: 'APOLLO-W1-MON-R1',
          dayKey: 'day_1',
          date: '2026-09-01',
          state: FixedProgrammeOccurrenceState.inProgressOverdue,
          trainingSessionId: 90,
          sessionTitle: 'Apollo Strength',
        );
        final completed = _occurrence(
          assignment: assignment,
          id: '00000000-0000-4000-8000-000000000302',
          slotId: '00000000-0000-4000-8000-000000000402',
          protocolId: 'APOLLO-W1-THU-R1',
          dayKey: 'day_2',
          date: '2026-09-02',
          state: FixedProgrammeOccurrenceState.completed,
          trainingSessionId: 91,
          sessionTitle: 'Apollo Engine',
        );
        final next = _occurrence(
          assignment: assignment,
          id: '00000000-0000-4000-8000-000000000303',
          slotId: '00000000-0000-4000-8000-000000000403',
          protocolId: 'APOLLO-W1-WED-R1',
          dayKey: 'day_3',
          date: '2026-09-03',
          state: FixedProgrammeOccurrenceState.planned,
          sessionTitle: 'Apollo Racehorse',
        );
        final calendar = _calendar(
          assignment: assignment,
          today: '2026-09-02',
          occurrences: [overdue, completed, next],
        );
        final tables = await _tablesWith(assignment);
        final performanceStore = InMemoryPerformanceRecordStore();
        final controller =
            PerformanceCaptureController.initializeFromExecutionPlan(
                plan: const SessionExecutionPlan(
                  sessionId: 'APOLLO-W1-THU-R1',
                  sessionTitle: 'Apollo Engine',
                  blocks: [
                    SessionExecutionBlock(
                      blockId: 'steady',
                      title: 'Continuous run',
                      blockType: SessionBlockType.conditioning,
                      content: 'Continuous aerobic work.',
                      workoutFormat: WorkoutFormat.steadyState,
                      position: 1,
                    ),
                  ],
                ),
                athleteId: 'athlete-1',
                trainingSessionId: 91,
              )
              ..updateBlockResultData(
                'steady',
                const EnduranceResultData(
                  distance: 10,
                  durationSeconds: 3600,
                  averageHeartRate: 140,
                ),
              )
              ..markBlockComplete('steady')
              ..updateSessionRpe(7);
        await performanceStore.completeRecord(
          controller.buildPersistableDraft(
            status: TrainingSessionRecordStatus.completed,
            completedAt: controller.draft.startedAt.add(
              const Duration(minutes: 61, seconds: 1),
            ),
          ),
        );
        final projectionStore = _ProjectionStore(calendar);
        final previewService = ScheduledProgrammeSessionPreviewService(
          loader: _PlanPreviewLoader(
            const SessionExecutionPlan(
              sessionId: 'APOLLO-W1-THU-R1',
              sessionTitle: 'Apollo Engine',
              blocks: [
                SessionExecutionBlock(
                  blockId: 'steady',
                  title: 'Continuous run',
                  blockType: SessionBlockType.conditioning,
                  content: 'Continuous aerobic work.',
                  workoutFormat: WorkoutFormat.steadyState,
                  position: 1,
                ),
              ],
            ),
          ),
        );

        Widget app({Key? key}) => MaterialApp(
          home: HomeScreen(
            key: key,
            embeddedInShell: true,
            athleteIdOverride: 'athlete-1',
            assignmentStore: InMemoryProgrammeAssignmentStore(tables),
            fixedOccurrenceStore: projectionStore,
            previewService: previewService,
            performanceRecordStore: performanceStore,
          ),
        );

        await tester.pumpWidget(app());
        await tester.pumpAndSettle();

        expect(find.text('Apollo Engine'), findsOneWidget);
        expect(find.text('Completed'), findsWidgets);
        expect(find.textContaining('Duration 61m 01s'), findsOneWidget);
        expect(find.textContaining('RPE 7'), findsOneWidget);
        expect(find.text('UP NEXT'), findsOneWidget);
        expect(find.text('Apollo Racehorse'), findsOneWidget);
        expect(find.text('Resume'), findsOneWidget);
        expect(find.text('Begin'), findsNothing);

        await tester.tap(find.byKey(const ValueKey('up-next-view-session')));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Available 3 September'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
      expect(find.text('Available 3 September'), findsOneWidget);
      expect(find.text('Train today'), findsNothing);
      expect(find.text('Begin'), findsNothing);
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('completed-today-view-result')),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            'This assigned session has been completed and cannot be restarted.',
          ),
          findsOneWidget,
        );
        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(find.textContaining('10.0 km in 1:00:00'), findsOneWidget);
        expect(find.text('Begin'), findsNothing);
        expect(find.text('Resume'), findsNothing);
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();

        await tester.pumpWidget(app(key: UniqueKey()));
        await tester.pumpAndSettle();
        expect(find.text('Apollo Engine'), findsOneWidget);
        expect(find.text('UP NEXT'), findsOneWidget);
        expect(find.text('Resume'), findsOneWidget);
        expect(find.text('Begin'), findsNothing);
      },
    );

    testWidgets(
      'completed today omits UP NEXT when no future planned occurrence exists',
      (tester) async {
        final assignment = _assignment();
        final laterMissed = _occurrence(
          assignment: assignment,
          id: '00000000-0000-4000-8000-000000000311',
          slotId: '00000000-0000-4000-8000-000000000411',
          protocolId: 'APOLLO-W1-WED-R1',
          dayKey: 'day_3',
          date: '2026-09-03',
          state: FixedProgrammeOccurrenceState.missed,
          sessionTitle: 'Apollo Racehorse',
        );
        final completed = _occurrence(
          assignment: assignment,
          id: '00000000-0000-4000-8000-000000000312',
          slotId: '00000000-0000-4000-8000-000000000412',
          protocolId: 'APOLLO-W1-THU-R1',
          dayKey: 'day_2',
          date: '2026-09-02',
          state: FixedProgrammeOccurrenceState.completed,
          trainingSessionId: 92,
          sessionTitle: 'Apollo Engine',
        );
        final calendar = _calendar(
          assignment: assignment,
          today: '2026-09-02',
          occurrences: [laterMissed, completed],
        );
        final tables = await _tablesWith(assignment);

        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(
              embeddedInShell: true,
              athleteIdOverride: 'athlete-1',
              assignmentStore: InMemoryProgrammeAssignmentStore(tables),
              fixedOccurrenceStore: _ProjectionStore(calendar),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Apollo Engine'), findsOneWidget);
        expect(find.text('Completed'), findsWidgets);
        expect(find.text('UP NEXT'), findsNothing);
        expect(find.text('Apollo Racehorse'), findsNothing);
        expect(calendar.nextPlannedOccurrence, isNull);
      },
    );

    test('next planned occurrence is the earliest future planned session', () {
      final assignment = _assignment();
      final later = _occurrence(
        assignment: assignment,
        id: '00000000-0000-4000-8000-000000000321',
        slotId: '00000000-0000-4000-8000-000000000421',
        protocolId: 'APOLLO-W1-FRI-R1',
        dayKey: 'day_5',
        date: '2026-09-04',
        state: FixedProgrammeOccurrenceState.planned,
        sessionTitle: 'Later session',
      );
      final sooner = _occurrence(
        assignment: assignment,
        id: '00000000-0000-4000-8000-000000000322',
        slotId: '00000000-0000-4000-8000-000000000422',
        protocolId: 'APOLLO-W1-WED-R1',
        dayKey: 'day_3',
        date: '2026-09-03',
        state: FixedProgrammeOccurrenceState.planned,
        sessionTitle: 'Sooner session',
      );
      final completed = _occurrence(
        assignment: assignment,
        id: '00000000-0000-4000-8000-000000000323',
        slotId: '00000000-0000-4000-8000-000000000423',
        protocolId: 'APOLLO-W1-THU-R1',
        dayKey: 'day_2',
        date: '2026-09-02',
        state: FixedProgrammeOccurrenceState.completed,
        sessionTitle: 'Apollo Engine',
      );

      final calendar = _calendar(
        assignment: assignment,
        today: '2026-09-02',
        occurrences: [later, completed, sooner],
      );

      expect(calendar.nextPlannedOccurrence?.sessionTitle, 'Sooner session');
    });

    testWidgets('Home and Plans render the same seven authoritative states', (
      tester,
    ) async {
      final assignment = _assignment(athleteId: 'athlete.local');
      final day1 = _occurrence(
        assignment: assignment,
        id: '00000000-0000-4000-8000-000000000201',
        slotId: ProgrammeScheduleTestFixtures.slot1Id,
        protocolId: 'BW-001',
        dayKey: 'day_1',
        date: '2026-09-01',
        state: FixedProgrammeOccurrenceState.missed,
      );
      final day2 = _occurrence(
        assignment: assignment,
        id: '00000000-0000-4000-8000-000000000202',
        slotId: ProgrammeScheduleTestFixtures.slot2Id,
        protocolId: 'RN-006',
        dayKey: 'day_2',
        date: '2026-09-02',
        state: FixedProgrammeOccurrenceState.today,
      );
      final projection = _calendar(
        assignment: assignment,
        today: '2026-09-02',
        occurrences: [day1, day2],
      );
      final store = _ProjectionStore(projection);
      final tables = await _tablesWith(assignment);
      final previewLoader = _PreviewLoader();
      final previewService = ScheduledProgrammeSessionPreviewService(
        loader: previewLoader,
      );
      final prepare = _prepareService(
        tables: tables,
        loader: _EchoLoader(),
        projectionStore: store,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            embeddedInShell: true,
            assignmentStore: InMemoryProgrammeAssignmentStore(tables),
            prepareService: prepare,
            fixedOccurrenceStore: store,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AthleteProgrammeTodaySection), findsOneWidget);
      expect(find.text("TODAY'S TRAINING"), findsOneWidget);
      expect(find.text('THIS WEEK'), findsOneWidget);
      expect(find.text('CURRENT PROGRAMME'), findsOneWidget);
      expect(find.text('Missed'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Not active'), findsOneWidget);
      expect(find.text('Rest'), findsNothing);
      expect(find.text('Programme'), findsNothing);
      expect(find.text('Build physical capability.'), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          home: AthleteProgrammeScheduleScreen(
            athleteId: 'athlete.local',
            assignmentId: assignment.id,
            fixedOccurrenceStore: store,
            previewService: previewService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('THIS WEEK'), findsOneWidget);
      expect(find.text('Missed'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Not active'), findsOneWidget);
      expect(find.text('Rest'), findsNothing);
    });

    testWidgets('Aug 24 future start is human upcoming and has no false Rest', (
      tester,
    ) async {
      final assignment = _assignment(athleteId: 'athlete.local');
      final firstWeek = _firstWeekOccurrences(assignment: assignment);
      final projection = _calendar(
        assignment: assignment,
        today: '2026-08-24',
        occurrences: firstWeek,
      );
      final store = _ProjectionStore(projection);
      final tables = await _tablesWith(assignment);
      final previewLoader = _PreviewLoader();
      final previewService = ScheduledProgrammeSessionPreviewService(
        loader: previewLoader,
      );
      final prepareLoader = _EchoLoader();
      final startStore = _StartStore();
      final executionView = _NoopSessionExecutionLauncher();
      final prepare = _prepareService(
        tables: tables,
        loader: prepareLoader,
        projectionStore: store,
      );
      final execution = ProgrammeSessionExecutionLauncher(
        startStore: startStore,
        sessionExecutionLauncher: executionView,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            embeddedInShell: true,
            assignmentStore: InMemoryProgrammeAssignmentStore(tables),
            fixedOccurrenceStore: store,
            prepareService: prepare,
            executionLauncher: execution,
            previewService: previewService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('UPCOMING PROGRAMME'), findsOneWidget);
      expect(find.text('Apollo Build — 12-Week Initial Block'), findsOneWidget);
      expect(find.text('Starts Tuesday, 1 September'), findsOneWidget);
      expect(
        find.text('Your first session unlocks in 8 days.'),
        findsOneWidget,
      );
      expect(find.text('FIRST WEEK'), findsOneWidget);
      expect(find.text('1–7 September'), findsOneWidget);
      expect(find.text('Planned'), findsNWidgets(7));
      expect(find.text("TODAY'S TRAINING"), findsNothing);
      expect(find.text('Begin'), findsNothing);
      expect(find.text('Rest'), findsNothing);
      expect(find.textContaining('2026-09-01'), findsNothing);
      expect(find.textContaining('Atlantic/Canary'), findsNothing);
      expect(find.textContaining('day_1'), findsNothing);
      expect(find.byType(AthleteProgrammeTodaySection), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('programme-week-day-2026-09-01')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byType(ScheduledProgrammeSessionPreviewScreen),
        findsOneWidget,
      );
      expect(find.text('Scheduled for Tuesday, 1 September'), findsOneWidget);
      expect(find.text('Begin'), findsNothing);
      expect(startStore.calls, isEmpty);
      expect(executionView.calls, 0);
      expect(prepareLoader.calls, 0);
      expect(tables.outcomes, isEmpty);
      expect(assignment.currentDayKey, 'day_1');
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        MaterialApp(
          home: AthleteProgrammeScheduleScreen(
            athleteId: 'athlete.local',
            assignmentId: assignment.id,
            fixedOccurrenceStore: store,
            previewService: previewService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Starts Tuesday, 1 September'), findsOneWidget);
      expect(find.text('FIRST WEEK'), findsOneWidget);
      expect(find.text('Planned'), findsNWidgets(7));
      expect(find.textContaining('2026-09-01'), findsNothing);
      expect(find.textContaining('Atlantic/Canary'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('programme-week-day-2026-09-01')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Session'), findsOneWidget);
      expect(find.text('Scheduled for Tuesday, 1 September'), findsOneWidget);
      expect(
        find.text('Week 1 · Day 1 · Tuesday, 1 September'),
        findsOneWidget,
      );
      expect(find.text('Strength Foundation'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Available 1 September'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Available 1 September'), findsOneWidget);
      expect(find.text('Train today'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Train today is available for sessions in the next 7 days.'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('2026-09-01'), findsNothing);
      expect(find.text('Begin'), findsNothing);
      expect(previewLoader.calls, 2);
    });

    testWidgets(
      'Plans shares upcoming lifecycle labels without false position',
      (tester) async {
        final assignment = _assignment(athleteId: 'athlete.local');
        final projection = _calendar(
          assignment: assignment,
          today: '2026-08-24',
          occurrences: _firstWeekOccurrences(assignment: assignment),
        );
        final store = _ProjectionStore(projection);
        final previewLoader = _PreviewLoader();
        final tables = await _tablesWith(assignment);
        final controller = AthleteProgrammeScreenController(
          athleteId: 'athlete.local',
          assignmentStore: InMemoryProgrammeAssignmentStore(tables),
          versionStore: InMemoryProgrammeVersionStore(tables),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: AthleteProgrammeScreen(
              athleteId: 'athlete.local',
              controller: controller,
              fixedOccurrenceStore: store,
              previewService: ScheduledProgrammeSessionPreviewService(
                loader: previewLoader,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Starts 1 September'), findsOneWidget);
        expect(
          find.text('Your first session unlocks in 8 days.'),
          findsOneWidget,
        );
        expect(find.text('12 weeks'), findsOneWidget);
        expect(find.text('7 sessions per week'), findsOneWidget);
        expect(find.text('View Programme Calendar'), findsOneWidget);
        expect(find.text('Preview Week 1'), findsNothing);
        expect(find.text('Browse programmes'), findsOneWidget);
        expect(find.text('View programmes'), findsNothing);
        expect(find.textContaining('Started'), findsNothing);
        expect(find.textContaining('Week 1 · Day 1'), findsNothing);
        expect(find.textContaining('session appears on Home'), findsNothing);
        expect(find.textContaining('2026-09-01'), findsNothing);
        expect(find.textContaining('Atlantic/Canary'), findsNothing);
        expect(find.text('FIRST WEEK'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('programme-week-day-2026-09-01')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Scheduled for Tuesday, 1 September'), findsOneWidget);
        expect(find.text('Strength Foundation'), findsOneWidget);
        expect(previewLoader.calls, 1);
      },
    );

    testWidgets('active Sep 1 and an empty date use lifecycle-safe headings', (
      tester,
    ) async {
      final assignment = _assignment(athleteId: 'athlete.local');
      final firstWeek = _firstWeekOccurrences(
        assignment: assignment,
        firstState: FixedProgrammeOccurrenceState.today,
      );
      final activeProjection = _calendar(
        assignment: assignment,
        today: '2026-09-01',
        occurrences: firstWeek,
      );
      final activeStore = _ProjectionStore(activeProjection);
      final tables = await _tablesWith(assignment);
      final prepare = _prepareService(
        tables: tables,
        loader: _EchoLoader(),
        projectionStore: activeStore,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            key: UniqueKey(),
            embeddedInShell: true,
            assignmentStore: InMemoryProgrammeAssignmentStore(tables),
            prepareService: prepare,
            fixedOccurrenceStore: activeStore,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("TODAY'S TRAINING"), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('THIS WEEK'), findsOneWidget);

      final plansController = AthleteProgrammeScreenController(
        athleteId: 'athlete.local',
        assignmentStore: InMemoryProgrammeAssignmentStore(tables),
        versionStore: InMemoryProgrammeVersionStore(tables),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AthleteProgrammeScreen(
            athleteId: 'athlete.local',
            controller: plansController,
            fixedOccurrenceStore: activeStore,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Week 1 · Day 1'), findsOneWidget);
      expect(
        find.text("Today's authored session is available on Home."),
        findsOneWidget,
      );

      final restOccurrences = firstWeek
          .where((occurrence) => occurrence.scheduledDate != '2026-09-06')
          .toList(growable: false);
      final restProjection = _calendar(
        assignment: assignment,
        today: '2026-09-06',
        occurrences: restOccurrences,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            embeddedInShell: true,
            assignmentStore: InMemoryProgrammeAssignmentStore(tables),
            fixedOccurrenceStore: _ProjectionStore(restProjection),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('No session scheduled today.'), findsOneWidget);
      expect(find.text("TODAY'S TRAINING"), findsNothing);
      expect(find.text('Rest'), findsNothing);
    });

    testWidgets('compact week is accessible at 320 logical pixels', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final assignment = _assignment(athleteId: 'athlete.local');
      final projection = _calendar(
        assignment: assignment,
        today: '2026-08-24',
        occurrences: _firstWeekOccurrences(assignment: assignment),
      );
      final tables = await _tablesWith(assignment);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            embeddedInShell: true,
            assignmentStore: InMemoryProgrammeAssignmentStore(tables),
            fixedOccurrenceStore: _ProjectionStore(projection),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final firstDay = find.byKey(
        const ValueKey('programme-week-day-2026-09-01'),
      );
      expect(firstDay, findsOneWidget);
      final tapSize = tester.getSize(firstDay);
      expect(tapSize.width, greaterThanOrEqualTo(48));
      expect(tapSize.height, greaterThanOrEqualTo(48));
      expect(find.text('Planned'), findsNWidgets(7));
    });

    testWidgets('empty calendar dates are inert and never labelled Rest', (
      tester,
    ) async {
      var opens = 0;
      final assigned = _occurrence(
        assignment: _assignment(),
        id: '00000000-0000-4000-8000-000000000702',
        slotId: ProgrammeScheduleTestFixtures.slot1Id,
        protocolId: 'APOLLO-W1-MON-R1',
        dayKey: 'day_1',
        date: '2026-09-01',
        state: FixedProgrammeOccurrenceState.planned,
      );
      final week = AthleteProgrammeWeekPresentation(
        heading: 'THIS WEEK',
        dateRangeLabel: '1–7 September',
        days: [
          AthleteProgrammeWeekDayPresentation(
            date: DateTime(2026, 9, 1),
            state: assigned.state,
            occurrence: assigned,
          ),
          ...List.generate(
            6,
            (index) => AthleteProgrammeWeekDayPresentation(
              date: DateTime(2026, 9, index + 2),
              state: FixedProgrammeOccurrenceState.rest,
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FixedProgrammeWeekView(
              presentation: week,
              onDayTap: (_) => opens++,
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('programme-week-day-2026-09-02')),
      );
      await tester.pump();
      expect(opens, 0);
      expect(find.text('Rest'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('programme-week-day-2026-09-01')),
      );
      expect(opens, 1);
    });
  });

  group('assigned scheduled-session read-only preview', () {
    test(
      'resolves APOLLO-W1-MON-R1 only through authoritative occurrence linkage',
      () async {
        final assignment = _assignment();
        final occurrence = _occurrence(
          assignment: assignment,
          id: '00000000-0000-4000-8000-000000000301',
          slotId: ProgrammeScheduleTestFixtures.slot1Id,
          protocolId: 'APOLLO-W1-MON-R1',
          dayKey: 'day_1',
          date: '2026-09-01',
          state: FixedProgrammeOccurrenceState.planned,
        );
        final calendar = _calendar(
          assignment: assignment,
          today: '2026-08-24',
          occurrences: [occurrence],
        );
        final day = AthleteProgrammeLifecycleFormatter.fromFixedProjection(
          calendar,
        ).week.days.first;
        final loader = _PreviewLoader();
        final service = ScheduledProgrammeSessionPreviewService(loader: loader);

        final preview = await service.load(calendar: calendar, day: day);

        expect(preview.occurrence?.occurrenceId, occurrence.occurrenceId);
        expect(loader.lastProtocolId, 'APOLLO-W1-MON-R1');
        expect(preview.plan?.sessionTitle, 'Strength Foundation');
        expect(preview.plan?.blocks, hasLength(2));

        final substituted = _occurrence(
          assignment: assignment,
          id: occurrence.occurrenceId,
          slotId: occurrence.sessionSlotId,
          protocolId: 'SUBSTITUTED-PROTOCOL',
          dayKey: occurrence.dayKey,
          date: occurrence.scheduledDate,
          state: occurrence.state,
        );
        final substitutedDay = AthleteProgrammeWeekDayPresentation(
          date: DateTime(2026, 9, 1),
          state: substituted.state,
          occurrence: substituted,
        );
        await expectLater(
          service.load(calendar: calendar, day: substitutedDay),
          throwsA(isA<StateError>()),
        );
        expect(loader.calls, 1);
      },
    );

    testWidgets(
      'future preview renders all structured warm-up content and exercise detail',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final assignment = _assignment(athleteId: 'athlete.local');
        final occurrence = _occurrence(
          assignment: assignment,
          id: '00000000-0000-4000-8000-000000000301',
          slotId: ProgrammeScheduleTestFixtures.slot1Id,
          protocolId: 'APOLLO-W1-MON-R1',
          dayKey: 'day_1',
          date: '2026-09-01',
          state: FixedProgrammeOccurrenceState.planned,
        );
        final calendar = _calendar(
          assignment: assignment,
          today: '2026-08-24',
          occurrences: [occurrence],
        );
        final day = AthleteProgrammeLifecycleFormatter.fromFixedProjection(
          calendar,
        ).week.days.first;
        final loader = _PreviewLoader();

        await tester.pumpWidget(
          MaterialApp(
            home: ScheduledProgrammeSessionPreviewScreen(
              athleteId: 'athlete.local',
              calendar: calendar,
              day: day,
              previewService: ScheduledProgrammeSessionPreviewService(
                loader: loader,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Scheduled for Tuesday, 1 September'), findsOneWidget);
        expect(
          find.text('Week 1 · Day 1 · Tuesday, 1 September'),
          findsOneWidget,
        );
        await tester.scrollUntilVisible(
          find.text('Type · Strength'),
          240,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Type · Strength'), findsOneWidget);
        expect(find.text('Focus · Full-body strength'), findsOneWidget);
        expect(find.text('60 min estimated'), findsOneWidget);
        expect(find.text('Begin'), findsNothing);
        expect(find.textContaining('APOLLO-W1-MON-R1'), findsNothing);
        expect(find.textContaining('day_1'), findsNothing);

        for (final movement in const [
          'Thoracic Extension Over Foam Roller',
          'Open-Book Rotation',
          'Serratus Wall Slide and Reach',
          'Wall Y / Lower-Trap Raise',
          'Single-Arm Cable/Band Row With Reach',
        ]) {
          await tester.scrollUntilVisible(
            find.text(movement),
            240,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text(movement), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        await tester.scrollUntilVisible(
          find.text('Available 1 September'),
          500,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Available 1 September'), findsOneWidget);
        expect(find.text('Train today'), findsNothing);
        await tester.scrollUntilVisible(
          find.text('Train today is available for sessions in the next 7 days.'),
          200,
          scrollable: find.byType(Scrollable).first,
        );

        await tester.scrollUntilVisible(
          find.bySemanticsLabel(
            'Exercise info for Thoracic Extension Over Foam Roller',
          ),
          -300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(
          find.bySemanticsLabel(
            'Exercise info for Thoracic Extension Over Foam Roller',
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.bySemanticsLabel(
            'Exercise info for Thoracic Extension Over Foam Roller',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ExerciseDetailScreen), findsOneWidget);
        expect(
          find.text('Thoracic Extension Over Foam Roller'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Today Begin is occurrence-bound and preview itself is inert', (
      tester,
    ) async {
      final assignment = _assignment();
      final occurrence = _occurrence(
        assignment: assignment,
        id: '00000000-0000-4000-8000-000000000201',
        slotId: ProgrammeScheduleTestFixtures.slot1Id,
        protocolId: 'BW-001',
        dayKey: 'day_1',
        date: '2026-09-01',
        state: FixedProgrammeOccurrenceState.today,
      );
      final calendar = _calendar(
        assignment: assignment,
        today: '2026-09-01',
        occurrences: [occurrence],
      );
      final day = AthleteProgrammeLifecycleFormatter.fromFixedProjection(
        calendar,
      ).week.days.firstWhere((candidate) => candidate.occurrence != null);
      final tables = await _tablesWith(assignment);
      final prepareLoader = _EchoLoader();
      final prepare = _prepareService(
        tables: tables,
        loader: prepareLoader,
        projectionStore: _ProjectionStore(calendar),
      );
      final startStore = _StartStore();
      final activeLauncher = _NoopSessionExecutionLauncher();
      final execution = ProgrammeSessionExecutionLauncher(
        startStore: startStore,
        sessionExecutionLauncher: activeLauncher,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => openScheduledProgrammeSessionPreview(
                context: context,
                athleteId: 'athlete-1',
                calendar: calendar,
                day: day,
                previewService: ScheduledProgrammeSessionPreviewService(
                  loader: _PreviewLoader(),
                ),
                assignmentStore: InMemoryProgrammeAssignmentStore(tables),
                prepareService: prepare,
                executionLauncher: execution,
              ),
              child: const Text('Open preview'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open preview'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Begin'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Begin'));
      await tester.pumpAndSettle();
      expect(find.text('Begin'), findsOneWidget);
      expect(startStore.calls, isEmpty);
      expect(prepareLoader.calls, 0);
      expect(activeLauncher.calls, 0);
      expect(tables.outcomes, isEmpty);

      await tester.tap(find.text('Begin'));
      await tester.pumpAndSettle();

      expect(startStore.calls, hasLength(1));
      expect(startStore.calls.single['occurrence_id'], occurrence.occurrenceId);
      expect(activeLauncher.calls, 1);
      expect(activeLauncher.lastOccurrenceId, occurrence.occurrenceId);
      expect(tables.outcomes, isEmpty);
      expect(assignment.currentDayKey, 'day_1');
    });

    testWidgets('overdue Resume remains occurrence-bound', (tester) async {
      final assignment = _assignment();
      final occurrence = _occurrence(
        assignment: assignment,
        id: '00000000-0000-4000-8000-000000000201',
        slotId: ProgrammeScheduleTestFixtures.slot1Id,
        protocolId: 'BW-001',
        dayKey: 'day_1',
        date: '2026-09-01',
        state: FixedProgrammeOccurrenceState.inProgressOverdue,
        trainingSessionId: 91,
      );
      final calendar = _calendar(
        assignment: assignment,
        today: '2026-09-02',
        occurrences: [occurrence],
      );
      final day = AthleteProgrammeWeekDayPresentation(
        date: DateTime(2026, 9, 1),
        state: occurrence.state,
        occurrence: occurrence,
      );
      final tables = await _tablesWith(assignment);
      final startStore = _StartStore();
      final activeLauncher = _NoopSessionExecutionLauncher();

      await tester.pumpWidget(
        MaterialApp(
          home: ScheduledProgrammeSessionPreviewScreen(
            athleteId: 'athlete-1',
            calendar: calendar,
            day: day,
            previewService: ScheduledProgrammeSessionPreviewService(
              loader: _PreviewLoader(),
            ),
            assignmentStore: InMemoryProgrammeAssignmentStore(tables),
            prepareService: _prepareService(
              tables: tables,
              loader: _EchoLoader(),
              projectionStore: _ProjectionStore(calendar),
            ),
            executionLauncher: ProgrammeSessionExecutionLauncher(
              startStore: startStore,
              sessionExecutionLauncher: activeLauncher,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Resume'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Resume'));
      await tester.pumpAndSettle();
      expect(find.text('Resume'), findsOneWidget);
      expect(startStore.calls, isEmpty);
      await tester.tap(find.text('Resume'));
      await tester.pumpAndSettle();
      expect(startStore.calls, hasLength(1));
      expect(startStore.calls.single['occurrence_id'], occurrence.occurrenceId);
      expect(activeLauncher.lastOccurrenceId, occurrence.occurrenceId);
    });

    testWidgets('Missed, Completed and empty dates never offer execution', (
      tester,
    ) async {
      final assignment = _assignment(athleteId: 'athlete.local');
      for (final state in const [
        FixedProgrammeOccurrenceState.missed,
        FixedProgrammeOccurrenceState.completed,
      ]) {
        final occurrence = _occurrence(
          assignment: assignment,
          id: '00000000-0000-4000-8000-000000000401',
          slotId: ProgrammeScheduleTestFixtures.slot1Id,
          protocolId: 'APOLLO-W1-MON-R1',
          dayKey: 'day_1',
          date: '2026-09-01',
          state: state,
        );
        final calendar = _calendar(
          assignment: assignment,
          today: '2026-09-02',
          occurrences: [occurrence],
        );
        await tester.pumpWidget(
          MaterialApp(
            home: ScheduledProgrammeSessionPreviewScreen(
              key: ValueKey(state),
              athleteId: 'athlete.local',
              calendar: calendar,
              day: AthleteProgrammeWeekDayPresentation(
                date: DateTime(2026, 9, 1),
                state: state,
                occurrence: occurrence,
              ),
              previewService: ScheduledProgrammeSessionPreviewService(
                loader: _PreviewLoader(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(state.displayLabel), findsOneWidget);
        expect(find.text('Begin'), findsNothing);
        expect(find.text('Resume'), findsNothing);
      }

      final restCalendar = _calendar(
        assignment: assignment,
        today: '2026-09-06',
        occurrences: const [],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ScheduledProgrammeSessionPreviewScreen(
            athleteId: 'athlete.local',
            calendar: restCalendar,
            day: AthleteProgrammeWeekDayPresentation(
              date: DateTime(2026, 9, 6),
              state: FixedProgrammeOccurrenceState.rest,
            ),
            previewService: ScheduledProgrammeSessionPreviewService(
              loader: _PreviewLoader(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No session scheduled'), findsWidgets);
      expect(find.text('Begin'), findsNothing);
      expect(find.text('Resume'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets(
    'athlete-wide Calendar retains all 84 assignment occurrences and opens an assigned session',
    (tester) async {
      final assignment = _assignment();
      final start = DateTime.utc(2026, 9, 1);
      final occurrences = List.generate(84, (index) {
        final date = start.add(Duration(days: index));
        return _occurrence(
          assignment: assignment,
          id: 'occurrence-$index',
          slotId: 'slot-$index',
          protocolId: 'APOLLO-${index + 1}',
          dayKey: 'day_${(index % 7) + 1}',
          date: date.toIso8601String().substring(0, 10),
          state: FixedProgrammeOccurrenceState.planned,
        );
      });
      final calendar = _calendar(
        assignment: assignment,
        today: '2026-08-25',
        occurrences: occurrences,
      );
      final store = _ProjectionStore(calendar);

      expect(calendar.occurrences, hasLength(84));
      expect(
        calendar.occurrences.every(
          (item) =>
              item.assignmentId == assignment.id &&
              item.programmeVersionId == assignment.programmeVersionId,
        ),
        isTrue,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AthleteCalendarScreen(
            athleteId: 'athlete.local',
            fixedOccurrenceStore: store,
            previewService: ScheduledProgrammeSessionPreviewService(
              loader: _PreviewLoader(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text('Rest'), findsNothing);
      await tester.tap(find.byTooltip('Next week'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('programme-week-day-2026-09-01')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Session'), findsOneWidget);
      expect(find.textContaining('Scheduled for'), findsOneWidget);
      expect(find.text('Begin'), findsNothing);
    },
  );

  testWidgets('Home calendar action delegates to the unified Calendar tab', (
    tester,
  ) async {
    final assignment = _assignment(athleteId: 'athlete.local');
    final calendar = _calendar(
      assignment: assignment,
      today: '2026-08-25',
      occurrences: _firstWeekOccurrences(assignment: assignment),
    );
    var openedCalendar = false;
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          embeddedInShell: true,
          assignmentStore: InMemoryProgrammeAssignmentStore(
            await _tablesWith(assignment),
          ),
          fixedOccurrenceStore: _ProjectionStore(calendar),
          onOpenCalendar: () => openedCalendar = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('View Calendar').first);
    expect(openedCalendar, isTrue);
  });

  testWidgets(
    'Calendar replaces a completed absent projection with no-programme state',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AthleteCalendarScreen(
            athleteId: 'athlete.local',
            fixedOccurrenceStore: _ProjectionStore(null),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No programme scheduled'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Rest'), findsNothing);
    },
  );

  testWidgets(
    'Calendar treats an active programme without an occurrence schedule as unavailable',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AthleteCalendarScreen(
            athleteId: 'athlete.local',
            fixedOccurrenceStore: _SequenceProjectionStore([
              const FixedProgrammeCalendarUnavailableException(
                'legacy_cursor_assignment',
              ),
            ]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Calendar unavailable'), findsOneWidget);
      expect(find.text('No programme scheduled'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
    },
  );

  testWidgets('Calendar reloads after delayed authentication restoration', (
    tester,
  ) async {
    final assignment = _assignment();
    final calendar = _calendar(
      assignment: assignment,
      today: '2026-08-25',
      occurrences: _firstWeekOccurrences(assignment: assignment),
    );
    final authChanges = ValueNotifier<int>(0);
    final store = _SequenceProjectionStore([null, calendar]);
    await tester.pumpWidget(
      MaterialApp(
        home: AthleteCalendarScreen(
          athleteId: 'athlete.local',
          fixedOccurrenceStore: store,
          authRefreshListenable: authChanges,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No programme scheduled'), findsOneWidget);

    authChanges.value++;
    await tester.pumpAndSettle();
    expect(find.text(calendar.programmeName), findsOneWidget);
    expect(find.text('No programme scheduled'), findsNothing);
    expect(store.calls, 2);
    authChanges.dispose();
  });

  testWidgets(
    'Calendar error is human-readable and Retry observes completion',
    (tester) async {
      final assignment = _assignment();
      final calendar = _calendar(
        assignment: assignment,
        today: '2026-08-25',
        occurrences: _firstWeekOccurrences(assignment: assignment),
      );
      final store = _SequenceProjectionStore([
        StateError('transport'),
        calendar,
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: AthleteCalendarScreen(
            athleteId: 'athlete.local',
            fixedOccurrenceStore: store,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Calendar unavailable'), findsOneWidget);
      expect(find.text('transport'), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text(calendar.programmeName), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  test('shared lifecycle formatter omits fixed cursor before start', () {
    final assignment = _assignment();
    final upcoming = _calendar(
      assignment: assignment,
      today: '2026-08-24',
      occurrences: _firstWeekOccurrences(assignment: assignment),
    );
    final upcomingLabels =
        AthleteProgrammeLifecycleFormatter.fromFixedProjection(upcoming);

    expect(upcomingLabels.lifecycle, AthleteProgrammeLifecycle.upcoming);
    expect(upcomingLabels.statusLabel, 'Starts 1 September');
    expect(upcomingLabels.daysUntilStart, 8);
    expect(upcomingLabels.currentWeekNumber, isNull);
    expect(upcomingLabels.currentDayLabel, isNull);
    expect(upcomingLabels.week.days, hasLength(7));

    final active = _calendar(
      assignment: assignment,
      today: '2026-09-01',
      occurrences: _firstWeekOccurrences(
        assignment: assignment,
        firstState: FixedProgrammeOccurrenceState.today,
      ),
    );
    final activeLabels = AthleteProgrammeLifecycleFormatter.fromFixedProjection(
      active,
    );
    expect(activeLabels.lifecycle, AthleteProgrammeLifecycle.active);
    expect(activeLabels.statusLabel, 'Week 1 · Day 1');
  });

  test('typed projection rejects malformed or non-seven-day payloads', () {
    expect(
      () => FixedProgrammeCalendarProjection.fromMap({
        'assignment_id': 'assignment',
        'programme_name': 'Apollo',
        'programme_timezone': 'Atlantic/Canary',
        'scheduling_mode': 'fixed_schedule',
        'start_date': '2026-09-01',
        'today': '2026-09-01',
        'week_start': '2026-08-31',
        'week_end': '2026-09-06',
        'occurrences': <Object>[],
        'current_week': <Object>[],
      }),
      throwsFormatException,
    );
  });
}
