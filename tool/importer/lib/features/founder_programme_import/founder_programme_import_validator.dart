import 'package:founder_importer/data/repositories/programme_version_store.dart';
import 'package:founder_importer/features/programme_builder/services/programme_builder_compiler.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_import_models.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_import_schema.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_prescription_mapper.dart';

class FounderProgrammeImportValidator {
  const FounderProgrammeImportValidator({
    ProgrammeBuilderCompiler compiler = const ProgrammeBuilderCompiler(),
    FounderProgrammePrescriptionMapper prescriptionMapper =
        const FounderProgrammePrescriptionMapper(),
  }) : _compiler = compiler,
       _prescriptionMapper = prescriptionMapper;

  final ProgrammeBuilderCompiler _compiler;
  final FounderProgrammePrescriptionMapper _prescriptionMapper;

  Future<List<String>> validate({
    required FounderProgrammeYamlDocument document,
    required FounderProgrammeExerciseResolver exerciseResolver,
    required ProgrammeVersionStore versionStore,
  }) async {
    final errors = <String>[];

    if (document.schemaVersion !=
        FounderProgrammeImportSchema.supportedSchemaVersion) {
      errors.add(
        'schema_version must be ${FounderProgrammeImportSchema.supportedSchemaVersion}.',
      );
    }

    final programme = document.programme;
    if (!_isValidImportKey(programme.importKey)) {
      errors.add(
        'programme.import_key must be a non-empty kebab-case identifier.',
      );
    }

    if (!_compiler.isValidLineageCode(programme.code)) {
      errors.add('programme.code is not a valid lineage code.');
    }

    if (programme.durationWeeks <= 0) {
      errors.add('programme.duration_weeks must be at least 1.');
    }

    if (document.weeks.isEmpty) {
      errors.add('weeks must contain at least one week.');
    }

    if (document.weeks.length != programme.durationWeeks) {
      errors.add(
        'programme.duration_weeks (${programme.durationWeeks}) must match weeks count (${document.weeks.length}).',
      );
    }

    final weekNumbers = <int>{};
    for (final week in document.weeks) {
      if (week.weekNumber <= 0) {
        errors.add('week_number must be positive (week ${week.weekNumber}).');
      }
      if (!weekNumbers.add(week.weekNumber)) {
        errors.add('Duplicate week_number ${week.weekNumber}.');
      }
      if (week.days.isEmpty) {
        errors.add('week ${week.weekNumber} must include at least one day.');
      }

      final dayNumbers = <int>{};
      for (final day in week.days) {
        if (day.dayNumber <= 0) {
          errors.add(
            'day_number must be positive (week ${week.weekNumber}, day ${day.dayNumber}).',
          );
        }
        if (!dayNumbers.add(day.dayNumber)) {
          errors.add(
            'Duplicate day_number ${day.dayNumber} in week ${week.weekNumber}.',
          );
        }

        if (day.isRestDay && day.sessions.isNotEmpty) {
          errors.add(
            'Rest day week ${week.weekNumber} day ${day.dayNumber} cannot include sessions.',
          );
        }

        if (!day.isRestDay && day.sessions.isEmpty) {
          errors.add(
            'Training day week ${week.weekNumber} day ${day.dayNumber} must include at least one session.',
          );
        }

        final sessionOrders = <int>{};
        for (
          var sessionIndex = 0;
          sessionIndex < day.sessions.length;
          sessionIndex++
        ) {
          final session = day.sessions[sessionIndex];
          final sessionOrder = sessionIndex + 1;
          if (!sessionOrders.add(sessionOrder)) {
            errors.add(
              'Duplicate session order $sessionOrder on week ${week.weekNumber} day ${day.dayNumber}.',
            );
          }
          final sessionPath =
              'week ${week.weekNumber} day ${day.dayNumber} session $sessionOrder';

          if (!FounderProgrammeImportSchema.allowedSessionTypes.contains(
            session.sessionType.trim().toLowerCase(),
          )) {
            errors.add(
              '$sessionPath has unsupported session_type "${session.sessionType}".',
            );
          }

          if (session.blocks.isEmpty) {
            errors.add('$sessionPath must include at least one block.');
          }

          final blockOrders = <int>{};
          for (
            var blockIndex = 0;
            blockIndex < session.blocks.length;
            blockIndex++
          ) {
            final block = session.blocks[blockIndex];
            final blockPath = '$sessionPath block ${blockIndex + 1}';

            if (!FounderProgrammeImportSchema.allowedBlockTypes.contains(
              block.blockType.trim().toLowerCase(),
            )) {
              errors.add(
                '$blockPath has unsupported block_type "${block.blockType}".',
              );
            }
            if (!blockOrders.add(block.order)) {
              errors.add('$blockPath duplicate block order ${block.order}.');
            }

            if (block.exercises.isEmpty) {
              errors.add('$blockPath must include at least one exercise.');
            }

            final exerciseOrders = <int>{};
            for (
              var exerciseIndex = 0;
              exerciseIndex < block.exercises.length;
              exerciseIndex++
            ) {
              final exercise = block.exercises[exerciseIndex];
              final exercisePath = '$blockPath exercise ${exerciseIndex + 1}';

              if (!exerciseOrders.add(exercise.order)) {
                errors.add(
                  '$exercisePath duplicate exercise order ${exercise.order}.',
                );
              }

              final exerciseError = exerciseResolver.validationError(
                exercise,
                exercisePath,
              );
              if (exerciseError != null) {
                errors.add(exerciseError);
              }

              errors.addAll(
                _prescriptionMapper
                    .validatePrescription(exercise.prescription)
                    .map((message) => '$exercisePath $message'),
              );
            }
          }
        }
      }
    }

    final existingByImportKey = await versionStore.getLineageByImportKey(
      programme.importKey,
    );
    if (existingByImportKey != null &&
        existingByImportKey.code.trim() != programme.code.trim()) {
      errors.add(
        'import_key "${programme.importKey}" already belongs to lineage code ${existingByImportKey.code}.',
      );
    }

    final existingByCode = await versionStore.getLineageByCode(programme.code);
    if (existingByCode != null &&
        existingByCode.importKey != null &&
        existingByCode.importKey!.trim() != programme.importKey.trim()) {
      errors.add(
        'programme.code "${programme.code}" is already used by import_key ${existingByCode.importKey}.',
      );
    }

    if (existingByCode != null && existingByCode.importKey == null) {
      errors.add(
        'programme.code "${programme.code}" already exists outside the founder importer.',
      );
    }

    if (existingByImportKey != null) {
      final version = await versionStore.getVersionByLineageAndNumber(
        lineageCode: existingByImportKey.code,
        versionNumber: 1,
      );
      if (version != null && version.isPublished) {
        errors.add(
          'import_key "${programme.importKey}" is already published. Use a new import_key to import a new version.',
        );
      }
    }

    return errors;
  }

  bool _isValidImportKey(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    return RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(trimmed);
  }
}
