import 'package:cohort_platform/features/coach_studio/governance/governance_copy.dart';
import 'package:cohort_platform/features/coach_studio/governance/widgets/exercise_usage_panel.dart';
import 'package:cohort_platform/features/coach_studio/governance/widgets/governance_status_badge.dart';
import 'package:cohort_platform/features/coach_studio/governance/widgets/session_governance_section.dart';
import 'package:cohort_platform/features/coach_studio/governance/widgets/session_revision_action_panel.dart';
import 'package:cohort_platform/features/coach_studio/governance/widgets/session_revision_identity_header.dart';
import 'package:cohort_platform/features/coach_studio/governance/widgets/session_revision_usage_panel.dart';
import 'package:cohort_platform/features/exercise_relationship/models/exercise_usage_models.dart';
import 'package:cohort_platform/features/exercise_relationship/services/exercise_relationship_service.dart';
import 'package:cohort_platform/features/performance/models/training_session_record_status.dart';
import 'package:cohort_platform/features/session_revision/models/content_usage_vocabulary.dart';
import 'package:cohort_platform/features/session_revision/models/session_revision_action_decision.dart';
import 'package:cohort_platform/features/session_revision/models/session_revision_action_vocabulary.dart';
import 'package:cohort_platform/features/session_revision/models/session_revision_usage_models.dart';
import 'package:cohort_platform/features/session_revision/services/session_revision_action_policy_service.dart';
import 'package:cohort_platform/features/session_revision/services/session_revision_relationship_service.dart';
import 'package:cohort_platform/features/session_revision/services/session_revision_service.dart';
import 'package:cohort_platform/features/coach_studio/governance/controllers/session_governance_controller.dart';
import 'package:cohort_platform/models/exercise.dart';
import 'package:cohort_platform/models/protocol_step_draft.dart';
import 'package:cohort_platform/models/session_block.dart';
import 'package:cohort_platform/models/session_block_exercise_link.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:cohort_platform/models/programme_version.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/session_revision_vocabulary.dart';
import 'package:cohort_platform/models/training_content_vocabulary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_protocol_builder_service.dart';
import '../support/in_memory_exercise_relationship_store.dart';
import '../support/in_memory_programme_stores.dart';
import '../support/in_memory_session_lineage_store.dart';
import '../support/in_memory_session_revision_delete_store.dart';
import '../support/in_memory_session_revision_relationship_store.dart';
import '../support/session_revision_usage_test_fixtures.dart';

