import 'package:cohort_platform/data/repositories/athlete_state_store.dart';
import 'package:cohort_platform/data/repositories/programme_assignment_store.dart';
import 'package:cohort_platform/data/repositories/programme_slot_outcome_delete_result.dart';
import 'package:cohort_platform/data/repositories/programme_slot_outcome_store.dart';
import 'package:cohort_platform/data/repositories/programme_store_exception.dart';
import 'package:cohort_platform/data/repositories/programme_template_tree_assembler.dart';
import 'package:cohort_platform/data/repositories/programme_version_store.dart';
import 'package:cohort_platform/features/programme/models/programme_catalog_entry.dart';
import 'package:cohort_platform/features/programme/models/programme_template.dart';
import 'package:cohort_platform/models/athlete_state.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:cohort_platform/models/programme_lineage.dart';
import 'package:cohort_platform/models/programme_slot_outcome.dart';
import 'package:cohort_platform/models/programme_version.dart';
import 'package:cohort_platform/models/programme_version_day.dart';
import 'package:cohort_platform/models/programme_version_phase.dart';
import 'package:cohort_platform/models/programme_version_session_slot.dart';
import 'package:cohort_platform/models/programme_version_week.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';

/// In-memory Programme Engine stores for unit tests.
class InMemoryProgrammeTables {
  final lineages = <ProgrammeLineage>[];
  final versions = <ProgrammeVersion>[];
  final phases = <ProgrammeVersionPhase>[];
  final weeks = <ProgrammeVersionWeek>[];
  final days = <ProgrammeVersionDay>[];
  final slots = <ProgrammeVersionSessionSlot>[];
  final assignments = <ProgrammeAssignment>[];
  final outcomes = <ProgrammeSlotOutcome>[];
  final athleteStates = <AthleteState>[];

  bool denyReads = false;
  bool denyWrites = false;
}

class InMemoryProgrammeVersionStore implements ProgrammeVersionStore {
  InMemoryProgrammeVersionStore(this.tables);

  final InMemoryProgrammeTables tables;
  final ProgrammeTemplateTreeAssembler assembler =
      const ProgrammeTemplateTreeAssembler();

  void _guardRead() {
    if (tables.denyReads) {
      throw ProgrammeStoreException(
        'permission denied for table programme_versions',
        code: '42501',
      );
    }
  }

  void _guardWrite() {
    if (tables.denyWrites) {
      throw ProgrammeStoreException(
        'permission denied for table programme_versions',
        code: '42501',
      );
    }
  }

  @override
  Future<ProgrammeLineage?> getLineageByCode(String code) async {
    _guardRead();

    for (final lineage in tables.lineages) {
      if (lineage.code == code) return lineage;
    }

    return null;
  }

  @override
  Future<ProgrammeLineage?> getLineageById(String lineageId) async {
    _guardRead();

    for (final lineage in tables.lineages) {
      if (lineage.id == lineageId) return lineage;
    }

    return null;
  }

  @override
  Future<ProgrammeVersion?> getVersionByLineageAndNumber({
    required String lineageCode,
    required int versionNumber,
  }) async {
    final lineage = await getLineageByCode(lineageCode);
    if (lineage == null) return null;

    for (final version in tables.versions) {
      if (version.lineageId == lineage.id &&
          version.versionNumber == versionNumber) {
        return version;
      }
    }

    return null;
  }

  @override
  Future<ProgrammeVersion?> getVersionById(String versionId) async {
    _guardRead();

    for (final version in tables.versions) {
      if (version.id == versionId) return version;
    }

    return null;
  }

  @override
  Future<ProgrammeVersion?> getPublishedVersion({
    required String lineageCode,
    required int versionNumber,
  }) async {
    final lineage = await getLineageByCode(lineageCode);
    if (lineage == null) return null;

    for (final version in tables.versions) {
      if (version.lineageId == lineage.id &&
          version.versionNumber == versionNumber &&
          version.isPublished) {
        return version;
      }
    }

    return null;
  }

  @override
  Future<ProgrammeTemplateTree?> loadTemplateTree(String versionId) async {
    _guardRead();

    final version = await getVersionById(versionId);
    if (version == null) return null;

    return assembler.assemble(
      version: version,
      phases: tables.phases.where((row) => row.versionId == versionId).toList(),
      weeks: tables.weeks.where((row) => row.versionId == versionId).toList(),
      days: tables.days
          .where(
            (row) => tables.weeks
                .where((week) => week.versionId == versionId)
                .any((week) => week.id == row.weekId),
          )
          .toList(),
      slots: tables.slots
          .where(
            (row) => tables.days.any((day) => day.id == row.dayId),
          )
          .toList(),
    );
  }

