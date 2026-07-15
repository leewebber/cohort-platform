import 'package:cohort_platform/data/repositories/programme_store_exception.dart';
import 'package:cohort_platform/data/repositories/programme_template_tree_assembler.dart';
import 'package:cohort_platform/features/programme/models/programme_catalog_entry.dart';
import 'package:cohort_platform/features/programme/models/programme_template.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:cohort_platform/models/programme_slot_outcome.dart';
import 'package:cohort_platform/models/programme_version.dart';
import 'package:cohort_platform/models/programme_version_day.dart';
import 'package:cohort_platform/models/programme_version_phase.dart';
import 'package:cohort_platform/models/programme_version_session_slot.dart';
import 'package:cohort_platform/models/programme_version_week.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/in_memory_programme_stores.dart';

void main() {
  const assembler = ProgrammeTemplateTreeAssembler();

  group('ProgrammeTemplateTreeAssembler', () {
    test('loads complete flat-week tree in deterministic order', () {
      final version = _version(id: 'version-1');
      final week = _week(id: 'week-1', versionId: version.id, weekNumber: 1);
      final dayOne = _day(
        id: 'day-1',
        weekId: week.id,
        dayKey: 'day_1',
        dayOrder: 1,
      );
      final dayTwo = _day(
        id: 'day-2',
        weekId: week.id,
        dayKey: 'day_2',
        dayOrder: 2,
      );
      final slotOne = _slot(
        id: 'slot-1',
        dayId: dayOne.id,
        sessionOrder: 1,
        protocolId: 'BW-001',
      );
      final slotTwo = _slot(
        id: 'slot-2',
        dayId: dayTwo.id,
        sessionOrder: 1,
        protocolId: 'RN-006',
      );

      final tree = assembler.assemble(
        version: version,
        phases: const [],
        weeks: [week],
        days: [dayTwo, dayOne],
        slots: [slotTwo, slotOne],
      );

      expect(tree.weekNodes, hasLength(1));
      expect(tree.weekNodes.first.sortedDays.first.day.dayKey, 'day_1');
      expect(tree.weekNodes.first.sortedDays.last.day.dayKey, 'day_2');
      expect(
        tree.weekNodes.first.sortedDays.first.sortedSlots.first.protocolId,
        'BW-001',
      );
    });

    test('loads phased programme with ordered phases and weeks', () {
      final version = _version(id: 'version-phased');
      final phase = ProgrammeVersionPhase(
        id: 'phase-1',
        versionId: version.id,
        phaseOrder: 1,
        title: 'Build',
        intent: ProgrammeIntent.build,
      );
      final week = _week(
        id: 'week-1',
        versionId: version.id,
        weekNumber: 1,
        phaseId: phase.id,
      );
      final day = _day(
        id: 'day-1',
        weekId: week.id,
        dayKey: 'day_1',
        dayOrder: 1,
      );
      final slot = _slot(
        id: 'slot-1',
        dayId: day.id,
        sessionOrder: 1,
        protocolId: 'FG-009',
      );

      final tree = assembler.assemble(
        version: version,
        phases: [phase],
        weeks: [week],
        days: [day],
        slots: [slot],
      );

      expect(tree.template.phases, hasLength(1));
      expect(tree.template.phases.first.title, 'Build');
      expect(tree.weekNodes.first.week.phaseId, phase.id);
    });
  });

  group('InMemoryProgrammeVersionStore', () {
    test('loads one requested version tree without catalogue fan-out', () async {
      final tables = InMemoryProgrammeTables();
      final store = InMemoryProgrammeVersionStore(tables);

      final version = _version(id: 'version-1');
      final otherVersion = _version(id: 'version-2', name: 'Other');
      final week = _week(id: 'week-1', versionId: version.id, weekNumber: 1);
      final day = _day(
        id: 'day-1',
        weekId: week.id,
        dayKey: 'day_1',
        dayOrder: 1,
      );
      final slot = _slot(
        id: 'slot-1',
        dayId: day.id,
        sessionOrder: 1,
        protocolId: 'BW-001',
      );

      tables.versions.addAll([version, otherVersion]);
      tables.weeks.add(week);
      tables.days.add(day);
      tables.slots.add(slot);

      final tree = await store.loadTemplateTree(version.id);

      expect(tree, isNotNull);
      expect(tree!.template.version.id, version.id);
      expect(tree.weekNodes, hasLength(1));
      expect(await store.listCatalogueVersions(const ProgrammeCatalogueQuery()),
          hasLength(2));
    });

    test('surfaces access denied instead of swallowing RLS failures', () async {
      final tables = InMemoryProgrammeTables()..denyReads = true;
      final store = InMemoryProgrammeVersionStore(tables);

      expect(
        () => store.getVersionById('version-1'),
        throwsA(
          isA<ProgrammeStoreException>().having(
            (error) => error.isAccessDenied,
            'isAccessDenied',
            isTrue,
          ),
        ),
      );
    });
  });

  group('InMemoryProgrammeAssignmentStore', () {
    test('finds active assignment for athlete', () async {
      final tables = InMemoryProgrammeTables();
      final store = InMemoryProgrammeAssignmentStore(tables);

      tables.assignments.addAll([
        _assignment(id: 'a-1', athleteId: 'lee', status: ProgrammeAssignmentStatus.completed),
        _assignment(id: 'a-2', athleteId: 'lee', status: ProgrammeAssignmentStatus.active),
      ]);

      final active = await store.getActiveAssignment('lee');

      expect(active?.id, 'a-2');
    });

    test('updates assignment cursor fields', () async {
      final tables = InMemoryProgrammeTables();
      final store = InMemoryProgrammeAssignmentStore(tables);
      final assignment = _assignment(id: 'a-1', athleteId: 'lee');

      tables.assignments.add(assignment);

      final updated = await store.update(
        assignment.copyWith(
          currentWeek: 1,
          currentDayKey: 'day_2',
          currentSessionOrder: 1,
        ),
      );

      expect(updated.currentDayKey, 'day_2');
      expect((await store.getById('a-1'))?.currentDayKey, 'day_2');
    });

    test('enforces one active assignment per athlete defensively', () async {
      final tables = InMemoryProgrammeTables();
      final store = InMemoryProgrammeAssignmentStore(tables);

      tables.assignments.add(
        _assignment(id: 'a-1', athleteId: 'lee', status: ProgrammeAssignmentStatus.active),
      );

      expect(
        () => store.insert(
          _assignment(id: 'a-2', athleteId: 'lee', status: ProgrammeAssignmentStatus.active),
        ),
        throwsA(
          isA<ProgrammeStoreException>().having(
            (error) => error.isUniqueViolation,
            'isUniqueViolation',
            isTrue,
          ),
        ),
      );
    });
  });

  group('InMemoryProgrammeSlotOutcomeStore', () {
    test('enforces one outcome per assignment and slot', () async {
      final tables = InMemoryProgrammeTables();
      final store = InMemoryProgrammeSlotOutcomeStore(tables);

      final first = _outcome(
        id: 'o-1',
        assignmentId: 'a-1',
        sessionSlotId: 'slot-1',
        status: ProgrammeSlotOutcomeStatus.scheduled,
      );
      final replaced = _outcome(
        id: 'o-1',
        assignmentId: 'a-1',
        sessionSlotId: 'slot-1',
        status: ProgrammeSlotOutcomeStatus.completed,
        trainingSessionId: 42,
      );

      await store.upsert(first);
      final updated = await store.upsert(replaced);

      expect(tables.outcomes, hasLength(1));
      expect(updated.outcomeStatus, ProgrammeSlotOutcomeStatus.completed);
      expect(updated.trainingSessionId, 42);
    });

    test('keeps completed_partial distinct from completed', () async {
      final tables = InMemoryProgrammeTables();
      final store = InMemoryProgrammeSlotOutcomeStore(tables);

      final partial = _outcome(
        id: 'o-partial',
        assignmentId: 'a-1',
        sessionSlotId: 'slot-1',
        status: ProgrammeSlotOutcomeStatus.completedPartial,
        trainingSessionId: 11,
      );
      final completed = _outcome(
        id: 'o-complete',
        assignmentId: 'a-1',
        sessionSlotId: 'slot-2',
        status: ProgrammeSlotOutcomeStatus.completed,
        trainingSessionId: 12,
      );

      await store.upsert(partial);
      await store.upsert(completed);

      final outcomes = await store.listForAssignment('a-1');

      expect(
        outcomes.map((outcome) => outcome.outcomeStatus).toSet(),
        {
          ProgrammeSlotOutcomeStatus.completedPartial,
          ProgrammeSlotOutcomeStatus.completed,
        },
      );
      expect(partial.outcomeStatus.isTerminal, isTrue);
      expect(partial.outcomeStatus, isNot(ProgrammeSlotOutcomeStatus.completed));
    });

    test('lists outcomes for a specific assignment day', () async {
      final tables = InMemoryProgrammeTables();
      final store = InMemoryProgrammeSlotOutcomeStore(tables);

      await store.upsert(
        _outcome(
          id: 'o-1',
          assignmentId: 'a-1',
          sessionSlotId: 'slot-1',
          weekNumber: 1,
          dayKey: 'day_1',
          status: ProgrammeSlotOutcomeStatus.scheduled,
        ),
      );
      await store.upsert(
        _outcome(
          id: 'o-2',
          assignmentId: 'a-1',
          sessionSlotId: 'slot-2',
          weekNumber: 1,
          dayKey: 'day_2',
          status: ProgrammeSlotOutcomeStatus.scheduled,
        ),
      );

      final dayOutcomes = await store.listForDay(
        assignmentId: 'a-1',
        weekNumber: 1,
        dayKey: 'day_1',
      );

      expect(dayOutcomes, hasLength(1));
      expect(dayOutcomes.first.sessionSlotId, 'slot-1');
    });
  });
}

