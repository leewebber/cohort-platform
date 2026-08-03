import '../../session_occurrence/value_objects/session_occurrence_date.dart';
import '../models/programme_schedule_projection.dart';
import '../models/programme_scheduling_preview.dart';
import '../models/programme_scheduling_requests.dart';
import '../models/programme_scheduling_snapshot.dart';
import '../models/scheduled_programme_occurrence.dart';
import '../policy/programme_scheduling_policy.dart';
import '../support/programme_scheduling_preview_fingerprint.dart';
import '../support/session_occurrence_date_arithmetic.dart';
import '../vocabulary/programme_schedule_disposition.dart';
import '../vocabulary/programme_scheduling_operation_type.dart';
import '../vocabulary/programme_scheduling_preview_code.dart';
import '../value_objects/scheduled_occurrence_identity.dart';

/// Authoritative compute-only scheduling preview owner (Sprint 1.7B).
///
/// Accepts an immutable snapshot + one operation request.
/// Performs no repository, cache, RPC, or database writes.
/// Never mutates the input projection.
class ProgrammeSchedulingPreviewEngine {
  const ProgrammeSchedulingPreviewEngine({
    this.policy = const ProgrammeSchedulingPolicy(),
  });

  final ProgrammeSchedulingPolicy policy;

  ProgrammeSchedulingPreviewResult preview({
    required ProgrammeSchedulingSnapshot snapshot,
    required ProgrammeSchedulingRequest request,
  }) {
    final assignmentDecision = policy.evaluateAssignment(snapshot);
    if (!assignmentDecision.isAllowed) {
      return ProgrammeSchedulingPreviewResult.ineligible(
        assignmentDecision.code,
        detail: assignmentDecision.detail,
      );
    }

    final consistency = _validateProjectionConsistency(snapshot);
    if (consistency != null) return consistency;

    return switch (request) {
      ProgrammeSchedulingMoveRequest(:final sessionSlotId, :final targetDate) =>
        _previewMove(snapshot, sessionSlotId, targetDate),
      ProgrammeSchedulingSwapRequest(
        :final sessionSlotIdA,
        :final sessionSlotIdB,
      ) =>
        _previewSwap(snapshot, sessionSlotIdA, sessionSlotIdB),
      ProgrammeSchedulingPushRequest(
        :final fromSessionSlotId,
        :final dayDelta,
      ) =>
        _previewPush(snapshot, fromSessionSlotId, dayDelta),
      ProgrammeSchedulingSkipRequest(:final sessionSlotId) =>
        _previewSkip(snapshot, sessionSlotId),
    };
  }

  ProgrammeSchedulingPreviewResult? _validateProjectionConsistency(
    ProgrammeSchedulingSnapshot snapshot,
  ) {
    final seen = <String>{};
    for (final occurrence in snapshot.projection.occurrences) {
      final id = occurrence.identity;
      if (id.assignmentId != snapshot.assignmentId ||
          id.programmeVersionId != snapshot.programmeVersionId ||
          id.packageContentHash != snapshot.packageContentHash) {
        return ProgrammeSchedulingPreviewResult.ineligible(
          ProgrammeSchedulingPreviewCode.provenanceMismatch,
          detail: 'Occurrence provenance does not match snapshot.',
        );
      }
      if (!seen.add(id.sessionSlotId)) {
        return ProgrammeSchedulingPreviewResult.ineligible(
          ProgrammeSchedulingPreviewCode.inconsistentProjection,
          detail: 'Duplicate sessionSlotId in projection.',
        );
      }
    }
    return null;
  }

