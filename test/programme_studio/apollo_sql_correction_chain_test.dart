import 'dart:io';

import 'package:cohort_platform/features/programme_studio/projection/apollo_sql_artifact_chain.dart';
import 'package:cohort_platform/features/programme_studio/projection/executable_protocol_sql_reader.dart';
import 'package:cohort_platform/features/programme_studio/projection/programme_review_catalog.dart';
import 'package:cohort_platform/features/programme_studio/projection/programme_review_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const reader = ExecutableProtocolSqlReader();

  List<String> insertSql() {
    return [
      for (final path in ApolloSqlArtifactChain.insertRelativePaths)
        File(path).readAsStringSync(),
    ];
  }

  List<ProgrammeSqlSource> corrections([int take = 5]) {
    return [
      for (final path in ApolloSqlArtifactChain.correctionRelativePaths.take(
        take,
      ))
        ProgrammeSqlSource(path: path, sql: File(path).readAsStringSync()),
    ];
  }

  test('discovers Apollo prescription SQL in migration order', () {
    final discovered = ApolloSqlArtifactChain.discoverPrescriptionArtifacts(
      Directory('supabase/migrations'),
    );
    expect(discovered, ApolloSqlArtifactChain.orderedRelativePaths);
    expect(
      ProgrammeReviewCatalogRegistry.apolloWeekSql,
      ApolloSqlArtifactChain.insertRelativePaths,
    );
    expect(
      ProgrammeReviewCatalogRegistry.apolloCorrectionSql,
      ApolloSqlArtifactChain.correctionRelativePaths,
    );
  });

  test('corrected warm-up and capture values replace earlier inserts', () {
    final initial = reader.read(insertSql());
    final mondayWarmup = initial['APOLLO-W1-MON-R1']!.blocks.firstWhere(
      (item) => item.title == 'Apollo Shoulder Balance Warm-Up',
    );
    expect(mondayWarmup.movements, isEmpty);
    expect(
      mondayWarmup.content,
      contains('Thoracic extension over foam roller'),
    );

    final w5 = initial['APOLLO-W5-SAT-R1']!.blocks.firstWhere(
      (item) => item.blockType == 'conditioning',
    );
    expect(w5.timerConfiguration, isNot(contains('capture_strategy')));
    expect(
      w5.movements
          .firstWhere((item) => item.exerciseId == 'EX-131')
          .rawPrescription,
      isNot(contains('athleteSelected')),
    );

    final afterMonday = reader.readWithCorrections(
      insertSql: insertSql(),
      corrections: corrections(1),
    );
    final compact = afterMonday.protocols['APOLLO-W1-MON-R1']!.blocks
        .firstWhere((item) => item.title == 'Apollo Shoulder Balance Warm-Up');
    expect(compact.movements, hasLength(5));
    expect(compact.movements.first.rawPrescription, contains('5 slow reps'));

    final afterPrescriptions = reader.readWithCorrections(
      insertSql: insertSql(),
      corrections: corrections(2),
    );
    final structured = afterPrescriptions.protocols['APOLLO-W1-MON-R1']!.blocks
        .firstWhere((item) => item.title == 'Apollo Shoulder Balance Warm-Up');
    expect(
      structured.movements.first.rawPrescription,
      contains('"type":"exact"'),
    );
    expect(structured.movements.first.reps, '5');

    final finalRead = reader.readWithCorrections(
      insertSql: insertSql(),
      corrections: corrections(),
    );
    expect(
      finalRead.findings.any(
        (item) => item.code == 'unsupported_sql_correction',
      ),
      isFalse,
    );
    expect(
      finalRead.findings.where((item) => item.code == 'sql_correction_applied'),
      hasLength(5),
    );

    final finalMonday = finalRead.protocols['APOLLO-W1-MON-R1']!.blocks
        .firstWhere((item) => item.title == 'Apollo Shoulder Balance Warm-Up');
    expect(finalMonday.content, isEmpty);
    expect(finalMonday.movements, hasLength(5));
    expect(finalMonday.movements.first.exerciseId, 'EX-150');
    expect(finalMonday.movements.first.reps, '5');
    expect(finalMonday.coachNotes, contains('Do not cue permanent shoulders'));

    final tueRun = finalRead.protocols['APOLLO-W5-TUE-R1']!.blocks.firstWhere(
      (item) => item.title == 'Zone 2 run',
    );
    expect(tueRun.workoutFormat, 'steady_state');
    expect(tueRun.timerConfiguration, contains('duration_seconds'));
    expect(tueRun.timerConfiguration, isNot(contains('work_seconds')));

    final finalW5 = finalRead.protocols['APOLLO-W5-SAT-R1']!.blocks.firstWhere(
      (item) => item.blockType == 'conditioning',
    );
    expect(finalW5.timerConfiguration, contains('fixed_work'));
    expect(
      finalW5.movements
          .firstWhere((item) => item.exerciseId == 'EX-131')
          .rawPrescription,
      contains('athleteSelected'),
    );

    final strength = finalRead.protocols['APOLLO-W5-SAT-R1']!.blocks.firstWhere(
      (item) => item.blockType == 'strength',
    );
    final initialStrength = initial['APOLLO-W5-SAT-R1']!.blocks.firstWhere(
      (item) => item.blockType == 'strength',
    );
    expect(strength.title, initialStrength.title);
    expect(strength.content, initialStrength.content);
    expect(
      strength.movements.map((item) => item.rawPrescription),
      initialStrength.movements.map((item) => item.rawPrescription),
    );
  });

  test('source provenance remains inspectable after replay', () {
    final result = reader.readWithCorrections(
      insertSql: insertSql(),
      corrections: corrections(),
    );
    expect(
      result.findings.map((item) => item.sourceContext),
      ApolloSqlArtifactChain.correctionRelativePaths,
    );
  });

  test('unsupported relevant corrections cannot be silently skipped', () {
    final result = reader.readWithCorrections(
      insertSql: insertSql(),
      corrections: [
        ...corrections(2),
        const ProgrammeSqlSource(
          path:
              'supabase/migrations/20990101120000_apollo_mystery_body_update.sql',
          sql: "UPDATE public.session_blocks SET content = 'invented';",
        ),
      ],
    );
    expect(
      result.findings.any((item) => item.code == 'unsupported_sql_correction'),
      isTrue,
    );
    final monday = result.protocols['APOLLO-W1-MON-R1']!.blocks.firstWhere(
      (item) => item.title == 'Apollo Shoulder Balance Warm-Up',
    );
    expect(monday.content, isNot('invented'));
    expect(monday.movements.first.reps, '5');
  });
}