  @override
  Future<ProgrammeVersion> saveDraftVersion(ProgrammeVersion version) async {
    _guardWrite();

    final resolved = version.id.isEmpty
        ? version.copyWith(
            id: 'version-${tables.versions.length + 1}',
            updatedAt: DateTime.now().toUtc(),
          )
        : version.copyWith(updatedAt: DateTime.now().toUtc());

    final index = tables.versions.indexWhere((row) => row.id == resolved.id);
    if (index == -1) {
      tables.versions.add(resolved);
      return resolved;
    }

    tables.versions[index] = resolved;
    return resolved;
  }

  @override
  Future<void> saveTemplateTree({
    required ProgrammeVersion version,
    required ProgrammeTemplateTree tree,
  }) async {
    _guardWrite();

    final savedVersion = await saveDraftVersion(version);

    final weekIds = tables.weeks
        .where((row) => row.versionId == savedVersion.id)
        .map((row) => row.id)
        .toSet();

    tables.slots.removeWhere(
      (slot) => tables.days.any(
        (day) => weekIds.contains(day.weekId) && day.id == slot.dayId,
      ),
    );
    tables.days.removeWhere((day) => weekIds.contains(day.weekId));
    tables.weeks.removeWhere((row) => row.versionId == savedVersion.id);
    tables.phases.removeWhere((row) => row.versionId == savedVersion.id);

    tables.phases.addAll(tree.template.phases);
    for (final weekNode in tree.weekNodes) {
      tables.weeks.add(weekNode.week);
      for (final dayNode in weekNode.days) {
        tables.days.add(dayNode.day);
        tables.slots.addAll(dayNode.slots);
      }
    }
  }

  @override
  Future<List<ProgrammeCatalogEntry>> listCatalogueVersions(
    ProgrammeCatalogueQuery query,
  ) async {
    _guardRead();

    final lineageById = {
      for (final lineage in tables.lineages) lineage.id: lineage.code,
    };

    return tables.versions
        .where((version) {
          if (query.libraryScope != null &&
              version.libraryScope != query.libraryScope) {
            return false;
          }

          if (query.ownerType != null && version.ownerType != query.ownerType) {
            return false;
          }

          if (query.ownerId != null && version.ownerId != query.ownerId) {
            return false;
          }

          if (query.includeGlobalApprovedOnly && !version.approvedForGlobal) {
            return false;
          }

          if (query.lifecycleStatus != null &&
              version.lifecycleStatus != query.lifecycleStatus) {
            return false;
          }

          if (query.primaryGoal != null &&
              query.primaryGoal!.trim().isNotEmpty &&
              version.primaryGoal != query.primaryGoal) {
            return false;
          }

          return true;
        })
        .map(
          (version) => ProgrammeCatalogEntry(
            versionId: version.id,
            lineageCode: lineageById[version.lineageId] ?? '',
            versionNumber: version.versionNumber,
            name: version.name,
            lifecycleStatus: version.lifecycleStatus,
            libraryScope: version.libraryScope,
            ownerType: version.ownerType,
            ownerId: version.ownerId,
            description: version.description,
            durationWeeks: version.durationWeeks,
            difficulty: version.difficulty,
            primaryGoal: version.primaryGoal,
            sessionsPerWeek: version.sessionsPerWeek,
            approvedForGlobal: version.approvedForGlobal,
            updatedAt: version.updatedAt,
            publishedAt: version.publishedAt,
            archivedAt: version.archivedAt,
          ),
        )
        .where((entry) {
          final term = query.searchTerm?.trim().toLowerCase();
          if (term == null || term.isEmpty) return true;

          return entry.name.toLowerCase().contains(term) ||
              entry.lineageCode.toLowerCase().contains(term) ||
              (entry.description?.toLowerCase().contains(term) ?? false);
        })
        .toList();
  }

  @override
  Future<ProgrammeLineage> insertLineage(ProgrammeLineage lineage) async {
    _guardWrite();

    final created = lineage.copyWith(
      id: lineage.id.isEmpty
          ? 'lineage-${tables.lineages.length + 1}'
          : lineage.id,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );
    tables.lineages.add(created);
    return created;
  }

