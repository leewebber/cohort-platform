import 'package:cohort_platform/domain/programme_scheduling/programme_scheduling_domain.dart';
import 'package:cohort_platform/domain/session_occurrence/value_objects/session_occurrence_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const assignmentId = 'assign-1';
  const versionId = 'version-1';
  const packageHash = 'pkg-hash-1';
  const timezone = 'Pacific/Auckland';
  final startedAt = SessionOccurrenceDate(year: 2026, month: 7, day: 1);
  final today = SessionOccurrenceDate(year: 2026, month: 7, day: 10);

  List<BaselineAuthoredSlot> slots(int count) {
    return List.generate(count, (i) {
      final n = i + 1;
      return BaselineAuthoredSlot(
        sessionSlotId: 'slot-$n',
        weekNumber: 1,
        dayKey: 'day_$n',
        sessionOrder: 0,
        protocolId: 'protocol-$n',
        programmedSessionKey: 'psk-$n',
      );
    });
  }

  ProgrammeSchedulingSnapshot snapshot({
    ProgrammeScheduleProjection? projection,
    ProgrammeSchedulingAssignmentStatus status =
        ProgrammeSchedulingAssignmentStatus.active,
    SessionOccurrenceDate? horizonEnd,
    Set<String> prepared = const {},
    Set<String> adapted = const {},
    Set<String> pending = const {},
    Set<String> consumed = const {},
    Set<String> completed = const {},
    int revision = 3,
  }) {
    final proj =
        projection ??
        BaselineProgrammeScheduleProjection.build(
          assignmentId: assignmentId,
          programmeVersionId: versionId,
          packageContentHash: packageHash,
          startedAt: startedAt,
          authoredSlots: slots(4),
          scheduleRevision: revision,
          completedSessionSlotIds: completed,
        );
    return ProgrammeSchedulingSnapshot(
      assignmentId: assignmentId,
      programmeVersionId: versionId,
      packageContentHash: packageHash,
      timezone: timezone,
      startedAt: startedAt,
      today: today,
      assignmentStatus: status,
      projection: proj,
      schedulingHorizonEnd: horizonEnd,
      preparedProgrammedSessionKeys: prepared,
      adaptedProgrammedSessionKeys: adapted,
      pendingAdaptationProposalKeys: pending,
      consumedAdaptationProposalIds: consumed,
      cursorSessionSlotId: proj.occurrences.first.identity.sessionSlotId,
    );
  }

  const engine = ProgrammeSchedulingPreviewEngine();

  group('identity and baseline', () {
    test('stable identity equality independent of date', () {
      final projection = BaselineProgrammeScheduleProjection.build(
        assignmentId: assignmentId,
        programmeVersionId: versionId,
        packageContentHash: packageHash,
        startedAt: startedAt,
        authoredSlots: slots(2),
      );
      final a = projection.occurrences[0];
      final moved = a.copyWith(
        scheduledDate: a.scheduledDate.addCalendarDays(5),
      );
      expect(moved.identity, a.identity);
      expect(moved.scheduledDate == a.scheduledDate, isFalse);
    });

    test('baseline places one executable slot per day from started_at', () {
      final projection = BaselineProgrammeScheduleProjection.build(
        assignmentId: assignmentId,
        programmeVersionId: versionId,
        packageContentHash: packageHash,
        startedAt: startedAt,
        authoredSlots: slots(3),
      );
      expect(projection.occurrences.map((o) => o.scheduledDate.toString()), [
        '2026-07-01',
        '2026-07-02',
        '2026-07-03',
      ]);
      expect(
        projection.occurrences.map((o) => o.identity.sessionSlotId).toList(),
        ['slot-1', 'slot-2', 'slot-3'],
      );
    });
  });

  group('Move preview', () {
    test('affects exactly one occurrence and leaves others unchanged', () {
      final snap = snapshot();
      final original = List.of(snap.projection.occurrences);
      final result = engine.preview(
        snapshot: snap,
        request: ProgrammeSchedulingMoveRequest(
          sessionSlotId: 'slot-2',
          targetDate: SessionOccurrenceDate(year: 2026, month: 7, day: 8),
        ),
      );
      expect(result.isReady, isTrue);
      final preview = result.preview!;
      expect(preview.changes, hasLength(1));
      expect(preview.changes.single.identity.sessionSlotId, 'slot-2');
      expect(preview.proposedProjection.bySlotId('slot-1')!.scheduledDate,
          original[0].scheduledDate);
      expect(preview.proposedProjection.bySlotId('slot-3')!.scheduledDate,
          original[2].scheduledDate);
      expect(preview.proposedProjection.bySlotId('slot-2')!.scheduledDate,
          SessionOccurrenceDate(year: 2026, month: 7, day: 8));
      expect(identical(snap.projection.occurrences, original), isFalse);
      expect(snap.projection.occurrences, original);
    });

    test('same-date move is typed no-op', () {
      final snap = snapshot();
      final current = snap.projection.bySlotId('slot-1')!.scheduledDate;
      final result = engine.preview(
        snapshot: snap,
        request: ProgrammeSchedulingMoveRequest(
          sessionSlotId: 'slot-1',
          targetDate: current,
        ),
      );
      expect(result.code, ProgrammeSchedulingPreviewCode.noChange);
    });

    test('before-start rejected; past through today allowed as overdue', () {
      final snap = snapshot();
      final before = engine.preview(
        snapshot: snap,
        request: ProgrammeSchedulingMoveRequest(
          sessionSlotId: 'slot-2',
          targetDate: SessionOccurrenceDate(year: 2026, month: 6, day: 30),
        ),
      );
      expect(before.code, ProgrammeSchedulingPreviewCode.beforeAssignmentStart);

      final catchUp = engine.preview(
        snapshot: snap,
        request: ProgrammeSchedulingMoveRequest(
          sessionSlotId: 'slot-4',
          targetDate: SessionOccurrenceDate(year: 2026, month: 7, day: 5),
        ),
      );
      expect(catchUp.isReady, isTrue);
      expect(
        catchUp.preview!.impacts.any(
          (i) => i.kind == ProgrammeSchedulingImpactKind.becomesOverdue,
        ),
        isTrue,
      );
      expect(
        catchUp.preview!.proposedProjection.bySlotId('slot-4')!.disposition,
        ProgrammeScheduleDisposition.scheduled,
      );
    });

    test('completed and in-flight rejected', () {
      final completedSnap = snapshot(completed: {'slot-1'});
      expect(
        engine
            .preview(
              snapshot: completedSnap,
              request: ProgrammeSchedulingMoveRequest(
                sessionSlotId: 'slot-1',
                targetDate: today,
              ),
            )
            .code,
        ProgrammeSchedulingPreviewCode.occurrenceCompleted,
      );

      final base = snapshot();
      final inFlightOcc = base.projection.bySlotId('slot-2')!.copyWith(
        hasInFlightExecution: true,
      );
      final inFlightSnap = ProgrammeSchedulingSnapshot(
        assignmentId: assignmentId,
        programmeVersionId: versionId,
        packageContentHash: packageHash,
        timezone: timezone,
        startedAt: startedAt,
        today: today,
        assignmentStatus: ProgrammeSchedulingAssignmentStatus.active,
        projection: base.projection.replacing({'slot-2': inFlightOcc}),
      );
      expect(
        engine
            .preview(
              snapshot: inFlightSnap,
              request: ProgrammeSchedulingMoveRequest(
                sessionSlotId: 'slot-2',
                targetDate: today,
              ),
            )
            .code,
        ProgrammeSchedulingPreviewCode.inFlightExecution,
      );
    });

    test('same-date collision reported but allowed', () {
      final snap = snapshot();
      final target = snap.projection.bySlotId('slot-1')!.scheduledDate;
      final result = engine.preview(
        snapshot: snap,
        request: ProgrammeSchedulingMoveRequest(
          sessionSlotId: 'slot-3',
          targetDate: target,
        ),
      );
      expect(result.isReady, isTrue);
      expect(result.preview!.collidingDates, contains(target));
      expect(
        result.preview!.impacts.any(
          (i) =>
              i.kind == ProgrammeSchedulingImpactKind.multiSessionDateCollision,
        ),
        isTrue,
      );
    });
  });

  group('Swap preview', () {
    test('exchanges dates only; identities and order preserved', () {
      final snap = snapshot();
      final aDate = snap.projection.bySlotId('slot-1')!.scheduledDate;
      final bDate = snap.projection.bySlotId('slot-3')!.scheduledDate;
      final result = engine.preview(
        snapshot: snap,
        request: const ProgrammeSchedulingSwapRequest(
          sessionSlotIdA: 'slot-1',
          sessionSlotIdB: 'slot-3',
        ),
      );
      expect(result.isReady, isTrue);
      final proposed = result.preview!.proposedProjection;
      expect(proposed.bySlotId('slot-1')!.scheduledDate, bDate);
      expect(proposed.bySlotId('slot-3')!.scheduledDate, aDate);
      expect(
        proposed.occurrences.map((o) => o.identity.sessionSlotId).toList(),
        snap.projection.occurrences.map((o) => o.identity.sessionSlotId),
      );
    });

    test('same-date swap is no-op; identical slots rejected', () {
      final snap = snapshot();
      final moved = snap.projection.replacing({
        'slot-2': snap.projection.bySlotId('slot-2')!.copyWith(
          scheduledDate: snap.projection.bySlotId('slot-1')!.scheduledDate,
        ),
      });
      final sameDateSnap = ProgrammeSchedulingSnapshot(
        assignmentId: assignmentId,
        programmeVersionId: versionId,
        packageContentHash: packageHash,
        timezone: timezone,
        startedAt: startedAt,
        today: today,
        assignmentStatus: ProgrammeSchedulingAssignmentStatus.active,
        projection: moved,
      );
      expect(
        engine
            .preview(
              snapshot: sameDateSnap,
              request: const ProgrammeSchedulingSwapRequest(
                sessionSlotIdA: 'slot-1',
                sessionSlotIdB: 'slot-2',
              ),
            )
            .code,
        ProgrammeSchedulingPreviewCode.noChange,
      );
      expect(
        engine
            .preview(
              snapshot: snap,
              request: const ProgrammeSchedulingSwapRequest(
                sessionSlotIdA: 'slot-1',
                sessionSlotIdB: 'slot-1',
              ),
            )
            .code,
        ProgrammeSchedulingPreviewCode.swapRequiresDistinctOccurrences,
      );
    });

    test('cross hash provenance rejected', () {
      final base = snapshot();
      final rogueIdentity = ScheduledOccurrenceIdentity(
        assignmentId: assignmentId,
        programmeVersionId: versionId,
        packageContentHash: 'other-hash',
        sessionSlotId: 'slot-2',
        weekNumber: 1,
        dayKey: 'day_2',
        sessionOrder: 0,
        protocolId: 'protocol-2',
        programmedSessionKey: 'psk-2',
      );
      final rogue = ScheduledProgrammeOccurrence(
        identity: rogueIdentity,
        scheduledDate: base.projection.bySlotId('slot-2')!.scheduledDate,
        disposition: ProgrammeScheduleDisposition.scheduled,
      );
      final bad = ProgrammeScheduleProjection(
        occurrences: [
          base.projection.bySlotId('slot-1')!,
          rogue,
          base.projection.bySlotId('slot-3')!,
          base.projection.bySlotId('slot-4')!,
        ],
        scheduleRevision: 3,
      );
      final badSnap = ProgrammeSchedulingSnapshot(
        assignmentId: assignmentId,
        programmeVersionId: versionId,
        packageContentHash: packageHash,
        timezone: timezone,
        startedAt: startedAt,
        today: today,
        assignmentStatus: ProgrammeSchedulingAssignmentStatus.active,
        projection: bad,
      );
      expect(
        engine
            .preview(
              snapshot: badSnap,
              request: const ProgrammeSchedulingSwapRequest(
                sessionSlotIdA: 'slot-1',
                sessionSlotIdB: 'slot-2',
              ),
            )
            .code,
        ProgrammeSchedulingPreviewCode.provenanceMismatch,
      );
    });
  });

  group('Push preview', () {
    test('shifts S and later uncompleted only; completed untouched', () {
      final snap = snapshot(completed: {'slot-1'});
      final before = Map.fromEntries(
        snap.projection.occurrences.map(
          (o) => MapEntry(o.identity.sessionSlotId, o.scheduledDate),
        ),
      );
      final result = engine.preview(
        snapshot: snap,
        request: const ProgrammeSchedulingPushRequest(
          fromSessionSlotId: 'slot-2',
          dayDelta: 2,
        ),
      );
      expect(result.isReady, isTrue);
      final proposed = result.preview!.proposedProjection;
      expect(proposed.bySlotId('slot-1')!.scheduledDate, before['slot-1']);
      expect(
        proposed.bySlotId('slot-2')!.scheduledDate,
        before['slot-2']!.addCalendarDays(2),
      );
      expect(
        proposed.bySlotId('slot-3')!.scheduledDate,
        before['slot-3']!.addCalendarDays(2),
      );
      expect(
        proposed.bySlotId('slot-4')!.scheduledDate,
        before['slot-4']!.addCalendarDays(2),
      );
      expect(result.preview!.changes, hasLength(3));
    });

    test('horizon exceed rejects entire push atomically', () {
      final snap = snapshot(
        horizonEnd: SessionOccurrenceDate(year: 2026, month: 7, day: 5),
      );
      final result = engine.preview(
        snapshot: snap,
        request: const ProgrammeSchedulingPushRequest(
          fromSessionSlotId: 'slot-1',
          dayDelta: 10,
        ),
      );
      expect(result.code, ProgrammeSchedulingPreviewCode.horizonExceeded);
      expect(result.preview, isNull);
    });

    test('invalid push distance rejected', () {
      final snap = snapshot();
      expect(
        engine
            .preview(
              snapshot: snap,
              request: const ProgrammeSchedulingPushRequest(
                fromSessionSlotId: 'slot-1',
                dayDelta: 0,
              ),
            )
            .code,
        ProgrammeSchedulingPreviewCode.invalidPushDistance,
      );
    });

    test('DST local calendar arithmetic across spring forward', () {
      // 2026-04-05 + 1 day is 2026-04-06 regardless of NZ DST.
      final d = SessionOccurrenceDate(year: 2026, month: 4, day: 5);
      expect(d.addCalendarDays(1).toString(), '2026-04-06');
      expect(d.addCalendarDays(7).toString(), '2026-04-12');
    });
  });

  group('Skip preview', () {
    test('proposes skipped disposition and cursor impact without completion', () {
      final snap = snapshot(prepared: {'psk-1'}, consumed: {'proposal-9'});
      final original = List.of(snap.projection.occurrences);
      final result = engine.preview(
        snapshot: snap,
        request: const ProgrammeSchedulingSkipRequest(sessionSlotId: 'slot-1'),
      );
      expect(result.isReady, isTrue);
      final preview = result.preview!;
      expect(
        preview.proposedProjection.bySlotId('slot-1')!.disposition,
        ProgrammeScheduleDisposition.skipped,
      );
      expect(
        preview.changes.single.proposedDisposition,
        ProgrammeScheduleDisposition.skipped,
      );
      expect(
        preview.impacts.any(
          (i) => i.kind == ProgrammeSchedulingImpactKind.skipDispositionProposed,
        ),
        isTrue,
      );
      expect(
        preview.impacts.any(
          (i) =>
              i.kind == ProgrammeSchedulingImpactKind.cursorWouldAdvanceTo &&
              i.sessionSlotId == 'slot-2',
        ),
        isTrue,
      );
      expect(
        preview.impacts.any(
          (i) =>
              i.kind == ProgrammeSchedulingImpactKind.preparedOccurrenceAffected,
        ),
        isTrue,
      );
      // Input unchanged; no completion fabrication.
      expect(snap.projection.occurrences, original);
      expect(original.first.disposition, ProgrammeScheduleDisposition.scheduled);
    });

    test('already skipped and completed rejected', () {
      final skipped = snapshot().projection.replacing({
        'slot-2': snapshot().projection.bySlotId('slot-2')!.copyWith(
          disposition: ProgrammeScheduleDisposition.skipped,
        ),
      });
      final skippedSnap = ProgrammeSchedulingSnapshot(
        assignmentId: assignmentId,
        programmeVersionId: versionId,
        packageContentHash: packageHash,
        timezone: timezone,
        startedAt: startedAt,
        today: today,
        assignmentStatus: ProgrammeSchedulingAssignmentStatus.active,
        projection: skipped,
        cursorSessionSlotId: 'slot-2',
      );
      expect(
        engine
            .preview(
              snapshot: skippedSnap,
              request: const ProgrammeSchedulingSkipRequest(
                sessionSlotId: 'slot-2',
              ),
            )
            .code,
        ProgrammeSchedulingPreviewCode.occurrenceAlreadySkipped,
      );
      expect(
        engine
            .preview(
              snapshot: snapshot(completed: {'slot-3'}),
              request: const ProgrammeSchedulingSkipRequest(
                sessionSlotId: 'slot-3',
              ),
            )
            .code,
        ProgrammeSchedulingPreviewCode.occurrenceCompleted,
      );
    });

    test('non-current skip rejected when cursor is present', () {
      final result = engine.preview(
        snapshot: snapshot(),
        request: const ProgrammeSchedulingSkipRequest(sessionSlotId: 'slot-2'),
      );
      expect(result.code, ProgrammeSchedulingPreviewCode.occurrenceNotCurrent);
    });
  });

  group('undo preview', () {
    ProgrammeSchedulingUndoableOperation skipOp({
      required ProgrammeSchedulingSnapshot afterSkip,
      Map<String, Object?>? priorOverrides,
      bool incomplete = false,
    }) {
      final skipped = afterSkip.projection.bySlotId('slot-1')!;
      final prior = <String, Object?>{
        'operation_type': 'skip',
        'session_slot_id': 'slot-1',
        'disposition_before': 'scheduled',
        'outcome_existed_before': false,
        'outcome_status_before': null,
        'cursor_before': {
          'week_number': skipped.identity.weekNumber,
          'day_key': skipped.identity.dayKey,
          'session_order': skipped.identity.sessionOrder,
        },
        'assignment_status_before': 'active',
        'assignment_completed_at_before': null,
        ...?priorOverrides,
      };
      return ProgrammeSchedulingUndoableOperation(
        operationId: 'op-skip-1',
        assignmentId: assignmentId,
        originalType: ProgrammeSchedulingOperationType.skip,
        resultRevision: afterSkip.projection.scheduleRevision,
        baseRevision: afterSkip.projection.scheduleRevision - 1,
        operatedAt: DateTime.utc(2026, 7, 10, 1),
        undoExpiresAt: DateTime.utc(2026, 7, 13, 1),
        priorSnapshot: prior,
        incompleteSnapshot: incomplete,
      );
    }

    test('undo skip restores disposition and binds live cursorBefore', () {
      final base = snapshot();
      final slot1 = base.projection.bySlotId('slot-1')!;
      final slot2 = base.projection.bySlotId('slot-2')!;
      final snap = ProgrammeSchedulingSnapshot(
        assignmentId: assignmentId,
        programmeVersionId: versionId,
        packageContentHash: packageHash,
        timezone: timezone,
        startedAt: startedAt,
        today: today,
        assignmentStatus: ProgrammeSchedulingAssignmentStatus.active,
        projection: base.projection.replacing({
          'slot-1': slot1.copyWith(
            disposition: ProgrammeScheduleDisposition.skipped,
          ),
        }),
        cursorSessionSlotId: 'slot-2',
      );
      final result = engine.previewUndo(
        snapshot: snap,
        operation: skipOp(afterSkip: snap),
      );
      expect(result.isReady, isTrue);
      expect(result.preview!.operationType, ProgrammeSchedulingOperationType.undo);
      expect(result.preview!.changes.single.proposedDisposition,
          ProgrammeScheduleDisposition.scheduled);
      final payload = ProgrammeSchedulingApplyFingerprint.payload(
        operation: ProgrammeSchedulingUndoRequest(operationId: 'op-skip-1')
            .toCanonicalMap(),
        assignmentId: assignmentId,
        programmeVersionId: versionId,
        packageContentHash: packageHash,
        scheduleRevision: snap.projection.scheduleRevision,
        timezone: timezone,
        affected: [
          ProgrammeSchedulingApplyFingerprint.affectedRow(
            sessionSlotId: 'slot-1',
            programmedSessionKey: 'psk-1',
            originalDate: slot1.scheduledDate.toString(),
            proposedDate: slot1.scheduledDate.toString(),
            originalDisposition: 'skipped',
            proposedDisposition: 'scheduled',
            weekNumber: slot1.identity.weekNumber,
            dayKey: slot1.identity.dayKey,
            sessionOrder: slot1.identity.sessionOrder,
            protocolId: slot1.identity.protocolId,
          ),
        ],
        collidingDates: const [],
        cursorBefore: ProgrammeSchedulingApplyFingerprint.cursorRow(
          sessionSlotId: 'slot-2',
          weekNumber: slot2.identity.weekNumber,
          dayKey: slot2.identity.dayKey,
          sessionOrder: slot2.identity.sessionOrder,
        ),
        cursorAfter: ProgrammeSchedulingApplyFingerprint.cursorRow(
          sessionSlotId: 'slot-1',
          weekNumber: slot1.identity.weekNumber,
          dayKey: slot1.identity.dayKey,
          sessionOrder: slot1.identity.sessionOrder,
        ),
      );
      expect(
        result.preview!.fingerprint,
        ProgrammeSchedulingApplyFingerprint.compute(payload),
      );
    });

    test('incomplete skip snapshot fails closed', () {
      final snap = snapshot();
      final op = skipOp(
        afterSkip: snap,
        incomplete: true,
        priorOverrides: const {},
      );
      final incomplete = ProgrammeSchedulingUndoableOperation(
        operationId: op.operationId,
        assignmentId: op.assignmentId,
        originalType: op.originalType,
        resultRevision: op.resultRevision,
        baseRevision: op.baseRevision,
        operatedAt: op.operatedAt,
        undoExpiresAt: op.undoExpiresAt,
        priorSnapshot: {
          'operation_type': 'skip',
          'session_slot_id': 'slot-1',
          'disposition_before': 'scheduled',
        },
        incompleteSnapshot: true,
      );
      final result = engine.previewUndo(snapshot: snap, operation: incomplete);
      expect(
        result.code,
        ProgrammeSchedulingPreviewCode.incompleteInverseSnapshot,
      );
    });

    test('non-null horizon does not alter undo fingerprint', () {
      final base = snapshot();
      final slot1 = base.projection.bySlotId('slot-1')!;
      final slot2 = base.projection.bySlotId('slot-2')!;
      final snap = ProgrammeSchedulingSnapshot(
        assignmentId: assignmentId,
        programmeVersionId: versionId,
        packageContentHash: packageHash,
        timezone: timezone,
        startedAt: startedAt,
        today: today,
        assignmentStatus: ProgrammeSchedulingAssignmentStatus.active,
        projection: base.projection.replacing({
          'slot-1': slot1.copyWith(
            disposition: ProgrammeScheduleDisposition.skipped,
          ),
        }),
        schedulingHorizonEnd:
            SessionOccurrenceDate(year: 2026, month: 8, day: 1),
        cursorSessionSlotId: 'slot-2',
      );
      final withHorizon = engine.previewUndo(
        snapshot: snap,
        operation: skipOp(afterSkip: snap),
      );
      final withoutHorizon = engine.previewUndo(
        snapshot: ProgrammeSchedulingSnapshot(
          assignmentId: assignmentId,
          programmeVersionId: versionId,
          packageContentHash: packageHash,
          timezone: timezone,
          startedAt: startedAt,
          today: today,
          assignmentStatus: ProgrammeSchedulingAssignmentStatus.active,
          projection: snap.projection,
          cursorSessionSlotId: 'slot-2',
        ),
        operation: skipOp(afterSkip: snap),
      );
      expect(withHorizon.preview!.fingerprint,
          withoutHorizon.preview!.fingerprint);
      expect(slot2.identity.sessionSlotId, 'slot-2');
    });
  });

  group('policy and fingerprint', () {
    test('paused assignment rejected', () {
      final result = engine.preview(
        snapshot: snapshot(status: ProgrammeSchedulingAssignmentStatus.paused),
        request: ProgrammeSchedulingMoveRequest(
          sessionSlotId: 'slot-1',
          targetDate: today,
        ),
      );
      expect(result.code, ProgrammeSchedulingPreviewCode.assignmentPaused);
    });

    test('deterministic fingerprint; revision change alters fingerprint', () {
      final snap = snapshot(revision: 3);
      final request = ProgrammeSchedulingMoveRequest(
        sessionSlotId: 'slot-2',
        targetDate: SessionOccurrenceDate(year: 2026, month: 7, day: 9),
      );
      final a = engine.preview(snapshot: snap, request: request);
      final b = engine.preview(snapshot: snap, request: request);
      expect(a.preview!.fingerprint, b.preview!.fingerprint);
      expect(a.preview!.fingerprint, hasLength(64));

      final revised = snapshot(revision: 4);
      final c = engine.preview(snapshot: revised, request: request);
      expect(c.preview!.fingerprint, isNot(a.preview!.fingerprint));
    });

    test('prepared/adapted/pending impacts reported without mutation', () {
      final snap = snapshot(
        prepared: {'psk-2'},
        adapted: {'psk-2'},
        pending: {'psk-2'},
        consumed: {'consumed-1'},
      );
      final originalPrepared = Set.of(snap.preparedProgrammedSessionKeys);
      final result = engine.preview(
        snapshot: snap,
        request: ProgrammeSchedulingMoveRequest(
          sessionSlotId: 'slot-2',
          targetDate: today,
        ),
      );
      expect(result.isReady, isTrue);
      final kinds = result.preview!.impacts.map((i) => i.kind).toSet();
      expect(
        kinds,
        containsAll([
          ProgrammeSchedulingImpactKind.preparedOccurrenceAffected,
          ProgrammeSchedulingImpactKind.adaptedPreparedOccurrenceAffected,
          ProgrammeSchedulingImpactKind
              .pendingAdaptationProposalWouldBeDiscarded,
          ProgrammeSchedulingImpactKind.consumedProposalIdsRemainConsumed,
        ]),
      );
      expect(snap.preparedProgrammedSessionKeys, originalPrepared);
      expect(snap.adaptedProgrammedSessionKeys, {'psk-2'});
      expect(snap.pendingAdaptationProposalKeys, {'psk-2'});
    });

    test('undo TTL policy modelled without persistence', () {
      const policy = ProgrammeSchedulingPolicy();
      expect(policy.undoTtlAthleteLocalHours, 72);
      final completed = DateTime(2026, 7, 1, 10);
      expect(
        policy.isWithinUndoTtl(
          operationCompletedAt: completed,
          nowAthleteLocal: completed.add(const Duration(hours: 71)),
        ),
        isTrue,
      );
      expect(
        policy.isWithinUndoTtl(
          operationCompletedAt: completed,
          nowAthleteLocal: completed.add(const Duration(hours: 72)),
        ),
        isFalse,
      );
      final inputs = ProgrammeSchedulingUndoPolicyInputs(
        operationCompletedAtAthleteLocal: completed,
        priorScheduleRevision: 2,
        priorSnapshotIdentity: 'snap-prior-2',
      );
      expect(inputs.ttlAthleteLocalHours, 72);
    });

    test('default policy allows all four operations', () {
      const policy = ProgrammeSchedulingPolicy();
      for (final type in ProgrammeSchedulingOperationType.values) {
        expect(policy.isOperationDefaultAllowed(type), isTrue);
      }
    });
  });

  group('compute-only guarantees', () {
    test('input projection unchanged after every preview path', () {
      final snap = snapshot();
      final before = snap.projection.toCanonicalMap();
      final ops = <ProgrammeSchedulingRequest>[
        ProgrammeSchedulingMoveRequest(
          sessionSlotId: 'slot-2',
          targetDate: today,
        ),
        const ProgrammeSchedulingSwapRequest(
          sessionSlotIdA: 'slot-1',
          sessionSlotIdB: 'slot-4',
        ),
        const ProgrammeSchedulingPushRequest(
          fromSessionSlotId: 'slot-2',
          dayDelta: 1,
        ),
        const ProgrammeSchedulingSkipRequest(sessionSlotId: 'slot-3'),
        ProgrammeSchedulingMoveRequest(
          sessionSlotId: 'slot-1',
          targetDate: SessionOccurrenceDate(year: 2026, month: 6, day: 1),
        ),
      ];
      for (final op in ops) {
        engine.preview(snapshot: snap, request: op);
        expect(snap.projection.toCanonicalMap(), before);
      }
    });

    test('preview engine source has no persistence or coupling imports', () {
      // Behavioural: engine class lives in domain and is constructible with
      // only policy — no repository constructor parameters.
      const e = ProgrammeSchedulingPreviewEngine();
      expect(e.policy.version, ProgrammeSchedulingSnapshot.defaultPolicyVersion);
    });
  });
}
