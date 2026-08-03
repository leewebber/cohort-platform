import 'dart:io';

import 'package:cohort_platform/application/adaptation/adaptation_application.dart';
import 'package:cohort_platform/features/adaptation/models/accepted_adaptation_decision.dart';
import 'package:cohort_platform/features/adaptation/models/programme_adaptation_proposal.dart';
import 'package:cohort_platform/features/adaptation/services/adaptation_policy_gate.dart';
import 'package:cohort_platform/features/plans/models/programmed_session_key.dart';
import 'package:cohort_platform/features/session/models/prepared_execution_package.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/workout_player/models/workout_session_brief.dart';
import 'package:cohort_platform/models/adaptation_reason.dart';
import 'package:cohort_platform/models/adaptation_request.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/adaptation_planning_test_support.dart';

void main() {
  group('ProgrammeAdaptationProposalService', () {
    late ProtocolDraft draft;
    late PreparedExecutionPackage package;
    late ProgrammeAdaptationProposalService service;

    setUp(() {
      draft = buildTimedPlanningSession(protocolId: 'proto.adapt.1.6b');
      package = _packageFromDraft(draft);
      service = ProgrammeAdaptationProposalService(
        loadProtocolDraft: (_) async => draft,
      );
    });

    test('time constraint can produce a reviewable proposal with material changes',
        () async {
      final proposal = await service.propose(
        package: package,
        request: const AdaptationRequest(
          reason: AdaptationReason.time,
          availableMinutes: 40,
        ),
        proposedAt: DateTime.utc(2026, 8, 3, 1),
      );

      expect(proposal.outcome, ProgrammeAdaptationProposalOutcome.reviewable);
      expect(
        proposal.programmedSessionKey.value,
        package.programmedSessionKey.value,
      );
      expect(proposal.assignmentId, package.assignmentId);
      expect(proposal.programmeVersionId, package.programmeVersionId);
      expect(proposal.packageContentHash, package.packageContentHash);
      expect(proposal.protocolId, package.protocolId);
      expect(proposal.allMaterialChanges, isNotEmpty);
      expect(
        proposal.derivationExplanation,
        contains('authored prescription'),
      );
      expect(proposal.policyKinds, contains('compressForTime'));
      expect(proposal, isNot(isA<AcceptedAdaptationDecision>()));
    });

    test('reviewable proposal retains separate session and exercise changes',
        () async {
      final proposal = await service.propose(
        package: package,
        request: const AdaptationRequest(
          reason: AdaptationReason.time,
          availableMinutes: 40,
        ),
      );

      expect(proposal.isReviewable, isTrue);
      expect(
        proposal.sessionChanges.length + proposal.exerciseChanges.length,
        greaterThan(0),
      );
      for (final change in proposal.exerciseChanges) {
        expect(change.scope, ProgrammeAdaptationChangeScope.exercise);
        expect(change.summary, isNotEmpty);
        expect(change.targetId, isNotEmpty);
      }
      for (final change in proposal.sessionChanges) {
        expect(change.scope, ProgrammeAdaptationChangeScope.session);
        expect(change.summary, isNotEmpty);
      }
    });

    test('equipment reason returns typed no-safe when pipeline cannot plan',
        () async {
      final proposal = await service.propose(
        package: package,
        request: const AdaptationRequest(
          reason: AdaptationReason.equipment,
          availableEquipment: {'bands'},
        ),
      );

      expect(
        proposal.outcome,
        ProgrammeAdaptationProposalOutcome.noSafeAdaptation,
      );
      expect(proposal.noSafeReason, isNotNull);
      expect(proposal.sessionChanges, isEmpty);
      expect(proposal.exerciseChanges, isEmpty);
      expect(proposal.athleteFacingMessage.toLowerCase(), contains('could not'));
      expect(
        proposal.athleteFacingMessage.toLowerCase(),
        contains('has not changed'),
      );
    });

    test('environment and recovery reasons return typed no-safe without inventing',
        () async {
      for (final request in const [
        AdaptationRequest(reason: AdaptationReason.environment),
        AdaptationRequest(reason: AdaptationReason.recovery),
      ]) {
        final proposal = await service.propose(
          package: package,
          request: request,
        );
        expect(
          proposal.outcome,
          ProgrammeAdaptationProposalOutcome.noSafeAdaptation,
          reason: request.reason.name,
        );
        expect(proposal.allMaterialChanges, isEmpty);
      }
    });

    test('time already satisfied returns noAdaptationRequired', () async {
      final proposal = await service.propose(
        package: package,
        request: const AdaptationRequest(
          reason: AdaptationReason.time,
          availableMinutes: 90,
        ),
      );

      expect(
        proposal.outcome,
        ProgrammeAdaptationProposalOutcome.noAdaptationRequired,
      );
      expect(proposal.allMaterialChanges, isEmpty);
    });

    test('stale non-programme package returns no-safe', () async {
      final legacy = PreparedExecutionPackage(
        programmedSessionKey: const ProgrammedSessionKey(
          planId: 'plan.legacy',
          planVersion: '1.0.0',
          week: 1,
          day: 1,
        ),
        plan: package.plan,
        brief: package.brief,
        preparedAt: package.preparedAt,
      );

      final proposal = await service.propose(
        package: legacy,
        request: const AdaptationRequest(
          reason: AdaptationReason.time,
          availableMinutes: 40,
        ),
      );

      expect(
        proposal.outcome,
        ProgrammeAdaptationProposalOutcome.noSafeAdaptation,
      );
      expect(
        proposal.noSafeReason,
        ProgrammeAdaptationNoSafeReason.notProgrammeBacked,
      );
    });

    test('protocol mismatch returns no-safe and does not invent a workout',
        () async {
      final mismatched = ProgrammeAdaptationProposalService(
        loadProtocolDraft: (_) async =>
            buildTimedPlanningSession(protocolId: 'proto.other'),
      );

      final proposal = await mismatched.propose(
        package: package,
        request: const AdaptationRequest(
          reason: AdaptationReason.time,
          availableMinutes: 40,
        ),
      );

      expect(
        proposal.outcome,
        ProgrammeAdaptationProposalOutcome.noSafeAdaptation,
      );
      expect(proposal.allMaterialChanges, isEmpty);
    });

    test('propose does not mutate prepared package or plan', () async {
      final beforePackage = _packageFingerprint(package);
      final beforePlan = _planFingerprint(package.plan);

      await service.propose(
        package: package,
        request: const AdaptationRequest(
          reason: AdaptationReason.time,
          availableMinutes: 40,
        ),
      );
      await service.propose(
        package: package,
        request: const AdaptationRequest(
          reason: AdaptationReason.equipment,
          availableEquipment: {'dumbbell'},
        ),
      );

      expect(_packageFingerprint(package), beforePackage);
      expect(_planFingerprint(package.plan), beforePlan);
      expect(package.acceptedAdaptation, isNull);
    });

    test('all four reason families enter through policy-controlled mappings',
        () async {
      for (final reason in AdaptationReason.values) {
        final kinds = AdaptationPolicyGate.kindsForDayOf(reason);
        expect(kinds, isNotEmpty, reason: reason.name);
        for (final kind in kinds) {
          expect(AdaptationPolicyGate.allowed.contains(kind), isTrue);
          expect(AdaptationPolicyGate.prohibited.contains(kind), isFalse);
        }
      }
    });
  });

  group('PlanPackageSessionAdaptationAdapter routing', () {
    test('delegates to SessionAdaptationPipeline and not CoachDecisionRouter',
        () {
      final source = _readRepoFile(
        'lib/application/adaptation/plan_package_session_adaptation_adapter.dart',
      );
      final serviceSource = _readRepoFile(
        'lib/application/adaptation/programme_adaptation_proposal_service.dart',
      );
      final flowSource = _readRepoFile(
        'lib/features/home/services/programme_adapt_flow.dart',
      );

      expect(source.contains('SessionAdaptationPipeline'), isTrue);
      expect(source.contains('import '), isTrue);
      expect(source.contains("coach_decision_router"), isFalse);
      expect(serviceSource.contains("coach_decision_router"), isFalse);
      expect(serviceSource.contains('adaptive_progression/'), isFalse);
      expect(flowSource.contains("coach_decision_router"), isFalse);
      expect(flowSource.contains('adaptive_progression/'), isFalse);
      expect(flowSource.contains('athlete_programme_generation_service'), isFalse);
      expect(source.contains('withAcceptedAdaptation('), isFalse);
      expect(serviceSource.contains('withAcceptedAdaptation('), isFalse);
      expect(flowSource.contains('withAcceptedAdaptation('), isFalse);
      expect(flowSource.contains('commitDayOfAdaptation('), isFalse);
      expect(flowSource.contains('attachAdaptation('), isFalse);
    });
  });
}

