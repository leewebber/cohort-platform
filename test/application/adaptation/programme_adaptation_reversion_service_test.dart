import 'dart:io';

import 'package:cohort_platform/application/adaptation/adaptation_application.dart';
import 'package:cohort_platform/core/persistence/athlete_local_repository.dart';
import 'package:cohort_platform/core/persistence/local_kv_store.dart';
import 'package:cohort_platform/features/adaptation/models/accepted_adaptation_decision.dart';
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
  group('ProgrammeAdaptationReversionService', () {
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
      draft = buildTimedPlanningSession(protocolId: 'proto.accept.1.6d');
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
        programmeName: 'Reversion Fixture',
        packageContentHash: originalPackage.packageContentHash,
        programmedSessionKey: originalPackage.programmedSessionKey.value,
      );
    });

    Future<PreparedExecutionPackage> acceptAdapted() async {
      final proposal = await proposalService.propose(
        package: originalPackage,
        request: const AdaptationRequest(
          reason: AdaptationReason.time,
          availableMinutes: 40,
        ),
        proposedAt: DateTime.utc(2026, 8, 3, 2),
      );
      expect(proposal.isAcceptable, isTrue);
      final accepted = await acceptanceService.accept(
        athleteId: 'athlete.1',
        currentPackage: originalPackage,
        proposal: proposal,
        executionContext: executionContext,
        acceptedAt: DateTime.utc(2026, 8, 3, 3),
      );
      expect(accepted.success, isTrue);
      return accepted.package!;
    }

    test('reverts adapted package to authoritative original plan', () async {
      final adapted = await acceptAdapted();
      final adaptedFp = ProgrammeAdaptationFingerprints.plan(adapted.plan);
      final originalFp = ProgrammeAdaptationFingerprints.plan(originalPlan);
      expect(adaptedFp, isNot(originalFp));
      expect(adapted.hasAcceptedAdaptation, isTrue);

      final result = await reversionService.revert(
        athleteId: 'athlete.1',
        currentPackage: adapted,
        executionContext: executionContext,
      );

      expect(result.success, isTrue);
      final reverted = result.package!;
      expect(reverted.hasAcceptedAdaptation, isFalse);
      expect(reverted.acceptedAdaptation, isNull);
      expect(
        ProgrammeAdaptationFingerprints.plan(reverted.plan),
        originalFp,
      );
      expect(
        reverted.programmedSessionKey.value,
        originalPackage.programmedSessionKey.value,
      );
      expect(reverted.assignmentId, originalPackage.assignmentId);
      expect(reverted.programmeVersionId, originalPackage.programmeVersionId);
      expect(reverted.packageContentHash, originalPackage.packageContentHash);
      expect(reverted.protocolId, originalPackage.protocolId);
      expect(adapted.hasAcceptedAdaptation, isTrue);
    });

    test('non-adapted package cannot be reverted', () async {
      final result = await reversionService.revert(
        athleteId: 'athlete.1',
        currentPackage: originalPackage,
        executionContext: executionContext,
      );
      expect(result.success, isFalse);
      expect(result.errorCode, 'not_adapted');
      expect(originalPackage.hasAcceptedAdaptation, isFalse);
    });

    test('mismatched assignment fails closed', () async {
      final adapted = await acceptAdapted();
      final mismatched = ProgrammeExecutionContext(
        assignmentId: 'other.assignment',
        programmeVersionId: executionContext.programmeVersionId,
        sessionSlotId: executionContext.sessionSlotId,
        weekNumber: executionContext.weekNumber,
        dayKey: executionContext.dayKey,
        sessionOrder: executionContext.sessionOrder,
        plannedProtocolId: executionContext.plannedProtocolId,
        effectiveProtocolId: executionContext.effectiveProtocolId,
        programmeName: executionContext.programmeName,
        packageContentHash: executionContext.packageContentHash,
        programmedSessionKey: executionContext.programmedSessionKey,
      );
      final result = await reversionService.revert(
        athleteId: 'athlete.1',
        currentPackage: adapted,
        executionContext: mismatched,
      );
      expect(result.success, isFalse);
      expect(result.errorCode, 'stale_identity');
      expect(adapted.hasAcceptedAdaptation, isTrue);
    });

    test('mismatched package hash fails closed', () async {
      final adapted = await acceptAdapted();
      final mismatched = ProgrammeExecutionContext(
        assignmentId: executionContext.assignmentId,
        programmeVersionId: executionContext.programmeVersionId,
        sessionSlotId: executionContext.sessionSlotId,
        weekNumber: executionContext.weekNumber,
        dayKey: executionContext.dayKey,
        sessionOrder: executionContext.sessionOrder,
        plannedProtocolId: executionContext.plannedProtocolId,
        effectiveProtocolId: executionContext.effectiveProtocolId,
        programmeName: executionContext.programmeName,
        packageContentHash: 'hash.other',
        programmedSessionKey: executionContext.programmedSessionKey,
      );
      final result = await reversionService.revert(
        athleteId: 'athlete.1',
        currentPackage: adapted,
        executionContext: mismatched,
      );
      expect(result.success, isFalse);
      expect(result.errorCode, 'stale_identity');
    });

    test('reconstruction fingerprint mismatch fails closed', () async {
      final adapted = await acceptAdapted();
      final wrongLoader = AthleteProgrammeSessionPrepareService(
        assignmentStore: InMemoryProgrammeAssignmentStore(
          InMemoryProgrammeTables(),
        ),
        slotResolver: AthleteProgrammeAuthoredSlotResolver(
          versionStore: InMemoryProgrammeVersionStore(InMemoryProgrammeTables()),
        ),
        sessionLoader: _FixedLoader(
          SessionExecutionPlan(
            sessionId: 'wrong',
            sessionTitle: 'Wrong',
            blocks: originalPlan.blocks,
            durationMin: 1,
          ),
        ),
        localRepository: AthleteLocalRepository(InMemoryKvStore()),
      );
      final isolated = ProgrammeAdaptationReversionService(
        prepareService: wrongLoader,
      );
      // Seed cache with adapted so race check is skipped when null path...
      // Cache is empty on isolated service — reconstruction still fails fingerprint.
      final result = await isolated.revert(
        athleteId: 'athlete.1',
        currentPackage: adapted,
        executionContext: executionContext,
      );
      expect(result.success, isFalse);
      expect(result.errorCode, 'original_fingerprint_mismatch');
      expect(adapted.hasAcceptedAdaptation, isTrue);
    });

    test('repeated revert after success is ineligible', () async {
      final adapted = await acceptAdapted();
      final first = await reversionService.revert(
        athleteId: 'athlete.1',
        currentPackage: adapted,
        executionContext: executionContext,
      );
      expect(first.success, isTrue);

      final second = await reversionService.revert(
        athleteId: 'athlete.1',
        currentPackage: first.package!,
        executionContext: executionContext,
      );
      expect(second.success, isFalse);
      expect(second.errorCode, 'not_adapted');
    });

    test('persisted revert restores original without active acceptance',
        () async {
      final adapted = await acceptAdapted();
      final reverted = await reversionService.revert(
        athleteId: 'athlete.1',
        currentPackage: adapted,
        executionContext: executionContext,
      );
      expect(reverted.success, isTrue);

      final record = await AthleteLocalRepository(kv).readGeneratedSession(
        'athlete.1',
      );
      expect(record, isNotNull);
      expect(record!.acceptedAdaptation, isNull);
      expect(
        ProgrammeAdaptationFingerprints.plan(record.plan),
        ProgrammeAdaptationFingerprints.plan(originalPlan),
      );

      // Simulate relaunch: new prepare service, same local store.
      final relaunched = AthleteProgrammeSessionPrepareService(
        assignmentStore: InMemoryProgrammeAssignmentStore(
          InMemoryProgrammeTables(),
        ),
        slotResolver: AthleteProgrammeAuthoredSlotResolver(
          versionStore: InMemoryProgrammeVersionStore(InMemoryProgrammeTables()),
        ),
        sessionLoader: _FixedLoader(originalPlan),
        localRepository: AthleteLocalRepository(kv),
      );
      // Direct record read already proves persistence; rebuild package from record
      // mirrors prepare restore of acceptedAdaptation null + original plan.
      final restoredDecision = record.acceptedAdaptation;
      expect(restoredDecision, isNull);
      expect(relaunched.cachedPackageForKey(
        originalPackage.programmedSessionKey.value,
      ), isNull);
    });

    test('old accepted proposal cannot be replayed after reversion', () async {
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

      final replay = await acceptanceService.accept(
        athleteId: 'athlete.1',
        currentPackage: reverted.package!,
        proposal: proposal,
        executionContext: executionContext,
      );
      expect(replay.success, isFalse);
      expect(replay.errorCode, 'proposal_consumed');
    });

    test('fresh proposal can be accepted after reversion', () async {
      final adapted = await acceptAdapted();
      final reverted = await reversionService.revert(
        athleteId: 'athlete.1',
        currentPackage: adapted,
        executionContext: executionContext,
      );
      expect(reverted.success, isTrue);

      final fresh = await proposalService.propose(
        package: reverted.package!,
        request: const AdaptationRequest(
          reason: AdaptationReason.time,
          availableMinutes: 40,
        ),
      );
      expect(fresh.isAcceptable, isTrue);
      final second = await acceptanceService.accept(
        athleteId: 'athlete.1',
        currentPackage: reverted.package!,
        proposal: fresh,
        executionContext: executionContext,
      );
      expect(second.success, isTrue);
      expect(second.package!.hasAcceptedAdaptation, isTrue);
    });

    test('reversion source does not invoke adaptation pipeline', () {
      final root = _repoRoot();
      final source = File(
        '${root.path}/lib/application/adaptation/programme_adaptation_reversion_service.dart',
      ).readAsStringSync();
      expect(source.contains('SessionAdaptationPipeline'), isFalse);
      expect(source.contains('PlanPackageSessionAdaptationAdapter'), isFalse);
      expect(source.contains('AdaptiveProgression'), isFalse);
      expect(source.contains('CoachDecisionRouter'), isFalse);
      expect(source.contains('loadAuthoredExecutablePlan'), isTrue);
      expect(source.contains('withRevertedToOriginal'), isTrue);
    });

    test('missing original fingerprint fails closed', () async {
      final adapted = await acceptAdapted();
      final brokenDecision = AcceptedAdaptationDecision(
        decisionId: adapted.acceptedAdaptation!.decisionId,
        programmedSessionKey: adapted.acceptedAdaptation!.programmedSessionKey,
        reasonCode: adapted.acceptedAdaptation!.reasonCode,
        acceptedAt: adapted.acceptedAdaptation!.acceptedAt,
        assignmentId: adapted.acceptedAdaptation!.assignmentId,
        programmeVersionId: adapted.acceptedAdaptation!.programmeVersionId,
        packageContentHash: adapted.acceptedAdaptation!.packageContentHash,
        protocolId: adapted.acceptedAdaptation!.protocolId,
        originalPlanFingerprint: null,
      );
      final broken = PreparedExecutionPackage(
        programmedSessionKey: adapted.programmedSessionKey,
        plan: adapted.plan,
        brief: adapted.brief,
        preparedAt: adapted.preparedAt,
        assignmentId: adapted.assignmentId,
        programmeVersionId: adapted.programmeVersionId,
        packageContentHash: adapted.packageContentHash,
        dayKey: adapted.dayKey,
        slotOrder: adapted.slotOrder,
        protocolId: adapted.protocolId,
        acceptedAdaptation: brokenDecision,
      );
      // Align cache with broken package for race check.
      await prepareService.replacePreparedPackage(
        athleteId: 'athlete.1',
        package: broken,
        executionContext: executionContext,
      );

      final result = await reversionService.revert(
        athleteId: 'athlete.1',
        currentPackage: broken,
        executionContext: executionContext,
      );
      expect(result.success, isFalse);
      expect(result.errorCode, 'missing_original_fingerprint');
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
    planId: 'lineage.s16d',
    planVersion: 'version.s16d',
    week: 1,
    day: 1,
    dayKey: 'day_1',
    slotOrder: 1,
    protocolId: draft.protocolId,
    programmeAssignmentId: 'assignment.s16d',
    packageContentHash: 'hash.s16d',
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
    assignmentId: 'assignment.s16d',
    programmeVersionId: 'version.s16d',
    packageContentHash: 'hash.s16d',
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
