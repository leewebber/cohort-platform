import '../../performance/models/active_performance_draft.dart';
import '../models/active_session_state.dart';
import '../models/production_restore_outcome.dart';
import '../models/production_session_draft.dart';
import '../models/production_session_ui_cursor.dart';
import '../presentation/production_restore_athlete_copy.dart';
import 'production_session_draft_classifier.dart';

/// Inputs for the single production restore authority.
class ProductionRestoreRequest {
  const ProductionRestoreRequest({
    required this.athleteId,
    required this.assignmentId,
    required this.programmeVersionId,
    required this.programmedSessionKey,
    required this.packageContentHash,
    this.occurrenceId,
    this.trainingSessionId,
    this.hostedCompleted = false,
    this.unavailable = false,
    this.transientNetworkFailure = false,
    this.jsonCorrupt = false,
    this.persistedIdentity,
    this.actuals,
    this.cursor,
    this.memoryState,
    this.legacySnapshotPresent = false,
  });

  final String athleteId;
  final String assignmentId;
  final String programmeVersionId;
  final String programmedSessionKey;
  final String packageContentHash;
  final String? occurrenceId;
  final int? trainingSessionId;
  final bool hostedCompleted;
  final bool unavailable;
  final bool transientNetworkFailure;
  final bool jsonCorrupt;
  final ProductionSessionDraft? persistedIdentity;
  final ActivePerformanceDraft? actuals;
  final ProductionSessionUiCursor? cursor;

  /// In-process cache only. Never authorizes resume.
  final ActiveSessionState? memoryState;

  /// Legacy WorkoutPlayer snapshot presence. Never authorizes resume.
  final bool legacySnapshotPresent;
}

class ProductionRestoreDecision {
  const ProductionRestoreDecision({
    required this.outcome,
    required this.athleteMessage,
    this.mayBeginFresh = false,
    this.mayEnterWithRestoredActuals = false,
    this.restoreCursor = false,
    this.discardMemory = true,
    this.suppressLegacySnapshot = true,
    this.identity,
    this.actuals,
    this.cursor,
    this.classification,
  });

  final ProductionRestoreOutcome outcome;
  final String athleteMessage;
  final bool mayBeginFresh;
  final bool mayEnterWithRestoredActuals;
  final bool restoreCursor;
  final bool discardMemory;
  final bool suppressLegacySnapshot;
  final ProductionSessionDraft? identity;
  final ActivePerformanceDraft? actuals;
  final ProductionSessionUiCursor? cursor;
  final ProductionDraftRestoreClass? classification;
}

/// Canonical production restore authority.
///
/// Durable actuals: [ActivePerformanceDraft].
/// Identity/integrity: [ProductionSessionDraft].
/// [AthleteSessionMemoryStore] and [WorkoutProgressSnapshot] cannot authorize.
class ProductionRestoreResolver {
  const ProductionRestoreResolver([
    this._classifier = const ProductionSessionDraftClassifier(),
  ]);

  final ProductionSessionDraftClassifier _classifier;

