import 'package:cohort_platform/features/programme/controllers/athlete_programme_controllers.dart';
import 'package:cohort_platform/features/programme/models/athlete_catalogue_enrolment.dart';
import 'package:cohort_platform/features/programme/models/programme_catalog_entry.dart';
import 'package:cohort_platform/features/programme/screens/athlete_programme_selection_screen.dart';
import 'package:cohort_platform/features/programme/services/athlete_catalogue_enrolment_service.dart';
import 'package:cohort_platform/features/programme/services/athlete_catalogue_enrolment_store.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_switch_catalog_service.dart';
import 'package:cohort_platform/features/programme/services/programme_catalog_service.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_programme_stores.dart';
import '../support/programme_schedule_test_fixtures.dart';

class _RecordingEnrolmentStore implements AthleteCatalogueEnrolmentStore {
  _RecordingEnrolmentStore(this.result);

  AthleteCatalogueEnrolmentResult result;
  int calls = 0;
  String? lastVersionId;
  bool? lastReplace;

  @override
  Future<AthleteCatalogueEnrolmentResult> enrol({
    required String programmeVersionId,
    String? timezone,
    bool replaceActive = false,
  }) async {
    calls++;
    lastVersionId = programmeVersionId;
    lastReplace = replaceActive;
    return result;
  }
}

class _Catalog implements ProgrammeCatalogService {
  _Catalog(this.entries);
  final List<ProgrammeCatalogEntry> entries;

  @override
  Future<ProgrammeCatalogEntry?> getEntry({
    required String lineageCode,
    required int versionNumber,
  }) async => null;

  @override
  Future<List<ProgrammeCatalogEntry>> listCatalogue({
    required ProgrammeCatalogueQuery query,
    ProgrammeLifecycleStatus? lifecycleStatus,
  }) async => entries;
}

ProgrammeCatalogEntry _entry(String id, {String name = 'Prog'}) {
  return ProgrammeCatalogEntry(
    versionId: id,
    lineageCode: 'L-$id',
    versionNumber: 1,
    name: name,
    lifecycleStatus: ProgrammeLifecycleStatus.published,
    libraryScope: ProgrammeLibraryScope.cohortGlobal,
    ownerType: ProgrammeOwnerType.global,
    approvedForGlobal: true,
    primaryGoal: 'Strength',
    description: 'Founder programme',
    durationWeeks: 8,
    sessionsPerWeek: 3,
  );
}