  ProgrammeSchedulingPreviewResult _previewMove(
    ProgrammeSchedulingSnapshot snapshot,
    String sessionSlotId,
    SessionOccurrenceDate targetDate,
  ) {
    final source = snapshot.projection.bySlotId(sessionSlotId);
    if (source == null) {
      return ProgrammeSchedulingPreviewResult.ineligible(
        ProgrammeSchedulingPreviewCode.occurrenceNotFound,
      );
    }

    final eligibility = policy.evaluateOccurrenceEligibility(
      source,
      allowSkipped: false,
    );
    if (!eligibility.isAllowed) {
      return ProgrammeSchedulingPreviewResult.ineligible(
        eligibility.code,
        detail: eligibility.detail,
      );
    }

    final dateDecision = policy.evaluateTargetDate(
      targetDate: targetDate,
      startedAt: snapshot.startedAt,
    );
    if (!dateDecision.isAllowed) {
      return ProgrammeSchedulingPreviewResult.ineligible(
        dateDecision.code,
        detail: dateDecision.detail,
      );
    }

    if (source.scheduledDate == targetDate) {
      return ProgrammeSchedulingPreviewResult.ineligible(
        ProgrammeSchedulingPreviewCode.noChange,
        detail: 'Move target equals current scheduled date.',
      );
    }

    final proposed = source.copyWith(scheduledDate: targetDate);
    final proposedProjection = snapshot.projection.replacing({
      sessionSlotId: proposed,
    });
    final changes = [
      ProgrammeSchedulingOccurrenceChange(
        identity: source.identity,
        originalDate: source.scheduledDate,
        proposedDate: targetDate,
        originalDisposition: source.disposition,
        proposedDisposition: source.disposition,
      ),
    ];
    final impacts = _buildImpacts(
      snapshot: snapshot,
      proposedProjection: proposedProjection,
      affected: [proposed],
    );

    return _ready(
      snapshot: snapshot,
      requestCanonical: ProgrammeSchedulingMoveRequest(
        sessionSlotId: sessionSlotId,
        targetDate: targetDate,
      ).toCanonicalMap(),
      proposedProjection: proposedProjection,
      changes: changes,
      impacts: impacts,
      operationType: ProgrammeSchedulingOperationType.move,
    );
  }

  ProgrammeSchedulingPreviewResult _previewSwap(
    ProgrammeSchedulingSnapshot snapshot,
    String sessionSlotIdA,
    String sessionSlotIdB,
  ) {
    if (sessionSlotIdA == sessionSlotIdB) {
      return ProgrammeSchedulingPreviewResult.ineligible(
        ProgrammeSchedulingPreviewCode.swapRequiresDistinctOccurrences,
      );
    }

    final a = snapshot.projection.bySlotId(sessionSlotIdA);
    final b = snapshot.projection.bySlotId(sessionSlotIdB);
    if (a == null || b == null) {
      return ProgrammeSchedulingPreviewResult.ineligible(
        ProgrammeSchedulingPreviewCode.occurrenceNotFound,
      );
    }

    if (!_sameProvenance(a.identity, b.identity) ||
        a.identity.assignmentId != snapshot.assignmentId ||
        a.identity.programmeVersionId != snapshot.programmeVersionId ||
        a.identity.packageContentHash != snapshot.packageContentHash) {
      return ProgrammeSchedulingPreviewResult.ineligible(
        ProgrammeSchedulingPreviewCode.crossAssignmentOrVersionSwap,
      );
    }

    for (final occurrence in [a, b]) {
      final eligibility = policy.evaluateOccurrenceEligibility(
        occurrence,
        allowSkipped: false,
      );
      if (!eligibility.isAllowed) {
        return ProgrammeSchedulingPreviewResult.ineligible(
          eligibility.code,
          detail: eligibility.detail,
        );
      }
    }

    if (a.scheduledDate == b.scheduledDate) {
      return ProgrammeSchedulingPreviewResult.ineligible(
        ProgrammeSchedulingPreviewCode.noChange,
        detail: 'Swap dates are identical.',
      );
    }

    final proposedA = a.copyWith(scheduledDate: b.scheduledDate);
    final proposedB = b.copyWith(scheduledDate: a.scheduledDate);
    final proposedProjection = snapshot.projection.replacing({
      sessionSlotIdA: proposedA,
      sessionSlotIdB: proposedB,
    });
    final changes =
        [
          ProgrammeSchedulingOccurrenceChange(
            identity: a.identity,
            originalDate: a.scheduledDate,
            proposedDate: proposedA.scheduledDate,
            originalDisposition: a.disposition,
            proposedDisposition: a.disposition,
          ),
          ProgrammeSchedulingOccurrenceChange(
            identity: b.identity,
            originalDate: b.scheduledDate,
            proposedDate: proposedB.scheduledDate,
            originalDisposition: b.disposition,
            proposedDisposition: b.disposition,
          ),
        ]..sort(
          (x, y) => x.identity.authoredOrderKey.compareTo(
            y.identity.authoredOrderKey,
          ),
        );

    final impacts = _buildImpacts(
      snapshot: snapshot,
      proposedProjection: proposedProjection,
      affected: [proposedA, proposedB],
    );

    return _ready(
      snapshot: snapshot,
      requestCanonical: ProgrammeSchedulingSwapRequest(
        sessionSlotIdA: sessionSlotIdA,
        sessionSlotIdB: sessionSlotIdB,
      ).toCanonicalMap(),
      proposedProjection: proposedProjection,
      changes: changes,
      impacts: impacts,
      operationType: ProgrammeSchedulingOperationType.swap,
    );
  }

