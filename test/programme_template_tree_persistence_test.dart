import 'package:cohort_platform/core/utils/database_uuid.dart';
import 'package:cohort_platform/data/repositories/programme_template_tree_assembler.dart';
import 'package:cohort_platform/features/programme/models/programme_template.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_builder_document.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_seed_template.dart';
import 'package:cohort_platform/features/programme_builder/models/programme_version_draft_metadata.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_builder_compiler.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_seed_template_builder.dart';
import 'package:cohort_platform/models/programme_lineage.dart';
import 'package:cohort_platform/models/programme_version.dart';
import 'package:cohort_platform/models/programme_version_day.dart';
import 'package:cohort_platform/models/programme_version_phase.dart';
import 'package:cohort_platform/models/programme_version_session_slot.dart';
import 'package:cohort_platform/models/programme_version_week.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/in_memory_programme_stores.dart';

void main() {
  const compiler = ProgrammeBuilderCompiler();
  const seedBuilder = ProgrammeSeedTemplateBuilder();
  const assembler = ProgrammeTemplateTreeAssembler();
  const persistedWeekId = '11111111-1111-4111-8111-111111111111';
  const persistedDayId = '22222222-2222-4222-8222-222222222222';
  const persistedSlotId = '33333333-3333-4333-8333-333333333333';
  const persistedPhaseId = '44444444-4444-4444-8444-444444444444';

  group('DatabaseUuid', () {
    test('rejects client local ids', () {
      expect(DatabaseUuid.isValidDatabaseUuid('week-1'), isFalse);
      expect(DatabaseUuid.isValidDatabaseUuid('day-1'), isFalse);
      expect(DatabaseUuid.isValidDatabaseUuid('slot-1'), isFalse);
      expect(DatabaseUuid.isValidDatabaseUuid('local-123'), isFalse);
      expect(DatabaseUuid.isValidDatabaseUuid(''), isFalse);
      expect(DatabaseUuid.isValidDatabaseUuid(null), isFalse);
    });

    test('accepts RFC-4122 UUID strings', () {
      expect(DatabaseUuid.isValidDatabaseUuid(persistedWeekId), isTrue);
      expect(
        DatabaseUuid.persistedIdOrNull(persistedWeekId),
        persistedWeekId,
      );
    });
  });

  group('template node toInsertMap', () {
    test('omits non-UUID week localId from insert payload', () {
      final payload = ProgrammeVersionWeek(
        id: 'week-1',
        versionId: 'version-1',
        weekNumber: 1,
      ).toInsertMap();

      expect(payload.containsKey('id'), isFalse);
      expect(payload['version_id'], 'version-1');
    });

    test('includes valid UUID week id in insert payload', () {
      final payload = ProgrammeVersionWeek(
        id: persistedWeekId,
        versionId: 'version-1',
        weekNumber: 1,
      ).toInsertMap();

      expect(payload['id'], persistedWeekId);
    });

    test('omits non-UUID day localId from insert payload', () {
      final payload = ProgrammeVersionDay(
        id: 'day-1',
        weekId: 'week-1',
        dayKey: 'day_1',
        dayOrder: 1,
      ).toInsertMap();

      expect(payload.containsKey('id'), isFalse);
      expect(payload['week_id'], 'week-1');
    });

    test('omits non-UUID slot localId from insert payload', () {
      final payload = ProgrammeVersionSessionSlot(
        id: 'slot-1',
        dayId: 'day-1',
        sessionOrder: 1,
        protocolId: 'BW-001',
      ).toInsertMap();

      expect(payload.containsKey('id'), isFalse);
      expect(payload['day_id'], 'day-1');
    });

    test('includes valid UUID slot id in insert payload', () {
      final payload = ProgrammeVersionSessionSlot(
        id: persistedSlotId,
        dayId: persistedDayId,
        sessionOrder: 1,
        protocolId: 'BW-001',
      ).toInsertMap();

      expect(payload['id'], persistedSlotId);
    });

    test('omits non-UUID phase localId and invalid phase_id references', () {
      final phasePayload = ProgrammeVersionPhase(
        id: 'phase-1',
        versionId: 'version-1',
        phaseOrder: 1,
        title: 'Build',
      ).toInsertMap();
      expect(phasePayload.containsKey('id'), isFalse);

      final weekPayload = ProgrammeVersionWeek(
        id: 'week-1',
        versionId: 'version-1',
        weekNumber: 1,
        phaseId: 'phase-1',
      ).toInsertMap();
      expect(weekPayload.containsKey('phase_id'), isFalse);
    });

    test('retains valid UUID phase_id reference', () {
      final payload = ProgrammeVersionWeek(
        id: persistedWeekId,
        versionId: 'version-1',
        weekNumber: 1,
        phaseId: persistedPhaseId,
      ).toInsertMap();

      expect(payload['phase_id'], persistedPhaseId);
    });
  });

  group('InMemoryProgrammeVersionStore template persistence', () {
    Future<ProgrammeVersion> _seedVersion(InMemoryProgrammeVersionStore store) {
      return store.saveDraftVersion(
        ProgrammeVersion(
          id: '',
          lineageId: 'lineage-1',
          versionNumber: 1,
          lifecycleStatus: ProgrammeLifecycleStatus.draft,
          libraryScope: ProgrammeLibraryScope.coachPrivate,
          ownerType: ProgrammeOwnerType.coach,
          ownerId: 'dev-coach',
          name: 'Hybrid Test',
        ),
      );
    }

    ProgrammeTemplateTree _treeFromSeed(ProgrammeSeedTemplate template) {
      final document = ProgrammeBuilderDocument.clean(
        metadata: const ProgrammeVersionDraftMetadata(
          lineageCode: 'COHORT-TREE-TEST',
          versionNumber: 1,
          name: 'Tree Test',
        ),
        template: seedBuilder.build(template),
      );
      return compiler.toTemplateTree(document);
    }

    test('hybrid seed save stores only database UUID ids', () async {
      final tables = InMemoryProgrammeTables();
      final store = InMemoryProgrammeVersionStore(tables);
      final version = await _seedVersion(store);

      await store.saveTemplateTree(
        version: version,
        tree: _treeFromSeed(ProgrammeSeedTemplate.hybrid),
      );

      expect(tables.weeks, isNotEmpty);
      for (final week in tables.weeks) {
        expect(DatabaseUuid.isValidDatabaseUuid(week.id), isTrue);
        expect(week.id, isNot('week-1'));
      }
      for (final day in tables.days) {
        expect(DatabaseUuid.isValidDatabaseUuid(day.id), isTrue);
        expect(day.id.startsWith('day-'), isFalse);
        expect(DatabaseUuid.isValidDatabaseUuid(day.weekId), isTrue);
      }
      for (final slot in tables.slots) {
        expect(DatabaseUuid.isValidDatabaseUuid(slot.id), isTrue);
        expect(slot.id.startsWith('slot-'), isFalse);
        expect(DatabaseUuid.isValidDatabaseUuid(slot.dayId), isTrue);
      }
    });

    test('second save after reload keeps valid UUID ids without local id errors', () async {
      final tables = InMemoryProgrammeTables();
      final store = InMemoryProgrammeVersionStore(tables);
      final version = await _seedVersion(store);
      final tree = _treeFromSeed(ProgrammeSeedTemplate.strength);

      await store.saveTemplateTree(version: version, tree: tree);

      final reloaded = await store.loadTemplateTree(version.id);
      expect(reloaded, isNotNull);

      await store.saveTemplateTree(
        version: version,
        tree: reloaded!,
      );

      for (final week in tables.weeks) {
        expect(DatabaseUuid.isValidDatabaseUuid(week.id), isTrue);
        expect(week.id, isNot('week-1'));
      }
      for (final day in tables.days) {
        expect(DatabaseUuid.isValidDatabaseUuid(day.id), isTrue);
        expect(day.id.startsWith('day-'), isFalse);
      }
      for (final slot in tables.slots) {
        expect(DatabaseUuid.isValidDatabaseUuid(slot.id), isTrue);
        expect(slot.id.startsWith('slot-'), isFalse);
      }
    });

    test('save reload round trip preserves structure', () async {
      final tables = InMemoryProgrammeTables();
      final store = InMemoryProgrammeVersionStore(tables);
      final version = await _seedVersion(store);
      final sourceTree = _treeFromSeed(ProgrammeSeedTemplate.hybrid);

      await store.saveTemplateTree(version: version, tree: sourceTree);
      final loaded = await store.loadTemplateTree(version.id);
      expect(loaded, isNotNull);

      expect(loaded!.weekNodes.length, sourceTree.weekNodes.length);
      expect(
        loaded.weekNodes.first.sortedDays.length,
        sourceTree.weekNodes.first.sortedDays.length,
      );
      expect(
        loaded.weekNodes.first.sortedDays.first.sortedSlots.length,
        sourceTree.weekNodes.first.sortedDays.first.sortedSlots.length,
      );
      expect(loaded.weekNodes.first.week.weekNumber, 1);
      expect(
        loaded.weekNodes.first.sortedDays.first.day.dayKey,
        'day_1',
      );
    });

    test('retains persisted UUID ids when reloading existing draft tree', () async {
      final tables = InMemoryProgrammeTables();
      final store = InMemoryProgrammeVersionStore(tables);
      final version = await _seedVersion(store);

      final tree = assembler.assemble(
        version: version,
        phases: [
          ProgrammeVersionPhase(
            id: persistedPhaseId,
            versionId: version.id,
            phaseOrder: 1,
            title: 'Build',
          ),
        ],
        weeks: [
          ProgrammeVersionWeek(
            id: persistedWeekId,
            versionId: version.id,
            phaseId: persistedPhaseId,
            weekNumber: 1,
          ),
        ],
        days: [
          ProgrammeVersionDay(
            id: persistedDayId,
            weekId: persistedWeekId,
            dayKey: 'day_1',
            dayOrder: 1,
          ),
        ],
        slots: [
          ProgrammeVersionSessionSlot(
            id: persistedSlotId,
            dayId: persistedDayId,
            sessionOrder: 1,
            protocolId: 'BW-001',
          ),
        ],
      );

      await store.saveTemplateTree(version: version, tree: tree);

      expect(tables.weeks.single.id, persistedWeekId);
      expect(tables.days.single.id, persistedDayId);
      expect(tables.slots.single.id, persistedSlotId);
      expect(tables.phases.single.id, persistedPhaseId);
    });
  });
}
