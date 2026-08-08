import 'dart:convert';
import 'dart:io';

import 'package:cohort_platform/application/adaptation/journey_d_equipment_adaptation_contract.dart';
import 'package:cohort_platform/application/adaptation/plan_package_session_adaptation_adapter.dart';
import 'package:cohort_platform/application/adaptation/programme_adaptation_acceptance_service.dart';
import 'package:cohort_platform/application/adaptation/programme_adaptation_proposal_service.dart';
import 'package:cohort_platform/core/persistence/athlete_local_repository.dart';
import 'package:cohort_platform/core/persistence/local_kv_store.dart';
import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/features/adaptation/services/adaptation_policy_gate.dart';
import 'package:cohort_platform/features/authored_plan_package/plan_package_manifest.dart';
import 'package:cohort_platform/features/plans/models/programmed_session_key.dart';
import 'package:cohort_platform/features/programme/models/programme_execution_context.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_authored_slot_resolver.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_session_prepare_service.dart';
import 'package:cohort_platform/features/programme_builder/authoring/programme_code_authoring.dart';
import 'package:cohort_platform/features/session/models/prepared_execution_package.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/services/session_execution_loader.dart';
import 'package:cohort_platform/features/workout_player/models/workout_session_brief.dart';
import 'package:cohort_platform/knowledge/io/yaml_knowledge_ontology_loader.dart';
import 'package:cohort_platform/knowledge/read/in_memory_knowledge_graph_reader.dart';
import 'package:cohort_platform/models/adaptation_reason.dart';
import 'package:cohort_platform/models/adaptation_request.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/session_block_exercise_link.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/strength_exercise_prescription.dart';
import 'package:cohort_platform/staging_tooling/journey_d/journey_d_credential_handoff.dart';
import 'package:cohort_platform/staging_tooling/journey_d/journey_d_execute_workflow.dart';
import 'package:cohort_platform/staging_tooling/journey_d/journey_d_hosted_execute_ports.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_programme_stores.dart';
import '../support/programme_session_authoring_test_support.dart';