  @override
  Future<void> deleteDraftVersion(String versionId) async {
    _guardWrite();

    final weekIds = tables.weeks
        .where((week) => week.versionId == versionId)
        .map((week) => week.id)
        .toList();
    final dayIds = tables.days
        .where((day) => weekIds.contains(day.weekId))
        .map((day) => day.id)
        .toList();

    tables.slots.removeWhere((slot) => dayIds.contains(slot.dayId));
    tables.days.removeWhere((day) => weekIds.contains(day.weekId));
    tables.weeks.removeWhere((week) => week.versionId == versionId);
    tables.phases.removeWhere((phase) => phase.versionId == versionId);
    tables.versions.removeWhere((version) => version.id == versionId);
  }
}

class InMemoryProgrammeAssignmentStore implements ProgrammeAssignmentStore {
  InMemoryProgrammeAssignmentStore(this.tables);

  final InMemoryProgrammeTables tables;
  int _fakeAssignmentIdSequence = 0;

  void _guardRead() {
    if (tables.denyReads) {
      throw ProgrammeStoreException(
        'permission denied for table programme_assignments',
        code: '42501',
      );
    }
  }

  void _guardWrite() {
    if (tables.denyWrites) {
      throw ProgrammeStoreException(
        'permission denied for table programme_assignments',
        code: '42501',
      );
    }
  }

  @override
  Future<ProgrammeAssignment?> getActiveAssignment(String athleteId) async {
    _guardRead();

    for (final assignment in tables.assignments) {
      if (assignment.athleteId == athleteId && assignment.isActive) {
        return assignment;
      }
    }

    return null;
  }

  @override
  Future<ProgrammeAssignment?> getById(String assignmentId) async {
    _guardRead();

    for (final assignment in tables.assignments) {
      if (assignment.id == assignmentId) return assignment;
    }

    return null;
  }

  @override
  Future<ProgrammeAssignment> insert(ProgrammeAssignment assignment) async {
    _guardWrite();

    if (assignment.isActive) {
      final existing = await getActiveAssignment(assignment.athleteId);
      if (existing != null) {
        throw ProgrammeStoreException(
          'Athlete already has an active programme assignment',
          code: '23505',
        );
      }
    }

    final persisted = assignment.id.trim().isEmpty
        ? assignment.copyWith(
            id: 'assignment-test-${++_fakeAssignmentIdSequence}',
          )
        : assignment;

    tables.assignments.add(persisted);
    return persisted;
  }

  @override
  Future<ProgrammeAssignment> update(ProgrammeAssignment assignment) async {
    _guardWrite();

    if (assignment.isActive) {
      final existing = await getActiveAssignment(assignment.athleteId);
      if (existing != null && existing.id != assignment.id) {
        throw ProgrammeStoreException(
          'Athlete already has a different active programme assignment',
          code: '23505',
        );
      }
    }

    final index =
        tables.assignments.indexWhere((row) => row.id == assignment.id);
    if (index == -1) {
      throw ProgrammeStoreException('Assignment not found');
    }

    tables.assignments[index] = assignment;
    return assignment;
  }

  @override
  Future<List<ProgrammeAssignment>> listForAthlete(String athleteId) async {
    _guardRead();

    return tables.assignments
        .where((assignment) => assignment.athleteId == athleteId)
        .toList();
  }

  @override
  Future<int> countAssignmentsForVersion(String programmeVersionId) async {
    _guardRead();

    return tables.assignments
        .where(
          (assignment) => assignment.programmeVersionId == programmeVersionId,
        )
        .length;
  }
}

class InMemoryProgrammeSlotOutcomeStore implements ProgrammeSlotOutcomeStore {
  InMemoryProgrammeSlotOutcomeStore(this.tables);

  final InMemoryProgrammeTables tables;

  /// When true, [deleteOutcomesForAssignment] throws an RLS-style access error.
  bool denyDelete = false;

  /// When true, simulates RLS blocking DELETE (returns zero without removing rows).
  bool simulateRlsBlockedDelete = false;

  void _guardRead() {
    if (tables.denyReads) {
      throw ProgrammeStoreException(
        'permission denied for table programme_slot_outcomes',
        code: '42501',
      );
    }
  }

  void _guardWrite() {
    if (tables.denyWrites) {
      throw ProgrammeStoreException(
        'permission denied for table programme_slot_outcomes',
        code: '42501',
      );
    }
  }

  @override
  Future<ProgrammeSlotOutcome?> getForSlot({
    required String assignmentId,
    required String sessionSlotId,
  }) async {
    _guardRead();

    for (final outcome in tables.outcomes) {
      if (outcome.assignmentId == assignmentId &&
          outcome.sessionSlotId == sessionSlotId) {
        return outcome;
      }
    }

    return null;
  }

