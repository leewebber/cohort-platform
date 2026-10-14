import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:founder_importer/data/repositories/programme_version_store.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_identity_resolution.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_import_validator.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_prescription_mapper.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_yaml_parser.dart';
import 'package:founder_importer/features/programme/models/programme_catalog_entry.dart';
import 'package:founder_importer/features/programme/models/programme_template.dart';
import 'package:founder_importer/models/exercise.dart' as importer;
import 'package:founder_importer/models/programme_lineage.dart';
import 'package:founder_importer/models/programme_version.dart';

import 'synthetic_fixture_identity_adapter.dart';
import 'synthetic_strength_lineage.dart';
import '../../../domain/exercise_knowledge/in_memory/in_memory_transitional_exercise_id_bridge.dart';
import '../../../domain/exercise_knowledge/models/exercise_definition.dart';
import '../../../domain/exercise_knowledge/models/exercise_identity_mapping.dart';
import '../../../domain/exercise_knowledge/vocabulary/exercise_lifecycle_status.dart';
import '../../../models/protocol_draft.dart';
import '../../../models/session_block.dart';
import '../../../models/session_block_exercise_link.dart';
import '../../../models/session_block_type.dart';
import '../../../models/strength_exercise_prescription.dart';
import '../../../models/training_content_vocabulary.dart';
import '../../../models/workout_format.dart';
import '../../session/models/session_execution_plan.dart';
import '../../session_builder/services/protocol_draft_block_resolver.dart';
import '../../session_builder/services/session_block_validation.dart';
import '../../session_builder/services/session_execution_plan_builder.dart';
import '../../session_revision/models/session_revision_usage_models.dart';
import 'founder_strength_source_guard.dart';
import 'protocol_authoring_fixtures.dart';

String d2SourceDigest(String bytes) =>
    sha256.convert(utf8.encode(bytes)).toString();

/// Immutable local compiler receipt. Source bytes, identity and typed meaning
/// are separate from the existing Plan Package hash.
class D2CompiledSession {
  D2CompiledSession._({
    required this.source,
    required this.identity,
    required this.protocol,
    required Map<String, String> bindings,
    required this.semanticJson,
    required this.profileFingerprint,
  }) : bindings = Map.unmodifiable(bindings),
       sourceDigest = d2SourceDigest(source);
  final String source;
  final String sourceDigest;
  final SessionRevisionIdentity identity;
  final ProtocolDraft protocol;
  final Map<String, String> bindings;
  final String semanticJson;
  final String profileFingerprint;
  SessionExecutionPlan get execution =>
      const SessionExecutionPlanBuilder().build(
        sessionId: identity.protocolId,
        sessionTitle: protocol.name,
        blocks: protocol.blocks,
        durationMin: protocol.durationMin,
        coachNotes: protocol.coachingNotes,
      );
}

/// Local composition of established components, never an import/apply service.
class SyntheticStrengthSessionCompiler {
  SyntheticStrengthSessionCompiler({
    List<ExerciseDefinition>? definitions,
    List<ExerciseIdentityMapping>? mappings,
    D2ReadOnlyVersionStore? store,
    this.allowSecondLineage = false,
  }) : _definitions = List.unmodifiable(
         (definitions ?? d2ExerciseDefinitions()).map(
           (d) => ExerciseDefinition.fromJson(
             jsonDecode(jsonEncode(d.toJson())) as Map<String, dynamic>,
           ),
         ),
       ),
       _mappings = List.unmodifiable(
         (mappings ?? d2IdentityMappings()).map(
           (m) => ExerciseIdentityMapping.fromJson(m.toJson()),
         ),
       ),
       store = store ?? D2ReadOnlyVersionStore();
  final List<ExerciseDefinition> _definitions;
  final List<ExerciseIdentityMapping> _mappings;
  final D2ReadOnlyVersionStore store;
  final bool allowSecondLineage;
  String get profileFingerprint => fixtureSnapshotFingerprint(
    _definitions.map((d) => d.toJson()),
    _mappings.map((m) => m.toJson()),
  );