/// Post-freshness Journey D StateError: stage attribution + evidence write 201.
void main() {
  const marker = 's17_jd_adapt_20260808T065203Z_cbe6b6cf';
  const athleteId = '9404925f-247b-4668-a596-5927ff086966';
  const assignmentId = 'd7535200-0c9d-445c-9b07-ae68b9cfe1f2';
  const versionId = 'd060803c-e093-4d16-b8d9-0a0049b57e26';

  late InMemoryKnowledgeGraphReader knowledge;
  late ProtocolDraft draft;
  late PreparedExecutionPackage package;
  late ProgrammeExecutionContext executionContext;
  late AthleteProgrammeSessionPrepareService prepareService;
  late List<PlanPackageAdaptationPermission> permissions;

  setUpAll(() async {
    final knowledgeRoot = _findKnowledgeRoot(Directory.current);
    final bundle = await const YamlKnowledgeOntologyLoader().loadFromDirectory(
      knowledgeRoot,
    );
    knowledge = InMemoryKnowledgeGraphReader(bundle);
  });

  setUp(() {
    draft = _fixtureCurrentDraft();
    package = _packageFromDraft(draft);
    permissions = const [
      PlanPackageAdaptationPermission(
        id: 'ADP-JD-EQUIP-CURRENT',
        changeKind: AdaptationChangeKind.substituteApprovedEquipment,
        targetRef: 'W1D1S1',
        athleteAgreementRequired: true,
      ),
      PlanPackageAdaptationPermission(
        id: 'ADP-JD-EQUIP-PROGRAMME',
        changeKind: AdaptationChangeKind.substituteApprovedExercise,
        targetRef: 'programme',
        athleteAgreementRequired: true,
      ),
    ];
    final kv = InMemoryKvStore();
    final tables = InMemoryProgrammeTables();
    prepareService = AthleteProgrammeSessionPrepareService(
      assignmentStore: InMemoryProgrammeAssignmentStore(tables),
      slotResolver: AthleteProgrammeAuthoredSlotResolver(
        versionStore: InMemoryProgrammeVersionStore(tables),
      ),
      sessionLoader: SessionExecutionLoader(),
      localRepository: AthleteLocalRepository(kv),
    );
    executionContext = ProgrammeExecutionContext(
      assignmentId: package.assignmentId!,
      programmeVersionId: package.programmeVersionId!,
      sessionSlotId: 'W1D1S1',
      weekNumber: 1,
      dayKey: package.dayKey!,
      sessionOrder: package.slotOrder!,
      plannedProtocolId: package.protocolId!,
      effectiveProtocolId: package.protocolId!,
      programmeName: 'Journey D Fixture',
      packageContentHash: package.packageContentHash,
      programmedSessionKey: package.programmedSessionKey.value,
    );
  });

  JourneyDPrivateCredential seedCred() => JourneyDPrivateCredential(
        marker: marker,
        lineageCode: JourneyDPrivateCredential.lineageProgS17JdAdapt,
        athleteId: athleteId,
        email: '$marker.athlete.jd@example.invalid',
        password: 'secret-not-logged',
        assignmentId: assignmentId,
        versionId: versionId,
        nonce: 'nonce-test',
        createdAtUtc: DateTime.utc(2026, 8, 8),
      );

  FakeJourneyDExecutePorts basePorts({
    String? throwStateErrorAtStage,
    String stateErrorMessage = 'injected_state_error',
  }) {
    return FakeJourneyDExecutePorts(
      resolution: JourneyDFixtureResolution(
        marker: marker,
        athleteId: athleteId,
        assignmentId: assignmentId,
        versionId: versionId,
        intendedOccurrenceKey: kJourneyDIntendedSessionKey,
        laterOccurrenceKey: kJourneyDLaterSessionKey,
      ),
      prepared: JourneyDPreparedOccurrence(
        package: package,
        executionContext: executionContext,
        sessionKey: kJourneyDIntendedSessionKey,
      ),
      permissions: permissions,
      throwStateErrorAtStage: throwStateErrorAtStage,
      stateErrorMessage: stateErrorMessage,
    );
  }

  JourneyDExecuteWorkflow workflowFor(FakeJourneyDExecutePorts ports) {
    return JourneyDExecuteWorkflow(
      ports: ports,
      proposalService: ProgrammeAdaptationProposalService(
        knowledge: knowledge,
        loadProtocolDraft: (_) async => draft,
        loadAdaptationPermissions: (_) async => permissions,
      ),
      acceptanceFactory: (prep) => ProgrammeAdaptationAcceptanceService(
        prepareService: prep,
        adapter: PlanPackageSessionAdaptationAdapter(knowledge: knowledge),
        loadProtocolDraft: (_) async => draft,
        loadAdaptationPermissions: (_) async => permissions,
      ),
    );
  }

  group('exception-stage attribution', () {
    test('StateError at authenticate retains stage + safe message', () async {
      final ports = basePorts(
        throwStateErrorAtStage: 'authenticate',
        stateErrorMessage: 'athlete_auth_failed',
      );
      final result = await workflowFor(ports).run(
        marker: marker,
        credential: seedCred(),
        prepareService: prepareService,
        eligibilityPassed: true,
      );
      expect(result.ok, isFalse);
      expect(result.executionStage, 'authenticate');
      expect(result.exceptionType, 'StateError');
      expect(result.exceptionMessage, 'athlete_auth_failed');
      expect(result.detail, contains('stage=authenticate'));
      expect(result.detail, contains('athlete_auth_failed'));
      expect(result.agreementAccepted, isFalse);
      expect(result.applicationInvoked, isFalse);
      expect(result.hostedWritesExecuted, 0);
      expect(jsonEncode(result.toJson()), isNot(contains('secret-not-logged')));
      expect(jsonEncode(result.toJson()), isNot(contains('@example.invalid')));
    });

    test(
      'StateError at later integrity retains stage after agreement',
      () async {
        // Exact post-freshness staging message from broken protocol select.
        final ports = basePorts(
          throwStateErrorAtStage: 'later_push_up_integrity',
          stateErrorMessage: 'http_400',
        );
        final result = await workflowFor(ports).run(
          marker: marker,
          credential: seedCred(),
          prepareService: prepareService,
          eligibilityPassed: true,
        );
        expect(result.ok, isFalse, reason: result.detail);
        expect(result.executionStage, 'later_push_up_integrity');
        expect(result.exceptionType, 'StateError');
        expect(result.exceptionMessage, 'http_400');
        expect(
          result.detail,
          'unhandled:stage=later_push_up_integrity:StateError:http_400',
        );
        expect(result.agreementAccepted, isTrue);
        expect(result.applicationInvoked, isTrue);
        expect(result.athleteAgreementRecorded, isFalse);
        expect(result.hostedWritesExecuted, 0);
      },
    );

    test(
      'StateError at evidence write retains stage + post-accept flags',
      () async {
        final ports = basePorts(
          throwStateErrorAtStage: 'record_execution_evidence',
          stateErrorMessage: 'evidence_write_http_201',
        );
        final result = await workflowFor(ports).run(
          marker: marker,
          credential: seedCred(),
          prepareService: prepareService,
          eligibilityPassed: true,
        );
        expect(result.ok, isFalse, reason: result.detail);
        expect(result.executionStage, 'record_execution_evidence');
        expect(result.exceptionType, 'StateError');
        expect(result.exceptionMessage, 'evidence_write_http_201');
        expect(
          result.detail,
          'unhandled:stage=record_execution_evidence:StateError:evidence_write_http_201',
        );
        expect(result.agreementAccepted, isTrue);
        expect(result.applicationInvoked, isTrue);
        expect(result.hostedWritesExecuted, 0);
        expect(result.exceptionLocation, isNotNull);
        expect(result.identityHints['athlete_id_prefix'], startsWith('9404925f'));
      },
    );
  });

  group('laterPushUpIntact schema contract (staging-shaped)', () {
    test(
      'selecting performance_protocols.id reproduces http_400 StateError',
      () async {
        // Exact staging defect: PostgREST 400
        // "column performance_protocols.id does not exist".
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          final path = request.uri.path;
          final qs = request.uri.query;
          if (path.contains('performance_protocols') &&
              qs.contains('select=protocol_id,id')) {
            request.response.statusCode = 400;
            request.response.write(
              jsonEncode({
                'code': '42703',
                'message':
                    'column performance_protocols.id does not exist',
              }),
            );
          } else {
            request.response.statusCode = 500;
            request.response.write('{"error":"unexpected"}');
          }
          await request.response.close();
        });
        addTearDown(() async => server.close(force: true));

        // Reproduce the throwing statement used by the broken query path.
        final uri = Uri.parse(
          'http://127.0.0.1:${server.port}/rest/v1/performance_protocols'
          '?select=protocol_id,id,session_lineage_id'
          '&protocol_id=eq.$kJourneyDLaterProtocolId',
        );
        final client = HttpClient();
        addTearDown(client.close);
        final req = await client.getUrl(uri);
        final resp = await req.close();
        final body = await resp.transform(utf8.decoder).join();
        expect(resp.statusCode, 400);
        expect(body, contains('performance_protocols.id'));
        expect(
          () {
            if (resp.statusCode != 200) {
              throw StateError('http_${resp.statusCode}');
            }
          },
          throwsA(
            isA<StateError>().having((e) => e.message, 'message', 'http_400'),
          ),
        );
      },
    );

    test(
      'repaired laterPushUpIntact finds push_up via session_blocks',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          final path = request.uri.path;
          final qs = request.uri.query;
          // Refuse the broken select shape if it reappears.
          if (qs.contains('select=protocol_id,id')) {
            request.response.statusCode = 400;
            request.response.write(
              '{"message":"column performance_protocols.id does not exist"}',
            );
          } else if (path.contains('session_blocks')) {
            request.response.statusCode = 200;
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode([
                {
                  'block_id': 'block-later-1',
                  'session_id': kJourneyDLaterProtocolId,
                },
              ]),
            );
          } else if (path.contains('session_block_exercises')) {
            request.response.statusCode = 200;
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode([
                {'exercise_id': kJourneyDLaterExerciseId},
              ]),
            );
          } else {
            request.response.statusCode = 404;
            request.response.write('{"error":"unexpected"}');
          }
          await request.response.close();
        });
        addTearDown(() async => server.close(force: true));

        final ports = HostedJourneyDExecutePorts(
          apiUrl: 'http://127.0.0.1:${server.port}',
          serviceKey: 'test-service-key',
          anonKey: 'test-anon-key',
        );
        final ok = await ports.laterPushUpIntact(
          marker: marker,
          assignmentId: assignmentId,
        );
        expect(ok, isTrue);
      },
    );

    test('missing later push_up still fails closed', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        final path = request.uri.path;
        if (path.contains('session_blocks')) {
          request.response.statusCode = 200;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode([
              {
                'block_id': 'block-later-1',
                'session_id': kJourneyDLaterProtocolId,
              },
            ]),
          );
        } else if (path.contains('session_block_exercises')) {
          request.response.statusCode = 200;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode([
              {'exercise_id': 'cohort.exercise.other'},
            ]),
          );
        } else if (path.contains('performance_protocols')) {
          request.response.statusCode = 200;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode([
              {
                'protocol_id': kJourneyDLaterProtocolId,
                'exercises': null,
                'main_session': null,
              },
            ]),
          );
        } else {
          request.response.statusCode = 404;
        }
        await request.response.close();
      });
      addTearDown(() async => server.close(force: true));

      final ports = HostedJourneyDExecutePorts(
        apiUrl: 'http://127.0.0.1:${server.port}',
        serviceKey: 'test-service-key',
        anonKey: 'test-anon-key',
      );
      final ok = await ports.laterPushUpIntact(
        marker: marker,
        assignmentId: assignmentId,
      );
      expect(ok, isFalse);
    });
  });

  group('evidence write GoTrue 201 (staging-shaped)', () {
    test(
      'knowledge-parity accept reaches evidence; PUT 201 no longer StateError',
      () async {
        // Staging defect: GoTrue admin user update returns 201 (password remint
        // already accepts 200|201) while evidence write required status==200
        // → StateError('evidence_write_http_201') after successful accept.
        final putStatuses = <int>[];
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          final path = request.uri.path;
          if (request.method == 'GET' &&
              path == '/auth/v1/admin/users/$athleteId') {
            request.response.statusCode = 200;
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode({
                'id': athleteId,
                'email': 'redacted@example.invalid',
                'user_metadata': {
                  'run_id': marker,
                  'purpose': 's17_journey_d_adaptation_fixture',
                },
              }),
            );
          } else if (request.method == 'PUT' &&
              path == '/auth/v1/admin/users/$athleteId') {
            final body = await utf8.decoder.bind(request).join();
            final decoded = jsonDecode(body) as Map<String, dynamic>;
            final meta = decoded['user_metadata'] as Map<String, dynamic>;
            expect(meta['run_id'], marker);
            expect(meta['journey_d_execution_count'], 1);
            expect(meta['action'], 'swapExercise');
            expect(
              meta['replacement_exercise_id'],
              JourneyDEquipmentAdaptationContract.replacementExerciseId,
            );
            putStatuses.add(201);
            request.response.statusCode = 201;
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode({
                'id': athleteId,
                'user_metadata': meta,
              }),
            );
          } else {
            request.response.statusCode = 404;
            request.response.write('{"error":"unexpected"}');
          }
          await request.response.close();
        });
        addTearDown(() async => server.close(force: true));

        final ports = HostedJourneyDExecutePorts(
          apiUrl: 'http://127.0.0.1:${server.port}',
          serviceKey: 'test-service-key',
          anonKey: 'test-anon-key',
        );

        final proposal = await ProgrammeAdaptationProposalService(
          knowledge: knowledge,
          loadProtocolDraft: (_) async => draft,
          loadAdaptationPermissions: (_) async => permissions,
        ).propose(
          package: package,
          request: const AdaptationRequest(
            reason: AdaptationReason.equipment,
            availableEquipment:
                JourneyDEquipmentAdaptationContract.availableEquipment,
          ),
        );
        expect(proposal.isAcceptable, isTrue);

        final accept = await ProgrammeAdaptationAcceptanceService(
          prepareService: prepareService,
          adapter: PlanPackageSessionAdaptationAdapter(knowledge: knowledge),
          loadProtocolDraft: (_) async => draft,
          loadAdaptationPermissions: (_) async => permissions,
        ).accept(
          athleteId: athleteId,
          currentPackage: package,
          proposal: proposal,
          executionContext: executionContext,
        );
        expect(accept.success, isTrue);

        await ports.recordExecutionEvidence(
          evidence: JourneyDExecuteEvidence(
            marker: marker,
            athleteId: athleteId,
            assignmentId: assignmentId,
            versionId: versionId,
            proposalId: proposal.proposalId,
            action: 'swapExercise',
            sourceExerciseId:
                JourneyDEquipmentAdaptationContract.sourceExerciseId,
            replacementExerciseId:
                JourneyDEquipmentAdaptationContract.replacementExerciseId,
            substitutionRuleId:
                JourneyDEquipmentAdaptationContract.substitutionRuleId,
            athleteAgreementRecorded: true,
            intendedOccurrenceKey: kJourneyDIntendedSessionKey,
            laterPushUpIntact: true,
            permissionsPassed: true,
            executedAtUtc: DateTime.utc(2026, 8, 8),
          ),
        );
        expect(putStatuses, [201]);
      },
    );

    test('malformed evidence PUT status still fails closed', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        if (request.method == 'GET') {
          request.response.statusCode = 200;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'id': athleteId,
              'user_metadata': {'run_id': marker},
            }),
          );
        } else {
          request.response.statusCode = 422;
          request.response.write('{"msg":"invalid"}');
        }
        await request.response.close();
      });
      addTearDown(() async => server.close(force: true));

      final ports = HostedJourneyDExecutePorts(
        apiUrl: 'http://127.0.0.1:${server.port}',
        serviceKey: 'test-service-key',
        anonKey: 'test-anon-key',
      );
      expect(
        () => ports.recordExecutionEvidence(
          evidence: JourneyDExecuteEvidence(
            marker: marker,
            athleteId: athleteId,
            assignmentId: assignmentId,
            versionId: versionId,
            proposalId: 'prop-1',
            action: 'swapExercise',
            sourceExerciseId:
                JourneyDEquipmentAdaptationContract.sourceExerciseId,
            replacementExerciseId:
                JourneyDEquipmentAdaptationContract.replacementExerciseId,
            substitutionRuleId:
                JourneyDEquipmentAdaptationContract.substitutionRuleId,
            athleteAgreementRecorded: true,
            intendedOccurrenceKey: kJourneyDIntendedSessionKey,
            laterPushUpIntact: true,
            permissionsPassed: true,
            executedAtUtc: DateTime.utc(2026, 8, 8),
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'evidence_write_http_422',
          ),
        ),
      );
    });

    test('already-recorded evidence remains fail-closed', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'id': athleteId,
            'user_metadata': {
              'run_id': marker,
              'journey_d_execution_count': 1,
            },
          }),
        );
        await request.response.close();
      });
      addTearDown(() async => server.close(force: true));

      final ports = HostedJourneyDExecutePorts(
        apiUrl: 'http://127.0.0.1:${server.port}',
        serviceKey: 'test-service-key',
        anonKey: 'test-anon-key',
      );
      expect(
        () => ports.recordExecutionEvidence(
          evidence: JourneyDExecuteEvidence(
            marker: marker,
            athleteId: athleteId,
            assignmentId: assignmentId,
            versionId: versionId,
            proposalId: 'prop-1',
            action: 'swapExercise',
            sourceExerciseId:
                JourneyDEquipmentAdaptationContract.sourceExerciseId,
            replacementExerciseId:
                JourneyDEquipmentAdaptationContract.replacementExerciseId,
            substitutionRuleId:
                JourneyDEquipmentAdaptationContract.substitutionRuleId,
            athleteAgreementRecorded: true,
            intendedOccurrenceKey: kJourneyDIntendedSessionKey,
            laterPushUpIntact: true,
            permissionsPassed: true,
            executedAtUtc: DateTime.utc(2026, 8, 8),
          ),
        ),
        throwsA(
          isA<JourneyDExecuteAmbiguity>().having(
            (e) => e.code,
            'code',
            'journey_d_already_recorded',
          ),
        ),
      );
    });
  });

  group('sanitiser', () {
    test('redacts emails and tokens from exception text', () {
      final msg = sanitizeJourneyDExceptionMessage(
        StateError(
          'fail user=s17_jd_adapt@example.invalid bearer eyJhbGciOiJIUzI1NiJ9.aaa.bbb',
        ),
      );
      expect(msg, isNot(contains('@example.invalid')));
      expect(msg, contains('<email>'));
      expect(msg.contains('eyJhbGci'), isFalse);
    });
  });
}

