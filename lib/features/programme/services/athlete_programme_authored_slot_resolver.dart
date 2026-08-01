import '../../../data/repositories/programme_version_store.dart';
import '../../../models/programme_assignment.dart';
import '../../../models/programme_version.dart';
import '../../../models/programme_version_session_slot.dart';
import '../errors/programme_schedule_exception.dart';
import '../models/programme_execution_context.dart';
import '../models/programme_template.dart';
import '../../plans/models/programmed_session_key.dart';

/// Resolved authored slot for an exact materialised programme assignment.
class AuthoredProgrammeSlotResolution {
  const AuthoredProgrammeSlotResolution({
    required this.assignment,
    required this.version,
    required this.tree,
    required this.slot,
    required this.executionContext,
    required this.programmedSessionKey,
    required this.scheduleDate,
  });

  final ProgrammeAssignment assignment;
  final ProgrammeVersion version;
  final ProgrammeTemplateTree tree;
  final ProgrammeVersionSessionSlot slot;
  final ProgrammeExecutionContext executionContext;
  final ProgrammedSessionKey programmedSessionKey;
  final DateTime scheduleDate;
}

/// Resolves the assignment cursor against its exact programme version/package.
///
/// Does not advance the cursor, fall back to latest, or invent a different slot.
class AthleteProgrammeAuthoredSlotResolver {
  const AthleteProgrammeAuthoredSlotResolver({
    required ProgrammeVersionStore versionStore,
  }) : _versionStore = versionStore;

  final ProgrammeVersionStore _versionStore;

  Future<AuthoredProgrammeSlotResolution> resolve(
    ProgrammeAssignment assignment, {
    DateTime? scheduleDate,
  }) async {
    if (!assignment.isActive) {
      throw ProgrammeScheduleException(
        ProgrammeScheduleErrorCode.assignmentNotActive,
        'Programme assignment is not active',
      );
    }
    if (!assignment.isMaterialised) {
      throw ProgrammeScheduleException(
        ProgrammeScheduleErrorCode.assignmentNotMaterialised,
        'Programme assignment is enrolled only and not materialised',
      );
    }

    final version = await _versionStore.getVersionById(
      assignment.programmeVersionId,
    );
    if (version == null) {
      throw ProgrammeScheduleException(
        ProgrammeScheduleErrorCode.missingProgrammeVersion,
        'Exact programme version ${assignment.programmeVersionId} was not found',
      );
    }
    if (!version.isPublished || version.archivedAt != null) {
      throw ProgrammeScheduleException(
        ProgrammeScheduleErrorCode.missingProgrammeVersion,
        'Exact programme version is not published/immutable',
      );
    }

    final materialisedHash = assignment.materialisedPackageContentHash?.trim();
    final versionHash = version.packageContentHash?.trim();
    if (materialisedHash == null ||
        materialisedHash.isEmpty ||
        versionHash == null ||
        versionHash.isEmpty ||
        materialisedHash != versionHash) {
      throw ProgrammeScheduleException(
        ProgrammeScheduleErrorCode.packageHashMismatch,
        'Materialised package hash does not match exact programme version',
      );
    }

    final tree = await _versionStore.loadTemplateTree(version.id);
    if (tree == null) {
      throw ProgrammeScheduleException(
        ProgrammeScheduleErrorCode.emptyProgrammeStructure,
        'Pinned programme version structure could not be loaded',
      );
    }

    final weekNode = tree.weekNodeForNumber(assignment.currentWeek);
    if (weekNode == null) {
      throw ProgrammeScheduleException(
        ProgrammeScheduleErrorCode.missingCurrentWeek,
        'Assignment cursor references missing week ${assignment.currentWeek}',
      );
    }

    ProgrammeTemplateDayNode? dayNode;
    for (final candidate in weekNode.sortedDays) {
      if (candidate.day.dayKey == assignment.currentDayKey) {
        dayNode = candidate;
        break;
      }
    }
    if (dayNode == null) {
      throw ProgrammeScheduleException(
        ProgrammeScheduleErrorCode.missingCurrentDay,
        'Assignment cursor references missing day ${assignment.currentDayKey}',
      );
    }
    if (dayNode.day.isRestDay) {
      throw ProgrammeScheduleException(
        ProgrammeScheduleErrorCode.unresolvableAuthoredSlot,
        'Assignment cursor points at a rest day',
      );
    }

    ProgrammeVersionSessionSlot? slot;
    for (final candidate in dayNode.sortedSlots) {
      if (candidate.sessionOrder == assignment.currentSessionOrder) {
        slot = candidate;
        break;
      }
    }
    if (slot == null) {
      throw ProgrammeScheduleException(
        ProgrammeScheduleErrorCode.missingCurrentSlot,
        'Assignment cursor references missing slot ${assignment.currentSessionOrder}',
      );
    }

    final protocolId = slot.protocolId.trim();
    if (protocolId.isEmpty) {
      throw ProgrammeScheduleException(
        ProgrammeScheduleErrorCode.unresolvableAuthoredSlot,
        'Authored slot has no protocol/bank identity',
      );
    }

    final date = scheduleDate ?? assignment.startedAt;
    final key = ProgrammedSessionKey.fromMaterialisedProgramme(
      assignment: assignment,
      protocolId: protocolId,
      packageContentHash: materialisedHash,
      scheduleDate: date,
    );

    final context = ProgrammeExecutionContext(
      assignmentId: assignment.id,
      programmeVersionId: assignment.programmeVersionId,
      sessionSlotId: slot.id,
      weekNumber: assignment.currentWeek,
      dayKey: assignment.currentDayKey,
      sessionOrder: assignment.currentSessionOrder,
      plannedProtocolId: protocolId,
      effectiveProtocolId: protocolId,
      lineageCode: assignment.lineageCode,
      programmeName: version.name,
      packageContentHash: materialisedHash,
      programmedSessionKey: key.value,
    );

    return AuthoredProgrammeSlotResolution(
      assignment: assignment,
      version: version,
      tree: tree,
      slot: slot,
      executionContext: context,
      programmedSessionKey: key,
      scheduleDate: date,
    );
  }
}