  ProductionRestoreDecision resolve(ProductionRestoreRequest request) {
    request.memoryState;
    request.legacySnapshotPresent;

    if (request.unavailable) {
      return ProductionRestoreDecision(
        outcome: ProductionRestoreOutcome.unavailable,
        athleteMessage: ProductionRestoreAthleteCopy.message(
          ProductionRestoreOutcome.unavailable,
        ),
      );
    }
    if (request.hostedCompleted) {
      return ProductionRestoreDecision(
        outcome: ProductionRestoreOutcome.completedHosted,
        athleteMessage: ProductionRestoreAthleteCopy.message(
          ProductionRestoreOutcome.completedHosted,
        ),
        identity: request.persistedIdentity,
        actuals: request.actuals,
        classification: ProductionDraftRestoreClass.completedHosted,
      );
    }
    if (request.transientNetworkFailure &&
        request.actuals == null &&
        request.persistedIdentity == null) {
      return ProductionRestoreDecision(
        outcome: ProductionRestoreOutcome.transientFailure,
        athleteMessage: ProductionRestoreAthleteCopy.message(
          ProductionRestoreOutcome.transientFailure,
        ),
      );
    }

    final actuals = request.actuals;
    if (actuals != null && actuals.athleteId != request.athleteId) {
      return ProductionRestoreDecision(
        outcome: ProductionRestoreOutcome.foreignAthlete,
        athleteMessage: ProductionRestoreAthleteCopy.message(
          ProductionRestoreOutcome.foreignAthlete,
        ),
        actuals: actuals,
        classification: ProductionDraftRestoreClass.foreignAthlete,
      );
    }

    if (request.jsonCorrupt) {
      return ProductionRestoreDecision(
        outcome: ProductionRestoreOutcome.corrupt,
        athleteMessage: ProductionRestoreAthleteCopy.message(
          ProductionRestoreOutcome.corrupt,
        ),
        classification: ProductionDraftRestoreClass.corrupt,
      );
    }

    if (actuals == null && request.persistedIdentity == null) {
      return ProductionRestoreDecision(
        outcome: ProductionRestoreOutcome.noDraft,
        athleteMessage: ProductionRestoreAthleteCopy.message(
          ProductionRestoreOutcome.noDraft,
        ),
        mayBeginFresh: true,
      );
    }

    if (actuals != null &&
        request.trainingSessionId != null &&
        actuals.trainingSessionId != request.trainingSessionId) {
      return ProductionRestoreDecision(
        outcome: ProductionRestoreOutcome.conflict,
        athleteMessage: ProductionRestoreAthleteCopy.message(
          ProductionRestoreOutcome.conflict,
        ),
        actuals: actuals,
      );
    }

    if (actuals != null &&
        actuals.assignmentId != null &&
        actuals.assignmentId!.isNotEmpty &&
        actuals.assignmentId != request.assignmentId) {
      return ProductionRestoreDecision(
        outcome: ProductionRestoreOutcome.staleOccurrence,
        athleteMessage: ProductionRestoreAthleteCopy.message(
          ProductionRestoreOutcome.staleOccurrence,
        ),
        actuals: actuals,
        classification: ProductionDraftRestoreClass.staleOccurrence,
      );
    }

    if (actuals != null &&
        actuals.programmeId != null &&
        actuals.programmeId!.isNotEmpty &&
        actuals.programmeId != request.programmeVersionId) {
      return ProductionRestoreDecision(
        outcome: ProductionRestoreOutcome.staleProgrammeVersion,
        athleteMessage: ProductionRestoreAthleteCopy.message(
          ProductionRestoreOutcome.staleProgrammeVersion,
        ),
        actuals: actuals,
        classification: ProductionDraftRestoreClass.staleProgrammeVersion,
      );
    }

    final identity = request.persistedIdentity ??
        (actuals == null
            ? null
            : _synthesizeIdentity(request, actuals));
    final authority = ProductionSessionDraftAuthority(
      athleteId: request.athleteId,
      assignmentId: request.assignmentId,
      programmeVersionId: request.programmeVersionId,
      programmedSessionKey: request.programmedSessionKey,
      occurrenceId: request.occurrenceId,
      hostedCompleted: request.hostedCompleted,
    );
    final classification = _classifier.classify(
      draft: identity,
      authority: authority,
    );

    final cursor = _acceptedCursor(request, actuals);

    switch (classification) {
      case ProductionDraftRestoreClass.compatible:
        return ProductionRestoreDecision(
          outcome: ProductionRestoreOutcome.resumable,
          athleteMessage: ProductionRestoreAthleteCopy.message(
            ProductionRestoreOutcome.resumable,
          ),
          mayEnterWithRestoredActuals: actuals != null,
          restoreCursor: cursor != null,
          identity: identity,
          actuals: actuals,
          cursor: cursor,
          classification: classification,
        );
      case ProductionDraftRestoreClass.legacyPartial:
        return ProductionRestoreDecision(
          outcome: ProductionRestoreOutcome.legacyPartiallyRecoverable,
          athleteMessage: ProductionRestoreAthleteCopy.message(
            ProductionRestoreOutcome.legacyPartiallyRecoverable,
          ),
          mayEnterWithRestoredActuals: actuals != null,
          restoreCursor: cursor != null,
          identity: identity,
          actuals: actuals,
          cursor: cursor,
          classification: classification,
        );
      case ProductionDraftRestoreClass.unsupportedFutureVersion:
        return ProductionRestoreDecision(
          outcome: ProductionRestoreOutcome.unsupportedVersion,
          athleteMessage: ProductionRestoreAthleteCopy.message(
            ProductionRestoreOutcome.unsupportedVersion,
          ),
          mayEnterWithRestoredActuals: false,
          restoreCursor: false,
          identity: identity,
          actuals: actuals,
          classification: classification,
        );
      case ProductionDraftRestoreClass.staleOccurrence:
        return ProductionRestoreDecision(
          outcome: ProductionRestoreOutcome.staleOccurrence,
          athleteMessage: ProductionRestoreAthleteCopy.message(
            ProductionRestoreOutcome.staleOccurrence,
          ),
          identity: identity,
          actuals: actuals,
          classification: classification,
        );
      case ProductionDraftRestoreClass.staleProgrammeVersion:
        return ProductionRestoreDecision(
          outcome: ProductionRestoreOutcome.staleProgrammeVersion,
          athleteMessage: ProductionRestoreAthleteCopy.message(
            ProductionRestoreOutcome.staleProgrammeVersion,
          ),
          identity: identity,
          actuals: actuals,
          classification: classification,
        );
      case ProductionDraftRestoreClass.foreignAthlete:
        return ProductionRestoreDecision(
          outcome: ProductionRestoreOutcome.foreignAthlete,
          athleteMessage: ProductionRestoreAthleteCopy.message(
          ProductionRestoreOutcome.foreignAthlete,
        ),
          identity: identity,
          actuals: actuals,
          classification: classification,
        );
      case ProductionDraftRestoreClass.completedHosted:
        return ProductionRestoreDecision(
          outcome: ProductionRestoreOutcome.completedHosted,
          athleteMessage: ProductionRestoreAthleteCopy.message(
          ProductionRestoreOutcome.completedHosted,
        ),
          identity: identity,
          actuals: actuals,
          classification: classification,
        );
      case ProductionDraftRestoreClass.corrupt:
        return ProductionRestoreDecision(
          outcome: ProductionRestoreOutcome.corrupt,
          athleteMessage: ProductionRestoreAthleteCopy.message(
            ProductionRestoreOutcome.corrupt,
          ),
          identity: identity,
          actuals: actuals,
          classification: classification,
        );
    }
  }

