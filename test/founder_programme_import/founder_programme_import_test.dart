import 'package:founder_importer/features/founder_programme_import/founder_programme_import_exception.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_import_service.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_import_validator.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_prescription_mapper.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_yaml_parser.dart';
import 'package:founder_importer/models/programme_vocabulary.dart';
import 'package:founder_importer/models/strength_exercise_prescription.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/founder_programme_import_test_support.dart';
import '../support/founder_importer_in_memory_programme_stores.dart';

void main() {
  group('FounderProgrammeYamlParser', () {
    test('parses schema version 1 document', () {
      const parser = FounderProgrammeYamlParser();
      final document = parser.parse(founderImportSampleYaml);

      expect(document.schemaVersion, 1);
      expect(document.programme.importKey, 'founder-test-v1');
      expect(document.weeks.single.days.length, 2);
      expect(
        document
            .weeks
            .single
            .days
            .first
            .sessions
            .single
            .blocks
            .single
            .exercises
            .single
            .exerciseSlug,
        'goblet-squat',
      );
    });
  });

  group('FounderProgrammePrescriptionMapper', () {
    test('maps simplified YAML prescription to structured model', () {
      const mapper = FounderProgrammePrescriptionMapper();
      final prescription = mapper.mapPrescription({
        'sets': 4,
        'reps': 8,
        'load': {'value': 24, 'unit': 'kg'},
        'rest_seconds': 90,
        'target_rpe': 8,
        'tempo': '3-0-1',
        'notes': 'Controlled reps',
      });

      expect(prescription, isNotNull);
      expect(prescription!.sets, 4);
      expect(prescription.reps.exactReps, 8);
      expect(prescription.load?.type, StrengthLoadType.fixedKg);
      expect(prescription.load?.kg, 24);
      expect(prescription.restSeconds, 90);
      expect(prescription.coachCue, 'Controlled reps');
    });

    test('maps duration and max effort reps', () {
      const mapper = FounderProgrammePrescriptionMapper();
      final duration = mapper.mapPrescription({
        'sets': 2,
        'reps': {'type': 'duration', 'text': '20-30 seconds'},
        'rest_seconds': 30,
      });
      expect(duration!.reps.type, StrengthRepType.duration);

      final amrap = mapper.mapPrescription({
        'sets': 3,
        'reps': {'type': 'max_effort', 'text': 'AMRAP'},
        'rest_seconds': 90,
      });
      expect(amrap!.reps.type, StrengthRepType.maxEffort);
    });
  });

  group('FounderProgrammeImportValidator', () {
    test('rejects unsupported schema version before import', () async {
      const parser = FounderProgrammeYamlParser();
      final document = parser.parse(
        founderImportSampleYaml.replaceFirst(
          'schema_version: 1',
          'schema_version: 99',
        ),
      );

      final tables = InMemoryProgrammeTables();
      final store = InMemoryProgrammeVersionStore(tables);
      const validator = FounderProgrammeImportValidator();
      final errors = await validator.validate(
        document: document,
        exerciseResolver: FounderProgrammeExerciseResolver.fromCatalogue(
          founderImportTestExercises(),
        ),
        versionStore: store,
      );

      expect(errors, contains('schema_version must be 1.'));
    });

    test('rejects unknown exercise slug', () async {
      const parser = FounderProgrammeYamlParser();
      final document = parser.parse(founderImportSampleYaml);

      const validator = FounderProgrammeImportValidator();
      final errors = await validator.validate(
        document: document,
        exerciseResolver: FounderProgrammeExerciseResolver.fromCatalogue(
          const [],
        ),
        versionStore: InMemoryProgrammeVersionStore(InMemoryProgrammeTables()),
      );

      expect(errors.any((error) => error.contains('goblet-squat')), isTrue);
    });
  });

  group('FounderProgrammeImportService', () {
    late InMemoryProgrammeTables tables;
    late InMemoryProgrammeVersionStore store;
    late RecordingFounderProgrammeProtocolWriter protocolWriter;

    setUp(() {
      tables = InMemoryProgrammeTables();
      store = InMemoryProgrammeVersionStore(tables);
      protocolWriter = RecordingFounderProgrammeProtocolWriter();
    });

    FounderProgrammeImportService buildService() {
      return FounderProgrammeImportService(
        versionStore: store,
        protocolWriter: protocolWriter,
        exerciseResolver: FounderProgrammeExerciseResolver.fromCatalogue(
          founderImportTestExercises(),
        ),
      );
    }

    test('dry-run passes for valid YAML without writing protocols', () async {
      final result = await buildService().dryRunYaml(
        yamlSource: founderImportSampleYaml,
      );

      expect(result.readyForApply, isTrue);
      expect(result.validationErrors, isEmpty);
      expect(result.sessionCount, 1);
      expect(result.wouldCreateLineage, isTrue);
      expect(protocolWriter.drafts, isEmpty);
    });

    test('creates draft programme and sessions from valid YAML', () async {
      final result = await buildService().importYaml(
        yamlSource: founderImportSampleYaml,
        coachId: 'coach-lee',
      );

      expect(result.created, isTrue);
      expect(result.importKey, 'founder-test-v1');
      expect(protocolWriter.drafts, hasLength(1));
      expect(protocolWriter.drafts.single.published, isFalse);
      expect(
        protocolWriter
            .drafts
            .single
            .blocks
            .single
            .linkedExercises
            .single
            .exerciseId,
        'GOBLET-SQ',
      );

      final version = await store.getVersionById(result.versionId);
      expect(version?.lifecycleStatus, ProgrammeLifecycleStatus.draft);
      expect(version?.isDraft, isTrue);

      final tree = await store.loadTemplateTree(result.versionId);
      expect(tree?.weekNodes.single.days.length, 2);
      expect(tree?.weekNodes.single.days.last.day.isRestDay, isTrue);
    });

    test(
      'rerunning import_key updates draft without duplicate lineage',
      () async {
        final service = buildService();
        final first = await service.importYaml(
          yamlSource: founderImportSampleYaml,
          coachId: 'coach-lee',
        );
        final second = await service.importYaml(
          yamlSource: founderImportSampleYaml,
          coachId: 'coach-lee',
        );

        expect(second.created, isFalse);
        expect(second.lineageId, first.lineageId);
        expect(second.versionId, first.versionId);
        expect(
          tables.lineages.where(
            (lineage) => lineage.importKey == 'founder-test-v1',
          ),
          hasLength(1),
        );
      },
    );

    test('fails when matching import_key is already published', () async {
      final service = buildService();
      final imported = await service.importYaml(
        yamlSource: founderImportSampleYaml,
        coachId: 'coach-lee',
      );

      final version = await store.getVersionById(imported.versionId);
      tables.versions
        ..removeWhere((row) => row.id == imported.versionId)
        ..add(
          version!.copyWith(
            lifecycleStatus: ProgrammeLifecycleStatus.published,
            publishedAt: DateTime.now().toUtc(),
          ),
        );

      expect(
        () => service.importYaml(
          yamlSource: founderImportSampleYaml,
          coachId: 'coach-lee',
        ),
        throwsA(isA<FounderProgrammeImportException>()),
      );
    });
  });
}
