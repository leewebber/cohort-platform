import 'dart:io';

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
import 'package:cohort_platform/staging_tooling/journey_d/journey_d_rebind.dart';
import 'package:flutter_test/flutter_test.dart';

/// Local-only CURRENT protocol publication repair proofs (no hosted contact).
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
  const stableMarker = 's17_jd_adapt_20260805T012428Z_933d9364';

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

  ProtocolDraft preRepairDraft(JourneyDProtocolPublicationIntent intent) {
    // Exact pre-repair construction: omitted sessionFormat.
    final base = programmeSession(
      protocolId: intent.protocolId,
      name: 'S17 Journey D ${intent.role}',
      programmeVersionId: ProtocolBuilderJourneyDPublisher
          .retiredNonUuidProgrammeVersionPlaceholder,
      ownerId: null,
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
            minimumViablePrescription: const MinimumViablePrescription(
              sets: 2,
            ),
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
    );
    return base.copyWith(revisionNumber: intent.revisionNumber);
  }

  group('pre-repair ProtocolBuilderException', () {
    test('CURRENT rejects missing sessionFormat before network', () {
      final service = ProtocolBuilderService();
      final draft = preRepairDraft(currentIntent);
      expect(draft.sessionFormat, isNull);
      expect(
        () => service.validateDraft(draft),
        throwsA(
          isA<ProtocolBuilderException>().having(
            (e) => e.message,
            'message',
            contains('Session format is required.'),
          ),
        ),
      );
    });

    test('LATER rejects missing sessionFormat before network', () {
      final service = ProtocolBuilderService();
      final draft = preRepairDraft(laterIntent);
      expect(
        () => service.validateDraft(draft),
        throwsA(
          isA<ProtocolBuilderException>().having(
            (e) => e.message,
            'message',
            contains('Session format is required.'),
          ),
        ),
      );
    });

    test('publisher reports pre-network builder failure accounting', () async {
      final service = _RecordingBuilderService();
      final broken = preRepairDraft(currentIntent);
      expect(
        () => service.validateDraft(broken),
        throwsA(isA<ProtocolBuilderException>()),
      );
      expect(service.publishCalls, 0);
    });
  });

  group('repaired drafts', () {
    test('CURRENT and LATER validate through production builder', () {
      final service = ProtocolBuilderService();
      final current = ProtocolBuilderJourneyDPublisher.draftFor(currentIntent);
      final later = ProtocolBuilderJourneyDPublisher.draftFor(laterIntent);
      expect(current.sessionFormat, 'structured_strength');
      expect(later.sessionFormat, 'structured_strength');
      expect(current.blocks.single.linkedExercises.single.exerciseId,
          'cohort.exercise.back_squat');
      expect(later.blocks.single.linkedExercises.single.exerciseId,
          'cohort.exercise.push_up');
      expect(current.blocks.single.adaptationPolicy?.canReplaceExercises, isTrue);
      service.validateDraft(current);
      service.validateDraft(later);
    });

    test('publisher distinguishes builder vs adapter errors', () async {
      final builderFail = _RecordingBuilderService(
        validateError: const ProtocolBuilderException(
          'Session format is required.',
        ),
      );
      final pub1 = ProtocolBuilderJourneyDPublisher(
        protocolBuilderService: builderFail,
        sessionLineageStore: _FakeLineageStore(),
      );
      final r1 = await pub1.publish(currentIntent);
      expect(r1.state, JourneyDPublicationStageState.failed);
      expect(r1.detail, contains('builder_validation:'));
      expect(r1.writeAccounting.requestDispatched, isFalse);
      expect(r1.writeAccounting.outcomeUncertain, isFalse);
      expect(builderFail.publishCalls, 0);

      final adapterFail = _RecordingBuilderService(
        publishError: const ProtocolBuilderException(
          'We could not save your protocol right now. Please try again.',
          postgrestCode: '22P02',
          postgrestMessage:
              'invalid input syntax for type uuid: "s17-jd-adapt-fixture-programme-version"',
        ),
      );
      final pub2 = ProtocolBuilderJourneyDPublisher(
        protocolBuilderService: adapterFail,
        sessionLineageStore: _FakeLineageStore(),
      );
      final r2 = await pub2.publish(currentIntent);
      expect(r2.state, JourneyDPublicationStageState.unknown);
      expect(r2.detail, contains('publishDraft_adapter_error:'));
      expect(r2.detail, contains('code=22P02'));
      expect(r2.detail, contains('invalid input syntax for type uuid'));
      expect(
        r2.detail,
        contains('We could not save your protocol right now. Please try again.'),
      );
      expect(r2.writeAccounting.requestDispatched, isTrue);
      expect(r2.writeAccounting.responseReceived, isTrue);
      expect(r2.writeAccounting.outcomeUncertain, isTrue);
      expect(adapterFail.publishCalls, 1);
    });
  });

  group('creator preflight ordering', () {
    test('invalid CURRENT fails before athlete creation', () async {
      final athlete = FakeJourneyDLiveAthleteFactory();
      final creator = JourneyDLiveFixtureCreator(
        preflight: FakeJourneyDLivePreflight(),
        athleteFactory: athlete,
        rebindPipeline: JourneyDRebindPipeline(
          publisher: FakeJourneyDProtocolPublisher(
            lineageByProtocolId: {
              'PROT-S17-JD-ADAPT-CURRENT': currentUuid,
              'PROT-S17-JD-ADAPT-LATER': laterUuid,
            },
          ),
        ),
        programmeLifecycle: FakeJourneyDLiveProgrammeLifecycle(),
        enrolment: FakeJourneyDLiveEnrolment(),
        materialisation: FakeJourneyDLiveMaterialisation(),
        buildProtocolDraft: preRepairDraft,
      );
      final result = await creator.run(
        marker: stableMarker,
        protocolIntentJson: intentJson,
        packageYaml: packageYaml,
        stagingConfirmed: true,
        liveAuthorized: true,
      );
      expect(result.ok, isFalse);
      expect(result.classification, 'B4D21D1_PROTOCOL_PREFLIGHT_FAILED');
      expect(athlete.calls, 0);
      final currentStage = result.stages.firstWhere(
        (s) => s.name == 'build_and_validate_current_protocol',
      );
      expect(currentStage.status, JourneyDPublicationStageState.failed);
      expect(currentStage.detail, contains('Session format is required.'));
      final athleteStage = result.stages.firstWhere(
        (s) => s.name == 'create_synthetic_athlete',
      );
      expect(athleteStage.status, JourneyDPublicationStageState.notStarted);
    });

    test('invalid LATER fails before athlete creation', () async {
      final athlete = FakeJourneyDLiveAthleteFactory();
      ProtocolDraft brokenLater(JourneyDProtocolPublicationIntent intent) {
        if (intent.protocolId == 'PROT-S17-JD-ADAPT-LATER') {
          return preRepairDraft(intent);
        }
        return ProtocolBuilderJourneyDPublisher.draftFor(intent);
      }

      final creator = JourneyDLiveFixtureCreator(
        preflight: FakeJourneyDLivePreflight(),
        athleteFactory: athlete,
        rebindPipeline: JourneyDRebindPipeline(
          publisher: FakeJourneyDProtocolPublisher(
            lineageByProtocolId: {
              'PROT-S17-JD-ADAPT-CURRENT': currentUuid,
              'PROT-S17-JD-ADAPT-LATER': laterUuid,
            },
          ),
        ),
        programmeLifecycle: FakeJourneyDLiveProgrammeLifecycle(),
        enrolment: FakeJourneyDLiveEnrolment(),
        materialisation: FakeJourneyDLiveMaterialisation(),
        buildProtocolDraft: brokenLater,
      );
      final result = await creator.run(
        marker: stableMarker,
        protocolIntentJson: intentJson,
        packageYaml: packageYaml,
        stagingConfirmed: true,
        liveAuthorized: true,
      );
      expect(result.ok, isFalse);
      expect(result.classification, 'B4D21D1_PROTOCOL_PREFLIGHT_FAILED');
      expect(athlete.calls, 0);
      expect(
        result.stages
            .firstWhere((s) => s.name == 'build_and_validate_later_protocol')
            .status,
        JourneyDPublicationStageState.failed,
      );
    });

    test('repaired loopback creator publishes CURRENT and LATER', () async {
      final publisher = FakeJourneyDProtocolPublisher(
        lineageByProtocolId: {
          'PROT-S17-JD-ADAPT-CURRENT': currentUuid,
          'PROT-S17-JD-ADAPT-LATER': laterUuid,
        },
      );
      final creator = JourneyDLiveFixtureCreator(
        preflight: FakeJourneyDLivePreflight(),
        athleteFactory: FakeJourneyDLiveAthleteFactory(),
        rebindPipeline: JourneyDRebindPipeline(publisher: publisher),
        programmeLifecycle: FakeJourneyDLiveProgrammeLifecycle(),
        enrolment: FakeJourneyDLiveEnrolment(),
        materialisation: FakeJourneyDLiveMaterialisation(),
      );
      final result = await creator.run(
        marker: stableMarker,
        protocolIntentJson: intentJson,
        packageYaml: packageYaml,
        stagingConfirmed: true,
        liveAuthorized: true,
      );
      expect(result.ok, isTrue, reason: result.classification);
      expect(publisher.publishedProtocolIds, [
        'PROT-S17-JD-ADAPT-CURRENT',
        'PROT-S17-JD-ADAPT-LATER',
      ]);
      expect(result.publishDraftInvocations, 2);
      expect(
        result.writeAccountingByStage['create_synthetic_athlete']
            ?.mutationConfirmed,
        isTrue,
      );
      expect(
        result.writeAccountingByStage['create_synthetic_athlete']
            ?.objectObservedPostAttempt,
        isFalse,
      );
      expect(
        result.stages
            .firstWhere((s) => s.name == 'build_and_validate_current_protocol')
            .status,
        JourneyDPublicationStageState.applied,
      );
      expect(
        result.stages
            .firstWhere((s) => s.name == 'build_and_validate_later_protocol')
            .status,
        JourneyDPublicationStageState.applied,
      );
    });

    test('Journey D coaching semantics remain intact in package + intents', () {
      final compile = const PlanPackageCompiler().compile(packageYaml);
      expect(compile.isValid, isTrue);
      final plan = const JourneyDPublicationPlanBuilder().build(
        protocolIntentJson: intentJson,
        packageManifest: compile.manifest!,
      );
      expect(plan.intents[0].exerciseId, 'cohort.exercise.back_squat');
      expect(
        plan.intents[0].replacementExerciseId,
        'cohort.exercise.goblet_squat',
      );
      expect(
        plan.intents[0].substitutionRuleId,
        'cohort.substitution.back_squat_to_goblet_squat',
      );
      expect(plan.intents[0].canReplaceExercises, isTrue);
      expect(plan.intents[1].exerciseId, 'cohort.exercise.push_up');
      expect(packageYaml, contains('substitute_approved_equipment'));
      expect(packageYaml, contains('substitute_approved_exercise'));
      expect(packageYaml, contains('athlete_agreement_required: true'));
      expect(intentJson, contains('cohort.equipment.barbell'));
      expect(intentJson, contains('cohort.equipment.squat_rack'));
      expect(intentJson, contains('cohort.exercise.back_squat'));
      expect(intentJson, contains('cohort.exercise.goblet_squat'));
      expect(intentJson, contains('cohort.exercise.push_up'));
    });

    test('stage order places builder preflight before hosted mutation', () {
      expect(
        JourneyDLiveFixtureCreator.stageOrder,
        containsAllInOrder([
          'compile_validate_package_local',
          'build_and_validate_current_protocol',
          'build_and_validate_later_protocol',
          'validate_rebind_import_assignment_materialisation_inputs',
          'check_marker_uniqueness_readonly',
          'create_synthetic_athlete',
          'publish_fixture_protocol_current',
          'publish_fixture_protocol_later',
        ]),
      );
      final currentIdx = JourneyDLiveFixtureCreator.stageOrder.indexOf(
        'build_and_validate_current_protocol',
      );
      final athleteIdx = JourneyDLiveFixtureCreator.stageOrder.indexOf(
        'create_synthetic_athlete',
      );
      expect(currentIdx, lessThan(athleteIdx));
    });
  });
}

class _RecordingBuilderService extends ProtocolBuilderService {
  _RecordingBuilderService({
    this.validateOnly = false,
    this.validateError,
    this.publishError,
  });

  final bool validateOnly;
  final ProtocolBuilderException? validateError;
  final ProtocolBuilderException? publishError;
  int publishCalls = 0;

  @override
  void validateDraft(ProtocolDraft draft) {
    if (validateError != null) throw validateError!;
    super.validateDraft(draft);
  }

  @override
  Future<ProtocolBuilderSaveResult> publishDraft(ProtocolDraft draft) async {
    publishCalls += 1;
    if (validateError != null) throw validateError!;
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
  @override
  Future<SessionLineage> insertLineage({
    required String displayName,
    String? id,
  }) async {
    return SessionLineage(
      id: id ?? currentUuid,
      displayName: displayName,
    );
  }

  @override
  Future<SessionRevisionIdentity?> getRevisionIdentity(
    String protocolId,
  ) async {
    return SessionRevisionIdentity(
      protocolId: protocolId,
      sessionLineageId: currentUuid,
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

const currentUuid = 'a1111111-1111-4111-8111-111111111111';