  ProgrammeSchedulingPreviewResult _previewPush(
    ProgrammeSchedulingSnapshot snapshot,
    String fromSessionSlotId,
    int dayDelta,
  ) {
    final distance = policy.evaluatePushDistance(dayDelta);
    if (!distance.isAllowed) {
      return ProgrammeSchedulingPreviewResult.ineligible(
        distance.code,
        detail: distance.detail,
      );
    }

    final source = snapshot.projection.bySlotId(fromSessionSlotId);
    if (source == null) {
      return ProgrammeSchedulingPreviewResult.ineligible(
        ProgrammeSchedulingPreviewCode.occurrenceNotFound,
      );
    }

    final eligibility = policy.evaluateOccurrenceEligibility(
      source,
      allowSkipped: false,
    );
    if (!eligibility.isAllowed) {
      return ProgrammeSchedulingPreviewResult.ineligible(
        eligibility.code,
        detail: eligibility.detail,
      );
    }

    final affectedOriginals = snapshot.projection.uncompletedFrom(
      source.identity,
    );
    if (affectedOriginals.isEmpty) {
      return ProgrammeSchedulingPreviewResult.ineligible(
        ProgrammeSchedulingPreviewCode.occurrenceNotFound,
      );
    }

    final replacements = <String, ScheduledProgrammeOccurrence>{};
    final changes = <ProgrammeSchedulingOccurrenceChange>[];
    for (final original in affectedOriginals) {
      final proposedDate = original.scheduledDate.addCalendarDays(dayDelta);
      final dateDecision = policy.evaluateTargetDate(
        targetDate: proposedDate,
        startedAt: snapshot.startedAt,
      );
      if (!dateDecision.isAllowed) {
        return ProgrammeSchedulingPreviewResult.ineligible(
          dateDecision.code,
          detail: dateDecision.detail,
        );
      }
      final horizon = policy.evaluateHorizon(
        proposedDate: proposedDate,
        horizonEnd: snapshot.schedulingHorizonEnd,
      );
      if (!horizon.isAllowed) {
        return ProgrammeSchedulingPreviewResult.ineligible(
          horizon.code,
          detail: 'Push would exceed programme scheduling horizon.',
        );
      }
      final proposed = original.copyWith(scheduledDate: proposedDate);
      replacements[original.identity.sessionSlotId] = proposed;
      changes.add(
        ProgrammeSchedulingOccurrenceChange(
          identity: original.identity,
          originalDate: original.scheduledDate,
          proposedDate: proposedDate,
          originalDisposition: original.disposition,
          proposedDisposition: original.disposition,
        ),
      );
    }

    final proposedProjection = snapshot.projection.replacing(replacements);
    final impacts = _buildImpacts(
      snapshot: snapshot,
      proposedProjection: proposedProjection,
      affected: replacements.values.toList(growable: false),
    );

    return _ready(
      snapshot: snapshot,
      requestCanonical: ProgrammeSchedulingPushRequest(
        fromSessionSlotId: fromSessionSlotId,
        dayDelta: dayDelta,
      ).toCanonicalMap(),
      proposedProjection: proposedProjection,
      changes: changes,
      impacts: impacts,
      operationType: ProgrammeSchedulingOperationType.push,
    );
  }

