import 'package:cohort_platform/features/programme/errors/programme_schedule_exception.dart';
import 'package:cohort_platform/features/programme/models/programme_schedule_resolution.dart';
import 'package:cohort_platform/features/programme/models/programme_template.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_authored_slot_resolver.dart';
import 'package:cohort_platform/features/programme/services/programme_schedule_resolver_impl.dart';
import 'package:cohort_platform/features/programme/services/today_session_service_impl.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:cohort_platform/models/programme_version.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_programme_stores.dart';
import '../support/programme_schedule_test_fixtures.dart';

const _baliHash =
    'f5da4085c0ea8b4c6eec93859451db624aaa52cd4af79ca702278518ea227b5b';
const _baliVersionId = 'b1a1b001-0000-4000-8000-ba11b0010001';
const _baliAssignmentId = '95ee6900-c3e2-4684-b704-dd261308458e';
const _apolloVersionId = '2ba018bd-7dc2-4dfd-8d8e-e35823158920';
const _apolloHash =
    '810334293c72aa2804ebd8bc2a426ca9f3e4977aed3da00989f67ae949dd0b83';

ProgrammeTemplateTree _namedFirstDayTree({
  required String versionId,
  required String firstDayKey,
  required String firstTitle,
}) {
  return ProgrammeScheduleTestFixtures.singleWeekTree(
    programmeVersionId: versionId,
    days: [
      ProgrammeScheduleTestFixtures.trainingDay(
        id: ProgrammeScheduleTestFixtures.day1Id,
        weekId: ProgrammeScheduleTestFixtures.week1Id,
        dayKey: firstDayKey,
        dayOrder: 1,
        title: firstTitle,
        slots: [
          ProgrammeScheduleTestFixtures.requiredSlot(
            id: ProgrammeScheduleTestFixtures.slot1Id,
            dayId: ProgrammeScheduleTestFixtures.day1Id,
            sessionOrder: 1,
            protocolId: 'BALI-W01-D01-S01-R1',
          ),
        ],
      ),
      ProgrammeScheduleTestFixtures.trainingDay(
        id: ProgrammeScheduleTestFixtures.day2Id,
        weekId: ProgrammeScheduleTestFixtures.week1Id,
        dayKey: 'day_2',
        dayOrder: 2,
        slots: [
          ProgrammeScheduleTestFixtures.requiredSlot(
            id: ProgrammeScheduleTestFixtures.slot2Id,
            dayId: ProgrammeScheduleTestFixtures.day2Id,
            sessionOrder: 1,
            protocolId: 'BALI-W01-D02-S01-R1',
          ),
          ProgrammeScheduleTestFixtures.requiredSlot(
            id: ProgrammeScheduleTestFixtures.slot3Id,
            dayId: ProgrammeScheduleTestFixtures.day2Id,
            sessionOrder: 2,
            protocolId: 'BALI-W01-D02-S02-R1',
          ),
        ],
      ),
    ],
  );
}

ProgrammeAssignment _hostedBaliShape({required String dayKey}) {
  return ProgrammeAssignment(
    id: _baliAssignmentId,
    athleteId: 'athlete-bali',
    programmeVersionId: _baliVersionId,
    lineageCode: 'BALI-HYBRID-BASE',
    status: ProgrammeAssignmentStatus.active,
    startedAt: DateTime(2026, 9, 26),
    timezone: 'Asia/Makassar',
    currentWeek: 1,
    currentDayKey: dayKey,
    currentSessionOrder: 1,
    enrolmentSource: 'dual_role_self',
    materialisedAt: DateTime(2026, 9, 26),
    materialisedPackageContentHash: _baliHash,
    materialisedPackageSchemaVersion: '1',
  );
}

