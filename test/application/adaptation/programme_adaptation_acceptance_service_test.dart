import 'package:cohort_platform/application/adaptation/adaptation_application.dart';
import 'package:cohort_platform/core/persistence/athlete_local_repository.dart';
import 'package:cohort_platform/core/persistence/local_kv_store.dart';
import 'package:cohort_platform/features/adaptation/models/accepted_adaptation_decision.dart';
import 'package:cohort_platform/features/adaptation/models/programme_adaptation_proposal.dart';
import 'package:cohort_platform/features/plans/models/programmed_session_key.dart';
import 'package:cohort_platform/features/programme/models/programme_execution_context.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_authored_slot_resolver.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_session_prepare_service.dart';
import 'package:cohort_platform/features/session/models/prepared_execution_package.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/services/session_execution_loader.dart';
import 'package:cohort_platform/features/workout_player/models/workout_session_brief.dart';
import 'package:cohort_platform/models/adaptation_reason.dart';
import 'package:cohort_platform/models/adaptation_request.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/adaptation_planning_test_support.dart';
import '../../support/in_memory_programme_stores.dart';

void main() {
  group('ProgrammeAdaptationAcceptanceService', () {
    late ProtocolDraft draft;
    late PreparedExecutionPackage package;
    late ProgrammeAdaptationProposalService proposalService;
    late AthleteProgrammeSessionPrepareService prepareService;
    late ProgrammeAdaptationAcceptanceService acceptanceService;
    late ProgrammeExecutionContext executionContext;
    late InMemoryKvStore kv;

    setUp(() {
      draft = buildTimedPlanningSession(protocolId: 'proto.accept.1.6c');
      package = _packageFromDraft(draft);
      kv = InMemoryKvStore();
      final tables = InMemoryProgrammeTables();
      prepareService = AthleteProgrammeSessionPrepareService(
        assignmentStore: InMemoryProgrammeAssignmentStore(tables),
        slotResolver: AthleteProgrammeAuthoredSlotResolver(
          versionStore: InMemoryProgrammeVersionStore(tables),
        ),
        sessionLoader: _FixedLoader(package.plan),
        localRepository: AthleteLocalRepository(kv),
      );
      proposalService = ProgrammeAdaptationProposalService(
        loadProtocolDraft: (_) async => draft,
      );
      acceptanceService = ProgrammeAdaptationAcceptanceService(
        prepareService: prepareService,
        loadProtocolDraft: (_) async => draft,
      );
      executionContext = ProgrammeExecutionContext(
        assignmentId: package.assignmentId!,
        programmeVersionId: package.programmeVersionId!,
        sessionSlotId: 'slot.1',
        weekNumber: 1,
        dayKey: package.dayKey!,
        sessionOrder: package.slotOrder!,
        plannedProtocolId: package.protocolId!,
        effectiveProtocolId: package.protocolId!,
        programmeName: 'Acceptance Fixture',
        packageContentHash: package.packageContentHash,
        programmedSessionKey: package.programmedSessionKey.value,
      );
    });

    Future<ProgrammeAdaptationProposal> reviewable() {
      return proposalService.propose(
        package: package,
        request: const AdaptationRequest(
          reason: AdaptationReason.time,
          availableMinutes: 40,
        ),
        proposedAt: DateTime.utc(2026, 8, 3, 2),
      );
    }

    test('accepts reviewable proposal and replaces only executable plan',
        () async {
      final proposal = await reviewable();
      expect(proposal.isAcceptable, isTrue);

      final beforeKey = package.programmedSessionKey.value;
      final beforeAssignment = package.assignmentId;
      final beforeHash = package.packageContentHash;
      final beforePlan = ProgrammeAdaptationFingerprints.plan(package.plan);

      final result = await acceptanceService.accept(
        athleteId: 'athlete.1',
        currentPackage: package,
        proposal: proposal,
        executionContext: executionContext,
        acceptedAt: DateTime.utc(2026, 8, 3, 3),
      );

      expect(result.success, isTrue);
      final updated = result.package!;
      expect(updated.acceptedAdaptation, isA<AcceptedAdaptationDecision>());
      expect(updated.programmedSessionKey.value, beforeKey);
      expect(updated.assignmentId, beforeAssignment);
      expect(updated.packageContentHash, beforeHash);
      expect(updated.programmeVersionId, package.programmeVersionId);
      expect(
        ProgrammeAdaptationFingerprints.plan(updated.plan),
        isNot(beforePlan),
      );
      expect(
        ProgrammeAdaptationFingerprints.plan(updated.plan),
        proposal.reviewedPlanFingerprint,
      );
      expect(updated.acceptedAdaptation!.reasonCode, 'time');
      expect(updated.acceptedAdaptation!.proposalId, proposal.proposalId);
      expect(
        updated.acceptedAdaptation!.sessionChanges.length +
            updated.acceptedAdaptation!.exerciseChanges.length,
        proposal.allMaterialChanges.length,
      );
      expect(package.acceptedAdaptation, isNull);
      expect(ProgrammeAdaptationFingerprints.plan(package.plan), beforePlan);
    });

    test('accepted decision retains every material change separately', () async {
      final proposal = await reviewable();
      final result = await acceptanceService.accept(
        athleteId: 'athlete.1',
        currentPackage: package,
        proposal: proposal,
        executionContext: executionContext,
      );
      final decision = result.decision!;
      expect(decision.changeSummary.length, proposal.allMaterialChanges.length);
      for (final change in proposal.exerciseChanges) {
        expect(
          decision.exerciseChanges.any((m) => m['summary'] == change.summary),
          isTrue,
        );
      }
      for (final change in proposal.sessionChanges) {
        expect(
          decision.sessionChanges.any((m) => m['summary'] == change.summary),
          isTrue,
        );
      }
    });

    test('no-safe and no-adaptation-required cannot be accepted', () async {
      for (final request in const [
        AdaptationRequest(
          reason: AdaptationReason.equipment,
          availableEquipment: {'bands'},
        ),
        AdaptationRequest(reason: AdaptationReason.time, availableMinutes: 90),
      ]) {
        final proposal = await proposalService.propose(
          package: package,
          request: request,
        );
        final result = await acceptanceService.accept(
          athleteId: 'athlete.1',
          currentPackage: package,
          proposal: proposal,
          executionContext: executionContext,
        );
        expect(result.success, isFalse, reason: request.reason.name);
        expect(result.errorCode, 'not_acceptable');
        expect(package.acceptedAdaptation, isNull);
      }
    });

    test('stale plan fingerprint fails closed', () async {
      final proposal = await reviewable();
      final mutatedPlan = SessionExecutionPlan(
        sessionId: package.plan.sessionId,
        sessionTitle: 'Mutated',
        blocks: package.plan.blocks,
        durationMin: 1,
      );
      final stalePackage = PreparedExecutionPackage(
        programmedSessionKey: package.programmedSessionKey,
        plan: mutatedPlan,
        brief: package.brief,
        preparedAt: package.preparedAt,
        assignmentId: package.assignmentId,
        programmeVersionId: package.programmeVersionId,
        packageContentHash: package.packageContentHash,
        dayKey: package.dayKey,
        slotOrder: package.slotOrder,
        protocolId: package.protocolId,
      );

      final result = await acceptanceService.accept(
        athleteId: 'athlete.1',
        currentPackage: stalePackage,
        proposal: proposal,
        executionContext: executionContext,
      );
      expect(result.success, isFalse);
      expect(result.errorCode, 'stale_plan');
    });

    test('consumed proposal cannot be reapplied', () async {
      final proposal = await reviewable();
      final first = await acceptanceService.accept(
        athleteId: 'athlete.1',
        currentPackage: package,
        proposal: proposal,
        executionContext: executionContext,
      );
      expect(first.success, isTrue);

      final replay = await acceptanceService.accept(
        athleteId: 'athlete.1',
        currentPackage: package,
        proposal: proposal,
        executionContext: executionContext,
      );
      expect(replay.success, isFalse);
      expect(replay.errorCode, 'proposal_consumed');
    });

    test('already adapted package cannot be overwritten', () async {
      final proposal = await reviewable();
      final first = await acceptanceService.accept(
        athleteId: 'athlete.1',
        currentPackage: package,
        proposal: proposal,
        executionContext: executionContext,
      );
      expect(first.success, isTrue);

      acceptanceService.resetConsumedProposalsForTests();
      final second = await acceptanceService.accept(
        athleteId: 'athlete.1',
        currentPackage: first.package!,
        proposal: proposal,
        executionContext: executionContext,
      );
      expect(second.success, isFalse);
      expect(second.errorCode, 'already_adapted');
    });

    test('local restore keeps accepted adaptation with executable plan',
        () async {
      final proposal = await reviewable();
      final accepted = await acceptanceService.accept(
        athleteId: 'athlete.1',
        currentPackage: package,
        proposal: proposal,
        executionContext: executionContext,
      );
      expect(accepted.success, isTrue);

      final record = await AthleteLocalRepository(kv).readGeneratedSession(
        'athlete.1',
      );
      expect(record, isNotNull);
      expect(record!.acceptedAdaptation, isNotNull);
      expect(
        ProgrammeAdaptationFingerprints.plan(record.plan),
        proposal.reviewedPlanFingerprint,
      );

      final decision = AcceptedAdaptationDecision.fromPersistenceMap(
        record.acceptedAdaptation!,
      );
      expect(decision.proposalId, proposal.proposalId);
      expect(decision.reasonCode, 'time');
    });
  });
}