  ProgrammeSchedulingPreviewResult _previewSkip(
    ProgrammeSchedulingSnapshot snapshot,
    String sessionSlotId,
  ) {
    final source = snapshot.projection.bySlotId(sessionSlotId);
    if (source == null) {
      return ProgrammeSchedulingPreviewResult.ineligible(
        ProgrammeSchedulingPreviewCode.occurrenceNotFound,
      );
    }

    if (source.isSkipped) {
      return ProgrammeSchedulingPreviewResult.ineligible(
        ProgrammeSchedulingPreviewCode.occurrenceAlreadySkipped,
      );
    }
    if (source.isCompleted) {
      return ProgrammeSchedulingPreviewResult.ineligible(
        ProgrammeSchedulingPreviewCode.occurrenceCompleted,
      );
    }
    if (source.hasInFlightExecution) {
      return ProgrammeSchedulingPreviewResult.ineligible(
        ProgrammeSchedulingPreviewCode.inFlightExecution,
      );
    }

    final proposed = source.copyWith(
      disposition: ProgrammeScheduleDisposition.skipped,
    );
    final proposedProjection = snapshot.projection.replacing({
      sessionSlotId: proposed,
    });
    final changes = [
      ProgrammeSchedulingOccurrenceChange(
        identity: source.identity,
        originalDate: source.scheduledDate,
        proposedDate: source.scheduledDate,
        originalDisposition: source.disposition,
        proposedDisposition: ProgrammeScheduleDisposition.skipped,
      ),
    ];

    final nextDue = _nextUncompletedAfterSkip(
      proposedProjection,
      skippedSlotId: sessionSlotId,
    );
    final impacts = <ProgrammeSchedulingImpact>[
      ProgrammeSchedulingImpact(
        kind: ProgrammeSchedulingImpactKind.skipDispositionProposed,
        message:
            'Skip proposes scheduling/adherence disposition skipped; '
            'no completion record or actuals.',
        sessionSlotId: sessionSlotId,
      ),
      if (snapshot.preparedProgrammedSessionKeys.contains(
        source.identity.programmedSessionKey,
      ))
        ProgrammeSchedulingImpact(
          kind: ProgrammeSchedulingImpactKind.preparedOccurrenceAffected,
          message:
              'Prepared state for this occurrence would be cleared if applied.',
          sessionSlotId: sessionSlotId,
        ),
      if (snapshot.adaptedProgrammedSessionKeys.contains(
        source.identity.programmedSessionKey,
      ))
        ProgrammeSchedulingImpact(
          kind:
              ProgrammeSchedulingImpactKind.adaptedPreparedOccurrenceAffected,
          message: 'Adapted prepared execution would be discarded if applied.',
          sessionSlotId: sessionSlotId,
        ),
      if (snapshot.pendingAdaptationProposalKeys.contains(
        source.identity.programmedSessionKey,
      ))
        ProgrammeSchedulingImpact(
          kind: ProgrammeSchedulingImpactKind
              .pendingAdaptationProposalWouldBeDiscarded,
          message:
              'Pending adaptation proposal would be discarded; consumed '
              'proposal IDs remain consumed.',
          sessionSlotId: sessionSlotId,
        ),
      if (snapshot.consumedAdaptationProposalIds.isNotEmpty)
        ProgrammeSchedulingImpact(
          kind: ProgrammeSchedulingImpactKind.consumedProposalIdsRemainConsumed,
          message: 'Consumed adaptation proposal IDs remain consumed.',
          relatedSlotIds: snapshot.consumedAdaptationProposalIds.toList()
            ..sort(),
        ),
      ProgrammeSchedulingImpact(
        kind: ProgrammeSchedulingImpactKind.cursorWouldAdvanceTo,
        message: nextDue == null
            ? 'Cursor would clear (no remaining uncompleted occurrence).'
            : 'Cursor would advance to next uncompleted authored occurrence.',
        sessionSlotId: nextDue?.identity.sessionSlotId,
      ),
      ProgrammeSchedulingImpact(
        kind: ProgrammeSchedulingImpactKind.undoPolicyNote,
        message:
            'Undo eligibility window is ${policy.undoTtlAthleteLocalHours} '
            'athlete-local hours after successful apply (not persisted here).',
      ),
    ];

    return _ready(
      snapshot: snapshot,
      requestCanonical: ProgrammeSchedulingSkipRequest(
        sessionSlotId: sessionSlotId,
      ).toCanonicalMap(),
      proposedProjection: proposedProjection,
      changes: changes,
      impacts: impacts,
      operationType: ProgrammeSchedulingOperationType.skip,
    );
  }

