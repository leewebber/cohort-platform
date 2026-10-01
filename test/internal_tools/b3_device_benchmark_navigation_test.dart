import 'package:cohort_platform/core/config/internal_tools_policy.dart';
import 'package:cohort_platform/core/widgets/cohort_card.dart';
import 'package:cohort_platform/features/app_shell/screens/athlete_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(InternalToolsPolicy.reset);

  testWidgets('athlete profile hides diagnostics by default', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AthleteProfileScreen()));

    expect(find.text('Developer tools'), findsNothing);
    expect(find.text('Diagnostics'), findsNothing);
  });

  testWidgets(
    'internal-tools build exposes the B3 benchmark through athlete profile',
    (tester) async {
      InternalToolsPolicy.enableForTesting();
      await tester.pumpWidget(const MaterialApp(home: AthleteProfileScreen()));

      final diagnostics = find.byKey(
        const ValueKey('athlete-profile-diagnostics'),
      );
      await tester.scrollUntilVisible(diagnostics, 300);
      await tester.drag(find.byType(ListView), const Offset(0, -80));
      await tester.pump();
      tester.widget<CohortCard>(diagnostics).onTap!();
      await tester.pumpAndSettle();

      expect(find.text('INTERNAL TOOLS'), findsOneWidget);
      expect(find.text('B3 device validation benchmark'), findsOneWidget);
    },
  );
}
