import '../../features/session_revision/models/content_usage_vocabulary.dart';
import '../../features/session_revision/models/session_revision_usage_models.dart';
import '../../models/programme_assignment.dart';

/// Read-only persistence boundary for Session Revision usage relationships.
///
/// Derives relationships from authoritative programme and performance tables.
/// No graph table or cached relationship rows.
abstract class SessionRevisionRelationshipStore {
  const SessionRevisionRelationshipStore();

  Future<List<SessionRevisionProgrammeReference>> listProgrammeSlotReferences(
    String protocolId,
  );

  Future<List<SessionRevisionAssignmentReference>>
      listActiveAssignmentReferences(
    String protocolId,
  );

  Future<SessionRevisionHistoricalUsage> getHistoricalUsage(String protocolId);
}

class SessionRevisionRelationshipStoreException implements Exception {
  const SessionRevisionRelationshipStoreException(this.message);

  final String message;

  @override
  String toString() => 'SessionRevisionRelationshipStoreException: $message';
}

/// Resolves active assignment references for programme versions that contain
/// [protocolId] in at least one slot.
List<SessionRevisionAssignmentReference> buildActiveAssignmentReferences({
  required Iterable<ProgrammeAssignment> assignments,
  required Set<String> referencingVersionIds,
}) {
  final seenAssignmentIds = <String>{};
  final results = <SessionRevisionAssignmentReference>[];

  final sortedAssignments = assignments.toList()
    ..sort((a, b) {
      final versionCompare =
          a.programmeVersionId.compareTo(b.programmeVersionId);
      if (versionCompare != 0) return versionCompare;
      return a.id.compareTo(b.id);
    });

  for (final assignment in sortedAssignments) {
    if (!assignment.isActive) continue;
    if (!referencingVersionIds.contains(assignment.programmeVersionId)) {
      continue;
    }
    if (!seenAssignmentIds.add(assignment.id)) continue;

    results.add(
      SessionRevisionAssignmentReference(
        assignmentId: assignment.id,
        programmeVersionId: assignment.programmeVersionId,
        assignmentStatus: assignment.status,
        athleteId: assignment.athleteId,
        assignedAt: assignment.startedAt,
        isActive: assignment.isActive,
      ),
    );
  }

  return results;
}

/// Computes historical usage from terminal training records only.
SessionRevisionHistoricalUsage buildHistoricalUsage({
  required Iterable<({DateTime performedAt})> terminalRecords,
}) {
  DateTime? earliest;
  DateTime? latest;
  var count = 0;

  for (final record in terminalRecords) {
    count++;
    if (earliest == null || record.performedAt.isBefore(earliest)) {
      earliest = record.performedAt;
    }
    if (latest == null || record.performedAt.isAfter(latest)) {
      latest = record.performedAt;
    }
  }

  return SessionRevisionHistoricalUsage(
    recordCount: count,
    earliestPerformedAt: earliest,
    latestPerformedAt: latest,
  );
}

int countDistinctProgrammeVersions(
  Iterable<SessionRevisionProgrammeReference> references,
) {
  return references.map((reference) => reference.programmeVersionId).toSet().length;
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
