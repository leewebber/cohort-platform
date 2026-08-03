import 'package:cohort_platform/core/persistence/athlete_local_repository.dart';
import 'package:cohort_platform/core/persistence/local_kv_store.dart';
import 'package:cohort_platform/domain/programme_scheduling/programme_scheduling_domain.dart';
import 'package:cohort_platform/domain/session_occurrence/value_objects/session_occurrence_date.dart';
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
  final startedAt = SessionOccurrenceDate(year: 2026, month: 7, day: 1);

  PersistedProgrammeScheduleProjection persisted({
    int revision = 3,
    SessionOccurrenceDate? date0,
    SessionOccurrenceDate? date1,
  }) {
    return PersistedProgrammeScheduleProjection(
      assignmentId: assignmentId,
      athleteId: athleteId,
      programmeVersionId: versionId,
      packageContentHash: packageHash,
      timezone: 'Pacific/Auckland',
      startedAt: startedAt,
      scheduleRevision: revision,
      schemaVersion: ProgrammeScheduleRestoreService.supportedSchemaVersion,
      occurrences: [
        PersistedProgrammeScheduleOccurrence(
          sessionSlotId: 'slot-1',
          programmeVersionId: versionId,
          packageContentHash: packageHash,
          weekNumber: 1,
          dayKey: 'day_1',
          sessionOrder: 0,
          protocolId: 'protocol-1',
          programmedSessionKey: 'psk-1',
          scheduledDate:
              date0 ?? const SessionOccurrenceDate(year: 2026, month: 7, day: 1),
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
          scheduledDate:
              date1 ?? const SessionOccurrenceDate(year: 2026, month: 7, day: 2),
          disposition: ProgrammeScheduleDisposition.scheduled,
        ),
      ],
    );
  }

  ProgrammeSchedulingSnapshot snapshotFrom(PersistedProgrammeScheduleProjection p) {
    return p.toSchedulingSnapshot(
      today: SessionOccurrenceDate(year: 2026, month: 7, day: 10),
    );
  }

  group('ProgrammeScheduleApplyService', () {
    test('command envelope excludes proposed projection fields', () {
      final command = ProgrammeScheduleMoveCommand(
        assignmentId: assignmentId,
        programmeVersionId: versionId,
        packageContentHash: packageHash,
        expectedScheduleRevision: 3,
        previewFingerprint: 'abc',
        idempotencyKey: 'idem-1',
        sessionSlotId: 'slot-1',
        targetDate: SessionOccurrenceDate(year: 2026, month: 7, day: 5),
      );
      final payload = command.toRpcPayload();
      expect(payload.containsKey('projection'), isFalse);
      expect(payload.containsKey('affected'), isFalse);
      expect(payload.containsKey('impacts'), isFalse);
      expect(payload['operation_type'], 'move');
      expect(payload['session_slot_id'], 'slot-1');
      expect(payload['expected_schedule_revision'], 3);
    });

    test('successful apply persists server projection and supersedes cache', () async {
      final local = AthleteLocalRepository(InMemoryKvStore());
      await local.saveProgrammeScheduleProjection(
        athleteId: athleteId,
        projection: persisted(revision: 3),
      );

      final applied = persisted(
        revision: 4,
        date0: const SessionOccurrenceDate(year: 2026, month: 7, day: 5),
      );
      final store = _FakeApplyStore(
        ProgrammeScheduleApplyResult(
          status: ProgrammeScheduleApplyStatus.applied,
          code: 'applied',
          assignmentId: assignmentId,
          scheduleRevision: 4,
          clearedProgrammedSessionKeys: const ['psk-1'],
          projection: applied,
        ),
      );
      final restore = ProgrammeScheduleRestoreService(
        store: _FakeProjectionStore(),
        localRepository: local,
      );
      final service = ProgrammeScheduleApplyService(
        applyStore: store,
        restoreService: restore,
        localRepository: local,
      );

      final snap = snapshotFrom(persisted());
      final engine = const ProgrammeSchedulingPreviewEngine();
      final preview = engine.preview(
        snapshot: snap,
        request: ProgrammeSchedulingMoveRequest(
          sessionSlotId: 'slot-1',
          targetDate: SessionOccurrenceDate(year: 2026, month: 7, day: 5),
        ),
      );
      expect(preview.isReady, isTrue);
      final command = service.moveCommandFromPreview(
        snapshot: snap,
        request: ProgrammeSchedulingMoveRequest(
          sessionSlotId: 'slot-1',
          targetDate: SessionOccurrenceDate(year: 2026, month: 7, day: 5),
        ),
        preview: preview.preview!,
        idempotencyKey: 'idem-success',
      )!;

      final result = await service.confirmApply(
        athleteId: athleteId,
        command: command,
      );
      expect(result.isSuccess, isTrue);

      final cached = await local.readProgrammeScheduleProjection(
        athleteId: athleteId,
        assignmentId: assignmentId,
      );
      expect(cached?.scheduleRevision, 4);
      expect(cached?.occurrences.first.scheduledDate.toString(), '2026-07-05');
    });

    test('failed apply does not install proposed local state', () async {
      final local = AthleteLocalRepository(InMemoryKvStore());
      final original = persisted(revision: 3);
      await local.saveProgrammeScheduleProjection(
        athleteId: athleteId,
        projection: original,
      );

      final store = _FakeApplyStore(
        const ProgrammeScheduleApplyResult(
          status: ProgrammeScheduleApplyStatus.stalePreviewFingerprint,
          code: 'stale_preview_fingerprint',
        ),
      );
      final restoreCalls = <String>[];
      final restore = ProgrammeScheduleRestoreService(
        store: _FakeProjectionStore(
          onEnsure: () {
            restoreCalls.add('ensure');
            return ProgrammeSchedulePersistenceResult(
              status: ProgrammeSchedulePersistenceStatus.alreadyExists,
              code: 'already_exists',
              projection: original,
              assignmentId: assignmentId,
              scheduleRevision: 3,
              source: ProgrammeSchedulePersistenceSource.server,
            );
          },
        ),
        localRepository: local,
      );
      final service = ProgrammeScheduleApplyService(
        applyStore: store,
        restoreService: restore,
        localRepository: local,
      );

      final result = await service.confirmApply(
        athleteId: athleteId,
        command: ProgrammeScheduleMoveCommand(
          assignmentId: assignmentId,
          programmeVersionId: versionId,
          packageContentHash: packageHash,
          expectedScheduleRevision: 3,
          previewFingerprint: 'stale',
          idempotencyKey: 'idem-fail',
          sessionSlotId: 'slot-1',
          targetDate: SessionOccurrenceDate(year: 2026, month: 7, day: 5),
        ),
      );
      expect(result.status, ProgrammeScheduleApplyStatus.stalePreviewFingerprint);
      expect(restoreCalls, isNotEmpty);

      final cached = await local.readProgrammeScheduleProjection(
        athleteId: athleteId,
        assignmentId: assignmentId,
      );
      expect(cached?.scheduleRevision, 3);
      expect(cached?.occurrences.first.scheduledDate.toString(), '2026-07-01');
    });

    test('push/skip command envelopes exclude client-nominated mutation fields', () {
      final push = ProgrammeSchedulePushCommand(
        assignmentId: assignmentId,
        programmeVersionId: versionId,
        packageContentHash: packageHash,
        expectedScheduleRevision: 3,
        previewFingerprint: 'push-fp',
        idempotencyKey: 'idem-push',
        fromSessionSlotId: 'slot-1',
        dayDelta: 2,
      );
      final pushPayload = push.toRpcPayload();
      expect(pushPayload['operation_type'], 'push');
      expect(pushPayload['session_slot_id'], 'slot-1');
      expect(pushPayload['day_delta'], 2);
      expect(pushPayload.containsKey('affected'), isFalse);
      expect(pushPayload.containsKey('cursor_after'), isFalse);
      expect(pushPayload.containsKey('projection'), isFalse);

      final skip = ProgrammeScheduleSkipCommand(
        assignmentId: assignmentId,
        programmeVersionId: versionId,
        packageContentHash: packageHash,
        expectedScheduleRevision: 3,
        previewFingerprint: 'skip-fp',
        idempotencyKey: 'idem-skip',
        sessionSlotId: 'slot-1',
      );
      final skipPayload = skip.toRpcPayload();
      expect(skipPayload['operation_type'], 'skip');
      expect(skipPayload['session_slot_id'], 'slot-1');
      expect(skipPayload.containsKey('cursor_after'), isFalse);
      expect(skipPayload.containsKey('resulting_disposition'), isFalse);
      expect(skipPayload.containsKey('affected'), isFalse);
    });

    test('push/skip command builders bind preview fingerprint and revision', () {
      final base = snapshotFrom(persisted(revision: 7));
      final snap = ProgrammeSchedulingSnapshot(
        assignmentId: base.assignmentId,
        programmeVersionId: base.programmeVersionId,
        packageContentHash: base.packageContentHash,
        timezone: base.timezone,
        startedAt: base.startedAt,
        today: base.today,
        assignmentStatus: base.assignmentStatus,
        projection: base.projection,
        cursorSessionSlotId: 'slot-1',
      );
      final service = ProgrammeScheduleApplyService(
        applyStore: _FakeApplyStore(
          const ProgrammeScheduleApplyResult(
            status: ProgrammeScheduleApplyStatus.failed,
          ),
        ),
        restoreService: ProgrammeScheduleRestoreService(
          store: _FakeProjectionStore(),
          localRepository: AthleteLocalRepository(InMemoryKvStore()),
        ),
        localRepository: AthleteLocalRepository(InMemoryKvStore()),
      );
      final pushPreview = const ProgrammeSchedulingPreviewEngine().preview(
        snapshot: snap,
        request: const ProgrammeSchedulingPushRequest(
          fromSessionSlotId: 'slot-1',
          dayDelta: 1,
        ),
      );
      expect(pushPreview.isReady, isTrue);
      final pushCommand = service.pushCommandFromPreview(
        snapshot: snap,
        request: const ProgrammeSchedulingPushRequest(
          fromSessionSlotId: 'slot-1',
          dayDelta: 1,
        ),
        preview: pushPreview.preview!,
        idempotencyKey: 'push-key',
      )!;
      expect(pushCommand.expectedScheduleRevision, 7);
      expect(pushCommand.previewFingerprint, pushPreview.preview!.fingerprint);
      expect(pushCommand.dayDelta, 1);

      final skipPreview = const ProgrammeSchedulingPreviewEngine().preview(
        snapshot: snap,
        request: const ProgrammeSchedulingSkipRequest(sessionSlotId: 'slot-1'),
      );
      expect(skipPreview.isReady, isTrue);
      final skipCommand = service.skipCommandFromPreview(
        snapshot: snap,
        request: const ProgrammeSchedulingSkipRequest(sessionSlotId: 'slot-1'),
        preview: skipPreview.preview!,
        idempotencyKey: 'skip-key',
      )!;
      expect(skipCommand.expectedScheduleRevision, 7);
      expect(skipCommand.previewFingerprint, skipPreview.preview!.fingerprint);
      expect(skipCommand.sessionSlotId, 'slot-1');
    });

    test('move/swap command builders bind preview fingerprint and revision', () {
      final snap = snapshotFrom(persisted(revision: 7));
      final service = ProgrammeScheduleApplyService(
        applyStore: _FakeApplyStore(
          const ProgrammeScheduleApplyResult(
            status: ProgrammeScheduleApplyStatus.failed,
          ),
        ),
        restoreService: ProgrammeScheduleRestoreService(
          store: _FakeProjectionStore(),
          localRepository: AthleteLocalRepository(InMemoryKvStore()),
        ),
        localRepository: AthleteLocalRepository(InMemoryKvStore()),
      );
      final preview = const ProgrammeSchedulingPreviewEngine().preview(
        snapshot: snap,
        request: ProgrammeSchedulingSwapRequest(
          sessionSlotIdA: 'slot-1',
          sessionSlotIdB: 'slot-2',
        ),
      );
      final command = service.swapCommandFromPreview(
        snapshot: snap,
        request: const ProgrammeSchedulingSwapRequest(
          sessionSlotIdA: 'slot-1',
          sessionSlotIdB: 'slot-2',
        ),
        preview: preview.preview!,
        idempotencyKey: 'fixed-key',
      )!;
      expect(command.expectedScheduleRevision, 7);
      expect(command.previewFingerprint, preview.preview!.fingerprint);
      expect(command.idempotencyKey, 'fixed-key');
    });
  });
}

class _FakeApplyStore implements ProgrammeScheduleApplyStore {
  _FakeApplyStore(this.result);
  final ProgrammeScheduleApplyResult result;

  @override
  Future<ProgrammeScheduleApplyResult> apply(
    ProgrammeScheduleApplyCommand command,
  ) async =>
      result;
}

class _FakeProjectionStore implements ProgrammeScheduleProjectionStore {
  _FakeProjectionStore({this.onEnsure});

  final ProgrammeSchedulePersistenceResult Function()? onEnsure;

  @override
  Future<ProgrammeSchedulePersistenceResult> ensureBaseline({
    required String programmeAssignmentId,
  }) async {
    if (onEnsure != null) return onEnsure!();
    return const ProgrammeSchedulePersistenceResult(
      status: ProgrammeSchedulePersistenceStatus.absent,
    );
  }
}
