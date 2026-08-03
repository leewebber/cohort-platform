import 'package:cohort_platform/core/persistence/athlete_local_repository.dart';
import 'package:cohort_platform/core/persistence/local_kv_store.dart';
import 'package:cohort_platform/domain/programme_scheduling/programme_scheduling_domain.dart';
import 'package:cohort_platform/domain/session_occurrence/value_objects/session_occurrence_date.dart';
import 'package:cohort_platform/features/programme/controllers/athlete_programme_schedule_controller.dart';
import 'package:cohort_platform/features/programme/models/programme_schedule_apply.dart';
import 'package:cohort_platform/features/programme/models/programme_schedule_persistence.dart';
import 'package:cohort_platform/features/programme/services/programme_schedule_apply_service.dart';
import 'package:cohort_platform/features/programme/services/programme_schedule_apply_store.dart';
import 'package:cohort_platform/features/programme/services/programme_schedule_projection_store.dart';
import 'package:cohort_platform/features/programme/services/programme_schedule_restore_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const athleteId = 'athlete-1';
  const assignmentId = 'assign-1';
  const versionId = 'version-1';
  const packageHash = 'pkg-hash-1';

  PersistedProgrammeScheduleProjection projection({int revision = 1}) {
    return PersistedProgrammeScheduleProjection(
      assignmentId: assignmentId,
      athleteId: athleteId,
      programmeVersionId: versionId,
      packageContentHash: packageHash,
      timezone: 'Pacific/Auckland',
      startedAt: const SessionOccurrenceDate(year: 2026, month: 7, day: 1),
      scheduleRevision: revision,
      schemaVersion: ProgrammeScheduleRestoreService.supportedSchemaVersion,
      occurrences: const [
        PersistedProgrammeScheduleOccurrence(
          sessionSlotId: 'slot-1',
          programmeVersionId: versionId,
          packageContentHash: packageHash,
          weekNumber: 1,
          dayKey: 'day_1',
          sessionOrder: 0,
          protocolId: 'protocol-1',
          programmedSessionKey: 'psk-1',
          scheduledDate: SessionOccurrenceDate(year: 2026, month: 7, day: 1),
          disposition: ProgrammeScheduleDisposition.scheduled,
        ),
        PersistedProgrammeScheduleOccurrence(
          sessionSlotId: 'slot-2',
          programmeVersionId: versionId,
          packageContentHash: packageHash,
          weekNumber: 1,
          dayKey: 'day_2',
          sessionOrder: 0,
          protocolId: 'protocol-2',
          programmedSessionKey: 'psk-2',
          scheduledDate: SessionOccurrenceDate(year: 2026, month: 7, day: 2),
          disposition: ProgrammeScheduleDisposition.scheduled,
        ),
      ],
    );
  }

  test('cancel clears preview without apply', () async {
    final local = AthleteLocalRepository(InMemoryKvStore());
    final applyStore = _RecordingApplyStore();
    final restore = ProgrammeScheduleRestoreService(
      store: _EnsureStore(projection()),
      localRepository: local,
    );
    final apply = ProgrammeScheduleApplyService(
      applyStore: applyStore,
      restoreService: restore,
      localRepository: local,
    );
    final controller = AthleteProgrammeScheduleController(
      athleteId: athleteId,
      assignmentId: assignmentId,
      restoreService: restore,
      applyService: apply,
    );

    await controller.load();
    await controller.previewMove(
      sessionSlotId: 'slot-1',
      targetDate: const SessionOccurrenceDate(year: 2026, month: 7, day: 5),
    );
    expect(controller.preview, isNotNull);
    controller.cancelPreview();
    expect(controller.preview, isNull);
    expect(applyStore.calls, 0);
  });

  test('confirm sends displayed revision and fingerprint once', () async {
    final local = AthleteLocalRepository(InMemoryKvStore());
    final base = projection(revision: 2);
    final applyStore = _RecordingApplyStore(
      result: ProgrammeScheduleApplyResult(
        status: ProgrammeScheduleApplyStatus.applied,
        code: 'applied',
        assignmentId: assignmentId,
        scheduleRevision: 3,
        projection: projection(revision: 3).copyWithMovedSlot1(),
      ),
    );
    final restore = ProgrammeScheduleRestoreService(
      store: _EnsureStore(base),
      localRepository: local,
    );
    final apply = ProgrammeScheduleApplyService(
      applyStore: applyStore,
      restoreService: restore,
      localRepository: local,
    );
    final controller = AthleteProgrammeScheduleController(
      athleteId: athleteId,
      assignmentId: assignmentId,
      restoreService: restore,
      applyService: apply,
    );

    await controller.load();
    await controller.previewMove(
      sessionSlotId: 'slot-1',
      targetDate: const SessionOccurrenceDate(year: 2026, month: 7, day: 5),
    );
    final fingerprint = controller.preview!.fingerprint;
    final result = await controller.confirmPreview();
    expect(result?.isSuccess, isTrue);
    expect(applyStore.calls, 1);
    final command = applyStore.lastCommand!;
    expect(command.expectedScheduleRevision, 2);
    expect(command.previewFingerprint, fingerprint);

    // Double confirm after success has no pending preview.
    final second = await controller.confirmPreview();
    expect(second, isNull);
    expect(applyStore.calls, 1);
  });

  test('swap preview shows both exchanges', () async {
    final local = AthleteLocalRepository(InMemoryKvStore());
    final restore = ProgrammeScheduleRestoreService(
      store: _EnsureStore(projection()),
      localRepository: local,
    );
    final apply = ProgrammeScheduleApplyService(
      applyStore: _RecordingApplyStore(),
      restoreService: restore,
      localRepository: local,
    );
    final controller = AthleteProgrammeScheduleController(
      athleteId: athleteId,
      assignmentId: assignmentId,
      restoreService: restore,
      applyService: apply,
    );
    await controller.load();
    await controller.previewSwap(
      sessionSlotIdA: 'slot-1',
      sessionSlotIdB: 'slot-2',
    );
    expect(controller.preview?.changes, hasLength(2));
    expect(
      controller.preview!.changes.map((c) => c.proposedDate.toString()).toSet(),
      {'2026-07-01', '2026-07-02'},
    );
  });
}