  ProductionSessionDraft _synthesizeIdentity(
    ProductionRestoreRequest request,
    ActivePerformanceDraft actuals,
  ) {
    return ProductionSessionDraft(
      schemaVersion: 0,
      athleteId: actuals.athleteId,
      assignmentId: actuals.assignmentId ?? request.assignmentId,
      programmeVersionId: actuals.programmeId ?? request.programmeVersionId,
      programmedSessionKey: request.programmedSessionKey,
      packageContentHash: request.packageContentHash,
      trainingSessionId: actuals.trainingSessionId,
      entryMode: 'live',
      occurrenceId: request.occurrenceId,
      startedAt: actuals.startedAt,
    );
  }

  ProductionSessionUiCursor? _acceptedCursor(
    ProductionRestoreRequest request,
    ActivePerformanceDraft? actuals,
  ) {
    final cursor = request.cursor;
    if (cursor == null || actuals == null) return null;
    if (cursor.isUnsupportedFutureVersion) return null;
    if (cursor.athleteId != request.athleteId) return null;
    if (cursor.trainingSessionId != actuals.trainingSessionId) return null;
    if (cursor.assignmentId != request.assignmentId) return null;
    if (request.occurrenceId != null &&
        cursor.occurrenceId != null &&
        cursor.occurrenceId != request.occurrenceId) {
      return null;
    }
    return cursor;
  }
}