  @override
  Future<List<ProgrammeSlotOutcome>> listForAssignment(
    String assignmentId,
  ) async {
    _guardRead();

    return tables.outcomes
        .where((outcome) => outcome.assignmentId == assignmentId)
        .toList();
  }

  @override
  Future<List<ProgrammeSlotOutcome>> listForDay({
    required String assignmentId,
    required int weekNumber,
    required String dayKey,
  }) async {
    _guardRead();

    return tables.outcomes
        .where(
          (outcome) =>
              outcome.assignmentId == assignmentId &&
              outcome.weekNumber == weekNumber &&
              outcome.dayKey == dayKey,
        )
        .toList();
  }

  @override
  Future<ProgrammeSlotOutcome> upsert(ProgrammeSlotOutcome outcome) async {
    _guardWrite();

    final index = tables.outcomes.indexWhere(
      (row) =>
          row.assignmentId == outcome.assignmentId &&
          row.sessionSlotId == outcome.sessionSlotId,
    );

    if (index == -1) {
      tables.outcomes.add(outcome);
      return outcome;
    }

    tables.outcomes[index] = outcome;
    return outcome;
  }

  @override
  Future<ProgrammeSlotOutcomeDeleteResult> deleteOutcomesForAssignment({
    required String assignmentId,
  }) async {
    if (denyDelete) {
      throw ProgrammeStoreException(
        'permission denied for table programme_slot_outcomes',
        code: '42501',
        operation: 'deleteOutcomesForAssignment',
        tableName: 'programme_slot_outcomes',
      );
    }

    _guardWrite();

    if (simulateRlsBlockedDelete) {
      return const ProgrammeSlotOutcomeDeleteResult(
        deletedCount: 0,
        deletedIds: [],
      );
    }

    final deleted = tables.outcomes
        .where((outcome) => outcome.assignmentId == assignmentId)
        .toList();
    tables.outcomes.removeWhere(
      (outcome) => outcome.assignmentId == assignmentId,
    );

    return ProgrammeSlotOutcomeDeleteResult(
      deletedCount: deleted.length,
      deletedIds: deleted.map((outcome) => outcome.id).toList(),
    );
  }
}

class InMemoryAthleteStateStore implements AthleteStateStore {
  InMemoryAthleteStateStore(this.tables);

  final InMemoryProgrammeTables tables;

  void _guardRead() {
    if (tables.denyReads) {
      throw ProgrammeStoreException(
        'permission denied for table athlete_state',
        code: '42501',
      );
    }
  }

  void _guardWrite() {
    if (tables.denyWrites) {
      throw ProgrammeStoreException(
        'permission denied for table athlete_state',
        code: '42501',
      );
    }
  }

  @override
  Future<AthleteState?> getByAthleteId(String athleteId) async {
    _guardRead();

    final matches = tables.athleteStates
        .where((state) => state.athleteId == athleteId)
        .toList();

    if (matches.length > 1) {
      throw ProgrammeStoreException(
        'athlete_state has duplicate rows for athlete_id $athleteId',
        code: '23505',
        operation: 'getByAthleteId',
        tableName: 'athlete_state',
        conflictTarget: 'athlete_id',
      );
    }

    if (matches.isEmpty) return null;

    return matches.first;
  }

  @override
  Future<void> upsertProjection(AthleteState projection) async {
    _guardWrite();

    final matches = tables.athleteStates
        .where((row) => row.athleteId == projection.athleteId)
        .toList();

    if (matches.length > 1) {
      throw ProgrammeStoreException(
        'athlete_state has duplicate rows for athlete_id ${projection.athleteId}',
        code: '23505',
        operation: 'upsertProjection',
        tableName: 'athlete_state',
        conflictTarget: 'athlete_id',
      );
    }

    final index = tables.athleteStates
        .indexWhere((row) => row.athleteId == projection.athleteId);
    if (index == -1) {
      tables.athleteStates.add(projection);
      return;
    }

    tables.athleteStates[index] = projection;
  }

  @override
  Future<void> clearProgrammeProjection(String athleteId) async {
    _guardWrite();

    final index =
        tables.athleteStates.indexWhere((row) => row.athleteId == athleteId);
    if (index == -1) return;

    tables.athleteStates[index] = tables.athleteStates[index].copyWith(
      clearProgrammeId: true,
      clearCurrentWeek: true,
      clearCurrentDay: true,
      clearCurrentProtocolId: true,
      clearSessionStatus: true,
    );
  }
}
