/// Diagnosis and fail-closed baseline for schedule-operation journeys (F–J).
///
/// B4b root cause: PROG-S13-ELIG is the Self-Test 1 one-slot package, so
/// ensure/restore correctly yields a single uncompleted occurrence. Horizon
/// and date filtering are not the cause.

/// Classifies why fewer than [requiredUncompleted] occurrences are available.
enum S17OccurrenceBlockerCause {
  /// Authored programme has fewer executable slots than required (B4b root cause).
  authoredProgrammeInsufficientSlots,

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

class S17OccurrenceBaselineSnapshot {
  const S17OccurrenceBaselineSnapshot({
    required this.authoredExecutableSlotCount,
    required this.projectedOccurrenceCount,
    required this.uncompletedOccurrenceCount,
    required this.completedOrSkippedCount,
    required this.lineageCode,
    this.schedulingHorizonEnd,
  });

  final int authoredExecutableSlotCount;
  final int projectedOccurrenceCount;
  final int uncompletedOccurrenceCount;
  final int completedOrSkippedCount;
  final String lineageCode;
  final String? schedulingHorizonEnd;

  bool get hasNullHorizon =>
      schedulingHorizonEnd == null || schedulingHorizonEnd!.trim().isEmpty;
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

    if (snap.authoredExecutableSlotCount < requiredUncompleted) {
      final isKnownOneSlot =
          snap.lineageCode == oneSlotCatalogueLineage ||
          snap.authoredExecutableSlotCount == 1;
      return S17OccurrenceBaselineDiagnosis(
        cause: S17OccurrenceBlockerCause.authoredProgrammeInsufficientSlots,
        detail:
            'Authored executable slots=${snap.authoredExecutableSlotCount} '
            'lineage=${snap.lineageCode}; need ≥$requiredUncompleted. '
            '${isKnownOneSlot ? 'PROG-S13-ELIG is the Self-Test 1 one-slot package.' : ''}',
        canPrepareViaMultiSlotEnrolment: isKnownOneSlot,
      );
    }

    if (snap.projectedOccurrenceCount < snap.authoredExecutableSlotCount) {
      return S17OccurrenceBaselineDiagnosis(
        cause: S17OccurrenceBlockerCause.materialisationInsufficient,
        detail:
            'Projected ${snap.projectedOccurrenceCount} < authored '
            '${snap.authoredExecutableSlotCount}',
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

    if (snap.authoredExecutableSlotCount >= requiredUncompleted &&
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
          'authored=${snap.authoredExecutableSlotCount}',
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