void main() {
  late InMemoryProgrammeTables programmeTables;
  late InMemorySessionLineageStore lineageStore;
  late InMemorySessionRevisionRelationshipStore relationshipStore;
  late FakeProtocolBuilderService builder;
  late SessionRevisionActionPolicyService policyService;
  late SessionRevisionRelationshipService relationshipService;
  late SessionRevisionService revisionService;
  late InMemorySessionRevisionDeleteStore deleteStore;

  const sessionLineageId = 'session-lineage-1';
  const draftProtocolId = 'coach-session-draft';
  const publishedProtocolId = 'coach-session-published';
  const archivedProtocolId = 'coach-session-archived';
  const sessionName = 'Strength Foundation';

  SessionGovernanceController buildController({
    required String protocolId,
    String? displayName,
  }) {
    return SessionGovernanceController(
      protocolId: protocolId,
      sessionDisplayName: displayName,
      lineageStore: lineageStore,
      protocolBuilderService: builder,
      actionPolicyService: policyService,
      relationshipService: relationshipService,
    );
  }

  ProtocolDraft draftFor(String protocolId) {
    return builder.draftsById[protocolId] ??
        ProtocolDraft(
          protocolId: protocolId,
          name: sessionName,
          steps: const [],
        );
  }

  Future<void> pumpGovernanceSection(
    WidgetTester tester, {
    required String protocolId,
    SessionGovernanceController? controller,
    void Function(ProtocolDraft draft)? onDraftChanged,
    void Function()? onDeleted,
  }) async {
    final resolvedController =
        controller ?? buildController(protocolId: protocolId);
    await resolvedController.load();

    ProtocolDraft? latestDraft = draftFor(protocolId);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SessionGovernanceSection(
              controller: resolvedController,
              revisionService: revisionService,
              draft: latestDraft,
              onDraftChanged: (draft) {
                latestDraft = draft;
                onDraftChanged?.call(draft);
              },
              onDeleted: onDeleted ?? () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  OutlinedButton actionButton(WidgetTester tester, String label) {
    return tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, label),
    );
  }

  setUp(() {
    programmeTables = InMemoryProgrammeTables();
    lineageStore = InMemorySessionLineageStore();
    relationshipStore = InMemorySessionRevisionRelationshipStore(
      programmeTables: programmeTables,
    );
    builder = FakeProtocolBuilderService();
    deleteStore = InMemorySessionRevisionDeleteStore();

    relationshipService = SessionRevisionRelationshipService(
      relationshipStore: relationshipStore,
      lineageStore: lineageStore,
    );

    policyService = SessionRevisionActionPolicyService(
      lineageStore: lineageStore,
      protocolBuilderService: builder,
      relationshipService: relationshipService,
    );

    revisionService = SessionRevisionService(
      lineageStore: lineageStore,
      protocolBuilderService: builder,
      actionPolicyService: policyService,
      deleteStore: deleteStore,
    );

    _seedRevision(
      lineageStore: lineageStore,
      builder: builder,
      protocolId: draftProtocolId,
      lifecycle: SessionRevisionLifecycleStatus.draft,
      revisionNumber: 3,
      name: sessionName,
    );
    _seedRevision(
      lineageStore: lineageStore,
      builder: builder,
      protocolId: publishedProtocolId,
      lifecycle: SessionRevisionLifecycleStatus.published,
      revisionNumber: 3,
      name: sessionName,
    );
    _seedRevision(
      lineageStore: lineageStore,
      builder: builder,
      protocolId: archivedProtocolId,
      lifecycle: SessionRevisionLifecycleStatus.archived,
      revisionNumber: 2,
      name: sessionName,
    );
  });

  group('session identity', () {
    testWidgets('draft revision label renders', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionRevisionIdentityHeader(
              sessionDisplayName: sessionName,
              revisionNumber: 3,
              lifecycleStatus: SessionRevisionLifecycleStatus.draft,
            ),
          ),
        ),
      );

      expect(find.text(sessionName), findsOneWidget);
      expect(find.textContaining('Revision 3'), findsOneWidget);
      expect(find.byType(GovernanceStatusBadge), findsOneWidget);
      expect(find.text('Draft'), findsOneWidget);
    });

    testWidgets('published revision label renders', (tester) async {
      await pumpGovernanceSection(tester, protocolId: publishedProtocolId);

      expect(find.text(sessionName), findsOneWidget);
      expect(find.textContaining('Revision 3'), findsOneWidget);
      expect(find.text('Published'), findsOneWidget);
    });

    testWidgets('archived revision label renders', (tester) async {
      await pumpGovernanceSection(tester, protocolId: archivedProtocolId);

      expect(find.textContaining('Revision 2'), findsOneWidget);
      expect(find.text('Archived'), findsOneWidget);
    });

    testWidgets('raw protocol ID not shown', (tester) async {
      await pumpGovernanceSection(tester, protocolId: publishedProtocolId);

      expect(find.text(publishedProtocolId), findsNothing);
      expect(find.text(sessionLineageId), findsNothing);
    });
  });

  group('session actions', () {
    testWidgets('draft edit enabled', (tester) async {
      await pumpGovernanceSection(tester, protocolId: draftProtocolId);
      expect(actionButton(tester, 'Edit').onPressed, isNotNull);
    });

    testWidgets('published edit blocked', (tester) async {
      await pumpGovernanceSection(tester, protocolId: publishedProtocolId);
      expect(actionButton(tester, 'Edit').onPressed, isNull);
      expect(find.textContaining('Published revisions cannot be edited'),
          findsOneWidget);
    });

    testWidgets('published create-revision enabled', (tester) async {
      await pumpGovernanceSection(tester, protocolId: publishedProtocolId);
      expect(actionButton(tester, 'Create new revision').onPressed, isNotNull);
    });

    testWidgets('draft create-revision blocked', (tester) async {
      await pumpGovernanceSection(tester, protocolId: draftProtocolId);
      expect(actionButton(tester, 'Create new revision').onPressed, isNull);
    });

    testWidgets('draft publish enabled', (tester) async {
      await pumpGovernanceSection(tester, protocolId: draftProtocolId);
      expect(actionButton(tester, 'Publish').onPressed, isNotNull);
    });

    testWidgets('published publish blocked', (tester) async {
      await pumpGovernanceSection(tester, protocolId: publishedProtocolId);
      expect(actionButton(tester, 'Publish').onPressed, isNull);
    });

    testWidgets('published archive enabled', (tester) async {
      await pumpGovernanceSection(tester, protocolId: publishedProtocolId);
      expect(actionButton(tester, 'Archive').onPressed, isNotNull);
    });

    testWidgets('archived archive handled consistently', (tester) async {
      await pumpGovernanceSection(tester, protocolId: archivedProtocolId);
      expect(actionButton(tester, 'Archive').onPressed, isNull);
    });

    testWidgets('unused draft delete enabled', (tester) async {
      await pumpGovernanceSection(tester, protocolId: draftProtocolId);
      expect(actionButton(tester, 'Delete').onPressed, isNotNull);
    });

    testWidgets('referenced draft delete blocked', (tester) async {
      _attachProtocolToProgramme(
        programmeTables: programmeTables,
        protocolId: draftProtocolId,
      );

      await pumpGovernanceSection(tester, protocolId: draftProtocolId);
      expect(actionButton(tester, 'Delete').onPressed, isNull);
    });

    testWidgets('historical draft delete blocked', (tester) async {
      _seedHistoricalUsage(
        relationshipStore: relationshipStore,
        protocolId: draftProtocolId,
      );

      await pumpGovernanceSection(tester, protocolId: draftProtocolId);
      expect(actionButton(tester, 'Delete').onPressed, isNull);
      expect(find.textContaining('historical'), findsWidgets);
    });

    testWidgets('policy lookup failure disables delete', (tester) async {
      final throwingRelationshipService = SessionRevisionRelationshipService(
        relationshipStore: _ThrowingRelationshipStore(programmeTables),
        lineageStore: lineageStore,
      );
      final failingPolicyService = SessionRevisionActionPolicyService(
        lineageStore: lineageStore,
        protocolBuilderService: builder,
        relationshipService: throwingRelationshipService,
      );
      final controller = SessionGovernanceController(
        protocolId: draftProtocolId,
        sessionDisplayName: sessionName,
        lineageStore: lineageStore,
        protocolBuilderService: builder,
        actionPolicyService: failingPolicyService,
        relationshipService: throwingRelationshipService,
      );

      await pumpGovernanceSection(
        tester,
        protocolId: draftProtocolId,
        controller: controller,
      );

      expect(actionButton(tester, 'Delete').onPressed, isNull);
    });

    testWidgets('blocked reason displayed', (tester) async {
      await pumpGovernanceSection(tester, protocolId: publishedProtocolId);
      expect(find.textContaining('Published revisions cannot be edited'),
          findsOneWidget);
    });

    testWidgets('recommended alternative displayed', (tester) async {
      await pumpGovernanceSection(tester, protocolId: publishedProtocolId);
      expect(find.textContaining('Create draft revision 4'), findsWidgets);
    });
  });

  group('session execution', () {
    testWidgets('create revision calls service once', (tester) async {
      await pumpGovernanceSection(tester, protocolId: publishedProtocolId);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Create new revision'));
      await tester.pumpAndSettle();

      expect(
        builder.draftsById.containsKey('$publishedProtocolId-rev-4'),
        isTrue,
      );
    });

    testWidgets('navigates to new draft', (tester) async {
      ProtocolDraft? replacedDraft;
      await pumpGovernanceSection(
        tester,
        protocolId: publishedProtocolId,
        onDraftChanged: (draft) => replacedDraft = draft,
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Create new revision'));
      await tester.pumpAndSettle();

      expect(replacedDraft?.lifecycleStatus, SessionRevisionLifecycleStatus.draft);
      expect(replacedDraft?.revisionNumber, 4);
    });

    testWidgets('publish refreshes policy state', (tester) async {
      await pumpGovernanceSection(tester, protocolId: draftProtocolId);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Publish'));
      await tester.pumpAndSettle();

      expect(find.text('Published'), findsOneWidget);
      expect(actionButton(tester, 'Edit').onPressed, isNull);
    });

    testWidgets('archive preserves usage display', (tester) async {
      _attachProtocolToProgramme(
        programmeTables: programmeTables,
        protocolId: publishedProtocolId,
        programmeName: 'HYROX Base',
      );

      await pumpGovernanceSection(tester, protocolId: publishedProtocolId);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Archive'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Archived'), findsOneWidget);
      expect(find.textContaining('HYROX Base'), findsOneWidget);
    });

    testWidgets('delete never executes when policy blocks', (tester) async {
      _attachProtocolToProgramme(
        programmeTables: programmeTables,
        protocolId: draftProtocolId,
      );

      await pumpGovernanceSection(tester, protocolId: draftProtocolId);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(deleteStore.deletedProtocolIds, isEmpty);
    });

    testWidgets('allowed delete returns to library', (tester) async {
      var deleted = false;
      final controller = buildController(protocolId: draftProtocolId);
      await controller.load();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SessionGovernanceSection(
                controller: controller,
                revisionService: revisionService,
                draft: draftFor(draftProtocolId),
                onDraftChanged: (_) {},
                onDeleted: () => deleted = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(deleted, isTrue);
      expect(deleteStore.deletedProtocolIds, [draftProtocolId]);
    });
  });

  group('session usage', () {
    testWidgets('programme version count shown', (tester) async {
      _attachProtocolToProgramme(
        programmeTables: programmeTables,
        protocolId: publishedProtocolId,
      );

      await pumpGovernanceSection(tester, protocolId: publishedProtocolId);
      expect(find.text('1 Programme Version'), findsOneWidget);
    });

    testWidgets('slot count distinct from programme count', (tester) async {
      final version = _attachProtocolToProgramme(
        programmeTables: programmeTables,
        protocolId: publishedProtocolId,
      );
      final week = SessionRevisionUsageTestFixtures.seedWeek(
        programmeTables,
        version: version,
        id: 'week-2',
        weekNumber: 2,
      );
      final day = SessionRevisionUsageTestFixtures.seedDay(
        programmeTables,
        week: week,
        id: 'day-2',
      );
      SessionRevisionUsageTestFixtures.seedSlot(
        programmeTables,
        day: day,
        protocolId: publishedProtocolId,
        id: 'slot-2',
        sessionOrder: 2,
      );

      await pumpGovernanceSection(tester, protocolId: publishedProtocolId);
      expect(find.text('1 Programme Version'), findsOneWidget);
      expect(find.text('2 programme slots'), findsOneWidget);
    });

    testWidgets('active assignment count shown', (tester) async {
      final version = _attachProtocolToProgramme(
        programmeTables: programmeTables,
        protocolId: publishedProtocolId,
      );
      _seedActiveAssignment(
        programmeTables: programmeTables,
        version: version,
      );

      await pumpGovernanceSection(tester, protocolId: publishedProtocolId);
      expect(find.text('1 Active Assignment'), findsOneWidget);
    });

    testWidgets('historical count shown', (tester) async {
      _seedHistoricalUsage(
        relationshipStore: relationshipStore,
        protocolId: publishedProtocolId,
        recordCount: 14,
      );

      await pumpGovernanceSection(tester, protocolId: publishedProtocolId);
      expect(find.text('14 Historical Performances'), findsOneWidget);
    });

    testWidgets('historical-only state explained', (tester) async {
      _seedHistoricalUsage(
        relationshipStore: relationshipStore,
        protocolId: publishedProtocolId,
      );

      await pumpGovernanceSection(tester, protocolId: publishedProtocolId);
      expect(
        find.text(GovernanceCopy.historicalOnlySessionRevisionMessage),
        findsOneWidget,
      );
    });

    testWidgets('unused state shown', (tester) async {
      await pumpGovernanceSection(tester, protocolId: draftProtocolId);
      expect(find.text(GovernanceCopy.unusedSessionRevisionMessage),
          findsOneWidget);
    });

    testWidgets('archived programme references still displayed', (tester) async {
      _attachProtocolToProgramme(
        programmeTables: programmeTables,
        protocolId: archivedProtocolId,
        programmeName: 'Founder Acceptance',
        lifecycleStatus: ProgrammeLifecycleStatus.archived,
      );

      await pumpGovernanceSection(tester, protocolId: archivedProtocolId);
      expect(find.textContaining('Founder Acceptance'), findsOneWidget);
    });

    testWidgets('no athlete IDs shown', (tester) async {
      final version = _attachProtocolToProgramme(
        programmeTables: programmeTables,
        protocolId: publishedProtocolId,
      );
      _seedActiveAssignment(
        programmeTables: programmeTables,
        version: version,
        athleteId: 'athlete-secret-42',
      );

      await pumpGovernanceSection(tester, protocolId: publishedProtocolId);
      expect(find.textContaining('athlete-secret-42'), findsNothing);
      expect(find.textContaining('assignment'), findsNothing);
    });

    testWidgets('lookup failure state shown', (tester) async {
      final lookup = SessionRevisionUsageLookupResult.lookupFailed('boom');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionRevisionUsagePanel(usageLookup: lookup),
          ),
        ),
      );

      expect(find.text('boom'), findsOneWidget);
    });
  });

  group('exercise usage', () {
    late InMemoryExerciseRelationshipTables exerciseTables;
    late ExerciseRelationshipService exerciseService;

    setUp(() {
      exerciseTables = InMemoryExerciseRelationshipTables();
      exerciseService = ExerciseRelationshipService(
        relationshipStore: InMemoryExerciseRelationshipStore(exerciseTables),
      );
      exerciseTables.exercises.add(
        const Exercise(exerciseId: 'SQ-001', name: 'Back Squat', published: true),
      );
    });

    Future<void> pumpExercisePanel(WidgetTester tester, String exerciseId) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExerciseUsagePanel(
              exerciseId: exerciseId,
              loadUsage: exerciseService.tryGetUsageForExercise,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('session revision count shown', (tester) async {
      _seedExerciseBlockLink(
        exerciseTables: exerciseTables,
        exerciseId: 'SQ-001',
        protocolId: 'session-v1',
        revisionNumber: 1,
      );
      _seedExerciseBlockLink(
        exerciseTables: exerciseTables,
        exerciseId: 'SQ-001',
        protocolId: 'session-v2',
        revisionNumber: 2,
        sessionName: 'Full Body Strength',
      );

      await pumpExercisePanel(tester, 'SQ-001');
      expect(find.text('2 Session Revisions'), findsOneWidget);
    });

    testWidgets('session lineage count shown', (tester) async {
      _seedExerciseBlockLink(
        exerciseTables: exerciseTables,
        exerciseId: 'SQ-001',
        protocolId: 'session-v1',
        sessionLineageId: 'lineage-a',
      );
      _seedExerciseBlockLink(
        exerciseTables: exerciseTables,
        exerciseId: 'SQ-001',
        protocolId: 'session-v2',
        sessionLineageId: 'lineage-b',
        sessionName: 'Other Session',
      );

      await pumpExercisePanel(tester, 'SQ-001');
      expect(find.text('2 Session Lineages'), findsOneWidget);
    });

    testWidgets('programme count shown', (tester) async {
      _seedExerciseProgrammeUsage(exerciseTables, exerciseId: 'SQ-001');

      await pumpExercisePanel(tester, 'SQ-001');
      expect(find.text('1 Programme Version'), findsOneWidget);
    });

    testWidgets('active assignment count shown', (tester) async {
      _seedExerciseProgrammeUsage(
        exerciseTables,
        exerciseId: 'SQ-001',
        withAssignment: true,
      );

      await pumpExercisePanel(tester, 'SQ-001');
      expect(find.text('1 Active Assignment'), findsOneWidget);
    });

    testWidgets('historical count shown', (tester) async {
      exerciseTables.historicalResults.add(
        InMemoryExerciseHistoricalResultFixture(
          exerciseResultId: 'result-1',
          exerciseId: 'SQ-001',
          recordId: 'record-1',
          sourceProtocolId: 'session-v1',
          performedAt: DateTime.utc(2026, 1, 1),
          status: TrainingSessionRecordStatus.completed,
        ),
      );

      await pumpExercisePanel(tester, 'SQ-001');
      expect(find.text('1 Historical Performance'), findsOneWidget);
    });

    testWidgets('block-link count shown', (tester) async {
      _seedExerciseBlockLink(
        exerciseTables: exerciseTables,
        exerciseId: 'SQ-001',
        protocolId: 'session-v1',
        blockId: 'block-1',
      );
      _seedExerciseBlockLink(
        exerciseTables: exerciseTables,
        exerciseId: 'SQ-001',
        protocolId: 'session-v1',
        blockId: 'block-2',
        blockOrder: 2,
      );

      await pumpExercisePanel(tester, 'SQ-001');
      expect(find.textContaining('2 session blocks'), findsOneWidget);
    });

    testWidgets('same-name exercises remain separate through service fixtures',
        (tester) async {
      exerciseTables.exercises.add(
        const Exercise(exerciseId: 'SQ-002', name: 'Back Squat', published: true),
      );
      _seedExerciseBlockLink(
        exerciseTables: exerciseTables,
        exerciseId: 'SQ-001',
        protocolId: 'session-a',
      );
      _seedExerciseBlockLink(
        exerciseTables: exerciseTables,
        exerciseId: 'SQ-002',
        protocolId: 'session-b',
        sessionName: 'Other Session',
      );

      await pumpExercisePanel(tester, 'SQ-001');
      expect(find.text('1 Session Revision'), findsOneWidget);
      expect(find.textContaining('Other Session'), findsNothing);
    });

    testWidgets('no athlete IDs shown', (tester) async {
      _seedExerciseProgrammeUsage(
        exerciseTables,
        exerciseId: 'SQ-001',
        withAssignment: true,
        athleteId: 'athlete-hidden-99',
      );

      await pumpExercisePanel(tester, 'SQ-001');
      expect(find.textContaining('athlete-hidden-99'), findsNothing);
    });

    testWidgets('empty state shown', (tester) async {
      await pumpExercisePanel(tester, 'SQ-001');
      expect(find.text(GovernanceCopy.exerciseUnusedMessage), findsOneWidget);
    });

    testWidgets('lookup failure shown', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExerciseUsagePanel(
              exerciseId: 'SQ-001',
              loadUsage: (_) async =>
                  const ExerciseUsageLookupResult.lookupFailed('Exercise boom'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Exercise boom'), findsOneWidget);
    });
  });
}

class _ThrowingRelationshipStore extends InMemorySessionRevisionRelationshipStore {
  _ThrowingRelationshipStore(InMemoryProgrammeTables tables)
      : super(programmeTables: tables);

  @override
  Future<List<SessionRevisionProgrammeReference>> listProgrammeSlotReferences(
    String protocolId,
  ) {
    throw Exception('lookup failed');
  }
}

void _seedRevision({
  required InMemorySessionLineageStore lineageStore,
  required FakeProtocolBuilderService builder,
  required String protocolId,
  required SessionRevisionLifecycleStatus lifecycle,
  required int revisionNumber,
  String sessionLineageId = 'session-lineage-1',
  String name = 'Coach Session',
  TrainingContentKind contentKind = TrainingContentKind.session,
  TrainingAuthoringScope authoringScope = TrainingAuthoringScope.coachPrivate,
  TrainingEndorsementStatus endorsementStatus =
      TrainingEndorsementStatus.coachAuthored,
}) {
  SessionRevisionUsageTestFixtures.seedRevisionMetadata(
    lineageStore,
    protocolId: protocolId,
    sessionLineageId: sessionLineageId,
    revisionNumber: revisionNumber,
    lifecycleStatus: lifecycle,
  );

  builder.seed(
    ProtocolDraft(
      protocolId: protocolId,
      name: name,
      steps: const [
        ProtocolStepDraft(
          localId: 'step-1',
          stepOrder: 1,
          title: 'Warm-up',
        ),
      ],
      blocks: const [
        SessionBlock(
          localId: 'block-1',
          blockType: SessionBlockType.strength,
          title: 'Strength',
          content: 'Back squat',
          workoutFormat: WorkoutFormat.none,
          position: 1,
          linkedExercises: [
            SessionBlockExerciseLink(
              localId: 'link-1',
              exerciseId: 'SQ-001',
              position: 1,
            ),
          ],
        ),
      ],
      lifecycleStatus: lifecycle,
      revisionNumber: revisionNumber,
      sessionLineageId: sessionLineageId,
      published: lifecycle == SessionRevisionLifecycleStatus.published,
      contentKind: contentKind,
      authoringScope: authoringScope,
      endorsementStatus: endorsementStatus,
      ownerId: 'coach-1',
      sessionFormat: 'structured_strength',
    ),
  );
}

void _seedHistoricalUsage({
  required InMemorySessionRevisionRelationshipStore relationshipStore,
  required String protocolId,
  int recordCount = 1,
}) {
  for (var i = 0; i < recordCount; i++) {
    relationshipStore.performanceRecords.add(
      SessionRevisionUsageTestFixtures.seedTerminalRecord(
        recordId: 'record-$i',
        athleteId: 'athlete-$i',
        sourceProtocolId: protocolId,
        performedAt: DateTime.utc(2026, 1, i + 1),
      ),
    );
  }
}

void _seedActiveAssignment({
  required InMemoryProgrammeTables programmeTables,
  required ProgrammeVersion version,
  String athleteId = 'athlete-1',
}) {
  final lineage = programmeTables.lineages.firstWhere(
    (entry) => entry.id == version.lineageId,
  );
  SessionRevisionUsageTestFixtures.seedAssignment(
    programmeTables,
    athleteId: athleteId,
    version: version,
    lineage: lineage,
  );
}

ProgrammeVersion _attachProtocolToProgramme({
  required InMemoryProgrammeTables programmeTables,
  required String protocolId,
  String programmeName = 'Test Programme',
  ProgrammeLifecycleStatus lifecycleStatus =
      ProgrammeLifecycleStatus.published,
}) {
  final lineage = SessionRevisionUsageTestFixtures.seedLineage(programmeTables);
  final version = SessionRevisionUsageTestFixtures.seedVersion(
    programmeTables,
    lineage: lineage,
    name: programmeName,
    lifecycleStatus: lifecycleStatus,
  );
  final week = SessionRevisionUsageTestFixtures.seedWeek(
    programmeTables,
    version: version,
  );
  final day = SessionRevisionUsageTestFixtures.seedDay(
    programmeTables,
    week: week,
  );
  SessionRevisionUsageTestFixtures.seedSlot(
    programmeTables,
    day: day,
    protocolId: protocolId,
  );
  return version;
}

void _seedExerciseBlockLink({
  required InMemoryExerciseRelationshipTables exerciseTables,
  required String exerciseId,
  required String protocolId,
  String blockId = 'block-1',
  int blockOrder = 1,
  int revisionNumber = 1,
  String sessionLineageId = 'session-lineage-1',
  String sessionName = 'Strength Foundation',
}) {
  exerciseTables.blockLinks.add(
    InMemoryExerciseBlockLinkFixture(
      exerciseLinkId: 'link-$blockId',
      exerciseId: exerciseId,
      blockId: blockId,
      blockTitle: 'Main',
      blockOrder: blockOrder,
      protocolId: protocolId,
      sessionLineageId: sessionLineageId,
      sessionRevisionNumber: revisionNumber,
      sessionName: sessionName,
      sessionLifecycleStatus: SessionRevisionLifecycleStatus.published,
    ),
  );
}

void _seedExerciseProgrammeUsage(
  InMemoryExerciseRelationshipTables exerciseTables, {
  required String exerciseId,
  bool withAssignment = false,
  String athleteId = 'athlete-1',
}) {
  final programmeTables = exerciseTables.programmeTables;
  final version = _attachProtocolToProgramme(
    programmeTables: programmeTables,
    protocolId: 'session-v1',
    programmeName: 'HYROX Base',
  );
  _seedExerciseBlockLink(
    exerciseTables: exerciseTables,
    exerciseId: exerciseId,
    protocolId: 'session-v1',
  );
  if (withAssignment) {
    _seedActiveAssignment(
      programmeTables: programmeTables,
      version: version,
      athleteId: athleteId,
    );
  }
}
