import 'package:cohort_platform/features/performance_tracking/distance_history_screen.dart';
import 'package:cohort_platform/internal_review/athlete_distance/synthetic_distance_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> visible(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<SyntheticDistanceHistory> mount(
    WidgetTester tester, {
    double scale = 1,
    double width = 800,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = SyntheticDistanceHistory();
    final c = source.controller();
    addTearDown(source.changes.close);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 900),
            textScaler: TextScaler.linear(scale),
          ),
          child: DistanceHistoryScreen(controller: c),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await c.toggleRecord(c.page.first);
    await c.selectBlock(c.views.first.summary.id, c.views.first.candidates[0]);
    await tester.pumpAndSettle();
    return source;
  }

  for (final width in [320.0, 800.0]) {
    testWidgets(
      'zero, source, dates and expandable evidence at width $width, 200 percent text',
      (tester) async {
        await mount(tester, scale: 2, width: width);
        await visible(tester, find.text('0 kilometres'));
        expect(find.text('Recorded'), findsOneWidget);
        expect(
          find.textContaining('date only · timezone unknown'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Source: owned History record'),
          findsOneWidget,
        );
        expect(
          find.textContaining('tracking_eligible'),
          findsNothing,
          reason: 'technical diagnostics initially collapsed',
        );
        await visible(tester, find.text('Evidence'));
        await tester.tap(find.text('Evidence'));
        await tester.pumpAndSettle();
        expect(find.textContaining('tracking_eligible'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('incompatible metres stay visible as incompatible evidence', (
    tester,
  ) async {
    await mount(tester);
    final c = tester
        .widget<DistanceHistoryScreen>(find.byType(DistanceHistoryScreen))
        .controller;
    await c.selectBlock(c.views.first.summary.id, c.views.first.candidates[6]);
    await tester.pumpAndSettle();
    await visible(tester, find.text('500 metres'));
    expect(find.text('Incompatible evidence'), findsOneWidget);
    expect(
      find.text('Units differ. No conversion is performed.'),
      findsOneWidget,
    );
  });
  testWidgets('partial and skipped remain distinct with withheld values', (
    tester,
  ) async {
    await mount(tester);
    final c = tester
        .widget<DistanceHistoryScreen>(find.byType(DistanceHistoryScreen))
        .controller;
    await c.selectBlock(c.views.first.summary.id, c.views.first.candidates[3]);
    await tester.pumpAndSettle();
    await visible(tester, find.text('Partial evidence'));
    expect(find.text('No admitted value'), findsOneWidget);
    await c.selectBlock(c.views.first.summary.id, c.views.first.candidates[4]);
    await tester.pumpAndSettle();
    expect(find.text('Skipped'), findsOneWidget);
  });
  testWidgets('pair refusal is short and evaluator-backed', (tester) async {
    await mount(tester);
    final c = tester
        .widget<DistanceHistoryScreen>(find.byType(DistanceHistoryScreen))
        .controller;
    await c.toggleRecord(c.page[1]);
    await c.selectBlock(c.views[1].summary.id, c.views[1].candidates[1]);
    await tester.pumpAndSettle();
    await visible(tester, find.byKey(const ValueKey('compare-distance')));
    await tester.tap(find.byKey(const ValueKey('compare-distance')));
    await tester.pumpAndSettle();
    await visible(tester, find.text('Not enough evidence to compare'));
    expect(
      find.text('Comparison context was not recorded for both blocks.'),
      findsOneWidget,
    );
  });
  testWidgets('sign-out removes even expanded evidence and source values', (
    tester,
  ) async {
    final source = await mount(tester);
    await visible(tester, find.text('Evidence'));
    await tester.tap(find.text('Evidence'));
    await tester.pumpAndSettle();
    source.signOut();
    await tester.pumpAndSettle();
    expect(find.text('0 kilometres'), findsNothing);
    expect(find.textContaining('audit_set_digest'), findsNothing);
    expect(find.textContaining('Account access changed.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('record and block buttons require explicit choices', (
    tester,
  ) async {
    final source = SyntheticDistanceHistory();
    addTearDown(source.changes.close);
    final c = source.controller();
    await tester.pumpWidget(
      MaterialApp(home: DistanceHistoryScreen(controller: c)),
    );
    await tester.pumpAndSettle();
    await visible(
      tester,
      find.byKey(ValueKey('record-${syntheticDistanceId(10)}')),
    );
    await tester.tap(find.byKey(ValueKey('record-${syntheticDistanceId(10)}')));
    await tester.pumpAndSettle();
    expect(c.views.single.selected, isNull);
    await visible(
      tester,
      find.byKey(ValueKey('block-${syntheticDistanceId(102)}')),
    );
    await tester.tap(find.byKey(ValueKey('block-${syntheticDistanceId(102)}')));
    await tester.pumpAndSettle();
    expect(
      c.views.single.selected!.field.blockResultId,
      syntheticDistanceId(102),
    );
    await visible(tester, find.text('5 kilometres'));
    expect(find.text('5 kilometres'), findsOneWidget);
  });
}
