import '../../features/performance/models/training_session_record.dart';
import '../../features/performance/models/training_session_record_status.dart';
import '../../features/performance/repositories/performance_record_store.dart';
import '../../features/performance/repositories/performance_record_store.dart';
import '../../features/programme_impact/models/programme_version_impact_models.dart';
import '../../models/programme_assignment.dart';
import '../../models/programme_slot_outcome.dart';
import '../../models/programme_version.dart';
import '../../models/programme_version_day.dart';
import '../../models/programme_version_session_slot.dart';
import '../../models/programme_version_week.dart';
import '../../models/programme_vocabulary.dart';
import '../../models/session_revision_vocabulary.dart';
import '../../features/session_revision/models/content_usage_vocabulary.dart';

/// Read-only persistence boundary for Programme Version impact analysis (M10.1).
abstract class ProgrammeVersionImpactStore {
  const ProgrammeVersionImpactStore();

  Future<ProgrammeVersion?> getVersionById(String programmeVersionId);

  Future<List<ProgrammeVersion>> listVersionsForLineage(String lineageId);

  Future<List<ProgrammeVersionSessionReference>> listSessionReferences(
    String programmeVersionId,
  );

  Future<List<ProgrammeVersionAssignmentImpact>> listAssignmentImpact(
    String programmeVersionId,
  );

  Future<ProgrammeVersionHistoricalImpactResult> getHistoricalImpact(
    String programmeVersionId,
  );

  Future<List<ProgrammeVersionExerciseReference>> listExerciseReferences(
    String programmeVersionId,
    Set<String> protocolIds,
  );
}

class ProgrammeVersionImpactStoreException implements Exception {
  const ProgrammeVersionImpactStoreException(this.message);

  final String message;

  @override
  String toString() => 'ProgrammeVersionImpactStoreException: $message';
}

class ProgrammeVersionHistoricalImpactResult {
  const ProgrammeVersionHistoricalImpactResult({
    required this.impact,
    this.lookupFailed = false,
    this.failureMessage,
  });

  final ProgrammeVersionHistoricalImpact impact;
  final bool lookupFailed;
  final String? failureMessage;
}

List<ContentUsageClassification> buildProgrammeVersionImpactClassifications({
  required bool hasAuthoredContent,
  required bool hasActiveOperationalImpact,
  required bool hasHistoricalImpact,
}) {
  return buildUsageClassifications(
    hasDirectAuthoredUsage: hasAuthoredContent,
    hasActiveOperationalUsage: hasActiveOperationalImpact,
    hasHistoricalUsage: hasHistoricalImpact,
  );
}

List<ContentUsageClassification> buildUsageClassifications({
  required bool hasDirectAuthoredUsage,
  required bool hasActiveOperationalUsage,
  required bool hasHistoricalUsage,
}) {
  final classifications = <ContentUsageClassification>[];
  if (hasDirectAuthoredUsage) {
    classifications.add(ContentUsageClassification.directAuthored);
  }
  if (hasActiveOperationalUsage) {
    classifications.add(ContentUsageClassification.activeOperational);
  }
  if (hasHistoricalUsage) {
    classifications.add(ContentUsageClassification.historicalPerformance);
  }
  return classifications;
}

int compareProgrammeVersionSessionReferences(
  ProgrammeVersionSessionReference a,
  ProgrammeVersionSessionReference b,
) {
  final weekCompare = a.weekNumber.compareTo(b.weekNumber);
  if (weekCompare != 0) return weekCompare;

  final dayCompare = a.dayOrder.compareTo(b.dayOrder);
  if (dayCompare != 0) return dayCompare;

  final slotCompare = a.slotOrder.compareTo(b.slotOrder);
  if (slotCompare != 0) return slotCompare;

  return a.slotId.compareTo(b.slotId);
}

int compareProgrammeVersionExerciseReferences(
  ProgrammeVersionExerciseReference a,
  ProgrammeVersionExerciseReference b,
) {
  final nameCompare = a.exerciseName.compareTo(b.exerciseName);
  if (nameCompare != 0) return nameCompare;
  return a.exerciseId.compareTo(b.exerciseId);
}

int compareProgrammeVersionAssignmentImpact(
  ProgrammeVersionAssignmentImpact a,
  ProgrammeVersionAssignmentImpact b,
) {
  final activeCompare = b.isActive.toString().compareTo(a.isActive.toString());
  if (activeCompare != 0) return activeCompare;
  return a.assignmentId.compareTo(b.assignmentId);
}

