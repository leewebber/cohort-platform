import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final files = [
    'supabase/migrations/20260919120000_publisher_athlete_membership_core.sql',
    'supabase/migrations/20260919120100_publisher_athlete_membership_rpcs.sql',
    'supabase/migrations/20260919120200_publisher_athlete_roster_projection.sql',
    'supabase/migrations/20260919120300_publisher_athlete_membership_rls.sql',
    'supabase/migrations/20260919120400_publisher_athlete_membership_capabilities.sql',
  ];

  test('membership migrations are additive and do not infer consent', () {
    for (final path in files) {
      final sql = File(path).readAsStringSync();
      expect(File(path).existsSync(), isTrue);
      expect(sql, isNot(contains('Lee')));
      expect(sql.toLowerCase(), isNot(contains('otnhhdxstdnwccehacku')));
      expect(sql, isNot(contains('79853f15')));
      expect(sql, isNot(contains('46940d28')));
      expect(sql, isNot(contains('UPDATE public.programme_assignments')));
      expect(sql, isNot(contains('INSERT INTO public.programme_assignments')));
    }
    expect(
      File(files.first).readAsStringSync(),
      isNot(contains('INSERT INTO public.publisher_athlete_')),
    );
    final core = File(files.first).readAsStringSync();
    expect(core, contains('publisher_athlete_invitations'));
    expect(core, contains('publisher_athlete_memberships'));
    expect(core, contains('publisher_athlete_membership_events'));
    expect(core, contains('publisher_athlete_invitations_one_pending'));
    expect(core, contains('publisher_athlete_memberships_one_active'));
    final rpcs = File(files[1]).readAsStringSync();
    expect(rpcs, contains('cohort_publisher_athlete_invite'));
    expect(rpcs, contains("'already_pending'"));
    expect(rpcs, contains("'already_active'"));
    expect(rpcs, contains("'unauthorised'"));
    final rls = File(files[3]).readAsStringSync();
    expect(rls, contains('WITH CHECK (FALSE)'));
    expect(rls, contains('USING (FALSE)'));
    final caps = File(files[4]).readAsStringSync();
    expect(caps, contains('publisher_athlete_membership_read'));
    expect(caps, contains("'schema_version', 3"));
  });
}
