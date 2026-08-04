import '../domain/programme_scheduling/support/session_occurrence_date_arithmetic.dart';
import '../domain/programme_scheduling/vocabulary/programme_scheduling_preview_code.dart';
import '../domain/session_occurrence/value_objects/session_occurrence_date.dart';
import 's17_journey_diagnosis.dart';

/// Pure B4d.6 Skip diagnosis helpers — no hosted I/O.
class S17SkipOccurrenceView {
  const S17SkipOccurrenceView({
    required this.sessionSlotId,
    required this.scheduledDate,
    required this.isUncompleted,
    required this.weekNumber,
    required this.dayKey,
    required this.sessionOrder,
  });

  final String sessionSlotId;
  final SessionOccurrenceDate scheduledDate;
  final bool isUncompleted;
  final int weekNumber;
  final String dayKey;
  final int sessionOrder;
}

class S17SkipSourceSelection {
  const S17SkipSourceSelection({
    required this.ok,
    required this.detail,
    required this.classification,
    this.sessionSlotId,
    this.firstUncompletedSlotId,
    this.cursorSlotId,
    this.selectedViaCursor = false,
  });

  final bool ok;
  final String detail;
  final String classification;
  final String? sessionSlotId;
  final String? firstUncompletedSlotId;
  final String? cursorSlotId;
  final bool selectedViaCursor;
}

class S17SkipAttemptReport {
  const S17SkipAttemptReport({
    required this.classification,
    required this.detail,
    required this.previewReached,
    required this.applyReached,
    this.previewCode,
    this.applyStatus,
    this.applyCode,
    this.mutationMayHavePersisted = false,
    this.undoRecordMayExist = false,
  });

  final String classification;
  final String detail;
  final bool previewReached;
  final bool applyReached;
  final String? previewCode;
  final String? applyStatus;
  final String? applyCode;
  final bool mutationMayHavePersisted;
  final bool undoRecordMayExist;
}

/// Date geometry after G swap then H push(+1) on first of two consecutive days.
class S17PostSwapPushGeometry {
  const S17PostSwapPushGeometry({
    required this.dateAAfter,
    required this.dateBAfter,
    required this.sameDateCollision,
  });

  final SessionOccurrenceDate dateAAfter;
  final SessionOccurrenceDate dateBAfter;
  final bool sameDateCollision;
}

class S17SkipDiagnosis {
  static const classHarnessStaleOccurrence = 'HARNESS_STALE_OCCURRENCE';
  static const classHarnessIneligibleSelection = 'HARNESS_INELIGIBLE_SELECTION';
  static const classHarnessPreviewConstruction = 'HARNESS_PREVIEW_CONSTRUCTION';
  static const classHarnessTypedResultCollapsed =
      'HARNESS_TYPED_RESULT_COLLAPSED';
  static const classHarnessPostconditionMismatch =
      'HARNESS_POSTCONDITION_MISMATCH';
  static const classExpectedSkipIneligibility = 'EXPECTED_SKIP_INELIGIBILITY';
  static const classProductPreviewDefect = 'PRODUCT_PREVIEW_DEFECT';
  static const classProductApplyDefect = 'PRODUCT_APPLY_DEFECT';
  static const classProductRevisionDefect = 'PRODUCT_REVISION_DEFECT';
  static const classProductReconstructionDefect =
      'PRODUCT_RECONSTRUCTION_DEFECT';
  static const classPersistedStateInconsistency =
      'PERSISTED_STATE_INCONSISTENCY';
  static const classInsufficientEvidence = 'INSUFFICIENT_PRESERVED_EVIDENCE';

