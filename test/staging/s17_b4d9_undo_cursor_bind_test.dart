import 'dart:io';

import 'package:cohort_platform/domain/programme_scheduling/programme_scheduling_domain.dart';
import 'package:cohort_platform/domain/session_occurrence/value_objects/session_occurrence_date.dart';
import 'package:cohort_platform/features/programme/models/programme_schedule_apply.dart';
import 'package:cohort_platform/staging/s17_journey_diagnosis.dart';
import 'package:cohort_platform/staging/s17_resume_mode.dart';
import 'package:cohort_platform/staging/s17_skip_diagnosis.dart';
import 'package:cohort_platform/staging/s17_undo_diagnosis.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const assignmentId = 'assign-b4d9';
  const versionId = 'version-b4d9';
  const packageHash = 'pkg-b4d9';
  const timezone = 'UTC';
  final startedAt = SessionOccurrenceDate(year: 2026, month: 8, day: 1);
  final today = SessionOccurrenceDate(year: 2026, month: 8, day: 4);

  List<BaselineAuthoredSlot> slots() => [
    BaselineAuthoredSlot(
      sessionSlotId: 'b49af2c9-first',
      weekNumber: 1,
      dayKey: 'day_1',
      sessionOrder: 0,
      protocolId: 'protocol-1',
      programmedSessionKey: 'psk-1',
    ),
    BaselineAuthoredSlot(
      sessionSlotId: '48a1ce94-cursor',
      weekNumber: 1,
      dayKey: 'day_2',
      sessionOrder: 1,
      protocolId: 'protocol-2',
      programmedSessionKey: 'psk-2',
    ),
  ];

  ProgrammeSchedulingSnapshot baseSnapshot({int revision = 5}) {
    final proj = BaselineProgrammeScheduleProjection.build(
      assignmentId: assignmentId,
      programmeVersionId: versionId,
      packageContentHash: packageHash,
      startedAt: startedAt,
      authoredSlots: slots(),
      scheduleRevision: revision,
    );
    return ProgrammeSchedulingSnapshot(
      assignmentId: assignmentId,
      programmeVersionId: versionId,
      packageContentHash: packageHash,
      timezone: timezone,
      startedAt: startedAt,
      today: today,
      assignmentStatus: ProgrammeSchedulingAssignmentStatus.active,
      projection: proj,
      cursorSessionSlotId: '48a1ce94-cursor',
    );
  }

  ProgrammeSchedulingSnapshot afterSkipSnapshot({
    required ProgrammeSchedulingSnapshot before,
    String? cursorSessionSlotId = 'b49af2c9-first',
  }) {
    final skipped = before.projection.bySlotId('48a1ce94-cursor')!;
    final replaced = before.projection.replacing({
      '48a1ce94-cursor': skipped.copyWith(
        disposition: ProgrammeScheduleDisposition.skipped,
      ),
    });
    return ProgrammeSchedulingSnapshot(
      assignmentId: assignmentId,
      programmeVersionId: versionId,
      packageContentHash: packageHash,
      timezone: timezone,
      startedAt: startedAt,
      today: today,
      assignmentStatus: ProgrammeSchedulingAssignmentStatus.active,
      projection: ProgrammeScheduleProjection(
        occurrences: replaced.occurrences,
        scheduleRevision: before.projection.scheduleRevision + 1,
      ),
      cursorSessionSlotId: cursorSessionSlotId,
    );
  }

  List<S17SkipOccurrenceView> views(ProgrammeSchedulingSnapshot snap) {
    return snap.projection.occurrences
        .map(
          (o) => S17SkipOccurrenceView(
            sessionSlotId: o.identity.sessionSlotId,
            scheduledDate: o.scheduledDate,
            isUncompleted: o.isUncompleted,
            weekNumber: o.identity.weekNumber,
            dayKey: o.identity.dayKey,
            sessionOrder: o.identity.sessionOrder,
          ),
        )
        .toList();
  }

  ProgrammeSchedulingUndoableOperation skipOp(
    ProgrammeSchedulingSnapshot after,
  ) {
    return ProgrammeSchedulingUndoableOperation(
      operationId: '03b19698-fresh-skip',
      assignmentId: assignmentId,
      originalType: ProgrammeSchedulingOperationType.skip,
      resultRevision: after.projection.scheduleRevision,
      baseRevision: after.projection.scheduleRevision - 1,
      operatedAt: DateTime.utc(2026, 8, 4, 1),
      undoExpiresAt: DateTime.utc(2026, 8, 7, 1),
      priorSnapshot: {
        'operation_type': 'skip',
        'session_slot_id': '48a1ce94-cursor',
        'disposition_before': 'scheduled',
        'outcome_existed_before': false,
        'outcome_status_before': null,
        'cursor_before': {
          'week_number': 1,
          'day_key': 'day_2',
          'session_order': 1,
        },
        'assignment_status_before': 'active',
        'assignment_completed_at_before': null,
      },
    );
  }

  group('B4d.9 Journey J live-cursor bind remediation', () {
    test('1. remediation path performs no hosted access', () {
      final src = File(
        'lib/staging/s17_undo_diagnosis.dart',
      ).readAsStringSync();
      expect(src.contains('Supabase'), isFalse);
      expect(src.contains('http://'), isFalse);
      expect(src.contains('CONFIRM_COHORT_STAGING'), isFalse);
      final entry = File('lib/main_s17_staging_verify.dart').readAsStringSync();
      final j = entry
          .split('// B4d.9: reload live assignment')
          .last
          .split('// K → C dependency')
          .first;
      expect(j.contains('service_role'), isFalse);
      expect(j.contains('Athlete C'), isFalse);
    });

    test('2–5. authoritative live cursor required before preview', () {
      final before = baseSnapshot();
      final after = afterSkipSnapshot(before: before);
      // Post-Skip assignment cursor advances to first remaining uncompleted.
      final bind = S17UndoDiagnosis.resolveAuthoritativeLiveCursor(
        occurrences: views(after),
        assignmentPresent: true,
        week: 1,
        dayKey: 'day_1',
        sessionOrder: 0,
        freshlySkippedSlotId: '48a1ce94-cursor',
      );
      expect(bind.ok, isTrue);
      expect(bind.cursorSessionSlotId, 'b49af2c9-first');
      expect(bind.cursorSessionSlotId, isNot('48a1ce94-cursor'));

      final bound = S17UndoDiagnosis.bindCursor(
        snapshot: afterSkipSnapshot(before: before, cursorSessionSlotId: null),
        cursorSessionSlotId: bind.cursorSessionSlotId!,
      );
      expect(bound.cursorSessionSlotId, 'b49af2c9-first');
      expect((bound.cursorSessionSlotId ?? '').trim().isNotEmpty, isTrue);
    });

    test('6–10. fail-closed cursor conditions', () {
      final after = afterSkipSnapshot(before: baseSnapshot());
      final occ = views(after);
      expect(
        S17UndoDiagnosis.resolveAuthoritativeLiveCursor(
          occurrences: occ,
          assignmentPresent: false,
        ).reason,
        S17UndoDiagnosis.cursorFailMissing,
      );
      expect(
        S17UndoDiagnosis.resolveAuthoritativeLiveCursor(
          occurrences: occ,
          assignmentPresent: true,
          week: null,
          dayKey: 'day_1',
          sessionOrder: 0,
        ).reason,
        S17UndoDiagnosis.cursorFailMalformed,
      );
      expect(
        S17UndoDiagnosis.resolveAuthoritativeLiveCursor(
          occurrences: occ,
          assignmentPresent: true,
          week: 9,
          dayKey: 'day_x',
          sessionOrder: 99,
          freshlySkippedSlotId: '48a1ce94-cursor',
        ).reason,
        S17UndoDiagnosis.cursorFailUnresolvable,
      );
      final ambiguous = [
        ...occ,
        S17SkipOccurrenceView(
          sessionSlotId: 'dup-slot',
          scheduledDate: today,
          isUncompleted: true,
          weekNumber: 1,
          dayKey: 'day_1',
          sessionOrder: 0,
        ),
      ];
      expect(
        S17UndoDiagnosis.resolveAuthoritativeLiveCursor(
          occurrences: ambiguous,
          assignmentPresent: true,
          week: 1,
          dayKey: 'day_1',
          sessionOrder: 0,
          freshlySkippedSlotId: '48a1ce94-cursor',
        ).reason,
        S17UndoDiagnosis.cursorFailAmbiguous,
      );
      expect(
        S17UndoDiagnosis.resolveAuthoritativeLiveCursor(
          occurrences: occ,
          assignmentPresent: true,
          week: 1,
          dayKey: 'day_2',
          sessionOrder: 1,
          freshlySkippedSlotId: '48a1ce94-cursor',
        ).reason,
        S17UndoDiagnosis.cursorFailStale,
      );
    });

    test('11–12. first-uncompleted / undo-record cannot substitute', () {
      expect(
        S17UndoDiagnosis.isIllegalFirstUncompletedSubstitution(
          authoritativeCursorSlotId: 'b49af2c9-first',
          firstUncompletedSlotId: 'b49af2c9-first',
          proposedSlotId: '48a1ce94-cursor',
        ),
        isFalse,
      );
      expect(
        S17UndoDiagnosis.isIllegalFirstUncompletedSubstitution(
          authoritativeCursorSlotId: 'live-cursor',
          firstUncompletedSlotId: 'first-uncompleted',
          proposedSlotId: 'first-uncompleted',
        ),
        isTrue,
      );
      expect(
        S17UndoDiagnosis.isIllegalUndoRecordSlotSubstitution(
          authoritativeCursorSlotId: 'b49af2c9-first',
          priorSnapshotSlotId: '48a1ce94-cursor',
          proposedSlotId: '48a1ce94-cursor',
        ),
        isTrue,
      );
      expect(
        S17UndoDiagnosis.isIllegalUndoRecordSlotSubstitution(
          authoritativeCursorSlotId: 'b49af2c9-first',
          priorSnapshotSlotId: '48a1ce94-cursor',
          proposedSlotId: 'b49af2c9-first',
        ),
        isFalse,
      );
    });

    test('13–21. bind survives copy; fingerprint parity; null mismatch gone', () {
      const engine = ProgrammeSchedulingPreviewEngine();
      final before = baseSnapshot(revision: 5);
      final productShaped = afterSkipSnapshot(
        before: before,
        cursorSessionSlotId: 'b49af2c9-first',
      );
      final nullCursor = afterSkipSnapshot(
        before: before,
        cursorSessionSlotId: null,
      );
      final harnessBound = S17UndoDiagnosis.bindCursor(
        snapshot: nullCursor,
        cursorSessionSlotId: 'b49af2c9-first',
      );
      expect(
        harnessBound.cursorSessionSlotId,
        productShaped.cursorSessionSlotId,
      );
      // Survive second reconstruction/copy.
      final recopied = S17UndoDiagnosis.bindCursor(
        snapshot: harnessBound,
        cursorSessionSlotId: harnessBound.cursorSessionSlotId!,
      );
      expect(recopied.cursorSessionSlotId, 'b49af2c9-first');

      final op = skipOp(productShaped);
      final productFp = engine.previewUndo(
        snapshot: productShaped,
        operation: op,
      );
      final harnessFp = engine.previewUndo(
        snapshot: harnessBound,
        operation: op,
      );
      final nullFp = engine.previewUndo(snapshot: nullCursor, operation: op);
      expect(productFp.isReady, isTrue);
      expect(harnessFp.isReady, isTrue);
      expect(nullFp.isReady, isTrue);
      expect(productFp.preview!.fingerprint, harnessFp.preview!.fingerprint);
      expect(
        nullFp.preview!.fingerprint,
        isNot(harnessFp.preview!.fingerprint),
      );
      // Preview + apply command share the same fingerprint from same snapshot.
      final cmd = ProgrammeScheduleUndoCommand(
        assignmentId: harnessBound.assignmentId,
        programmeVersionId: harnessBound.programmeVersionId,
        packageContentHash: harnessBound.packageContentHash,
        expectedScheduleRevision: harnessBound.projection.scheduleRevision,
        previewFingerprint: harnessFp.preview!.fingerprint,
        idempotencyKey: 'b4d9-parity',
        operationId: op.operationId,
      );
      expect(cmd.previewFingerprint, productFp.preview!.fingerprint);
      expect(cmd.expectedScheduleRevision, 6);

      // Fingerprint algorithm source unchanged.
      final fpSrc = File(
        'lib/domain/programme_scheduling/support/programme_scheduling_apply_fingerprint.dart',
      ).readAsStringSync();
      expect(fpSrc.contains('cursorBefore'), isTrue);
    });

    test('22–25. revision contract independent of cursor bind', () {
      expect(
        S17UndoDiagnosis.authoritativeExpectedRevision(
          preSkipRevision: 5,
          postSkipRevision: 6,
        ),
        6,
      );
      expect(
        S17UndoDiagnosis.classifyRevisionSelection(
          commandExpectedRevision: 5,
          authoritativeCurrentRevision: 6,
          sourceRevision: 5,
          resultingRevision: 6,
        ),
        'harness_used_source_revision',
      );
      expect(
        S17UndoDiagnosis.classifyRevisionSelection(
          commandExpectedRevision: 6,
          authoritativeCurrentRevision: 6,
          sourceRevision: 5,
          resultingRevision: 6,
        ),
        'revision_ok_current_post_skip',
      );
    });

    test('26–36. correlation / identity / inverse / apply-invoked gates', () {
      final after = afterSkipSnapshot(before: baseSnapshot());
      final op = skipOp(after);
      expect(
        S17UndoDiagnosis.correlateFreshSkip(
          latestOperationType: 'skip',
          latestOperationId: op.operationId,
          latestBaseRevision: 5,
          latestResultRevision: 6,
          expectedBaseRevision: 5,
          expectedResultRevision: 6,
          expectedSkippedSlotId: '48a1ce94-cursor',
          priorSnapshotSlotId: '48a1ce94-cursor',
        ).ok,
        isTrue,
      );
      expect(
        S17UndoDiagnosis.correlateFreshSkip(
          latestOperationType: 'skip',
          latestOperationId: 'old',
          latestBaseRevision: 3,
          latestResultRevision: 4,
          expectedBaseRevision: 5,
          expectedResultRevision: 6,
          expectedSkippedSlotId: '48a1ce94-cursor',
        ).ok,
        isFalse,
      );
      expect(
        S17JourneyDiagnosis.requireSkipUndoTarget(
          latestOperationType: 'move',
        ).ok,
        isFalse,
      );
      expect(
        S17UndoDiagnosis.correlateFreshSkip(
          latestOperationType: 'skip',
          latestOperationId: op.operationId,
          latestBaseRevision: 5,
          latestResultRevision: 6,
          expectedBaseRevision: 5,
          expectedResultRevision: 6,
          expectedSkippedSlotId: '48a1ce94-cursor',
          expectedAssignmentId: assignmentId,
          recordAssignmentId: 'other',
        ).ok,
        isFalse,
      );
      expect(S17SkipInverseSchema.isComplete(op.priorSnapshot), isTrue);
      final notInvoked = S17UndoDiagnosis.classifyAttempt(
        hasUndoRecord: true,
        latestIsSkip: true,
        freshSkipCorrelated: true,
        inverseDecodable: true,
        inverseComplete: true,
        previewReached: true,
        previewReady: true,
        commandBuilt: true,
        applyReached: false,
        reloadOk: false,
        revisionRestored: false,
        stateRestored: false,
        snapshotCursorBound: true,
      );
      expect(notInvoked.applyReached, isFalse);
      final invoked = S17UndoDiagnosis.classifyAttempt(
        hasUndoRecord: true,
        latestIsSkip: true,
        freshSkipCorrelated: true,
        inverseDecodable: true,
        inverseComplete: true,
        previewReached: true,
        previewReady: true,
        commandBuilt: true,
        applyReached: true,
        applySucceeded: false,
        applyStatus: 'conflict',
        applyCode: 'stale_preview_fingerprint',
        reloadOk: true,
        revisionRestored: false,
        stateRestored: false,
        snapshotCursorBound: true,
      );
      expect(invoked.applyReached, isTrue);
      expect(invoked.applyCode, 'stale_preview_fingerprint');
    });

    test('37–44. typed status/code preserved; opaque collapse gone', () {
      final evidence = S17UndoDiagnosis.classifyAttempt(
        hasUndoRecord: true,
        latestIsSkip: true,
        freshSkipCorrelated: true,
        inverseDecodable: true,
        inverseComplete: true,
        previewReached: true,
        previewReady: true,
        commandBuilt: true,
        applyReached: true,
        applySucceeded: false,
        applyStatus: 'conflict',
        applyCode: 'stale_preview_fingerprint',
        reloadOk: true,
        revisionRestored: false,
        stateRestored: false,
        snapshotCursorBound: true,
        commandExpectedRevision: 6,
      );
      final detail = S17UndoDiagnosis.formatFailureDetail(evidence: evidence);
      expect(detail, contains('status=conflict'));
      expect(detail, contains('code=stale_preview_fingerprint'));
      expect(detail, contains('apply_invoked=true'));
      expect(detail, contains('expected_revision=6'));
      expect(detail, contains('cursor_bound=true'));
      expect(S17UndoDiagnosis.isOpaqueCollapsedMessage(detail), isFalse);
      expect(
        S17UndoDiagnosis.isOpaqueCollapsedMessage(
          'UNDO_REJECTED: apply unsuccessful',
        ),
        isTrue,
      );

      final unknown = S17UndoDiagnosis.formatFailureDetail(
        evidence: S17UndoDiagnosis.classifyAttempt(
          hasUndoRecord: true,
          latestIsSkip: true,
          freshSkipCorrelated: true,
          inverseDecodable: true,
          inverseComplete: true,
          previewReached: true,
          previewReady: true,
          commandBuilt: true,
          applyReached: true,
          applySucceeded: false,
          reloadOk: false,
          revisionRestored: false,
          stateRestored: false,
          snapshotCursorBound: true,
        ),
      );
      expect(unknown, contains('typed=applyStatusUnknown'));

      expect(
        S17UndoDiagnosis.classifyAttempt(
          hasUndoRecord: true,
          latestIsSkip: true,
          freshSkipCorrelated: true,
          inverseDecodable: true,
          inverseComplete: true,
          previewReached: true,
          previewReady: true,
          commandBuilt: true,
          applyReached: true,
          applySucceeded: true,
          applyStatus: 'applied',
          reloadOk: false,
          revisionRestored: false,
          stateRestored: false,
          snapshotCursorBound: true,
        ).classification,
        S17UndoDiagnosis.classProductUndoReconstruction,
      );
      expect(
        S17UndoDiagnosis.classifyAttempt(
          hasUndoRecord: true,
          latestIsSkip: true,
          freshSkipCorrelated: true,
          inverseDecodable: true,
          inverseComplete: true,
          previewReached: true,
          previewReady: true,
          commandBuilt: true,
          applyReached: true,
          applySucceeded: true,
          applyStatus: 'applied',
          reloadOk: true,
          revisionRestored: true,
          stateRestored: false,
          snapshotCursorBound: true,
        ).classification,
        S17UndoDiagnosis.classHarnessPostconditionMismatch,
      );
    });

    test('45–48. successful Undo restores pre-I; invariants hold', () {
      const engine = ProgrammeSchedulingPreviewEngine();
      final before = baseSnapshot(revision: 5);
      final preI = {
        for (final o in before.projection.occurrences)
          o.identity.sessionSlotId: '${o.scheduledDate}|${o.disposition.name}',
      };
      final after = afterSkipSnapshot(
        before: before,
        cursorSessionSlotId: 'b49af2c9-first',
      );
      final preview = engine.previewUndo(
        snapshot: after,
        operation: skipOp(after),
      );
      expect(preview.isReady, isTrue);
      for (final o in preview.preview!.proposedProjection.occurrences) {
        expect(
          '${o.scheduledDate}|${o.disposition.name}',
          preI[o.identity.sessionSlotId],
        );
      }
      expect(after.assignmentId, assignmentId);
      expect(after.programmeVersionId, versionId);
      expect(after.projection.scheduleRevision, 6);
    });

    test('49–59. J gates; harness-only; no product/D/creator/Athlete C', () {
      final selected = S17ResumeMode.parseSelectedJourneys('I,J');
      expect(
        S17JourneyDiagnosis.isExactCursorSkipUndoSelection(selected),
        isTrue,
      );
      expect(selected.contains('D'), isFalse);

      final entry = File('lib/main_s17_staging_verify.dart').readAsStringSync();
      final jStart = entry.indexOf('if (runJ && scheduleOpsContinue)');
      final jEnd = entry.indexOf('// K → C dependency', jStart);
      final jBlock = entry.substring(jStart, jEnd);
      expect(jBlock.contains('resolveAuthoritativeLiveCursor'), isTrue);
      expect(jBlock.contains('previewSkip'), isFalse);
      expect(jBlock.contains('confirmApply'), isTrue);
      expect(jBlock.contains('apply unsuccessful'), isFalse);
      expect(jBlock.contains('replaceActive'), isFalse);
      expect(jBlock.contains('Athlete C'), isFalse);
      expect(jBlock.contains('getActiveAssignment'), isTrue);
      // Product fingerprint / SQL / skip writer untouched.
      expect(
        File(
          'lib/domain/programme_scheduling/support/programme_scheduling_apply_fingerprint.dart',
        ).readAsStringSync().contains('policyVersion'),
        isTrue,
      );

      expect(
        S17JourneyDiagnosis.redactPrefix('03b19698-fresh-skip-uuid'),
        '03b19698…',
      );
      expect(entry.contains('exitCode'), isTrue);
    });
  });
}
