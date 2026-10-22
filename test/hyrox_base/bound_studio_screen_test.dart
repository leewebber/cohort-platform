import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cohort_platform/features/programme_studio/bound_personalisation/bound_review_screen.dart';

Future<void> reveal(WidgetTester t, Finder f) async {
  await t.scrollUntilVisible(f, 250, scrollable: find.byType(Scrollable).first);
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'compiled missing targets remain explicit through local start freeze',
    (t) async {
      await t.pumpWidget(const MaterialApp(home: BoundStudioReviewScreen()));
      final review = find.text('Review compiled targets');
      await reveal(t, review);
      await t.tap(review);
      await t.pumpAndSettle();
      final missing = find.text('Selected benchmark evidence: missing');
      await reveal(t, missing.first);
      expect(missing, findsWidgets);
      final start = find.text(
        'Start synthetic session and freeze prescription',
      );
      await reveal(t, start);
      await t.tap(start);
      await t.pumpAndSettle();
      await reveal(t, find.text('W1-GYM: started synthetic snapshot'));
      expect(find.text('W1-GYM: started synthetic snapshot'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'benchmark entry, explicit acceptance, source review and frozen selected target',
    (t) async {
      await t.pumpWidget(const MaterialApp(home: BoundStudioReviewScreen()));
      final slots = find.byType(DropdownButtonFormField<String>);
      await reveal(t, slots);
      await t.tap(slots);
      await t.pumpAndSettle();
      await t.tap(find.text('W1-RUN').last);
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).at(0), '2400');
      await t.enterText(find.byType(TextField).at(2), 'synthetic known 10km');
      final add = find.text('Add benchmark entry');
      await reveal(t, add);
      await t.tap(add);
      await t.pumpAndSettle();
      final choose = find.text('Choose');
      await reveal(t, choose);
      await t.tap(choose);
      await t.pumpAndSettle();
      final accept = find.text('Accept future target selection');
      await reveal(t, accept);
      await t.tap(accept);
      await t.pumpAndSettle();
      final review = find.text('Review compiled targets');
      await reveal(t, review);
      await t.tap(review);
      await t.pumpAndSettle();
      final pace = find.textContaining('240.0–252.0 seconds /km');
      await reveal(t, pace);
      expect(pace, findsOneWidget);
      expect(find.text('Actual: not recorded'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'narrow large text remains usable and invalid numeric input is shown',
    (t) async {
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
          home: const BoundStudioReviewScreen(),
        ),
      );
      await t.enterText(find.byType(TextField).first, 'NaN');
      final add = find.text('Add benchmark entry');
      await reveal(t, add);
      await t.tap(add);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('bound-error')), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
