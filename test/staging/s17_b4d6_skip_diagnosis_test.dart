import 'dart:io';

import 'package:cohort_platform/domain/programme_scheduling/programme_scheduling_domain.dart';
import 'package:cohort_platform/domain/session_occurrence/value_objects/session_occurrence_date.dart';
import 'package:cohort_platform/staging/s17_journey_diagnosis.dart';
import 'package:cohort_platform/staging/s17_resume_mode.dart';
import 'package:cohort_platform/staging/s17_skip_diagnosis.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('B4d.6 post-Swap+Push Skip diagnosis', () {
    test('1. order remains G→H→I→J', () {
      expect(S17ResumeMode.executionOrderFor(['G', 'H', 'I', 'J']), [
        'G',
        'H',
        'I',
        'J',
      ]);
    });

    test('2–4. I prefers cursor identity over first uncompleted', () {
      final d1 = SessionOccurrenceDate(year: 2026, month: 8, day: 6);
      final d2 = SessionOccurrenceDate(year: 2026, month: 8, day: 7);
      final occs = [
        S17SkipOccurrenceView(
          sessionSlotId: 'b49af2c9-first',
          scheduledDate: d1,
          isUncompleted: true,
          weekNumber: 1,
          dayKey: 'day_1',
          sessionOrder: 0,
        ),
        S17SkipOccurrenceView(
          sessionSlotId: '48a1ce94-second',
          scheduledDate: d2,
          isUncompleted: true,
          weekNumber: 1,
          dayKey: 'day_2',
          sessionOrder: 1,
        ),
      ];
      final legacy = S17SkipDiagnosis.selectSkipSource(
        occurrences: occs,
        cursorSessionSlotId: null,
        preferCursor: false,
      );
      expect(legacy.sessionSlotId, 'b49af2c9-first');
      expect(
        legacy.classification,
        S17SkipDiagnosis.classHarnessIneligibleSelection,
      );

      final cursorAligned = S17SkipDiagnosis.selectSkipSource(
        occurrences: occs,
        cursorSessionSlotId: '48a1ce94-second',
        preferCursor: true,
      );
      expect(cursorAligned.ok, isTrue);
      expect(cursorAligned.sessionSlotId, '48a1ce94-second');
      expect(cursorAligned.selectedViaCursor, isTrue);
      expect(cursorAligned.firstUncompletedSlotId, 'b49af2c9-first');

      // B4d.7: preferCursor with null cursor fails closed.
      final nullCursor = S17SkipDiagnosis.selectSkipSource(
        occurrences: occs,
        cursorSessionSlotId: null,
        preferCursor: true,
      );
      expect(nullCursor.ok, isFalse);
      expect(nullCursor.detail, contains('refusing first-uncompleted'));
    });

    test('5–8. post-Swap+Push geometry; skip still domain-ready for cursor', () {
      final d = SessionOccurrenceDate(year: 2026, month: 8, day: 6);
      final d2 = SessionOccurrenceDate(year: 2026, month: 8, day: 7);
      final geo = S17SkipDiagnosis.reconstructPostSwapPushDates(
        dateABefore: d,
        dateBBefore: d2,
      );
      // Swap then push+1 from A: A@D+2=08-08, B@D+1=08-07
      expect(geo.dateAAfter.toString(), '2026-08-08');
      expect(geo.dateBAfter.toString(), '2026-08-07');
      expect(geo.sameDateCollision, isFalse);

      const engine = ProgrammeSchedulingPreviewEngine();
      final started = d;
      final projection = BaselineProgrammeScheduleProjection.build(
        assignmentId: 'assign',
        programmeVersionId: 'ver',
        packageContentHash: 'hash',
        startedAt: started,
        authoredSlots: const [
          BaselineAuthoredSlot(
            sessionSlotId: 'slot-a',
            weekNumber: 1,
            dayKey: 'day_1',
            sessionOrder: 0,
            protocolId: 'p1',
            programmedSessionKey: 'k1',
          ),
          BaselineAuthoredSlot(
            sessionSlotId: 'slot-b',
            weekNumber: 1,
            dayKey: 'day_2',
            sessionOrder: 1,
            protocolId: 'p2',
            programmedSessionKey: 'k2',
          ),
        ],
      );
      // Apply swap dates then push+1 geometry manually.
      final afterGh = projection.replacing({
        'slot-a': projection
            .bySlotId('slot-a')!
            .copyWith(scheduledDate: geo.dateAAfter),
        'slot-b': projection
            .bySlotId('slot-b')!
            .copyWith(scheduledDate: geo.dateBAfter),
      });
      final snapCursorA = ProgrammeSchedulingSnapshot(
        assignmentId: 'assign',
        programmeVersionId: 'ver',
        packageContentHash: 'hash',
        timezone: 'UTC',
        startedAt: started,
        today: started,
        assignmentStatus: ProgrammeSchedulingAssignmentStatus.active,
        projection: afterGh,
        cursorSessionSlotId: 'slot-a',
      );
      final skipA = engine.preview(
        snapshot: snapCursorA,
        request: const ProgrammeSchedulingSkipRequest(sessionSlotId: 'slot-a'),
      );
      expect(skipA.isReady, isTrue);

      final snapCursorB = ProgrammeSchedulingSnapshot(
        assignmentId: 'assign',
        programmeVersionId: 'ver',
        packageContentHash: 'hash',
        timezone: 'UTC',
        startedAt: started,
        today: started,
        assignmentStatus: ProgrammeSchedulingAssignmentStatus.active,
        projection: afterGh,
        cursorSessionSlotId: 'slot-b',
      );
      final skipANotCurrent = engine.preview(
        snapshot: snapCursorB,
        request: const ProgrammeSchedulingSkipRequest(sessionSlotId: 'slot-a'),
      );
      expect(skipANotCurrent.isReady, isFalse);
      expect(
        skipANotCurrent.code,
        ProgrammeSchedulingPreviewCode.occurrenceNotCurrent,
      );

      // Null cursor: client allows skip of first uncompleted even if not current.
      final snapNull = ProgrammeSchedulingSnapshot(
        assignmentId: 'assign',
        programmeVersionId: 'ver',
        packageContentHash: 'hash',
        timezone: 'UTC',
        startedAt: started,
        today: started,
        assignmentStatus: ProgrammeSchedulingAssignmentStatus.active,
        projection: afterGh,
      );
      final skipNull = engine.preview(
        snapshot: snapNull,
        request: const ProgrammeSchedulingSkipRequest(sessionSlotId: 'slot-a'),
      );
      expect(skipNull.isReady, isTrue);
    });

    test('9–18. typed attempt classification distinctions', () {
      final collapsed = S17SkipDiagnosis.classifyAttempt(
        hasUncompleted: true,
        previewReached: false,
        previewReady: false,
        commandBuilt: false,
        applyReached: false,
        reconstructionOk: false,
        revisionAdvanced: false,
        occurrenceSkipped: false,
        cursorBound: false,
      );
      expect(
        collapsed.classification,
        S17SkipDiagnosis.classHarnessIneligibleSelection,
      );

      final previewReject = S17SkipDiagnosis.classifyAttempt(
        hasUncompleted: true,
        previewReached: true,
        previewReady: false,
        previewCode: 'occurrenceNotCurrent',
        commandBuilt: false,
        applyReached: false,
        reconstructionOk: false,
        revisionAdvanced: false,
        occurrenceSkipped: false,
        cursorBound: true,
        selectedMatchesCursor: true,
      );
      expect(
        previewReject.classification,
        S17SkipDiagnosis.classExpectedSkipIneligibility,
      );

      final applyFail = S17SkipDiagnosis.classifyAttempt(
        hasUncompleted: true,
        previewReached: true,
        previewReady: true,
        previewCode: 'previewReady',
        commandBuilt: true,
        applyReached: true,
        applySucceeded: false,
        applyStatus: 'ineligible',
        applyCode: 'occurrence_not_current',
        reconstructionOk: false,
        revisionAdvanced: false,
        occurrenceSkipped: false,
        cursorBound: true,
      );
      expect(
        applyFail.classification,
        S17SkipDiagnosis.classExpectedSkipIneligibility,
      );
      expect(applyFail.mutationMayHavePersisted, isFalse);

      final post = S17SkipDiagnosis.classifyAttempt(
        hasUncompleted: true,
        previewReached: true,
        previewReady: true,
        previewCode: 'previewReady',
        commandBuilt: true,
        applyReached: true,
        applySucceeded: true,
        applyStatus: 'applied',
        applyCode: 'ok',
        reconstructionOk: true,
        revisionAdvanced: false,
        occurrenceSkipped: false,
        cursorBound: true,
      );
      expect(
        post.classification,
        S17SkipDiagnosis.classHarnessPostconditionMismatch,
      );
      expect(post.mutationMayHavePersisted, isTrue);
      expect(post.undoRecordMayExist, isTrue);

      final detail = S17SkipDiagnosis.formatFailureDetail(
        report: applyFail,
        sourcePrefix: 'b49af2c9…',
      );
      expect(detail, contains('preview_code='));
      expect(detail, contains('apply_code=occurrence_not_current'));
      expect(S17SkipDiagnosis.isOpaqueCollapsedMessage(detail), isFalse);
      expect(
        S17SkipDiagnosis.isOpaqueCollapsedMessage(
          'Skip failed or unavailable source=b49af2c9…',
        ),
        isTrue,
      );
    });

    test('19–23. no undo in I; J blocked when I fails; no opaque hide', () {
      final entry = File('lib/main_s17_staging_verify.dart').readAsStringSync();
      expect(entry.contains('S17SkipDiagnosis'), isTrue);
      expect(entry.contains('cursorSessionSlotId: cursorSlotId'), isTrue);
      expect(entry.contains('preferCursor: true'), isTrue);
      expect(entry.contains('formatFailureDetail'), isTrue);
      expect(entry.contains('Blocked: I Skip did not pass'), isTrue);
      // Journey I must not call previewUndo / confirm undo.
      final iBlock = entry.split('// I Skip').last.split('// J Undo').first;
      expect(iBlock.contains('previewUndo'), isFalse);
      expect(S17JourneyDiagnosis.intentionallySequential['I'], 'J');
    });

    test('24–30. safety: no creator/Athlete C; sentinel intact', () {
      final diag = File(
        'lib/staging/s17_skip_diagnosis.dart',
      ).readAsStringSync();
      final entry = File('lib/main_s17_staging_verify.dart').readAsStringSync();
      final forbidden = RegExp(
        r'Athlete C\b|listAthletes|discoverAthlete|service_role|create_s17_athlete',
      );
      expect(forbidden.hasMatch(diag), isFalse);
      expect(entry.contains('S17RefuseEnrolmentAdapter'), isTrue);
      expect(entry.contains('S17_FLUTTER_COMPLETE exit='), isTrue);
      expect(
        S17JourneyDiagnosis.redactPrefix('b49af2c9-aaaa-bbbb'),
        'b49af2c9…',
      );
    });
  });
}
