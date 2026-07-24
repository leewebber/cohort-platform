import '../../../models/programme_assignment.dart';
import 'programme_assignment_operation_result.dart';
import 'resolved_today_session.dart';

enum AthleteProgrammeSwitchStatus {
  switched,
  cancelled,
  alreadyActive,
  failed,
}

class AthleteProgrammeSwitchResult {
  const AthleteProgrammeSwitchResult({
    required this.status,
    this.assignment,
    this.previousAssignmentId,
    this.resolvedTodaySession,
    this.message,
  });

  final AthleteProgrammeSwitchStatus status;
  final ProgrammeAssignment? assignment;
  final String? previousAssignmentId;
  final ResolvedTodaySession? resolvedTodaySession;
  final String? message;

  bool get isSuccess => status == AthleteProgrammeSwitchStatus.switched;

  factory AthleteProgrammeSwitchResult.alreadyActive() {
    return const AthleteProgrammeSwitchResult(
      status: AthleteProgrammeSwitchStatus.alreadyActive,
      message: 'This is already your active programme.',
    );
  }

  factory AthleteProgrammeSwitchResult.cancelled() {
    return const AthleteProgrammeSwitchResult(
      status: AthleteProgrammeSwitchStatus.cancelled,
    );
  }

  factory AthleteProgrammeSwitchResult.fromAssignmentOperation(
    ProgrammeAssignmentOperationResult result,
  ) {
    if (!result.isSuccess) {
      return AthleteProgrammeSwitchResult(
        status: AthleteProgrammeSwitchStatus.failed,
        message: result.warnings.isNotEmpty
            ? result.warnings.first
            : 'Programme switch failed.',
      );
    }

    return AthleteProgrammeSwitchResult(
      status: AthleteProgrammeSwitchStatus.switched,
      assignment: result.assignment,
      previousAssignmentId: result.replacedAssignmentId,
      resolvedTodaySession: result.resolvedTodaySession,
    );
  }
}
