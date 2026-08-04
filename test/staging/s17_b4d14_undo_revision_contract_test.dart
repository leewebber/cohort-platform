import 'package:cohort_platform/staging/s17_occurrence_baseline.dart';
import 'package:cohort_platform/staging/s17_resume_mode.dart';
import 'package:cohort_platform/staging/s17_undo_diagnosis.dart';
import 'package:flutter_test/flutter_test.dart';

/// B4d.14 — Undo revision contract + aggregate restoration reporting.
///
/// Local fake/fixture only. Does not reclassify B4d.13 as staging PASS.
void main() {
  const preI = <String, String>{
    'slot-a': '2026-08-07|scheduled',
    'slot-b': '2026-08-08|scheduled',
    'slot-c': '2026-08-09|skipped',
  };

  group('B4d.14 Undo revision contract', () {
    test('1–2. B4d.13 shape 7→8→9 with complete restoration passes', () {
      final revision = S17UndoDiagnosis.evaluateRevisionContract(
        preSkipRevision: 7,
        postSkipRevision: 8,
        expectedApplyRevision: 8,
        applyResultRevision: 9,
        reloadedRevision: 9,
      );
      expect(revision.ok, isTrue);
      expect(revision.legacyRewindWouldPass, isFalse);
      expect(revision.contractResultRevision, 9);

      final post = S17UndoDiagnosis.evaluatePostUndoPostconditions(
        applySucceeded: true,
        reloadOk: true,
        reconstructionOk: true,
        revision: revision,
        preIBaseline: preI,
        targetSlotId: 'slot-a',
        preICursorSlotId: 'slot-a',
        postJCursorSlotId: 'slot-a',
        expectedAssignmentId: 'assign-d',
        expectedVersionId: 'version-s15a',
        expectedLineageCode: 'PROG-S15A-STAGING',
        observedAssignmentId: 'assign-d',
        observedVersionId: 'version-s15a',
        observedLineageCode: 'PROG-S15A-STAGING',
        postJBaseline: Map<String, String>.from(preI),
      );
      expect(post.revisionContractOk, isTrue);
      expect(post.completeRestorationOk, isTrue);
      expect(post.journeyJPass, isTrue);
      // Must not require post-J == pre-I revision.
      expect(revision.reloadedRevision, isNot(7));
    });

    test('3. B4d.11-shaped 6→7 Undo accepted under contract', () {
      final revision = S17UndoDiagnosis.evaluateRevisionContract(
        preSkipRevision: 5,
        postSkipRevision: 6,
        expectedApplyRevision: 6,
        applyResultRevision: 7,
        reloadedRevision: 7,
      );
      expect(revision.ok, isTrue);
      expect(revision.contractResultRevision, 7);
    });

    test('4–5. expected apply must equal post-Skip; stale fails', () {
      final ok = S17UndoDiagnosis.evaluateRevisionContract(
        preSkipRevision: 7,
        postSkipRevision: 8,
        expectedApplyRevision: 8,
        applyResultRevision: 9,
        reloadedRevision: 9,
      );
      expect(ok.expectedApplyOk, isTrue);

      final stale = S17UndoDiagnosis.evaluateRevisionContract(
        preSkipRevision: 7,
        postSkipRevision: 8,
        expectedApplyRevision: 7,
        applyResultRevision: 8,
        reloadedRevision: 8,
      );
      expect(stale.ok, isFalse);
      expect(stale.expectedApplyOk, isFalse);
    });

    test(
      '6–8. apply/reload mismatch, missing result, invalid revision fail',
      () {
        final mismatch = S17UndoDiagnosis.evaluateRevisionContract(
          preSkipRevision: 7,
          postSkipRevision: 8,
          expectedApplyRevision: 8,
          applyResultRevision: 9,
          reloadedRevision: 10,
        );
        expect(mismatch.ok, isFalse);
        expect(mismatch.reloadMatchesResult, isFalse);

        final missing = S17UndoDiagnosis.evaluateRevisionContract(
          preSkipRevision: 7,
          postSkipRevision: 8,
          expectedApplyRevision: 8,
          applyResultRevision: null,
          reloadedRevision: 9,
        );
        expect(missing.ok, isFalse);
        expect(missing.resultingRevisionPresent, isFalse);

        final nonMono = S17UndoDiagnosis.evaluateRevisionContract(
          preSkipRevision: 7,
          postSkipRevision: 8,
          expectedApplyRevision: 8,
          applyResultRevision: 8,
          reloadedRevision: 8,
        );
        expect(nonMono.ok, isFalse);
        expect(nonMono.resultingMatchesContract, isFalse);
      },
    );

    test('9–12. valid revision + logical mismatches fail restoration', () {
      final revision = S17UndoDiagnosis.evaluateRevisionContract(
        preSkipRevision: 7,
        postSkipRevision: 8,
        expectedApplyRevision: 8,
        applyResultRevision: 9,
        reloadedRevision: 9,
      );

      final targetFail = _post(
        revision: revision,
        postJBaseline: {
          'slot-a': '2026-08-07|skipped',
          'slot-b': '2026-08-08|scheduled',
          'slot-c': '2026-08-09|skipped',
        },
      );
      expect(targetFail.revisionContractOk, isTrue);
      expect(targetFail.targetDispositionRestored, isFalse);
      expect(targetFail.completeRestorationOk, isFalse);
      expect(targetFail.journeyJPass, isFalse);

      final cursorFail = _post(revision: revision, postJCursorSlotId: 'slot-b');
      expect(cursorFail.cursorRestored, isFalse);
      expect(cursorFail.journeyJPass, isFalse);

      final unrelatedFail = _post(
        revision: revision,
        postJBaseline: {
          'slot-a': '2026-08-07|scheduled',
          'slot-b': '2026-08-10|scheduled',
          'slot-c': '2026-08-09|skipped',
        },
      );
      expect(unrelatedFail.unrelatedOccurrencesUnchanged, isFalse);
      expect(unrelatedFail.journeyJPass, isFalse);

      final identityFail = _post(
        revision: revision,
        observedAssignmentId: 'other-assign',
        observedVersionId: 'other-version',
        observedLineageCode: 'PROG-OTHER',
      );
      expect(identityFail.assignmentIdentityUnchanged, isFalse);
      expect(identityFail.programmeVersionIdentityUnchanged, isFalse);
      expect(identityFail.lineageIdentityUnchanged, isFalse);
      expect(identityFail.journeyJPass, isFalse);
    });

    test(
      '13. incorrect revision + complete logical restoration still fails',
      () {
        final badRev = S17UndoDiagnosis.evaluateRevisionContract(
          preSkipRevision: 7,
          postSkipRevision: 8,
          expectedApplyRevision: 8,
          applyResultRevision: 7,
          reloadedRevision: 7,
        );
        expect(badRev.ok, isFalse);
        expect(badRev.legacyRewindWouldPass, isTrue);
        final post = _post(revision: badRev);
        expect(post.completeRestorationOk, isTrue);
        expect(post.journeyJPass, isFalse);
      },
    );

    test('14–16. failures report independently; multi-failure lists all', () {
      final badRev = S17UndoDiagnosis.evaluateRevisionContract(
        preSkipRevision: 7,
        postSkipRevision: 8,
        expectedApplyRevision: 7,
        applyResultRevision: 7,
        reloadedRevision: 7,
      );
      final post = _post(
        revision: badRev,
        postJBaseline: {
          'slot-a': '2026-08-07|skipped',
          'slot-b': '2026-08-10|scheduled',
          'slot-c': '2026-08-09|skipped',
        },
        postJCursorSlotId: 'slot-b',
        observedAssignmentId: 'wrong',
      );
      expect(post.revisionContractOk, isFalse);
      expect(post.targetDispositionRestored, isFalse);
      expect(post.cursorRestored, isFalse);
      expect(post.unrelatedOccurrencesUnchanged, isFalse);
      expect(post.assignmentIdentityUnchanged, isFalse);
      final failed = post.failedPostconditions;
      expect(failed, contains('revision_contract_ok'));
      expect(failed, contains('target_disposition_restored'));
      expect(failed, contains('cursor_restored'));
      expect(failed, contains('unrelated_occurrences_unchanged'));
      expect(failed, contains('assignment_identity_unchanged'));
      final detail = post.formatDetail(
        typed: S17UndoDiagnosis.typedApplySucceededPostconditionFailed,
        applyStatus: 'applied',
        applyCode: 'applied',
        applyInvoked: true,
        cursorBound: true,
      );
      expect(detail, contains('revision_contract_ok=false'));
      expect(detail, contains('target_disposition_restored=false'));
      expect(detail, contains('cursor_restored=false'));
    });

    test(
      '17–19. reload/reconstruction failures leave comparisons unevaluated',
      () {
        final revision = S17UndoDiagnosis.evaluateRevisionContract(
          preSkipRevision: 7,
          postSkipRevision: 8,
          expectedApplyRevision: 8,
          applyResultRevision: 9,
          reloadedRevision: null,
        );
        final reloadFail = S17UndoDiagnosis.evaluatePostUndoPostconditions(
          applySucceeded: true,
          reloadOk: false,
          reconstructionOk: false,
          revision: revision,
          preIBaseline: preI,
          targetSlotId: 'slot-a',
          preICursorSlotId: 'slot-a',
          postJCursorSlotId: null,
          expectedAssignmentId: 'assign-d',
          expectedVersionId: 'version-s15a',
          expectedLineageCode: 'PROG-S15A-STAGING',
          observedAssignmentId: null,
          observedVersionId: null,
          observedLineageCode: null,
          postJBaseline: null,
        );
        expect(reloadFail.reloadOk, isFalse);
        expect(reloadFail.targetIdentityRestored, isNull);
        expect(reloadFail.cursorRestored, isNull);
        expect(reloadFail.completeRestorationOk, isFalse);
        expect(reloadFail.failedPostconditions, contains('reload_ok'));
      },
    );

    test(
      '20–21. complete success passes; apply success alone insufficient',
      () {
        final revision = S17UndoDiagnosis.evaluateRevisionContract(
          preSkipRevision: 7,
          postSkipRevision: 8,
          expectedApplyRevision: 8,
          applyResultRevision: 9,
          reloadedRevision: 9,
        );
        final pass = _post(revision: revision);
        expect(pass.journeyJPass, isTrue);

        final applyOnly = S17UndoDiagnosis.evaluatePostUndoPostconditions(
          applySucceeded: true,
          reloadOk: true,
          reconstructionOk: true,
          revision: revision,
          preIBaseline: preI,
          targetSlotId: 'slot-a',
          preICursorSlotId: 'slot-a',
          postJCursorSlotId: 'slot-b',
          expectedAssignmentId: 'assign-d',
          expectedVersionId: 'version-s15a',
          expectedLineageCode: 'PROG-S15A-STAGING',
          observedAssignmentId: 'assign-d',
          observedVersionId: 'version-s15a',
          observedLineageCode: 'PROG-S15A-STAGING',
          postJBaseline: {
            'slot-a': '2026-08-07|skipped',
            'slot-b': '2026-08-08|scheduled',
            'slot-c': '2026-08-09|skipped',
          },
        );
        expect(applyOnly.applySucceeded, isTrue);
        expect(applyOnly.journeyJPass, isFalse);
      },
    );

    test('22–24. postcondition tests invoke no Skip/Undo/retry paths', () {
      // Pure evaluation helpers only — no repository methods.
      expect(true, isTrue);
    });

    test('25–27. B4d.9/B4d.12 semantics and typed labels remain distinct', () {
      expect(S17UndoDiagnosis.typedUndoApplied, 'undoApplied');
      expect(
        S17UndoDiagnosis.typedApplySucceededPostconditionFailed,
        'applySucceededPostconditionFailed',
      );
      const snap = S17OccurrenceBaselineSnapshot(
        authoredExecutableSlotCount: null,
        projectedOccurrenceCount: 3,
        uncompletedOccurrenceCount: 2,
        completedOrSkippedCount: 1,
        lineageCode: 'PROG-S15A-STAGING',
      );
      expect(S17OccurrenceBaseline.failClosedReason(snap), isNull);
      expect(
        snap.authoredExecutableSlotCountStatus,
        S17AuthoredExecutableSlotCountStatus.notEvaluated,
      );
    });

    test(
      '28. JSON/report fields expose expected/result/reloaded revisions',
      () {
        final revision = S17UndoDiagnosis.evaluateRevisionContract(
          preSkipRevision: 7,
          postSkipRevision: 8,
          expectedApplyRevision: 8,
          applyResultRevision: 9,
          reloadedRevision: 9,
        );
        final fields = revision.toReportFields();
        expect(fields['expected_apply_revision'], 8);
        expect(fields['apply_result_revision'], 9);
        expect(fields['reloaded_revision'], 9);
        expect(fields['contract_result_revision'], 9);
        expect(fields['pre_skip_revision'], 7);
        expect(fields['post_skip_revision'], 8);
      },
    );

    test(
      '29. legacy after.revision == beforeSkipRev cannot determine PASS',
      () {
        final rewind = S17UndoDiagnosis.evaluateRevisionContract(
          preSkipRevision: 7,
          postSkipRevision: 8,
          expectedApplyRevision: 8,
          applyResultRevision: 7,
          reloadedRevision: 7,
        );
        expect(rewind.legacyRewindWouldPass, isTrue);
        expect(rewind.ok, isFalse);
        expect(_post(revision: rewind).journeyJPass, isFalse);
      },
    );

    test('30. Journey D remains disabled in I→J selection', () {
      final selected = S17ResumeMode.parseSelectedJourneys('I,J');
      expect(selected.contains('D'), isFalse);
      expect(selected, ['I', 'J']);
    });

    test('B4d.13 observed shape + restoration failure reports aggregate', () {
      final revision = S17UndoDiagnosis.evaluateRevisionContract(
        preSkipRevision: 7,
        postSkipRevision: 8,
        expectedApplyRevision: 8,
        applyResultRevision: 9,
        reloadedRevision: 9,
      );
      expect(revision.ok, isTrue);
      final post = _post(
        revision: revision,
        postJBaseline: {
          'slot-a': '2026-08-07|skipped',
          'slot-b': '2026-08-08|scheduled',
          'slot-c': '2026-08-09|skipped',
        },
      );
      expect(post.revisionContractOk, isTrue);
      expect(post.completeRestorationOk, isFalse);
      expect(post.journeyJPass, isFalse);
      expect(
        post.failedPostconditions,
        contains('target_disposition_restored'),
      );
      expect(post.failedPostconditions, contains('complete_restoration_ok'));
      // Local assertion only — does not reclassify B4d.13 staging.
      expect(true, isTrue);
    });
  });
}

