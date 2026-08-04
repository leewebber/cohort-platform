import 'dart:io';

import 'package:cohort_platform/domain/programme_scheduling/programme_scheduling_domain.dart';
import 'package:cohort_platform/domain/session_occurrence/value_objects/session_occurrence_date.dart';
import 'package:cohort_platform/features/programme/models/programme_schedule_apply.dart';
import 'package:cohort_platform/staging/s17_journey_diagnosis.dart';
import 'package:cohort_platform/staging/s17_resume_mode.dart';
import 'package:cohort_platform/staging/s17_undo_diagnosis.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const assignmentId = 'assign-b4d7';
  const versionId = 'version-b4d7';
  const packageHash = 'pkg-b4d7';
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

  ProgrammeSchedulingUndoableOperation skipOp({
    required ProgrammeSchedulingSnapshot after,
    int? baseRevision,
    int? resultRevision,
    String operationId = '03b19698-fresh-skip',
    String slotId = '48a1ce94-cursor',
    Map<String, Object?>? priorOverrides,
    bool incomplete = false,
  }) {
    final prior = <String, Object?>{
      'operation_type': 'skip',
      'session_slot_id': slotId,
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
      ...?priorOverrides,
    };
    return ProgrammeSchedulingUndoableOperation(
      operationId: operationId,
      assignmentId: assignmentId,
      originalType: ProgrammeSchedulingOperationType.skip,
      resultRevision: resultRevision ?? after.projection.scheduleRevision,
      baseRevision: baseRevision ?? after.projection.scheduleRevision - 1,
      operatedAt: DateTime.utc(2026, 8, 4, 1),
      undoExpiresAt: DateTime.utc(2026, 8, 7, 1),
      priorSnapshot: prior,
      incompleteSnapshot: incomplete,
    );
  }

  group('B4d.8 Undo apply rejection diagnosis', () {
    test('1. authorized diagnostic path performs no hosted access', () {
      final src = File(
        'lib/staging/s17_undo_diagnosis.dart',
      ).readAsStringSync();
      expect(src.contains('Supabase'), isFalse);
      expect(src.contains('http://'), isFalse);
      expect(src.contains('https://'), isFalse);
      expect(src.contains('CONFIRM_COHORT_STAGING'), isFalse);
      expect(src.contains('Athlete C'), isFalse);
    });

    test('2–5. B4d.7-shaped Skip 5→6 creates latest reversible Skip', () {
      const engine = ProgrammeSchedulingPreviewEngine();
      final before = baseSnapshot(revision: 5);
      expect(before.projection.scheduleRevision, 5);
      final skipPreview = engine.preview(
        snapshot: before,
        request: const ProgrammeSchedulingSkipRequest(
          sessionSlotId: '48a1ce94-cursor',
        ),
      );
      expect(skipPreview.isReady, isTrue);
      final after = afterSkipSnapshot(before: before);
      expect(after.projection.scheduleRevision, 6);
      expect(
        after.projection.bySlotId('48a1ce94-cursor')!.disposition,
        ProgrammeScheduleDisposition.skipped,
      );
      final op = skipOp(after: after);
      expect(op.originalType, ProgrammeSchedulingOperationType.skip);
      expect(op.baseRevision, 5);
      expect(op.resultRevision, 6);
      final corr = S17UndoDiagnosis.correlateFreshSkip(
        latestOperationType: op.originalType.name,
        latestOperationId: op.operationId,
        latestBaseRevision: op.baseRevision,
        latestResultRevision: op.resultRevision,
        expectedBaseRevision: 5,
        expectedResultRevision: 6,
        expectedSkippedSlotId: '48a1ce94-cursor',
        priorSnapshotSlotId: op.priorSnapshot['session_slot_id']?.toString(),
      );
      expect(corr.ok, isTrue);
    });

    test('6–7. older Skip / non-Skip latest rejected before apply', () {
      final after = afterSkipSnapshot(before: baseSnapshot());
      final older = skipOp(
        after: after,
        operationId: 'old-skip',
        baseRevision: 3,
        resultRevision: 4,
      );
      final corr = S17UndoDiagnosis.correlateFreshSkip(
        latestOperationType: older.originalType.name,
        latestOperationId: older.operationId,
        latestBaseRevision: older.baseRevision,
        latestResultRevision: older.resultRevision,
        expectedBaseRevision: 5,
        expectedResultRevision: 6,
        expectedSkippedSlotId: '48a1ce94-cursor',
        priorSnapshotSlotId: '48a1ce94-cursor',
      );
      expect(corr.ok, isFalse);
      expect(corr.detail, contains('IDENTITY_MISMATCH'));

      final moveCorr = S17JourneyDiagnosis.requireSkipUndoTarget(
        latestOperationType: 'move',
      );
      expect(moveCorr.ok, isFalse);
      expect(moveCorr.detail, startsWith('LATEST_NOT_SKIP'));

      final notInvoked = S17UndoDiagnosis.classifyAttempt(
        hasUndoRecord: true,
        latestIsSkip: false,
        freshSkipCorrelated: false,
        inverseDecodable: true,
        inverseComplete: true,
        previewReached: false,
        previewReady: false,
        commandBuilt: false,
        applyReached: false,
        reloadOk: false,
        revisionRestored: false,
        stateRestored: false,
        snapshotCursorBound: false,
      );
      expect(notInvoked.applyReached, isFalse);
      expect(
        notInvoked.classification,
        S17UndoDiagnosis.classHarnessRecordSelection,
      );
    });

    test('8–13. identity and revision distinctions', () {
      final after = afterSkipSnapshot(before: baseSnapshot());
      final op = skipOp(after: after);
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
          expectedAssignmentId: assignmentId,
          recordAssignmentId: 'other-assign',
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
          priorSnapshotSlotId: '48a1ce94-cursor',
          expectedVersionId: versionId,
          recordVersionId: 'other-version',
        ).detail,
        contains('version'),
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
          priorSnapshotSlotId: '48a1ce94-cursor',
          expectedLineage: 'PROG-S15A-STAGING',
          recordLineage: 'OTHER',
        ).detail,
        contains('lineage'),
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
          priorSnapshotSlotId: 'b49af2c9-first',
        ).ok,
        isFalse,
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
      expect(
        S17UndoDiagnosis.classifyRevisionSelection(
          commandExpectedRevision: 7,
          authoritativeCurrentRevision: 6,
          sourceRevision: 5,
          resultingRevision: 6,
        ),
        'off_by_one_revision',
      );
      expect(
        S17UndoDiagnosis.classifyRevisionSelection(
          commandExpectedRevision: 6,
          authoritativeCurrentRevision: 7,
          sourceRevision: 5,
          resultingRevision: 6,
        ),
        'harness_used_resulting_but_current_diverged',
      );
    });

    test('14–17. inverse completeness and unsupported inverse', () {
      final complete = <String, Object?>{
        'disposition_before': 'scheduled',
        'outcome_existed_before': false,
        'outcome_status_before': null,
        'assignment_status_before': 'active',
        'assignment_completed_at_before': null,
        'cursor_before': {
          'week_number': 1,
          'day_key': 'day_2',
          'session_order': 1,
        },
        'session_slot_id': '48a1ce94-cursor',
      };
      expect(S17SkipInverseSchema.isComplete(complete), isTrue);

      for (final key in S17SkipInverseSchema.requiredKeys) {
        final copy = Map<String, Object?>.from(complete)..remove(key);
        expect(
          S17SkipInverseSchema.missingFields(copy),
          contains(key),
          reason: 'missing $key',
        );
      }
      final badCursor = Map<String, Object?>.from(complete)
        ..['cursor_before'] = {'week_number': 1};
      expect(
        S17SkipInverseSchema.missingFields(badCursor),
        containsAll(['cursor_before.day_key', 'cursor_before.session_order']),
      );

      final incompleteEv = S17UndoDiagnosis.classifyAttempt(
        hasUndoRecord: true,
        latestIsSkip: true,
        freshSkipCorrelated: true,
        inverseDecodable: true,
        inverseComplete: false,
        previewReached: false,
        previewReady: false,
        commandBuilt: false,
        applyReached: false,
        reloadOk: false,
        revisionRestored: false,
        stateRestored: false,
        snapshotCursorBound: true,
      );
      expect(
        incompleteEv.classification,
        S17UndoDiagnosis.classHarnessIncompleteInverse,
      );
      expect(incompleteEv.applyReached, isFalse);

      final unsupported = S17UndoDiagnosis.classifyAttempt(
        hasUndoRecord: true,
        latestIsSkip: true,
        freshSkipCorrelated: true,
        inverseDecodable: true,
        inverseComplete: true,
        previewReached: false,
        previewReady: false,
        commandBuilt: false,
        applyReached: false,
        reloadOk: false,
        revisionRestored: false,
        stateRestored: false,
        snapshotCursorBound: true,
        unsupportedInverse: true,
      );
      expect(
        unsupported.classification,
        S17UndoDiagnosis.classExpectedUndoRejection,
      );
    });

    test('18–22. revision contract; apply-not-invoked vs invoked', () {
      expect(
        S17UndoDiagnosis.authoritativeExpectedRevision(
          preSkipRevision: 5,
          postSkipRevision: 6,
        ),
        6,
      );
      final before = baseSnapshot(revision: 5);
      final after = afterSkipSnapshot(
        before: before,
        cursorSessionSlotId: null,
      );
      const engine = ProgrammeSchedulingPreviewEngine();
      final op = skipOp(after: after);
      final preview = engine.previewUndo(snapshot: after, operation: op);
      expect(preview.isReady, isTrue);
      // Command revision binds snapshot.projection.scheduleRevision (=6).
      final cmd = ProgrammeScheduleUndoCommand(
        assignmentId: after.assignmentId,
        programmeVersionId: after.programmeVersionId,
        packageContentHash: after.packageContentHash,
        expectedScheduleRevision: after.projection.scheduleRevision,
        previewFingerprint: preview.preview!.fingerprint,
        idempotencyKey: 'b4d8-diag-undo',
        operationId: op.operationId,
      );
      expect(cmd.expectedScheduleRevision, 6);

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
        snapshotCursorBound: false,
        commandExpectedRevision: 6,
        authoritativeCurrentRevision: 6,
        sourceRevision: 5,
        resultingRevision: 6,
      );
      expect(notInvoked.applyReached, isFalse);
      expect(notInvoked.detail, contains('NOT_INVOKED'));

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
        snapshotCursorBound: false,
        commandExpectedRevision: 6,
        authoritativeCurrentRevision: 6,
        sourceRevision: 5,
        resultingRevision: 6,
      );
      expect(invoked.applyReached, isTrue);
      expect(invoked.applyCode, 'stale_preview_fingerprint');
    });

    test('19–21. null-cursor Undo fingerprint ≠ cursor-bound fingerprint', () {
      const engine = ProgrammeSchedulingPreviewEngine();
      final before = baseSnapshot(revision: 5);
      final withCursor = afterSkipSnapshot(
        before: before,
        cursorSessionSlotId: 'b49af2c9-first',
      );
      final withoutCursor = afterSkipSnapshot(
        before: before,
        cursorSessionSlotId: null,
      );
      final op = skipOp(after: withCursor);
      final readyBound = engine.previewUndo(
        snapshot: withCursor,
        operation: op,
      );
      final readyNull = engine.previewUndo(
        snapshot: withoutCursor,
        operation: op,
      );
      expect(readyBound.isReady, isTrue);
      expect(readyNull.isReady, isTrue);
      expect(
        readyBound.preview!.fingerprint,
        isNot(readyNull.preview!.fingerprint),
      );
      final entry = File('lib/main_s17_staging_verify.dart').readAsStringSync();
      expect(entry.contains('B4d.8: reloadSnapshot omits cursor'), isTrue);
    });

    test(
      '23–28. typed repository/RPC results preserved; no opaque collapse',
      () {
        final cases = <(String?, String?, String)>[
          ('applied', null, S17UndoDiagnosis.typedUndoApplied),
          (null, 'operation_not_found', S17UndoDiagnosis.typedNoUndoRecord),
          (
            null,
            'operation_not_undoable',
            S17UndoDiagnosis.typedLatestNotReversible,
          ),
          (
            null,
            'incomplete_inverse_snapshot',
            S17UndoDiagnosis.typedIncompleteInverse,
          ),
          (null, 'undo_already_consumed', S17UndoDiagnosis.typedAlreadyUndone),
          (
            null,
            'occurrence_not_found',
            S17UndoDiagnosis.typedOccurrenceNotFound,
          ),
          (
            null,
            'stale_schedule_revision',
            S17UndoDiagnosis.typedCurrentRevisionMismatch,
          ),
          (
            null,
            'stale_preview_fingerprint',
            S17UndoDiagnosis.typedUndoRejected,
          ),
          (
            null,
            'provenance_mismatch',
            S17UndoDiagnosis.typedAssignmentMismatch,
          ),
          (
            null,
            'malformed_request',
            S17UndoDiagnosis.typedRpcMalformedResponse,
          ),
          (null, null, S17UndoDiagnosis.typedApplyStatusUnknown),
          ('failed', 'mystery_code', S17UndoDiagnosis.typedUndoRejected),
        ];
        for (final c in cases) {
          expect(
            S17UndoDiagnosis.typedLabelFromApply(
              applyStatus: c.$1,
              applyCode: c.$2,
            ),
            c.$3,
            reason: '${c.$1}/${c.$2}',
          );
        }

        final collapsed = S17UndoDiagnosis.classifyAttempt(
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
          applyStatus: null,
          applyCode: null,
          reloadOk: false,
          revisionRestored: false,
          stateRestored: false,
          snapshotCursorBound: false,
        );
        expect(
          collapsed.classification,
          S17UndoDiagnosis.classInsufficientEvidence,
        );
        final detail = S17UndoDiagnosis.formatFailureDetail(
          evidence: collapsed,
        );
        expect(detail, contains('typed=applyStatusUnknown'));
        expect(S17UndoDiagnosis.isOpaqueCollapsedMessage(detail), isFalse);
        expect(
          S17UndoDiagnosis.isOpaqueCollapsedMessage(
            'UNDO_REJECTED: apply unsuccessful',
          ),
          isTrue,
        );

        final typedReject = S17UndoDiagnosis.classifyAttempt(
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
          snapshotCursorBound: false,
        );
        expect(
          typedReject.classification,
          S17UndoDiagnosis.classHarnessRequestConstruction,
        );
        final typedDetail = S17UndoDiagnosis.formatFailureDetail(
          evidence: typedReject,
        );
        expect(typedDetail, contains('code=stale_preview_fingerprint'));
        expect(S17UndoDiagnosis.isOpaqueCollapsedMessage(typedDetail), isFalse);

        final transport = S17UndoDiagnosis.classifyAttempt(
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
          transportFailure: true,
        );
        expect(transport.detail, contains('TRANSPORT'));
        final malformed = S17UndoDiagnosis.classifyAttempt(
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
          malformedResponse: true,
        );
        expect(malformed.detail, contains('MALFORMED'));
      },
    );

    test('29–33. success/reload/postcondition distinctions', () {
      final reloadFail = S17UndoDiagnosis.classifyAttempt(
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
      );
      expect(
        reloadFail.classification,
        S17UndoDiagnosis.classProductUndoReconstruction,
      );
      final postFail = S17UndoDiagnosis.classifyAttempt(
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
        revisionRestored: false,
        stateRestored: true,
        snapshotCursorBound: true,
      );
      expect(
        postFail.classification,
        S17UndoDiagnosis.classHarnessPostconditionMismatch,
      );
      final applyReject = S17UndoDiagnosis.classifyAttempt(
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
        applyCode: 'stale_schedule_revision',
        reloadOk: true,
        revisionRestored: false,
        stateRestored: false,
        snapshotCursorBound: true,
      );
      expect(applyReject.detail, contains('UNDO_REJECTED'));
      expect(applyReject.detail, isNot(contains('POSTCONDITION')));
      expect(postFail.detail, isNot(contains('UNDO_REJECTED')));
    });

    test(
      '34–38. successful Undo restores pre-I disposition/date/invariants',
      () {
        const engine = ProgrammeSchedulingPreviewEngine();
        final before = baseSnapshot(revision: 5);
        final preI = {
          for (final o in before.projection.occurrences)
            o.identity.sessionSlotId:
                '${o.scheduledDate}|${o.disposition.name}',
        };
        final after = afterSkipSnapshot(
          before: before,
          cursorSessionSlotId: 'b49af2c9-first',
        );
        final op = skipOp(after: after);
        final preview = engine.previewUndo(snapshot: after, operation: op);
        expect(preview.isReady, isTrue);
        final restored = preview.preview!.proposedProjection;
        for (final o in restored.occurrences) {
          expect(
            '${o.scheduledDate}|${o.disposition.name}',
            preI[o.identity.sessionSlotId],
          );
        }
        expect(after.assignmentId, assignmentId);
        expect(after.programmeVersionId, versionId);
        expect(
          after.projection.bySlotId('b49af2c9-first')!.disposition,
          ProgrammeScheduleDisposition.scheduled,
        );
        expect(
          S17UndoDiagnosis.authoritativeExpectedRevision(
            preSkipRevision: 5,
            postSkipRevision: 6,
          ),
          6,
        );
      },
    );

    test(
      '39–48. J path gates; no D/creator/athlete-C; redaction; sentinel',
      () {
        final selected = S17ResumeMode.parseSelectedJourneys('I,J');
        expect(
          S17JourneyDiagnosis.isExactCursorSkipUndoSelection(selected),
          isTrue,
        );
        expect(S17ResumeMode.executionOrderFor(selected), ['I', 'J']);
        expect(selected.contains('D'), isFalse);

        final entry = File(
          'lib/main_s17_staging_verify.dart',
        ).readAsStringSync();
        final jStart = entry.indexOf('if (runJ && scheduleOpsContinue)');
        final jEnd = entry.indexOf('// K → C dependency', jStart);
        final jBlock = entry.substring(jStart, jEnd);
        expect(jBlock.contains('previewSkip'), isFalse);
        expect(jBlock.contains('confirmApply'), isTrue);
        expect(jBlock.contains('previewUndo'), isTrue);
        expect(jBlock.contains('apply unsuccessful'), isFalse);
        expect(jBlock.contains('S17UndoDiagnosis'), isTrue);
        expect(jBlock.contains('replaceActive'), isFalse);
        expect(jBlock.contains('Athlete C'), isFalse);
        expect(entry.contains('exitCode'), isTrue);

        final primary = S17UndoDiagnosis.primaryClassificationForB4d7(
          freshSkipCorrelated: true,
          inverseComplete: true,
          previewReady: true,
          commandBuilt: true,
          applyReached: true,
          applySucceeded: false,
          preservedApplyStatus: null,
          preservedApplyCode: null,
          journeyJReloadOmitsCursor: true,
        );
        expect(primary, S17UndoDiagnosis.classHarnessRequestConstruction);
        expect(
          S17UndoDiagnosis.secondaryB4d7ReportingWeakness,
          S17UndoDiagnosis.classHarnessTypedResultCollapsed,
        );

        expect(
          S17JourneyDiagnosis.redactPrefix('03b19698-fresh-skip-uuid'),
          '03b19698…',
        );
        expect(S17JourneyDiagnosis.redactPrefix('short'), '***');

        final first = S17UndoDiagnosis.classifyAttempt(
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
          reloadOk: false,
          revisionRestored: false,
          stateRestored: false,
          snapshotCursorBound: false,
        );
        expect(first.boundary, 'server_validation');
        expect(first.classification, isNot(S17UndoDiagnosis.typedUndoApplied));
      },
    );

    test(
      'fake limitation: cannot invent SQL fingerprint or hosted mutation',
      () {
        // Local characterization uses the Dart preview engine fingerprint only.
        // It cannot recompute PostgreSQL cohort_scheduling_apply_fingerprint or
        // prove whether a hosted Undo mutation persisted after B4d.7 rejection.
        expect(
          S17UndoDiagnosis.primaryClassificationForB4d7(
            freshSkipCorrelated: true,
            inverseComplete: true,
            previewReady: true,
            commandBuilt: true,
            applyReached: true,
            applySucceeded: false,
            preservedApplyStatus: null,
            preservedApplyCode: null,
            journeyJReloadOmitsCursor: true,
          ),
          S17UndoDiagnosis.classHarnessRequestConstruction,
        );
      },
    );
  });
}
