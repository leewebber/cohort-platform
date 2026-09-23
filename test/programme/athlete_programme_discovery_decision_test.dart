import 'package:cohort_platform/features/programme/controllers/athlete_programme_controllers.dart';
import 'package:cohort_platform/features/programme/models/athlete_catalogue_enrolment.dart';
import 'package:cohort_platform/features/programme/presentation/athlete_programme_decision_copy.dart';
import 'package:cohort_platform/features/programme/presentation/athlete_programme_decision_facts.dart';
import 'package:cohort_platform/features/programme/presentation/programme_discovery_decision_preview_catalog.dart';
import 'package:cohort_platform/main_programme_discovery_decision_preview.dart';
import 'package:cohort_platform/features/programme/screens/athlete_programme_comparison_screen.dart';
import 'package:cohort_platform/features/programme/screens/athlete_programme_detail_screen.dart';
import 'package:cohort_platform/features/programme/screens/athlete_programme_enrolment_review_screen.dart';
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

ProgrammeCatalogEntry _entry(
  String id, {
  String name = 'Prog',
  String? goal = 'Strength',
  String? description = 'Founder programme',
  int? durationWeeks = 8,
  int? sessionsPerWeek = 3,
  String? difficulty = 'Intermediate',
  String? equipment,
  ProgrammeLifecycleStatus lifecycle = ProgrammeLifecycleStatus.published,
  bool approved = true,
  DateTime? archivedAt,
  bool blocking = false,
}) {
  return ProgrammeCatalogEntry(
    versionId: id,
    lineageCode: 'L-$id',
    versionNumber: 1,
    name: name,
    lifecycleStatus: lifecycle,
    libraryScope: ProgrammeLibraryScope.cohortGlobal,
    ownerType: ProgrammeOwnerType.global,
    approvedForGlobal: approved,
    primaryGoal: goal,
    description: description,
    durationWeeks: durationWeeks,
    sessionsPerWeek: sessionsPerWeek,
    difficulty: difficulty,
    equipmentRequirements: equipment,
    archivedAt: archivedAt,
    hasBlockingValidationErrors: blocking,
  );
}

AthleteProgrammeSelectionController _controller({
  required List<ProgrammeCatalogEntry> entries,
  _RecordingEnrolmentStore? store,
  InMemoryProgrammeTables? tables,
}) {
  return AthleteProgrammeSelectionController(
    athleteId: 'lee',
    catalogService: AthleteProgrammeSwitchCatalogService(
      catalogService: _Catalog(entries),
    ),
    enrolmentService: AthleteCatalogueEnrolmentService(
      enrolmentStore:
          store ??
          _RecordingEnrolmentStore(
            const AthleteCatalogueEnrolmentResult(
              status: AthleteCatalogueEnrolmentStatus.enrolled,
              enrolmentId: 'e1',
              programmeVersionId: 'v-apollo',
              athleteId: 'lee',
              enrolmentSource: EnrolmentSource.nonCommercialTest,
            ),
          ),
    ),
    assignmentStore: tables == null
        ? null
        : InMemoryProgrammeAssignmentStore(tables),
  );
}