ProgrammeVersionLineageContext buildProgrammeVersionLineageContext({
  required ProgrammeVersion queriedVersion,
  required List<ProgrammeVersion> lineageVersions,
}) {
  final sortedVersions = lineageVersions.toList()
    ..sort((a, b) => a.versionNumber.compareTo(b.versionNumber));

  final newerVersions = sortedVersions
      .where((version) => version.versionNumber > queriedVersion.versionNumber)
      .toList();

  ProgrammeVersion? latestPublished;
  for (final version in sortedVersions.reversed) {
    if (version.lifecycleStatus == ProgrammeLifecycleStatus.published) {
      latestPublished = version;
      break;
    }
  }

  return ProgrammeVersionLineageContext(
    programmeLineageId: queriedVersion.lineageId,
    currentVersionNumber: queriedVersion.versionNumber,
    latestPublishedVersionId: latestPublished?.id,
    latestPublishedVersionNumber: latestPublished?.versionNumber,
    newerVersionIds: newerVersions.map((version) => version.id).toList(),
    hasNewerVersion: newerVersions.isNotEmpty,
    queriedVersionLifecycleStatus: queriedVersion.lifecycleStatus,
  );
}

ProgrammeVersionHistoricalImpact buildHistoricalImpactFromRecords({
  required Iterable<TrainingSessionRecord> terminalRecords,
  required int skippedSessionCount,
  required int exerciseResultCount,
  required bool isAuthoritative,
  String? limitationNote,
}) {
  final seenRecordIds = <String>{};
  final seenAthletes = <String>{};
  final seenSessionRevisions = <String>{};
  DateTime? earliest;
  DateTime? latest;
  var completedSessionCount = 0;

  for (final record in terminalRecords) {
    if (!seenRecordIds.add(record.recordId)) continue;
    seenAthletes.add(record.athleteId);
    final protocolId = record.sourceProtocolId?.trim();
    if (protocolId != null && protocolId.isNotEmpty) {
      seenSessionRevisions.add(protocolId);
    }

    final performedAt = record.completedAt ?? record.startedAt;
    if (earliest == null || performedAt.isBefore(earliest)) {
      earliest = performedAt;
    }
    if (latest == null || performedAt.isAfter(latest)) {
      latest = performedAt;
    }

    if (record.status == TrainingSessionRecordStatus.completed) {
      completedSessionCount++;
    }
  }

  return ProgrammeVersionHistoricalImpact(
    terminalRecordCount: seenRecordIds.length,
    completedSessionCount: completedSessionCount,
    skippedSessionCount: skippedSessionCount,
    athleteCount: seenAthletes.length,
    sessionRevisionCount: seenSessionRevisions.length,
    exerciseResultCount: exerciseResultCount,
    earliestPerformedAt: earliest,
    latestPerformedAt: latest,
    isAuthoritative: isAuthoritative,
    limitationNote: limitationNote,
  );
}

bool isRecordAttributableToProgrammeVersion({
  required TrainingSessionRecord record,
  required String programmeVersionId,
  required Map<String, String> assignmentVersionById,
  required Map<String, String> slotVersionById,
}) {
  if (!isTerminalRecordStatus(record.status)) return false;

  final assignmentId = record.assignmentId?.trim();
  if (assignmentId != null && assignmentId.isNotEmpty) {
    return assignmentVersionById[assignmentId] == programmeVersionId;
  }

  final slotId = record.programmeSessionId?.trim();
  if (slotId != null && slotId.isNotEmpty) {
    return slotVersionById[slotId] == programmeVersionId;
  }

  return false;
}

int countSkippedSlotOutcomes({
  required Iterable<ProgrammeSlotOutcome> outcomes,
  required Iterable<ProgrammeAssignment> assignments,
  required String programmeVersionId,
}) {
  final assignmentIds = assignments
      .where((assignment) => assignment.programmeVersionId == programmeVersionId)
      .map((assignment) => assignment.id)
      .toSet();

  return outcomes
      .where(
        (outcome) =>
            assignmentIds.contains(outcome.assignmentId) &&
            outcome.outcomeStatus == ProgrammeSlotOutcomeStatus.skipped,
      )
      .length;
}

