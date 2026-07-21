import 'package:cohort_platform/data/repositories/programme_migration_planner_store.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:cohort_platform/models/programme_slot_outcome.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';

import 'in_memory_programme_stores.dart';

class InMemoryProgrammeMigrationPlannerStore
    extends ProgrammeMigrationPlannerStore {
  InMemoryProgrammeMigrationPlannerStore(this.tables);

  final InMemoryProgrammeTables tables;

  @override
  Future<List<ProgrammeAssignment>> listAssignmentsForPlanning({
    required String programmeVersionId,
    List<String>? assignmentIds,
  }) async {
    Iterable<ProgrammeAssignment> candidates = tables.assignments.where(
      (assignment) => assignment.programmeVersionId == programmeVersionId,
    );

    if (assignmentIds != null && assignmentIds.isNotEmpty) {
      final idSet = assignmentIds.toSet();
      candidates = candidates.where((assignment) => idSet.contains(assignment.id));
    } else {
      candidates =
          candidates.where((assignment) => assignment.status == ProgrammeAssignmentStatus.active);
    }

    final results = candidates.toList()..sort((a, b) => a.id.compareTo(b.id));
    return results;
  }

  @override
  Future<Map<String, List<ProgrammeSlotOutcome>>> listOutcomesForAssignments(
    List<String> assignmentIds,
  ) async {
    if (assignmentIds.isEmpty) return const {};

    final idSet = assignmentIds.toSet();
    final grouped = <String, List<ProgrammeSlotOutcome>>{};

    for (final outcome in tables.outcomes) {
      if (!idSet.contains(outcome.assignmentId)) continue;
      grouped.putIfAbsent(outcome.assignmentId, () => []).add(outcome);
    }

    return grouped;
  }
}
