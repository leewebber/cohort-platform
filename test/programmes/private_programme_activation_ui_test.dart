import 'package:cohort_platform/app/theme.dart';
import 'package:cohort_platform/features/programme/models/athlete_catalogue_enrolment.dart';
import 'package:cohort_platform/features/programme/models/private_programme_summary.dart';
import 'package:cohort_platform/features/programme/screens/athlete_private_programme_activation_screen.dart';
import 'package:cohort_platform/features/programme/services/private_programme_discovery_store.dart';
import 'package:cohort_platform/features/programme/services/private_programme_enrolment_store.dart';
import 'package:cohort_platform/features/programme/widgets/athlete_private_programmes_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _ListStore implements PrivateProgrammeDiscoveryStore {
  _ListStore(this.items);
  final List<PrivateProgrammeSummary> items;
  @override
  Future<List<PrivateProgrammeSummary>> listMine() async => items;
}

class _EnrolStore implements PrivateProgrammeEnrolmentStore {
  _EnrolStore({this.succeed = true});
  final bool succeed;
  int calls = 0;
  String? lastVersion;
  String? lastTimezone;
  DateTime? lastDate;
  bool? lastReplace;

  @override
  Future<AthleteCatalogueEnrolmentResult> enrol({
    required String programmeVersionId,
    required String timezone,
    required DateTime localStartDate,
    required bool replaceActive,
  }) async {
    calls += 1;
    lastVersion = programmeVersionId;
    lastTimezone = timezone;
    lastDate = localStartDate;
    lastReplace = replaceActive;
    if (!succeed) {
      return const AthleteCatalogueEnrolmentResult(
        status: AthleteCatalogueEnrolmentStatus.failed,
        message: 'Activation could not be completed. Apollo remains current.',
      );
    }
    return AthleteCatalogueEnrolmentResult(
      status: AthleteCatalogueEnrolmentStatus.enrolled,
      programmeVersionId: programmeVersionId,
      timezone: timezone,
      startedAt: localStartDate,
    );
  }
}

final _bali = PrivateProgrammeSummary(
  versionId: 'from-discovery-not-constant-ui',
  title: 'Bali Hybrid Base',
  summary: 'Internal hybrid base',
  durationWeeks: 8,
  classification: 'private',
  startEligible: true,
  authorisedTimezone: 'Asia/Makassar',
  authorisedLocalStartDate: DateTime(2026, 9, 26),
);

void main() {
  testWidgets('empty private list is absent', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: cohortTheme,
        home: Scaffold(
          body: AthletePrivateProgrammesSection(
            discoveryStore: _ListStore(const []),
            enrolmentStore: _EnrolStore(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('My private programmes'), findsNothing);
  });

  testWidgets('list renders discovery title not a baked UUID', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: cohortTheme,
        home: Scaffold(
          body: AthletePrivateProgrammesSection(
            discoveryStore: _ListStore([_bali]),
            enrolmentStore: _EnrolStore(),
            currentProgrammeTitle: 'Apollo Build',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('MY PRIVATE PROGRAMMES'), findsOneWidget);
    expect(find.text('Bali Hybrid Base'), findsOneWidget);
    expect(find.textContaining('b1a1b001'), findsNothing);
  });

  testWidgets('cancel does not enrol', (tester) async {
    final enrol = _EnrolStore();
    await tester.pumpWidget(
      MaterialApp(
        theme: cohortTheme,
        home: AthletePrivateProgrammeActivationScreen(
          programme: _bali,
          currentProgrammeTitle: 'Apollo Build',
          enrolmentStore: enrol,
        ),
      ),
    );
    expect(find.textContaining('Apollo Build is currently active'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(enrol.calls, 0);
  });

  testWidgets('confirmation invokes exact discovery version once', (tester) async {
    final enrol = _EnrolStore();
    await tester.pumpWidget(
      MaterialApp(
        theme: cohortTheme,
        home: AthletePrivateProgrammeActivationScreen(
          programme: _bali,
          currentProgrammeTitle: 'Apollo Build',
          enrolmentStore: enrol,
        ),
      ),
    );
    await tester.tap(find.text('Activate Bali Hybrid Base'));
    await tester.pumpAndSettle();
    expect(enrol.calls, 1);
    expect(enrol.lastVersion, 'from-discovery-not-constant-ui');
    expect(enrol.lastTimezone, 'Asia/Makassar');
    expect(enrol.lastDate, DateTime(2026, 9, 26));
    expect(enrol.lastReplace, isTrue);
  });

  testWidgets('failure leaves no success path', (tester) async {
    final enrol = _EnrolStore(succeed: false);
    await tester.pumpWidget(
      MaterialApp(
        theme: cohortTheme,
        home: AthletePrivateProgrammeActivationScreen(
          programme: _bali,
          currentProgrammeTitle: 'Apollo Build',
          enrolmentStore: enrol,
        ),
      ),
    );
    await tester.tap(find.text('Activate Bali Hybrid Base'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Apollo remains current'), findsOneWidget);
    expect(enrol.calls, 1);
  });
}
