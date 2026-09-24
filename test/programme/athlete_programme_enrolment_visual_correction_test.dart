import 'package:cohort_platform/features/programme/controllers/athlete_programme_controllers.dart';
import 'package:cohort_platform/features/programme/domain/athlete_programme_continuity.dart';
import 'package:cohort_platform/features/programme/domain/enrolment_timezone_capture.dart';
import 'package:cohort_platform/features/programme/models/athlete_catalogue_enrolment.dart';
import 'package:cohort_platform/features/programme/presentation/athlete_programme_continuity_copy.dart';
import 'package:cohort_platform/features/programme/presentation/athlete_programme_decision_copy.dart';
import 'package:cohort_platform/features/programme/presentation/enrolment_date_presentation.dart';
import 'package:cohort_platform/features/programme/screens/athlete_programme_enrolment_review_screen.dart';
import 'package:cohort_platform/features/programme/services/athlete_catalogue_enrolment_service.dart';
import 'package:cohort_platform/features/programme/services/athlete_catalogue_enrolment_store.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_switch_catalog_service.dart';
import 'package:cohort_platform/features/programme/services/programme_catalog_service.dart';
import 'package:cohort_platform/features/programme/widgets/athlete_programme_status_state.dart';
import 'package:cohort_platform/core/widgets/cohort_button.dart';
import 'package:cohort_platform/features/programme/widgets/enrolment_timezone_picker_sheet.dart';
import 'package:cohort_platform/main_enrolment_continuity_preview.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

class _Store implements AthleteCatalogueEnrolmentStore {
  @override
  Future<AthleteCatalogueEnrolmentResult> enrol({
    required String programmeVersionId,
    String? timezone,
    bool replaceActive = false,
  }) async {
    return AthleteCatalogueEnrolmentResult(
      status: AthleteCatalogueEnrolmentStatus.enrolled,
      programmeVersionId: programmeVersionId,
      startedAt: DateTime(2026, 6, 16),
      timezone: timezone,
    );
  }
}

ProgrammeCatalogEntry _apollo() {
  return ProgrammeCatalogEntry(
    versionId: 'v-apollo',
    lineageCode: 'APOLLO',
    versionNumber: 1,
    name: 'Apollo',
    lifecycleStatus: ProgrammeLifecycleStatus.published,
    libraryScope: ProgrammeLibraryScope.cohortGlobal,
    ownerType: ProgrammeOwnerType.global,
    approvedForGlobal: true,
    primaryGoal: 'Hybrid strength',
    durationWeeks: 12,
    sessionsPerWeek: 4,
    difficulty: 'Intermediate',
  );
}

Future<AthleteProgrammeSelectionController> _controller() async {
  final controller = AthleteProgrammeSelectionController(
    athleteId: 'lee',
    catalogService: AthleteProgrammeSwitchCatalogService(
      catalogService: _Catalog([_apollo()]),
    ),
    enrolmentService: AthleteCatalogueEnrolmentService(enrolmentStore: _Store()),
  );
  await controller.load();
  return controller;
}

