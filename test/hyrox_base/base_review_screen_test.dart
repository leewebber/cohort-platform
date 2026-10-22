import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cohort_platform/internal_review/hyrox_base/base_review_screen.dart';

Future<void> reveal(WidgetTester t, Finder finder) async {
  await t.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'missing benchmarks produce labelled effort/target-unavailable preview',
    (t) async {
      await t.pumpWidget(const MaterialApp(home: BaseReviewScreen()));
      final calculate = find.text('Calculate session preview');
      await reveal(t, calculate);
      await t.tap(calculate);
      await t.pumpAndSettle();
      expect(
        find.textContaining('Week 1 • authored + calculated preview'),
        findsOneWidget,
      );
      await reveal(
        t,
        find.textContaining('Numeric target unavailable: missing_10km'),
      );
      expect(
        find.textContaining('Numeric target unavailable: missing_10km'),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'entry requires source, explicit selection then calculates 40-minute pace',
    (t) async {
      await t.pumpWidget(const MaterialApp(home: BaseReviewScreen()));
      await t.enterText(find.byType(TextField).at(0), '2400');
      await t.enterText(find.byType(TextField).at(2), 'known synthetic run');
      final add = find.text('Add benchmark entry');
      await reveal(t, add);
      await t.tap(add);
      await t.pumpAndSettle();
      final choose = find.text('Choose');
      await reveal(t, choose);
      await t.tap(choose);
      await t.pumpAndSettle();
      final accept = find.text('Accept benchmark selection');
      await reveal(t, accept);
      await t.tap(accept);
      await t.pumpAndSettle();
      final calculate = find.text('Calculate session preview');
      await reveal(t, calculate);
      await t.tap(calculate);
      await t.pumpAndSettle();
      await reveal(t, find.textContaining('4:00.0–4:12.0 /km'));
      expect(find.textContaining('4:00.0–4:12.0 /km'), findsOneWidget);
      final freeze = find.text('Freeze local started-session example');
      await reveal(t, freeze);
      await t.tap(freeze);
      await t.pumpAndSettle();
      await reveal(t, find.textContaining('local-1: started local example'));
      expect(
        find.textContaining('local-1: started local example'),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('invalid input is explicit and cannot freeze stale review', (
    t,
  ) async {
    await t.pumpWidget(const MaterialApp(home: BaseReviewScreen()));
    await t.enterText(find.byType(TextField).first, 'NaN');
    final add = find.text('Add benchmark entry');
    await reveal(t, add);
    await t.tap(add);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('input-error')), findsOneWidget);
    final calculate = find.text('Calculate session preview');
    await reveal(t, calculate);
    await t.tap(calculate);
    await t.pumpAndSettle();
    expect(find.text('Freeze local started-session example'), findsNothing);
  });
  testWidgets('narrow layout remains operable with large text', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: const BaseReviewScreen(),
      ),
    );
    await reveal(t, find.text('Calculate session preview'));
    await t.tap(find.text('Calculate session preview'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