void main() {
  const resolver = ProgrammeScheduleResolverImpl();

  test('initial cursor uses the first authored day key, not a literal day_1', () {
    final tree = _namedFirstDayTree(
      versionId: 'sat-first',
      firstDayKey: 'day_8',
      firstTitle: 'Saturday',
    );
    final cursor = resolver.resolveInitialCursor(tree: tree);
    expect(cursor.dayKey, 'day_8');
    expect(cursor.weekNumber, 1);
    expect(cursor.slotOrder, 1);
  });

  test('hosted Bali shape stores and resolves Strength A on day_1', () {
    final tree = _namedFirstDayTree(
      versionId: _baliVersionId,
      firstDayKey: 'day_1',
      firstTitle: 'Saturday',
    );
    final assignment = _hostedBaliShape(dayKey: 'day_1');
    final resolution = resolver.resolve(
      assignment: assignment,
      tree: tree,
      outcomes: const [],
    );
    expect(resolution.kind, ProgrammeScheduleResolutionKind.executableSlot);
    expect(resolution.plannedProtocolId, 'BALI-W01-D01-S01-R1');
    expect(assignment.currentDayKey, 'day_1');
    expect(assignment.startedAt, DateTime(2026, 9, 26));
    expect(assignment.timezone, 'Asia/Makassar');
  });

  test('Sunday AM/PM stay on the same authored day and ordered', () {
    final tree = _namedFirstDayTree(
      versionId: _baliVersionId,
      firstDayKey: 'day_1',
      firstTitle: 'Saturday',
    );
    final morning = resolver.resolve(
      assignment: _hostedBaliShape(dayKey: 'day_2').copyWith(
        currentSessionOrder: 1,
      ),
      tree: tree,
      outcomes: const [],
    );
    expect(morning.dayKey, 'day_2');
    expect(morning.slot?.sessionOrder, 1);
    expect(morning.plannedProtocolId, 'BALI-W01-D02-S01-R1');
  });

  test('weeks without days fail closed on the stored cursor', () {
    final emptyWeek = ProgrammeScheduleTestFixtures.singleWeekTree(
      programmeVersionId: _baliVersionId,
      days: const [],
    );
    expect(
      () => resolver.resolve(
        assignment: _hostedBaliShape(dayKey: 'day_1'),
        tree: emptyWeek,
        outcomes: const [],
      ),
      throwsA(
        isA<ProgrammeScheduleException>().having(
          (error) => error.code,
          'code',
          ProgrammeScheduleErrorCode.missingCurrentDay,
        ),
      ),
    );
  });

  test('invalid cursor identity fails closed', () {
    expect(
      () => resolver.resolve(
        assignment: _hostedBaliShape(dayKey: 'day_99'),
        tree: _namedFirstDayTree(
          versionId: _baliVersionId,
          firstDayKey: 'day_1',
          firstTitle: 'Saturday',
        ),
        outcomes: const [],
      ),
      throwsA(
        isA<ProgrammeScheduleException>().having(
          (error) => error.code,
          'code',
          ProgrammeScheduleErrorCode.missingCurrentDay,
        ),
      ),
    );
  });

  test('Apollo-style day_1 programmes remain resolvable', () {
    final resolution = resolver.resolve(
      assignment: ProgrammeScheduleTestFixtures.assignment(dayKey: 'day_1'),
      tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(),
      outcomes: const [],
    );
    expect(resolution.kind, ProgrammeScheduleResolutionKind.executableSlot);
    expect(resolution.dayKey, 'day_1');
    expect(resolution.plannedProtocolId, 'BW-001');
  });

  test('restart resolves the same hosted Bali cursor', () async {
    final tables = InMemoryProgrammeTables();
    final version = ProgrammeVersion(
      id: _baliVersionId,
      lineageId: 'bali-lineage',
      versionNumber: 1,
      lifecycleStatus: ProgrammeLifecycleStatus.published,
      libraryScope: ProgrammeLibraryScope.coachPrivate,
      ownerType: ProgrammeOwnerType.coach,
      name: 'Bali Hybrid Base',
      packageContentHash: _baliHash,
      publishedAt: DateTime(2026, 9, 26),
    );
    tables.versions.add(version);
    await InMemoryProgrammeVersionStore(tables).saveTemplateTree(
      version: version,
      tree: _namedFirstDayTree(
        versionId: _baliVersionId,
        firstDayKey: 'day_1',
        firstTitle: 'Saturday',
      ),
    );
    final assignment = _hostedBaliShape(dayKey: 'day_1');
    tables.assignments.add(assignment);

    final service = TodaySessionServiceImpl(
      assignmentStore: InMemoryProgrammeAssignmentStore(tables),
      versionStore: InMemoryProgrammeVersionStore(tables),
      slotOutcomeStore: InMemoryProgrammeSlotOutcomeStore(tables),
      scheduleResolver: resolver,
    );
    final first = await service.resolveForAthlete(assignment.athleteId);
    final second = await service.resolveForAthlete(assignment.athleteId);
    expect(first.kind.name, second.kind.name);
    expect(first.plannedProtocolId, 'BALI-W01-D01-S01-R1');
    expect(second.plannedProtocolId, 'BALI-W01-D01-S01-R1');
    expect(tables.assignments.single.currentDayKey, 'day_1');
    expect(tables.assignments.single.id, _baliAssignmentId);
  });

  test('unrelated Apollo assignment is not rewritten', () async {
    final tables = InMemoryProgrammeTables();
    final apollo = ProgrammeScheduleTestFixtures.materialisedAssignment(
      id: 'apollo-history',
      programmeVersionId: _apolloVersionId,
      packageContentHash: _apolloHash,
    ).copyWith(status: ProgrammeAssignmentStatus.reassigned);
    final bali = _hostedBaliShape(dayKey: 'day_1');
    tables.assignments.add(apollo);
    tables.assignments.add(bali);
    expect(tables.assignments.length, 2);
    expect(
      tables.assignments.firstWhere((row) => row.id == 'apollo-history').status,
      ProgrammeAssignmentStatus.reassigned,
    );
    expect(
      tables.assignments.firstWhere((row) => row.id == _baliAssignmentId)
          .programmeVersionId,
      _baliVersionId,
    );
  });

  test('authored slot resolver uses the stored canonical day key', () async {
    final tables = InMemoryProgrammeTables();
    final version = ProgrammeVersion(
      id: _baliVersionId,
      lineageId: 'bali-lineage',
      versionNumber: 1,
      lifecycleStatus: ProgrammeLifecycleStatus.published,
      libraryScope: ProgrammeLibraryScope.coachPrivate,
      ownerType: ProgrammeOwnerType.coach,
      name: 'Bali Hybrid Base',
      packageContentHash: _baliHash,
      publishedAt: DateTime(2026, 9, 26),
    );
    tables.versions.add(version);
    await InMemoryProgrammeVersionStore(tables).saveTemplateTree(
      version: version,
      tree: _namedFirstDayTree(
        versionId: _baliVersionId,
        firstDayKey: 'day_1',
        firstTitle: 'Saturday',
      ),
    );
    final resolved = await AthleteProgrammeAuthoredSlotResolver(
      versionStore: InMemoryProgrammeVersionStore(tables),
    ).resolve(_hostedBaliShape(dayKey: 'day_1'));
    expect(resolved.programmedSessionKey.dayKey, 'day_1');
    expect(resolved.slot.protocolId, 'BALI-W01-D01-S01-R1');
  });
}
