// Diagnosis and fail-closed baseline for schedule-operation journeys (F–J).
//
// Authored executable slot count and current uncompleted executable
// occurrence count are different values. The I→J baseline gate evaluates
// current assignment state. A baseline insufficiency does not prove an
// authored programme insufficiency.
//
// B4b root cause (when authored count is known): PROG-S13-ELIG is the
// Self-Test 1 one-slot package. Horizon and date filtering are not the cause.

/// Classifies why fewer than [requiredUncompleted] occurrences are available.
enum S17OccurrenceBlockerCause {
  /// Authored programme has fewer executable slots than required.
  ///
  /// Only when [S17OccurrenceBaselineSnapshot.authoredExecutableSlotCount]
  /// is known from an authoritative authored-plan source.
  authoredProgrammeInsufficientSlots,

  /// Current assignment has fewer uncompleted executable occurrences than
  /// required for deterministic I→J (Skip then Undo) verification.
  ///
  /// Does not assert authored programme structure.
  currentBaselineInsufficientExecutableOccurrences,

  /// Authored slots suffice but materialised/projected occurrences do not.
  materialisationInsufficient,

  /// Horizon or date selection excluded otherwise available occurrences.
  horizonOrDateExclusion,

  /// Harness filtered incorrectly relative to the raw projection.
  harnessFilterError,

  /// Retained Athlete D state is incomplete or ambiguous for scheduling ops.
  incompleteBaseline,

  /// Product behaviour contradicted authored slot → occurrence projection.
  productDefect,
}

/// Status of the authored-slot field when no authoritative plan source exists.
enum S17AuthoredExecutableSlotCountStatus { evaluated, notEvaluated }

class S17OccurrenceBaselineSnapshot {
  const S17OccurrenceBaselineSnapshot({
    this.authoredExecutableSlotCount,
    required this.projectedOccurrenceCount,
    required this.uncompletedOccurrenceCount,
    required this.completedOrSkippedCount,
    required this.lineageCode,
    this.schedulingHorizonEnd,
  });

  /// Executable slots from an authoritative authored plan/package source.
  ///
  /// Null means not evaluated — never populate from current occurrence state.
  final int? authoredExecutableSlotCount;

  final int projectedOccurrenceCount;

  /// Current uncompleted executable occurrences on the live assignment.
  ///
  /// This is the value the I→J preparation gate evaluates.
  final int uncompletedOccurrenceCount;

  final int completedOrSkippedCount;
  final String lineageCode;
  final String? schedulingHorizonEnd;

  /// Repository-native alias for report/JSON clarity.
  int get currentUncompletedExecutableOccurrenceCount =>
      uncompletedOccurrenceCount;

  S17AuthoredExecutableSlotCountStatus get authoredExecutableSlotCountStatus =>
      authoredExecutableSlotCount == null
      ? S17AuthoredExecutableSlotCountStatus.notEvaluated
      : S17AuthoredExecutableSlotCountStatus.evaluated;

  bool get hasNullHorizon =>
      schedulingHorizonEnd == null || schedulingHorizonEnd!.trim().isEmpty;

  /// Redacted report fields for journey detail / JSON (no private ids).
  Map<String, Object?> toReportFields() => {
    'authored_executable_slot_count': authoredExecutableSlotCount,
    'authored_executable_slot_count_status':
        authoredExecutableSlotCountStatus.name,
    'current_uncompleted_executable_occurrence_count':
        currentUncompletedExecutableOccurrenceCount,
    'projected_occurrence_count': projectedOccurrenceCount,
    'completed_or_skipped_count': completedOrSkippedCount,
    'lineage_code': lineageCode,
  };
}

class S17OccurrenceBaselineDiagnosis {
  const S17OccurrenceBaselineDiagnosis({
    required this.cause,
    required this.detail,
    required this.canPrepareViaMultiSlotEnrolment,
  });

  final S17OccurrenceBlockerCause cause;
  final String detail;
  final bool canPrepareViaMultiSlotEnrolment;
}

class S17OccurrenceBaseline {
  static const requiredUncompletedForScheduleOps = 2;

  /// One-slot Self-Test 1 catalogue fixture used by B4b Athlete D creation.
  static const oneSlotCatalogueLineage = 'PROG-S13-ELIG';

  /// Published multi-slot staging package suitable for Athlete D-owned prep.
  /// Programme code only — not an athlete identity or lookup.
  static const multiSlotSchedulingLineage = 'PROG-S15A-STAGING';

