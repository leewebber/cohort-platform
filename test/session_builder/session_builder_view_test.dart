import 'dart:io';

import 'package:cohort_platform/features/session_builder/controllers/session_builder_editing_state.dart';
import 'package:cohort_platform/features/session_builder/models/programme_session_authoring_context.dart';
import 'package:cohort_platform/features/session_builder/models/session_builder_display_context.dart';
import 'package:cohort_platform/features/session_builder/models/session_builder_host_mode.dart';
import 'package:cohort_platform/features/session_builder/services/programme_session_draft_factory.dart';
import 'package:cohort_platform/features/session_builder/services/session_builder_validation.dart';
import 'package:cohort_platform/features/session_builder/widgets/session_builder_view.dart';
import 'package:cohort_platform/models/exercise.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/training_content_vocabulary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const exercises = [
    Exercise(exerciseId: 'EX-001', name: 'Back Squat', published: true),
  ];

  group('ProgrammeSessionDraftFactory', () {
    test('creates blank programme-only session with coach defaults', () {
      const context = ProgrammeSessionAuthoringContext(
        programmeVersionId: '11111111-1111-1111-1111-111111111111',
        weekLocalId: 'week-1',
        dayLocalId: 'day-1',
        slotLocalId: 'slot-1',
        weekNumber: 2,
        dayLabel: 'Tuesday',
        slotDisplayLabel: 'Morning',
        authoringIntent: ProgrammeSessionAuthoringIntent.createBlank,
        programmeLocationLabel: 'Week 2 · Tuesday · Morning',
      );

      final draft =
          ProgrammeSessionDraftFactory.createBlankProgrammeSessionDraft(context);

      expect(draft.contentKind, TrainingContentKind.session);
      expect(draft.authoringScope, TrainingAuthoringScope.programmeOnly);
      expect(draft.endorsementStatus, TrainingEndorsementStatus.coachAuthored);
      expect(draft.programmeVersionId, context.programmeVersionId);
      expect(draft.published, isFalse);
      expect(draft.protocolId, startsWith('local-session-'));
      expect(draft.name, contains('Week 2'));
      expect(draft.steps, isEmpty);
    });
  });

  group('SessionBuilderEditingState', () {
    test('add step and build draft retains metadata', () {
      const draft = ProtocolDraft(
        protocolId: 'RN-006',
        name: 'Threshold',
        steps: [],
        contentKind: TrainingContentKind.cohortProtocol,
      );

      final state = SessionBuilderEditingState(draft: draft);
      state.addStep();

      final built = state.buildDraft();
      expect(built.steps, hasLength(1));
      expect(built.contentKind, TrainingContentKind.cohortProtocol);
      expect(built.protocolId, 'RN-006');
    });

    test('editing name does not reset classification', () {
      const draft = ProtocolDraft(
        protocolId: 'RN-006',
        name: 'Threshold',
        steps: [],
      );

      final state = SessionBuilderEditingState(draft: draft);
      state.name = 'Updated';
      final built = state.buildDraft();

      expect(built.name, 'Updated');
      expect(built.contentKind, TrainingContentKind.cohortProtocol);
    });
  });

  group('SessionBuilderValidation', () {
    test('preview requires name, format, and steps', () {
      const draft = ProtocolDraft(
        protocolId: 'local-session-1',
        name: '',
        steps: [],
      );

      final messages = SessionBuilderValidation.previewReadinessMessages(draft);
      expect(messages.length, greaterThanOrEqualTo(3));
    });
  });

  group('SessionBuilderView', () {
    testWidgets('embedded mode uses Session terminology', (tester) async {
      ProtocolDraft? latest;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SessionBuilderView(
                draft: const ProtocolDraft(
                  protocolId: 'local-session-slot-1',
                  name: 'Week 1 Session',
                  steps: [],
                  contentKind: TrainingContentKind.session,
                  authoringScope: TrainingAuthoringScope.programmeOnly,
                  endorsementStatus: TrainingEndorsementStatus.coachAuthored,
                ),
                exercises: exercises,
                displayContext:
                    SessionBuilderDisplayContext.embeddedProgrammeSession(
                  programmeLocationLabel: 'Week 1 · Tuesday · Morning',
                ),
                capabilities: SessionBuilderCapabilities.embeddedCoachSession(),
                onDraftChanged: (draft) => latest = draft,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Session name'), findsOneWidget);
      expect(find.text('Session type'), findsOneWidget);
      expect(find.text('BLOCKS'), findsOneWidget);
      expect(find.text('protocol_id'), findsNothing);
      expect(find.text('Publish'), findsNothing);
    });

    testWidgets('admin mode shows protocol_id field', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SessionBuilderView(
                draft: const ProtocolDraft(
                  protocolId: 'RN-006',
                  name: 'Threshold',
                  steps: [],
                ),
                exercises: exercises,
                displayContext:
                    SessionBuilderDisplayContext.cohortProtocolAdmin(),
                capabilities: SessionBuilderCapabilities.cohortProtocolAdmin(
                  protocolIdLocked: false,
                ),
                onDraftChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('protocol_id'), findsOneWidget);
      expect(find.text('PROTOCOL DETAILS'), findsOneWidget);
      expect(find.text('SESSION STEPS'), findsOneWidget);
    });

    testWidgets('editing session name emits updated draft', (tester) async {
      ProtocolDraft? latest;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SessionBuilderView(
                draft: const ProtocolDraft(
                  protocolId: 'local-session-1',
                  name: 'Original',
                  steps: [],
                ),
                exercises: exercises,
                displayContext:
                    SessionBuilderDisplayContext.embeddedProgrammeSession(
                  programmeLocationLabel: 'Week 1 · Day 1 · Morning',
                ),
                capabilities: SessionBuilderCapabilities.embeddedCoachSession(),
                onDraftChanged: (draft) => latest = draft,
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField).first, 'Updated Name');
      await tester.pump();

      expect(latest?.name, 'Updated Name');
    });

    testWidgets('add step emits draft with one step', (tester) async {
      ProtocolDraft? latest;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SessionBuilderView(
                draft: const ProtocolDraft(
                  protocolId: 'local-session-1',
                  name: 'Session',
                  steps: [],
                ),
                exercises: exercises,
                displayContext:
                    SessionBuilderDisplayContext.embeddedProgrammeSession(
                  programmeLocationLabel: 'Week 1 · Day 1',
                ),
                capabilities: SessionBuilderCapabilities.embeddedCoachSession(),
                onDraftChanged: (draft) => latest = draft,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Add exercise'));
      await tester.pump();

      expect(latest?.steps, hasLength(1));
    });

    test('shared view source has no Supabase imports', () {
      final source = File(
        'lib/features/session_builder/widgets/session_builder_view.dart',
      ).readAsStringSync();

      expect(source, isNot(contains("import 'package:supabase")));
      expect(source, isNot(contains('SupabaseService')));
    });
  });
}
