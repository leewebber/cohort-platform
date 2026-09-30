import 'package:cohort_platform/main_b3_slice3_preview.dart' as preview;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('local preview opens with athlete-safe calculated target copy', (
    tester,
  ) async {
    await tester.pumpWidget(const preview.B3Slice3PreviewApp());

    expect(find.text('LOCAL PREVIEW'), findsOneWidget);
    expect(find.text('Advisory pace target'), findsOneWidget);
    expect(find.text('3:50–4:10 /km'), findsOneWidget);
    expect(find.text('Work repetition 1'), findsOneWidget);
    expect(find.textContaining(':s:'), findsNothing);
    expect(find.textContaining('123e4567'), findsNothing);
  });

  testWidgets('local preview exposes every founder review surface', (
    tester,
  ) async {
    await tester.pumpWidget(const preview.B3Slice3PreviewApp());

    await tester.tap(find.byKey(const ValueKey('b3-preview-surface')));
    await tester.pumpAndSettle();
    for (final label in const [
      '1 · Calculated work target',
      '2 · Recovery isolation',
      '3 · Repetition capture',
      '4 · Review Session',
      '5 · History + correction',
      '6 · Pace unavailable',
      '7 · Skipped work',
    ]) {
      expect(find.text(label), findsAtLeastNWidgets(1));
    }
  });

  testWidgets('local preview shows the single pace-unavailable explanation', (
    tester,
  ) async {
    await tester.pumpWidget(
      const preview.B3Slice3PreviewApp(initialSurfaceIndex: 5),
    );

    expect(find.text('Pace target unavailable'), findsOneWidget);
    expect(
      find.text(
        'No eligible recent 5 km benchmark was available when this session started. Follow the authored guidance. Cohort has not estimated a pace.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining(':s:'), findsNothing);
  });

  testWidgets('local preview shows skipped actual separately from target', (
    tester,
  ) async {
    await tester.pumpWidget(
      const preview.B3Slice3PreviewApp(initialSurfaceIndex: 6),
    );

    expect(
      find.text('Skipped work makes this session partially completed.'),
      findsOneWidget,
    );
    expect(find.text('PARTIALLY COMPLETED SESSION'), findsOneWidget);
    expect(find.textContaining('Partially completed '), findsOneWidget);
    expect(
      find.text('Blocks · 1 completed · 0 skipped · 0 incomplete'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Work repetitions · 1 completed · 1 pace unavailable · 1 skipped · 0 incomplete',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('edit-results')), findsNothing);
    await tester.drag(
      find.byKey(const ValueKey('completed-session-result')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Interval performance'));
    await tester.pumpAndSettle();
    expect(find.text('Target · 3:50 /km–4:10 /km'), findsNWidgets(3));
    expect(find.text('Actual · Skipped'), findsOneWidget);
  });
}
