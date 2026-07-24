import 'package:founder_importer/core/utils/database_uuid.dart';
import 'package:founder_importer/data/repositories/programme_version_store.dart';
import 'package:founder_importer/features/programme/models/programme_template.dart';
import 'package:founder_importer/models/programme_lineage.dart';
import 'package:founder_importer/models/programme_version.dart';
import 'package:founder_importer/models/programme_version_day.dart';
import 'package:founder_importer/models/programme_version_session_slot.dart';
import 'package:founder_importer/models/programme_version_week.dart';
import 'package:founder_importer/models/programme_vocabulary.dart';
import 'package:founder_importer/models/protocol_draft.dart';
import 'package:founder_importer/models/session_block.dart';
import 'package:founder_importer/models/session_block_exercise_link.dart';
import 'package:founder_importer/models/session_block_type.dart';
import 'package:founder_importer/models/training_content_vocabulary.dart';
import 'package:founder_importer/models/workout_format.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_import_dry_run_result.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_import_exception.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_import_models.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_import_result.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_import_validator.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_prescription_mapper.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_protocol_writer.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_yaml_parser.dart';

class FounderProgrammeImportService {
  FounderProgrammeImportService({
    required ProgrammeVersionStore versionStore,
    required FounderProgrammeProtocolWriter protocolWriter,
    required FounderProgrammeExerciseResolver exerciseResolver,
    FounderProgrammeYamlParser parser = const FounderProgrammeYamlParser(),
    FounderProgrammeImportValidator validator =
        const FounderProgrammeImportValidator(),
    FounderProgrammePrescriptionMapper prescriptionMapper =
        const FounderProgrammePrescriptionMapper(),
  }) : _versionStore = versionStore,
       _protocolWriter = protocolWriter,
       _exerciseResolver = exerciseResolver,
       _parser = parser,
       _validator = validator,
       _prescriptionMapper = prescriptionMapper;

  final ProgrammeVersionStore _versionStore;
  final FounderProgrammeProtocolWriter _protocolWriter;
  final FounderProgrammeExerciseResolver _exerciseResolver;
  final FounderProgrammeYamlParser _parser;
  final FounderProgrammeImportValidator _validator;
  final FounderProgrammePrescriptionMapper _prescriptionMapper;

  Future<FounderProgrammeImportDryRunResult> dryRunYaml({
    required String yamlSource,
  }) async {
    final document = _parser.parse(yamlSource);
    final programme = document.programme;

    final validationErrors = await _validator.validate(
      document: document,
      exerciseResolver: _exerciseResolver,
      versionStore: _versionStore,
    );

    final unresolvedExerciseSlugs = _collectUnresolvedExerciseSlugs(document);
    final warnings = <String>[];
    final existingLineage = await _versionStore.getLineageByImportKey(
      programme.importKey,
    );
    if (existingLineage == null) {
      warnings.add('No existing lineage for import_key; apply would create new draft v1.');
    } else {
      warnings.add(
        'Existing lineage ${existingLineage.code}; apply would replace draft v1 tree and session protocols.',
      );
    }

    var sessionCount = 0;
    for (final week in document.weeks) {
      for (final day in week.days) {
        if (day.isRestDay) continue;
        sessionCount += day.sessions.length;
      }
    }

    final readyForApply = validationErrors.isEmpty;

    return FounderProgrammeImportDryRunResult(
      importKey: programme.importKey,
      lineageCode: programme.code,
      validationErrors: validationErrors,
      warnings: warnings,
      unresolvedExerciseSlugs: unresolvedExerciseSlugs,
      sessionCount: sessionCount,
      wouldCreateLineage: existingLineage == null,
      readyForApply: readyForApply,
    );
  }

