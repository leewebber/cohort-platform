import 'package:cohort_platform/core/widgets/today_session_card.dart';
import 'package:cohort_platform/features/home/controllers/home_today_session_refresh_controller.dart';
import 'package:cohort_platform/features/home/debug/home_debug_programme_refresh_policy.dart';
import 'package:cohort_platform/features/home/models/home_today_session_state.dart';
import 'package:cohort_platform/features/home/widgets/home_today_session_section.dart';
import 'package:cohort_platform/features/programme/models/programme_assignment_operation_result.dart';
import 'package:cohort_platform/features/programme/models/programme_execution_context.dart';
import 'package:cohort_platform/features/programme/models/resolved_today_session.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:cohort_platform/models/protocol.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ResolvedTodaySession executableResolution({
    required String dayKey,
    required String protocolId,
    String slotId = 'slot-1',
  }) {
    return ResolvedTodaySession(
      kind: ResolvedTodaySessionKind.executable,
      assignment: ProgrammeAssignment(
        id: 'assignment-1',
        athleteId: 'lee',
        programmeVersionId: 'version-1',
        lineageCode: 'COHORT-FOUNDATION-TEST',
        status: ProgrammeAssignmentStatus.active,
        startedAt: DateTime.utc(2026, 7, 15),
        currentWeek: 1,
        currentDayKey: dayKey,
        currentSessionOrder: 1,
      ),
      assignmentId: 'assignment-1',
      programmeVersionId: 'version-1',
      lineageCode: 'COHORT-FOUNDATION-TEST',
      programmeName: 'Cohort Foundation Test',
      weekNumber: 1,
      dayKey: dayKey,
      slotId: slotId,
      slotOrder: 1,
      plannedProtocolId: protocolId,
      effectiveProtocolId: protocolId,
      isOptional: false,
      isRestDay: false,
      programmeComplete: false,
    );
  }

  HomeTodaySessionProgrammeExecutable executableState({
    required String dayKey,
    required String protocolId,
    required String protocolName,
  }) {
    final resolution = executableResolution(
      dayKey: dayKey,
      protocolId: protocolId,
    );

    return HomeTodaySessionProgrammeExecutable(
      resolution: resolution,
      protocol: Protocol(protocolId: protocolId, name: protocolName),
      executionContext: ProgrammeExecutionContext.fromResolvedSession(resolution),
    );
  }

  group('HomeTodaySessionSection refresh', () {
    testWidgets('successful reset refresh shows day_1 without route restart',
        (tester) async {
      final controller = HomeTodaySessionRefreshController();
      var loadCount = 0;

      Future<HomeTodaySessionState> loadOverride(String athleteId) async {
        loadCount++;
        return loadCount == 1
            ? executableState(
                dayKey: 'day_2',
                protocolId: 'RN-006',
                protocolName: 'Classic Threshold Intervals',
              )
            : executableState(
                dayKey: 'day_1',
                protocolId: 'BW-001',
                protocolName: 'Bodyweight Grinder',
              );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeTodaySessionSection(
              refreshController: controller,
              loadOverride: loadOverride,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Classic Threshold Intervals'), findsOneWidget);
      expect(find.textContaining('Day 2'), findsOneWidget);
      expect(loadCount, 1);

      controller.requestRefresh(source: 'programme_reset');
      await tester.pump();
      expect(find.text('Loading session...'), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('Bodyweight Grinder'), findsOneWidget);
      expect(find.textContaining('Day 1'), findsOneWidget);
      expect(find.text('Classic Threshold Intervals'), findsNothing);
      expect(loadCount, 2);
    });

    testWidgets('successful complete-slot refresh shows day_2', (tester) async {
      final controller = HomeTodaySessionRefreshController();
      var loadCount = 0;

      Future<HomeTodaySessionState> loadOverride(String athleteId) async {
        loadCount++;
        return loadCount == 1
            ? executableState(
                dayKey: 'day_1',
                protocolId: 'BW-001',
                protocolName: 'Bodyweight Grinder',
              )
            : executableState(
                dayKey: 'day_2',
                protocolId: 'RN-006',
                protocolName: 'Classic Threshold Intervals',
              );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeTodaySessionSection(
              refreshController: controller,
              loadOverride: loadOverride,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bodyweight Grinder'), findsOneWidget);

      controller.requestRefresh(source: 'programme_complete');
      await tester.pumpAndSettle();

      expect(find.text('Classic Threshold Intervals'), findsOneWidget);
      expect(find.textContaining('Day 2'), findsOneWidget);
      expect(loadCount, 2);
    });

    testWidgets('failed reset policy leaves card unchanged when not refreshed',
        (tester) async {
      final controller = HomeTodaySessionRefreshController();
      var loadCount = 0;

      Future<HomeTodaySessionState> loadOverride(String athleteId) async {
        loadCount++;
        return executableState(
          dayKey: 'day_2',
          protocolId: 'RN-006',
          protocolName: 'Classic Threshold Intervals',
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeTodaySessionSection(
              refreshController: controller,
              loadOverride: loadOverride,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final failedReset = ProgrammeAssignmentOperationResult.failed(
        message: 'DELETE removed 0 rows',
      );
      expect(
        HomeDebugProgrammeRefreshPolicy.shouldRefreshAfterReset(failedReset),
        isFalse,
      );

      expect(find.text('Classic Threshold Intervals'), findsOneWidget);
      expect(loadCount, 1);
    });

    testWidgets('read-only resolve does not auto-refresh Today section',
        (tester) async {
      final controller = HomeTodaySessionRefreshController();
      var loadCount = 0;

      Future<HomeTodaySessionState> loadOverride(String athleteId) async {
        loadCount++;
        return executableState(
          dayKey: 'day_2',
          protocolId: 'RN-006',
          protocolName: 'Classic Threshold Intervals',
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeTodaySessionSection(
              refreshController: controller,
              loadOverride: loadOverride,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(loadCount, 1);
      expect(find.text('Classic Threshold Intervals'), findsOneWidget);
      expect(find.byType(TodaySessionCard), findsOneWidget);
    });

    testWidgets('GlobalKey currentState refresh matches HomeScreen wiring',
        (tester) async {
      final sectionKey = GlobalKey<HomeTodaySessionSectionState>();
      var loadCount = 0;

      Future<HomeTodaySessionState> loadOverride(String athleteId) async {
        loadCount++;
        return loadCount == 1
            ? executableState(
                dayKey: 'day_2',
                protocolId: 'RN-006',
                protocolName: 'Classic Threshold Intervals',
              )
            : executableState(
                dayKey: 'day_1',
                protocolId: 'BW-001',
                protocolName: 'Bodyweight Grinder',
              );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeTodaySessionSection(
              key: sectionKey,
              loadOverride: loadOverride,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(sectionKey.currentState, isNotNull);
      expect(find.text('Classic Threshold Intervals'), findsOneWidget);

      sectionKey.currentState!.refresh(source: 'programme_reset');
      await tester.pumpAndSettle();

      expect(find.text('Bodyweight Grinder'), findsOneWidget);
      expect(loadCount, 2);
    });
  });
}
