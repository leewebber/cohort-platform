/// Explicit overdue recovery command. Late execution is not a reschedule.
class OverdueProgrammeRecoveryCommand {
  const OverdueProgrammeRecoveryCommand({
    required this.assignmentId,
    required this.sourceOccurrenceId,
    required this.operation,
    required this.idempotencyKey,
    this.destinationDate,
    this.counterpartOccurrenceId,
    this.expectedSourceDate,
    this.expectedDestinationDate,
    this.expectedScheduleRevision,
    this.reason,
  });

  final String assignmentId;
  final String sourceOccurrenceId;
  final OverdueProgrammeRecoveryOperation operation;
  final String idempotencyKey;
  final String? destinationDate;
  final String? counterpartOccurrenceId;
  final String? expectedSourceDate;
  final String? expectedDestinationDate;
  final int? expectedScheduleRevision;
  final String? reason;

  Map<String, Object?> toRpcPayload() => {
    'assignment_id': assignmentId,
    'source_occurrence_id': sourceOccurrenceId,
    'operation': operation.wireValue,
    'idempotency_key': idempotencyKey,
    if (destinationDate != null) 'destination_date': destinationDate,
    if (counterpartOccurrenceId != null)
      'counterpart_occurrence_id': counterpartOccurrenceId,
    if (expectedSourceDate != null) 'expected_source_date': expectedSourceDate,
    if (expectedDestinationDate != null)
      'expected_destination_date': expectedDestinationDate,
    if (expectedScheduleRevision != null)
      'expected_schedule_revision': expectedScheduleRevision,
    if (reason != null) 'reason': reason,
  };
}

enum OverdueProgrammeRecoveryOperation {
  move('move'),
  swap('swap'),
  skip('skip');

  const OverdueProgrammeRecoveryOperation(this.wireValue);
  final String wireValue;
}

enum OverdueProgrammeRecoveryStatus {
  applied,
  alreadyApplied,
  rejected,
  failed,
}

class OverdueProgrammeRecoveryResult {
  const OverdueProgrammeRecoveryResult({
    required this.status,
    this.code,
    this.message,
    this.operationType,
    this.originalDate,
    this.resultingDate,
    this.scheduleRevision,
  });

  final OverdueProgrammeRecoveryStatus status;
  final String? code;
  final String? message;
  final String? operationType;
  final String? originalDate;
  final String? resultingDate;
  final int? scheduleRevision;

  bool get isSuccess =>
      status == OverdueProgrammeRecoveryStatus.applied ||
      status == OverdueProgrammeRecoveryStatus.alreadyApplied;

  String get athleteVisibleMessage {
    final provided = message?.trim();
    if (provided != null && provided.isNotEmpty) return provided;
    return athleteVisibleMessageForCode(code);
  }

  static String athleteVisibleMessageForCode(String? code) {
    return switch (code) {
      'destination_outside_horizon' =>
        'You can reschedule an overdue session into the next 7 days.',
      'destination_in_past' =>
        'Choose today or a future date in the next 7 days.',
      'destination_after_assignment_end' =>
        'That date is after this programme ends.',
      'destination_occupied' =>
        'That date already has a session. Swap it, or choose an empty day.',
      'destination_completed' =>
        'A completed session is already on that date and cannot be moved.',
      'destination_in_progress' =>
        'Finish the session already in progress on that date before swapping.',
      'occurrence_in_progress' => 'Finish this session before rescheduling it.',
      'occurrence_completed' => 'That session is already completed.',
      'source_not_overdue' =>
        'Only an overdue session can be rescheduled here.',
      'stale_occurrence_dates' || 'stale_schedule_revision' =>
        'Your calendar has changed. Refresh and try again.',
      'not_authenticated' || 'assignment_not_authorised' =>
        'This programme could not be updated for the signed-in athlete.',
      _ =>
        'This session could not be rescheduled. Refresh your calendar and try again.',
    };
  }

  factory OverdueProgrammeRecoveryResult.fromRpcMap(Map<String, dynamic> map) {
    final statusRaw = map['status']?.toString() ?? '';
    final status = switch (statusRaw) {
      'applied' => OverdueProgrammeRecoveryStatus.applied,
      'already_applied' => OverdueProgrammeRecoveryStatus.alreadyApplied,
      'ineligible' ||
      'conflict' ||
      'validation_failure' ||
      'authorization_failure' => OverdueProgrammeRecoveryStatus.rejected,
      _ => OverdueProgrammeRecoveryStatus.failed,
    };
    return OverdueProgrammeRecoveryResult(
      status: status,
      code: map['code']?.toString(),
      message: map['message']?.toString(),
      operationType: map['operation_type']?.toString(),
      originalDate: map['original_date']?.toString(),
      resultingDate: map['resulting_date']?.toString(),
      scheduleRevision: map['schedule_revision'] is int
          ? map['schedule_revision'] as int
          : int.tryParse('${map['schedule_revision']}'),
    );
  }
}
