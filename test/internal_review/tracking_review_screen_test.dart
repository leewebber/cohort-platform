import 'package:cohort_platform/app/theme.dart';
import 'package:cohort_platform/internal_review/performance_tracking/tracking_review_scenarios.dart';
import 'package:cohort_platform/internal_review/performance_tracking/tracking_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> mount(
  WidgetTester tester,
  TrackingReviewScenario scenario, {
  Size size = const Size(1440, 1000),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: cohortTheme,
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: TrackingReviewScreen(initialScenario: scenario),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('default has clear measured facts and hides technical evidence', (
    tester,
  ) async {
    await mount(tester, TrackingReviewScenario.complete);
    expect(
      find.textContaining('Synthetic data — internal visual review only'),
      findsOneWidget,
    );
    expect(
      find.text('Synthetic observation profile · version 1'),
      findsOneWidget,
    );
    expect(
      find.text('Synthetic block duration · definition version 1'),
      findsOneWidget,
    );
    expect(find.text('12 seconds'), findsWidgets);
    expect(find.text('14 seconds'), findsWidgets);
    expect(find.textContaining('8 Jan 2026 · 12:00:00 UTC'), findsWidgets);
    expect(find.text('Can compare'), findsOneWidget);
    expect(
      find.text('Independent observation · no programme link requested'),
      findsNWidgets(2),
    );
    expect(find.byType(SelectableText), findsNothing);
    expect(find.textContaining('Selected-field coverage:'), findsNothing);
    expect(
      find.textContaining('Independent tracking eligibility:'),
      findsNothing,
    );
    for (final label in [
      'Save',
      'Select profile',
      'Accept',
      'Enter result',
      'Publish',
    ]) {
      expect(find.text(label), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'evidence expands and resets when scenario changes; failure remains explicit',
    (tester) async {
      await mount(tester, TrackingReviewScenario.complete);
      await tester.ensureVisible(find.text('Definition evidence'));
      await tester.tap(find.text('Definition evidence'));
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsOneWidget);
      final source = tester
          .widget<SelectableText>(find.byType(SelectableText))
          .data!;
      expect(source, contains('synthetic.c4.metric'));
      expect(source, contains('digest'));
      await tester.tap(find.byKey(const ValueKey('scenario-aliases')));
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsNothing);
      expect(find.text('Evaluation refused'), findsOneWidget);
      expect(
        find.text('References to the same source disagree.'),
        findsOneWidget,
      );
      expect(
        find.text('One physical observation · multiple references'),
        findsOneWidget,
      );
      expect(
        find.text('The same observation is referenced twice.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final scenario in TrackingReviewScenario.values) {
    testWidgets(
      '${scenario.name} narrow large-text layout and evidence are readable',
      (tester) async {
        await mount(tester, scenario, size: const Size(390, 844), scale: 2);
        expect(find.byKey(const ValueKey('scenario-menu')), findsOneWidget);
        expect(tester.takeException(), isNull);
        final evidence = find.text('Source and correction evidence').first;
        await tester.ensureVisible(evidence);
        await tester.tap(evidence);
        await tester.pumpAndSettle();
        expect(find.byType(SelectableText), findsOneWidget);
        await tester.drag(
          find.byKey(const ValueKey('review-workspace')),
          const Offset(0, -700),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'narrow scenario menu supports keyboard focus and changes only review state',
    (tester) async {
      await mount(
        tester,
        TrackingReviewScenario.complete,
        size: const Size(390, 844),
      );
      final semantics = tester.ensureSemantics();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      expect(FocusManager.instance.primaryFocus, isNotNull);
      await tester.tap(find.byKey(const ValueKey('scenario-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Corrected evidence').last);
      await tester.pumpAndSettle();
      expect(
        find.text('Correction audit present; earlier inputs unavailable.'),
        findsWidgets,
      );
      expect(find.textContaining('Recorded audit times'), findsNothing);
      expect(find.text('Can compare'), findsNothing);
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('default evidence states and attribution reasons remain plain', (
    tester,
  ) async {
    await mount(tester, TrackingReviewScenario.missing);
    expect(find.text('Missing evidence — no value'), findsWidgets);
    expect(find.text('Partial evidence — no value'), findsWidgets);
    expect(find.text('Skipped — no value'), findsOneWidget);
    expect(find.text('Value unavailable — no value'), findsOneWidget);
    expect(find.textContaining('date only · timezone unknown'), findsOneWidget);
    expect(find.text('Not enough evidence'), findsNWidgets(2));
    expect(find.textContaining('Selected-field coverage:'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'observation Evidence retains coverage eligibility and exact facts',
    (tester) async {
      await mount(tester, TrackingReviewScenario.complete);
      await tester.ensureVisible(find.text('Evidence').first);
      await tester.tap(find.text('Evidence').first);
      await tester.pumpAndSettle();
      expect(
        find.text('Selected-field coverage: 1 of 1 required complete fields'),
        findsOneWidget,
      );
      expect(
        find.text('Independent tracking eligibility: eligible'),
        findsOneWidget,
      );
      final evidence = tester
          .widget<SelectableText>(find.byType(SelectableText))
          .data!;
      expect(evidence, contains('"tracking_eligible": true'));
      expect(evidence, contains('"grants_prescription_eligibility": false'));
      expect(evidence, contains('"performed_at": "2026-01-01T12:00:00.000Z"'));
      expect(
        evidence,
        contains(
          '"audit_membership_proves_field_changed_or_latest_revision": false',
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'comparison refusals use short reasons and preserve every mismatch',
    (tester) async {
      await mount(tester, TrackingReviewScenario.incompatible);
      expect(find.text('Cannot compare'), findsNWidgets(3));
      expect(find.text('Not enough evidence'), findsOneWidget);
      expect(
        find.text('Units differ. No conversion is performed.'),
        findsNWidgets(2),
      );
      expect(find.text('Measurement methods differ.'), findsOneWidget);
      expect(find.text('Metric definitions differ.'), findsOneWidget);
      expect(find.textContaining('Comparison context differs'), findsOneWidget);
      expect(
        find.textContaining('Comparison context is missing'),
        findsOneWidget,
      );
      expect(
        find.text('A complete, usable observation is missing.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'independent and unproven scope remain visible without a fallback',
    (tester) async {
      await mount(tester, TrackingReviewScenario.attribution);
      expect(
        find.textContaining('Independent tracking eligibility:'),
        findsNothing,
      );
      expect(
        find.text('Independent observation · no programme link requested'),
        findsOneWidget,
      );
      expect(find.text('Programme scope unproven'), findsOneWidget);
      expect(
        find.text('Programme link proven in this synthetic fixture'),
        findsOneWidget,
      );
      expect(find.text('Programme link refused'), findsOneWidget);
      expect(find.text('Request refused'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );
}
