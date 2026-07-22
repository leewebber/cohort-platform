import 'package:cohort_platform/features/auth/models/user_profile.dart';
import 'package:cohort_platform/features/auth/services/current_user_session.dart';
import 'package:cohort_platform/features/coach_athlete/models/coach_athlete_operation_result.dart';
import 'package:cohort_platform/features/coach_athlete/services/coach_athlete_service.dart';
import 'package:cohort_platform/features/personal_training/models/personal_training_operation_result.dart';
import 'package:cohort_platform/features/personal_training/services/personal_training_setup_service.dart';
import 'package:cohort_platform/features/programme/models/programme_catalog_entry.dart';
import 'package:cohort_platform/features/programme/models/programme_template.dart';
import 'package:cohort_platform/features/programme/services/athlete_state_sync_service_impl.dart';
import 'package:cohort_platform/features/programme/services/programme_assignment_service_impl.dart';
import 'package:cohort_platform/features/programme/services/programme_catalog_service.dart';
import 'package:cohort_platform/features/programme/services/programme_schedule_resolver_impl.dart';
import 'package:cohort_platform/features/programme/services/today_session_service_impl.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:cohort_platform/models/programme_lineage.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_coach_athlete_stores.dart';
import '../support/in_memory_profile_repository.dart';
import '../support/in_memory_programme_stores.dart';
import '../support/programme_schedule_test_fixtures.dart';

class _FakeCatalogService implements ProgrammeCatalogService {
  const _FakeCatalogService();

