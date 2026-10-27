import 'package:cohort_platform/features/auth/services/current_user_session.dart';
import 'package:cohort_platform/features/programme_acquisition/acquisition_store.dart';
import 'package:cohort_platform/features/programme_acquisition/private_programme_catalogue.dart';
import 'package:cohort_platform/features/programme_acquisition/training_setup_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'acquisition_test_support.dart';

void main() {
  setUp(bindAcquisitionActor);
  tearDown(CurrentUserSession.clear);
  testWidgets(
    'saved onboarding draft resumes review; Finish opens catalogue child without enrolment',
    (t) async {
      final store = FakeAcquisitionStore()
        ..setup = const TrainingSetup(timezone: 'Europe/London');
      await t.pumpWidget(
        MaterialApp(
          home: TrainingSetupGate(
            athleteId: 'athlete-a',
            store: store,
            child: const Scaffold(body: Text('Catalogue destination')),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Finish setup'), findsOneWidget);
      expect(find.textContaining('Benchmarks are only needed'), findsOneWidget);
      await t.tap(find.text('Finish setup'));
      await t.pumpAndSettle();
      expect(find.text('Catalogue destination'), findsOneWidget);
      expect(store.acquisitions, 0);
    },
  );
  testWidgets('setup failure stays unavailable and exposes retry', (t) async {
    final store = FakeAcquisitionStore()..failure = 'unavailable';
    await t.pumpWidget(
      MaterialApp(
        home: TrainingSetupGate(
          athleteId: 'athlete-a',
          store: store,
          child: const Text('Shell'),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Shell'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    store.failure = null;
    await t.tap(find.text('Retry'));
    await t.pumpAndSettle();
    expect(find.text('Choose timezone'), findsOneWidget);
  });
  testWidgets(
    'catalogue shows authoritative facts; cancelling detail does not enrol',
    (t) async {
      final store = FakeAcquisitionStore();
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrivateProgrammeCatalogue(
              athleteId: 'athlete-a',
              store: store,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.textContaining('2 weeks'), findsOneWidget);
      await t.tap(find.text('[TEST ONLY] Private programme'));
      await t.pumpAndSettle();
      expect(find.text('Private · Free'), findsOneWidget);
      expect(store.acquisitions, 0);
      await t.pageBack();
      await t.pumpAndSettle();
      expect(store.acquisitions, 0);
    },
  );
  testWidgets('explicit free acquisition opens exact assignment schedule', (
    t,
  ) async {
    final store = FakeAcquisitionStore();
    String? assignment;
    await t.pumpWidget(
      MaterialApp(
        home: PrivateProgrammeDetail(
          athleteId: 'athlete-a',
          versionId: 'private-v1',
          store: store,
          openSchedule: (id) async {
            assignment = id;
          },
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Choose start date'));
    await t.pumpAndSettle();
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Get programme — free'));
    await t.tap(find.text('Get programme — free'));
    await t.pumpAndSettle();
    expect(assignment, 'assignment-exact');
    expect(store.acquisitions, 1);
  });
  testWidgets('empty, expired session and denied detail are distinct', (
    t,
  ) async {
    final store = FakeAcquisitionStore()..offers = [];
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrivateProgrammeCatalogue(athleteId: 'athlete-a', store: store),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.textContaining('No private programmes'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    store.failure = 'session_expired';
    await t.pumpWidget(
      MaterialApp(
        home: PrivateProgrammeDetail(
          athleteId: 'athlete-a',
          versionId: 'guessed',
          store: store,
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.textContaining('session has expired'), findsOneWidget);
    expect(find.text('Get programme — free'), findsNothing);
    store.failure = 'access_denied';
    await t.tap(find.text('Reload programme'));
    await t.pumpAndSettle();
    expect(
      find.textContaining('not available to your account'),
      findsOneWidget,
    );
  });
}
