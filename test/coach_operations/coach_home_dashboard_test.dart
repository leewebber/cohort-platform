import 'package:cohort_platform/features/auth/models/user_profile.dart';
import 'package:cohort_platform/features/auth/services/current_user_session.dart';
import 'package:cohort_platform/features/coach_athlete/models/coach_athlete_roster_entry.dart';
import 'package:cohort_platform/features/coach_athlete/services/coach_athlete_service.dart';
import 'package:cohort_platform/features/coach_operations/controllers/coach_home_dashboard_controller.dart';
import 'package:cohort_platform/features/coach_operations/models/coach_athlete_daily_snapshot.dart';
import 'package:cohort_platform/features/coach_operations/screens/coach_home_dashboard_screen.dart';
import 'package:cohort_platform/features/coach_operations/services/coach_athlete_daily_status_service.dart';
import 'package:cohort_platform/features/coach_operations/widgets/coach_athlete_operational_card.dart';
import 'package:cohort_platform/features/programme/models/resolved_today_session.dart';
import 'package:cohort_platform/features/programme/services/programme_schedule_resolver_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_coach_athlete_stores.dart';
import '../support/in_memory_profile_repository.dart';
import '../support/in_memory_programme_stores.dart';

class _FakeDailyStatusService extends CoachAthleteDailyStatusService {
  _FakeDailyStatusService(this._snapshots)
      : super(
          coachAthleteService: CoachAthleteService(
            relationshipRepository: InMemoryCoachAthleteRelationshipRepository(
              InMemoryCoachAthleteTables(),
            ),
            inviteRepository: InMemoryCoachAthleteInviteRepository(
              InMemoryCoachAthleteTables(),
            ),
            profileRepository: InMemoryProfileRepository(),
          ),
          assignmentStore: InMemoryProgrammeAssignmentStore(
            InMemoryProgrammeTables(),
          ),
          versionStore: InMemoryProgrammeVersionStore(
            InMemoryProgrammeTables(),
          ),
          slotOutcomeStore: InMemoryProgrammeSlotOutcomeStore(
            InMemoryProgrammeTables(),
          ),
          scheduleResolver: const ProgrammeScheduleResolverImpl(),
        );

  final List<CoachAthleteDailySnapshot> _snapshots;

  @override
  Future<List<CoachAthleteDailySnapshot>> loadDashboardSnapshots() async {
    return _snapshots;
  }
}

CoachAthleteRosterEntry _rosterEntry({
  required String athleteId,
  required String name,
}) {
  return CoachAthleteRosterEntry(
    athleteId: athleteId,
    displayName: name,
    relationshipId: 'relationship-$athleteId',
    activeProgrammeName: 'Foundation',
    activeProgrammeVersionLabel: 'Version 1',
    hasActiveAssignment: true,
  );
}

