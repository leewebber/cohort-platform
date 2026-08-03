import '../../session_occurrence/value_objects/session_occurrence_date.dart';
import '../vocabulary/programme_scheduling_assignment_status.dart';
import 'programme_schedule_projection.dart';

/// Immutable authoritative input for compute-only scheduling preview.
class ProgrammeSchedulingSnapshot {
  const ProgrammeSchedulingSnapshot({
    required this.assignmentId,
    required this.programmeVersionId,
    required this.packageContentHash,
    required this.timezone,
    required this.startedAt,
    required this.today,
    required this.assignmentStatus,
    required this.projection,
    this.schedulingHorizonEnd,
    this.preparedProgrammedSessionKeys = const {},
    this.adaptedProgrammedSessionKeys = const {},
    this.pendingAdaptationProposalKeys = const {},
    this.consumedAdaptationProposalIds = const {},
    this.cursorSessionSlotId,
    this.policyVersion = ProgrammeSchedulingSnapshot.defaultPolicyVersion,
  });

  static const defaultPolicyVersion = 'programme.scheduling.policy.v1';

  final String assignmentId;
  final String programmeVersionId;
  final String packageContentHash;
  final String timezone;
  final SessionOccurrenceDate startedAt;
  final SessionOccurrenceDate today;
  final ProgrammeSchedulingAssignmentStatus assignmentStatus;
  final ProgrammeScheduleProjection projection;

  /// Inclusive last permitted scheduled date for push; null = unbounded.
  final SessionOccurrenceDate? schedulingHorizonEnd;

  final Set<String> preparedProgrammedSessionKeys;
  final Set<String> adaptedProgrammedSessionKeys;
  final Set<String> pendingAdaptationProposalKeys;
  final Set<String> consumedAdaptationProposalIds;
  final String? cursorSessionSlotId;
  final String policyVersion;

  Map<String, Object?> toCanonicalMap() => {
    'assignmentId': assignmentId,
    'programmeVersionId': programmeVersionId,
    'packageContentHash': packageContentHash,
    'timezone': timezone,
    'startedAt': startedAt.toString(),
    'today': today.toString(),
    'assignmentStatus': assignmentStatus.name,
    'schedulingHorizonEnd': schedulingHorizonEnd?.toString(),
    'cursorSessionSlotId': cursorSessionSlotId,
    'policyVersion': policyVersion,
    'preparedProgrammedSessionKeys':
        (preparedProgrammedSessionKeys.toList()..sort()),
    'adaptedProgrammedSessionKeys':
        (adaptedProgrammedSessionKeys.toList()..sort()),
    'pendingAdaptationProposalKeys':
        (pendingAdaptationProposalKeys.toList()..sort()),
    'consumedAdaptationProposalIds':
        (consumedAdaptationProposalIds.toList()..sort()),
    'projection': projection.toCanonicalMap(),
  };
}
