import 'package:cohort_platform/features/performance/models/previous_strength_performance.dart';
import 'package:cohort_platform/features/performance/models/session_result_entry_mode.dart';
import 'package:cohort_platform/features/performance/models/training_session_record_status.dart';
import 'package:cohort_platform/features/performance/services/previous_strength_performance_selector.dart';
import 'package:cohort_platform/features/performance/services/previous_strength_performance_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(PreviousStrengthPerformanceCache.clear);

  PreviousStrengthCandidate week1({
    String athleteId = 'lee',
    String recordId = '5981c74a-aa66-42f5-aed4-1a4538a6d616',
    DateTime? startedAt,
    TrainingSessionRecordStatus status = TrainingSessionRecordStatus.completed,
  }) {
    return PreviousStrengthCandidate(
      recordId: recordId,
      athleteId: athleteId,
      status: status,
      startedAt: startedAt ?? DateTime.utc(2026, 9, 7, 15, 37),
      completedAt: DateTime.utc(2026, 9, 10, 14, 20),
      exercises: const [
        PreviousStrengthCandidateExercise(
          exerciseId: 'EX-095',
          sets: [
            PreviousStrengthSetEvidence(setNumber: 1, reps: 5, load: 10, loadUnit: 'kg'),
            PreviousStrengthSetEvidence(setNumber: 2, reps: 5, load: 15, loadUnit: 'kg'),
            PreviousStrengthSetEvidence(setNumber: 3, reps: 5, load: 20, loadUnit: 'kg'),
            PreviousStrengthSetEvidence(setNumber: 4, reps: 8, load: 15, loadUnit: 'kg'),
          ],
        ),
        PreviousStrengthCandidateExercise(
          exerciseId: 'EX-136',
          sets: [
            PreviousStrengthSetEvidence(setNumber: 1, reps: 8, load: 70, loadUnit: 'kg'),
            PreviousStrengthSetEvidence(setNumber: 2, reps: 6, load: 70, loadUnit: 'kg'),
            PreviousStrengthSetEvidence(setNumber: 3, reps: 4, load: 70, loadUnit: 'kg'),
            PreviousStrengthSetEvidence(setNumber: 4, reps: 6, load: 70, loadUnit: 'kg'),
          ],
        ),
        PreviousStrengthCandidateExercise(
          exerciseId: 'EX-138',
          sets: [
            PreviousStrengthSetEvidence(setNumber: 1, reps: 15, load: 10, loadUnit: 'kg'),
            PreviousStrengthSetEvidence(setNumber: 2, reps: 15, load: 10, loadUnit: 'kg'),
            PreviousStrengthSetEvidence(setNumber: 3, reps: 5, load: 10, loadUnit: 'kg'),
          ],
        ),
      ],
    );
  }

  test('Apollo Week 2 Day 1 finds Week 1 same-exercise evidence', () {
    final selected = PreviousStrengthPerformanceSelector.selectLatest(
      athleteId: 'lee',
      exerciseIds: const ['EX-095', 'EX-136', 'EX-138', 'EX-999'],
      candidates: [week1()],
      excludeRecordId: '297d8f36-013a-49df-a5a6-e9ac0c1cd203',
      currentChronologyAt: DateTime.utc(2026, 9, 14, 8, 43),
    );
    expect(selected['EX-095']!.sets, hasLength(4));
    expect(selected['EX-095']!.sets.last.load, 15);
    expect(selected['EX-136']!.sets.first.load, 70);
    expect(selected['EX-138']!.completedSetCount, 3);
    expect(selected.containsKey('EX-999'), isFalse);
  });

  test('canonical exercise ID is the primary match, not session title or week', () {
    final selected = PreviousStrengthPerformanceSelector.selectLatest(
      athleteId: 'lee',
      exerciseIds: const ['EX-095'],
      candidates: [week1()],
    );
    expect(selected['EX-095']!.recordId, startsWith('5981c74a'));
  });

  test('in-progress and abandoned evidence is excluded', () {
    final selected = PreviousStrengthPerformanceSelector.selectLatest(
      athleteId: 'lee',
      exerciseIds: const ['EX-095'],
      candidates: [
        week1(
          recordId: 'open',
          status: TrainingSessionRecordStatus.inProgress,
        ),
        week1(
          recordId: 'abandoned',
          status: TrainingSessionRecordStatus.abandoned,
        ),
      ],
    );
    expect(selected, isEmpty);
  });

  test('partially completed session exposes only completed sets', () {
    final selected = PreviousStrengthPerformanceSelector.selectLatest(
      athleteId: 'lee',
      exerciseIds: const ['EX-095', 'EX-136'],
      candidates: [
        PreviousStrengthCandidate(
          recordId: 'partial',
          athleteId: 'lee',
          status: TrainingSessionRecordStatus.partiallyCompleted,
          startedAt: DateTime.utc(2026, 9, 1),
          exercises: const [
            PreviousStrengthCandidateExercise(
              exerciseId: 'EX-095',
              sets: [
                PreviousStrengthSetEvidence(setNumber: 1, reps: 5, load: 10),
              ],
            ),
            PreviousStrengthCandidateExercise(
              exerciseId: 'EX-136',
              sets: [PreviousStrengthSetEvidence(setNumber: 1)],
            ),
          ],
        ),
      ],
    );
    expect(selected['EX-095']!.completedSetCount, 1);
    expect(selected.containsKey('EX-136'), isFalse);
  });

  test('current session excludes itself', () {
    final selected = PreviousStrengthPerformanceSelector.selectLatest(
      athleteId: 'lee',
      exerciseIds: const ['EX-095'],
      candidates: [week1(recordId: 'current')],
      excludeRecordId: 'current',
    );
    expect(selected, isEmpty);
  });

  test('athlete isolation', () {
    final selected = PreviousStrengthPerformanceSelector.selectLatest(
      athleteId: 'lee',
      exerciseIds: const ['EX-095'],
      candidates: [week1(athleteId: 'other')],
    );
    expect(selected, isEmpty);
  });

  test('older Backfill does not become latest because it was entered later', () {
    final live = week1();
    final olderBackfill = PreviousStrengthCandidate(
      recordId: 'backfill-old',
      athleteId: 'lee',
      status: TrainingSessionRecordStatus.completed,
      startedAt: DateTime.utc(2026, 9, 13, 12),
      performedOn: DateTime.utc(2026, 8, 1),
      entryMode: SessionResultEntryMode.backfill,
      exercises: const [
        PreviousStrengthCandidateExercise(
          exerciseId: 'EX-095',
          sets: [
            PreviousStrengthSetEvidence(setNumber: 1, reps: 3, load: 99),
          ],
        ),
      ],
    );
    final selected = PreviousStrengthPerformanceSelector.selectLatest(
      athleteId: 'lee',
      exerciseIds: const ['EX-095'],
      candidates: [olderBackfill, live],
      currentChronologyAt: DateTime.utc(2026, 9, 14),
    );
    expect(selected['EX-095']!.recordId, live.recordId);
    expect(selected['EX-095']!.sets.last.load, 15);
  });

  test('changed set count maps positionally without fabricating extras', () {
    final evidence = PreviousStrengthPerformanceSelector.selectLatest(
      athleteId: 'lee',
      exerciseIds: const ['EX-138'],
      candidates: [week1()],
    )['EX-138']!;
    expect(evidence.setForNumber(1)!.ghostLine, contains('10 kg'));
    expect(evidence.setForNumber(4), isNull);
    expect(evidence.completedSetCount, 3);
  });

  test('variants remain distinct', () {
    final selected = PreviousStrengthPerformanceSelector.selectLatest(
      athleteId: 'lee',
      exerciseIds: const ['EX-073'],
      candidates: [week1()],
    );
    expect(selected.containsKey('EX-073'), isFalse);
  });

  test('cached empty result invalidates after write', () async {
    final store = InMemoryPreviousStrengthPerformanceStore([]);
    final service = PreviousStrengthPerformanceService(store: store);
    final first = await service.latestForExercises(
      athleteId: 'lee',
      exerciseIds: const ['EX-095'],
    );
    expect(first, isEmpty);
    expect(store.loadCount, 1);
    await service.latestForExercises(
      athleteId: 'lee',
      exerciseIds: const ['EX-095'],
    );
    expect(store.loadCount, 1);
    PreviousStrengthPerformanceService.invalidateAfterWrite('lee');
    store.candidates.add(week1());
    final after = await service.latestForExercises(
      athleteId: 'lee',
      exerciseIds: const ['EX-095'],
    );
    expect(after['EX-095'], isNotNull);
    expect(store.loadCount, 2);
  });

  test('redundant parent lifecycle lag does not erase valid record evidence', () {
    final selected = PreviousStrengthPerformanceSelector.selectLatest(
      athleteId: 'lee',
      exerciseIds: const ['EX-095'],
      candidates: [week1()],
    );
    expect(selected['EX-095'], isNotNull);
  });

  test('protocol-step and block identity are not required to match', () {
    final selected = PreviousStrengthPerformanceSelector.selectLatest(
      athleteId: 'lee',
      exerciseIds: const ['EX-095'],
      candidates: [week1()],
    );
    expect(selected['EX-095']!.exerciseId, 'EX-095');
  });

  test('batched store is not N+1 per exercise', () async {
    final store = InMemoryPreviousStrengthPerformanceStore([week1()]);
    final service = PreviousStrengthPerformanceService(store: store);
    await service.latestForExercises(
      athleteId: 'lee',
      exerciseIds: const ['EX-095', 'EX-136', 'EX-138'],
    );
    expect(store.loadCount, 1);
  });
}