List<ProgrammeVersionAssignmentImpact> buildActiveAssignmentImpact({
  required Iterable<ProgrammeAssignment> assignments,
  required String programmeVersionId,
}) {
  final seenAssignmentIds = <String>{};
  final results = <ProgrammeVersionAssignmentImpact>[];

  final sortedAssignments = assignments.toList()
    ..sort((a, b) => a.id.compareTo(b.id));

  for (final assignment in sortedAssignments) {
    if (assignment.programmeVersionId != programmeVersionId) continue;
    if (!assignment.isActive) continue;
    if (!seenAssignmentIds.add(assignment.id)) continue;

    results.add(
      ProgrammeVersionAssignmentImpact(
        assignmentId: assignment.id,
        assignmentStatus: assignment.status,
        assignedAt: assignment.startedAt,
        startedAt: assignment.startedAt,
        completedAt: assignment.completedAt,
        isActive: assignment.isActive,
        progressSummary:
            'Week ${assignment.currentWeek} · ${assignment.currentDayKey} · Slot ${assignment.currentSessionOrder}',
      ),
    );
  }

  results.sort(compareProgrammeVersionAssignmentImpact);
  return results;
}

int countDistinctSessionRevisions(
  Iterable<ProgrammeVersionSessionReference> references,
) {
  return references.map((reference) => reference.protocolId).toSet().length;
}

int countDistinctSessionLineages(
  Iterable<ProgrammeVersionSessionReference> references,
) {
  return references.map((reference) => reference.sessionLineageId).toSet().length;
}

List<ProgrammeVersionSessionReference> applySessionOccurrenceCounts(
  List<ProgrammeVersionSessionReference> slotReferences,
) {
  final countsByProtocol = <String, int>{};
  for (final reference in slotReferences) {
    countsByProtocol[reference.protocolId] =
        (countsByProtocol[reference.protocolId] ?? 0) + 1;
  }

  final seenProtocols = <String>{};
  final results = <ProgrammeVersionSessionReference>[];

  for (final reference in slotReferences) {
    if (!seenProtocols.add(reference.protocolId)) continue;
    results.add(
      ProgrammeVersionSessionReference(
        programmeVersionId: reference.programmeVersionId,
        slotId: reference.slotId,
        protocolId: reference.protocolId,
        sessionLineageId: reference.sessionLineageId,
        sessionRevisionNumber: reference.sessionRevisionNumber,
        sessionName: reference.sessionName,
        sessionLifecycleStatus: reference.sessionLifecycleStatus,
        weekNumber: reference.weekNumber,
        dayKey: reference.dayKey,
        dayOrder: reference.dayOrder,
        slotOrder: reference.slotOrder,
        slotLabel: reference.slotLabel,
        occurrenceCount: countsByProtocol[reference.protocolId] ?? 1,
      ),
    );
  }

  return results;
}

SessionRevisionLifecycleStatus defaultSessionLifecycleForProtocol({
  required bool published,
}) {
  return published
      ? SessionRevisionLifecycleStatus.published
      : SessionRevisionLifecycleStatus.draft;
}

ProgrammeVersionSessionReference buildSessionReference({
  required ProgrammeVersion version,
  required ProgrammeVersionWeek week,
  required ProgrammeVersionDay day,
  required ProgrammeVersionSessionSlot slot,
  required String sessionLineageId,
  required int sessionRevisionNumber,
  required String sessionName,
  required SessionRevisionLifecycleStatus sessionLifecycleStatus,
}) {
  return ProgrammeVersionSessionReference(
    programmeVersionId: version.id,
    slotId: slot.id,
    protocolId: slot.protocolId,
    sessionLineageId: sessionLineageId,
    sessionRevisionNumber: sessionRevisionNumber,
    sessionName: sessionName,
    sessionLifecycleStatus: sessionLifecycleStatus,
    weekNumber: week.weekNumber,
    dayKey: day.dayKey,
    dayOrder: day.dayOrder,
    slotOrder: slot.sessionOrder,
    slotLabel: slot.displayTitle,
  );
}

Map<String, String> buildAssignmentVersionIndex(
  Iterable<ProgrammeAssignment> assignments,
) {
  return {
    for (final assignment in assignments) assignment.id: assignment.programmeVersionId,
  };
}

Map<String, String> buildSlotVersionIndex({
  required Iterable<ProgrammeVersionSessionSlot> slots,
  required Iterable<ProgrammeVersionDay> days,
  required Iterable<ProgrammeVersionWeek> weeks,
}) {
  final weekById = {for (final week in weeks) week.id: week};
  final dayById = {for (final day in days) day.id: day};

  final slotVersionById = <String, String>{};
  for (final slot in slots) {
    final day = dayById[slot.dayId];
    if (day == null) continue;
    final week = weekById[day.weekId];
    if (week == null) continue;
    slotVersionById[slot.id] = week.versionId;
  }
  return slotVersionById;
}
