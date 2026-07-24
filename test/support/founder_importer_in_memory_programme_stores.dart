/// In-memory programme version store for founder_importer tests.
import 'package:founder_importer/core/utils/database_uuid.dart';
import 'package:founder_importer/data/repositories/programme_store_exception.dart';
import 'package:founder_importer/data/repositories/programme_template_tree_assembler.dart';
import 'package:founder_importer/data/repositories/programme_version_store.dart';
import 'package:founder_importer/features/programme/models/programme_catalog_entry.dart';
import 'package:founder_importer/features/programme/models/programme_template.dart';
import 'package:founder_importer/models/programme_lineage.dart';
import 'package:founder_importer/models/programme_version.dart';
import 'package:founder_importer/models/programme_version_day.dart';
import 'package:founder_importer/models/programme_version_phase.dart';
import 'package:founder_importer/models/programme_version_session_slot.dart';
import 'package:founder_importer/models/programme_version_week.dart';
import 'package:founder_importer/models/programme_vocabulary.dart';

/// In-memory Programme Engine stores for unit tests.
class InMemoryProgrammeTables {
  final lineages = <ProgrammeLineage>[];
  final versions = <ProgrammeVersion>[];
  final phases = <ProgrammeVersionPhase>[];
  final weeks = <ProgrammeVersionWeek>[];
  final days = <ProgrammeVersionDay>[];
  final slots = <ProgrammeVersionSessionSlot>[];

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
  Future<ProgrammeLineage?> getLineageByImportKey(String importKey) async {
    _guardRead();

    for (final lineage in tables.lineages) {
      if (lineage.importKey == importKey) return lineage;
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

    var generatedIdCounter = 0;
    String resolvePersistedId(String candidate) {
      if (DatabaseUuid.isValidDatabaseUuid(candidate)) {
        return candidate.trim();
      }

      generatedIdCounter += 1;
      final suffix = generatedIdCounter.toRadixString(16).padLeft(12, '0');
      return '00000000-0000-4000-8000-$suffix';
    }

    final phaseIdsByLocalId = <String, String>{};
    for (final phase in tree.template.phases) {
      final phaseId = resolvePersistedId(phase.id);
      phaseIdsByLocalId[phase.id] = phaseId;
      tables.phases.add(
        ProgrammeVersionPhase(
          id: phaseId,
          versionId: savedVersion.id,
          phaseOrder: phase.phaseOrder,
          title: phase.title,
          intent: phase.intent,
          coachNote: phase.coachNote,
        ),
      );
    }

    for (final weekNode in tree.weekNodes) {
      final weekId = resolvePersistedId(weekNode.week.id);
      final phaseId = weekNode.week.phaseId == null
          ? null
          : phaseIdsByLocalId[weekNode.week.phaseId!] ??
              (DatabaseUuid.isValidDatabaseUuid(weekNode.week.phaseId)
                  ? weekNode.week.phaseId!.trim()
                  : null);

      tables.weeks.add(
        ProgrammeVersionWeek(
          id: weekId,
          versionId: savedVersion.id,
          phaseId: phaseId,
          weekNumber: weekNode.week.weekNumber,
          title: weekNode.week.title,
          intent: weekNode.week.intent,
          coachNote: weekNode.week.coachNote,
          athleteNote: weekNode.week.athleteNote,
        ),
      );

      for (final dayNode in weekNode.days) {
        final dayId = resolvePersistedId(dayNode.day.id);
        tables.days.add(
          ProgrammeVersionDay(
            id: dayId,
            weekId: weekId,
            dayKey: dayNode.day.dayKey,
            dayOrder: dayNode.day.dayOrder,
            title: dayNode.day.title,
            dayType: dayNode.day.dayType,
            intent: dayNode.day.intent,
            coachNote: dayNode.day.coachNote,
            athleteNote: dayNode.day.athleteNote,
          ),
        );

        for (final slot in dayNode.slots) {
          final slotId = resolvePersistedId(slot.id);
          tables.slots.add(
            ProgrammeVersionSessionSlot(
              id: slotId,
              dayId: dayId,
              sessionOrder: slot.sessionOrder,
              protocolId: slot.protocolId,
              displayTitle: slot.displayTitle,
              timeOfDay: slot.timeOfDay,
              isOptional: slot.isOptional,
              completionExpectation: slot.completionExpectation,
              coachNote: slot.coachNote,
              athleteNote: slot.athleteNote,
            ),
          );
        }
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
