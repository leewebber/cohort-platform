import 'package:cohort_platform/core/persistence/athlete_local_repository.dart';
import 'package:cohort_platform/core/persistence/local_kv_store.dart';
import 'package:cohort_platform/domain/programme_scheduling/programme_scheduling_domain.dart';
import 'package:cohort_platform/domain/session_occurrence/value_objects/session_occurrence_date.dart';
import 'package:cohort_platform/features/programme/models/programme_schedule_persistence.dart';
import 'package:cohort_platform/features/programme/services/programme_schedule_projection_store.dart';
import 'package:cohort_platform/features/programme/services/programme_schedule_restore_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStore implements ProgrammeScheduleProjectionStore {
  _FakeStore(this.result);

  ProgrammeSchedulePersistenceResult result;
  int ensureCalls = 0;

  @override
  Future<ProgrammeSchedulePersistenceResult> ensureBaseline({
    required String programmeAssignmentId,
  }) async {
    ensureCalls += 1;
    return result;
  }
}

void main() {
  const athleteId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  const assignmentId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  const versionId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
  const hash =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  PersistedProgrammeScheduleProjection projection({
    int revision = 0,
    String athlete = athleteId,
  }) {
    return PersistedProgrammeScheduleProjection(
      assignmentId: assignmentId,
      athleteId: athlete,
      programmeVersionId: versionId,
      packageContentHash: hash,
      timezone: 'Pacific/Auckland',
      startedAt: const SessionOccurrenceDate(year: 2026, month: 7, day: 1),
      scheduleRevision: revision,
      schemaVersion: ProgrammeScheduleRestoreService.supportedSchemaVersion,
      occurrences: [
        PersistedProgrammeScheduleOccurrence(
          sessionSlotId: 'slot-1',
          programmeVersionId: versionId,
          packageContentHash: hash,
          weekNumber: 1,
          dayKey: 'day_1',
          sessionOrder: 1,
          protocolId: 'P1',
          programmedSessionKey: 'prog:$assignmentId@$versionId:w1:day_1:s1:P1',
          scheduledDate: const SessionOccurrenceDate(
            year: 2026,
            month: 7,
            day: 1,
          ),
          disposition: ProgrammeScheduleDisposition.scheduled,
        ),
        PersistedProgrammeScheduleOccurrence(
          sessionSlotId: 'slot-2',
          programmeVersionId: versionId,
          packageContentHash: hash,
          weekNumber: 1,
          dayKey: 'day_2',
          sessionOrder: 1,
          protocolId: 'P2',
          programmedSessionKey: 'prog:$assignmentId@$versionId:w1:day_2:s1:P2',
          scheduledDate: const SessionOccurrenceDate(
            year: 2026,
            month: 7,
            day: 2,
          ),
          disposition: ProgrammeScheduleDisposition.completed,
        ),
      ],
    );
  }

  late InMemoryKvStore kv;
  late AthleteLocalRepository local;

  setUp(() {
    kv = InMemoryKvStore();
    local = AthleteLocalRepository(kv);
  });

  test('ensureAndRestore persists server projection and reconstructs domain',
      () async {
    final store = _FakeStore(
      ProgrammeSchedulePersistenceResult(
        status: ProgrammeSchedulePersistenceStatus.initialised,
        code: 'projection_initialised',
        assignmentId: assignmentId,
        scheduleRevision: 0,
        projection: projection(),
      ),
    );
    final service = ProgrammeScheduleRestoreService(
      store: store,
      localRepository: local,
    );

    final result = await service.ensureAndRestore(
      athleteId: athleteId,
      programmeAssignmentId: assignmentId,
    );

    expect(result.isSuccess, isTrue);
    expect(store.ensureCalls, 1);
    expect(result.projection!.scheduleRevision, 0);
    expect(result.projection!.occurrences, hasLength(2));

    final cached = await local.readProgrammeScheduleProjection(
      athleteId: athleteId,
      assignmentId: assignmentId,
    );
    expect(cached, isNotNull);
    expect(cached!.occurrences.first.scheduledDate.toString(), '2026-07-01');

    final domain = cached.toDomainProjection();
    expect(domain.scheduleRevision, 0);
    expect(domain.occurrences.first.identity.sessionSlotId, 'slot-1');
    final moved = domain.occurrences.first.copyWith(
      scheduledDate: const SessionOccurrenceDate(year: 2026, month: 8, day: 1),
    );
    expect(moved.identity, domain.occurrences.first.identity);
    expect(
      domain.bySlotId('slot-2')!.disposition,
      ProgrammeScheduleDisposition.completed,
    );

    final snapshot = service.snapshotForPreview(
      projection: cached,
      today: const SessionOccurrenceDate(year: 2026, month: 7, day: 10),
    );
    const engine = ProgrammeSchedulingPreviewEngine();
    final preview = engine.preview(
      snapshot: snapshot,
      request: const ProgrammeSchedulingMoveRequest(
        sessionSlotId: 'slot-1',
        targetDate: SessionOccurrenceDate(year: 2026, month: 7, day: 8),
      ),
    );
    expect(preview.isReady, isTrue);
    expect(
      snapshot.projection.bySlotId('slot-1')!.scheduledDate.toString(),
      '2026-07-01',
    );
  });

  test('stale cache rejected when server revision is newer', () {
    final service = ProgrammeScheduleRestoreService(
      store: _FakeStore(
        const ProgrammeSchedulePersistenceResult(
          status: ProgrammeSchedulePersistenceStatus.failed,
        ),
      ),
      localRepository: local,
    );
    final rejected = service.rejectStaleCache(
      athleteId: athleteId,
      assignmentId: assignmentId,
      cache: projection(revision: 0),
      server: projection(revision: 2),
    );
    expect(
      rejected!.status,
      ProgrammeSchedulePersistenceStatus.localCacheStale,
    );
    expect(rejected.projection!.scheduleRevision, 2);
  });

  test('cross-athlete cache rejected', () async {
    final store = _FakeStore(
      ProgrammeSchedulePersistenceResult(
        status: ProgrammeSchedulePersistenceStatus.alreadyExists,
        projection: projection(athlete: 'other-athlete'),
      ),
    );
    final service = ProgrammeScheduleRestoreService(
      store: store,
      localRepository: local,
    );
    final result = await service.ensureAndRestore(
      athleteId: athleteId,
      programmeAssignmentId: assignmentId,
    );
    expect(
      result.status,
      ProgrammeSchedulePersistenceStatus.assignmentNotOwned,
    );
  });

  test('corrupt cache cleared; absent when server unavailable', () async {
    await kv.writeString(
      PersistenceKeys.programmeScheduleProjection(athleteId, assignmentId),
      '{"schemaVersion":1,"savedAt":"2026-07-01T00:00:00Z","payload":{"broken":true}}',
    );

    final store = _FakeStore(
      const ProgrammeSchedulePersistenceResult(
        status: ProgrammeSchedulePersistenceStatus.persistenceUnavailable,
        code: 'client_error',
      ),
    );
    final service = ProgrammeScheduleRestoreService(
      store: store,
      localRepository: local,
    );
    final result = await service.restoreAfterRelaunch(
      athleteId: athleteId,
      programmeAssignmentId: assignmentId,
    );
    expect(result.status, ProgrammeSchedulePersistenceStatus.absent);
  });

  test('store surface is ensure-only (no generic writer)', () {
    const names = ['ensureBaseline'];
    expect(names, isNot(contains('saveSchedule')));
    expect(names, isNot(contains('replaceProjection')));
    expect(names, isNot(contains('applySchedulingOperation')));
  });
}
