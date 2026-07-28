import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/domain/session_occurrence/session_occurrence_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/adaptation_application_test_support.dart';
import '../../support/adaptation_planning_test_support.dart';

void main() {
  final plannedDate = SessionOccurrenceDate.fromDateTime(DateTime.utc(2026, 7, 28));
  final t0 = DateTime.utc(2026, 7, 28, 8);
  final t1 = DateTime.utc(2026, 7, 28, 9);
  final t2 = DateTime.utc(2026, 7, 28, 10);

  late AdaptedSessionExecutionSnapshot snapshot;

  setUp(() {
    final draft = buildTimedPlanningSession(protocolId: 'proto-occ-1');
    final input = timedPlanningInputFromDraft(draft);
    final applied = applyTimedSessionPlan(
      draft: draft,
      constraints: const AdaptationConstraintContext(availableDurationMin: 55),
      input: input,
    );
    snapshot = applied.snapshot!;
  });

  SessionOccurrence _scheduled({String id = 'occ-1'}) {
    return SessionOccurrence.schedule(
      occurrenceId: id,
      sourceSessionId: 'proto-occ-1',
      plannedDate: plannedDate,
      recordedAt: t0,
    );
  }

  group('SessionOccurrence creation', () {
    test('schedule factory sets initial lifecycle and dates', () {
      final occurrence = _scheduled();
      expect(occurrence.lifecycleState, SessionOccurrenceLifecycleState.scheduled);
      expect(occurrence.completionStatus, SessionOccurrenceCompletionStatus.pending);
      expect(occurrence.plannedDate, plannedDate);
      expect(occurrence.originalPlannedDate, plannedDate);
      expect(occurrence.currentDate, plannedDate);
      expect(occurrence.executionSnapshot, isNull);
      expect(occurrence.auditTrail.single.eventType,
          SessionOccurrenceAuditEventType.scheduled);
    });

    test('rejects empty occurrence id', () {
      expect(
        () => SessionOccurrence.schedule(
          occurrenceId: ' ',
          sourceSessionId: 'proto-1',
          plannedDate: plannedDate,
          recordedAt: t0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('lifecycle transitions', () {
    test('scheduled → adapted → inProgress → completed', () {
      final scheduled = _scheduled();
      final adapted = scheduled.attachAdaptation(
        executionSnapshot: snapshot,
        recordedAt: t1,
      );
      expect(adapted.isSuccess, isTrue);
      expect(
        adapted.occurrence!.lifecycleState,
        SessionOccurrenceLifecycleState.adapted,
      );
      expect(adapted.occurrence!.executionSnapshot, same(snapshot));

      final inProgress = adapted.occurrence!.startInProgress(recordedAt: t1);
      expect(inProgress.isSuccess, isTrue);
      expect(
        inProgress.occurrence!.lifecycleState,
        SessionOccurrenceLifecycleState.inProgress,
      );

      final completed = inProgress.occurrence!.complete(completedAt: t2);
      expect(completed.isSuccess, isTrue);
      expect(completed.occurrence!.completedAt, t2);
      expect(
        completed.occurrence!.completionStatus,
        SessionOccurrenceCompletionStatus.completed,
      );
    });

    test('scheduled can start without adaptation', () {
      final result = _scheduled().startInProgress(recordedAt: t1);
      expect(result.isSuccess, isTrue);
      expect(result.occurrence!.executionSnapshot, isNull);
    });

    test('scheduled can skip without starting', () {
      final result = _scheduled().skip(recordedAt: t1, reason: 'travel');
      expect(result.isSuccess, isTrue);
      expect(
        result.occurrence!.completionStatus,
        SessionOccurrenceCompletionStatus.skipped,
      );
    });
  });

  group('invalid lifecycle transitions', () {
    test('complete from scheduled rejected', () {
      final result = _scheduled().complete(completedAt: t2);
      expect(result.isSuccess, isFalse);
      expect(
        result.issues.first.code,
        SessionOccurrenceTransitionIssueCode.invalidLifecycleState,
      );
    });

    test('terminal occurrence rejects adaptation', () {
      final skipped = _scheduled().skip(recordedAt: t1).occurrence!;
      final result = skipped.attachAdaptation(
        executionSnapshot: snapshot,
        recordedAt: t2,
      );
      expect(result.issues.first.code,
          SessionOccurrenceTransitionIssueCode.terminalState);
    });

    test('reschedule while in progress rejected', () {
      final inProgress =
          _scheduled().startInProgress(recordedAt: t1).occurrence!;
      final result = inProgress.reschedule(
        toDate: SessionOccurrenceDate.fromDateTime(DateTime.utc(2026, 7, 29)),
        recordedAt: t2,
      );
      expect(result.isSuccess, isFalse);
    });
  });

  group('adaptation attachment', () {
    test('rejects snapshot source mismatch', () {
      final mismatch = AdaptedSessionExecutionSnapshot(
        snapshotId: snapshot.snapshotId,
        sourceProtocolId: 'other-proto',
        status: snapshot.status,
        originalPlannedDurationMin: snapshot.originalPlannedDurationMin,
        resultingEstimatedDurationMin: snapshot.resultingEstimatedDurationMin,
        durationEstimateReliable: snapshot.durationEstimateReliable,
        primarySessionIntent: snapshot.primarySessionIntent,
        secondarySessionIntents: snapshot.secondarySessionIntents,
        retainedBlocks: snapshot.retainedBlocks,
        omittedBlocks: snapshot.omittedBlocks,
        appliedAdaptationAudit: snapshot.appliedAdaptationAudit,
        expectedFidelity: snapshot.expectedFidelity,
        adaptationConfidence: snapshot.adaptationConfidence,
        evaluationOutcome: snapshot.evaluationOutcome,
        planStatus: snapshot.planStatus,
        unresolvedConstraints: snapshot.unresolvedConstraints,
        exactDurationFeasibilityConfirmed: snapshot.exactDurationFeasibilityConfirmed,
        unresolvedDurationDeficitMinutes: snapshot.unresolvedDurationDeficitMinutes,
        planFindings: snapshot.planFindings,
      );
      final result = _scheduled().attachAdaptation(
        executionSnapshot: mismatch,
        recordedAt: t1,
      );
      expect(
        result.issues.first.code,
        SessionOccurrenceTransitionIssueCode.snapshotSourceMismatch,
      );
    });

    test('replacing adaptation records audit event', () {
      final first = _scheduled()
          .attachAdaptation(executionSnapshot: snapshot, recordedAt: t1)
          .occurrence!;
      final secondSnapshot = applyTimedSessionPlan(
        draft: buildTimedPlanningSession(protocolId: 'proto-occ-1'),
        constraints: const AdaptationConstraintContext(availableDurationMin: 45),
      ).snapshot!;
      final second = first.attachAdaptation(
        executionSnapshot: secondSnapshot,
        recordedAt: t2,
      );
      expect(second.isSuccess, isTrue);
      expect(
        second.occurrence!.auditTrail
            .where((e) => e.eventType == SessionOccurrenceAuditEventType.adaptationReplaced),
        isNotEmpty,
      );
    });
  });

  group('rescheduling metadata', () {
    test('reschedule preserves original planned date and appends history', () {
      final movedDate = SessionOccurrenceDate.fromDateTime(DateTime.utc(2026, 7, 30));
      final result = _scheduled().reschedule(
        toDate: movedDate,
        recordedAt: t1,
        reason: 'work trip',
      );
      expect(result.isSuccess, isTrue);
      final occurrence = result.occurrence!;
      expect(occurrence.originalPlannedDate, plannedDate);
      expect(occurrence.plannedDate, movedDate);
      expect(occurrence.currentDate, movedDate);
      expect(occurrence.rescheduleHistory.single.fromDate, plannedDate);
      expect(occurrence.rescheduleHistory.single.toDate, movedDate);
    });

    test('reschedule to same date rejected', () {
      final result = _scheduled().reschedule(toDate: plannedDate, recordedAt: t1);
      expect(
        result.issues.first.code,
        SessionOccurrenceTransitionIssueCode.invalidRescheduleTarget,
      );
    });
  });

  group('immutability and equality', () {
    test('transitions return new instances', () {
      final original = _scheduled();
      final updated = original.startInProgress(recordedAt: t1).occurrence!;
      expect(identical(original, updated), isFalse);
      expect(original.lifecycleState, SessionOccurrenceLifecycleState.scheduled);
    });

    test('equal occurrences compare equal', () {
      final a = _scheduled();
      final b = _scheduled();
      expect(a, equals(b));
    });

    test('copy via transition does not mutate prior instance audit trail length', () {
      final original = _scheduled();
      original.updateNotes(notes: 'note', recordedAt: t1);
      expect(original.notes, isNull);
    });
  });

  group('SessionOccurrenceLifecycle rules', () {
    test('documents allowed transitions', () {
      expect(
        SessionOccurrenceLifecycle.canTransition(
          from: SessionOccurrenceLifecycleState.scheduled,
          to: SessionOccurrenceLifecycleState.adapted,
        ),
        isTrue,
      );
      expect(
        SessionOccurrenceLifecycle.canTransition(
          from: SessionOccurrenceLifecycleState.inProgress,
          to: SessionOccurrenceLifecycleState.skipped,
        ),
        isFalse,
      );
    });
  });
}