CoachAthleteDailySnapshot _snapshot({
  required String athleteId,
  required String name,
  required CoachAthleteTodayStatus status,
  required String complianceLabel,
  bool needsAttention = false,
  int sessionsBehind = 0,
}) {
  return CoachAthleteDailySnapshot(
    rosterEntry: _rosterEntry(athleteId: athleteId, name: name),
    todayStatus: status,
    complianceLabel: complianceLabel,
    sessionsBehind: sessionsBehind,
    needsAttention: needsAttention,
    programmeName: 'Foundation Programme',
    weekDayLabel: 'Week 1 • Day 1',
    progressLabel: 'Week 1 of 2 • 1 / 4 sessions completed',
    lastActivityLabel: 'Yesterday',
    resolution: const ResolvedTodaySession(
      kind: ResolvedTodaySessionKind.executable,
      weekNumber: 1,
      dayKey: 'day_1',
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(CurrentUserSession.clear);

  group('CoachAthleteDailySnapshot filters', () {
    final snapshots = [
      _snapshot(
        athleteId: 'a1',
        name: 'Alex',
        status: CoachAthleteTodayStatus.trainingToday,
        complianceLabel: 'On Track',
      ),
      _snapshot(
        athleteId: 'a2',
        name: 'Sam',
        status: CoachAthleteTodayStatus.behindSchedule,
        complianceLabel: '2 Sessions Behind',
        needsAttention: true,
        sessionsBehind: 2,
      ),
      _snapshot(
        athleteId: 'a3',
        name: 'Jordan',
        status: CoachAthleteTodayStatus.completedToday,
        complianceLabel: 'Completed Today',
      ),
      _snapshot(
        athleteId: 'a4',
        name: 'Taylor',
        status: CoachAthleteTodayStatus.noActiveProgramme,
        complianceLabel: 'No Programme',
        needsAttention: true,
      ),
    ];

    test('needs attention filter', () {
      expect(
        snapshots
            .where((s) => s.matchesFilter(CoachDashboardFilter.needsAttention))
            .length,
        2,
      );
    });

    test('training today filter', () {
      expect(
        snapshots
            .where((s) => s.matchesFilter(CoachDashboardFilter.trainingToday))
            .length,
        1,
      );
    });

    test('completed today filter', () {
      expect(
        snapshots
            .where((s) => s.matchesFilter(CoachDashboardFilter.completedToday))
            .length,
        1,
      );
    });

    test('no programme filter', () {
      expect(
        snapshots
            .where((s) => s.matchesFilter(CoachDashboardFilter.noProgramme))
            .length,
        1,
      );
    });
  });

  group('CoachHomeDashboardController', () {
    test('loads snapshots and applies filters', () async {
      final controller = CoachHomeDashboardController(
        dailyStatusService: _FakeDailyStatusService([
          _snapshot(
            athleteId: 'a1',
            name: 'Alex',
            status: CoachAthleteTodayStatus.trainingToday,
            complianceLabel: 'On Track',
          ),
          _snapshot(
            athleteId: 'a2',
            name: 'Sam',
            status: CoachAthleteTodayStatus.behindSchedule,
            complianceLabel: '1 Session Behind',
            needsAttention: true,
            sessionsBehind: 1,
          ),
        ]),
      );

      await controller.load();

      expect(controller.status, CoachHomeDashboardStatus.ready);
      expect(controller.snapshots.length, 2);

      controller.setFilter(CoachDashboardFilter.needsAttention);
      expect(controller.filteredSnapshots.length, 1);
      expect(controller.filteredSnapshots.first.displayName, 'Sam');
    });

    test('empty roster shows empty status', () async {
      final controller = CoachHomeDashboardController(
        dailyStatusService: _FakeDailyStatusService(const []),
      );

      await controller.load();

      expect(controller.status, CoachHomeDashboardStatus.empty);
    });

    test('coach role required maps to dedicated status', () async {
      final profileRepository = InMemoryProfileRepository();
      profileRepository.profiles['athlete-only'] = const UserProfile(
        id: 'athlete-only',
        displayName: 'Alex',
        isCoach: false,
        isAthlete: true,
      );
      CurrentUserSession.bind(profileRepository.profiles['athlete-only']!);

      final service = CoachAthleteDailyStatusService(
        coachAthleteService: CoachAthleteService(
          relationshipRepository: InMemoryCoachAthleteRelationshipRepository(
            InMemoryCoachAthleteTables(),
          ),
          inviteRepository: InMemoryCoachAthleteInviteRepository(
            InMemoryCoachAthleteTables(),
          ),
          profileRepository: profileRepository,
        ),
        assignmentStore: InMemoryProgrammeAssignmentStore(
          InMemoryProgrammeTables(),
        ),
        versionStore: InMemoryProgrammeVersionStore(
          InMemoryProgrammeTables(),
        ),
        slotOutcomeStore: InMemoryProgrammeSlotOutcomeStore(
          InMemoryProgrammeTables(),
        ),
        scheduleResolver: const ProgrammeScheduleResolverImpl(),
      );

      final controller = CoachHomeDashboardController(
        dailyStatusService: service,
      );
      await controller.load();

      expect(controller.status, CoachHomeDashboardStatus.coachRoleRequired);
    });
  });

  group('CoachHomeDashboardScreen', () {
    testWidgets('renders athlete cards and filter chips', (tester) async {
      final controller = CoachHomeDashboardController(
        dailyStatusService: _FakeDailyStatusService([
          _snapshot(
            athleteId: 'a1',
            name: 'Alex',
            status: CoachAthleteTodayStatus.trainingToday,
            complianceLabel: 'On Track',
          ),
        ]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CoachHomeDashboardScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Athletes'), findsOneWidget);
      expect(find.text('Alex'), findsOneWidget);
      expect(find.text('On Track'), findsOneWidget);
      expect(find.text('Training today'), findsOneWidget);
      expect(find.byType(CoachAthleteOperationalCard), findsOneWidget);
      expect(find.text('Needs Attention'), findsOneWidget);
    });

    testWidgets('shows empty filter message', (tester) async {
      final controller = CoachHomeDashboardController(
        dailyStatusService: _FakeDailyStatusService([
          _snapshot(
            athleteId: 'a1',
            name: 'Alex',
            status: CoachAthleteTodayStatus.trainingToday,
            complianceLabel: 'On Track',
          ),
        ]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CoachHomeDashboardScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      controller.setFilter(CoachDashboardFilter.noProgramme);
      await tester.pumpAndSettle();

      expect(find.textContaining('No athletes match'), findsOneWidget);
    });

    testWidgets('shows empty roster message', (tester) async {
      final controller = CoachHomeDashboardController(
        dailyStatusService: _FakeDailyStatusService(const []),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CoachHomeDashboardScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'No athletes linked yet. Invite an athlete to start coaching.',
        ),
        findsOneWidget,
      );
    });
  });
}
