import '../../performance/models/active_performance_draft.dart';
import '../../performance/models/training_session_record.dart';

enum BackfillProgrammeSessionStatus { saved, rejected, conflict, failed }

class BackfillPerformedDateDecision {
  const BackfillPerformedDateDecision({
    required this.accepted,
    this.code,
    this.message,
  });

  final bool accepted;
  final String? code;
  final String? message;

  static const acceptedOk = BackfillPerformedDateDecision(accepted: true);
}

abstract final class BackfillPerformedDatePolicy {
  static const dateHelp =
      'This records when you performed the session. Cohort will also retain when the results were entered.';

  static BackfillPerformedDateDecision validate({
    required String scheduledDate,
    required String performedOn,
    required String today,
    required String assignmentStart,
    String? assignmentEnd,
  }) {
    if (!_isIsoDate(scheduledDate) ||
        !_isIsoDate(performedOn) ||
        !_isIsoDate(today) ||
        !_isIsoDate(assignmentStart)) {
      return const BackfillPerformedDateDecision(
        accepted: false,
        code: 'invalid_date',
        message: 'Choose a valid performance date.',
      );
    }
    if (performedOn.compareTo(scheduledDate) < 0) {
      return const BackfillPerformedDateDecision(
        accepted: false,
        code: 'before_scheduled',
        message: 'The performance date cannot be before the scheduled date.',
      );
    }
    if (performedOn.compareTo(today) > 0) {
      return const BackfillPerformedDateDecision(
        accepted: false,
        code: 'future_date',
        message: 'The performance date cannot be in the future.',
      );
    }
    if (performedOn.compareTo(assignmentStart) < 0) {
      return const BackfillPerformedDateDecision(
        accepted: false,
        code: 'before_assignment',
        message: 'The performance date is outside this programme assignment.',
      );
    }
    if (assignmentEnd != null &&
        _isIsoDate(assignmentEnd) &&
        performedOn.compareTo(assignmentEnd) > 0) {
      return const BackfillPerformedDateDecision(
        accepted: false,
        code: 'after_assignment',
        message: 'The performance date is outside this programme assignment.',
      );
    }
    return BackfillPerformedDateDecision.acceptedOk;
  }

  static bool _isIsoDate(String value) {
    return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value);
  }
}

class BackfillProgrammeSessionCommand {
  const BackfillProgrammeSessionCommand({
    required this.athleteId,
    required this.assignmentId,
    required this.occurrenceId,
    required this.scheduledDate,
    required this.performedOn,
    required this.timezone,
    required this.idempotencyKey,
    required this.draft,
  });

  final String athleteId;
  final String assignmentId;
  final String occurrenceId;
  final String scheduledDate;
  final String performedOn;
  final String timezone;
  final String idempotencyKey;
  final ActivePerformanceDraft draft;
}

class BackfillProgrammeSessionResult {
  const BackfillProgrammeSessionResult({
    required this.status,
    this.code,
    this.message,
    this.record,
  });

  final BackfillProgrammeSessionStatus status;
  final String? code;
  final String? message;
  final TrainingSessionRecord? record;

  bool get isSaved => status == BackfillProgrammeSessionStatus.saved;
}
