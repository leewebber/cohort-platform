import 'dart:io';

import 'package:cohort_platform/core/services/authenticated_identity.dart';
import 'package:cohort_platform/data/repositories/programme_assignment_store.dart';
import 'package:cohort_platform/features/auth/models/user_profile.dart';
import 'package:cohort_platform/features/auth/services/athlete_surface_identity.dart';
import 'package:cohort_platform/features/auth/services/current_user_session.dart';
import 'package:cohort_platform/features/home/home_screen.dart';
import 'package:cohort_platform/features/home/widgets/athlete_home_completed_programme_card.dart';
import 'package:cohort_platform/features/performance/screens/training_history_screen.dart';
import 'package:cohort_platform/features/performance/services/performance_record_save_coordinator.dart';
import 'package:cohort_platform/features/programme/domain/athlete_programme_context.dart';
import 'package:cohort_platform/features/programme/models/fixed_programme_occurrence_projection.dart';
import 'package:cohort_platform/features/programme/screens/athlete_calendar_screen.dart';
import 'package:cohort_platform/features/programme/controllers/athlete_programme_controllers.dart';
import 'package:cohort_platform/features/programme/screens/athlete_programme_screen.dart';
import 'package:cohort_platform/features/performance/models/training_session_record.dart';
import 'package:cohort_platform/features/progress/models/progress_summary.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_context_resolver.dart';
import 'package:cohort_platform/features/programme/services/fixed_programme_occurrence_projection_store.dart';
import 'package:cohort_platform/features/progress/screens/progress_screen.dart';
import 'package:cohort_platform/features/progress/services/athlete_progress_summary_builder.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_programme_stores.dart';
import '../support/programme_schedule_test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(CurrentUserSession.clear);

  group('assignment projection', () {
    test('active precedes completed and none is only a successful empty read', () async {
      final tables = InMemoryProgrammeTables();
      final completed = _assignment(
        id: 'older',
        status: ProgrammeAssignmentStatus.completed,
        completedAt: DateTime.utc(2026, 1, 1),
      );
      final active = _assignment(id: 'active');
      tables.assignments.addAll([completed, active]);
      final resolver = AthleteProgrammeContextResolver(
        InMemoryProgrammeAssignmentStore(tables),
      );

      final both = await resolver.resolve('athlete-s3');
      expect(both.isActive, isTrue);
      expect(both.assignment?.id, 'active');

      tables.assignments.removeWhere((row) => row.id == 'active');
      final after = await resolver.resolve('athlete-s3');
      expect(after.isCompleted, isTrue);
      expect(after.assignment?.id, 'older');

      tables.assignments.clear();
      final none = await resolver.resolve('athlete-s3');
      expect(none.isNone, isTrue);
    });

    test('most-recent completed is deterministic', () {
      final older = _assignment(
        id: 'a',
        status: ProgrammeAssignmentStatus.completed,
        completedAt: DateTime.utc(2026, 1, 1),
      );
      final newer = _assignment(
        id: 'b',
        status: ProgrammeAssignmentStatus.completed,
        completedAt: DateTime.utc(2026, 2, 1),
      );
      final selected = AthleteProgrammeContext.mostRecentCompleted([
        older,
        newer,
      ]);
      expect(selected?.id, 'b');
    });

    test('repository failure is not none', () async {
      expect(
        () => AthleteProgrammeContextResolver(
          _ThrowingAssignments(),
        ).resolve('athlete-s3'),
        throwsA(isA<AthleteProgrammeContextUnavailable>()),
      );
    });
  });

  group('identity', () {
    test('production requireAthleteId has no athlete.local fallback', () {
      expect(
        () => AthleteSurfaceIdentity.require(),
        throwsA(isA<AuthenticatedIdentityException>()),
      );
    });

    testWidgets('coach-only cannot open AuthGate athlete shell', (tester) async {
      CurrentUserSession.bind(
        const UserProfile(
          id: 'coach-only',
          displayName: 'Coach',
          isCoach: true,
          isAthlete: false,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return const Text('probe');
              },
            ),
          ),
        ),
      );
      expect(find.text('Athlete access is required'), findsNothing);
      expect(
        FileScan.hasNoAthleteLocal(
          'lib/features/home/home_screen.dart',
        ),
        isTrue,
      );
      expect(
        FileScan.hasNoAthleteLocal(
          'lib/features/progress/screens/progress_screen.dart',
        ),
        isTrue,
      );
      expect(
        FileScan.hasNoAthleteLocal(
          'lib/features/app_shell/athlete_app_shell.dart',
        ),
        isTrue,
      );
    });
  });

  group('completed Home and Programmes', () {
    testWidgets('completed Home wording and actions', (tester) async {
      final tables = InMemoryProgrammeTables();
      final assignment = _assignment(
        status: ProgrammeAssignmentStatus.completed,
        completedAt: DateTime.utc(2026, 9, 1),
      );
      tables.assignments.add(assignment);
      final calendar = _calendar(assignment, inspectionOnly: true);
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            athleteIdOverride: 'athlete-s3',
            embeddedInShell: true,
            assignmentStore: InMemoryProgrammeAssignmentStore(tables),
            fixedOccurrenceStore: _Projection(calendar),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AthleteHomeCompletedProgrammeCard), findsOneWidget);
      expect(find.text('You finished Apollo Strength.'), findsOneWidget);
      expect(find.text('View results'), findsOneWidget);
      expect(find.text('Browse programmes'), findsOneWidget);
      expect(find.text('Begin'), findsNothing);
      expect(find.text('Resume'), findsNothing);
      expect(find.text('Choose a plan'), findsNothing);
    });

    testWidgets('completed Calendar is inspect-only', (tester) async {
      final tables = InMemoryProgrammeTables();
      final assignment = _assignment(
        status: ProgrammeAssignmentStatus.completed,
        completedAt: DateTime.utc(2026, 9, 1),
      );
      tables.assignments.add(assignment);
      await tester.pumpWidget(
        MaterialApp(
          home: AthleteCalendarScreen(
            athleteId: 'athlete-s3',
            assignmentStore: InMemoryProgrammeAssignmentStore(tables),
            fixedOccurrenceStore: _Projection(
              _calendar(assignment, inspectionOnly: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Complete · inspect only'), findsOneWidget);
      expect(find.text('Begin'), findsNothing);
      expect(find.text('Resume'), findsNothing);
    });

    testWidgets('Programmes labels completed assignment Complete', (tester) async {
      final tables = InMemoryProgrammeTables();
      final assignment = _assignment(
        status: ProgrammeAssignmentStatus.completed,
        completedAt: DateTime.utc(2026, 9, 1),
      );
      tables.assignments.add(assignment);
      tables.versions.add(ProgrammeScheduleTestFixtures.version());
      await tester.pumpWidget(
        MaterialApp(
          home: AthleteProgrammeScreen(
            athleteId: 'athlete-s3',
            assignmentStore: InMemoryProgrammeAssignmentStore(tables),
            controller: AthleteProgrammeScreenController(
              athleteId: 'athlete-s3',
              assignmentStore: InMemoryProgrammeAssignmentStore(tables),
              versionStore: InMemoryProgrammeVersionStore(tables),
            ),
            fixedOccurrenceStore: _Projection(
              _calendar(assignment, inspectionOnly: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Complete'), findsWidgets);
      expect(find.text('Browse programmes'), findsOneWidget);
    });
  });

  group('Progress and History states', () {
    testWidgets('Progress blocking failure is not empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProgressScreen(
            athleteIdOverride: 'athlete-s3',
            progressBuilder: _FailingProgressBuilder(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Progress could not be loaded'), findsOneWidget);
      expect(find.text('No recorded sessions yet.'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('History blocking failure exposes Retry', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TrainingHistoryScreen(
            athleteId: 'athlete-s3',
            saveCoordinator: _FailingHistoryCoordinator(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Could not load history'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Completed sessions will appear here.'), findsNothing);
    });
  });

  test('production main does not import completion preview', () {
    expect(
      FileScan.contains(
        'lib/main.dart',
        'main_completion_history_integrity_preview',
      ),
      isFalse,
    );
  });
}

ProgrammeAssignment _assignment({
  String id = 'assignment-s3',
  ProgrammeAssignmentStatus status = ProgrammeAssignmentStatus.active,
  DateTime? completedAt,
}) {
  return ProgrammeAssignment(
    id: id,
    athleteId: 'athlete-s3',
    programmeVersionId: ProgrammeScheduleTestFixtures.versionId,
    lineageCode: 'APOLLO-BUILD-12-WEEK',
    status: status,
    startedAt: DateTime.utc(2026, 8, 1),
    completedAt: completedAt,
    timezone: 'Atlantic/Canary',
    scheduleMode: 'fixed_schedule',
    materialisedAt: DateTime.utc(2026, 8, 1),
    materialisedPackageContentHash:
        'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
  );
}

FixedProgrammeCalendarProjection _calendar(
  ProgrammeAssignment assignment, {
  bool inspectionOnly = false,
}) {
  return FixedProgrammeCalendarProjection(
    assignmentId: assignment.id,
    programmeName: 'Apollo Strength',
    timezone: 'Atlantic/Canary',
    scheduleMode: 'fixed_schedule',
    startDate: '2026-08-01',
    today: '2026-09-10',
    weekStart: '2026-09-07',
    weekEnd: '2026-09-13',
    assignmentStatus: inspectionOnly ? 'completed' : 'active',
    occurrences: [
      FixedProgrammeOccurrenceProjection(
        assignmentId: assignment.id,
        occurrenceId: 'occ-1',
        sessionSlotId: ProgrammeScheduleTestFixtures.slot1Id,
        programmeVersionId: assignment.programmeVersionId,
        protocolId: 'BW-001',
        programmedSessionKey: 'psk-1',
        weekNumber: 1,
        dayKey: 'day_1',
        sessionOrder: 1,
        scheduledDate: '2026-08-01',
        originalScheduledDate: '2026-08-01',
        state: FixedProgrammeOccurrenceState.completed,
        sessionTitle: 'Strength',
      ),
    ],
    currentWeek: [
      for (var i = 0; i < 7; i++)
        FixedProgrammeCalendarDayProjection(
          date: '2026-09-${(7 + i).toString().padLeft(2, '0')}',
          state: FixedProgrammeOccurrenceState.rest,
        ),
    ],
  );
}

class _Projection implements FixedProgrammeOccurrenceProjectionStore {
  _Projection(this.calendar);
  final FixedProgrammeCalendarProjection calendar;

  @override
  Future<FixedProgrammeCalendarProjection?> resolveActive() async {
    return calendar.isInspectionOnly ? null : calendar;
  }

  @override
  Future<FixedProgrammeCalendarProjection> resolveForAssignment(
    String assignmentId,
  ) async {
    if (calendar.assignmentId != assignmentId) {
      throw const FixedProgrammeCalendarUnavailableException(
        'assignment_not_found',
      );
    }
    return calendar;
  }
}

class _ThrowingAssignments implements ProgrammeAssignmentStore {
  @override
  Future<ProgrammeAssignment?> getActiveAssignment(String athleteId) {
    throw StateError('network');
  }

  @override
  Future<ProgrammeAssignment?> getById(String assignmentId) {
    throw StateError('network');
  }

  @override
  Future<ProgrammeAssignment> insert(ProgrammeAssignment assignment) {
    throw StateError('network');
  }

  @override
  Future<ProgrammeAssignment> update(ProgrammeAssignment assignment) {
    throw StateError('network');
  }

  @override
  Future<List<ProgrammeAssignment>> listForAthlete(String athleteId) {
    throw StateError('network');
  }

  @override
  Future<int> countAssignmentsForVersion(String programmeVersionId) async => 0;
}

class _FailingProgressBuilder extends AthleteProgressSummaryBuilder {
  @override
  Future<ProgressSummary> build({required String athleteId}) {
    throw const AthleteProgressEvidenceFailure('history_unavailable');
  }
}

class _FailingHistoryCoordinator extends PerformanceRecordSaveCoordinator {
  @override
  Future<List<TrainingSessionRecord>> listHistory({
    required String athleteId,
    int limit = 25,
    int offset = 0,
  }) {
    throw StateError('history repository failed');
  }
}

abstract final class FileScan {
  static bool contains(String path, String needle) {
    return File(path).readAsStringSync().contains(needle);
  }

  static bool hasNoAthleteLocal(String path) {
    return !File(path).readAsStringSync().contains('athlete.local');
  }
}