  List<ProgrammeSchedulingImpact> _buildImpacts({
    required ProgrammeSchedulingSnapshot snapshot,
    required ProgrammeScheduleProjection proposedProjection,
    required List<ScheduledProgrammeOccurrence> affected,
  }) {
    final impacts = <ProgrammeSchedulingImpact>[];
    final collidingDates = _collidingDates(proposedProjection);
    for (final date in collidingDates) {
      final slots = proposedProjection.occurrences
          .where((o) => o.isUncompleted && o.scheduledDate == date)
          .map((o) => o.identity.sessionSlotId)
          .toList(growable: false);
      impacts.add(
        ProgrammeSchedulingImpact(
          kind: ProgrammeSchedulingImpactKind.multiSessionDateCollision,
          message: 'Multiple uncompleted occurrences share $date (allowed).',
          date: date,
          relatedSlotIds: slots,
        ),
      );
    }

    for (final occurrence in affected) {
      final key = occurrence.identity.programmedSessionKey;
      final slotId = occurrence.identity.sessionSlotId;
      if (occurrence.scheduledDate.isBefore(snapshot.today)) {
        impacts.add(
          ProgrammeSchedulingImpact(
            kind: ProgrammeSchedulingImpactKind.becomesOverdue,
            message:
                'Occurrence placed before today remains uncompleted and '
                'becomes overdue; no completion or actuals are fabricated.',
            sessionSlotId: slotId,
            date: occurrence.scheduledDate,
          ),
        );
      }
      if (snapshot.preparedProgrammedSessionKeys.contains(key)) {
        impacts.add(
          ProgrammeSchedulingImpact(
            kind: ProgrammeSchedulingImpactKind.preparedOccurrenceAffected,
            message:
                'Prepared state would be cleared if this operation were applied.',
            sessionSlotId: slotId,
          ),
        );
      }
      if (snapshot.adaptedProgrammedSessionKeys.contains(key)) {
        impacts.add(
          ProgrammeSchedulingImpact(
            kind: ProgrammeSchedulingImpactKind
                .adaptedPreparedOccurrenceAffected,
            message: 'Adapted prepared execution would be discarded if applied.',
            sessionSlotId: slotId,
          ),
        );
      }
      if (snapshot.pendingAdaptationProposalKeys.contains(key)) {
        impacts.add(
          ProgrammeSchedulingImpact(
            kind: ProgrammeSchedulingImpactKind
                .pendingAdaptationProposalWouldBeDiscarded,
            message:
                'Pending adaptation proposal would be discarded; consumed '
                'proposal IDs remain consumed.',
            sessionSlotId: slotId,
          ),
        );
      }
    }

    if (snapshot.consumedAdaptationProposalIds.isNotEmpty &&
        impacts.any(
          (i) =>
              i.kind ==
                  ProgrammeSchedulingImpactKind
                      .pendingAdaptationProposalWouldBeDiscarded ||
              i.kind ==
                  ProgrammeSchedulingImpactKind.preparedOccurrenceAffected,
        )) {
      impacts.add(
        ProgrammeSchedulingImpact(
          kind: ProgrammeSchedulingImpactKind.consumedProposalIdsRemainConsumed,
          message: 'Consumed adaptation proposal IDs remain consumed.',
          relatedSlotIds: snapshot.consumedAdaptationProposalIds.toList()
            ..sort(),
        ),
      );
    }

    impacts.add(
      ProgrammeSchedulingImpact(
        kind: ProgrammeSchedulingImpactKind.undoPolicyNote,
        message:
            'Undo eligibility window is ${policy.undoTtlAthleteLocalHours} '
            'athlete-local hours after successful apply (not persisted here).',
      ),
    );

    return List.unmodifiable(impacts);
  }