  @override
  Future<ProgrammeCatalogEntry?> getEntry({
    required String lineageCode,
    required int versionNumber,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<ProgrammeCatalogEntry>> listCatalogue({
    required ProgrammeCatalogueQuery query,
    ProgrammeLifecycleStatus? lifecycleStatus,
  }) async {
    return const [
      ProgrammeCatalogEntry(
        versionId: 'version-1',
        lineageCode: 'COHORT-FOUNDATION-TEST',
        versionNumber: 1,
        name: 'Foundation Programme',
        lifecycleStatus: ProgrammeLifecycleStatus.published,
        libraryScope: ProgrammeLibraryScope.cohortGlobal,
        ownerType: ProgrammeOwnerType.global,
      ),
    ];
  }
}

void main() {
  const dualRoleUserId = 'lee-dual';
  const athleteOnlyId = 'athlete-only';
  const coachOnlyId = 'coach-only';
  const linkedAthleteId = 'linked-athlete';

  late InMemoryProgrammeTables programmeTables;
  late InMemoryProgrammeVersionStore versionStore;
  late InMemoryProgrammeAssignmentStore assignmentStore;
  late InMemoryProgrammeSlotOutcomeStore outcomeStore;
  late InMemoryAthleteStateStore athleteStateStore;
  late InMemoryCoachAthleteTables coachTables;
  late InMemoryCoachAthleteRelationshipRepository relationshipRepository;
  late InMemoryProfileRepository profileRepository;
  late ProgrammeAssignmentServiceImpl assignmentService;

  PersonalTrainingSetupService buildPersonalService() {
    return PersonalTrainingSetupService(
      assignmentStore: assignmentStore,
      catalogService: const _FakeCatalogService(),
      assignmentService: assignmentService,
    );
  }

  CoachAthleteService buildCoachAthleteService() {
    return CoachAthleteService(
      relationshipRepository: relationshipRepository,
      inviteRepository: InMemoryCoachAthleteInviteRepository(coachTables),
      profileRepository: profileRepository,
      assignmentStore: assignmentStore,
      versionStore: versionStore,
      catalogService: const _FakeCatalogService(),
      assignmentService: assignmentService,
    );
  }

  Future<void> seedPublishedProgramme() async {
    programmeTables.lineages.add(
      const ProgrammeLineage(
        id: 'lineage-1',
        code: 'COHORT-FOUNDATION-TEST',
      ),
    );
    await versionStore.saveTemplateTree(
      version: ProgrammeScheduleTestFixtures.version().copyWith(
        id: 'version-1',
        lifecycleStatus: ProgrammeLifecycleStatus.published,
      ),
      tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(
        versionId: 'version-1',
      ),
    );
  }

  setUp(() {
    CurrentUserSession.clear();
    programmeTables = InMemoryProgrammeTables();
    versionStore = InMemoryProgrammeVersionStore(programmeTables);
    assignmentStore = InMemoryProgrammeAssignmentStore(programmeTables);
    outcomeStore = InMemoryProgrammeSlotOutcomeStore(programmeTables);
    athleteStateStore = InMemoryAthleteStateStore(programmeTables);
    coachTables = InMemoryCoachAthleteTables();
    relationshipRepository = InMemoryCoachAthleteRelationshipRepository(coachTables);
    profileRepository = InMemoryProfileRepository();

    profileRepository.profiles[dualRoleUserId] = const UserProfile(
      id: dualRoleUserId,
      displayName: 'Lee',
      isCoach: true,
      isAthlete: true,
    );
    profileRepository.profiles[athleteOnlyId] = const UserProfile(
      id: athleteOnlyId,
      displayName: 'Alex',
      isCoach: false,
      isAthlete: true,
    );
    profileRepository.profiles[coachOnlyId] = const UserProfile(
      id: coachOnlyId,
      displayName: 'Coach Pat',
      isCoach: true,
      isAthlete: false,
    );

    assignmentService = ProgrammeAssignmentServiceImpl(
      assignmentStore: assignmentStore,
      versionStore: versionStore,
      scheduleResolver: const ProgrammeScheduleResolverImpl(),
      todaySessionService: TodaySessionServiceImpl(
        assignmentStore: assignmentStore,
        versionStore: versionStore,
        slotOutcomeStore: outcomeStore,
        scheduleResolver: const ProgrammeScheduleResolverImpl(),
      ),
      athleteStateSyncService: AthleteStateSyncServiceImpl(
        athleteStateStore: athleteStateStore,
      ),
    );
  });

  tearDown(() {
    CurrentUserSession.clear();
  });

  group('PersonalTrainingSetupService', () {
    test('dual-role user can self-assign using auth uid', () async {
      await seedPublishedProgramme();
      CurrentUserSession.bind(profileRepository.profiles[dualRoleUserId]!);

      final service = buildPersonalService();
      expect(service.canSetupPersonalTraining, isTrue);

      final result = await service.assignProgrammeToSelf(
        programmeVersionId: 'version-1',
        startedAt: DateTime.utc(2026, 7, 22),
        timezone: 'UTC',
      );

      expect(result.isSuccess, isTrue);
      expect(result.value!.assignment.athleteId, dualRoleUserId);
      expect(
        coachTables.relationships.where(
          (relationship) =>
              relationship.coachId == dualRoleUserId &&
              relationship.athleteId == dualRoleUserId,
        ),
        isEmpty,
      );
    });

    test('athlete-only user cannot self-assign', () async {
      await seedPublishedProgramme();
      CurrentUserSession.bind(profileRepository.profiles[athleteOnlyId]!);

      final service = buildPersonalService();
      expect(service.canSetupPersonalTraining, isFalse);

      final result = await service.assignProgrammeToSelf(
        programmeVersionId: 'version-1',
        startedAt: DateTime.utc(2026, 7, 22),
        timezone: 'UTC',
      );

      expect(result.status, PersonalTrainingOperationStatus.dualRoleRequired);
    });

    test('coach-only user without athlete role cannot self-assign', () async {
      await seedPublishedProgramme();
      CurrentUserSession.bind(profileRepository.profiles[coachOnlyId]!);

      final service = buildPersonalService();
      expect(service.canSetupPersonalTraining, isFalse);

      final result = await service.assignProgrammeToSelf(
        programmeVersionId: 'version-1',
        startedAt: DateTime.utc(2026, 7, 22),
        timezone: 'UTC',
      );

      expect(result.status, PersonalTrainingOperationStatus.dualRoleRequired);
    });

    test('inaccessible programme version is rejected', () async {
      await seedPublishedProgramme();
      CurrentUserSession.bind(profileRepository.profiles[dualRoleUserId]!);

      final result = await buildPersonalService().assignProgrammeToSelf(
        programmeVersionId: 'unknown-version',
        startedAt: DateTime.utc(2026, 7, 22),
        timezone: 'UTC',
      );

      expect(result.status, PersonalTrainingOperationStatus.inaccessibleProgramme);
    });

    test('active replacement follows existing assignment rules', () async {
      await seedPublishedProgramme();
      CurrentUserSession.bind(profileRepository.profiles[dualRoleUserId]!);

      final service = buildPersonalService();
      final first = await service.assignProgrammeToSelf(
        programmeVersionId: 'version-1',
        startedAt: DateTime.utc(2026, 7, 1),
        timezone: 'UTC',
      );
      expect(first.isSuccess, isTrue);

      final conflict = await service.assignProgrammeToSelf(
        programmeVersionId: 'version-1',
        startedAt: DateTime.utc(2026, 7, 22),
        timezone: 'UTC',
      );
      expect(conflict.isSuccess, isFalse);

      final replaced = await service.assignProgrammeToSelf(
        programmeVersionId: 'version-1',
        startedAt: DateTime.utc(2026, 7, 22),
        timezone: 'UTC',
        replaceExistingActive: true,
      );
      expect(replaced.isSuccess, isTrue);

      final active = await assignmentStore.getActiveAssignment(dualRoleUserId);
      expect(active, isNotNull);
      expect(active!.id, isNot(first.value!.assignment.id));
    });
  });

  group('CoachAthleteService assignment authorization', () {
    test('coach can still assign linked athlete', () async {
      await seedPublishedProgramme();
      relationshipRepository.createActiveRelationship(
        coachId: dualRoleUserId,
        athleteId: linkedAthleteId,
      );

      CurrentUserSession.bind(profileRepository.profiles[dualRoleUserId]!);
      final service = buildCoachAthleteService();

      final result = await service.assignProgrammeToAthlete(
        athleteId: linkedAthleteId,
        programmeVersionId: 'version-1',
        startedAt: DateTime.utc(2026, 7, 22),
        timezone: 'UTC',
      );

      expect(result.isSuccess, isTrue);
      expect(result.value!.assignment.athleteId, linkedAthleteId);
    });

    test('unrelated coach cannot assign athlete', () async {
      await seedPublishedProgramme();
      relationshipRepository.createActiveRelationship(
        coachId: 'other-coach',
        athleteId: linkedAthleteId,
      );

      CurrentUserSession.bind(profileRepository.profiles[dualRoleUserId]!);
      final service = buildCoachAthleteService();

      final result = await service.assignProgrammeToAthlete(
        athleteId: linkedAthleteId,
        programmeVersionId: 'version-1',
        startedAt: DateTime.utc(2026, 7, 22),
        timezone: 'UTC',
      );

      expect(result.status, CoachAthleteOperationStatus.notLinked);
    });
  });
}
