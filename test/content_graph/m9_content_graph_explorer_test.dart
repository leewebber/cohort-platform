import 'package:cohort_platform/domain/content_graph/content_graph_vocabulary.dart';
import 'package:cohort_platform/main_m9_content_graph_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('fixture explorer shows pinned v1 and local-only banner', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const M9ContentGraphPreviewApp());
    expect(find.textContaining('LOCAL FIXTURES ONLY'), findsOneWidget);
    expect(find.textContaining('Existing athlete pinned to v1'), findsOneWidget);
    expect(find.textContaining('Source package hash:'), findsOneWidget);
    expect(find.textContaining('Composite content identity:'), findsOneWidget);
    await tester.tap(find.text('Used by'));
    await tester.pump();
    expect(find.textContaining('EX-136 used-by'), findsOneWidget);
    await tester.tap(find.text('Deny cross-namespace'));
    await tester.pump();
    expect(
      find.textContaining(ContentGraphFailureCode.namespaceIsolation.name),
      findsOneWidget,
    );
  });
}
