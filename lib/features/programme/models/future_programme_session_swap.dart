/// Command for the authenticated future-session swap-and-begin authority.
class FutureProgrammeSessionSwapCommand {
  const FutureProgrammeSessionSwapCommand({
    required this.assignmentId,
    required this.todayOccurrenceId,
    required this.selectedOccurrenceId,
    required this.expectedTodayDate,
    required this.expectedSelectedDate,
    this.expectedScheduleRevision,
  });

  final String assignmentId;
  final String todayOccurrenceId;
  final String selectedOccurrenceId;
  final String expectedTodayDate;
  final String expectedSelectedDate;
  final int? expectedScheduleRevision;

  Map<String, Object?> toRpcPayload() => {
    'assignment_id': assignmentId,
    'today_occurrence_id': todayOccurrenceId,
    'selected_occurrence_id': selectedOccurrenceId,
    'expected_today_date': expectedTodayDate,
    'expected_selected_date': expectedSelectedDate,
    if (expectedScheduleRevision != null)
      'expected_schedule_revision': expectedScheduleRevision,
  };
}

enum FutureProgrammeSessionSwapStatus {
  created,
  resumed,
  rejected,
  failed,
}

class FutureProgrammeSessionSwapResult {
  const FutureProgrammeSessionSwapResult({
    required this.status,
    this.code,
    this.message,
    this.assignmentId,
    this.selectedOccurrenceId,
    this.todayScheduledDate,
    this.displacedScheduledDate,
    this.programmedSessionKey,
    this.trainingSession,
    this.scheduleRevision,
  });

  final FutureProgrammeSessionSwapStatus status;
  final String? code;
  final String? message;
  final String? assignmentId;
  final String? selectedOccurrenceId;
  final String? todayScheduledDate;
  final String? displacedScheduledDate;
  final String? programmedSessionKey;
  final Map<String, dynamic>? trainingSession;
  final int? scheduleRevision;

  bool get isSuccess =>
      status == FutureProgrammeSessionSwapStatus.created ||
      status == FutureProgrammeSessionSwapStatus.resumed;

  String get athleteVisibleMessage {
    final provided = message?.trim();
    if (provided != null && provided.isNotEmpty) {
      return provided;
    }
    return athleteVisibleMessageForCode(code);
  }

  static String athleteVisibleMessageForCode(String? code) {
    return switch (code) {
      'overdue_occurrence' =>
        'Train today is unavailable while an earlier session is still unresolved.',
      'in_progress_session_exists' ||
      'occurrence_has_session_state' =>
        'Finish your current session before swapping another session into today.',
      'selected_outside_train_today_horizon' =>
        'Train today is available for sessions in the next 7 days.',
      'stale_occurrence_dates' ||
      'today_date_mismatch' ||
      'stale_schedule_revision' =>
        'Your calendar has changed. Refresh and try again.',
      'occurrence_completed' => 'That session is already completed.',
      'occurrence_skipped' => 'That session was skipped.',
      'selected_not_future' =>
        'Only a future session can be swapped into today.',
      'swap_not_offered' => 'A clean one-for-one swap is not available.',
      _ =>
        'This session could not be swapped and started. Refresh your calendar and try again.',
    };
  }

  factory FutureProgrammeSessionSwapResult.fromRpcMap(
    Map<String, dynamic> map,
  ) {
    final statusRaw = map['status']?.toString() ?? '';
    final code = map['code']?.toString();
    Map<String, dynamic>? session;
    final sessionRaw = map['training_session'];
    if (sessionRaw is Map<String, dynamic>) {
      session = sessionRaw;
    } else if (sessionRaw is Map) {
      session = Map<String, dynamic>.from(sessionRaw);
    }
    final rawMessage = map['message']?.toString();
    return FutureProgrammeSessionSwapResult(
      status: switch (statusRaw) {
        'created' => FutureProgrammeSessionSwapStatus.created,
        'resumed' => FutureProgrammeSessionSwapStatus.resumed,
        'authorization_failure' ||
        'validation_failure' ||
        'ineligible' ||
        'conflict' => FutureProgrammeSessionSwapStatus.rejected,
        _ => FutureProgrammeSessionSwapStatus.failed,
      },
      code: code,
      message: (rawMessage != null && rawMessage.trim().isNotEmpty)
          ? rawMessage
          : athleteVisibleMessageForCode(code),
      assignmentId: map['assignment_id']?.toString(),
      selectedOccurrenceId: map['selected_occurrence_id']?.toString(),
      todayScheduledDate: map['today_scheduled_date']?.toString(),
      displacedScheduledDate: map['displaced_scheduled_date']?.toString(),
      programmedSessionKey: map['programmed_session_key']?.toString(),
      trainingSession: session,
      scheduleRevision: _nullableInt(map['schedule_revision']),
    );
  }
}

int? _nullableInt(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}
