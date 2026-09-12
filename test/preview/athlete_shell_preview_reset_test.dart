import 'package:cohort_platform/features/athlete_profile/services/athlete_profile_session.dart';
import 'package:cohort_platform/features/auth/services/current_user_session.dart';
import 'package:cohort_platform/preview/athlete_shell_preview_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    CurrentUserSession.clear();
    AthleteProfileSession.clear();
  });

  testWidgets('Reset preview rebuilds the disposable fixture shell', (
    tester,
  ) async {
    await tester.pumpWidget(const AthleteShellPreviewApp());
    await tester.pumpAndSettle();

    expect(find.text('LOCAL PREVIEW'), findsOneWidget);
    expect(find.text('Reset preview'), findsWidgets);
    expect(find.text('Apollo Strength'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('preview-reset')));
    await tester.pumpAndSettle();

    expect(find.text('LOCAL PREVIEW'), findsOneWidget);
    expect(find.text('Apollo Strength'), findsOneWidget);
    expect(find.text('Reset preview'), findsWidgets);
  });
}
