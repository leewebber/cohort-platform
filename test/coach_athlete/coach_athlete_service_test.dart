import 'package:cohort_platform/features/auth/models/user_profile.dart';
import 'package:cohort_platform/features/auth/services/current_user_session.dart';
import 'package:cohort_platform/features/coach_athlete/models/coach_athlete_invite.dart';
import 'package:cohort_platform/features/coach_athlete/models/coach_athlete_operation_result.dart';
import 'package:cohort_platform/features/coach_athlete/services/coach_athlete_invite_code_generator.dart';
import 'package:cohort_platform/features/coach_athlete/services/coach_athlete_service.dart';
import 'package:cohort_platform/features/programme/models/programme_catalog_entry.dart';
import 'package:cohort_platform/features/programme/services/programme_catalog_service.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_coach_athlete_stores.dart';
import '../support/in_memory_profile_repository.dart';

class _FakeCatalogService implements ProgrammeCatalogService {
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
        lineageCode: 'PROG-TEST',
        versionNumber: 1,
        name: 'Test Programme',
        lifecycleStatus: ProgrammeLifecycleStatus.published,
        libraryScope: ProgrammeLibraryScope.cohortGlobal,
        ownerType: ProgrammeOwnerType.global,
      ),
    ];
  }
}

void main() {
  late InMemoryCoachAthleteTables tables;
  late InMemoryCoachAthleteRelationshipRepository relationshipRepository;
  late InMemoryCoachAthleteInviteRepository inviteRepository;
  late InMemoryProfileRepository profileRepository;

  const coachId = 'coach-111';
  const athleteId = 'athlete-222';

  CoachAthleteService buildService() {
    return CoachAthleteService(
      relationshipRepository: relationshipRepository,
      inviteRepository: inviteRepository,
      profileRepository: profileRepository,
      codeGenerator: const CoachAthleteInviteCodeGenerator(),
      catalogService: _FakeCatalogService(),
    );
  }

  setUp(() {
    CurrentUserSession.clear();
    tables = InMemoryCoachAthleteTables();
    relationshipRepository = InMemoryCoachAthleteRelationshipRepository(tables);
    inviteRepository = InMemoryCoachAthleteInviteRepository(tables);
    profileRepository = InMemoryProfileRepository();

    profileRepository.profiles[coachId] = const UserProfile(
      id: coachId,
      displayName: 'Lee',
      isCoach: true,
      isAthlete: true,
    );
    profileRepository.profiles[athleteId] = const UserProfile(
      id: athleteId,
      displayName: 'Alex',
      isCoach: false,
      isAthlete: true,
    );

    tables.profiles.addAll(profileRepository.profiles);
  });

  tearDown(() {
    CurrentUserSession.clear();
  });

  test('coach creates invite', () async {
    CurrentUserSession.bind(profileRepository.profiles[coachId]!);
    final service = buildService();

    final result = await service.createInvite();

    expect(result.isSuccess, isTrue);
    expect(result.value!.code.length, 8);
  });

  test('athlete accepts valid invite', () async {
    CurrentUserSession.bind(profileRepository.profiles[coachId]!);
    final coachService = buildService();
    final invite = (await coachService.createInvite()).value!;

    CurrentUserSession.bind(profileRepository.profiles[athleteId]!);
    inviteRepository.currentAthleteId = athleteId;
    final athleteService = buildService();

    final result = await athleteService.acceptInvite(invite.code);

    expect(result.isSuccess, isTrue);
    expect(result.value!.coachDisplayName, 'Lee');
  });

  test('expired invite rejected', () async {
    tables.invites.add(
      CoachAthleteInvite(
        id: 'invite-expired',
        coachId: coachId,
        code: 'ABCD2345',
        status: CoachAthleteInviteStatus.pending,
        expiresAt: DateTime.now().toUtc().subtract(const Duration(days: 1)),
        createdAt: DateTime.now().toUtc().subtract(const Duration(days: 8)),
      ),
    );

    CurrentUserSession.bind(profileRepository.profiles[athleteId]!);
    inviteRepository.currentAthleteId = athleteId;
    final service = buildService();

    final result = await service.acceptInvite('ABCD2345');

    expect(result.status, CoachAthleteOperationStatus.expiredInvite);
  });

  test('coach cannot accept own invite', () async {
    tables.invites.add(
      CoachAthleteInvite(
        id: 'invite-self',
        coachId: coachId,
        code: 'WXYZ5678',
        status: CoachAthleteInviteStatus.pending,
        expiresAt: DateTime.now().toUtc().add(const Duration(days: 1)),
        createdAt: DateTime.now().toUtc(),
      ),
    );

    CurrentUserSession.bind(profileRepository.profiles[coachId]!);
    inviteRepository.currentAthleteId = coachId;
    final service = buildService();

    final result = await service.acceptInvite('WXYZ5678');

    expect(result.status, CoachAthleteOperationStatus.selfInvite);
  });

  test('duplicate relationship prevented', () async {
    relationshipRepository.createActiveRelationship(
      coachId: coachId,
      athleteId: athleteId,
    );

    tables.invites.add(
      CoachAthleteInvite(
        id: 'invite-dup',
        coachId: 'coach-other',
        code: 'HJKL3456',
        status: CoachAthleteInviteStatus.pending,
        expiresAt: DateTime.now().toUtc().add(const Duration(days: 1)),
        createdAt: DateTime.now().toUtc(),
      ),
    );

    CurrentUserSession.bind(profileRepository.profiles[athleteId]!);
    inviteRepository.currentAthleteId = athleteId;
    final service = buildService();

    final result = await service.acceptInvite('HJKL3456');

    expect(result.status, CoachAthleteOperationStatus.alreadyLinked);
  });

  test('coach lists only their athletes', () async {
    relationshipRepository.createActiveRelationship(
      coachId: coachId,
      athleteId: athleteId,
    );
    relationshipRepository.createActiveRelationship(
      coachId: 'other-coach',
      athleteId: 'other-athlete',
    );

    CurrentUserSession.bind(profileRepository.profiles[coachId]!);
    final service = buildService();

    final result = await service.listLinkedAthletes();

    expect(result.isSuccess, isTrue);
    expect(result.value, hasLength(1));
    expect(result.value!.first.displayName, 'Alex');
  });
}
