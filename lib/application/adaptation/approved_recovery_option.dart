import 'dart:convert';

import '../../core/persistence/session_execution_plan_codec.dart';
import '../../features/adaptation/models/programme_adaptation_proposal.dart';
import '../../features/auth/services/current_user_session.dart';
import '../../features/programme/models/programme_execution_context.dart';
import '../../features/programme/services/athlete_programme_session_prepare_service.dart';
import '../../features/session/models/prepared_execution_package.dart';
import '../../features/session/models/session_execution_plan.dart';
import '../../models/adaptation_reason.dart';
import '../../models/adaptation_request.dart';
import '../../models/programme_vocabulary.dart';
import '../../models/recovery_state.dart';
import 'approved_time_option.dart';

typedef ProgrammeRecoveryApprovalLoader =
    Future<ApprovedRecoveryOption?> Function(ProgrammeExecutionContext context);

/// Independently approved for Recovery on one exact private occurrence.
class ApprovedRecoveryOption {
  ApprovedRecoveryOption({
    required this.athleteId,
    required this.assignmentId,
    required this.versionId,
    required this.slotId,
    required this.occurrenceId,
    required this.scheduledDate,
    required this.omission,
    this.scopeSealHash,
    required SessionExecutionPlan originalPlan,
  }) : _originalPlan = _encodePlan(originalPlan);

  final String athleteId;
  final String assignmentId;
  final String versionId;
  final String slotId;
  final String occurrenceId;
  final String scheduledDate;
  final ApprovedAccessoryOmission omission;
  final String? scopeSealHash;
  final String _originalPlan;

  String get pin => jsonEncode([
    athleteId,
    assignmentId,
    versionId,
    slotId,
    occurrenceId,
    scheduledDate,
    scopeSealHash,
    omission.permission.id,
    omission.slotKey,
    omission.protocolId,
    omission.packageHash,
    omission.fullMinutes,
    omission.shortMinutes,
    omission.omittedPosition,
    omission.intent?.name,
    _originalPlan,
  ]);

  bool matches(
    String athlete,
    PreparedExecutionPackage package,
    ProgrammeExecutionContext context,
  ) =>
      athleteId == athlete &&
      context.assignmentId == assignmentId &&
      context.programmeVersionId == versionId &&
      context.sessionSlotId == slotId &&
      context.packageSlotKey == omission.slotKey &&
      context.occurrenceId == occurrenceId &&
      omission.fullMinutes == 45 &&
      omission.shortMinutes == 30 &&
      omission.omittedPosition == 3 &&
      package.acceptedAdaptation == null &&
      _encodePlan(package.plan) == _originalPlan;

  static String _encodePlan(SessionExecutionPlan plan) =>
      jsonEncode(const SessionExecutionPlanCodec().encodePlan(plan));
}

/// Evidence for one open questionnaire and comparison. Never persisted.
class RecoveryReview {
  RecoveryReview({
    required this.athleteId,
    required this.prepareService,
    required this.loadApproval,
    required this.isOpen,
  }) : _session = CurrentUserSession.maybeInstance;

  final String athleteId;
  final AthleteProgrammeSessionPrepareService prepareService;
  final ProgrammeRecoveryApprovalLoader loadApproval;
  final bool Function() isOpen;
  final CurrentUserSession? _session;
  ProgrammeAdaptationProposal? _proposal;
  String? _reviewedApprovalPin;

  bool get isCurrent =>
      isOpen() &&
      _session?.isAthlete == true &&
      _session?.athleteId == athleteId &&
      identical(_session, CurrentUserSession.maybeInstance);

  void bindProposal(ProgrammeAdaptationProposal proposal) {
    _proposal = proposal;
  }

  bool permitsAcceptance(
    ProgrammeAdaptationProposal proposal,
    String athlete,
  ) => isCurrent && athlete == athleteId && identical(_proposal, proposal);

  Future<ApprovedRecoveryOption?> readApproval({
    required PreparedExecutionPackage package,
    required ProgrammeExecutionContext context,
    required AdaptationRequest request,
  }) async {
    if (!isCurrent ||
        request.reason != AdaptationReason.recovery ||
        request.recoveryState != RecoveryState.poorSleep) {
      return null;
    }
    final approval = await loadApproval(context);
    if (approval == null || !approval.matches(athleteId, package, context)) {
      return null;
    }
    if (_reviewedApprovalPin != null && _reviewedApprovalPin != approval.pin) {
      return null;
    }
    final assignment = await prepareService.assignmentStore.getActiveAssignment(
      athleteId,
    );
    if (assignment == null ||
        assignment.id != approval.assignmentId ||
        assignment.athleteId != athleteId ||
        !assignment.isActive ||
        !assignment.isFixedSchedule) {
      return null;
    }
    final calendar = await prepareService.fixedOccurrenceStore.resolveActive();
    if (calendar == null ||
        calendar.assignmentId != approval.assignmentId ||
        calendar.assignmentStatus != 'active' ||
        calendar.scheduleMode != 'fixed_schedule' ||
        calendar.today != approval.scheduledDate) {
      return null;
    }
    final matches = calendar.occurrences.where(
      (occurrence) => occurrence.occurrenceId == approval.occurrenceId,
    );
    final occurrence = matches.singleOrNull;
    if (occurrence == null ||
        !occurrence.isToday ||
        occurrence.trainingSessionId != null ||
        occurrence.scheduledDate != calendar.today ||
        occurrence.assignmentId != approval.assignmentId ||
        occurrence.programmeVersionId != approval.versionId ||
        occurrence.sessionSlotId != approval.slotId ||
        occurrence.protocolId != approval.omission.protocolId ||
        occurrence.programmedSessionKey != package.programmedSessionKey.value) {
      return null;
    }
    final resolved = await prepareService.slotResolver.resolve(
      assignment.copyWith(
        currentWeek: occurrence.weekNumber,
        currentDayKey: occurrence.dayKey,
        currentSessionOrder: occurrence.sessionOrder,
      ),
      scheduleDate: DateTime.parse(occurrence.scheduledDate),
    );
    if (resolved.version.libraryScope != ProgrammeLibraryScope.coachPrivate ||
        resolved.slot.id != approval.slotId ||
        resolved.slot.packageSlotKey != approval.omission.slotKey ||
        resolved.programmedSessionKey.value !=
            package.programmedSessionKey.value) {
      return null;
    }

    final persisted = await prepareService.localRepository
        ?.readGeneratedSession(athleteId);
    if (persisted == null ||
        persisted.athleteId != athleteId ||
        persisted.programmedSessionKey != package.programmedSessionKey.value ||
        persisted.generatedAt != package.preparedAt ||
        persisted.acceptedAdaptation != null ||
        ApprovedRecoveryOption._encodePlan(persisted.plan) !=
            approval._originalPlan ||
        !identical(
          prepareService.cachedPackageForKey(
            package.programmedSessionKey.value,
          ),
          package,
        ) ||
        !isCurrent) {
      return null;
    }
    _reviewedApprovalPin = approval.pin;
    return approval;
  }
}