  Future<D2CompiledSession> compileExact(
    String source,
    SessionRevisionIdentity identity,
  ) async {
    final lineage = SyntheticStrengthLineage.resolve(
      identity,
      allowSecond: allowSecondLineage,
    );
    const FounderStrengthSourceGuard().read(
      source,
      importKey: lineage.importKey(identity.revisionNumber),
    );
    final document = const FounderProgrammeYamlParser().parse(source);
    if (_mappings.map((m) => m.id).toSet().length != _mappings.length) {
      throw const FormatException(
        'conflicting_transitional_mapping: duplicate mapping record identity.',
      );
    }
    final bridge = InMemoryTransitionalExerciseIdBridge(initial: _mappings);
    final catalogue = [
      for (final d in _definitions)
        importer.Exercise(
          exerciseId: d.id.value,
          name: d.canonicalName,
          published:
              d.lifecycleStatus == ExerciseLifecycleStatus.published &&
              d.version.trim().isNotEmpty,
        ),
    ];
    final validation = await const FounderProgrammeImportValidator().validate(
      document: document,
      exerciseResolver: FounderProgrammeExerciseResolver.fromCatalogue(
        catalogue,
        transitionalIdentityResolver: SyntheticFixtureIdentityAdapter(bridge),
      ),
      versionStore: store,
    );
    if (!validation.isValid) {
      throw FormatException(validation.validationErrors.join('\n'));
    }
    final session = document.weeks.single.days.single.sessions.single;
    final block = session.blocks.single;
    final bindings = <String, String>{};
    final links = <SessionBlockExerciseLink>[];
    for (final exercise in block.exercises) {
      final id = validation.identityPlan.canonicalIdAt(
        FounderProgrammeExerciseLocation(
          importKey: document.programme.importKey,
          weekNumber: 1,
          dayNumber: 1,
          sessionOrder: 1,
          blockOrder: 1,
          exerciseOrder: exercise.order,
        ),
      );
      if (id != 'EX-9001' && id != 'EX-9002') {
        throw const FormatException('fixture_identity: foreign target.');
      }
      final definition = _definitions.singleWhere((d) => d.id.value == id);
      final transitional = exercise.transitionalExerciseId!;
      if (transitional != 'cohort.exercise.d2_fixture_a' &&
          transitional != 'cohort.exercise.d2_fixture_b') {
        throw const FormatException(
          'fixture_identity: foreign transitional identity.',
        );
      }
      bindings[transitional] = '$id@${definition.version}';
      final mapped = const FounderProgrammePrescriptionMapper().mapPrescription(
        exercise.prescription,
      )!;
      final prescription = StrengthExercisePrescription.fromJson(
        mapped.toJson(),
      );
      // These shared factories must agree on the entire supported subset.
      if (jsonEncode(prescription.toJson()) != jsonEncode(mapped.toJson())) {
        throw const FormatException(
          'compiler_compatibility: strength conversion loses fields.',
        );
      }
      links.add(
        SessionBlockExerciseLink(
          localId: 'd2-link-${exercise.order}',
          exerciseId: id,
          position: exercise.order,
          displayLabelOverride: exercise.exerciseName,
          prescription: prescription,
        ),
      );
    }
    final blocks = List<SessionBlock>.unmodifiable([
      SessionBlock(
        localId: 'd2-block-1',
        blockType: SessionBlockType.strength,
        title: block.title,
        content: '',
        workoutFormat: WorkoutFormat.none,
        position: 1,
        coachNotes: block.coachNotes,
        linkedExercises: List.unmodifiable(links),
      ),
    ]);
    final errors = const SessionBlockValidation().validateSession(
      name: session.title,
      blocks: blocks,
    );
    if (errors.isNotEmpty) throw FormatException(errors.join('\n'));
    final protocol = ProtocolDraft(
      protocolId: identity.protocolId,
      name: session.title,
      steps: const [],
      blocks: blocks,
      published: false,
      contentKind: TrainingContentKind.session,
      authoringScope: TrainingAuthoringScope.programmeOnly,
      endorsementStatus: TrainingEndorsementStatus.coachAuthored,
      sessionLineageId: identity.sessionLineageId,
      revisionNumber: identity.revisionNumber,
      sessionType: 'strength',
      sessionFormat: 'structured_strength',
      durationMin: session.estimatedDurationMinutes,
      coachingNotes: session.coachNotes,
    );
    final legacy = const ProtocolDraftBlockResolver().resolveSteps(protocol);
    if (legacy.length != links.length) {
      throw const FormatException(
        'compiler_compatibility: legacy projection count.',
      );
    }
    final meaning = {
      'title': protocol.name,
      'duration_minutes': protocol.durationMin,
      'coach_notes': protocol.coachingNotes,
      'bindings': bindings,
      'block': {
        'title': block.title,
        'coach_notes': block.coachNotes,
        'exercises': [
          for (final link in links)
            {
              'exercise_id': link.exerciseId,
              'position': link.position,
              'label': link.displayLabelOverride,
              'prescription': link.prescription!.toJson(),
            },
        ],
      },
    };
    final result = D2CompiledSession._(
      source: source,
      identity: identity,
      protocol: protocol,
      bindings: bindings,
      semanticJson: jsonEncode(meaning),
      profileFingerprint: profileFingerprint,
    );
    if (result.execution.blocks.single.linkedExercises.length != links.length) {
      throw const FormatException(
        'compiler_compatibility: execution projection count.',
      );
    }
    return result;
  }
}

/// Only the synthetic validation reads used by the established validator exist.
/// All writes fail loudly; no hidden storage backend or network implementation.
class D2ReadOnlyVersionStore implements ProgrammeVersionStore {
  int mutationAttempts = 0;
  Never _write() {
    mutationAttempts++;
    throw StateError('D2 prohibits programme writes.');
  }

  @override
  Future<ProgrammeLineage?> getLineageByCode(String code) async => null;
  @override
  Future<ProgrammeLineage?> getLineageByImportKey(String importKey) async =>
      null;
  @override
  Future<ProgrammeVersion?> getVersionByLineageAndNumber({
    required String lineageCode,
    required int versionNumber,
  }) async => null;
  @override
  Future<ProgrammeLineage?> getLineageById(String lineageId) =>
      throw UnsupportedError('Not a synthetic validation read.');
  @override
  Future<ProgrammeVersion?> getVersionById(String versionId) =>
      throw UnsupportedError('Not a synthetic validation read.');
  @override
  Future<ProgrammeVersion?> getPublishedVersion({
    required String lineageCode,
    required int versionNumber,
  }) => throw UnsupportedError('Not a synthetic validation read.');
  @override
  Future<ProgrammeTemplateTree?> loadTemplateTree(String versionId) =>
      throw UnsupportedError('Not a synthetic validation read.');
  @override
  Future<List<ProgrammeCatalogEntry>> listCatalogueVersions(
    ProgrammeCatalogueQuery query,
  ) => throw UnsupportedError('Not a synthetic validation read.');
  @override
  Future<ProgrammeVersion> saveDraftVersion(ProgrammeVersion version) =>
      _write();
  @override
  Future<void> saveTemplateTree({
    required ProgrammeVersion version,
    required ProgrammeTemplateTree tree,
  }) => _write();
  @override
  Future<ProgrammeLineage> insertLineage(ProgrammeLineage lineage) => _write();
  @override
  Future<void> deleteDraftVersion(String versionId) => _write();
}
