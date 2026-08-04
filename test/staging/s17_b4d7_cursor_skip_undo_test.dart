import 'dart:io';

import 'package:cohort_platform/domain/session_occurrence/value_objects/session_occurrence_date.dart';
import 'package:cohort_platform/staging/s17_journey_diagnosis.dart';
import 'package:cohort_platform/staging/s17_resume_mode.dart';
import 'package:cohort_platform/staging/s17_skip_diagnosis.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('B4d.7 cursor-aligned I→J', () {
    test('1–3. exact I,J selection and order; others excluded', () {
      final selected = S17ResumeMode.parseSelectedJourneys('I,J');
      expect(selected, ['I', 'J']);
      expect(
        S17JourneyDiagnosis.isExactCursorSkipUndoSelection(selected),
        isTrue,
      );
      expect(S17ResumeMode.executionOrderFor(selected), ['I', 'J']);
      final entry = File('lib/main_s17_staging_verify.dart').readAsStringSync();
      expect(entry.contains("selected.contains('G')"), isTrue);
      expect(entry.contains("selected.contains('D')"), isTrue);
      expect(entry.contains("selected.contains('F')"), isTrue);
    });

    test('4–10. cursor required; first-uncompleted cannot override', () {
      final d1 = SessionOccurrenceDate(year: 2026, month: 8, day: 6);
      final d2 = SessionOccurrenceDate(year: 2026, month: 8, day: 7);
      final occs = [
        S17SkipOccurrenceView(
          sessionSlotId: 'first-slot',
          scheduledDate: d1,
          isUncompleted: true,
          weekNumber: 1,
          dayKey: 'day_1',
          sessionOrder: 0,
        ),
        S17SkipOccurrenceView(
          sessionSlotId: 'cursor-slot',
          scheduledDate: d2,
          isUncompleted: true,
          weekNumber: 1,
          dayKey: 'day_2',
          sessionOrder: 1,
        ),
      ];
      final missing = S17SkipDiagnosis.selectSkipSource(
        occurrences: occs,
        cursorSessionSlotId: null,
        preferCursor: true,
      );
      expect(missing.ok, isFalse);
      expect(missing.detail, contains('refusing first-uncompleted'));

      final aligned = S17SkipDiagnosis.selectSkipSource(
        occurrences: occs,
        cursorSessionSlotId: 'cursor-slot',
        preferCursor: true,
      );
      expect(aligned.ok, isTrue);
      expect(aligned.sessionSlotId, 'cursor-slot');
      expect(aligned.firstUncompletedSlotId, 'first-slot');
      expect(aligned.sessionSlotId, isNot(aligned.firstUncompletedSlotId));
    });

    test('11–20. typed Skip reporting distinctions preserved', () {
      final notCurrent = S17SkipDiagnosis.classifyAttempt(
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
      );
      expect(
        notCurrent.classification,
        S17SkipDiagnosis.classExpectedSkipIneligibility,
      );
      final detail = S17SkipDiagnosis.formatFailureDetail(
        report: notCurrent,
        sourcePrefix: 'abcd1234…',
      );
      expect(detail, contains('occurrenceNotCurrent'));
      expect(S17SkipDiagnosis.isOpaqueCollapsedMessage(detail), isFalse);

      final revOnly = S17SkipDiagnosis.classifyAttempt(
        hasUncompleted: true,
        previewReached: true,
        previewReady: true,
        previewCode: 'previewReady',
        commandBuilt: true,
        applyReached: true,
        applySucceeded: true,
        applyStatus: 'applied',
        reconstructionOk: true,
        revisionAdvanced: true,
        occurrenceSkipped: false,
        cursorBound: true,
      );
      expect(
        revOnly.classification,
        S17SkipDiagnosis.classHarnessPostconditionMismatch,
      );
    });

    test('21–33. fresh Skip undo correlation; J gated on I', () {
      expect(
        S17JourneyDiagnosis.requireFreshSkipUndoTarget(
          latestOperationType: 'skip',
          latestOperationId: 'op-12345678-aaaa',
          latestBaseRevision: 4,
          latestResultRevision: 5,
          expectedBaseRevision: 4,
          expectedResultRevision: 5,
          expectedSkippedSlotId: 'slot-a',
          priorSnapshotSlotId: 'slot-a',
        ).ok,
        isTrue,
      );
      expect(
        S17JourneyDiagnosis.requireFreshSkipUndoTarget(
          latestOperationType: 'push',
          latestOperationId: 'op-1',
          latestBaseRevision: 4,
          latestResultRevision: 5,
          expectedBaseRevision: 4,
          expectedResultRevision: 5,
          expectedSkippedSlotId: 'slot-a',
        ).detail,
        startsWith('LATEST_NOT_SKIP'),
      );
      expect(
        S17JourneyDiagnosis.requireFreshSkipUndoTarget(
          latestOperationType: 'skip',
          latestOperationId: 'op-1',
          latestBaseRevision: 3,
          latestResultRevision: 5,
          expectedBaseRevision: 4,
          expectedResultRevision: 5,
          expectedSkippedSlotId: 'slot-a',
        ).detail,
        contains('LATEST_SKIP_IDENTITY_MISMATCH'),
      );
      expect(
        S17JourneyDiagnosis.requireFreshSkipUndoTarget(
          latestOperationType: 'skip',
          latestOperationId: 'op-1',
          latestBaseRevision: 4,
          latestResultRevision: 5,
          expectedBaseRevision: 4,
          expectedResultRevision: 5,
          expectedSkippedSlotId: 'slot-a',
          priorSnapshotSlotId: 'slot-other',
        ).detail,
        contains('LATEST_SKIP_IDENTITY_MISMATCH'),
      );
      final entry = File('lib/main_s17_staging_verify.dart').readAsStringSync();
      expect(entry.contains('requireFreshSkipUndoTarget'), isTrue);
      expect(entry.contains('preIBaseline'), isTrue);
      expect(entry.contains('Blocked: I Skip did not pass'), isTrue);
      final iBlock = entry.split('// I Skip').last.split('// J Undo').first;
      expect(iBlock.contains('previewUndo'), isFalse);
    });

    test('34–38. safety and dry-run tokens', () {
      final runner = File(
        'tool/staging/run_s17_flutter_staging_verify.sh',
      ).readAsStringSync();
      expect(runner.contains('CURSOR_RESOLUTION=required'), isTrue);
      expect(
        runner.contains(
          'FIRST_UNCOMPLETED_FALLBACK=forbidden_when_differs_from_cursor',
        ),
        isTrue,
      );
      expect(runner.contains('I,J|i,j) echo "EXECUTION_ORDER=I,J"'), isTrue);
      expect(runner.contains('D_ADAPTATION_EXECUTION=forbidden'), isTrue);
      final entry = File('lib/main_s17_staging_verify.dart').readAsStringSync();
      expect(entry.contains('Athlete C'), isFalse);
      expect(entry.contains('S17RefuseEnrolmentAdapter'), isTrue);
      expect(entry.contains('S17_FLUTTER_COMPLETE exit='), isTrue);
    });
  });
}
