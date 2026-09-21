import '../models/production_restore_outcome.dart';

/// Athlete-facing restore copy. Technical outcome names stay in preview harness.
class ProductionRestoreAthleteCopy {
  const ProductionRestoreAthleteCopy._();

  static const foreignAthleteTitle = 'This saved workout belongs to another account.';
  static const foreignAthleteBody =
      'It cannot be opened here. Nothing from that account is shown.';
  static const staleOccurrenceTitle = 'This draft is from a different scheduled session.';
  static const staleOccurrenceBody =
      'Your current schedule is unchanged. Return Home or open Calendar to continue with today’s session.';
  static const staleVersionTitle = 'This draft is from a previous programme version.';
  static const staleVersionBody =
      'Your current schedule is unchanged. Return Home or open Calendar to continue with today’s session.';
  static const corruptTitle = 'Draft cannot be safely restored';
  static const corruptBody =
      'This draft is damaged and cannot be opened. Your hosted results are unchanged. A new session is not started.';
  static const unsupportedTitle = 'Draft cannot be safely restored';
  static const unsupportedBody =
      'This draft was saved in a newer app version and cannot be opened here. A new session is not started.';
  static const unsafeLegacyTitle = 'Draft cannot be safely restored';
  static const unsafeLegacyBody =
      'An older in-progress snapshot cannot be opened as a workout. Captured results are not discarded. A new session is not started.';
  static const legacyPartialTitle = 'Some details can be recovered';
  static const legacyPartialBody =
      'Your captured results are kept. Position may start at the first incomplete movement.';
  static const completionPendingTitle = 'Completion pending';
  static const completionPendingBody =
      'Your entered results remain saved on this phone. Retry will not start a new workout.';
  static const completionReconciledTitle = 'This session was already saved.';
  static const completionReconciledBody =
      'Your results are in training history. Nothing else needs to be submitted.';
  static const returnHome = 'Return to Home';
  static const continueSafely = 'Continue safely';
  static const openCalendar = 'Open Calendar';
  static const switchAccount = 'Switch account';
  static const discardDraft = 'Discard local draft';
  static const discardDraftConfirm =
      'This removes only the local restore envelope. Entered results are not deleted.';
  static const retry = 'Retry';
  static const returnToSession = 'Return to session';

  static String message(ProductionRestoreOutcome outcome) {
    return switch (outcome) {
      ProductionRestoreOutcome.foreignAthlete => foreignAthleteTitle,
      ProductionRestoreOutcome.staleOccurrence => staleOccurrenceTitle,
      ProductionRestoreOutcome.staleProgrammeVersion => staleVersionTitle,
      ProductionRestoreOutcome.corrupt => corruptTitle,
      ProductionRestoreOutcome.unsupportedVersion => unsupportedTitle,
      ProductionRestoreOutcome.legacyPartiallyRecoverable =>
        'Restoring your session',
      ProductionRestoreOutcome.resumable => 'Restoring your session',
      ProductionRestoreOutcome.noDraft => "Preparing today's session",
      ProductionRestoreOutcome.completedHosted => 'Session already completed',
      ProductionRestoreOutcome.unavailable =>
        'This session format is not available yet.',
      ProductionRestoreOutcome.transientFailure => 'Waiting for connection',
      ProductionRestoreOutcome.conflict => corruptTitle,
    };
  }

  static String title(ProductionRestoreOutcome outcome) {
    return switch (outcome) {
      ProductionRestoreOutcome.foreignAthlete => foreignAthleteTitle,
      ProductionRestoreOutcome.staleOccurrence => staleOccurrenceTitle,
      ProductionRestoreOutcome.staleProgrammeVersion => staleVersionTitle,
      ProductionRestoreOutcome.corrupt ||
      ProductionRestoreOutcome.conflict =>
        corruptTitle,
      ProductionRestoreOutcome.unsupportedVersion => unsupportedTitle,
      ProductionRestoreOutcome.legacyPartiallyRecoverable =>
        legacyPartialTitle,
      _ => message(outcome),
    };
  }

  static String body(ProductionRestoreOutcome outcome) {
    return switch (outcome) {
      ProductionRestoreOutcome.foreignAthlete => foreignAthleteBody,
      ProductionRestoreOutcome.staleOccurrence => staleOccurrenceBody,
      ProductionRestoreOutcome.staleProgrammeVersion => staleVersionBody,
      ProductionRestoreOutcome.corrupt ||
      ProductionRestoreOutcome.conflict =>
        corruptBody,
      ProductionRestoreOutcome.unsupportedVersion => unsupportedBody,
      ProductionRestoreOutcome.legacyPartiallyRecoverable =>
        legacyPartialBody,
      _ => message(outcome),
    };
  }

  static bool isBlocked(ProductionRestoreOutcome outcome) {
    return switch (outcome) {
      ProductionRestoreOutcome.staleOccurrence ||
      ProductionRestoreOutcome.staleProgrammeVersion ||
      ProductionRestoreOutcome.foreignAthlete ||
      ProductionRestoreOutcome.corrupt ||
      ProductionRestoreOutcome.unsupportedVersion ||
      ProductionRestoreOutcome.conflict ||
      ProductionRestoreOutcome.unavailable =>
        true,
      _ => false,
    };
  }

  static bool mayContinueSafely(ProductionRestoreOutcome outcome) {
    return outcome == ProductionRestoreOutcome.legacyPartiallyRecoverable;
  }

  static bool offersCalendar(ProductionRestoreOutcome outcome) {
    return outcome == ProductionRestoreOutcome.staleOccurrence ||
        outcome == ProductionRestoreOutcome.staleProgrammeVersion;
  }

  static bool offersSwitchAccount(ProductionRestoreOutcome outcome) {
    return outcome == ProductionRestoreOutcome.foreignAthlete;
  }

  static bool offersDiscard(ProductionRestoreOutcome outcome) {
    return outcome == ProductionRestoreOutcome.corrupt ||
        outcome == ProductionRestoreOutcome.unsupportedVersion ||
        outcome == ProductionRestoreOutcome.conflict;
  }
}