class _FixedLoader extends SessionExecutionLoader {
  _FixedLoader(this.plan) : super();

  final SessionExecutionPlan plan;

  @override
  Future<SessionExecutionLoadResult> load({
    required String protocolId,
    String? displayTitle,
    String? programmeContextLabel,
    Map<String, String> prescriptionLoadOverrides = const {},
  }) async {
    return SessionExecutionLoadResult(plan: plan);
  }
}

PreparedExecutionPackage _packageFromDraft(ProtocolDraft draft) {
  final key = ProgrammedSessionKey(
    planId: 'lineage.s16c',
    planVersion: 'version.s16c',
    week: 1,
    day: 1,
    dayKey: 'day_1',
    slotOrder: 1,
    protocolId: draft.protocolId,
    programmeAssignmentId: 'assignment.s16c',
    packageContentHash: 'hash.s16c',
  );

  final plan = SessionExecutionPlan(
    sessionId: draft.protocolId,
    sessionTitle: draft.name,
    durationMin: draft.durationMin,
    blocks: draft.blocks
        .map(
          (block) => SessionExecutionBlock.fromSessionBlock(
            block,
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
    preparedAt: DateTime.utc(2026, 8, 3),
    assignmentId: 'assignment.s16c',
    programmeVersionId: 'version.s16c',
    packageContentHash: 'hash.s16c',
    dayKey: 'day_1',
    slotOrder: 1,
    protocolId: draft.protocolId,
  );
}
