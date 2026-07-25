import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/features/programme_builder/models/cohort_protocol_customisation_result.dart';
import 'package:cohort_platform/features/programme_builder/services/cohort_protocol_customisation_coordinator.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_session_authoring_coordinator.dart';
import 'package:cohort_platform/features/session_builder/controllers/session_builder_editing_state.dart';
import 'package:cohort_platform/features/session_builder/models/cohort_protocol_copy_destination.dart';
import 'package:cohort_platform/features/session_builder/models/programme_session_authoring_context.dart';
import 'package:cohort_platform/features/session_builder/models/session_builder_display_context.dart';
import 'package:cohort_platform/features/session_builder/models/session_builder_host_mode.dart';
import 'package:cohort_platform/features/session_builder/services/session_clone_service.dart';
import 'package:cohort_platform/features/session_builder/widgets/session_builder_view.dart';
import 'package:cohort_platform/features/training_library/services/session_library_authoring_coordinator.dart';
import 'package:cohort_platform/models/exercise.dart';
import 'package:cohort_platform/models/protocol.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/session_adaptation_metadata_codec.dart';
import 'package:cohort_platform/models/training_content_vocabulary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_protocol_builder_service.dart';
import '../support/in_memory_protocol_row_store.dart';
import '../support/programme_session_authoring_test_support.dart'
    hide FakeProtocolBuilderService;
import '../support/session_library_test_support.dart';

