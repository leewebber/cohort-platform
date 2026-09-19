import 'package:cohort_platform/main_m10_isolation_preview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('preview identifies itself and shows the successful roster', (
    tester,
  ) async {
    await tester.pumpWidget(const M10IsolationPreviewApp());
    expect(find.textContaining('INTERNAL PREVIEW'), findsOneWidget);
    expect(find.textContaining('Roster status: ready'), findsOneWidget);
    expect(find.textContaining('athlete.fixture-existing'), findsOneWidget);
  });

  testWidgets('preview can show unauthorised and empty states', (tester) async {
    await tester.pumpWidget(const M10IsolationPreviewApp());
    await tester.tap(find.text('empty'));
    await tester.pump();
    expect(find.textContaining('Roster status: empty'), findsOneWidget);
    await tester.tap(find.text('unauthorised'));
    await tester.pump();
    expect(find.textContaining('Roster status: unauthorised'), findsOneWidget);
  });
}
