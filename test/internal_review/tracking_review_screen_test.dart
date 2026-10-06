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
    expect(find.textContaining('2026-01-08'), findsWidgets);
    expect(find.text('Comparable'), findsOneWidget);
    expect(find.text('Programme attribution not requested'), findsNWidgets(2));
    expect(find.byType(SelectableText), findsNothing);
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
        find.text(
          'Aliases of one physical source contain conflicting evidence.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('One physical observation · multiple references'),
        findsOneWidget,
      );
      expect(
        find.text('Both references identify the same physical observation.'),
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
      expect(find.textContaining('Tied audit times'), findsOneWidget);
      expect(find.text('Comparable'), findsNothing);
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
    expect(find.text('Comparison unavailable'), findsNWidgets(2));
    expect(
      find.textContaining('Selected-field coverage: 0 of 1'),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'independent and unproven scope remain visible without a fallback',
    (tester) async {
      await mount(tester, TrackingReviewScenario.attribution);
      expect(
        find.text('Independent tracking eligibility: eligible'),
        findsNWidgets(2),
      );
      expect(find.text('Programme attribution not requested'), findsOneWidget);
      expect(find.text('Programme scope unproven'), findsOneWidget);
      expect(
        find.text('Programme attribution: proven in this synthetic fixture'),
        findsOneWidget,
      );
      expect(find.text('Programme attribution failed'), findsOneWidget);
      expect(find.text('Request refused'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );
}
