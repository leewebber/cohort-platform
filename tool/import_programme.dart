#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:cohort_platform/domain/exercise_knowledge/in_memory/in_memory_transitional_exercise_id_bridge.dart';
import 'package:cohort_platform/domain/exercise_knowledge/seed/founder_approved_identity_mappings_phase_3_1f.dart';
import 'package:founder_importer/core/config/internal_tools_policy.dart';
import 'package:founder_importer/data/repositories/exercise_repository.dart';
import 'package:founder_importer/data/repositories/programme_version_supabase_store.dart';
import 'package:founder_importer/features/admin/services/protocol_builder_service.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_import_dry_run_result.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_import_exception.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_import_service.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_prescription_mapper.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_protocol_writer.dart';
import 'package:founder_importer/runtime/env_config.dart';
import 'package:founder_importer/runtime/supabase_client_holder.dart';
import 'package:supabase/supabase.dart';

import 'founder_programme_import/repository_transitional_identity_adapter.dart';

Future<void> main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  final positional = args
      .where((arg) => arg != '--dry-run')
      .toList(growable: false);

  if (positional.length != 1) {
    _printUsage();
    exitCode = 64;
    return;
  }

  InternalToolsPolicy.enable();
  final file = File(positional.single);
  if (!file.existsSync()) {
    print('File not found: ${file.path}');
    exitCode = 66;
    return;
  }

  late final EnvConfig env;
  try {
    env = EnvConfig.loadFromWorkspace();
  } on EnvConfigException catch (error) {
    print(error);
    exitCode = 78;
    return;
  }

  final client = SupabaseClient(env.supabaseUrl, env.supabaseAnonKey);
  SupabaseClientHolder.bind(client);

  if (!dryRun &&
      (env.importEmail == null ||
          env.importEmail!.isEmpty ||
          env.importPassword == null ||
          env.importPassword!.isEmpty)) {
    print(
      'Set SUPABASE_IMPORT_EMAIL and SUPABASE_IMPORT_PASSWORD in .env for coach sign-in.',
    );
    exitCode = 78;
    return;
  }

  try {
    String? coachId;
    if (!dryRun) {
      final authResponse = await client.auth.signInWithPassword(
        email: env.importEmail!,
        password: env.importPassword!,
      );
      coachId = authResponse.user?.id;
      if (coachId == null || coachId.isEmpty) {
        print(
          'Coach sign-in succeeded but no authenticated user id was returned.',
        );
        exitCode = 70;
        return;
      }
    }

    final exercises = await ExerciseRepository().getExercises();
    final bridge = InMemoryTransitionalExerciseIdBridge(
      initial: FounderApprovedIdentityMappingsPhase31F.allMappings,
    );
    final exerciseResolver = FounderProgrammeExerciseResolver.fromCatalogue(
      exercises,
      transitionalIdentityResolver: RepositoryTransitionalIdentityAdapter(
        bridge,
      ),
    );
    final importer = FounderProgrammeImportService(
      versionStore: const ProgrammeVersionSupabaseStore(),
      protocolWriter: ProtocolBuilderProgrammeProtocolWriter(
        ProtocolBuilderService(),
      ),
      exerciseResolver: exerciseResolver,
    );
    final yamlSource = file.readAsStringSync();

    if (dryRun) {
      final result = await importer.dryRunYaml(yamlSource: yamlSource);
      _printDryRunReport(result);
      exitCode = result.readyForApply ? 0 : 65;
      return;
    }

    final result = await importer.importYaml(
      yamlSource: yamlSource,
      coachId: coachId!,
    );
    print(result.summaryMessage);
    print('lineage_code=${result.lineageCode}');
    print('version_id=${result.versionId}');
    print('import_key=${result.importKey}');
    exitCode = 0;
  } on FounderProgrammeImportException catch (error) {
    print(error);
    exitCode = 65;
  } catch (error) {
    print('Import failed: $error');
    exitCode = 70;
  }
}

void _printDryRunReport(FounderProgrammeImportDryRunResult result) {
  print(result.summaryMessage);
  print('import_key=${result.importKey}');
  print('lineage_code=${result.lineageCode}');
  print('session_count=${result.sessionCount}');
  print('ready_for_apply=${result.readyForApply}');
  if (result.validationErrors.isNotEmpty) {
    print('validation_errors:');
    for (final error in result.validationErrors) {
      print('  - $error');
    }
  }
  if (result.unresolvedExerciseSlugs.isNotEmpty) {
    print('unresolved_exercise_references:');
    for (final reference in result.unresolvedExerciseSlugs) {
      print('  - $reference');
    }
  }
  if (result.warnings.isNotEmpty) {
    print('warnings:');
    for (final warning in result.warnings) {
      print('  - $warning');
    }
  }
}

void _printUsage() {
  print(
    'Usage: dart run tool/import_programme.dart [--dry-run] '
    'path/to/programme.yaml',
  );
}
