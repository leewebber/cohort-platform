import 'dart:io';

/// Ordered Apollo executable-protocol SQL used as programme-body authority.
///
/// Discovery is filename-plus-statement class only. This is not a SQL engine.
abstract final class ApolloSqlArtifactChain {
  static const insertRelativePaths = [
    'supabase/migrations/20260821120000_apollo_build_week1_executable_protocols.sql',
    'supabase/migrations/20260821121000_apollo_build_week2_executable_protocols.sql',
    'supabase/migrations/20260821122000_apollo_build_week3_executable_protocols.sql',
    'supabase/migrations/20260821123000_apollo_build_week4_executable_protocols.sql',
    'supabase/migrations/20260821124000_apollo_build_week5_executable_protocols.sql',
    'supabase/migrations/20260821125000_apollo_build_week6_executable_protocols.sql',
    'supabase/migrations/20260821130000_apollo_build_week7_executable_protocols.sql',
    'supabase/migrations/20260821131000_apollo_build_week8_executable_protocols.sql',
    'supabase/migrations/20260821132000_apollo_build_week9_executable_protocols.sql',
    'supabase/migrations/20260821133000_apollo_build_week10_executable_protocols.sql',
    'supabase/migrations/20260821134000_apollo_build_week11_executable_protocols.sql',
    'supabase/migrations/20260821135000_apollo_build_week12_executable_protocols.sql',
  ];

  static const correctionRelativePaths = [
    'supabase/migrations/20260823121000_structure_apollo_week1_monday_warmup_exercises.sql',
    'supabase/migrations/20260824121000_correct_apollo_structured_warmup_prescriptions.sql',
    'supabase/migrations/20260825120000_structure_all_apollo_warmups_and_athlete_details.sql',
    'supabase/migrations/20260903120000_classify_continuous_conditioning_as_steady_state.sql',
    'supabase/migrations/20260906160000_apollo_w5_fixed_work_rounds_capture.sql',
  ];

  static List<String> get orderedRelativePaths => [
    ...insertRelativePaths,
    ...correctionRelativePaths,
  ];

  static List<String> discoverPrescriptionArtifacts(Directory migrations) {
    final files =
        migrations
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.sql'))
            .toList()
          ..sort(
            (a, b) =>
                a.uri.pathSegments.last.compareTo(b.uri.pathSegments.last),
          );
    return [
      for (final file in files)
        if (_isPrescriptionArtifact(file))
          'supabase/migrations/${file.uri.pathSegments.last}',
    ];
  }

  static bool _isPrescriptionArtifact(File file) {
    final name = file.uri.pathSegments.last;
    if (name.contains('apollo_calendar') || name.contains('publish_apollo')) {
      return false;
    }
    final sql = file.readAsStringSync();
    final touchesBodies =
        sql.contains('INSERT INTO public.session_blocks') ||
        sql.contains('UPDATE public.session_blocks') ||
        sql.contains('INSERT INTO public.session_block_exercises') ||
        sql.contains('UPDATE public.session_block_exercises');
    if (!touchesBodies) {
      return false;
    }
    return name.contains('apollo') ||
        name.contains('classify_continuous_conditioning');
  }
}
