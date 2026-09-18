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
  });
}
