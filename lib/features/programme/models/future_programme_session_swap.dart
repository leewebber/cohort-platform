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
      message: map['message']?.toString(),
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