ProgrammeVersion _version({
  required String id,
  String name = 'Test Programme',
}) {
  return ProgrammeVersion(
    id: id,
    lineageId: 'lineage-1',
    versionNumber: 1,
    lifecycleStatus: ProgrammeLifecycleStatus.draft,
    libraryScope: ProgrammeLibraryScope.cohortGlobal,
    ownerType: ProgrammeOwnerType.global,
    name: name,
  );
}

ProgrammeVersionWeek _week({
  required String id,
  required String versionId,
  required int weekNumber,
  String? phaseId,
}) {
  return ProgrammeVersionWeek(
    id: id,
    versionId: versionId,
    weekNumber: weekNumber,
    phaseId: phaseId,
    title: 'Week $weekNumber',
  );
}

ProgrammeVersionDay _day({
  required String id,
  required String weekId,
  required String dayKey,
  required int dayOrder,
  ProgrammeDayType dayType = ProgrammeDayType.training,
}) {
  return ProgrammeVersionDay(
    id: id,
    weekId: weekId,
    dayKey: dayKey,
    dayOrder: dayOrder,
    dayType: dayType,
  );
}

ProgrammeVersionSessionSlot _slot({
  required String id,
  required String dayId,
  required int sessionOrder,
  required String protocolId,
}) {
  return ProgrammeVersionSessionSlot(
    id: id,
    dayId: dayId,
    sessionOrder: sessionOrder,
    protocolId: protocolId,
  );
}

ProgrammeAssignment _assignment({
  required String id,
  required String athleteId,
  ProgrammeAssignmentStatus status = ProgrammeAssignmentStatus.active,
}) {
  return ProgrammeAssignment(
    id: id,
    athleteId: athleteId,
    programmeVersionId: 'version-1',
    lineageCode: 'COHORT-FOUNDATION-TEST',
    status: status,
    startedAt: DateTime.utc(2026, 7, 15),
  );
}

ProgrammeSlotOutcome _outcome({
  required String id,
  required String assignmentId,
  required String sessionSlotId,
  required ProgrammeSlotOutcomeStatus status,
  int weekNumber = 1,
  String dayKey = 'day_1',
  int? trainingSessionId,
}) {
  return ProgrammeSlotOutcome(
    id: id,
    assignmentId: assignmentId,
    sessionSlotId: sessionSlotId,
    weekNumber: weekNumber,
    dayKey: dayKey,
    sessionOrder: 1,
    outcomeStatus: status,
    trainingSessionId: trainingSessionId,
  );
}