ProtocolDraft _fixtureCurrentDraft() {
  return programmeSession(
    protocolId: 'PROT-S17-JD-ADAPT-CURRENT',
    name: 'Journey D Current Equipment Session',
    programmeVersionId: testProgrammeVersionId,
    ownerId: 'dev-coach',
    durationMin: 45,
    primarySessionIntent: SessionIntent.lowerBodyStrength,
    minimumViableDurationMin: 25,
    blocks: [
      block(
        localId: 'block-strength',
        type: SessionBlockType.strength,
        position: 1,
        title: 'Main',
        blockPriority: BlockPriority.essential,
        adaptationPolicy: const BlockAdaptationPolicy(
          canRemove: false,
          canShorten: false,
          canReduceVolume: true,
          canReduceIntensity: true,
          canIncreaseRest: true,
          canSuperset: false,
          canReplaceExercises: true,
          canReplaceBlock: false,
          minimumViablePrescription: MinimumViablePrescription(sets: 2),
        ),
        linkedExercises: [
          SessionBlockExerciseLink(
            localId: 'link-strength-1',
            exerciseId: JourneyDEquipmentAdaptationContract.sourceExerciseId,
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
  );
}

PreparedExecutionPackage _packageFromDraft(ProtocolDraft draft) {
  final key = ProgrammedSessionKey(
    planId: 'lineage.jd.adapt',
    planVersion: 'version.jd.adapt',
    week: 1,
    day: 1,
    dayKey: 'day_1',
    slotOrder: 1,
    protocolId: draft.protocolId,
    programmeAssignmentId: 'assignment.jd.adapt',
    packageContentHash: 'hash.jd.adapt',
  );
  final plan = SessionExecutionPlan(
    sessionId: draft.protocolId,
    sessionTitle: draft.name,
    durationMin: draft.durationMin,
    blocks: draft.blocks
        .map(
          (b) => SessionExecutionBlock.fromSessionBlock(
            b,
            exercisesById: const {},
          ),
        )
        .toList(growable: false),
  );
  return PreparedExecutionPackage(
    programmedSessionKey: key,
    plan: plan,
    brief: WorkoutSessionBrief(
      sessionName: draft.name,
      estimatedDurationMinutes: draft.durationMin,
    ),
    preparedAt: DateTime.utc(2026, 8, 4),
    assignmentId: 'assignment.jd.adapt',
    programmeVersionId: testProgrammeVersionId,
    packageContentHash: 'hash.jd.adapt',
    dayKey: 'day_1',
    slotOrder: 1,
    protocolId: draft.protocolId,
  );
}

String _findKnowledgeRoot(Directory start) {
  var dir = start;
  for (var i = 0; i < 8; i++) {
    final candidate = Directory('${dir.path}/knowledge/reference');
    if (candidate.existsSync()) return '${dir.path}/knowledge';
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError('knowledge root not found from ${start.path}');
}
