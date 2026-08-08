import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cohort_platform/core/utils/database_uuid.dart';
import 'package:cohort_platform/data/repositories/session_lineage_store.dart';
import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/features/admin/services/protocol_builder_service.dart';
import 'package:cohort_platform/features/authored_plan_package/authored_plan_package.dart';
import 'package:cohort_platform/features/programme_builder/authoring/programme_code_authoring.dart';
import 'package:cohort_platform/features/session_revision/models/session_revision_usage_models.dart';
import 'package:cohort_platform/models/protocol_builder_save_result.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/session_block_exercise_link.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/session_lineage.dart';
import 'package:cohort_platform/models/session_revision_vocabulary.dart';
import 'package:cohort_platform/models/strength_exercise_prescription.dart';
import 'package:cohort_platform/models/training_content_vocabulary.dart';
import 'package:cohort_platform/staging_tooling/journey_d/journey_d_rebind.dart';
import 'package:flutter_test/flutter_test.dart';

/// CURRENT publication failure: non-UUID programme_version_id → PostgREST 22P02.
///
/// Local only — exercises real [ProtocolBuilderJourneyDPublisher] + real
/// [ProtocolBuilderService.validateDraft]. No hosted staging contact.
void main() {
  final root = Directory.current.path;
  final packageYaml = File(
    '$root/tool/staging/fixtures/journey_d/prog_s17_journey_d_adaptation.yaml',
  ).readAsStringSync();
  final intentJson = File(
    '$root/tool/staging/fixtures/journey_d/protocol_intent.json',
  ).readAsStringSync();

  const currentUuid = 'a1111111-1111-4111-8111-111111111111';
  const laterUuid = 'b2222222-2222-4222-8222-222222222222';

  final currentIntent = const JourneyDProtocolPublicationIntent(
    order: 1,
    role: 'current_equipment_conflict',
    protocolId: 'PROT-S17-JD-ADAPT-CURRENT',
    sessionKey: 'SES-JD-ADAPT-CURRENT',
    symbolicSessionLineageId: 'SL-S17-JD-ADAPT-CURRENT',
    revisionNumber: 1,
    exerciseId: 'cohort.exercise.back_squat',
    replacementExerciseId: 'cohort.exercise.goblet_squat',
    substitutionRuleId: 'cohort.substitution.back_squat_to_goblet_squat',
    canReplaceExercises: true,
  );
  final laterIntent = const JourneyDProtocolPublicationIntent(
    order: 2,
    role: 'unaffected_occurrence_baseline',
    protocolId: 'PROT-S17-JD-ADAPT-LATER',
    sessionKey: 'SES-JD-ADAPT-LATER',
    symbolicSessionLineageId: 'SL-S17-JD-ADAPT-LATER',
    revisionNumber: 1,
    exerciseId: 'cohort.exercise.push_up',
  );

  ProtocolDraft poisonedDraft(JourneyDProtocolPublicationIntent intent) {
    return programmeSession(
      protocolId: intent.protocolId,
      name: 'S17 Journey D ${intent.role}',
      programmeVersionId: ProtocolBuilderJourneyDPublisher
          .retiredNonUuidProgrammeVersionPlaceholder,
      ownerId: null,
      sessionFormat: ProtocolBuilderJourneyDPublisher.fixtureSessionFormat,
      durationMin: 45,
      primarySessionIntent: SessionIntent.lowerBodyStrength,
      minimumViableDurationMin: 25,
      blocks: [
        block(
          localId: 'block-main',
          type: SessionBlockType.strength,
          position: 1,
          title: 'Main',
          blockPriority: BlockPriority.essential,
          adaptationPolicy: BlockAdaptationPolicy(
            canRemove: false,
            canShorten: false,
            canReduceVolume: true,
            canReduceIntensity: true,
            canIncreaseRest: true,
            canSuperset: false,
            canReplaceExercises: intent.canReplaceExercises,
            canReplaceBlock: false,
            minimumViablePrescription: const MinimumViablePrescription(sets: 2),
          ),
          linkedExercises: [
            SessionBlockExerciseLink(
              localId: 'link-1',
              exerciseId: intent.exerciseId,
              position: 1,
              prescription: StrengthExercisePrescription(
                sets: 3,
                reps: StrengthRepPrescription.exact(5),
                restSeconds: 120,
              ),
            ),
          ],
        ),
      ],
    ).copyWith(revisionNumber: intent.revisionNumber);
  }

  test('exact failure: retired placeholder is non-UUID programme_version_id', () {
    const poisoned =
        ProtocolBuilderJourneyDPublisher.retiredNonUuidProgrammeVersionPlaceholder;
    expect(DatabaseUuid.isValidDatabaseUuid(poisoned), isFalse);
    final map = poisonedDraft(currentIntent).toProtocolMap();
    expect(map['programme_version_id'], poisoned);
    expect(map['content_kind'], 'session');
    expect(map['authoring_scope'], 'programme_only');
  });

  test('repaired CURRENT/LATER match Protocol Builder contract', () {
    final service = ProtocolBuilderService();
    for (final intent in [currentIntent, laterIntent]) {
      final draft = ProtocolBuilderJourneyDPublisher.draftFor(intent);
      expect(draft.sessionFormat, 'structured_strength');
      expect(draft.contentKind, TrainingContentKind.cohortProtocol);
      expect(draft.authoringScope, TrainingAuthoringScope.cohortGlobal);
      expect(draft.endorsementStatus, TrainingEndorsementStatus.cohortEndorsed);
      expect(draft.programmeVersionId, isNull);
      expect(draft.ownerId, isNull);
      final map = draft.toProtocolMap();
      expect(map['programme_version_id'], isNull);
      expect(map['content_kind'], 'cohort_protocol');
      expect(
        map['programme_version_id'],
        isNot(
          ProtocolBuilderJourneyDPublisher
              .retiredNonUuidProgrammeVersionPlaceholder,
        ),
      );
      service.validateDraft(draft);
    }
    expect(
      ProtocolBuilderJourneyDPublisher.draftFor(currentIntent)
          .blocks
          .single
          .linkedExercises
          .single
          .exerciseId,
      'cohort.exercise.back_squat',
    );
    expect(
      ProtocolBuilderJourneyDPublisher.draftFor(laterIntent)
          .blocks
          .single
          .linkedExercises
          .single
          .exerciseId,
      'cohort.exercise.push_up',
    );
  });

  test('programme YAML hash and coaching semantics unchanged', () {
    final compile = const PlanPackageCompiler().compile(packageYaml);
    expect(compile.isValid, isTrue);
    expect(
      compile.contentHashSha256,
      '156dfe8cf262e43f4e7e47cab070a37f466d3271fe26b29ca80e5c5e49e8a7d7',
    );
    expect(intentJson, contains('cohort.exercise.back_squat'));
    expect(intentJson, contains('cohort.exercise.goblet_squat'));
    expect(intentJson, contains('cohort.exercise.push_up'));
    expect(packageYaml, contains('athlete_agreement_required: true'));
  });

  test('real adapter retains PostgREST 22P02 behind generic save message',
      () async {
    final service = _RecordingBuilderService(
      publishError: const ProtocolBuilderException(
        'We could not save your protocol right now. Please try again.',
        postgrestCode: '22P02',
        postgrestMessage:
            'invalid input syntax for type uuid: "s17-jd-adapt-fixture-programme-version"',
      ),
    );
    final publisher = ProtocolBuilderJourneyDPublisher(
      protocolBuilderService: service,
      sessionLineageStore: _FakeLineageStore(),
    );
    final result = await publisher.publish(currentIntent);
    expect(result.state, JourneyDPublicationStageState.unknown);
    expect(result.detail, startsWith('publishDraft_adapter_error:'));
    expect(result.detail, contains('code=22P02'));
    expect(result.detail, contains('invalid input syntax for type uuid'));
    expect(
      result.detail,
      contains('We could not save your protocol right now. Please try again.'),
    );
    // Secrets/emails redacted helper still applied; placeholder text is OK.
    expect(result.writeAccounting.requestDispatched, isTrue);
    expect(result.writeAccounting.responseReceived, isTrue);
    expect(service.publishCalls, 1);
    expect(service.lastPublishedDraft?.programmeVersionId, isNull);
  });

  test('real adapter publishes CURRENT and LATER through application service',
      () async {
    final service = _RecordingBuilderService();
    final publisher = ProtocolBuilderJourneyDPublisher(
      protocolBuilderService: service,
      sessionLineageStore: _FakeLineageStore(
        identities: {
          'PROT-S17-JD-ADAPT-CURRENT': currentUuid,
          'PROT-S17-JD-ADAPT-LATER': laterUuid,
        },
      ),
    );
    final current = await publisher.publish(currentIntent);
    final later = await publisher.publish(laterIntent);
    expect(current.state, JourneyDPublicationStageState.applied);
    expect(later.state, JourneyDPublicationStageState.applied);
    expect(current.returnedSessionLineageId, currentUuid);
    expect(later.returnedSessionLineageId, laterUuid);
    expect(service.publishCalls, 2);
    expect(service.publishedProtocolIds, [
      'PROT-S17-JD-ADAPT-CURRENT',
      'PROT-S17-JD-ADAPT-LATER',
    ]);
    for (final draft in service.publishedDrafts) {
      expect(draft.sessionFormat, 'structured_strength');
      expect(draft.programmeVersionId, isNull);
      expect(draft.contentKind, TrainingContentKind.cohortProtocol);
    }
  });

  test('loopback rejects poisoned UUID body; accepts repaired upsert shape',
      () async {
    final received = <Map<String, dynamic>>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async => server.close(force: true));
    unawaited(
      server.forEach((req) async {
        final body = await utf8.decoder.bind(req).join();
        final decoded = body.isEmpty
            ? <String, dynamic>{}
            : Map<String, dynamic>.from(jsonDecode(body) as Map);
        received.add({
          'method': req.method,
          'path': req.uri.path,
          'body': decoded,
        });
        final pv = decoded['programme_version_id'];
        if (pv is String &&
            pv.isNotEmpty &&
            !DatabaseUuid.isValidDatabaseUuid(pv)) {
          req.response.statusCode = 400;
          req.response.headers.contentType = ContentType.json;
          req.response.write(
            jsonEncode({
              'code': '22P02',
              'message': 'invalid input syntax for type uuid: "$pv"',
            }),
          );
        } else {
          req.response.statusCode = 201;
          req.response.headers.contentType = ContentType.json;
          req.response.write(
            jsonEncode({
              'protocol_id': decoded['protocol_id'],
              'programme_version_id': pv,
            }),
          );
        }
        await req.response.close();
      }),
    );

    Future<Map<String, dynamic>> postUpsert(Map<String, dynamic> map) async {
      final client = HttpClient();
      final req = await client.postUrl(
        Uri.parse(
          'http://127.0.0.1:${server.port}/rest/v1/performance_protocols',
        ),
      );
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(map));
      final resp = await req.close();
      final text = await utf8.decoder.bind(resp).join();
      client.close(force: true);
      return {
        'status': resp.statusCode,
        'body': jsonDecode(text),
      };
    }

    final poisoned = await postUpsert(poisonedDraft(currentIntent).toProtocolMap());
    expect(poisoned['status'], 400);
    expect((poisoned['body'] as Map)['code'], '22P02');

    final repaired = await postUpsert(
      ProtocolBuilderJourneyDPublisher.draftFor(currentIntent).toProtocolMap(),
    );
    expect(repaired['status'], 201);
    expect((repaired['body'] as Map)['programme_version_id'], isNull);

    expect(received.length, 2);
    expect(received.first['method'], 'POST');
    expect(received.first['path'], '/rest/v1/performance_protocols');
  });
}

