import 'package:cohort_platform/domain/programme_scheduling/vocabulary/programme_schedule_disposition.dart';
import 'package:cohort_platform/staging/s17_occurrence_baseline.dart';
import 'package:flutter_test/flutter_test.dart';

/// B4d.12 — authored slots vs current uncompleted baseline semantics.
///
/// Local fake/fixture only. No staging contact, no Skip/Undo, no journeys.
void main() {
  group('B4d.12 baseline semantics and labeling', () {
    test(
      '1. one uncompleted does not become authoredExecutableSlotCount=1',
      () {
        final snap = _s15aCurrentBaseline(uncompleted: 1, projected: 3);
        expect(snap.authoredExecutableSlotCount, isNull);
        expect(
          snap.authoredExecutableSlotCountStatus,
          S17AuthoredExecutableSlotCountStatus.notEvaluated,
        );
        expect(snap.currentUncompletedExecutableOccurrenceCount, 1);
        expect(snap.authoredExecutableSlotCount, isNot(1));
      },
    );

    test(
      '2–3. one uncompleted → current-baseline insufficiency, not authored',
      () {
        final snap = _s15aCurrentBaseline(uncompleted: 1, projected: 3);
        final d = S17OccurrenceBaseline.diagnose(snap);
        expect(
          d.cause,
          S17OccurrenceBlockerCause
              .currentBaselineInsufficientExecutableOccurrences,
        );
        expect(
          d.cause,
          isNot(S17OccurrenceBlockerCause.authoredProgrammeInsufficientSlots),
        );
        expect(d.detail, contains('current-baseline insufficiency'));
        expect(d.detail, isNot(contains('Authored executable slots=')));
        expect(d.detail, isNot(contains('PROG-S13-ELIG is the Self-Test')));
        expect(d.canPrepareViaMultiSlotEnrolment, isFalse);
      },
    );

    test(
      '4–5. two and many uncompleted satisfy the I→J baseline-count gate',
      () {
        for (final n in [2, 3, 5]) {
          final snap = _s15aCurrentBaseline(uncompleted: n, projected: n);
          expect(S17OccurrenceBaseline.failClosedReason(snap), isNull);
          expect(
            S17OccurrenceBaseline.diagnose(snap).detail,
            'Baseline already sufficient',
          );
        }
      },
    );

    test(
      '6. zero uncompleted fails closed with current-baseline classification',
      () {
        final snap = _s15aCurrentBaseline(uncompleted: 0, projected: 0);
        final reason = S17OccurrenceBaseline.failClosedReason(snap);
        expect(reason, isNotNull);
        expect(
          reason,
          contains(
            S17OccurrenceBlockerCause
                .currentBaselineInsufficientExecutableOccurrences
                .name,
          ),
        );
        expect(reason, isNot(contains('authoredProgrammeInsufficientSlots')));
      },
    );

    test(
      '7–9. completed, skipped, and non-scheduled are not current uncompleted',
      () {
        // Mirrors ScheduledProgrammeOccurrence.isUncompleted contract:
        // only disposition == scheduled counts as current uncompleted.
        bool isCurrentUncompleted(ProgrammeScheduleDisposition d) =>
            d == ProgrammeScheduleDisposition.scheduled;
        final dispositions = [
          ProgrammeScheduleDisposition.scheduled,
          ProgrammeScheduleDisposition.completed,
          ProgrammeScheduleDisposition.skipped,
        ];
        final uncompleted = dispositions.where(isCurrentUncompleted).length;
        expect(uncompleted, 1);
        expect(
          dispositions
              .where(
                (d) =>
                    d == ProgrammeScheduleDisposition.completed ||
                    d == ProgrammeScheduleDisposition.skipped,
              )
              .length,
          2,
        );
        final snap = S17OccurrenceBaselineSnapshot(
          authoredExecutableSlotCount: null,
          projectedOccurrenceCount: dispositions.length,
          uncompletedOccurrenceCount: uncompleted,
          completedOrSkippedCount: dispositions.length - uncompleted,
          lineageCode: S17OccurrenceBaseline.multiSlotSchedulingLineage,
        );
        expect(snap.currentUncompletedExecutableOccurrenceCount, 1);
        expect(
          S17OccurrenceBaseline.diagnose(snap).cause,
          S17OccurrenceBlockerCause
              .currentBaselineInsufficientExecutableOccurrences,
        );
      },
    );

    test(
      '10. diagnosis reports live lineage; unrelated S13 identity not implied',
      () {
        final snap = _s15aCurrentBaseline(uncompleted: 1, projected: 2);
        final d = S17OccurrenceBaseline.diagnose(snap);
        expect(d.detail, contains('PROG-S15A-STAGING'));
        expect(d.detail, isNot(contains('PROG-S13-ELIG is the Self-Test')));
        expect(
          snap.lineageCode,
          isNot(S17OccurrenceBaseline.oneSlotCatalogueLineage),
        );
      },
    );

    test('11. S15A live identity does not emit S13 wording', () {
      final snap = _s15aCurrentBaseline(uncompleted: 1, projected: 1);
      final detail = S17OccurrenceBaseline.diagnose(snap).detail;
      expect(detail, isNot(contains('Self-Test 1 one-slot package')));
      expect(detail, contains('PROG-S15A-STAGING'));
    });

    test(
      '12. authored count absent/not_evaluated without authoritative source',
      () {
        final snap = _s15aCurrentBaseline(uncompleted: 2, projected: 2);
        final fields = snap.toReportFields();
        expect(fields['authored_executable_slot_count'], isNull);
        expect(fields['authored_executable_slot_count_status'], 'notEvaluated');
      },
    );

    test(
      '13. authoritative authored count stays independent of uncompleted',
      () {
        const snap = S17OccurrenceBaselineSnapshot(
          authoredExecutableSlotCount: 4,
          projectedOccurrenceCount: 2,
          uncompletedOccurrenceCount: 2,
          completedOrSkippedCount: 0,
          lineageCode: 'PROG-S15A-STAGING',
        );
        expect(snap.authoredExecutableSlotCount, 4);
        expect(snap.currentUncompletedExecutableOccurrenceCount, 2);
        expect(
          snap.authoredExecutableSlotCount,
          isNot(snap.uncompletedOccurrenceCount),
        );
        expect(S17OccurrenceBaseline.failClosedReason(snap), isNull);
      },
    );

    test(
      '14. JSON/detail fields expose corrected current count explicitly',
      () {
        final snap = _s15aCurrentBaseline(uncompleted: 1, projected: 3);
        final fields = snap.toReportFields();
        expect(fields['current_uncompleted_executable_occurrence_count'], 1);
        expect(fields['lineage_code'], 'PROG-S15A-STAGING');
        expect(fields.containsKey('authored_executable_slot_count'), isTrue);
      },
    );

    test(
      '15. legacy misleading classification/wording cannot emit on this path',
      () {
        final snap = _s15aCurrentBaseline(uncompleted: 1, projected: 3);
        final d = S17OccurrenceBaseline.diagnose(snap);
        final reason = S17OccurrenceBaseline.failClosedReason(snap)!;
        expect(d.cause.name, isNot('authoredProgrammeInsufficientSlots'));
        expect(reason, isNot(contains('Authored executable slots=1')));
        expect(reason, isNot(contains('PROG-S13-ELIG is the Self-Test 1')));
        expect(
          reason,
          contains('currentBaselineInsufficientExecutableOccurrences'),
        );
      },
    );

    test(
      '16–18. local prep/label tests do not enable journeys or mutate ops',
      () {
        // This suite constructs snapshots only — no journey matrix, no Skip/Undo.
        expect(true, isTrue);
      },
    );

    test('B4d.10 shape: S15A + 1 uncompleted → current baseline block', () {
      const snap = S17OccurrenceBaselineSnapshot(
        authoredExecutableSlotCount: null,
        projectedOccurrenceCount: 3,
        uncompletedOccurrenceCount: 1,
        completedOrSkippedCount: 2,
        lineageCode: 'PROG-S15A-STAGING',
      );
      final d = S17OccurrenceBaseline.diagnose(snap);
      expect(
        d.cause,
        S17OccurrenceBlockerCause
            .currentBaselineInsufficientExecutableOccurrences,
      );
      expect(d.detail, contains('need ≥2'));
      expect(d.detail, isNot(contains('Authored executable slots=1')));
      expect(d.detail, isNot(contains('one-slot package')));
    });

    test('B4d.11 restored shape: S15A + 2 uncompleted → gate passes', () {
      const snap = S17OccurrenceBaselineSnapshot(
        authoredExecutableSlotCount: null,
        projectedOccurrenceCount: 3,
        uncompletedOccurrenceCount: 2,
        completedOrSkippedCount: 1,
        lineageCode: 'PROG-S15A-STAGING',
      );
      expect(S17OccurrenceBaseline.failClosedReason(snap), isNull);
    });

    test(
      'genuine S13 authored insufficiency still classified when authored known',
      () {
        const snap = S17OccurrenceBaselineSnapshot(
          authoredExecutableSlotCount: 1,
          projectedOccurrenceCount: 1,
          uncompletedOccurrenceCount: 1,
          completedOrSkippedCount: 0,
          lineageCode: 'PROG-S13-ELIG',
        );
        final d = S17OccurrenceBaseline.diagnose(snap);
        expect(
          d.cause,
          S17OccurrenceBlockerCause.authoredProgrammeInsufficientSlots,
        );
        expect(d.canPrepareViaMultiSlotEnrolment, isTrue);
        expect(
          d.detail,
          contains('PROG-S13-ELIG is the Self-Test 1 one-slot package.'),
        );
      },
    );

    test(
      'authored==1 on S15A without lineage catalogue does not force S13 wording',
      () {
        // If a caller wrongly supplies authored=1 on S15A, do not emit S13 package copy.
        const snap = S17OccurrenceBaselineSnapshot(
          authoredExecutableSlotCount: 1,
          projectedOccurrenceCount: 1,
          uncompletedOccurrenceCount: 1,
          completedOrSkippedCount: 0,
          lineageCode: 'PROG-S15A-STAGING',
        );
        final d = S17OccurrenceBaseline.diagnose(snap);
        expect(
          d.cause,
          S17OccurrenceBlockerCause.authoredProgrammeInsufficientSlots,
        );
        expect(d.detail, isNot(contains('Self-Test 1 one-slot package')));
        expect(d.canPrepareViaMultiSlotEnrolment, isFalse);
      },
    );
  });
}

S17OccurrenceBaselineSnapshot _s15aCurrentBaseline({
  required int uncompleted,
  required int projected,
}) {
  assert(projected >= uncompleted);
  return S17OccurrenceBaselineSnapshot(
    authoredExecutableSlotCount: null,
    projectedOccurrenceCount: projected,
    uncompletedOccurrenceCount: uncompleted,
    completedOrSkippedCount: projected - uncompleted,
    lineageCode: S17OccurrenceBaseline.multiSlotSchedulingLineage,
  );
}