Future<void> _pumpReview(
  WidgetTester tester, {
  required Size size,
  double textScale = 1,
  DeviceIanaTimezoneSource source = const StaticDeviceIanaTimezoneSource(
    'Asia/Makassar',
  ),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final controller = await _controller();
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
      child: MaterialApp(
        home: AthleteProgrammeEnrolmentReviewScreen(
          controller: controller,
          versionId: 'v-apollo',
          timezoneSource: source,
          clock: () => DateTime.utc(2026, 6, 15, 16, 30),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('human-readable start date keeps ISO internally', () {
    expect(EnrolmentDatePresentation.fromIso('2026-06-16'), '16 June 2026');
    expect(EnrolmentDatePresentation.athleteFacing(DateTime(2026, 6, 16)),
        '16 June 2026');
  });

  testWidgets('review uses composed sections instead of a flat programme row', (
    tester,
  ) async {
    await _pumpReview(tester, size: const Size(390, 1400));
    expect(find.text('Enrol in Apollo?'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
    expect(find.text('Programme'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Continuity'), findsOneWidget);
    expect(find.text('Goal'), findsOneWidget);
    expect(find.text('Hybrid strength'), findsOneWidget);
    expect(find.text('12 weeks'), findsOneWidget);
    expect(find.text('Training timezone'), findsOneWidget);
    expect(find.text('Central Indonesia Time'), findsOneWidget);
    expect(find.text('Asia/Makassar'), findsOneWidget);
    expect(find.text('16 June 2026'), findsOneWidget);
    expect(find.text('2026-06-16'), findsNothing);
    expect(
      find.text(AthleteProgrammeDecisionCopy.enrolReviewBody('Apollo')),
      findsOneWidget,
    );
    expect(find.text(AthleteProgrammeContinuityCopy.travelAnchor), findsOneWidget);
    expect(find.text(AthleteProgrammeDecisionCopy.enrolConfirm), findsOneWidget);
  });

  testWidgets('missing timezone blocks confirmation', (tester) async {
    await _pumpReview(
      tester,
      size: const Size(390, 1400),
      source: const StaticDeviceIanaTimezoneSource(null),
    );
    expect(find.text(AthleteProgrammeContinuityCopy.timezoneRequired), findsOneWidget);
    expect(find.text(AthleteProgrammeDecisionCopy.enrolConfirm), findsOneWidget);
    expect(
      tester
          .widget<CohortButton>(
            find.widgetWithText(
              CohortButton,
              AthleteProgrammeDecisionCopy.enrolConfirm,
            ),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('timezone picker shows suggested, IANA, and selected check', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EnrolmentTimezonePickerSheet(
            selectedIana: 'Asia/Makassar',
            suggestedIana: 'Asia/Makassar',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Suggested'), findsOneWidget);
    expect(find.text('All timezones'), findsOneWidget);
    expect(find.text('Central Indonesia Time'), findsWidgets);
    expect(find.text('Asia/Makassar'), findsWidgets);
    expect(find.textContaining('Asia ·'), findsNothing);
    expect(find.byIcon(Icons.check), findsWidgets);
    expect(find.text(AthleteProgrammeContinuityCopy.useSelectedTimezone),
        findsOneWidget);
    final selected = tester.widget<Semantics>(
      find.descendant(
        of: find.byType(EnrolmentTimezonePickerSheet),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.selected == true,
        ),
      ).first,
    );
    expect(selected.properties.selected, isTrue);

    await tester.enterText(find.byType(TextField), 'london');
    await tester.pumpAndSettle();
    expect(find.text('United Kingdom'), findsWidgets);
    expect(find.text('Europe/London'), findsWidgets);
    expect(find.text('Search results'), findsOneWidget);
  });

  testWidgets('continuity and success states use headline then explanation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ListView(
          children: [
            AthleteProgrammeStatusState.fromContinuity(
              const AthleteProgrammeContinuity(
                status: AthleteProgrammeContinuityStatus.currentPinned,
                timezoneHealth: AssignmentTimezoneHealth.valid,
              ),
            ),
            AthleteProgrammeStatusState.fromContinuity(
              const AthleteProgrammeContinuity(
                status: AthleteProgrammeContinuityStatus.pinnedUnavailable,
                timezoneHealth: AssignmentTimezoneHealth.valid,
              ),
            ),
            AthleteProgrammeStatusState.fromContinuity(
              const AthleteProgrammeContinuity(
                status: AthleteProgrammeContinuityStatus.currentPinned,
                timezoneHealth: AssignmentTimezoneHealth.repairRequired,
              ),
            ),
            EnrolmentSuccessState(
              programmeTitle: 'Apollo',
              startDate: DateTime(2026, 6, 16),
              timezoneIana: 'Asia/Makassar',
            ),
          ],
        ),
      ),
    );
    expect(find.text('Your programme is unchanged'), findsOneWidget);
    expect(find.text('Programme temporarily unavailable'), findsOneWidget);
    expect(find.text('Confirm your training timezone'), findsOneWidget);
    expect(find.text('You’re enrolled'), findsOneWidget);
    expect(find.text('Apollo'), findsOneWidget);
    expect(find.text('16 June 2026'), findsOneWidget);
    expect(find.text('Central Indonesia Time'), findsOneWidget);
    expect(find.text('Asia/Makassar'), findsOneWidget);
    expect(find.text('Begin'), findsNothing);
    expect(find.text('Resume'), findsNothing);
  });

  testWidgets('preview fixtures keep Makassar, London, and missing truthful', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const EnrolmentContinuityPreviewApp(
        initialState: EnrolmentContinuityPreviewState.makassarSuggestion,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Enrol in Apollo?'), findsOneWidget);
    expect(find.text('Central Indonesia Time'), findsWidgets);
    expect(find.text('Asia/Makassar'), findsWidgets);
    expect(find.text('16 June 2026'), findsOneWidget);

    await tester.pumpWidget(
      const EnrolmentContinuityPreviewApp(
        initialState: EnrolmentContinuityPreviewState.londonSuggestion,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Europe/London'), findsWidgets);
    expect(find.text('United Kingdom'), findsWidgets);

    await tester.pumpWidget(
      const EnrolmentContinuityPreviewApp(
        initialState: EnrolmentContinuityPreviewState.missingTimezone,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(AthleteProgrammeContinuityCopy.timezoneRequired),
        findsOneWidget);

    await tester.pumpWidget(
      const EnrolmentContinuityPreviewApp(
        initialState: EnrolmentContinuityPreviewState.enrolmentSuccess,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('You’re enrolled'), findsOneWidget);
    expect(find.text('Apollo'), findsOneWidget);
    expect(find.text('16 June 2026'), findsOneWidget);
    expect(find.text('Asia/Makassar'), findsOneWidget);
  });

  testWidgets('320 and 390 review layouts do not overflow', (tester) async {
    for (final width in [320.0, 390.0]) {
      await _pumpReview(
        tester,
        size: Size(width, 1600),
        textScale: width == 320 ? 2 : 1,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Enrol in Apollo?'), findsOneWidget);
      expect(find.text(AthleteProgrammeDecisionCopy.enrolConfirm), findsOneWidget);
      await tester.ensureVisible(
        find.text(AthleteProgrammeDecisionCopy.enrolConfirm),
      );
      expect(find.text(AthleteProgrammeDecisionCopy.cancel), findsOneWidget);
    }
  });
}