  Future<FounderProgrammeImportResult> importYaml({
    required String yamlSource,
    required String coachId,
  }) async {
    final document = _parser.parse(yamlSource);

    final validationErrors = await _validator.validate(
      document: document,
      exerciseResolver: _exerciseResolver,
      versionStore: _versionStore,
    );
    if (validationErrors.isNotEmpty) {
      throw FounderProgrammeImportException(
        'Programme import validation failed.',
        validationErrors: validationErrors,
      );
    }

    final programme = document.programme;
    final existingLineage = await _versionStore.getLineageByImportKey(
      programme.importKey,
    );
    final created = existingLineage == null;

    ProgrammeLineage lineage;
    ProgrammeVersion version;
    String? rollbackVersionId;

    try {
      if (existingLineage == null) {
        lineage = await _versionStore.insertLineage(
          ProgrammeLineage(
            id: '',
            code: programme.code.trim(),
            importKey: programme.importKey.trim(),
            createdBy: coachId,
          ),
        );

        version = await _versionStore.saveDraftVersion(
          ProgrammeVersion(
            id: '',
            lineageId: lineage.id,
            versionNumber: 1,
            lifecycleStatus: ProgrammeLifecycleStatus.draft,
            libraryScope: ProgrammeLibraryScope.coachPrivate,
            ownerType: ProgrammeOwnerType.coach,
            ownerId: coachId,
            name: programme.title.trim(),
            description: programme.description,
            primaryGoal: programme.objective,
            durationWeeks: programme.durationWeeks,
            sessionsPerWeek:
                programme.sessionsPerWeek ?? _inferSessionsPerWeek(document),
            createdBy: coachId,
          ),
        );
        rollbackVersionId = version.id;
      } else {
        lineage = existingLineage;
        final existingVersion = await _versionStore
            .getVersionByLineageAndNumber(
              lineageCode: lineage.code,
              versionNumber: 1,
            );
        if (existingVersion == null) {
          throw FounderProgrammeImportException(
            'Imported lineage exists but version 1 draft is missing.',
          );
        }
        if (existingVersion.isPublished) {
          throw FounderProgrammeImportException(
            'import_key "${programme.importKey}" is published and cannot be replaced.',
          );
        }

        version = await _versionStore.saveDraftVersion(
          existingVersion.copyWith(
            name: programme.title.trim(),
            description: programme.description,
            primaryGoal: programme.objective,
            durationWeeks: programme.durationWeeks,
            sessionsPerWeek:
                programme.sessionsPerWeek ?? _inferSessionsPerWeek(document),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
      }

      var sessionCount = 0;
      final weekNodes = <ProgrammeTemplateWeekNode>[];
      final weekRows = <ProgrammeVersionWeek>[];

      for (final week in document.weeks) {
        final weekId = DatabaseUuid.newV4();
        final weekRow = ProgrammeVersionWeek(
          id: weekId,
          versionId: version.id,
          weekNumber: week.weekNumber,
          title: week.title,
        );
        weekRows.add(weekRow);

        final dayNodes = <ProgrammeTemplateDayNode>[];
        for (final day in week.days) {
          final dayId = DatabaseUuid.newV4();
          final dayRow = ProgrammeVersionDay(
            id: dayId,
            weekId: weekId,
            dayKey: 'day_${day.dayNumber}',
            dayOrder: day.dayNumber,
            title: day.displayName,
            dayType: day.isRestDay
                ? ProgrammeDayType.rest
                : ProgrammeDayType.training,
            coachNote: day.coachNotes,
          );

          final slots = <ProgrammeVersionSessionSlot>[];
          for (
            var sessionIndex = 0;
            sessionIndex < day.sessions.length;
            sessionIndex++
          ) {
            final session = day.sessions[sessionIndex];
            final sessionOrder = sessionIndex + 1;
            final protocolId = _protocolIdForSlot(
              importKey: programme.importKey,
              weekNumber: week.weekNumber,
              dayNumber: day.dayNumber,
              sessionOrder: sessionOrder,
            );

            final draft = _buildProtocolDraft(
              protocolId: protocolId,
              session: session,
              coachId: coachId,
              programmeVersionId: version.id,
            );
            await _protocolWriter.saveDraft(draft);
            sessionCount++;

            slots.add(
              ProgrammeVersionSessionSlot(
                id: DatabaseUuid.newV4(),
                dayId: dayId,
                sessionOrder: sessionOrder,
                protocolId: protocolId,
                displayTitle: session.title,
                coachNote: session.coachNotes,
              ),
            );
          }

          dayNodes.add(ProgrammeTemplateDayNode(day: dayRow, slots: slots));
        }

        weekNodes.add(ProgrammeTemplateWeekNode(week: weekRow, days: dayNodes));
      }

      final tree = ProgrammeTemplateTree(
        template: ProgrammeTemplate(version: version, weeks: weekRows),
        weekNodes: weekNodes,
      );

      await _versionStore.saveTemplateTree(version: version, tree: tree);

      final summary = created
          ? 'Created draft programme ${programme.code} (${programme.importKey}) with $sessionCount sessions.'
          : 'Updated draft programme ${programme.code} (${programme.importKey}) with $sessionCount sessions.';

      return FounderProgrammeImportResult(
        importKey: programme.importKey,
        lineageId: lineage.id,
        lineageCode: lineage.code,
        versionId: version.id,
        created: created,
        sessionCount: sessionCount,
        summaryMessage: summary,
      );
    } catch (error) {
      if (created && rollbackVersionId != null) {
        try {
          await _versionStore.deleteDraftVersion(rollbackVersionId);
        } catch (_) {
          // Best-effort cleanup only.
        }
      }
      if (error is FounderProgrammeImportException) rethrow;
      throw FounderProgrammeImportException('Programme import failed: $error');
    }
  }

  ProtocolDraft _buildProtocolDraft({
    required String protocolId,
    required FounderProgrammeYamlSession session,
    required String coachId,
    required String programmeVersionId,
  }) {
    final blocks = session.blocks
        .map(
          (block) => SessionBlock(
            localId: DatabaseUuid.newV4(),
            blockType: SessionBlockTypeDb.fromDb(block.blockType),
            title: block.title,
            content: '',
            workoutFormat: WorkoutFormat.none,
            position: block.order,
            coachNotes: block.coachNotes,
            linkedExercises: block.exercises
                .map(
                  (exercise) => SessionBlockExerciseLink(
                    localId: DatabaseUuid.newV4(),
                    exerciseId: _exerciseResolver.resolveExerciseId(exercise)!,
                    position: exercise.order,
                    prescription: _prescriptionMapper.mapPrescription(
                      exercise.prescription,
                    ),
                    displayLabelOverride: exercise.exerciseName,
                  ),
                )
                .toList(growable: false),
          ),
        )
        .toList(growable: false);

    return ProtocolDraft(
      protocolId: protocolId,
      name: session.title,
      steps: const [],
      blocks: blocks,
      published: false,
      contentKind: TrainingContentKind.session,
      authoringScope: TrainingAuthoringScope.programmeOnly,
      endorsementStatus: TrainingEndorsementStatus.coachAuthored,
      programmeVersionId: programmeVersionId,
      ownerId: coachId,
      sessionType: _mapSessionType(session.sessionType),
      sessionFormat: _mapSessionFormat(session.sessionType),
      durationMin: session.estimatedDurationMinutes,
      coachingNotes: session.coachNotes,
    );
  }

  static String _protocolIdForSlot({
    required String importKey,
    required int weekNumber,
    required int dayNumber,
    required int sessionOrder,
  }) {
    final slug = importKey.trim().toLowerCase();
    return '$slug-w$weekNumber-d$dayNumber-s$sessionOrder';
  }

  List<String> _collectUnresolvedExerciseSlugs(
    FounderProgrammeYamlDocument document,
  ) {
    final unresolved = <String>{};
    for (final week in document.weeks) {
      for (final day in week.days) {
        for (final session in day.sessions) {
          for (final block in session.blocks) {
            for (final exercise in block.exercises) {
              if (_exerciseResolver.resolveExerciseId(exercise) != null) {
                continue;
              }
              final slug = exercise.exerciseSlug?.trim();
              if (slug != null && slug.isNotEmpty) {
                unresolved.add(slug);
                continue;
              }
              final name = exercise.exerciseName?.trim();
              if (name != null && name.isNotEmpty) {
                unresolved.add(name);
              }
            }
          }
        }
      }
    }
    return unresolved.toList()..sort();
  }

  static int _inferSessionsPerWeek(FounderProgrammeYamlDocument document) {
    var maxSessions = 0;
    for (final week in document.weeks) {
      for (final day in week.days) {
        if (day.isRestDay) continue;
        if (day.sessions.length > maxSessions) {
          maxSessions = day.sessions.length;
        }
      }
    }
    return maxSessions == 0 ? 1 : maxSessions;
  }

  static String _mapSessionType(String raw) {
    return switch (raw.trim().toLowerCase()) {
      'strength' || 'accessory' || 'skill' || 'core' => 'strength',
      'conditioning' || 'circuit' => 'circuit',
      'running' || 'intervals' => 'running',
      'recovery' => 'recovery',
      _ => 'strength',
    };
  }

  static String _mapSessionFormat(String raw) {
    return switch (raw.trim().toLowerCase()) {
      'strength' || 'accessory' || 'skill' || 'core' => 'structured_strength',
      'conditioning' || 'circuit' => 'circuit',
      'running' || 'intervals' => 'intervals',
      'recovery' => 'recovery_flow',
      _ => 'structured_strength',
    };
  }
}