  /// B4d.5 selected first uncompleted without cursor — may diverge from
  /// server Skip contract (current cursor only).
  static S17SkipSourceSelection selectSkipSource({
    required List<S17SkipOccurrenceView> occurrences,
    String? cursorSessionSlotId,
    bool preferCursor = true,
  }) {
    final uncompleted = occurrences
        .where((o) => o.isUncompleted)
        .toList(growable: false);
    if (uncompleted.isEmpty) {
      return const S17SkipSourceSelection(
        ok: false,
        detail: 'No uncompleted occurrence available for Skip',
        classification: classExpectedSkipIneligibility,
      );
    }
    final first = uncompleted.first.sessionSlotId;
    final cursor = cursorSessionSlotId?.trim() ?? '';
    // B4d.7: when preferCursor, null/unresolvable cursor fails closed —
    // first-uncompleted must never override a missing cursor.
    if (preferCursor) {
      if (cursor.isEmpty) {
        return S17SkipSourceSelection(
          ok: false,
          detail:
              'Cursor null/unresolvable; refusing first-uncompleted fallback',
          classification: classHarnessIneligibleSelection,
          firstUncompletedSlotId: first,
        );
      }
      final cursorOcc = uncompleted
          .where((o) => o.sessionSlotId == cursor)
          .toList(growable: false);
      if (cursorOcc.isEmpty) {
        return S17SkipSourceSelection(
          ok: false,
          detail:
              'Cursor ${S17JourneyDiagnosis.redactPrefix(cursor)} is not an '
              'uncompleted occurrence; refusing first-uncompleted fallback',
          classification: classHarnessIneligibleSelection,
          firstUncompletedSlotId: first,
          cursorSlotId: cursor,
        );
      }
      final viaCursor = cursor != first;
      return S17SkipSourceSelection(
        ok: true,
        detail: viaCursor
            ? 'Selected cursor occurrence (differs from first uncompleted)'
            : 'Selected cursor occurrence (matches first uncompleted)',
        classification: 'CURSOR_ALIGNED',
        sessionSlotId: cursor,
        firstUncompletedSlotId: first,
        cursorSlotId: cursor,
        selectedViaCursor: true,
      );
    }
    // Legacy B4d.5 characterisation path only (preferCursor: false).
    return S17SkipSourceSelection(
      ok: true,
      detail:
          'Selected first uncompleted without cursor binding '
          '(B4d.5-style; may diverge from server occurrence_not_current)',
      classification: classHarnessIneligibleSelection,
      sessionSlotId: first,
      firstUncompletedSlotId: first,
      cursorSlotId: cursor.isEmpty ? null : cursor,
      selectedViaCursor: false,
    );
  }

  static String? resolveCursorSlotId({
    required List<S17SkipOccurrenceView> occurrences,
    required int week,
    required String dayKey,
    required int sessionOrder,
  }) {
    for (final o in occurrences) {
      if (o.weekNumber == week &&
          o.dayKey == dayKey &&
          o.sessionOrder == sessionOrder) {
        return o.sessionSlotId;
      }
    }
    return null;
  }

  /// Two consecutive days → swap → push(+1) from A: A@D+2, B@D+1 (no collision).
  static S17PostSwapPushGeometry reconstructPostSwapPushDates({
    required SessionOccurrenceDate dateABefore,
    required SessionOccurrenceDate dateBBefore,
  }) {
    // After swap: A has B's date, B has A's date.
    final aAfterSwap = dateBBefore;
    final bAfterSwap = dateABefore;
    // Push(+1) from A affects A and later uncompleted (B if authored after A).
    // Domain push uses authored order uncompletedFrom(A).
    final aAfterPush = aAfterSwap.addCalendarDays(1);
    final bAfterPush = bAfterSwap.addCalendarDays(1);
    return S17PostSwapPushGeometry(
      dateAAfter: aAfterPush,
      dateBAfter: bAfterPush,
      sameDateCollision: aAfterPush == bAfterPush,
    );
  }