String _packageFingerprint(PreparedExecutionPackage package) {
  return [
    package.programmedSessionKey.value,
    package.assignmentId ?? '',
    package.programmeVersionId ?? '',
    package.packageContentHash ?? '',
    package.protocolId ?? '',
    package.acceptedAdaptation?.decisionId ?? '',
    _planFingerprint(package.plan),
  ].join('|');
}

String _planFingerprint(SessionExecutionPlan plan) {
  final blockBits = plan.blocks
      .map(
        (b) =>
            '${b.blockId}:${b.linkedExercises.map((e) => e.exerciseId).join(',')}',
      )
      .join(';');
  return '${plan.blocks.length}|$blockBits';
}

String _readRepoFile(String relativePath) {
  var dir = Directory.current;
  while (true) {
    final candidate = File('${dir.path}/$relativePath');
    if (candidate.existsSync()) return candidate.readAsStringSync();
    if (dir.parent.path == dir.path) {
      return File(relativePath).readAsStringSync();
    }
    dir = dir.parent;
  }
}

PreparedExecutionPackage _packageFromDraft(ProtocolDraft draft) {
  final key = ProgrammedSessionKey(
    planId: 'lineage.s16b',
    planVersion: 'version.s16b',
    week: 1,
    day: 1,
    dayKey: 'day_1',
    slotOrder: 1,
    protocolId: draft.protocolId,
    programmeAssignmentId: 'assignment.s16b',
    packageContentHash: 'hash.s16b',
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
    assignmentId: 'assignment.s16b',
    programmeVersionId: 'version.s16b',
    packageContentHash: 'hash.s16b',
    dayKey: 'day_1',
    slotOrder: 1,
    protocolId: draft.protocolId,
  );
}