Future<void> _pumpSelection(
  WidgetTester tester,
  AthleteProgrammeSelectionController controller,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AthleteProgrammeSelectionScreen(
        athleteId: 'lee',
        controller: controller,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('facts use authored fields and do not guess omitted ones', () {
    final facts = AthleteProgrammeDecisionFacts.fromEntry(
      _entry(
        'v1',
        name: 'Apollo',
        equipment: null,
        description: null,
        difficulty: null,
      ),
      isCurrentProgramme: false,
    );
    expect(facts.title, 'Apollo');
    expect(facts.goalLabel, 'Strength');
    expect(facts.equipmentLabel, AthleteProgrammeDecisionCopy.notProvided);
    expect(facts.summaryLabel, AthleteProgrammeDecisionCopy.notProvided);
    expect(facts.levelLabel, AthleteProgrammeDecisionCopy.notProvided);
    expect(facts.emphasisLabel, AthleteProgrammeDecisionCopy.notProvided);
    expect(facts.formatsLabel, AthleteProgrammeDecisionCopy.notProvided);
    expect(facts.hasSupportingInformation, isFalse);
    expect(facts.trainingEmphasis, isNull);
    expect(facts.versionId, 'v1');
  });

  test('catalogue service hides unpublished and invalid entries', () async {
    final catalog = AthleteProgrammeSwitchCatalogService(
      catalogService: _Catalog([
        _entry('pub', name: 'Published'),
        _entry('draft', lifecycle: ProgrammeLifecycleStatus.draft),
        _entry('unapproved', approved: false),
        _entry('archived', archivedAt: DateTime.utc(2026, 1, 1)),
        _entry('blocked', blocking: true),
      ]),
    );
    final listed = await catalog.listPublishedAssignableProgrammes();
    expect(listed.map((e) => e.versionId), ['pub']);
  });

  testWidgets('discovery reaches detail and hides testing copy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controller(
      entries: [_entry('v-apollo', name: 'Apollo')],
    );
    await _pumpSelection(tester, controller);

    expect(find.text('Choose programme'), findsOneWidget);
    expect(find.text('View details'), findsOneWidget);
    expect(find.textContaining('testing'), findsNothing);
    expect(find.textContaining('not a purchase'), findsNothing);

    await tester.ensureVisible(find.text('View details'));
    await tester.tap(find.text('View details'));
    await tester.pumpAndSettle();
    expect(find.byType(AthleteProgrammeDetailScreen), findsOneWidget);
    expect(find.text('Apollo'), findsOneWidget);
    expect(find.text('Training emphasis'), findsNothing);
    expect(find.text(AthleteProgrammeDecisionCopy.notProvided), findsNothing);
    await tester.ensureVisible(find.text('Enrol'));
    expect(find.text('Enrol'), findsOneWidget);
  });

  testWidgets('exactly two comparison candidates with aligned facts', (
    tester,
  ) async {
    final controller = _controller(
      entries: [
        _entry('v-apollo', name: 'Apollo', durationWeeks: 12),
        _entry('v-spartan', name: 'Spartan', durationWeeks: 8, goal: 'Hybrid'),
      ],
    );
    await _pumpSelection(tester, controller);
    controller.toggleCompare(controller.programmes.first);
    controller.toggleCompare(controller.programmes.last);
    await tester.pumpAndSettle();
    expect(controller.comparisonVersionIds, ['v-apollo', 'v-spartan']);

    await tester.tap(find.text('Compare selected'));
    await tester.pumpAndSettle();
    expect(find.byType(AthleteProgrammeComparisonScreen), findsOneWidget);
    expect(find.text('Duration'), findsOneWidget);
    expect(find.text('12 weeks'), findsOneWidget);
    expect(find.text('8 weeks'), findsOneWidget);
    expect(find.text('Training emphasis'), findsNothing);
    expect(find.text(AthleteProgrammeDecisionCopy.notProvided), findsNothing);
  });

  testWidgets('comparison stacks on a 320px viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _controller(
      entries: [
        _entry('v-apollo', name: 'Apollo'),
        _entry('v-spartan', name: 'Spartan'),
      ],
    );
    await controller.load();
    controller.toggleCompare(controller.programmes.first);
    controller.toggleCompare(controller.programmes.last);

    await tester.pumpWidget(
      MaterialApp(
        home: AthleteProgrammeComparisonScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Apollo'), findsWidgets);
    expect(find.text('Spartan'), findsWidgets);
    expect(find.textContaining('Apollo:'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('optional supporting section is omitted when unauthored', (
    tester,
  ) async {
    final controller = _controller(
      entries: [_entry('v-apollo', name: 'Apollo')],
    );
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        home: AthleteProgrammeDetailScreen(
          controller: controller,
          versionId: 'v-apollo',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('At a glance'), findsOneWidget);
    expect(find.text('Training emphasis'), findsNothing);
    expect(find.text('Session formats'), findsNothing);
    expect(find.text('Progression'), findsNothing);
    expect(find.text('Recovery'), findsNothing);
    expect(find.text(AthleteProgrammeDecisionCopy.notProvided), findsNothing);
  });

  testWidgets('detail has one programme title below the app bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final tables = InMemoryProgrammeTables()
      ..assignments.add(
        ProgrammeScheduleTestFixtures.assignment(
          programmeVersionId: 'v-apollo',
        ),
      );
    final controller = _controller(
      entries: [
        _entry('v-apollo', name: 'Apollo'),
        _entry('v-spartan', name: 'Spartan'),
      ],
      tables: tables,
    );
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(
        home: AthleteProgrammeDetailScreen(
          controller: controller,
          versionId: 'v-apollo',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Apollo'), findsOneWidget);
    expect(
      find.text(AthleteProgrammeDecisionCopy.currentProgramme),
      findsOneWidget,
    );
    expect(find.text(AthleteProgrammeDecisionCopy.enrol), findsNothing);

    final detail = find.byType(AthleteProgrammeDetailScreen);
    final appBar = find.descendant(of: detail, matching: find.byType(AppBar));
    final title = find.descendant(of: detail, matching: find.text('Apollo'));
    expect(
      tester.getTopLeft(title).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(appBar).dy - 0.5),
    );
  });

  testWidgets('Spartan title stays below the app bar at large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _controller(
      entries: [_entry('v-spartan', name: 'Spartan')],
    );
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          );
        },
        home: AthleteProgrammeDetailScreen(
          controller: controller,
          versionId: 'v-spartan',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Spartan'), findsOneWidget);
    final detail = find.byType(AthleteProgrammeDetailScreen);
    final appBar = find.descendant(of: detail, matching: find.byType(AppBar));
    final title = find.descendant(of: detail, matching: find.text('Spartan'));
    expect(
      tester.getTopLeft(title).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(appBar).dy - 0.5),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('one-sided missing comparison data stays labelled', (
    tester,
  ) async {
    final controller = _controller(
      entries: [
        _entry('v-apollo', name: 'Apollo', equipment: 'Barbell'),
        _entry('v-spartan', name: 'Spartan', equipment: null),
      ],
    );
    await controller.load();
    controller.toggleCompare(controller.programmes.first);
    controller.toggleCompare(controller.programmes.last);
    await tester.pumpWidget(
      MaterialApp(
        home: AthleteProgrammeComparisonScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Equipment'), findsOneWidget);
    expect(find.text('Barbell'), findsOneWidget);
    expect(
      find.text(AthleteProgrammeDecisionCopy.notSpecified),
      findsOneWidget,
    );
    expect(find.text(AthleteProgrammeDecisionCopy.notProvided), findsNothing);
  });

  testWidgets('comparison identity stays visible while scrolling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _controller(
      entries: [
        _entry('v-apollo', name: 'Apollo'),
        _entry('v-spartan', name: 'Spartan'),
      ],
    );
    await controller.load();
    controller.toggleCompare(controller.programmes.first);
    controller.toggleCompare(controller.programmes.last);
    await tester.pumpWidget(
      MaterialApp(
        home: AthleteProgrammeComparisonScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('Apollo'), findsWidgets);
    expect(find.text('Spartan'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test('active athlete confirmEnrol does not call RPC or replace', () async {
    final store = _RecordingEnrolmentStore(
      const AthleteCatalogueEnrolmentResult(
        status: AthleteCatalogueEnrolmentStatus.enrolled,
        programmeVersionId: 'v-spartan',
        athleteId: 'lee',
      ),
    );
    final tables = InMemoryProgrammeTables()
      ..assignments.add(
        ProgrammeScheduleTestFixtures.assignment(
          programmeVersionId: 'v-apollo',
        ),
      );
    final controller = _controller(
      entries: [
        _entry('v-apollo', name: 'Apollo'),
        _entry('v-spartan', name: 'Spartan'),
      ],
      store: store,
      tables: tables,
    );
    await controller.load();
    controller.selectProgramme(controller.programmes.last);
    final result = await controller.confirmEnrol(
      startedAt: DateTime.utc(2026, 9, 22),
      timezone: 'UTC',
      replaceActive: true,
    );
    expect(store.calls, 0);
    expect(result?.status, AthleteCatalogueEnrolmentStatus.conflict);
    expect(result?.message, AthleteProgrammeDecisionCopy.switchingUnavailable);
    expect(controller.activeVersionId, 'v-apollo');
  });

  test(
    'no-programme enrol uses existing RPC only and ignores replace',
    () async {
      final store = _RecordingEnrolmentStore(
        const AthleteCatalogueEnrolmentResult(
          status: AthleteCatalogueEnrolmentStatus.enrolled,
          enrolmentId: 'e-new',
          programmeVersionId: 'v-apollo',
          athleteId: 'lee',
          enrolmentSource: EnrolmentSource.nonCommercialTest,
        ),
      );
      final controller = _controller(
        entries: [_entry('v-apollo', name: 'Apollo')],
        store: store,
      );
      await controller.load();
      controller.selectProgramme(controller.programmes.first);
      final first = controller.confirmEnrol(
        startedAt: DateTime.utc(2026, 9, 22),
        timezone: 'UTC',
        replaceActive: true,
      );
      final second = await controller.confirmEnrol(
        startedAt: DateTime.utc(2026, 9, 22),
        timezone: 'UTC',
      );
      final firstResult = await first;
      expect(second, isNull);
      expect(firstResult?.isSuccess, isTrue);
      expect(store.calls, 1);
      expect(store.lastVersionId, 'v-apollo');
      expect(store.lastReplace, isFalse);
      expect(controller.activeVersionId, 'v-apollo');
    },
  );

  testWidgets('active athlete detail has no enrol CTA', (tester) async {
    final tables = InMemoryProgrammeTables()
      ..assignments.add(
        ProgrammeScheduleTestFixtures.assignment(
          programmeVersionId: 'v-apollo',
        ),
      );
    final controller = _controller(
      entries: [
        _entry('v-apollo', name: 'Apollo'),
        _entry('v-spartan', name: 'Spartan'),
      ],
      tables: tables,
    );
    await controller.load();
    expect(controller.hasActiveAssignment, isTrue);
    expect(controller.entryByVersionId('v-spartan'), isNotNull);
    await tester.pumpWidget(
      MaterialApp(
        home: AthleteProgrammeDetailScreen(
          controller: controller,
          versionId: 'v-spartan',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(AthleteProgrammeDecisionCopy.switchingUnavailable),
      findsOneWidget,
    );
    expect(find.text(AthleteProgrammeDecisionCopy.enrol), findsNothing);
  });

  testWidgets('enrolment review does not mutate before confirm', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = _RecordingEnrolmentStore(
      const AthleteCatalogueEnrolmentResult(
        status: AthleteCatalogueEnrolmentStatus.failed,
        message: 'Hosted enrolment is unavailable.',
      ),
    );
    final controller = _controller(
      entries: [_entry('v-apollo', name: 'Apollo')],
      store: store,
    );
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        home: AthleteProgrammeEnrolmentReviewScreen(
          controller: controller,
          versionId: 'v-apollo',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(store.calls, 0);
    expect(find.textContaining('Apollo'), findsWidgets);
    expect(
      find.text(AthleteProgrammeDecisionCopy.enrolConfirm),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.text(AthleteProgrammeDecisionCopy.enrolConfirm),
    );
    await tester.tap(find.text(AthleteProgrammeDecisionCopy.enrolConfirm));
    await tester.pumpAndSettle();
    expect(store.calls, 1);
    expect(find.text('Hosted enrolment is unavailable.'), findsWidgets);
    expect(find.text(AthleteProgrammeDecisionCopy.retry), findsOneWidget);
  });

  testWidgets('enrolment review uses one version-commitment statement', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _controller(
      entries: [_entry('v-apollo', name: 'Apollo')],
    );
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        home: AthleteProgrammeEnrolmentReviewScreen(
          controller: controller,
          versionId: 'v-apollo',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Apollo becomes your current programme. Your training stays '
        'pinned to this exact programme version.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Later sessions stay'), findsNothing);
    expect(find.textContaining('You are choosing'), findsNothing);
    expect(
      find.textContaining('It becomes your current programme'),
      findsNothing,
    );
    expect(find.text('Goal'), findsOneWidget);
    expect(find.text('Duration'), findsOneWidget);
    expect(find.text('Sessions per week'), findsOneWidget);
    expect(find.text('Intended level'), findsOneWidget);
    expect(
      find.text(AthleteProgrammeDecisionCopy.enrolConfirm),
      findsOneWidget,
    );
    expect(find.text(AthleteProgrammeDecisionCopy.cancel), findsOneWidget);
  });

  testWidgets('preview enrolment review cannot perform a real enrolment', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProgrammeDiscoveryDecisionPreviewApp(
        initialState: ProgrammeDiscoveryDecisionPreviewState.enrolmentReview,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(AthleteProgrammeDecisionCopy.enrolConfirm),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.text(AthleteProgrammeDecisionCopy.enrolConfirm),
    );
    await tester.tap(find.text(AthleteProgrammeDecisionCopy.enrolConfirm));
    await tester.pumpAndSettle();
    expect(find.text('Preview does not enrol.'), findsWidgets);
    expect(find.text(AthleteProgrammeDecisionCopy.enrolSuccess), findsNothing);
    expect(find.text(AthleteProgrammeDecisionCopy.retry), findsOneWidget);
  });

  testWidgets('error is not an empty catalogue', (tester) async {
    final controller = AthleteProgrammeSelectionController(
      athleteId: 'lee',
      catalogService: AthleteProgrammeSwitchCatalogService(
        catalogService: _FailingCatalog(),
      ),
      enrolmentService: AthleteCatalogueEnrolmentService(
        enrolmentStore: _RecordingEnrolmentStore(
          const AthleteCatalogueEnrolmentResult(
            status: AthleteCatalogueEnrolmentStatus.failed,
          ),
        ),
      ),
    );
    await _pumpSelection(tester, controller);
    expect(
      find.text(AthleteProgrammeDecisionCopy.catalogueUnavailable),
      findsOneWidget,
    );
    expect(
      find.text(AthleteProgrammeDecisionCopy.catalogueEmpty),
      findsNothing,
    );
  });
}

class _FailingCatalog implements ProgrammeCatalogService {
  @override
  Future<ProgrammeCatalogEntry?> getEntry({
    required String lineageCode,
    required int versionNumber,
  }) async => throw StateError('catalogue down');

  @override
  Future<List<ProgrammeCatalogEntry>> listCatalogue({
    required ProgrammeCatalogueQuery query,
    ProgrammeLifecycleStatus? lifecycleStatus,
  }) async => throw StateError('catalogue down');
}
