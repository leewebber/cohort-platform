import '../../features/exercise_relationship/models/exercise_usage_models.dart';
import '../../features/session_revision/models/content_usage_vocabulary.dart';
import '../../models/exercise.dart';
import '../../models/programme_assignment.dart';

abstract class ExerciseRelationshipStore {
  const ExerciseRelationshipStore();

  Future<Exercise?> getExerciseById(String exerciseId);

  Future<List<ExerciseRevisionReference>> listSessionRevisionReferences(
    String exerciseId,
  );

  Future<List<ExerciseProgrammeReference>> listProgrammeReferences(
    String exerciseId,
    Set<String> protocolIds,
  );

  Future<List<ExerciseAssignmentReference>> listActiveAssignmentReferences(
    String exerciseId,
    Set<String> programmeVersionIds,
  );

  Future<ExerciseHistoricalUsage> getHistoricalUsage(String exerciseId);
}

class ExerciseRelationshipStoreException implements Exception {
  const ExerciseRelationshipStoreException(this.message);

  final String message;

  @override
  String toString() => 'ExerciseRelationshipStoreException: $message';
}

List<ExerciseAssignmentReference> buildExerciseActiveAssignmentReferences({
  required Iterable<ProgrammeAssignment> assignments,
  required Set<String> referencingVersionIds,
}) {
  final seenAssignmentIds = <String>{};
  final results = <ExerciseAssignmentReference>[];

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
      ExerciseAssignmentReference(
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

List<ExerciseSessionLineageReference> buildSessionLineageReferences(
  Iterable<ExerciseRevisionReference> sessionReferences,
) {
  final byLineage = <String, List<ExerciseRevisionReference>>{};
  for (final reference in sessionReferences) {
    byLineage.putIfAbsent(reference.sessionLineageId, () => []).add(reference);
  }

  final results = <ExerciseSessionLineageReference>[];
  for (final entry in byLineage.entries) {
    final revisions = entry.value
        .map((reference) => reference.sessionRevisionNumber)
        .toSet()
        .toList()
      ..sort();
    final displayName = entry.value.first.sessionName;

    results.add(
      ExerciseSessionLineageReference(
        sessionLineageId: entry.key,
        sessionDisplayName: displayName,
        revisionCount: revisions.length,
        revisionNumbers: revisions,
      ),
    );
  }

  results.sort(
    (a, b) => a.sessionDisplayName.compareTo(b.sessionDisplayName),
  );
  return results;
}

List<ContentUsageClassification> buildExerciseUsageClassifications({
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

int compareExerciseRevisionReferences(
  ExerciseRevisionReference a,
  ExerciseRevisionReference b,
) {
  final nameCompare = a.sessionName.compareTo(b.sessionName);
  if (nameCompare != 0) return nameCompare;

  final revisionCompare =
      a.sessionRevisionNumber.compareTo(b.sessionRevisionNumber);
  if (revisionCompare != 0) return revisionCompare;

  return a.blockOrder.compareTo(b.blockOrder);
}

int compareExerciseProgrammeReferences(
  ExerciseProgrammeReference a,
  ExerciseProgrammeReference b,
) {
  final programmeCompare = a.programmeName.compareTo(b.programmeName);
  if (programmeCompare != 0) return programmeCompare;

  final versionCompare =
      a.programmeVersionNumber.compareTo(b.programmeVersionNumber);
  if (versionCompare != 0) return versionCompare;

  final weekCompare = a.weekNumber.compareTo(b.weekNumber);
  if (weekCompare != 0) return weekCompare;

  final dayCompare = a.dayOrder.compareTo(b.dayOrder);
  if (dayCompare != 0) return dayCompare;

  return a.slotOrder.compareTo(b.slotOrder);
}
