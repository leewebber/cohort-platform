import 'dart:io';

import 'package:cohort_platform/application/adaptation/adaptation_application.dart';
import 'package:cohort_platform/core/persistence/athlete_local_repository.dart';
import 'package:cohort_platform/core/persistence/local_kv_store.dart';
import 'package:cohort_platform/features/adaptation/models/programme_adaptation_proposal.dart';
import 'package:cohort_platform/features/adaptation/services/adaptation_policy_gate.dart';
import 'package:cohort_platform/features/adaptation/services/post_completion_adaptation_evaluator.dart'
    show AdaptationEvaluationType;
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
import '../../support/programme_adaptation_coaching_recognition_fixture.dart';

/// Sprint 1.6E hardening: policy/no-safe cases + Coaching Recognition fixtures.
///
/// Staging evidence is out of scope unless separately authorised. This suite is
/// local-only and must not open post-completion or rescheduling paths.
void main() {
  group('Sprint 1.6E programme adaptation hardening', () {
    late ProtocolDraft draft;
    late PreparedExecutionPackage originalPackage;
    late SessionExecutionPlan originalPlan;
    late AthleteProgrammeSessionPrepareService prepareService;
    late ProgrammeAdaptationProposalService proposalService;
    late ProgrammeAdaptationAcceptanceService acceptanceService;
    late ProgrammeAdaptationReversionService reversionService;
    late ProgrammeExecutionContext executionContext;
    late InMemoryKvStore kv;

    setUp(() {
      draft = buildTimedPlanningSession(protocolId: 'proto.harden.1.6e');
      originalPackage = _packageFromDraft(draft);
      originalPlan = originalPackage.plan;
      kv = InMemoryKvStore();
      final tables = InMemoryProgrammeTables();
      prepareService = AthleteProgrammeSessionPrepareService(
        assignmentStore: InMemoryProgrammeAssignmentStore(tables),
        slotResolver: AthleteProgrammeAuthoredSlotResolver(
          versionStore: InMemoryProgrammeVersionStore(tables),
        ),
        sessionLoader: _FixedLoader(originalPlan),
        localRepository: AthleteLocalRepository(kv),
      );
      proposalService = ProgrammeAdaptationProposalService(
        loadProtocolDraft: (_) async => draft,
      );
      acceptanceService = ProgrammeAdaptationAcceptanceService(
        prepareService: prepareService,
        loadProtocolDraft: (_) async => draft,
      );
      reversionService = ProgrammeAdaptationReversionService(
        prepareService: prepareService,
      );
      executionContext = ProgrammeExecutionContext(
        assignmentId: originalPackage.assignmentId!,
        programmeVersionId: originalPackage.programmeVersionId!,
        sessionSlotId: 'slot.1',
        weekNumber: 1,
        dayKey: originalPackage.dayKey!,
        sessionOrder: originalPackage.slotOrder!,
        plannedProtocolId: originalPackage.protocolId!,
        effectiveProtocolId: originalPackage.protocolId!,
        programmeName: '1.6E Hardening Fixture',
        packageContentHash: originalPackage.packageContentHash,
        programmedSessionKey: originalPackage.programmedSessionKey.value,
      );
    });

    group('policy / no-safe cases', () {
      test('day-of reason kinds never include prohibited programme mutations',
          () {
        const gate = AdaptationPolicyGate();
        for (final reason in AdaptationReason.values) {
          final kinds = AdaptationPolicyGate.kindsForDayOf(reason);
          expect(
            gate.rejectUnsupported(kinds),
            isEmpty,
            reason: reason.name,
          );
          expect(kinds, isNot(contains(AdaptationChangeKind.rewritePlan)));
          expect(
            kinds,
            isNot(contains(AdaptationChangeKind.rewriteLaterSessions)),
          );
          expect(kinds, isNot(contains(AdaptationChangeKind.forceDeload)));
          expect(kinds, isNot(contains(AdaptationChangeKind.moveWeek)));
          expect(
            kinds,
            isNot(contains(AdaptationChangeKind.mutateProgrammedSession)),
          );
        }
      });

      test('post-completion policy kinds remain prohibited for programme path',
          () {
        const gate = AdaptationPolicyGate();
        for (final type in AdaptationEvaluationType.values) {
          final kinds = AdaptationPolicyGate.kindsForPostCompletion(type);
          expect(gate.rejectUnsupported(kinds), isNotEmpty);
          expect(
            () => gate.assertAllowed(kinds),
            throwsA(isA<AdaptationPolicyException>()),
          );
        }
      });

      test('no-safe outcomes leave prepared state unchanged and are not acceptable',
          () async {
        final beforePackage = ProgrammeAdaptationFingerprints.package(
          originalPackage,
        );
        final beforePlan = ProgrammeAdaptationFingerprints.plan(originalPlan);

        for (final request in const [
          AdaptationRequest(
            reason: AdaptationReason.equipment,
            availableEquipment: {'bands'},
          ),
          AdaptationRequest(reason: AdaptationReason.environment),
          AdaptationRequest(reason: AdaptationReason.recovery),
        ]) {
          final proposal = await proposalService.propose(
            package: originalPackage,
            request: request,
          );
          expect(
            proposal.outcome,
            ProgrammeAdaptationProposalOutcome.noSafeAdaptation,
            reason: request.reason.name,
          );
          expect(proposal.isAcceptable, isFalse);
          expect(proposal.allMaterialChanges, isEmpty);

          final accept = await acceptanceService.accept(
            athleteId: 'athlete.1',
            currentPackage: originalPackage,
            proposal: proposal,
            executionContext: executionContext,
          );
          expect(accept.success, isFalse);
          expect(accept.errorCode, 'not_acceptable');
        }

        expect(
          ProgrammeAdaptationFingerprints.package(originalPackage),
          beforePackage,
        );
        expect(
          ProgrammeAdaptationFingerprints.plan(originalPackage.plan),
          beforePlan,
        );
        expect(originalPackage.acceptedAdaptation, isNull);
      });

      test('no-adaptation-required is not acceptable and mutates nothing',
          () async {
        final before = ProgrammeAdaptationFingerprints.package(originalPackage);
        final proposal = await proposalService.propose(
          package: originalPackage,
          request: const AdaptationRequest(
            reason: AdaptationReason.time,
            availableMinutes: 90,
          ),
        );
        expect(
          proposal.outcome,
          ProgrammeAdaptationProposalOutcome.noAdaptationRequired,
        );
        expect(proposal.isAcceptable, isFalse);

        final accept = await acceptanceService.accept(
          athleteId: 'athlete.1',
          currentPackage: originalPackage,
          proposal: proposal,
          executionContext: executionContext,
        );
        expect(accept.success, isFalse);
        expect(
          ProgrammeAdaptationFingerprints.package(originalPackage),
          before,
        );
      });
    });

    group('Coaching Recognition fixtures', () {
      test('accepted adaptation remains recognisable as the same programme',
          () async {
        final proposal = await proposalService.propose(
          package: originalPackage,
          request: const AdaptationRequest(
            reason: AdaptationReason.time,
            availableMinutes: 40,
          ),
        );
        expect(proposal.isAcceptable, isTrue);

        final accepted = await acceptanceService.accept(
          athleteId: 'athlete.1',
          currentPackage: originalPackage,
          proposal: proposal,
          executionContext: executionContext,
        );
        expect(accepted.success, isTrue);

        final loaded = await prepareService.loadAuthoredExecutablePlan(
          accepted.package!,
          programmeContextLabel: executionContext.programmeName,
        );
        expect(loaded, isNotNull);

        ProgrammeAdaptationCoachingRecognitionFixture
            .assertProgrammeStillRecognisable(
          before: originalPackage,
          after: accepted.package!,
          reconstructedOriginalPlan: loaded!.plan,
        );

        // Active executable plan may differ; programmed identity must not.
        expect(
          ProgrammeAdaptationFingerprints.plan(accepted.package!.plan),
          proposal.reviewedPlanFingerprint,
        );
        expect(
          ProgrammeAdaptationFingerprints.plan(accepted.package!.plan),
          isNot(ProgrammeAdaptationFingerprints.plan(originalPlan)),
        );
      });

      test('reversion restores the recognisable original prepared session',
          () async {
        final proposal = await proposalService.propose(
          package: originalPackage,
          request: const AdaptationRequest(
            reason: AdaptationReason.time,
            availableMinutes: 40,
          ),
        );
        final accepted = await acceptanceService.accept(
          athleteId: 'athlete.1',
          currentPackage: originalPackage,
          proposal: proposal,
          executionContext: executionContext,
        );
        expect(accepted.success, isTrue);

        final reverted = await reversionService.revert(
          athleteId: 'athlete.1',
          currentPackage: accepted.package!,
          executionContext: executionContext,
        );
        expect(reverted.success, isTrue);

        ProgrammeAdaptationCoachingRecognitionFixture.assertOriginalRestored(
          originalBeforeAdaptation: originalPackage,
          afterRevert: reverted.package!,
        );
      });

      test('local persistence preserves Coaching Recognition provenance',
          () async {
        final proposal = await proposalService.propose(
          package: originalPackage,
          request: const AdaptationRequest(
            reason: AdaptationReason.time,
            availableMinutes: 40,
          ),
        );
        final accepted = await acceptanceService.accept(
          athleteId: 'athlete.1',
          currentPackage: originalPackage,
          proposal: proposal,
          executionContext: executionContext,
        );
        expect(accepted.success, isTrue);

        final record = await AthleteLocalRepository(kv).readGeneratedSession(
          'athlete.1',
        );
        expect(record, isNotNull);
        expect(record!.acceptedAdaptation, isNotNull);
        expect(record.protocolId, originalPackage.protocolId);
        expect(
          record.programmedSessionKey,
          originalPackage.programmedSessionKey.value,
        );
        expect(
          record.acceptedAdaptation!['programmeVersionId'],
          originalPackage.programmeVersionId,
        );
        expect(
          record.acceptedAdaptation!['packageContentHash'],
          originalPackage.packageContentHash,
        );
        expect(
          record.acceptedAdaptation!['originalPlanFingerprint'],
          ProgrammeAdaptationFingerprints.plan(originalPlan),
        );
      });
    });

    group('chain regression without post-completion or rescheduling', () {
      test('propose → accept → revert → fresh propose remains compute-then-accept',
          () async {
        final firstProposal = await proposalService.propose(
          package: originalPackage,
          request: const AdaptationRequest(
            reason: AdaptationReason.time,
            availableMinutes: 40,
          ),
        );
        final accepted = await acceptanceService.accept(
          athleteId: 'athlete.1',
          currentPackage: originalPackage,
          proposal: firstProposal,
          executionContext: executionContext,
        );
        expect(accepted.success, isTrue);

        final reverted = await reversionService.revert(
          athleteId: 'athlete.1',
          currentPackage: accepted.package!,
          executionContext: executionContext,
        );
        expect(reverted.success, isTrue);

        final replay = await acceptanceService.accept(
          athleteId: 'athlete.1',
          currentPackage: reverted.package!,
          proposal: firstProposal,
          executionContext: executionContext,
        );
        expect(replay.success, isFalse);
        expect(replay.errorCode, 'proposal_consumed');

        final fresh = await proposalService.propose(
          package: reverted.package!,
          request: const AdaptationRequest(
            reason: AdaptationReason.time,
            availableMinutes: 40,
          ),
        );
        expect(fresh.isAcceptable, isTrue);
        expect(fresh.proposalId, isNot(firstProposal.proposalId));

        final second = await acceptanceService.accept(
          athleteId: 'athlete.1',
          currentPackage: reverted.package!,
          proposal: fresh,
          executionContext: executionContext,
        );
        expect(second.success, isTrue);
      });

      test('programme adaptation owners do not open rescheduling or post-completion',
          () {
        final root = _repoRoot().path;
        final owners = [
          'lib/application/adaptation/programme_adaptation_proposal_service.dart',
          'lib/application/adaptation/programme_adaptation_acceptance_service.dart',
          'lib/application/adaptation/programme_adaptation_reversion_service.dart',
          'lib/features/home/services/programme_adapt_flow.dart',
        ];
        const forbidden = [
          'pushRight',
          'swapSession',
          'reschedule',
          'skipSession',
          'AdaptationExecutionCoordinator',
          'PostCompletionAdaptationEvaluator',
          'AdaptiveProgressionCoordinator',
          'AthleteProgrammeGenerationService',
        ];
        for (final path in owners) {
          final source = File('$root/$path').readAsStringSync();
          for (final token in forbidden) {
            expect(
              source.contains(token),
              isFalse,
              reason: '$path must not reference $token',
            );
          }
        }
      });
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
    planId: 'lineage.s16e',
    planVersion: 'version.s16e',
    week: 1,
    day: 1,
    dayKey: 'day_1',
    slotOrder: 1,
    protocolId: draft.protocolId,
    programmeAssignmentId: 'assignment.s16e',
    packageContentHash: 'hash.s16e',
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
    assignmentId: 'assignment.s16e',
    programmeVersionId: 'version.s16e',
    packageContentHash: 'hash.s16e',
    dayKey: 'day_1',
    slotOrder: 1,
    protocolId: draft.protocolId,
  );
}

Directory _repoRoot() {
  var dir = Directory.current;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return dir;
    if (dir.parent.path == dir.path) return Directory.current;
    dir = dir.parent;
  }
}
