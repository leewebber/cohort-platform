import 'package:cohort_platform/data/repositories/protocol_repository.dart';
import 'package:cohort_platform/features/training_library/models/session_library_authoring_result.dart';
import 'package:cohort_platform/features/training_library/services/session_library_authoring_coordinator.dart';
import 'package:cohort_platform/features/training_library/services/training_library_service.dart';
import 'package:cohort_platform/models/protocol.dart';
import 'package:cohort_platform/models/training_content_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/programme_session_authoring_test_support.dart';
import '../support/session_library_test_support.dart';

void main() {
  group('TrainingLibraryService', () {
    test('loadReusableSessionSummaries returns reusable sessions only', () async {
      final repository = FakeTrainingLibraryRepository(
        reusableSessions: const [
          Protocol(protocolId: testDurableSessionId, name: 'Morning Strength'),
        ],
      );
      final service = TrainingLibraryService(protocolRepository: repository);

      final summaries = await service.loadReusableSessionSummaries(
        ownerId: 'dev-coach',
      );

      expect(summaries, hasLength(1));
      expect(summaries.first.title, 'Morning Strength');
      expect(summaries.first.isReusableSession, isTrue);
    });

    test('search filters by title case-insensitively', () async {
      final repository = FakeTrainingLibraryRepository(
        reusableSessions: const [
          Protocol(protocolId: 'a', name: 'Upper Body'),
          Protocol(protocolId: 'b', name: 'Lower Body'),
        ],
      );
      final service = TrainingLibraryService(protocolRepository: repository);

      final summaries = await service.loadReusableSessionSummaries(
        ownerId: 'dev-coach',
        searchTerm: 'upper',
      );

      expect(summaries, hasLength(1));
      expect(summaries.first.title, 'Upper Body');
    });
  });

  group('SessionLibraryAuthoringCoordinator', () {
    test('createSession assigns durable ID and coach_private metadata', () async {
      final protocolService = FakeProtocolBuilderService();
      final coordinator = SessionLibraryAuthoringCoordinator(
        protocolBuilderService: protocolService,
        idGenerator: FixedSessionIdGenerator(testDurableSessionId),
        coachIdentity: const FixedCoachIdentity('dev-coach'),
      );

      final result = await coordinator.createSession(
        draft: buildValidLibrarySessionDraft(),
      );

      expect(result.isSuccess, isTrue);
      expect(result.contentId, testDurableSessionId);
      expect(protocolService.librarySaveCallCount, 1);

      final saved = protocolService.libraryDrafts[testDurableSessionId];
      expect(saved!.authoringScope, TrainingAuthoringScope.coachPrivate);
      expect(saved.programmeVersionId, isNull);
      expect(saved.published, isTrue);
      expect(saved.ownerId, 'dev-coach');
    });

    test('updateSession preserves ID and does not duplicate row', () async {
      final protocolService = FakeProtocolBuilderService();
      protocolService.libraryDrafts[testDurableSessionId] =
          buildValidLibrarySessionDraft(
        protocolId: testDurableSessionId,
        name: 'Original',
      );

      final coordinator = SessionLibraryAuthoringCoordinator(
        protocolBuilderService: protocolService,
        idGenerator: FixedSessionIdGenerator('unused'),
        coachIdentity: const FixedCoachIdentity('dev-coach'),
      );

      final result = await coordinator.updateSession(
        draft: buildValidLibrarySessionDraft(
          protocolId: testDurableSessionId,
          name: 'Updated Title',
        ),
      );

      expect(result.status.name, 'updated');
      expect(protocolService.libraryDrafts.length, 1);
      expect(protocolService.libraryDrafts[testDurableSessionId]!.name,
          'Updated Title');
    });

    test('rejects programme-only draft on update', () async {
      final coordinator = SessionLibraryAuthoringCoordinator(
        protocolBuilderService: FakeProtocolBuilderService(),
        idGenerator: FixedSessionIdGenerator(testDurableSessionId),
        coachIdentity: const FixedCoachIdentity('dev-coach'),
      );

      final draft = buildValidLibrarySessionDraft().copyWith(
        authoringScope: TrainingAuthoringScope.programmeOnly,
        programmeVersionId: testProgrammeVersionId,
      );

      final result = await coordinator.updateSession(draft: draft);

      expect(result.status, SessionLibraryAuthoringStatus.wrongContentKind);
    });
  });
}

class FakeTrainingLibraryRepository extends ProtocolRepository {
  FakeTrainingLibraryRepository({
    this.reusableSessions = const [],
  });

  final List<Protocol> reusableSessions;

  @override
  Future<List<Protocol>> listReusableCoachSessions(
    String ownerId, {
    int limit = 100,
  }) async {
    return reusableSessions;
  }
}
