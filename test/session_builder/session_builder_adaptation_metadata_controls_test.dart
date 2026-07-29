import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/features/programme_builder/authoring/programme_code_authoring.dart';
import 'package:cohort_platform/features/session_builder/controllers/session_builder_editing_state.dart';
import 'package:cohort_platform/features/session_builder/models/session_builder_display_context.dart';
import 'package:cohort_platform/features/session_builder/widgets/session_builder_view.dart';
import 'package:cohort_platform/models/exercise.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:cohort_platform/models/session_adaptation_metadata_codec.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/programme_code_authoring_fixtures.dart';
import '../support/programme_session_authoring_test_support.dart';

Future<void> scrollSessionBuilderTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    500,
    scrollable: find.byType(Scrollable).first,
  );
}

void main() {
  const exercises = [
    Exercise(exerciseId: 'BP-001', name: 'Bench Press', published: true),
  ];

  group('SessionBuilderEditingState adaptation', () {
    test('legacy session loads with null adaptation fields', () {
      final state = SessionBuilderEditingState(
        draft: ProtocolDraft(
          protocolId: 'legacy',
          name: 'Legacy',
          steps: [],
          sessionFormat: 'structured_strength',
        ),
      );

      expect(state.primarySessionIntent, isNull);
      expect(state.secondarySessionIntents, isEmpty);
      expect(state.minimumViableDurationMin, isNull);
    });

    test('setting primary removes it from secondary intents', () {
      final state = SessionBuilderEditingState(
        draft: ProtocolDraft(
          protocolId: 'sess',
          name: 'Session',
          steps: [],
          secondarySessionIntents: const [
            SessionIntent.mobility,
            SessionIntent.prehabilitation,
          ],
        ),
      );

      state.setPrimarySessionIntent(SessionIntent.prehabilitation);

      expect(state.primarySessionIntent, SessionIntent.prehabilitation);
      expect(state.secondarySessionIntents, [SessionIntent.mobility]);
    });

    test('selecting primary intent updates built draft', () {
      final state = SessionBuilderEditingState(
        draft: ProtocolDraft(protocolId: 'sess', name: 'Session', steps: []),
      );

      state.setPrimarySessionIntent(SessionIntent.threshold);

      expect(state.buildDraft().primarySessionIntent, SessionIntent.threshold);
    });

    test('secondary intents dedupe and exclude primary in built draft', () {
      final state = SessionBuilderEditingState(
        draft: ProtocolDraft(
          protocolId: 'sess',
          name: 'Session',
          steps: [],
          primarySessionIntent: SessionIntent.threshold,
        ),
      );

      state.setSecondarySessionIntents(const [
        SessionIntent.mobility,
        SessionIntent.mobility,
        SessionIntent.threshold,
      ]);

      expect(state.buildDraft().secondarySessionIntents, [
        SessionIntent.mobility,
      ]);
    });

    test('build draft preserves explicit block metadata without defaults', () {
      final codeDraft = fullyTaggedUpperBodyStrengthSession(
        protocolId: 'code-1',
        programmeVersionId: testProgrammeVersionId,
      );
      final state = SessionBuilderEditingState(draft: codeDraft);
      final built = state.buildDraft();

      expect(built.primarySessionIntent, SessionIntent.upperBodyStrength);
      expect(built.blocks[1].blockPriority, BlockPriority.essential);
      expect(built.blocks[0].blockPriority, isNull);
      expect(built.blocks[0].adaptationPolicy, isNull);
    });

    test(
      'returning block to recommended clears explicit policy in built draft',
      () {
        final authoredBlock = block(
          type: SessionBlockType.strength,
          adaptationPolicy: const BlockAdaptationPolicy(
            canRemove: true,
            canShorten: true,
            canReduceVolume: true,
            canReduceIntensity: true,
            canIncreaseRest: true,
            canSuperset: true,
            canReplaceExercises: true,
            canReplaceBlock: true,
          ),
        );
        final cleared = authoredBlock.copyWith(clearAdaptationPolicy: true);
        expect(cleared.adaptationPolicy, isNull);
        expect(cleared.effectiveAdaptationPolicy.canRemove, isFalse);
      },
    );

    test('minimum viable duration validation when planned duration set', () {
      final state = SessionBuilderEditingState(
        draft: ProtocolDraft(
          protocolId: 'sess',
          name: 'Session',
          steps: [],
          durationMin: 45,
          minimumViableDurationMin: 50,
        ),
      );
      final built = state.buildDraft();
      final messages = SessionAdaptationMetadataValidation.validate(
        primarySessionIntent: built.primarySessionIntent,
        secondarySessionIntents: built.secondarySessionIntents,
        minimumViableDurationMin: built.minimumViableDurationMin,
        plannedDurationMin: built.durationMin,
      );
      expect(messages, isNotEmpty);
    });
  });

  group('SessionBuilderView adaptation controls', () {
    testWidgets('shows adaptation section for embedded coach session', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SessionBuilderView(
                draft: ProtocolDraft(
                  protocolId: 'local-1',
                  name: 'Session',
                  sessionFormat: 'structured_strength',
                  steps: [],
                ),
                exercises: exercises,
                displayContext:
                    SessionBuilderDisplayContext.embeddedProgrammeSession(
                      programmeLocationLabel: 'Week 1 · Day 1',
                    ),
                capabilities: SessionBuilderCapabilities.embeddedCoachSession(),
                onDraftChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Adaptation metadata'), findsOneWidget);
      expect(find.text('Primary session intent'), findsOneWidget);
      expect(find.textContaining('Shortest duration'), findsOneWidget);
    });

    testWidgets('code-created session displays authored intents', (
      tester,
    ) async {
      final codeDraft = fullyTaggedUpperBodyStrengthSession(
        protocolId: 'code-ui-1',
        programmeVersionId: testProgrammeVersionId,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SessionBuilderView(
                draft: codeDraft,
                exercises: exercises,
                displayContext:
                    SessionBuilderDisplayContext.embeddedProgrammeSession(
                      programmeLocationLabel: 'Week 1',
                    ),
                capabilities: SessionBuilderCapabilities.embeddedCoachSession(),
                onDraftChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Upper body strength'), findsWidgets);
      expect(find.text('Upper body hypertrophy'), findsWidgets);
      final editing = SessionBuilderEditingState(draft: codeDraft);
      expect(editing.primarySessionIntent, SessionIntent.upperBodyStrength);
    });

    testWidgets('secondary intent chips exclude primary', (tester) async {
      ProtocolDraft? latest;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SessionBuilderView(
                draft: ProtocolDraft(
                  protocolId: 'local-1',
                  name: 'Session',
                  sessionFormat: 'structured_strength',
                  steps: [],
                  primarySessionIntent: SessionIntent.threshold,
                ),
                exercises: exercises,
                displayContext:
                    SessionBuilderDisplayContext.embeddedProgrammeSession(
                      programmeLocationLabel: 'Week 1',
                    ),
                capabilities: SessionBuilderCapabilities.embeddedCoachSession(),
                onDraftChanged: (value) => latest = value,
              ),
            ),
          ),
        ),
      );

      final thresholdChips = find.widgetWithText(FilterChip, 'Threshold');
      expect(thresholdChips, findsNothing);
    });

    testWidgets('secondary intent chip selection updates draft', (
      tester,
    ) async {
      ProtocolDraft? latest;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SessionBuilderView(
                draft: ProtocolDraft(
                  protocolId: 'local-1',
                  name: 'Session',
                  sessionFormat: 'structured_strength',
                  steps: [],
                ),
                exercises: exercises,
                displayContext:
                    SessionBuilderDisplayContext.embeddedProgrammeSession(
                      programmeLocationLabel: 'Week 1',
                    ),
                capabilities: SessionBuilderCapabilities.embeddedCoachSession(),
                onDraftChanged: (value) => latest = value,
              ),
            ),
          ),
        ),
      );

      final mobilityChip = find.widgetWithText(FilterChip, 'Mobility').first;
      await scrollSessionBuilderTo(tester, mobilityChip);
      await tester.tap(mobilityChip);
      await tester.pumpAndSettle();
      expect(latest?.secondarySessionIntents, [SessionIntent.mobility]);
    });

    testWidgets('save and reopen restores adaptation fields via applyDraft', (
      tester,
    ) async {
      final saved = ProtocolDraft(
        protocolId: 'local-1',
        name: 'Session',
        sessionFormat: 'structured_strength',
        steps: [],
        primarySessionIntent: SessionIntent.aerobicConditioning,
        secondarySessionIntents: const [SessionIntent.mobility],
        minimumViableDurationMin: 30,
        durationMin: 60,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SessionBuilderView(
                draft: saved,
                exercises: exercises,
                displayContext:
                    SessionBuilderDisplayContext.embeddedProgrammeSession(
                      programmeLocationLabel: 'Week 1',
                    ),
                capabilities: SessionBuilderCapabilities.embeddedCoachSession(),
                onDraftChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SessionBuilderView(
                draft: saved,
                exercises: exercises,
                displayContext:
                    SessionBuilderDisplayContext.embeddedProgrammeSession(
                      programmeLocationLabel: 'Week 1',
                    ),
                capabilities: SessionBuilderCapabilities.embeddedCoachSession(),
                onDraftChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aerobic conditioning'), findsWidgets);
      expect(find.text('30'), findsWidgets);
    });

    testWidgets('block shows recommended adaptation policy by default', (
      tester,
    ) async {
      ProtocolDraft? latest;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SessionBuilderView(
                draft: ProtocolDraft(
                  protocolId: 'local-1',
                  name: 'Session',
                  sessionFormat: 'structured_strength',
                  steps: [],
                  blocks: [
                    block(
                      type: SessionBlockType.strength,
                      title: 'Main',
                      content: 'Lift',
                      workoutFormat: WorkoutFormat.none,
                    ),
                  ],
                ),
                exercises: exercises,
                displayContext:
                    SessionBuilderDisplayContext.embeddedProgrammeSession(
                      programmeLocationLabel: 'Week 1',
                    ),
                capabilities: SessionBuilderCapabilities.embeddedCoachSession(),
                onDraftChanged: (value) => latest = value,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Recommended'), findsWidgets);
      expect(latest?.blocks.first.adaptationPolicy, isNull);
    });

    testWidgets(
      'switching adaptation policy custom then recommended clears override',
      (tester) async {
        ProtocolDraft? latest;
        final initial = ProtocolDraft(
          protocolId: 'local-1',
          name: 'Session',
          sessionFormat: 'structured_strength',
          steps: [],
          blocks: [
            block(
              type: SessionBlockType.strength,
              title: 'Main',
              content: 'Lift',
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SessionBuilderView(
                  draft: initial,
                  exercises: exercises,
                  displayContext:
                      SessionBuilderDisplayContext.embeddedProgrammeSession(
                        programmeLocationLabel: 'Week 1',
                      ),
                  capabilities:
                      SessionBuilderCapabilities.embeddedCoachSession(),
                  onDraftChanged: (value) => latest = value,
                ),
              ),
            ),
          ),
        );

        final customSegment = find.text('Custom').first;
        await scrollSessionBuilderTo(tester, customSegment);
        await tester.tap(customSegment);
        await tester.pumpAndSettle();
        expect(latest?.blocks.first.adaptationPolicy, isNotNull);

        final recommendedSegment = find.text('Recommended').first;
        await scrollSessionBuilderTo(tester, recommendedSegment);
        await tester.tap(recommendedSegment);
        await tester.pumpAndSettle();
        expect(latest?.blocks.first.adaptationPolicy, isNull);
      },
    );
  });
}
