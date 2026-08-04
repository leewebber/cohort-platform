import '../domain/programme_scheduling/support/session_occurrence_date_arithmetic.dart';
import '../domain/session_occurrence/value_objects/session_occurrence_date.dart';
import '../features/adaptation/models/programme_adaptation_proposal.dart';

/// Pure B4d.4 diagnosis helpers for D/G/H/J — no hosted I/O.
class S17SwapCandidatePair {
  const S17SwapCandidatePair({
    required this.slotIdA,
    required this.slotIdB,
    required this.dateA,
    required this.dateB,
  });

  final String slotIdA;
  final String slotIdB;
  final SessionOccurrenceDate dateA;
  final SessionOccurrenceDate dateB;
}

class S17SwapSelectionResult {
  const S17SwapSelectionResult({
    required this.ok,
    required this.detail,
    this.pair,
    this.sameDateContamination = false,
  });

  final bool ok;
  final String detail;
  final S17SwapCandidatePair? pair;
  final bool sameDateContamination;
}

/// Occurrence view for swap selection (slot + date only).
class S17OccurrenceDateView {
  const S17OccurrenceDateView({
    required this.sessionSlotId,
    required this.scheduledDate,
    required this.isUncompleted,
  });

  final String sessionSlotId;
  final SessionOccurrenceDate scheduledDate;
  final bool isUncompleted;
}

class S17HorizonInvalidPushResult {
  const S17HorizonInvalidPushResult({
    required this.classification,
    required this.detail,
    required this.expectPreviewNotReady,
    this.dayDeltaForInvalidProbe,
  });

  /// `UNBOUNDED_NULL_HORIZON`, `OUT_OF_HORIZON`, `ALWAYS_INVALID_DISTANCE`,
  /// `IN_HORIZON_NOT_INVALID`.
  final String classification;
  final String detail;
  final bool expectPreviewNotReady;
  final int? dayDeltaForInvalidProbe;
}

class S17AdaptationNoProposalReport {
  const S17AdaptationNoProposalReport({
    required this.blocked,
    required this.safeDetail,
    required this.outcomeName,
    this.noSafeReasonName,
  });

  final bool blocked;
  final String safeDetail;
  final String outcomeName;
  final String? noSafeReasonName;
}

class S17UndoTargetCheck {
  const S17UndoTargetCheck({
    required this.ok,
    required this.detail,
    required this.expectedOperationType,
    this.observedOperationType,
  });

  final bool ok;
  final String detail;
  final String expectedOperationType;
  final String? observedOperationType;
}

class S17JourneyDiagnosis {
  /// Documented execution order for the staging harness (not matrix letter order).
  static const documentedExecutionOrder = [
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'C',
    'D',
  ];

  /// Shared sequentially mutated schedule — intentional for F→J; accidental for G after F+1.
  static const sharedScheduleJourneys = ['F', 'G', 'H', 'I', 'J'];
  static const intentionallySequential = {
    'I': 'J', // Skip must establish undoable for Undo
    'K': 'C', // Completion may create prior performance for C
  };

  /// Select first two uncompleted occurrences with distinct calendar dates.
  static S17SwapSelectionResult selectDistinctDateSwapPair(
    List<S17OccurrenceDateView> occurrences,
  ) {
    final uncompleted = occurrences.where((o) => o.isUncompleted).toList();
    if (uncompleted.length < 2) {
      return const S17SwapSelectionResult(
        ok: false,
        detail: 'BLOCKED: fewer than 2 uncompleted occurrences for swap',
      );
    }
    final naiveA = uncompleted[0];
    final naiveB = uncompleted[1];
    if (naiveA.scheduledDate == naiveB.scheduledDate) {
      // Look further for a distinct-date partner.
      for (var i = 0; i < uncompleted.length; i++) {
        for (var j = i + 1; j < uncompleted.length; j++) {
          if (uncompleted[i].scheduledDate != uncompleted[j].scheduledDate) {
            return S17SwapSelectionResult(
              ok: true,
              detail: 'Selected distinct-date swap pair after refresh',
              pair: S17SwapCandidatePair(
                slotIdA: uncompleted[i].sessionSlotId,
                slotIdB: uncompleted[j].sessionSlotId,
                dateA: uncompleted[i].scheduledDate,
                dateB: uncompleted[j].scheduledDate,
              ),
            );
          }
        }
      }
      return const S17SwapSelectionResult(
        ok: false,
        detail:
            'CONTAMINATED: first uncompleted pair share a date; no distinct-date '
            'swap pair available (likely prior Move +1 onto next slot day)',
        sameDateContamination: true,
      );
    }
    return S17SwapSelectionResult(
      ok: true,
      detail: 'Selected first two uncompleted with distinct dates',
      pair: S17SwapCandidatePair(
        slotIdA: naiveA.sessionSlotId,
        slotIdB: naiveB.sessionSlotId,
        dateA: naiveA.scheduledDate,
        dateB: naiveB.scheduledDate,
      ),
    );
  }