  List<SessionOccurrenceDate> _collidingDates(
    ProgrammeScheduleProjection projection,
  ) {
    final counts = <SessionOccurrenceDate, int>{};
    for (final occurrence in projection.occurrences) {
      if (!occurrence.isUncompleted) continue;
      counts.update(
        occurrence.scheduledDate,
        (c) => c + 1,
        ifAbsent: () => 1,
      );
    }
    final colliding =
        counts.entries.where((e) => e.value > 1).map((e) => e.key).toList()
          ..sort((a, b) => a.compareTo(b));
    return List.unmodifiable(colliding);
  }

  ScheduledProgrammeOccurrence? _nextUncompletedAfterSkip(
    ProgrammeScheduleProjection projection, {
    required String skippedSlotId,
  }) {
    final skipped = projection.bySlotId(skippedSlotId);
    if (skipped == null) return null;
    for (final occurrence in projection.occurrences) {
      if (!occurrence.isUncompleted) continue;
      if (occurrence.identity.authoredOrderKey >
          skipped.identity.authoredOrderKey) {
        return occurrence;
      }
    }
    for (final occurrence in projection.occurrences) {
      if (occurrence.isUncompleted) return occurrence;
    }
    return null;
  }

  bool _sameProvenance(
    ScheduledOccurrenceIdentity a,
    ScheduledOccurrenceIdentity b,
  ) {
    return a.assignmentId == b.assignmentId &&
        a.programmeVersionId == b.programmeVersionId &&
        a.packageContentHash == b.packageContentHash;
  }

  ProgrammeSchedulingPreviewResult _ready({
    required ProgrammeSchedulingSnapshot snapshot,
    required Map<String, Object?> requestCanonical,
    required ProgrammeScheduleProjection proposedProjection,
    required List<ProgrammeSchedulingOccurrenceChange> changes,
    required List<ProgrammeSchedulingImpact> impacts,
    required ProgrammeSchedulingOperationType operationType,
  }) {
    final collidingDates = _collidingDates(proposedProjection);
    final fingerprintPayload = <String, Object?>{
      'operation': requestCanonical,
      'assignmentId': snapshot.assignmentId,
      'programmeVersionId': snapshot.programmeVersionId,
      'packageContentHash': snapshot.packageContentHash,
      'scheduleRevision': snapshot.projection.scheduleRevision,
      'timezone': snapshot.timezone,
      'policyVersion': policy.version,
      'affected': changes.map((c) => c.toCanonicalMap()).toList(),
      'impacts': impacts.map((i) => i.toCanonicalMap()).toList(),
      'collidingDates': collidingDates.map((d) => d.toString()).toList(),
    };
    final fingerprint = ProgrammeSchedulingPreviewFingerprint.compute(
      fingerprintPayload,
    );

    return ProgrammeSchedulingPreviewResult.ready(
      ProgrammeSchedulingPreview(
        operationType: operationType,
        fingerprint: fingerprint,
        proposedProjection: proposedProjection,
        changes: List.unmodifiable(changes),
        impacts: List.unmodifiable(impacts),
        collidingDates: collidingDates,
      ),
    );
  }
}