class _RecordingBuilderService extends ProtocolBuilderService {
  _RecordingBuilderService({this.publishError});

  final ProtocolBuilderException? publishError;
  int publishCalls = 0;
  final publishedDrafts = <ProtocolDraft>[];
  ProtocolDraft? lastPublishedDraft;
  List<String> get publishedProtocolIds =>
      publishedDrafts.map((d) => d.protocolId).toList();

  @override
  Future<ProtocolBuilderSaveResult> publishDraft(ProtocolDraft draft) async {
    publishCalls += 1;
    lastPublishedDraft = draft;
    publishedDrafts.add(draft);
    validateDraft(draft);
    if (publishError != null) throw publishError!;
    return ProtocolBuilderSaveResult.published(
      protocolId: draft.protocolId,
      created: true,
      stepCount: 1,
    );
  }
}

class _FakeLineageStore implements SessionLineageStore {
  _FakeLineageStore({this.identities = const {}});

  final Map<String, String> identities;

  @override
  Future<SessionLineage> insertLineage({
    required String displayName,
    String? id,
  }) async {
    return SessionLineage(
      id: id ?? 'a1111111-1111-4111-8111-111111111111',
      displayName: displayName,
    );
  }

  @override
  Future<SessionRevisionIdentity?> getRevisionIdentity(
    String protocolId,
  ) async {
    final lineage =
        identities[protocolId] ?? 'a1111111-1111-4111-8111-111111111111';
    return SessionRevisionIdentity(
      protocolId: protocolId,
      sessionLineageId: lineage,
      revisionNumber: 1,
    );
  }

  @override
  Future<SessionLineage?> getLineageById(String lineageId) async => null;

  @override
  Future<int> getMaxRevisionNumber(String lineageId) async => 0;

  @override
  Future<SessionRevisionLifecycleStatus?> getRevisionLifecycleStatus(
    String protocolId,
  ) async =>
      null;

  @override
  Future<String?> getLineageIdForRevision(String protocolId) async => null;

  @override
  Future<void> updateRevisionLifecycle({
    required String protocolId,
    required SessionRevisionLifecycleStatus lifecycleStatus,
    DateTime? publishedAt,
    DateTime? archivedAt,
  }) async {}

  @override
  Future<void> assignRevisionLineage({
    required String protocolId,
    required String sessionLineageId,
    required int revisionNumber,
    required SessionRevisionLifecycleStatus lifecycleStatus,
    DateTime? publishedAt,
  }) async {}
}
