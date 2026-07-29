import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/features/programme_builder/authoring/programme_code_authoring.dart';
import 'package:cohort_platform/models/block_performance_capture_mode.dart';
import 'package:cohort_platform/features/programme_builder/authoring/programme_code_authoring_persistence.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/session_adaptation_metadata_codec.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/training_content_vocabulary.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_protocol_builder_service.dart';
import '../support/in_memory_protocol_row_store.dart';
import '../support/in_memory_session_block_repository.dart';
import '../support/programme_session_authoring_test_support.dart'
    hide FakeProtocolBuilderService;
import '../support/programme_code_authoring_fixtures.dart';

void main() {
  group('ProgrammeCodeSessionAuthoringValidation', () {
    test('rejects invalid minimum viable duration', () {
      expect(
        () => programmeSession(
          protocolId: 'p1',
          name: 'Session',
          programmeVersionId: testProgrammeVersionId,
          minimumViableDurationMin: 0,
        ),
        throwsA(isA<ProgrammeCodeAuthoringException>()),
      );
    });

    test('rejects primary duplicated in secondary intents', () {
      expect(
        () => programmeSession(
          protocolId: 'p1',
          name: 'Session',
          programmeVersionId: testProgrammeVersionId,
          primarySessionIntent: SessionIntent.tempo,
          secondarySessionIntents: const [
            SessionIntent.tempo,
            SessionIntent.aerobicBase,
          ],
        ),
        throwsA(isA<ProgrammeCodeAuthoringException>()),
      );
    });

    test('rejects duplicate secondary intents', () {
      expect(
        () => programmeSession(
          protocolId: 'p1',
          name: 'Session',
          programmeVersionId: testProgrammeVersionId,
          secondarySessionIntents: const [
            SessionIntent.mobility,
            SessionIntent.mobility,
          ],
        ),
        throwsA(isA<ProgrammeCodeAuthoringException>()),
      );
    });
  });

  group('Programme code authoring models', () {
    test('metadata authored through code reaches canonical domain objects', () {
      final draft = fullyTaggedUpperBodyStrengthSession(
        protocolId: 'code-ubs-1',
        programmeVersionId: testProgrammeVersionId,
      );

      expect(draft.primarySessionIntent, SessionIntent.upperBodyStrength);
      expect(draft.secondarySessionIntents, [
        SessionIntent.upperBodyHypertrophy,
      ]);
      expect(draft.minimumViableDurationMin, 35);
      expect(draft.blocks.first.blockPriority, isNull);
      expect(draft.blocks[1].blockPriority, BlockPriority.essential);
      expect(draft.blocks[1].effectiveBlockPriority, BlockPriority.essential);
      expect(draft.blocks[1].adaptationPolicy?.canRemove, isFalse);
    });

    test(
      'metadata persists and reloads through row maps and block repository',
      () async {
        final draft = fullyTaggedUpperBodyStrengthSession(
          protocolId: 'code-ubs-2',
          programmeVersionId: testProgrammeVersionId,
        );

        final protocolStore = InMemoryProtocolRowStore()
          ..upsertFromDraft(draft);
        final blockRepo = InMemorySessionBlockRepository();
        await blockRepo.replaceSessionBlocks(
          sessionId: draft.protocolId,
          blocks: draft.blocks,
        );

        final reloadedProtocol = protocolStore.loadDraft(
          protocolId: draft.protocolId,
          blocks: await blockRepo.getSessionBlocks(draft.protocolId),
        );

        expect(
          reloadedProtocol.primarySessionIntent,
          SessionIntent.upperBodyStrength,
        );
        expect(reloadedProtocol.minimumViableDurationMin, 35);
        expect(
          reloadedProtocol.blocks[1].blockPriority,
          BlockPriority.essential,
        );
        expect(
          reloadedProtocol.toProtocolMap()[SessionAdaptationMetadataKeys
              .primarySessionIntent],
          'upper_body_strength',
        );
      },
    );

    test(
      'code-created programme session loads via builder protocol service',
      () async {
        final builder = FakeProtocolBuilderService();
        final persistence = ProgrammeCodeAuthoringPersistence(builder);
        final draft = fullyTaggedUpperBodyStrengthSession(
          protocolId: 'code-ubs-3',
          programmeVersionId: testProgrammeVersionId,
        );

        await persistence.saveProgrammeSession(draft);
        final loaded = await persistence.loadSession(draft.protocolId);

        expect(loaded.primarySessionIntent, SessionIntent.upperBodyStrength);
        expect(loaded.blocks.length, draft.blocks.length);
        expect(loaded.contentKind, TrainingContentKind.session);
        expect(loaded.authoringScope, TrainingAuthoringScope.programmeOnly);
      },
    );

    test('code-created reusable session remains reusable', () async {
      final builder = FakeProtocolBuilderService();
      final persistence = ProgrammeCodeAuthoringPersistence(builder);

      final draft = reusableSession(
        protocolId: 'library-ubs-1',
        name: 'Upper Body — Library',
        ownerId: 'dev-coach',
        sessionFormat: 'structured_strength',
        primarySessionIntent: SessionIntent.upperBodyStrength,
        minimumViableDurationMin: 30,
        blocks: [
          block(
            type: SessionBlockType.strength,
            blockPriority: BlockPriority.primary,
          ),
        ],
      );

      await persistence.saveReusableSession(draft);
      final loaded = await persistence.loadSession(draft.protocolId);

      expect(loaded.authoringScope, TrainingAuthoringScope.coachPrivate);
      expect(loaded.contentKind, TrainingContentKind.session);
      expect(loaded.published, isTrue);
      expect(loaded.programmeVersionId, isNull);
    });

    test('existing untagged code authoring still works', () {
      final legacy = programmeSession(
        protocolId: 'legacy-code-session',
        name: 'Morning Strength',
        programmeVersionId: testProgrammeVersionId,
        sessionFormat: 'structured_strength',
        blocks: [
          block(
            type: SessionBlockType.strength,
            content: 'Main lift',
            workoutFormat: WorkoutFormat.none,
          ),
        ],
      );

      expect(legacy.primarySessionIntent, isNull);
      expect(legacy.secondarySessionIntents, isEmpty);
      expect(legacy.minimumViableDurationMin, isNull);
      expect(legacy.blocks.first.blockPriority, isNull);
      expect(legacy.blocks.first.effectiveBlockPriority, isNotNull);
    });
  });
}