  static S17SkipAttemptReport classifyAttempt({
    required bool hasUncompleted,
    required bool previewReached,
    required bool previewReady,
    String? previewCode,
    required bool commandBuilt,
    required bool applyReached,
    bool? applySucceeded,
    String? applyStatus,
    String? applyCode,
    required bool reconstructionOk,
    required bool revisionAdvanced,
    required bool occurrenceSkipped,
    bool cursorBound = false,
    bool selectedMatchesCursor = true,
  }) {
    if (!hasUncompleted) {
      return const S17SkipAttemptReport(
        classification: classExpectedSkipIneligibility,
        detail: 'No uncompleted occurrence',
        previewReached: false,
        applyReached: false,
      );
    }
    if (!cursorBound) {
      return S17SkipAttemptReport(
        classification: classHarnessIneligibleSelection,
        detail:
            'Cursor unbound on snapshot; client may preview non-current Skip '
            'while server rejects occurrence_not_current',
        previewReached: previewReached,
        applyReached: applyReached,
        previewCode: previewCode,
        applyStatus: applyStatus,
        applyCode: applyCode,
        mutationMayHavePersisted: applyReached && applySucceeded == true,
        undoRecordMayExist: applyReached && applySucceeded == true,
      );
    }
    if (!selectedMatchesCursor) {
      return S17SkipAttemptReport(
        classification: classHarnessIneligibleSelection,
        detail:
            'Selected occurrence is not the current cursor '
            '(previewCode=${previewCode ?? 'n/a'})',
        previewReached: previewReached,
        applyReached: applyReached,
        previewCode: previewCode,
        applyStatus: applyStatus,
        applyCode: applyCode,
      );
    }
    if (!previewReached) {
      return const S17SkipAttemptReport(
        classification: classHarnessPreviewConstruction,
        detail: 'Skip preview was not invoked',
        previewReached: false,
        applyReached: false,
      );
    }
    if (!previewReady) {
      final code = previewCode ?? 'unknown';
      final expected =
          code == ProgrammeSchedulingPreviewCode.occurrenceNotCurrent.name ||
          code == 'occurrenceNotCurrent';
      return S17SkipAttemptReport(
        classification: expected
            ? classExpectedSkipIneligibility
            : classProductPreviewDefect,
        detail: 'Skip preview rejected code=$code',
        previewReached: true,
        applyReached: false,
        previewCode: code,
      );
    }
    if (!commandBuilt) {
      return S17SkipAttemptReport(
        classification: classHarnessPreviewConstruction,
        detail: 'Skip command not built from ready preview',
        previewReached: true,
        applyReached: false,
        previewCode: previewCode,
      );
    }
    if (!applyReached) {
      return S17SkipAttemptReport(
        classification: classHarnessPreviewConstruction,
        detail: 'Skip apply not invoked after ready preview',
        previewReached: true,
        applyReached: false,
        previewCode: previewCode,
      );
    }
    if (applySucceeded != true) {
      final code = (applyCode ?? 'none').trim();
      final expectedServer = code == 'occurrence_not_current';
      return S17SkipAttemptReport(
        classification: expectedServer
            ? classExpectedSkipIneligibility
            : classProductApplyDefect,
        detail:
            'Skip apply failed status=${applyStatus ?? 'unknown'} code=$code',
        previewReached: true,
        applyReached: true,
        previewCode: previewCode,
        applyStatus: applyStatus,
        applyCode: code,
        mutationMayHavePersisted: false,
        undoRecordMayExist: false,
      );
    }
    if (!reconstructionOk) {
      return S17SkipAttemptReport(
        classification: classProductReconstructionDefect,
        detail: 'Skip apply succeeded but reconstruction failed',
        previewReached: true,
        applyReached: true,
        previewCode: previewCode,
        applyStatus: applyStatus,
        applyCode: applyCode,
        mutationMayHavePersisted: true,
        undoRecordMayExist: true,
      );
    }
    if (!revisionAdvanced) {
      return S17SkipAttemptReport(
        classification: classHarnessPostconditionMismatch,
        detail: 'Skip apply succeeded but revision did not advance',
        previewReached: true,
        applyReached: true,
        previewCode: previewCode,
        applyStatus: applyStatus,
        applyCode: applyCode,
        mutationMayHavePersisted: true,
        undoRecordMayExist: true,
      );
    }
    if (!occurrenceSkipped) {
      return S17SkipAttemptReport(
        classification: classHarnessPostconditionMismatch,
        detail: 'Skip apply succeeded but occurrence not skipped',
        previewReached: true,
        applyReached: true,
        previewCode: previewCode,
        applyStatus: applyStatus,
        applyCode: applyCode,
        mutationMayHavePersisted: true,
        undoRecordMayExist: true,
      );
    }
    return S17SkipAttemptReport(
      classification: 'SKIP_OK',
      detail: 'Skip preview+apply+postcondition satisfied',
      previewReached: true,
      applyReached: true,
      previewCode: previewCode,
      applyStatus: applyStatus,
      applyCode: applyCode,
      mutationMayHavePersisted: true,
      undoRecordMayExist: true,
    );
  }

  /// Opaque B4d.5 message must not be emitted when typed detail exists.
  static String formatFailureDetail({
    required S17SkipAttemptReport report,
    required String sourcePrefix,
  }) {
    return '${report.classification} source=$sourcePrefix '
        'preview_reached=${report.previewReached} '
        'preview_code=${report.previewCode ?? 'n/a'} '
        'apply_reached=${report.applyReached} '
        'apply_status=${report.applyStatus ?? 'n/a'} '
        'apply_code=${report.applyCode ?? 'n/a'} '
        'mutation_uncertain=${report.mutationMayHavePersisted} '
        '${report.detail}';
  }

  static bool isOpaqueCollapsedMessage(String detail) {
    return detail.startsWith('Skip failed or unavailable') &&
        !detail.contains('preview_code=') &&
        !detail.contains('HARNESS_') &&
        !detail.contains('PRODUCT_') &&
        !detail.contains('EXPECTED_');
  }
}
