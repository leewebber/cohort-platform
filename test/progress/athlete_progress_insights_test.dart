import 'package:cohort_platform/data/repositories/programme_assignment_store.dart';
import 'package:cohort_platform/features/performance/models/performance_result_type.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:cohort_platform/features/performance/models/performance_snapshot.dart';
import 'package:cohort_platform/features/performance/models/training_block_result_status.dart';
import 'package:cohort_platform/features/performance/models/training_session_record.dart';
import 'package:cohort_platform/features/performance/models/training_session_record_status.dart';
import 'package:cohort_platform/features/performance/repositories/in_memory_performance_record_store.dart';
import 'package:cohort_platform/features/progress/screens/progress_screen.dart';
import 'package:cohort_platform/features/progress/services/athlete_progress_evidence_projection.dart';
import 'package:cohort_platform/features/progress/services/athlete_progress_summary_builder.dart';
import 'package:cohort_platform/features/progress/services/capability_radar_projection_service.dart';
import 'package:cohort_platform/features/progress/widgets/capability_radar_chart.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('zero completed records leave bests empty', () {
    expect(AthleteProgressEvidenceProjection.exerciseBests(const []), isEmpty);
    expect(AthleteProgressEvidenceProjection.completedRecords(const []), isEmpty);
  });

  test('abandoned records are excluded', () {
    final abandoned = _record(
      recordId: 'abandoned',
      status: TrainingSessionRecordStatus.abandoned,
      pullLoad: 10,
    );
    expect(
      AthleteProgressEvidenceProjection.completedRecords([abandoned]),
      isEmpty,
    );
  });

  test('two strength sessions populate count and comparable bests', () {
    final first = _record(
      recordId: 'one',
      completedAt: DateTime.utc(2026, 9, 3),
      pullLoad: 10,
      includePress: false,
    );
    final second = _record(
      recordId: 'two',
      completedAt: DateTime.utc(2026, 9, 10),
      pullLoad: 12,
      includePress: true,
    );
    final completed = [first, second];
    expect(
      AthleteProgressEvidenceProjection.strengthSessionCount(completed),
      2,
    );
    final bests = AthleteProgressEvidenceProjection.exerciseBests(completed);
    expect(bests, hasLength(2));
    final pull = bests.firstWhere((best) => best.exerciseId == 'EX-095');
    expect(pull.comparisonImproved, isTrue);
    expect(pull.isFirstRecorded, isFalse);
    final press = bests.firstWhere((best) => best.exerciseId == 'EX-136');
    expect(press.isFirstRecorded, isTrue);
    expect(press.comparisonImproved, isFalse);
  });

  test('two strength sessions fill Strength participation without claiming improvement', () {
    const service = CapabilityRadarProjectionService();
    final radar = service.project(
      timeline: const [],
      strengthSessionCount: 2,
      enduranceSessionCount: 0,
    );
    final strength = radar.axes.firstWhere(
      (axis) => axis.dimension == CapabilityRadarDimension.strength,
    );
    final endurance = radar.axes.firstWhere(
      (axis) => axis.dimension == CapabilityRadarDimension.endurance,
    );
    expect(strength.available, isTrue);
    expect(strength.normalisedValue, closeTo(0.34, 0.001));
    expect(endurance.available, isFalse);
    expect(service.metricCards(timeline: const []), isEmpty);
  });

  testWidgets('Progress structure renders with zero data', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProgressScreen(
          summary: AthleteProgressSummaryBuilder.emptySummary(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CapabilityRadarChart), findsOneWidget);
    expect(find.text('0 sessions completed'), findsOneWidget);
    expect(find.text('Complete your first session to begin'), findsWidgets);
    expect(find.text('Awaiting evidence'), findsWidgets);
    expect(find.textContaining('trends'), findsNothing);
  });

  testWidgets('completed sessions populate Progress independently of fixtures', (
    tester,
  ) async {
    final store = InMemoryPerformanceRecordStore()
      ..put(
        _record(
          recordId: 'one',
          completedAt: DateTime.utc(2026, 9, 3),
          pullLoad: 10,
        ),
      )
      ..put(
        _record(
          recordId: 'two',
          completedAt: DateTime.utc(2026, 9, 10),
          pullLoad: 12,
          includePress: true,
        ),
      );
    final builder = AthleteProgressSummaryBuilder(
      assignmentStore: const _EmptyAssignmentStore(),
      performanceRecordStore: store,
    );
    final summary = await builder.build(athleteId: 'athlete-1');
    expect(summary.sessionsCompleted, 2);

    await tester.pumpWidget(MaterialApp(home: ProgressScreen(summary: summary)));
    await tester.pump();
    expect(find.text('2 sessions completed'), findsOneWidget);
    expect(find.text('Weighted Pull-Up'), findsWidgets);
    expect(find.text('First recorded performance'), findsOneWidget);
    expect(find.textContaining('Improved compared'), findsWidgets);
  });
}

class _EmptyAssignmentStore implements ProgrammeAssignmentStore {
  const _EmptyAssignmentStore();

  @override
  Future<ProgrammeAssignment?> getActiveAssignment(String athleteId) async =>
      null;

  @override
  Future<ProgrammeAssignment?> getById(String assignmentId) async => null;

  @override
  Future<ProgrammeAssignment> insert(ProgrammeAssignment assignment) {
    throw UnsupportedError('read-only');
  }

  @override
  Future<ProgrammeAssignment> update(ProgrammeAssignment assignment) {
    throw UnsupportedError('read-only');
  }

  @override
  Future<List<ProgrammeAssignment>> listForAthlete(String athleteId) async =>
      const [];

  @override
  Future<int> countAssignmentsForVersion(String programmeVersionId) async => 0;
}

TrainingSessionRecord _record({
  required String recordId,
  required double pullLoad,
  DateTime? completedAt,
  TrainingSessionRecordStatus status = TrainingSessionRecordStatus.completed,
  bool includePress = false,
}) {
  final at = completedAt ?? DateTime.utc(2026, 9, 10);
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
    exercise(id: 'EX-095', name: 'Weighted Pull-Up', position: 1, load: pullLoad),
    if (includePress)
      exercise(id: 'EX-136', name: 'Incline DB Press', position: 2, load: 22),
  ];
  return TrainingSessionRecord(
    recordId: recordId,
    athleteId: 'athlete-1',
    trainingSessionId: 41,
    sourceProtocolId: 'BW-001',
    status: status,
    sessionSnapshot: SessionPerformanceSnapshot(
      sourceProtocolId: 'BW-001',
      sessionTitle: 'Apollo Strength',
      blocks: [
        BlockPerformanceSnapshot(
          sourceBlockId: 'strength',
          title: 'Upper Strength',
          blockType: SessionBlockType.strength,
          content: '',
          workoutFormat: WorkoutFormat.none,
          position: 1,
          exercises: [for (final item in exercises) item.exerciseSnapshot],
        ),
      ],
    ),
    startedAt: at.subtract(const Duration(hours: 1)),
    completedAt: at,
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
          exercises: [for (final item in exercises) item.exerciseSnapshot],
        ),
        status: TrainingBlockResultStatus.completed,
        resultType: PerformanceResultType.strength,
        position: 1,
        exerciseResults: exercises,
      ),
    ],
  );
}
