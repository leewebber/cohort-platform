import '../../session_occurrence/value_objects/session_occurrence_date.dart';
import '../vocabulary/programme_scheduling_operation_type.dart';

/// Sealed-style request hierarchy for compute-only preview.
sealed class ProgrammeSchedulingRequest {
  const ProgrammeSchedulingRequest();

  ProgrammeSchedulingOperationType get type;
}

class ProgrammeSchedulingMoveRequest extends ProgrammeSchedulingRequest {
  const ProgrammeSchedulingMoveRequest({
    required this.sessionSlotId,
    required this.targetDate,
  });

  final String sessionSlotId;
  final SessionOccurrenceDate targetDate;

  @override
  ProgrammeSchedulingOperationType get type =>
      ProgrammeSchedulingOperationType.move;

  Map<String, Object?> toCanonicalMap() => {
    'type': type.name,
    'sessionSlotId': sessionSlotId,
    'targetDate': targetDate.toString(),
  };
}

class ProgrammeSchedulingSwapRequest extends ProgrammeSchedulingRequest {
  const ProgrammeSchedulingSwapRequest({
    required this.sessionSlotIdA,
    required this.sessionSlotIdB,
  });

  final String sessionSlotIdA;
  final String sessionSlotIdB;

  @override
  ProgrammeSchedulingOperationType get type =>
      ProgrammeSchedulingOperationType.swap;

  Map<String, Object?> toCanonicalMap() => {
    'type': type.name,
    'sessionSlotIdA': sessionSlotIdA,
    'sessionSlotIdB': sessionSlotIdB,
  };
}

class ProgrammeSchedulingPushRequest extends ProgrammeSchedulingRequest {
  const ProgrammeSchedulingPushRequest({
    required this.fromSessionSlotId,
    required this.dayDelta,
  });

  final String fromSessionSlotId;
  final int dayDelta;

  @override
  ProgrammeSchedulingOperationType get type =>
      ProgrammeSchedulingOperationType.push;

  Map<String, Object?> toCanonicalMap() => {
    'type': type.name,
    'fromSessionSlotId': fromSessionSlotId,
    'dayDelta': dayDelta,
  };
}

class ProgrammeSchedulingSkipRequest extends ProgrammeSchedulingRequest {
  const ProgrammeSchedulingSkipRequest({required this.sessionSlotId});

  final String sessionSlotId;

  @override
  ProgrammeSchedulingOperationType get type =>
      ProgrammeSchedulingOperationType.skip;

  Map<String, Object?> toCanonicalMap() => {
    'type': type.name,
    'sessionSlotId': sessionSlotId,
  };
}
