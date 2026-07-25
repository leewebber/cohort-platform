import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Coach-only route surfaces that must remain deep-link safe for athletes.
const coachOnlyScreenFiles = <String>[
  'lib/features/coach_operations/screens/coach_home_dashboard_screen.dart',
  'lib/features/coach_studio/coach_studio_home_screen.dart',
  'lib/features/coach_studio/programmes/programme_catalogue_screen.dart',
  'lib/features/coach_studio/programmes/new_programme_screen.dart',
  'lib/features/coach_studio/programmes/programme_editor_screen.dart',
  'lib/features/coach_studio/programmes/programme_preview_screen.dart',
  'lib/features/training_library/screens/training_library_screen.dart',
  'lib/features/training_library/screens/library_session_builder_screen.dart',
  'lib/features/coach_athlete/screens/athlete_detail_screen.dart',
  'lib/features/coach_athlete/screens/athlete_roster_screen.dart',
  'lib/features/admin/protocol_builder_screen.dart',
  'lib/features/admin/protocol_drafts_screen.dart',
  'lib/features/admin/published_protocols_screen.dart',
  'lib/features/admin/admin_protocol_editor_screen.dart',
  'lib/features/personal_training/screens/personal_training_setup_screen.dart',
  'lib/features/session/session_preview_screen.dart',
];

void main() {
  test('coach-only screens wrap content with CoachRouteGuard', () {
    for (final relativePath in coachOnlyScreenFiles) {
      final file = File(relativePath);
      expect(file.existsSync(), isTrue, reason: 'Missing $relativePath');
      final source = file.readAsStringSync();
      expect(
        source.contains('CoachRouteGuard.wrap') ||
            source.contains('CoachRouteGuard('),
        isTrue,
        reason: '$relativePath must use CoachRouteGuard',
      );
    }
  });

  test('athlete join-coach screen is not coach-guarded', () {
    final source = File(
      'lib/features/coach_athlete/screens/join_coach_screen.dart',
    ).readAsStringSync();
    expect(source.contains('CoachRouteGuard'), isFalse);
  });
}