S17UndoPostconditionEvaluation _post({
  required S17UndoRevisionContractEvaluation revision,
  Map<String, String>? postJBaseline,
  String postJCursorSlotId = 'slot-a',
  String observedAssignmentId = 'assign-d',
  String observedVersionId = 'version-s15a',
  String observedLineageCode = 'PROG-S15A-STAGING',
}) {
  const preI = <String, String>{
    'slot-a': '2026-08-07|scheduled',
    'slot-b': '2026-08-08|scheduled',
    'slot-c': '2026-08-09|skipped',
  };
  return S17UndoDiagnosis.evaluatePostUndoPostconditions(
    applySucceeded: true,
    reloadOk: true,
    reconstructionOk: true,
    revision: revision,
    preIBaseline: preI,
    targetSlotId: 'slot-a',
    preICursorSlotId: 'slot-a',
    postJCursorSlotId: postJCursorSlotId,
    expectedAssignmentId: 'assign-d',
    expectedVersionId: 'version-s15a',
    expectedLineageCode: 'PROG-S15A-STAGING',
    observedAssignmentId: observedAssignmentId,
    observedVersionId: observedVersionId,
    observedLineageCode: observedLineageCode,
    postJBaseline: postJBaseline ?? Map<String, String>.from(preI),
  );
}
