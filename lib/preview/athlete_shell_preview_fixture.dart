import '../features/athlete_profile/models/athlete_profile.dart';
import '../features/athlete_profile/services/athlete_profile_session.dart';
import '../features/auth/models/user_profile.dart';
import '../features/auth/services/current_user_session.dart';
import '../features/performance/models/performance_result_type.dart';
import '../features/performance/models/performance_snapshot.dart';
import '../features/performance/models/training_block_result_status.dart';
import '../features/performance/models/training_session_record.dart';
import '../features/performance/models/training_session_record_status.dart';
import '../features/progress/services/athlete_progress_summary_builder.dart';
import '../features/performance/repositories/in_memory_performance_record_store.dart';
import '../features/plans/models/programmed_session_key.dart';
import '../features/programme/controllers/athlete_programme_controllers.dart';
import '../features/programme/models/fixed_programme_occurrence_projection.dart';
import '../features/programme/models/programme_catalog_entry.dart';
import '../features/programme/models/programme_template.dart';
import '../features/programme/services/athlete_programme_authored_slot_resolver.dart';
import '../features/programme/services/athlete_programme_session_prepare_service.dart';
import '../features/programme/services/backfill_programme_session_store.dart';
import '../features/programme/services/in_memory_backfill_programme_session_store.dart';
import '../features/programme/services/scheduled_programme_session_preview_service.dart';
import '../features/session/models/session_execution_plan.dart';
import '../features/session/services/programme_session_execution_launcher.dart';
import '../features/session/services/session_execution_loader.dart';
import '../features/session/services/session_execution_launcher.dart';
import '../features/workout_player/models/previous_performance_snapshot.dart';
import '../core/persistence/athlete_local_repository.dart';
import '../core/persistence/local_kv_store.dart';
import '../models/programme_assignment.dart';
import '../models/programme_lineage.dart';
import '../models/programme_version.dart';
import '../models/programme_version_day.dart';
import '../models/programme_version_session_slot.dart';
import '../models/programme_version_week.dart';
import '../models/programme_vocabulary.dart';
import '../models/protocol.dart';
import '../models/session_block_type.dart';
import '../models/strength_exercise_prescription.dart';
import '../models/workout_format.dart';
import 'athlete_shell_preview_stores.dart';

const previewAthleteId = 'athlete.preview.lee';
const previewAssignmentId = 'assignment-preview';
const previewVersionId = 'version-preview';
const previewPackageHash =
    'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
const previewSlotStrength = '00000000-0000-4000-8000-000000000001';
const previewSlotIntervals = '00000000-0000-4000-8000-000000000002';
const previewSlotFuture = '00000000-0000-4000-8000-000000000003';
const previewToday = '2026-09-10';

enum AthleteShellPreviewScenario {
  todayNotStarted,
  todayInProgress,
  todayComplete,
  restDay,
  progressEmpty,
  progressTwoStrength,
  incompleteRecovery,
}

class AthleteShellPreviewBundle {
  AthleteShellPreviewBundle({
    required this.assignmentStore,
    required this.versionStore,
    required this.projectionStore,
    required this.prepare,
    required this.execution,
    required this.previewService,
    required this.performance,
    required this.swapStore,
    required this.backfillStore,
    required this.programmeController,
    required this.progressBuilder,
  });

  final PreviewAssignmentStore assignmentStore;
  final PreviewVersionStore versionStore;
  final PreviewProjectionStore projectionStore;
  final AthleteProgrammeSessionPrepareService prepare;
  final ProgrammeSessionExecutionLauncher execution;
  final ScheduledProgrammeSessionPreviewService previewService;
  final InMemoryPerformanceRecordStore performance;
  final PreviewSwapStore swapStore;
  final BackfillProgrammeSessionStore backfillStore;
  final AthleteProgrammeScreenController programmeController;
  final AthleteProgressSummaryBuilder progressBuilder;