  /// Prove F moving first slot +1 day onto the second slot's day contaminates G.
  static bool movePlusOneContaminatesFirstTwoSwapDates({
    required SessionOccurrenceDate firstDate,
    required SessionOccurrenceDate secondDate,
  }) {
    final moved = SessionOccurrenceDate(
      year: firstDate.year,
      month: firstDate.month,
      day: firstDate.day + 1,
    );
    // Same arithmetic the harness uses (raw day+1) for contamination diagnosis.
    return moved.year == secondDate.year &&
        moved.month == secondDate.month &&
        moved.day == secondDate.day;
  }

  /// Horizon contract: null = unbounded; non-null inclusive end (`isAfter` rejects).
  static S17HorizonInvalidPushResult classifyInvalidPushProbe({
    required SessionOccurrenceDate? horizonEnd,
    required SessionOccurrenceDate fromDate,
    required int harnessLargeDelta,
  }) {
    if (horizonEnd == null) {
      return S17HorizonInvalidPushResult(
        classification: 'UNBOUNDED_NULL_HORIZON',
        detail:
            'NULL scheduling_horizon_end is unbounded; large dayDelta is not '
            'an out-of-horizon invalid. Use dayDelta<=0 for always-invalid probe.',
        expectPreviewNotReady: false,
        dayDeltaForInvalidProbe: 0,
      );
    }
    final proposed = fromDate.addCalendarDays(harnessLargeDelta);
    if (proposed.isAfter(horizonEnd)) {
      return S17HorizonInvalidPushResult(
        classification: 'OUT_OF_HORIZON',
        detail:
            'Target after inclusive horizonEnd=$horizonEnd; expect horizonExceeded',
        expectPreviewNotReady: true,
        dayDeltaForInvalidProbe: harnessLargeDelta,
      );
    }
    return S17HorizonInvalidPushResult(
      classification: 'IN_HORIZON_NOT_INVALID',
      detail:
          'Large delta still within inclusive horizon; not a valid invalid probe',
      expectPreviewNotReady: false,
      dayDeltaForInvalidProbe: 0,
    );
  }

  static bool horizonInclusiveRejects({
    required SessionOccurrenceDate proposedDate,
    required SessionOccurrenceDate horizonEnd,
  }) {
    return proposedDate.isAfter(horizonEnd);
  }

  static bool horizonAllowsOnEndDate({
    required SessionOccurrenceDate proposedDate,
    required SessionOccurrenceDate horizonEnd,
  }) {
    return !proposedDate.isAfter(horizonEnd);
  }

  /// Map typed proposal outcomes to safe BLOCKED detail (never PASS).
  static S17AdaptationNoProposalReport reportNonAcceptableProposal({
    required ProgrammeAdaptationProposalOutcome outcome,
    ProgrammeAdaptationNoSafeReason? noSafeReason,
  }) {
    final reason = noSafeReason?.name;
    final detail = switch (outcome) {
      ProgrammeAdaptationProposalOutcome.noSafeAdaptation =>
        'BLOCKED: noSafeAdaptation'
            '${reason == null ? '' : ' reason=$reason'} '
            '(expected policy/eligibility; not a proposal failure)',
      ProgrammeAdaptationProposalOutcome.noAdaptationRequired =>
        'BLOCKED: noAdaptationRequired (constraint already satisfied)',
      ProgrammeAdaptationProposalOutcome.reviewable =>
        'BLOCKED: reviewable proposal not acceptable (missing plan/request fingerprint)',
    };
    return S17AdaptationNoProposalReport(
      blocked: true,
      safeDetail: detail,
      outcomeName: outcome.name,
      noSafeReasonName: reason,
    );
  }

  /// J must undo the skip established by I — not a prior F/G/H operation.
  static S17UndoTargetCheck requireSkipUndoTarget({
    required String? latestOperationType,
  }) {
    const expected = 'skip';
    final observed = latestOperationType?.trim().toLowerCase();
    if (observed == null || observed.isEmpty) {
      return const S17UndoTargetCheck(
        ok: false,
        detail: 'Undo unavailable: no latest undoable operation after Skip',
        expectedOperationType: expected,
      );
    }
    if (observed != expected) {
      return S17UndoTargetCheck(
        ok: false,
        detail:
            'Undo target contamination: latest=$observed expected=$expected '
            '(prior journey stole undo stack)',
        expectedOperationType: expected,
        observedOperationType: observed,
      );
    }
    return const S17UndoTargetCheck(
      ok: true,
      detail: 'Latest undoable is Skip from journey I setup',
      expectedOperationType: expected,
      observedOperationType: expected,
    );
  }

  static String redactPrefix(String value) {
    final t = value.trim();
    if (t.length <= 8) return '***';
    return '${t.substring(0, 8)}…';
  }
}
