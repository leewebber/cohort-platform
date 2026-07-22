import 'package:cohort_platform/core/widgets/today_session_card.dart';
import 'package:cohort_platform/features/home/models/home_today_session_state.dart';
import 'package:cohort_platform/features/home/services/home_today_session_loader.dart';
import 'package:cohort_platform/features/home/widgets/home_today_session_section.dart';
import 'package:cohort_platform/features/programme/models/programme_execution_context.dart';
import 'package:cohort_platform/features/programme/models/programme_progress_summary.dart';
import 'package:cohort_platform/features/programme/models/resolved_today_session.dart';
import 'package:cohort_platform/features/session/models/active_session_state.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/programme/models/programme_progression_result.dart';
import 'package:cohort_platform/features/session/models/session_execution_status.dart';
import 'package:cohort_platform/models/programme_slot_outcome.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:cohort_platform/features/session/screens/session_complete_screen.dart';
import 'package:cohort_platform/models/protocol.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ActiveSessionState _testSessionState({
  required SessionExecutionPlan plan,
  Set<String>? completedBlockIds,
  DateTime? startedAt,
  DateTime? endedAt,
}) {
  final completed = completedBlockIds ?? const {};
  return ActiveSessionState(
    sessionKey: 'test-session',
    plan: plan,
    blockStates: const [],
    activeBlockIndex: 0,
    completedBlockIds: completed,
    expandedBlockIds: const {},
    sessionStatus: SessionExecutionStatus.completed,
    startedAt: startedAt,
    endedAt: endedAt,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ResolvedTodaySession executableResolution() {
    return ResolvedTodaySession(
      kind: ResolvedTodaySessionKind.executable,
      assignment: ProgrammeAssignment(
        id: 'assignment-1',
        athleteId: 'lee',
        programmeVersionId: 'version-1',
        lineageCode: 'COHORT-FOUNDATION-TEST',
        status: ProgrammeAssignmentStatus.active,
        startedAt: DateTime.utc(2026, 7, 15),
        currentWeek: 3,
        currentDayKey: 'day_1',
        currentSessionOrder: 1,
      ),
      assignmentId: 'assignment-1',
      programmeVersionId: 'version-1',
      lineageCode: 'COHORT-FOUNDATION-TEST',
      programmeName: 'Cohort Foundation',
      weekNumber: 3,
      dayKey: 'day_1',
      dayIntent: ProgrammeIntent.build,
      slotTitle: 'Lower Body Strength',
      plannedProtocolId: 'BW-001',
      effectiveProtocolId: 'RN-006',
      isOptional: false,
      isRestDay: false,
      programmeComplete: false,
    );
  }

  group('TodaySessionCard', () {
    testWidgets('shows programme context and START SESSION CTA', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TodaySessionCard(
              title: 'Recovery Flow',
              subtitle: "Today's session • Lower Body Strength",
              programmeName: 'Cohort Foundation',
              weekLabel: 'Week 3 • Day 1',
              duration: '45 min estimated',
              sessionGoal: 'Session goal: Build',
              progressLabel: 'Week 3 of 8 • 12 / 32 sessions completed',
              adaptationNotice:
                  'Adapted for today — Recovery Flow replaces the originally planned session.',
              buttonLabel: 'START SESSION',
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text("TODAY'S TRAINING"), findsOneWidget);
      expect(find.text('Recovery Flow'), findsOneWidget);
      expect(find.text('Cohort Foundation'), findsOneWidget);
      expect(find.text('Session goal: Build'), findsOneWidget);
      expect(find.textContaining('12 / 32 sessions completed'), findsOneWidget);
      expect(find.textContaining('Adapted for today'), findsOneWidget);
      expect(find.text('START SESSION'), findsOneWidget);
    });
  });

  group('HomeTodaySessionLabels', () {
    test('session goal uses day intent label', () {
      expect(
        HomeTodaySessionLabels.sessionGoal(executableResolution()),
        'Session goal: Build',
      );
    });

    test('adaptation notice appears when protocol differs', () {
      final notice = HomeTodaySessionLabels.adaptationNotice(
        executableResolution(),
        const Protocol(protocolId: 'RN-006', name: 'Recovery Flow'),
      );

      expect(notice, contains('Recovery Flow'));
      expect(notice, contains('originally planned'));
    });

    test('week label excludes programme name', () {
      expect(
        HomeTodaySessionLabels.weekLabel(executableResolution()),
        'Week 3 • Day 1',
      );
    });
  });

  group('HomeTodaySessionSection states', () {
    testWidgets('empty state explains no programme assigned', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeTodaySessionSection(
            athleteId: 'lee',
            loadOverride: (_) async => const HomeTodaySessionEmpty(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No programme assigned'), findsOneWidget);
      expect(find.textContaining('coach assigns'), findsOneWidget);
    });

    testWidgets('rest day card shows recovery copy', (tester) async {
      final resolution = ResolvedTodaySession(
        kind: ResolvedTodaySessionKind.restDay,
        programmeName: 'Cohort Foundation',
        weekNumber: 2,
        dayKey: 'day_3',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeTodaySessionSection(
            athleteId: 'lee',
            loadOverride: (_) async => HomeTodaySessionRestDay(
              resolution: resolution,
              progressSummary: const ProgrammeProgressSummary(
                currentWeek: 2,
                totalWeeks: 8,
                completedSessions: 5,
                totalSessions: 32,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Recovery is part'), findsOneWidget);
      expect(find.text('Cohort Foundation'), findsOneWidget);
      expect(find.textContaining('5 / 32 sessions completed'), findsOneWidget);
    });

    testWidgets('programme complete card celebrates completion', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeTodaySessionSection(
            athleteId: 'lee',
            loadOverride: (_) async => HomeTodaySessionProgrammeComplete(
              resolution: ResolvedTodaySession(
                kind: ResolvedTodaySessionKind.programmeComplete,
                programmeName: 'Cohort Foundation',
                weekNumber: 8,
                dayKey: 'day_7',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Congratulations'), findsOneWidget);
      expect(find.textContaining('Programme Complete'), findsWidgets);
    });
  });

  group('SessionCompleteScreen', () {
    testWidgets('shows saved, progress, adaptation, and next session', (tester) async {
      final plan = SessionExecutionPlan(
        sessionId: 'BW-001',
        sessionTitle: 'Bodyweight Grinder',
        blocks: const [],
      );
      final state = _testSessionState(
        plan: plan,
        completedBlockIds: {'block-1', 'block-2', 'block-3'},
        startedAt: DateTime.utc(2026, 7, 22, 10),
        endedAt: DateTime.utc(2026, 7, 22, 10, 45),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SessionCompleteScreen(
            state: state,
            savedRecord: null,
            adaptationMessage: 'Load increased by 2.5 kg on your next squat slot.',
            programmeProgress: const ProgrammeProgressSummary(
              currentWeek: 3,
              totalWeeks: 8,
              completedSessions: 12,
              totalSessions: 32,
            ),
            progressionResult: ProgrammeProgressionResult.completed(
              outcome: ProgrammeSlotOutcome(
                id: 'outcome-1',
                assignmentId: 'assignment-1',
                sessionSlotId: 'slot-1',
                weekNumber: 3,
                dayKey: 'day_2',
                sessionOrder: 1,
                outcomeStatus: ProgrammeSlotOutcomeStatus.completed,
              ),
              updatedAssignment: ProgrammeAssignment(
                id: 'assignment-1',
                athleteId: 'lee',
                programmeVersionId: 'version-1',
                lineageCode: 'COHORT-FOUNDATION-TEST',
                status: ProgrammeAssignmentStatus.active,
                startedAt: DateTime.utc(2026, 7, 1),
                currentWeek: 3,
                currentDayKey: 'day_2',
                currentSessionOrder: 1,
              ),
              nextResolvedSession: ResolvedTodaySession(
                kind: ResolvedTodaySessionKind.executable,
                programmeName: 'Cohort Foundation',
                weekNumber: 3,
                dayKey: 'day_2',
                slotTitle: 'Conditioning',
                effectiveProtocolId: 'RN-006',
              ),
              athleteStateSynced: true,
            ),
          ),
        ),
      );

      expect(find.text('SESSION COMPLETE'), findsOneWidget);
      expect(find.text('Session saved'), findsOneWidget);
      expect(find.text('Programme progress'), findsOneWidget);
      expect(find.textContaining('12 / 32 sessions completed'), findsOneWidget);
      expect(find.textContaining('Load increased'), findsOneWidget);
      expect(find.text('Next scheduled session'), findsOneWidget);
      expect(find.textContaining('Conditioning'), findsOneWidget);
    });

    testWidgets('defaults adaptation copy when no change applied', (tester) async {
      final plan = SessionExecutionPlan(
        sessionId: 'BW-001',
        sessionTitle: 'Bodyweight Grinder',
        blocks: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SessionCompleteScreen(
            state: _testSessionState(
              plan: plan,
              completedBlockIds: {'block-1'},
            ),
          ),
        ),
      );

      expect(
        find.text('Programme continues as planned.'),
        findsOneWidget,
      );
    });
  });
}