  factory AthleteShellPreviewBundle.seed(AthleteShellPreviewScenario scenario) {
    _bindAthlete();
    PreviousPerformanceStore.replaceAll([
      PreviousPerformanceSnapshot(
        exerciseId: 'EX-095',
        sessionType: PreviousPerformanceSessionType.strength,
        performedAt: DateTime.utc(2026, 8, 3),
        repSummary: '6, 6, 5, 5',
        loadSummary: '+10 kg',
      ),
    ]);
    final assignment = _assignment();
    final version = _version();
    final tree = _tree(version);
    final assignmentStore = PreviewAssignmentStore(assignment);
    final versionStore = PreviewVersionStore(
      lineage: const ProgrammeLineage(id: 'lineage-preview', code: 'APOLLO-V2'),
      version: version,
      tree: tree,
      catalogue: [
        ProgrammeCatalogEntry(
          versionId: version.id,
          lineageCode: 'APOLLO-V2',
          versionNumber: 2,
          name: version.name,
          lifecycleStatus: version.lifecycleStatus,
          libraryScope: version.libraryScope,
          ownerType: version.ownerType,
          description: version.description,
          durationWeeks: version.durationWeeks,
          approvedForGlobal: true,
        ),
      ],
    );
    final projectionStore = PreviewProjectionStore(
      _calendar(assignment, scenario),
    );
    final loader = PreviewSessionLoader();
    final prepare = AthleteProgrammeSessionPrepareService(
      assignmentStore: assignmentStore,
      slotResolver: AthleteProgrammeAuthoredSlotResolver(
        versionStore: versionStore,
      ),
      sessionLoader: loader,
      localRepository: AthleteLocalRepository(InMemoryKvStore()),
      fixedOccurrenceStore: projectionStore,
    );
    final performance = InMemoryPerformanceRecordStore();
    if (scenario == AthleteShellPreviewScenario.progressTwoStrength) {
      for (final record in _completedStrengthHistory()) {
        performance.put(record);
      }
    } else if (scenario == AthleteShellPreviewScenario.todayComplete) {
      performance.put(_completedStrengthHistory().last);
    }
    return AthleteShellPreviewBundle(
      assignmentStore: assignmentStore,
      versionStore: versionStore,
      projectionStore: projectionStore,
      prepare: prepare,
      execution: ProgrammeSessionExecutionLauncher(
        startStore: PreviewStartStore(),
        sessionExecutionLauncher: SessionExecutionLauncher(loader: loader),
      ),
      previewService: ScheduledProgrammeSessionPreviewService(loader: loader),
      performance: performance,
      swapStore: PreviewSwapStore(
        assignmentStore: assignmentStore,
        projectionStore: projectionStore,
        packageContentHash: previewPackageHash,
      ),
      backfillStore: InMemoryBackfillProgrammeSessionStore(
        performance: performance,
        projectionStore: projectionStore,
        readProjection: () => projectionStore.projection,
        writeProjection: (next) => projectionStore.projection = next,
      ),
      programmeController: AthleteProgrammeScreenController(
        athleteId: previewAthleteId,
        assignmentStore: assignmentStore,
        versionStore: versionStore,
        prepareService: prepare,
      ),
      progressBuilder: AthleteProgressSummaryBuilder(
        assignmentStore: assignmentStore,
        versionStore: versionStore,
        performanceRecordStore: performance,
      ),
    );
  }
}

void _bindAthlete() {
  CurrentUserSession.bind(
    const UserProfile(
      id: previewAthleteId,
      displayName: 'Lee',
      isCoach: false,
      isAthlete: true,
    ),
  );
  final now = DateTime.utc(2026, 9, 10, 10);
  AthleteProfileSession.bind(
    profile: AthleteProfile(
      athleteId: previewAthleteId,
      displayName: 'Lee',
      primaryGoal: AthleteGoalCatalog.byId('strength'),
      availableEquipment: const ['cohort.equipment.gym'],
      environmentId: 'cohort.environment.gym',
      trainingDaysPerWeek: 5,
      preferredSessionDurationMinutes: 60,
      experienceLevel: AthleteExperienceLevel.intermediate,
      assessmentComplete: true,
      createdAt: now,
      updatedAt: now,
    ),
  );
}

ProgrammeAssignment _assignment() {
  return ProgrammeAssignment(
    id: previewAssignmentId,
    athleteId: previewAthleteId,
    programmeVersionId: previewVersionId,
    lineageCode: 'APOLLO-V2',
    status: ProgrammeAssignmentStatus.active,
    startedAt: DateTime.utc(2026, 9, 1),
    timezone: 'Atlantic/Canary',
    scheduleMode: 'fixed_schedule',
    materialisedAt: DateTime.utc(2026, 9, 1),
    materialisationSource: 'preview',
    materialisedPackageContentHash: previewPackageHash,
    currentWeek: 1,
    currentDayKey: 'day_4',
    currentSessionOrder: 1,
  );
}