void main() {
  group('Protocol canonical adaptation metadata (shared Session Definition model)', () {
    late InMemoryProtocolRowStore store;

    setUp(() {
      store = InMemoryProtocolRowStore();
    });

    test('persists and reloads through performance_protocols row maps', () {
      const protocolId = 'proto-adapt-1';
      final authored = ProtocolDraft(
        protocolId: protocolId,
        name: 'Cohort Threshold',
        sessionFormat: 'intervals',
        steps: const [],
        published: true,
        contentKind: TrainingContentKind.cohortProtocol,
        primaryCapability: 'Threshold',
        primarySessionIntent: SessionIntent.threshold,
        secondarySessionIntents: const [SessionIntent.aerobicBase],
        minimumViableDurationMin: 28,
        durationMin: 45,
      );

      store.upsertFromDraft(authored, published: true);
      final upsert = store.buildUpsertMap(authored, published: true);

      expect(upsert[SessionAdaptationMetadataKeys.primarySessionIntent], 'threshold');
      expect(
        upsert[SessionAdaptationMetadataKeys.secondarySessionIntents],
        ['aerobic_base'],
      );
      expect(upsert[SessionAdaptationMetadataKeys.minimumViableDurationMin], 28);
      expect(upsert['primary_capability'], 'Threshold');

      final reloaded = store.loadDraft(protocolId: protocolId);
      expect(reloaded.primarySessionIntent, SessionIntent.threshold);
      expect(reloaded.secondarySessionIntents, [SessionIntent.aerobicBase]);
      expect(reloaded.minimumViableDurationMin, 28);
      expect(reloaded.primaryCapability, 'Threshold');
    });

    test('legacy protocol with only primary_capability does not infer session intent', () {
      store.rowsByProtocolId['legacy-cap'] = {
        'protocol_id': 'legacy-cap',
        'name': 'Legacy strength',
        'primary_capability': 'Upper body strength',
        'duration_min': 50,
      };

      final draft = store.loadDraft(protocolId: 'legacy-cap');
      final protocol = store.loadProtocol('legacy-cap');

      expect(draft.primaryCapability, 'Upper body strength');
      expect(draft.primarySessionIntent, isNull);
      expect(draft.secondarySessionIntents, isEmpty);
      expect(protocol.goal, 'Upper body strength');
      expect(protocol.primarySessionIntent, isNull);
    });

    test('clearing adaptation fields writes nulls on upsert', () {
      const protocolId = 'proto-clear';
      store.upsertFromDraft(
        ProtocolDraft(
          protocolId: protocolId,
          name: 'Tagged',
          sessionFormat: 'intervals',
          steps: const [],
          primarySessionIntent: SessionIntent.tempo,
          secondarySessionIntents: const [SessionIntent.aerobicBase],
          minimumViableDurationMin: 20,
        ),
      );

      store.upsertFromDraft(
        ProtocolDraft(
          protocolId: protocolId,
          name: 'Tagged',
          sessionFormat: 'intervals',
          steps: const [],
        ).copyWith(
          clearPrimarySessionIntent: true,
          clearSecondarySessionIntents: true,
          clearMinimumViableDurationMin: true,
        ),
      );

      final row = store.row(protocolId)!;
      expect(row[SessionAdaptationMetadataKeys.primarySessionIntent], isNull);
      expect(row[SessionAdaptationMetadataKeys.secondarySessionIntents], isNull);
      expect(row[SessionAdaptationMetadataKeys.minimumViableDurationMin], isNull);
    });

    test('unknown intent values are skipped without crashing load', () {
      store.rowsByProtocolId['proto-unknown'] = {
        'protocol_id': 'proto-unknown',
        'name': 'Mixed row',
        SessionAdaptationMetadataKeys.primarySessionIntent: 'not_a_real_intent',
        SessionAdaptationMetadataKeys.secondarySessionIntents: [
          'threshold',
          'bogus_intent',
        ],
      };

      final draft = store.loadDraft(protocolId: 'proto-unknown');
      expect(draft.primarySessionIntent, isNull);
      expect(draft.secondarySessionIntents, [SessionIntent.threshold]);
    });
  });

  group('Protocol duplication and programme insertion', () {
    const cloneService = SessionCloneService();

    test('cloneCohortProtocolToSession preserves canonical metadata', () {
      final source = cohortProtocolWithAdaptationMetadata(
        protocolId: testCohortProtocolId,
      ).copyWith(primaryCapability: 'Threshold running');

      final copied = cloneService.cloneCohortProtocolToSession(
        source: source,
        newContentId: 'local-copy-programme',
        ownerId: 'dev-coach',
        destination: CohortProtocolCopyDestination.programmeOnly,
        programmeVersionId: testProgrammeVersionId,
      );

      expect(copied.primarySessionIntent, SessionIntent.threshold);
      expect(copied.secondarySessionIntents, [SessionIntent.aerobicBase]);
      expect(copied.minimumViableDurationMin, 30);
      expect(copied.primaryCapability, 'Threshold running');
      expect(copied.sourceContentId, testCohortProtocolId);
    });

    test('assign unchanged keeps metadata on referenced cohort protocol row', () {
      const protocolId = testCohortProtocolId;
      final store = InMemoryProtocolRowStore()
        ..upsertFromDraft(
          cohortProtocolWithAdaptationMetadata(protocolId: protocolId),
          published: true,
        );

      const slotProtocolId = protocolId;
      final resolved = loadProgrammeProtocolsSafely(store, [slotProtocolId]);
      expect(resolved, hasLength(1));
      expect(resolved.first.primarySessionIntent, SessionIntent.threshold);
    });

    test('prepareCopy then builder edit preserves edited canonical metadata', () async {
      final protocolService = FakeProtocolBuilderService();
      final source = buildEligibleCohortProtocolDraft().copyWith(
        primarySessionIntent: SessionIntent.vo2Max,
        secondarySessionIntents: const [SessionIntent.runningEconomy],
        minimumViableDurationMin: 22,
      );
      protocolService.seed(source);

      final coordinator = CohortProtocolCustomisationCoordinator(
        protocolBuilderService: protocolService,
        programmeSessionCoordinator: ProgrammeSessionAuthoringCoordinator(
          protocolBuilderService: protocolService,
          assignmentPort: FakeProgrammeSessionAssignmentPort(
            document: buildProgrammeDocumentWithSlot(),
          ),
          idGenerator: FixedSessionIdGenerator(testDurableSessionId),
          coachIdentity: const FixedCoachIdentity('dev-coach'),
        ),
        librarySessionCoordinator: SessionLibraryAuthoringCoordinator(
          protocolBuilderService: protocolService,
          idGenerator: FixedSessionIdGenerator(testDurableSessionId),
          coachIdentity: const FixedCoachIdentity('dev-coach'),
        ),
        sessionCloneService: cloneService,
        coachIdentity: const FixedCoachIdentity('dev-coach'),
        assignmentPort: FakeProgrammeSessionAssignmentPort(
          document: buildProgrammeDocumentWithSlot(),
        ),
      );

      final prepared = await coordinator.prepareCopy(
        sourceProtocolId: testCohortProtocolId,
        destination: CohortProtocolCopyDestination.programmeOnly,
        programmeContext: ProgrammeSessionAuthoringContext(
          programmeVersionId: testProgrammeVersionId,
          weekLocalId: testWeekLocalId,
          dayLocalId: testDayLocalId,
          slotLocalId: testSlotLocalId,
          weekNumber: 2,
          dayLabel: 'Tuesday',
          slotDisplayLabel: 'Morning',
          authoringIntent: ProgrammeSessionAuthoringIntent.copyCohortProtocol,
          sourceProtocolId: testCohortProtocolId,
        ),
      );

      expect(prepared.status, CohortProtocolCustomisationStatus.prepared);
      final editing = SessionBuilderEditingState(draft: prepared.copiedDraft!);
      editing.setPrimarySessionIntent(SessionIntent.threshold);
      editing.setSecondarySessionIntents(const [SessionIntent.aerobicBase]);
      editing.setMinimumViableDurationMin(25);

      final built = editing.buildDraft();
      expect(built.primarySessionIntent, SessionIntent.threshold);
      expect(built.secondarySessionIntents, [SessionIntent.aerobicBase]);
      expect(built.minimumViableDurationMin, 25);
      expect(built.primaryCapability, source.primaryCapability);
    });
  });

  group('Protocol Builder UI', () {
    testWidgets('cohort protocol admin shows shared adaptation controls', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SessionBuilderView(
                draft: ProtocolDraft(
                  protocolId: 'RN-100',
                  name: 'Threshold',
                  sessionFormat: 'intervals',
                  steps: const [],
                  primaryCapability: 'Threshold',
                  primarySessionIntent: SessionIntent.threshold,
                ),
                exercises: const [
                  Exercise(exerciseId: 'EX-1', name: 'Squat', published: true),
                ],
                displayContext: SessionBuilderDisplayContext.cohortProtocolAdmin(),
                capabilities: SessionBuilderCapabilities.cohortProtocolAdmin(
                  protocolIdLocked: true,
                ),
                onDraftChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Adaptation metadata'), findsOneWidget);
      expect(find.text('Primary session intent'), findsOneWidget);
    });
  });
}