  /// Diagnoses `<2` uncompleted occurrences without contacting a host.
  static S17OccurrenceBaselineDiagnosis diagnose(
    S17OccurrenceBaselineSnapshot snap, {
    int requiredUncompleted = requiredUncompletedForScheduleOps,
  }) {
    if (snap.uncompletedOccurrenceCount >= requiredUncompleted &&
        snap.projectedOccurrenceCount >= requiredUncompleted) {
      return const S17OccurrenceBaselineDiagnosis(
        cause: S17OccurrenceBlockerCause.incompleteBaseline,
        detail: 'Baseline already sufficient',
        canPrepareViaMultiSlotEnrolment: false,
      );
    }

    // Harness filter error: uncompleted count lower than raw scheduled rows
    // would require a mismatch between projection and isUncompleted — represented
    // when projected count is high but uncompleted is inexplicably low while
    // completed/skipped cannot account for the gap.
    final accounted =
        snap.uncompletedOccurrenceCount + snap.completedOrSkippedCount;
    if (snap.projectedOccurrenceCount >= requiredUncompleted &&
        accounted != snap.projectedOccurrenceCount) {
      return S17OccurrenceBaselineDiagnosis(
        cause: S17OccurrenceBlockerCause.harnessFilterError,
        detail:
            'Projection count ${snap.projectedOccurrenceCount} does not equal '
            'uncompleted+terminal $accounted',
        canPrepareViaMultiSlotEnrolment: false,
      );
    }

    final authored = snap.authoredExecutableSlotCount;

    // Genuine authored insufficiency — only when authored count is known.
    if (authored != null && authored < requiredUncompleted) {
      final isKnownOneSlot = snap.lineageCode == oneSlotCatalogueLineage;
      return S17OccurrenceBaselineDiagnosis(
        cause: S17OccurrenceBlockerCause.authoredProgrammeInsufficientSlots,
        detail:
            'Authored executable slots=$authored '
            'lineage=${snap.lineageCode}; need ≥$requiredUncompleted. '
            '${isKnownOneSlot ? 'PROG-S13-ELIG is the Self-Test 1 one-slot package.' : ''}',
        canPrepareViaMultiSlotEnrolment: isKnownOneSlot,
      );
    }

    if (authored != null && snap.projectedOccurrenceCount < authored) {
      return S17OccurrenceBaselineDiagnosis(
        cause: S17OccurrenceBlockerCause.materialisationInsufficient,
        detail:
            'Projected ${snap.projectedOccurrenceCount} < authored $authored',
        canPrepareViaMultiSlotEnrolment: false,
      );
    }

    if (!snap.hasNullHorizon &&
        snap.projectedOccurrenceCount >= requiredUncompleted &&
        snap.uncompletedOccurrenceCount < requiredUncompleted) {
      return S17OccurrenceBaselineDiagnosis(
        cause: S17OccurrenceBlockerCause.horizonOrDateExclusion,
        detail: 'Horizon ${snap.schedulingHorizonEnd} may exclude occurrences',
        canPrepareViaMultiSlotEnrolment: false,
      );
    }

    // I→J preparation gate: current live baseline, not authored structure.
    if (snap.uncompletedOccurrenceCount < requiredUncompleted) {
      return S17OccurrenceBaselineDiagnosis(
        cause: S17OccurrenceBlockerCause
            .currentBaselineInsufficientExecutableOccurrences,
        detail:
            'Current uncompleted executable occurrences='
            '${snap.currentUncompletedExecutableOccurrenceCount} '
            'lineage=${snap.lineageCode}; need ≥$requiredUncompleted. '
            'This is a current-baseline insufficiency, not an authored '
            'programme slot-count proof.',
        canPrepareViaMultiSlotEnrolment: false,
      );
    }

    if (authored != null &&
        authored >= requiredUncompleted &&
        snap.projectedOccurrenceCount < requiredUncompleted) {
      return const S17OccurrenceBaselineDiagnosis(
        cause: S17OccurrenceBlockerCause.productDefect,
        detail:
            'Authored slots suffice but projection produced fewer occurrences',
        canPrepareViaMultiSlotEnrolment: false,
      );
    }

    return S17OccurrenceBaselineDiagnosis(
      cause: S17OccurrenceBlockerCause.incompleteBaseline,
      detail:
          'Uncompleted=${snap.uncompletedOccurrenceCount} '
          'projected=${snap.projectedOccurrenceCount} '
          'authored=${authored ?? 'not_evaluated'}',
      canPrepareViaMultiSlotEnrolment:
          snap.lineageCode == oneSlotCatalogueLineage,
    );
  }

  /// Fail-closed assertion used before F–J.
  static String? failClosedReason(
    S17OccurrenceBaselineSnapshot snap, {
    int requiredUncompleted = requiredUncompletedForScheduleOps,
  }) {
    if (snap.uncompletedOccurrenceCount >= requiredUncompleted &&
        snap.projectedOccurrenceCount >= requiredUncompleted) {
      return null;
    }
    final d = diagnose(snap, requiredUncompleted: requiredUncompleted);
    return 'BASELINE_FAIL cause=${d.cause.name} ${d.detail}';
  }
}
