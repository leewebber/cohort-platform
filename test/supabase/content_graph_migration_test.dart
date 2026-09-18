import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final files = [
    'supabase/migrations/20260918120000_content_graph_core.sql',
    'supabase/migrations/20260918120100_content_graph_publication.sql',
    'supabase/migrations/20260918120200_content_graph_read_models.sql',
    'supabase/migrations/20260918120300_content_graph_rls.sql',
    'supabase/migrations/20260918120400_content_graph_reconstruction.sql',
  ];

  test('content-graph migrations are additive and do not rewrite assignments', () {
    for (final path in files) {
      final sql = File(path).readAsStringSync();
      expect(File(path).existsSync(), isTrue);
      expect(sql, isNot(contains('Lee')));
      expect(sql.toLowerCase(), isNot(contains('otnhhdxstdnwccehacku')));
      expect(sql, isNot(contains('UPDATE public.programme_assignments')));
      expect(sql, isNot(contains('session_block_exercises.exercise_id →')));
    }
    final core = File(files.first).readAsStringSync();
    expect(core, contains('CREATE TABLE IF NOT EXISTS public.content_publishers'));
    expect(core, contains('CREATE TABLE IF NOT EXISTS public.content_graph_manifests'));
    expect(core, contains('content_graph_prevent_assignment_repin'));
    expect(core, isNot(contains('INSERT INTO public.content_publishers')));
    expect(core.toLowerCase(), isNot(contains("'cohort_global'")));
    final publish = File(files[1]).readAsStringSync();
    expect(publish, contains('publish_content_graph_manifest'));
    expect(publish, contains("'published'"));
    expect(publish, contains("'already_published'"));
    expect(publish, contains("'hash_mismatch'"));
    expect(publish, contains("'unsupported_format'"));
    expect(publish, contains("'unresolved_reference'"));
    expect(publish, contains("'conflicting_identity'"));
    expect(publish, contains("'unauthorised'"));
    final rls = File(files[3]).readAsStringSync();
    expect(rls, contains('content_graph_read'));
    expect(rls, contains('ENABLE ROW LEVEL SECURITY'));
    expect(rls, contains('content_graph_actor_may_read_manifest'));
    expect(
      rls,
      isNot(contains('OR public.cohort_auth_is_coach()')),
    );
  });

  test('manual publisher bootstrap is not part of the migration chain', () {
    final migrations = Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last)
        .toList();
    expect(
      migrations.any((name) => name.contains('bootstrap_cohort_global')),
      isFalse,
    );
    final bootstrap = File(
      'supabase/manual/content_graph_bootstrap_cohort_global.sql',
    );
    expect(bootstrap.existsSync(), isTrue);
    final sql = bootstrap.readAsStringSync();
    expect(sql, contains('content_graph_bootstrap_cohort_global'));
    expect(sql, contains("'created'"));
    expect(sql, contains("'already_exists'"));
    expect(sql, contains("'conflict'"));
    expect(sql, contains('missing_principal'));
    expect(sql, isNot(contains('otnhhdxstdnwccehacku')));
    expect(sql, isNot(contains('b5fc87e3')));
    expect(sql, contains('-- SELECT public.content_graph_bootstrap_cohort_global'));
    expect(
      sql,
      isNot(contains('\nSELECT public.content_graph_bootstrap_cohort_global')),
    );
    final publish = File(files[1]).readAsStringSync();
    expect(publish, contains("'missing_publisher'"));
  });
}