ProgrammeVersion _version() {
  return ProgrammeVersion(
    id: previewVersionId,
    lineageId: 'lineage-preview',
    versionNumber: 2,
    lifecycleStatus: ProgrammeLifecycleStatus.published,
    libraryScope: ProgrammeLibraryScope.cohortGlobal,
    ownerType: ProgrammeOwnerType.global,
    name: 'Apollo Build — 12-Week Initial Block',
    description: 'Apollo v2 fixture used only by the local athlete-shell preview.',
    durationWeeks: 12,
    publishedAt: DateTime.utc(2026, 8, 1),
    packageContentHash: previewPackageHash,
  );
}

ProgrammeTemplateTree _tree(ProgrammeVersion version) {
  const weekId = '00000000-0000-4000-8000-000000000011';
  ProgrammeTemplateDayNode day({
    required String id,
    required String dayKey,
    required int order,
    required bool rest,
    List<ProgrammeVersionSessionSlot> slots = const [],
  }) {
    return ProgrammeTemplateDayNode(
      day: ProgrammeVersionDay(
        id: id,
        weekId: weekId,
        dayKey: dayKey,
        dayOrder: order,
        title: rest ? 'Rest' : null,
        dayType: rest ? ProgrammeDayType.rest : ProgrammeDayType.training,
      ),
      slots: slots,
    );
  }

  ProgrammeVersionSessionSlot slot({
    required String id,
    required String dayId,
    required String protocolId,
  }) {
    return ProgrammeVersionSessionSlot(
      id: id,
      dayId: dayId,
      sessionOrder: 1,
      protocolId: protocolId,
    );
  }

  final week = ProgrammeVersionWeek(
    id: weekId,
    versionId: version.id,
    weekNumber: 1,
    title: 'Week 1',
  );
  return ProgrammeTemplateTree(
    template: ProgrammeTemplate(version: version, weeks: [week]),
    weekNodes: [
      ProgrammeTemplateWeekNode(
        week: week,
        days: [
          day(
            id: '00000000-0000-4000-8000-000000000101',
            dayKey: 'day_1',
            order: 1,
            rest: true,
          ),
          day(
            id: '00000000-0000-4000-8000-000000000102',
            dayKey: 'day_2',
            order: 2,
            rest: false,
            slots: [
              slot(
                id: previewSlotIntervals,
                dayId: '00000000-0000-4000-8000-000000000102',
                protocolId: 'RN-006',
              ),
            ],
          ),
          day(
            id: '00000000-0000-4000-8000-000000000103',
            dayKey: 'day_3',
            order: 3,
            rest: true,
          ),
          day(
            id: '00000000-0000-4000-8000-000000000104',
            dayKey: 'day_4',
            order: 4,
            rest: false,
            slots: [
              slot(
                id: previewSlotStrength,
                dayId: '00000000-0000-4000-8000-000000000104',
                protocolId: 'BW-001',
              ),
            ],
          ),
          day(
            id: '00000000-0000-4000-8000-000000000105',
            dayKey: 'day_5',
            order: 5,
            rest: false,
            slots: [
              slot(
                id: previewSlotFuture,
                dayId: '00000000-0000-4000-8000-000000000105',
                protocolId: 'RN-006',
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

String _key({
  required ProgrammeAssignment assignment,
  required int week,
  required String dayKey,
  required String protocolId,
  required String date,
}) {
  return ProgrammedSessionKey.fromMaterialisedProgramme(
    assignment: assignment.copyWith(
      currentWeek: week,
      currentDayKey: dayKey,
      currentSessionOrder: 1,
    ),
    protocolId: protocolId,
    packageContentHash: previewPackageHash,
    scheduleDate: DateTime.parse(date),
  ).value;
}

FixedProgrammeCalendarProjection _calendar(
  ProgrammeAssignment assignment,
  AthleteShellPreviewScenario scenario,
) {
  FixedProgrammeOccurrenceProjection session({
    required String id,
    required String date,
    required FixedProgrammeOccurrenceState state,
    required String title,
    required String type,
    required String dayKey,
    required String protocolId,
    required String slotId,
    int? trainingSessionId,
  }) {
    return FixedProgrammeOccurrenceProjection(
      assignmentId: assignment.id,
      occurrenceId: id,
      sessionSlotId: slotId,
      programmeVersionId: assignment.programmeVersionId,
      protocolId: protocolId,
      programmedSessionKey: _key(
        assignment: assignment,
        week: 1,
        dayKey: dayKey,
        protocolId: protocolId,
        date: date,
      ),
      weekNumber: 1,
      dayKey: dayKey,
      sessionOrder: 1,
      scheduledDate: date,
      originalScheduledDate: date,
      state: state,
      sessionTitle: title,
      sessionType: type,
      trainingSessionId: trainingSessionId,
    );
  }

  final todayState = switch (scenario) {
    AthleteShellPreviewScenario.todayNotStarted =>
      FixedProgrammeOccurrenceState.today,
    AthleteShellPreviewScenario.todayInProgress =>
      FixedProgrammeOccurrenceState.inProgress,
    AthleteShellPreviewScenario.todayComplete =>
      FixedProgrammeOccurrenceState.completed,
    AthleteShellPreviewScenario.restDay => FixedProgrammeOccurrenceState.rest,
    AthleteShellPreviewScenario.progressEmpty =>
      FixedProgrammeOccurrenceState.today,
    AthleteShellPreviewScenario.progressTwoStrength =>
      FixedProgrammeOccurrenceState.completed,
    AthleteShellPreviewScenario.incompleteRecovery =>
      FixedProgrammeOccurrenceState.today,
  };
  final occurrences = <FixedProgrammeOccurrenceProjection>[
    session(
      id: 'occ-incomplete',
      date: '2026-09-08',
      state: FixedProgrammeOccurrenceState.overdue,
      title: 'Apollo Intervals',
      type: 'Run',
      dayKey: 'day_2',
      protocolId: 'RN-006',
      slotId: previewSlotIntervals,
    ),
    if (scenario != AthleteShellPreviewScenario.restDay)
      session(
        id: 'occ-today',
        date: previewToday,
        state: todayState,
        title: 'Apollo Strength',
        type: 'Strength · Gym',
        dayKey: 'day_4',
        protocolId: 'BW-001',
        slotId: previewSlotStrength,
        trainingSessionId:
            scenario == AthleteShellPreviewScenario.todayComplete ||
                    scenario == AthleteShellPreviewScenario.progressTwoStrength
                ? 41
                : null,
      ),
    session(
      id: 'occ-future',
      date: '2026-09-11',
      state: FixedProgrammeOccurrenceState.planned,
      title: 'Interval Run',
      type: 'Run',
      dayKey: 'day_5',
      protocolId: 'RN-006',
      slotId: previewSlotFuture,
    ),
  ];
  final todayDate = DateTime.parse(previewToday);
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
    today: previewToday,
    weekStart: week.first.date,
    weekEnd: week.last.date,
    occurrences: occurrences,
    currentWeek: week,
  );
}

List<TrainingSessionRecord> _completedStrengthHistory() {
  return [
    _strengthRecord(
      recordId: 'record-preview-earlier',
      trainingSessionId: 40,
      completedAt: DateTime.utc(2026, 9, 3, 10),
      pullLoad: 10,
      includePress: false,
    ),
    _strengthRecord(
      recordId: 'record-preview-complete',
      trainingSessionId: 41,
      completedAt: DateTime.utc(2026, 9, 10, 10, 12),
      pullLoad: 12,
      includePress: true,
    ),
  ];
}

TrainingSessionRecord _strengthRecord({
  required String recordId,
  required int trainingSessionId,
  required DateTime completedAt,
  required double pullLoad,
  required bool includePress,
}) {
  TrainingExerciseResult exercise({
    required String id,
    required String name,
    required int position,
    required double load,
  }) {
    return TrainingExerciseResult(
      exerciseResultId: '$recordId-$id',
      blockResultId: '$recordId-s',
      sourceExerciseId: id,
      exerciseSnapshot: ExercisePerformanceSnapshot(
        sourceExerciseId: id,
        displayName: name,
        position: position,
        loadKind: StrengthActualLoadKind.external,
      ),
      position: position,
      setResults: [
        TrainingSetResult(
          setResultId: '$recordId-$id-1',
          exerciseResultId: '$recordId-$id',
          setNumber: 1,
          position: 1,
          reps: 6,
          load: load,
          loadUnit: 'kg',
          completed: true,
        ),
      ],
    );
  }

  final exercises = [
    exercise(
      id: 'EX-095',
      name: 'Weighted Pull-Up',
      position: 1,
      load: pullLoad,
    ),
    if (includePress)
      exercise(
        id: 'EX-136',
        name: 'Incline DB Press',
        position: 2,
        load: 22,
      ),
  ];
  return TrainingSessionRecord(
    recordId: recordId,
    athleteId: previewAthleteId,
    trainingSessionId: trainingSessionId,
    sourceProtocolId: 'BW-001',
    programmeId: 'APOLLO-V2',
    assignmentId: previewAssignmentId,
    status: TrainingSessionRecordStatus.completed,
    sessionSnapshot: SessionPerformanceSnapshot(
      sourceProtocolId: 'BW-001',
      sessionTitle: 'Apollo Strength',
      programmeTitle: 'Apollo Build — 12-Week Initial Block',
      blocks: [
        BlockPerformanceSnapshot(
          sourceBlockId: 'strength',
          title: 'Upper Strength',
          blockType: SessionBlockType.strength,
          content: '',
          workoutFormat: WorkoutFormat.none,
          position: 1,
          exercises: [
            for (final item in exercises) item.exerciseSnapshot,
          ],
        ),
      ],
    ),
    startedAt: completedAt.subtract(const Duration(hours: 1)),
    completedAt: completedAt,
    durationSeconds: 4320,
    overallRpe: 7,
    blockResults: [
      TrainingBlockResult(
        blockResultId: '$recordId-s',
        sessionRecordId: recordId,
        sourceBlockId: 'strength',
        blockSnapshot: BlockPerformanceSnapshot(
          sourceBlockId: 'strength',
          title: 'Upper Strength',
          blockType: SessionBlockType.strength,
          content: '',
          workoutFormat: WorkoutFormat.none,
          position: 1,
          exercises: [
            for (final item in exercises) item.exerciseSnapshot,
          ],
        ),
        status: TrainingBlockResultStatus.completed,
        resultType: PerformanceResultType.strength,
        position: 1,
        exerciseResults: exercises,
      ),
    ],
  );
}

class PreviewSessionLoader extends SessionExecutionLoader {
  @override
  Future<SessionExecutionLoadResult> load({
    required String protocolId,
    String? displayTitle,
    String? programmeContextLabel,
    Map<String, String> prescriptionLoadOverrides = const {},
  }) async {
    final strength = protocolId == 'BW-001';
    return SessionExecutionLoadResult(
      plan: SessionExecutionPlan(
        sessionId: protocolId,
        sessionTitle: displayTitle ??
            (strength ? 'Apollo Strength' : 'Apollo Intervals'),
        durationMin: strength ? 60 : 35,
        programmeContextLabel: programmeContextLabel,
        protocol: Protocol(
          protocolId: protocolId,
          name: displayTitle ??
              (strength ? 'Apollo Strength' : 'Apollo Intervals'),
          sessionType: strength ? 'Strength' : 'Run',
          environment: strength ? 'Gym' : 'Outdoor',
          goal: strength
              ? 'Upper-body strength and posterior-chain accessories'
              : 'Aerobic intervals',
          durationMin: strength ? 60 : 35,
        ),
        blocks: [
          SessionExecutionBlock(
            blockId: strength ? 'apollo-w1-upper-preview' : 'apollo-intervals',
            title: strength ? 'Upper Strength' : 'Intervals',
            blockType: strength
                ? SessionBlockType.strength
                : SessionBlockType.conditioning,
            content: '',
            workoutFormat: WorkoutFormat.none,
            position: 1,
            linkedExercises: strength
                ? const [
                    SessionExecutionExerciseSummary(
                      exerciseId: 'EX-095',
                      displayName: 'Weighted Pull-Up',
                      prescription: StrengthExercisePrescription(
                        sets: 4,
                        reps: StrengthRepPrescription(
                          type: StrengthRepType.range,
                          minReps: 5,
                          maxReps: 6,
                        ),
                      ),
                    ),
                    SessionExecutionExerciseSummary(
                      exerciseId: 'EX-136',
                      displayName: 'Incline DB Press',
                      prescription: StrengthExercisePrescription(
                        sets: 4,
                        reps: StrengthRepPrescription(
                          type: StrengthRepType.range,
                          minReps: 8,
                          maxReps: 10,
                        ),
                      ),
                    ),
                  ]
                : const [],
          ),
        ],
      ),
    );
  }
}