void main() {
  group('AthleteCatalogueEnrolmentResult', () {
    test('parses enrolled and preserves exact version id', () {
      final result = AthleteCatalogueEnrolmentResult.fromRpcMap({
        'status': 'enrolled',
        'enrolment_id': 'e1',
        'programme_version_id': 'v-exact',
        'lineage_code': 'PROG-A',
        'enrolment_source': 'non_commercial_test',
        'athlete_id': 'a1',
      });

      expect(result.status, AthleteCatalogueEnrolmentStatus.enrolled);
      expect(result.isSuccess, isTrue);
      expect(result.programmeVersionId, 'v-exact');
      expect(result.enrolmentSource, EnrolmentSource.nonCommercialTest);
      expect(result.message, isNull);
    });

    test('already_enrolled is idempotent success', () {
      final result = AthleteCatalogueEnrolmentResult.fromRpcMap({
        'status': 'already_enrolled',
        'enrolment_id': 'e1',
        'programme_version_id': 'v1',
        'enrolment_source': 'non_commercial_test',
        'athlete_id': 'a1',
      });
      expect(result.isIdempotentAlreadyEnrolled, isTrue);
      expect(result.isSuccess, isTrue);
    });

    test('does not map enrolment to purchase semantics', () {
      final result = AthleteCatalogueEnrolmentResult.fromRpcMap({
        'status': 'enrolled',
        'enrolment_id': 'e1',
        'programme_version_id': 'v1',
        'enrolment_source': 'non_commercial_test',
        'athlete_id': 'a1',
      });
      final handoff = AthletePlanMaterialisationHandoff.fromEnrolmentResult(
        result,
      );
      expect(handoff.toMap()['binds_exact_version'], isTrue);
      expect(handoff.toMap()['commercial_entitlement'], isNull);
      expect(handoff.programmeVersionId, 'v1');
    });

    test('authorization failure for ineligible version', () {
      final result = AthleteCatalogueEnrolmentResult.fromRpcMap({
        'status': 'authorization_failure',
        'code': 'version_not_catalogue_eligible',
      });
      expect(
        result.status,
        AthleteCatalogueEnrolmentStatus.authorizationFailure,
      );
      expect(result.message, contains('not available'));
    });
  });

  group('AthleteCatalogueEnrolmentService', () {
    test(
      'enrol passes exact version and reconcile on ambiguous failure',
      () async {
        final tables = InMemoryProgrammeTables()
          ..assignments.add(
            ProgrammeScheduleTestFixtures.assignment(
              id: 'e-active',
              programmeVersionId: 'v-exact',
            ).copyWith(enrolmentSource: 'non_commercial_test'),
          );
        final store = _RecordingEnrolmentStore(
          const AthleteCatalogueEnrolmentResult(
            status: AthleteCatalogueEnrolmentStatus.failed,
            message: 'network',
          ),
        );
        final service = AthleteCatalogueEnrolmentService(
          enrolmentStore: store,
          assignmentStore: InMemoryProgrammeAssignmentStore(tables),
        );

        final result = await service.enrol(
          athleteId: 'lee',
          programmeVersionId: 'v-exact',
          timezone: 'UTC',
        );

        expect(store.calls, 1);
        expect(store.lastVersionId, 'v-exact');
        expect(result.status, AthleteCatalogueEnrolmentStatus.alreadyEnrolled);
        expect(result.programmeVersionId, 'v-exact');
      },
    );

    test('no version substitution on success', () async {
      final store = _RecordingEnrolmentStore(
        const AthleteCatalogueEnrolmentResult(
          status: AthleteCatalogueEnrolmentStatus.enrolled,
          enrolmentId: 'e1',
          programmeVersionId: 'requested-version',
          athleteId: 'lee',
          enrolmentSource: EnrolmentSource.nonCommercialTest,
        ),
      );
      final service = AthleteCatalogueEnrolmentService(enrolmentStore: store);

      final result = await service.enrol(
        athleteId: 'lee',
        programmeVersionId: 'requested-version',
      );

      expect(result.programmeVersionId, 'requested-version');
      expect(store.lastVersionId, 'requested-version');
    });
  });

  group('AthleteProgrammeSelectionController enrolment', () {
    test('duplicate submit while in progress is ignored', () async {
      final store = _RecordingEnrolmentStore(
        const AthleteCatalogueEnrolmentResult(
          status: AthleteCatalogueEnrolmentStatus.enrolled,
          enrolmentId: 'e1',
          programmeVersionId: 'v2',
          athleteId: 'lee',
          enrolmentSource: EnrolmentSource.nonCommercialTest,
        ),
      );
      final controller = AthleteProgrammeSelectionController(
        athleteId: 'lee',
        catalogService: AthleteProgrammeSwitchCatalogService(
          catalogService: _Catalog([_entry('v1'), _entry('v2')]),
        ),
        enrolmentService: AthleteCatalogueEnrolmentService(
          enrolmentStore: store,
        ),
      );
      await controller.load();
      controller.selectProgramme(controller.programmes.last);

      final first = controller.confirmEnrol(
        startedAt: DateTime.utc(2026, 8, 1),
        timezone: 'UTC',
      );
      final second = await controller.confirmEnrol(
        startedAt: DateTime.utc(2026, 8, 1),
        timezone: 'UTC',
      );
      final firstResult = await first;

      expect(second, isNull);
      expect(firstResult?.isSuccess, isTrue);
      expect(store.calls, 1);
    });

    test('already enrolled short-circuits without RPC', () async {
      final store = _RecordingEnrolmentStore(
        const AthleteCatalogueEnrolmentResult(
          status: AthleteCatalogueEnrolmentStatus.enrolled,
          enrolmentId: 'e1',
          programmeVersionId: 'v1',
          athleteId: 'lee',
        ),
      );
      final tables = InMemoryProgrammeTables()
        ..assignments.add(
          ProgrammeScheduleTestFixtures.assignment(programmeVersionId: 'v1'),
        );
      final controller = AthleteProgrammeSelectionController(
        athleteId: 'lee',
        catalogService: AthleteProgrammeSwitchCatalogService(
          catalogService: _Catalog([_entry('v1')]),
        ),
        enrolmentService: AthleteCatalogueEnrolmentService(
          enrolmentStore: store,
        ),
        assignmentStore: InMemoryProgrammeAssignmentStore(tables),
      );
      await controller.load();
      controller.selectProgramme(controller.programmes.first);

      final result = await controller.confirmEnrol(
        startedAt: DateTime.utc(2026, 8, 1),
        timezone: 'UTC',
      );

      expect(result?.isIdempotentAlreadyEnrolled, isTrue);
      expect(store.calls, 0);
    });
  });

  group('AthleteProgrammeSelectionScreen widget', () {
    testWidgets('renders catalogue and enrol language without purchase terms', (
      tester,
    ) async {
      final controller = AthleteProgrammeSelectionController(
        athleteId: 'lee',
        catalogService: AthleteProgrammeSwitchCatalogService(
          catalogService: _Catalog([_entry('v1', name: 'Cohort Strength')]),
        ),
        enrolmentService: AthleteCatalogueEnrolmentService(
          enrolmentStore: _RecordingEnrolmentStore(
            const AthleteCatalogueEnrolmentResult(
              status: AthleteCatalogueEnrolmentStatus.enrolled,
              enrolmentId: 'e1',
              programmeVersionId: 'v1',
              athleteId: 'lee',
              enrolmentSource: EnrolmentSource.nonCommercialTest,
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AthleteProgrammeSelectionScreen(
            athleteId: 'lee',
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Choose programme'), findsOneWidget);
      expect(find.text('Cohort Strength'), findsOneWidget);
      expect(find.textContaining('Buy'), findsNothing);
      expect(find.textContaining('Purchase'), findsNothing);
      expect(find.textContaining('Checkout'), findsNothing);
      expect(find.textContaining(r'$'), findsNothing);

      await tester.tap(find.text('Cohort Strength'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Enrol in'), findsOneWidget);
      expect(find.text('Enrol'), findsOneWidget);
      expect(find.textContaining('not a purchase'), findsOneWidget);
    });

    testWidgets('empty catalogue state', (tester) async {
      final controller = AthleteProgrammeSelectionController(
        athleteId: 'lee',
        catalogService: AthleteProgrammeSwitchCatalogService(
          catalogService: _Catalog(const []),
        ),
        enrolmentService: AthleteCatalogueEnrolmentService(
          enrolmentStore: _RecordingEnrolmentStore(
            const AthleteCatalogueEnrolmentResult(
              status: AthleteCatalogueEnrolmentStatus.failed,
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AthleteProgrammeSelectionScreen(
            athleteId: 'lee',
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('No programmes are available'),
        findsOneWidget,
      );
    });
  });
}
