import 'dart:io';

import 'package:cohort_platform/features/programme_builder/models/programme_session_authoring_result.dart';
import 'package:cohort_platform/features/programme_builder/screens/embedded_session_builder_screen.dart';
import 'package:cohort_platform/features/programme_builder/services/programme_session_authoring_coordinator.dart';
import 'package:cohort_platform/features/session_builder/models/programme_session_authoring_context.dart';
import 'package:cohort_platform/features/session_builder/models/session_builder_host_mode.dart';
import 'package:cohort_platform/models/exercise.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/training_content_vocabulary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/programme_session_authoring_test_support.dart';

void main() {
  const authoringContext = ProgrammeSessionAuthoringContext(
    programmeVersionId: testProgrammeVersionId,
    weekLocalId: testWeekLocalId,
    dayLocalId: testDayLocalId,
    slotLocalId: testSlotLocalId,
    weekNumber: 2,
    dayLabel: 'Tuesday',
    slotDisplayLabel: 'Morning',
    authoringIntent: ProgrammeSessionAuthoringIntent.createBlank,
    programmeLocationLabel: 'Week 2 · Tuesday · Morning',
  );

  ProgrammeSessionAuthoringCoordinator buildCoordinator({
    bool failSave = false,
    bool failAttach = false,
  }) {
    final protocolService = FakeProtocolBuilderService()..failSave = failSave;
    final assignmentPort = FakeProgrammeSessionAssignmentPort(
      document: buildProgrammeDocumentWithSlot(),
      failAttach: failAttach,
    );

    return ProgrammeSessionAuthoringCoordinator(
      protocolBuilderService: protocolService,
      assignmentPort: assignmentPort,
      idGenerator: FixedSessionIdGenerator(testDurableSessionId),
      coachIdentity: const FixedCoachIdentity('dev-coach'),
    );
  }

  group('EmbeddedSessionBuilderScreen', () {
    testWidgets('displays programme location and active Save & Attach',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EmbeddedSessionBuilderScreen(
            authoringContext: authoringContext,
            coordinator: buildCoordinator(),
            loadExercises: () async => const [
              Exercise(exerciseId: 'EX-001', name: 'Back Squat', published: true),
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Session Builder'), findsOneWidget);
      expect(find.text('Week 2 · Tuesday · Morning'), findsWidgets);
      expect(find.text('Save & Attach'), findsOneWidget);
      expect(find.text('Save & Attach will be enabled in M3.'), findsNothing);
    });

    testWidgets('cancel pops with cancelled result', (tester) async {
      ProgrammeSessionAuthoringResult? popResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () async {
                    popResult =
                        await Navigator.of(context).push<ProgrammeSessionAuthoringResult>(
                      MaterialPageRoute<ProgrammeSessionAuthoringResult>(
                        builder: (_) => EmbeddedSessionBuilderScreen(
                          authoringContext: authoringContext,
                          coordinator: buildCoordinator(),
                          loadExercises: () async => const [],
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('← Cancel'));
      await tester.pumpAndSettle();

      expect(popResult?.status, ProgrammeSessionAuthoringStatus.cancelled);
    });

    testWidgets('success closes route after Save & Attach', (tester) async {
      ProgrammeSessionAuthoringResult? popResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () async {
                    popResult =
                        await Navigator.of(context).push<ProgrammeSessionAuthoringResult>(
                      MaterialPageRoute<ProgrammeSessionAuthoringResult>(
                        builder: (_) => EmbeddedSessionBuilderScreen(
                          authoringContext: authoringContext,
                          coordinator: buildCoordinator(),
                          initialDraft: buildValidProgrammeSessionDraft(),
                          loadExercises: () async => const [],
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save & Attach'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(popResult?.isAttached, isTrue);
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('save failure stays on screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EmbeddedSessionBuilderScreen(
            authoringContext: authoringContext,
            coordinator: buildCoordinator(failSave: true),
            initialDraft: buildValidProgrammeSessionDraft(),
            loadExercises: () async => const [],
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Save & Attach'));
      await tester.pumpAndSettle();

      expect(find.text('Session could not be saved.'), findsOneWidget);
      expect(find.text('Save & Attach'), findsOneWidget);
    });

    testWidgets('partial failure displays Retry adding to programme',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EmbeddedSessionBuilderScreen(
            authoringContext: authoringContext,
            coordinator: buildCoordinator(failAttach: true),
            initialDraft: buildValidProgrammeSessionDraft(),
            loadExercises: () async => const [],
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Save & Attach'));
      await tester.pumpAndSettle();

      expect(
        find.text('Session saved, but could not be added to the programme.'),
        findsOneWidget,
      );
      expect(find.text('Retry adding to programme'), findsOneWidget);
    });

    testWidgets('uses preloaded draft when provided', (tester) async {
      const preloaded = ProtocolDraft(
        protocolId: 'local-session-slot-am',
        name: 'Custom Session',
        steps: [],
        contentKind: TrainingContentKind.session,
        authoringScope: TrainingAuthoringScope.programmeOnly,
        endorsementStatus: TrainingEndorsementStatus.coachAuthored,
        programmeVersionId: testProgrammeVersionId,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EmbeddedSessionBuilderScreen(
            authoringContext: authoringContext,
            coordinator: buildCoordinator(),
            initialDraft: preloaded,
            loadExercises: () async => const [],
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Custom Session'), findsOneWidget);
    });

    test('screen source has no raw Supabase client import', () {
      final source = File(
        'lib/features/programme_builder/screens/embedded_session_builder_screen.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('SupabaseService')));
      expect(source.toLowerCase(), isNot(contains('supabase_flutter')));
    });
  });
}