class _EnsureStore implements ProgrammeScheduleProjectionStore {
  _EnsureStore(this.projection);
  final PersistedProgrammeScheduleProjection projection;

  @override
  Future<ProgrammeSchedulePersistenceResult> ensureBaseline({
    required String programmeAssignmentId,
  }) async {
    return ProgrammeSchedulePersistenceResult(
      status: ProgrammeSchedulePersistenceStatus.alreadyExists,
      code: 'already_exists',
      assignmentId: programmeAssignmentId,
      scheduleRevision: projection.scheduleRevision,
      projection: projection,
    );
  }
}

class _RecordingApplyStore implements ProgrammeScheduleApplyStore {
  _RecordingApplyStore({this.result});

  final ProgrammeScheduleApplyResult? result;
  int calls = 0;
  ProgrammeScheduleApplyCommand? lastCommand;

  @override
  Future<ProgrammeScheduleApplyResult> apply(
    ProgrammeScheduleApplyCommand command,
  ) async {
    calls += 1;
    lastCommand = command;
    return result ??
        const ProgrammeScheduleApplyResult(
          status: ProgrammeScheduleApplyStatus.failed,
        );
  }
}

extension on PersistedProgrammeScheduleProjection {
  PersistedProgrammeScheduleProjection copyWithMovedSlot1() {
    return PersistedProgrammeScheduleProjection(
      assignmentId: assignmentId,
      athleteId: athleteId,
      programmeVersionId: programmeVersionId,
      packageContentHash: packageContentHash,
      timezone: timezone,
      startedAt: startedAt,
      scheduleRevision: scheduleRevision,
      schemaVersion: schemaVersion,
      occurrences: [
        PersistedProgrammeScheduleOccurrence(
          sessionSlotId: occurrences[0].sessionSlotId,
          programmeVersionId: occurrences[0].programmeVersionId,
          packageContentHash: occurrences[0].packageContentHash,
          weekNumber: occurrences[0].weekNumber,
          dayKey: occurrences[0].dayKey,
          sessionOrder: occurrences[0].sessionOrder,
          protocolId: occurrences[0].protocolId,
          programmedSessionKey: occurrences[0].programmedSessionKey,
          scheduledDate: const SessionOccurrenceDate(
            year: 2026,
            month: 7,
            day: 5,
          ),
          disposition: occurrences[0].disposition,
        ),
        occurrences[1],
      ],
    );
  }
}
