import 'package:flutter/foundation.dart';

import '../../data/repositories/athlete_state_repository.dart';
import '../../data/repositories/exercise_repository.dart';
import '../../data/repositories/protocol_repository.dart';
import '../../data/repositories/protocol_step_repository.dart';
import '../../models/adaptation_decision.dart';
import '../../models/adaptation_reason.dart';
import '../../models/adaptation_request.dart';
import '../../models/adaptation_session_environment.dart';
import '../../models/movement_profile.dart';
import '../../models/protocol.dart';
import '../../models/protocol_analysis.dart';
import '../../models/protocol_similarity_result.dart';
import '../../models/session_fingerprint.dart';
import '../adaptation/services/adaptation_candidate_filter.dart';
import '../adaptation/services/adaptation_decision_service.dart';
import '../home/debug/home_debug_programme_refresh_policy.dart';
import '../programme/debug/programme_debug_actions.dart';
import '../programme/debug/programme_debug_resolution_cache.dart';
import '../programme/models/programme_assignment_operation_result.dart';
import '../protocol_analysis/services/protocol_analyzer.dart';
import '../protocol_analysis/services/protocol_similarity_service.dart';
import '../session/services/circuit_session_plan_builder.dart';
import '../session/services/interval_session_plan_builder.dart';

/// Protocol and programme engineering hooks for [InternalToolsScreen].
class InternalToolsDebugActions {
  InternalToolsDebugActions._();

  // TODO(debug): Remove temporary ProtocolAnalyzer hook once analysis UI exists.
  static Future<void> analyzeCurrentProtocol({required String athleteId}) async {
    const athleteStateRepository = AthleteStateRepository();
    final analyzer = ProtocolAnalyzer(
      ProtocolRepository(),
      const ProtocolStepRepository(),
      ExerciseRepository(),
    );

    final athleteState =
        await athleteStateRepository.getAthleteState(athleteId);
    final protocolId = athleteState?.currentProtocolId?.trim();
    if (protocolId == null || protocolId.isEmpty) {
      debugPrint('[ProtocolAnalyzer] aborted: current_protocol_id is null');
      return;
    }

    try {
      final analysis = await analyzer.analyseProtocol(protocolId);
      debugPrintProtocolAnalysis(analysis);
    } catch (error, stackTrace) {
      debugPrint('[ProtocolAnalyzer] failed: $error');
      debugPrint('[ProtocolAnalyzer] stackTrace: $stackTrace');
    }
  }

  static void debugPrintProtocolAnalysis(ProtocolAnalysis analysis) {
    debugPrint('[ProtocolAnalyzer] protocolId: ${analysis.protocolId}');
    debugPrint('[ProtocolAnalyzer] protocolName: ${analysis.protocolName}');
    debugPrint('[ProtocolAnalyzer] exerciseCount: ${analysis.exerciseCount}');
    debugPrint('[ProtocolAnalyzer] stepCount: ${analysis.stepCount}');
    debugPrint(
      '[ProtocolAnalyzer] requiredEquipmentSummary: ${analysis.requiredEquipmentSummary}',
    );
    debugPrint(
      '[ProtocolAnalyzer] bodyFocusSummary: ${analysis.bodyFocusSummary}',
    );
    debugPrint('[ProtocolAnalyzer] hasRunning: ${analysis.hasRunning}');
    debugPrint('[ProtocolAnalyzer] hasErg: ${analysis.hasErg}');

    final profile = analysis.movementProfile;
    if (profile == null) {
      debugPrint('[ProtocolAnalyzer] movementProfile: null');
    } else {
      debugPrintMovementProfile(profile);
    }

    final fingerprint = analysis.fingerprint;
    if (fingerprint == null) {
      debugPrint('[ProtocolAnalyzer] fingerprint: null');
    } else {
      debugPrintSessionFingerprint(fingerprint);
    }
  }

  static void debugPrintMovementProfile(MovementProfile profile) {
    debugPrint('[ProtocolAnalyzer] movementProfile.push: ${profile.push}');
    debugPrint('[ProtocolAnalyzer] movementProfile.pull: ${profile.pull}');
    debugPrint('[ProtocolAnalyzer] movementProfile.squat: ${profile.squat}');
    debugPrint('[ProtocolAnalyzer] movementProfile.hinge: ${profile.hinge}');
    debugPrint('[ProtocolAnalyzer] movementProfile.lunge: ${profile.lunge}');
    debugPrint('[ProtocolAnalyzer] movementProfile.carry: ${profile.carry}');
    debugPrint('[ProtocolAnalyzer] movementProfile.core: ${profile.core}');
    debugPrint('[ProtocolAnalyzer] movementProfile.running: ${profile.running}');
    debugPrint('[ProtocolAnalyzer] movementProfile.erg: ${profile.erg}');
    debugPrint(
      '[ProtocolAnalyzer] movementProfile.upperBody: ${profile.upperBody}',
    );
    debugPrint(
      '[ProtocolAnalyzer] movementProfile.lowerBody: ${profile.lowerBody}',
    );
    debugPrint(
      '[ProtocolAnalyzer] movementProfile.totalMovements: ${profile.totalMovements}',
    );
    debugPrint(
      '[ProtocolAnalyzer] movementProfile.pushPercent: ${formatPercent(profile.pushPercent)}',
    );
    debugPrint(
      '[ProtocolAnalyzer] movementProfile.pullPercent: ${formatPercent(profile.pullPercent)}',
    );
    debugPrint(
      '[ProtocolAnalyzer] movementProfile.squatPercent: ${formatPercent(profile.squatPercent)}',
    );
    debugPrint(
      '[ProtocolAnalyzer] movementProfile.hingePercent: ${formatPercent(profile.hingePercent)}',
    );
    debugPrint(
      '[ProtocolAnalyzer] movementProfile.lungePercent: ${formatPercent(profile.lungePercent)}',
    );
    debugPrint(
      '[ProtocolAnalyzer] movementProfile.carryPercent: ${formatPercent(profile.carryPercent)}',
    );
    debugPrint(
      '[ProtocolAnalyzer] movementProfile.corePercent: ${formatPercent(profile.corePercent)}',
    );
    debugPrint(
      '[ProtocolAnalyzer] movementProfile.runningPercent: ${formatPercent(profile.runningPercent)}',
    );
    debugPrint(
      '[ProtocolAnalyzer] movementProfile.ergPercent: ${formatPercent(profile.ergPercent)}',
    );
    debugPrint(
      '[ProtocolAnalyzer] movementProfile.upperBodyPercent: ${formatPercent(profile.upperBodyPercent)}',
    );
    debugPrint(
      '[ProtocolAnalyzer] movementProfile.lowerBodyPercent: ${formatPercent(profile.lowerBodyPercent)}',
    );
    debugPrint('[ProtocolAnalyzer] movementProfile summary: $profile');
  }

  static String formatPercent(double value) {
    if (value == value.roundToDouble()) {
      return '${value.round()}%';
    }
    return '$value%';
  }

  static void debugPrintSessionFingerprint(SessionFingerprint fingerprint) {
    debugPrint(
      '[ProtocolAnalyzer] fingerprint.structureType: ${fingerprint.structureType.name}',
    );
    debugPrint(
      '[ProtocolAnalyzer] fingerprint.pacingStyle: ${fingerprint.pacingStyle.name}',
    );
    debugPrint(
      '[ProtocolAnalyzer] fingerprint.dominantStimulus: ${fingerprint.dominantStimulus.name}',
    );
    debugPrint(
      '[ProtocolAnalyzer] fingerprint.equipmentDependency: ${fingerprint.equipmentDependency.name}',
    );
    debugPrint(
      '[ProtocolAnalyzer] fingerprint.movementBias: ${fingerprint.movementBias.name}',
    );
    debugPrint(
      '[ProtocolAnalyzer] fingerprint.transitionDensity: ${fingerprint.transitionDensity.name}',
    );
    debugPrint(
      '[ProtocolAnalyzer] fingerprint.substitutionDifficulty: ${fingerprint.substitutionDifficulty.name}',
    );
    debugPrint('[ProtocolAnalyzer] fingerprint summary: $fingerprint');
  }

  static Future<void> compileRn006IntervalPlan() async {
    const protocolId = 'RN-006';
    final protocolRepository = ProtocolRepository();
    const stepRepository = ProtocolStepRepository();
    const planBuilder = IntervalSessionPlanBuilder();

    try {
      final protocol = await protocolRepository.getProtocolById(protocolId);
      if (protocol == null) {
        debugPrint(
          '[IntervalSessionPlanBuilder] aborted: protocol not found for $protocolId',
        );
        return;
      }

      final steps = await stepRepository.getProtocolSteps(protocolId);
      if (steps.isEmpty) {
        debugPrint(
          '[IntervalSessionPlanBuilder] aborted: no protocol steps for $protocolId',
        );
        return;
      }

      final plan = planBuilder.build(protocol: protocol, steps: steps);
      IntervalSessionPlanBuilder.debugPrintPlan(plan);
    } catch (error, stackTrace) {
      debugPrint('[IntervalSessionPlanBuilder] failed: $error');
      debugPrint('[IntervalSessionPlanBuilder] stackTrace: $stackTrace');
    }
  }

  // TODO(debug): Remove temporary circuit plan hook once CircuitSessionView exists.
  static Future<void> compileCircuitDebugPlans() async {
    const protocolIds = ['BW-001', 'BD-001', 'FG-009'];
    final protocolRepository = ProtocolRepository();
    const stepRepository = ProtocolStepRepository();
    const planBuilder = CircuitSessionPlanBuilder();

    for (final protocolId in protocolIds) {
      try {
        final protocol = await protocolRepository.getProtocolById(protocolId);
        if (protocol == null) {
          debugPrint(
            '[CircuitSessionPlanBuilder] aborted: protocol not found for $protocolId',
          );
          continue;
        }

        final steps = await stepRepository.getProtocolSteps(protocolId);
        if (steps.isEmpty) {
          debugPrint(
            '[CircuitSessionPlanBuilder] aborted: no protocol steps for $protocolId',
          );
          continue;
        }

        final plan = planBuilder.build(protocol: protocol, steps: steps);
        CircuitSessionPlanBuilder.debugPrintPlan(plan);
      } catch (error, stackTrace) {
        debugPrint(
          '[CircuitSessionPlanBuilder] failed for $protocolId: $error',
        );
        debugPrint('[CircuitSessionPlanBuilder] stackTrace: $stackTrace');
      }
    }
  }

  // TODO(debug): Remove temporary similarity hook once adaptation ranking exists.
  static Future<void> compareBw001Similarity() async {
    const sourceProtocolId = 'BW-001';
    const similarityService = ProtocolSimilarityService();
    final analyzer = ProtocolAnalyzer(
      ProtocolRepository(),
      const ProtocolStepRepository(),
      ExerciseRepository(),
    );
    final protocolRepository = ProtocolRepository();

    try {
      final sourceAnalysis = await analyzer.analyseProtocol(sourceProtocolId);
      if (sourceAnalysis.stepCount == 0) {
        debugPrint(
          '[ProtocolSimilarity] aborted: $sourceProtocolId has no analysable steps',
        );
        return;
      }

      final protocols = await protocolRepository.getProtocols();
      final candidateAnalyses = <ProtocolAnalysis>[];
      final noStepProtocolIds = <String>[];
      var protocolsWithSteps = 1;
      var protocolsWithoutSteps = 0;
      var protocolsFailedAnalysis = 0;

      for (final protocol in protocols) {
        if (protocol.protocolId == sourceProtocolId) {
          continue;
        }

        try {
          final analysis = await analyzer.analyseProtocol(protocol.protocolId);
          if (analysis.stepCount > 0) {
            candidateAnalyses.add(analysis);
            protocolsWithSteps++;
          } else {
            protocolsWithoutSteps++;
            noStepProtocolIds.add(protocol.protocolId);
          }
        } catch (error) {
          protocolsFailedAnalysis++;
          debugPrint(
            '[ProtocolSimilarity] skipped ${protocol.protocolId}: $error',
          );
        }
      }

      debugPrintSimilarityDiagnostics(
        totalProtocolsLoaded: protocols.length,
        protocolsWithSteps: protocolsWithSteps,
        protocolsWithoutSteps: protocolsWithoutSteps,
        protocolsFailedAnalysis: protocolsFailedAnalysis,
        noStepProtocolIds: noStepProtocolIds,
      );

      final results = similarityService.rankCandidates(
        source: sourceAnalysis,
        candidates: candidateAnalyses,
      );

      debugPrint(
        '[ProtocolSimilarity] compared $sourceProtocolId against '
        '${candidateAnalyses.length} protocols with analysable steps',
      );

      final topMatches = results.take(5).toList();
      if (topMatches.isEmpty) {
        debugPrint('[ProtocolSimilarity] no comparable protocols found');
        return;
      }

      for (var index = 0; index < topMatches.length; index++) {
        debugPrintSimilarityResult(topMatches[index], rank: index + 1);
      }
    } catch (error, stackTrace) {
      debugPrint('[ProtocolSimilarity] failed: $error');
      debugPrint('[ProtocolSimilarity] stackTrace: $stackTrace');
    }
  }

  // TODO(debug): Remove once programme-driven Home replaces manual projection.
  static Future<void> installFounderAcceptanceProgramme() async {
    try {
      final result =
          await ProgrammeDebugActions.installFounderAcceptanceProgramme();
      debugPrint('[FounderAcceptanceInstall] $result');
    } catch (error, stackTrace) {
      debugPrint('[FounderAcceptanceInstall] failed: $error');
      debugPrint('[FounderAcceptanceInstall] stackTrace: $stackTrace');
    }
  }

  // TODO(debug): Remove once programme-driven Home replaces manual projection.
  static Future<void> assignFounderAcceptanceProgramme({required String athleteId}) async {
    try {
      final result =
          await ProgrammeDebugActions.assignFounderAcceptanceProgramme();
      if (result.resolvedTodaySession != null) {
        ProgrammeDebugResolutionCache.store(result.resolvedTodaySession!);
      }

      if (HomeDebugProgrammeRefreshPolicy.shouldRefreshAfterAssign(result)) {
        debugPrint('[InternalTools] refresh requested after programme action');
      }
    } catch (error, stackTrace) {
      debugPrint('[FounderAcceptanceAssign] failed: $error');
      debugPrint('[FounderAcceptanceAssign] stackTrace: $stackTrace');
    }
  }

  // TODO(debug): Remove once programme-driven Home replaces manual projection.
  static Future<void> resolveFounderAcceptanceProgramme({required String athleteId}) async {
    try {
      final resolution =
          await ProgrammeDebugActions.resolveFounderAcceptanceProgramme();
      ProgrammeDebugResolutionCache.store(resolution);
      debugPrint('[FounderAcceptanceResolve] result: $resolution');
    } catch (error, stackTrace) {
      debugPrint('[FounderAcceptanceResolve] failed: $error');
      debugPrint('[FounderAcceptanceResolve] stackTrace: $stackTrace');
    }
  }

  // TODO(debug): Remove once programme progression is production-wired.
  static Future<void> resetFounderAcceptanceProgrammeAssignment({required String athleteId}) async {
    try {
      final result =
          await ProgrammeDebugActions.resetFounderAcceptanceProgrammeAssignment();
      if (HomeDebugProgrammeRefreshPolicy.shouldRefreshAfterReset(result)) {
        debugPrint('[InternalTools] refresh requested after programme action');
      } else if (result.status == ProgrammeAssignmentOperationStatus.failed ||
          result.status == ProgrammeAssignmentOperationStatus.noAssignment) {
        debugPrint(
          '[FounderAcceptanceReset] failed warnings=${result.warnings}',
        );
      }
    } catch (error, stackTrace) {
      debugPrint('[FounderAcceptanceReset] failed: $error');
      debugPrint('[FounderAcceptanceReset] stackTrace: $stackTrace');
    }
  }

  // TODO(debug): Remove once programme-driven Home replaces manual projection.
  static Future<void> assignTestProgramme({required String athleteId}) async {
    try {
      final result = await ProgrammeDebugActions.assignTestProgramme();
      if (result.resolvedTodaySession != null) {
        ProgrammeDebugResolutionCache.store(result.resolvedTodaySession!);
      }

      debugPrint('[ProgrammeAssign] result: $result');
      if (result.warnings.isNotEmpty) {
        debugPrint('[ProgrammeAssign] warnings: ${result.warnings}');
      }

      if (HomeDebugProgrammeRefreshPolicy.shouldRefreshAfterAssign(result)) {
        debugPrint('[InternalTools] refresh requested after programme action');
      } else if (result.status == ProgrammeAssignmentOperationStatus.failed) {
        debugPrint('[HomeDebug] action=assign failed');
      }
    } catch (error, stackTrace) {
      debugPrint('[ProgrammeAssign] failed: $error');
      debugPrint('[ProgrammeAssign] stackTrace: $stackTrace');
    }
  }

  // TODO(debug): Remove once programme-driven Home replaces manual projection.
  static Future<void> resolveTestProgramme({required String athleteId}) async {
    try {
      final resolution = await ProgrammeDebugActions.resolveCurrentTestSession();

      ProgrammeDebugResolutionCache.store(resolution);

      debugPrint('[ProgrammeResolve] result: $resolution');
    } catch (error, stackTrace) {
      debugPrint('[ProgrammeResolve] failed: $error');
      debugPrint('[ProgrammeResolve] stackTrace: $stackTrace');
    }
  }

  // TODO(debug): Remove once athlete_state sync is wired to Home load.
  static Future<void> syncResolvedSession({required String athleteId}) async {
    final resolution = ProgrammeDebugResolutionCache.lastResolution;
    if (resolution == null) {
      debugPrint(
        '[ProgrammeSync] aborted: run Resolve Test Programme first',
      );
      return;
    }

    try {
      final syncService = ProgrammeDebugActions.createAthleteStateSyncService();
      await syncService.syncFromResolvedSession(
        athleteId: athleteId,
        resolution: resolution,
      );

      const athleteStateRepository = AthleteStateRepository();
      final athleteState =
          await athleteStateRepository.getAthleteState(athleteId);

      debugPrint('[ProgrammeSync] projection updated for $athleteId');
      debugPrint('[ProgrammeSync] athlete_state: $athleteState');
    } catch (error, stackTrace) {
      debugPrint('[ProgrammeSync] failed: $error');
      debugPrint('[ProgrammeSync] stackTrace: $stackTrace');
    }
  }

  // TODO(debug): Remove once programme progression is production-wired.
  static Future<void> completeCurrentProgrammeSlot({
    required String athleteId,
    required bool partial,
  }) async {
    try {
      final assignmentService = ProgrammeDebugActions.createAssignmentService();
      final assignment =
          await assignmentService.getCurrentAssignment(athleteId: athleteId);
      if (assignment == null) {
        debugPrint(
          '[ProgrammeProgress] aborted: no active assignment for $athleteId '
          '— run Assign Test Programme first',
        );
        return;
      }

      final previousCursor =
          'week ${assignment.currentWeek} ${assignment.currentDayKey} '
          'slot ${assignment.currentSessionOrder}';

      final resolution = await ProgrammeDebugActions.resolveCurrentTestSession();
      ProgrammeDebugResolutionCache.clear();

      final progression = ProgrammeDebugActions.createProgressionService();
      final result = partial
          ? await progression.completeSessionPartial(
              athleteId: athleteId,
              resolution: resolution,
            )
          : await progression.completeSession(
              athleteId: athleteId,
              resolution: resolution,
            );

      debugPrint('[ProgrammeProgress] previous cursor: $previousCursor');
      debugPrint('[ProgrammeProgress] outcome: ${result.outcome}');
      debugPrint(
        '[ProgrammeProgress] updated cursor: week '
        '${result.updatedAssignment?.currentWeek} '
        '${result.updatedAssignment?.currentDayKey} '
        'slot ${result.updatedAssignment?.currentSessionOrder}',
      );
      debugPrint('[ProgrammeProgress] next session: ${result.nextResolvedSession}');
      debugPrint('[ProgrammeProgress] status: ${result.status}');
      if (result.nextResolvedSession != null) {
        ProgrammeDebugResolutionCache.store(result.nextResolvedSession!);
      } else {
        ProgrammeDebugResolutionCache.clear();
      }

      if (HomeDebugProgrammeRefreshPolicy.shouldRefreshAfterProgression(result)) {
        debugPrint('[InternalTools] refresh requested after programme action');
      } else {
        debugPrint(
          '[HomeDebug] action=${partial ? 'complete_partial' : 'complete'} '
          'skipped refresh status=${result.status}',
        );
      }
    } catch (error, stackTrace) {
      debugPrint('[ProgrammeProgress] failed: $error');
      debugPrint('[ProgrammeProgress] stackTrace: $stackTrace');
    }
  }

  // TODO(debug): Remove once programme progression is production-wired.
  static Future<void> resetTestProgrammeAssignment({required String athleteId}) async {
    try {
      final result = await ProgrammeDebugActions.resetTestProgrammeAssignment();
      if (HomeDebugProgrammeRefreshPolicy.shouldRefreshAfterReset(result)) {
        debugPrint('[InternalTools] refresh requested after programme action');
      } else if (result.status == ProgrammeAssignmentOperationStatus.failed ||
          result.status == ProgrammeAssignmentOperationStatus.noAssignment) {
        debugPrint('[HomeDebug] action=reset failed warnings=${result.warnings}');
        debugPrint('[ProgrammeReset] failed: ${result.warnings}');
      } else {
        debugPrint(
          '[HomeDebug] action=reset skipped refresh '
          'status=${result.status} assignment=${result.assignment?.id}',
        );
      }
    } catch (error, stackTrace) {
      debugPrint('[HomeDebug] action=reset failed');
      debugPrint('[ProgrammeReset] failed: $error');
      debugPrint('[ProgrammeReset] stackTrace: $stackTrace');
    }
  }

  // TODO(debug): Remove once adaptation ranking is wired to athlete UI.
  static Future<void> compareBw001SuitableAlternatives({required String athleteId}) async {
    const sourceProtocolId = 'FG-009';
    const debugRequest = AdaptationRequest(
      reason: AdaptationReason.environment,
      environment: AdaptationSessionEnvironment.hotelRoom,
    );
    const candidateFilter = AdaptationCandidateFilter();
    const decisionService = AdaptationDecisionService();
    const similarityService = ProtocolSimilarityService();
    final analyzer = ProtocolAnalyzer(
      ProtocolRepository(),
      const ProtocolStepRepository(),
      ExerciseRepository(),
    );
    final protocolRepository = ProtocolRepository();

    try {
      final currentProtocol =
          await protocolRepository.getProtocolById(sourceProtocolId);
      if (currentProtocol == null) {
        debugPrint(
          '[AdaptationSimilarity] aborted: $sourceProtocolId not found',
        );
        return;
      }

      final sourceAnalysis = await analyzer.analyseProtocol(sourceProtocolId);
      if (sourceAnalysis.stepCount == 0) {
        debugPrint(
          '[AdaptationSimilarity] aborted: $sourceProtocolId has no analysable steps',
        );
        return;
      }

      final decision = decisionService.evaluate(
        currentProtocol: currentProtocol,
        request: debugRequest,
      );

      debugPrintHotelRoomDecisionDiagnostics(
        currentProtocol: currentProtocol,
        request: debugRequest,
        decision: decision,
      );

      final selfFilterResult = candidateFilter.evaluate(
        currentProtocol: currentProtocol,
        candidateProtocol: currentProtocol,
        request: debugRequest,
      );
      debugPrint(
        '[AdaptationDecision] candidateFilterOnCurrent.isSuitable: '
        '${selfFilterResult.isSuitable}',
      );
      debugPrint(
        '[AdaptationDecision] candidateFilterOnCurrent.rejectionReason: '
        '${selfFilterResult.rejectionReason ?? 'none'}',
      );

      if (decision.decisionType == AdaptationDecisionType.keepOriginal) {
        debugPrint(
          '[AdaptationSimilarity] keeping planned session — '
          'no alternative ranking',
        );
        return;
      }

      final protocols = await protocolRepository.getProtocols();
      final protocolById = {
        for (final protocol in protocols) protocol.protocolId: protocol,
      };
      final suitableAnalyses = <ProtocolAnalysis>[];
      final rejectedCandidates = <String, String>{};
      var protocolsWithoutSteps = 0;
      var protocolsFailedAnalysis = 0;

      for (final protocol in protocols) {
        if (protocol.protocolId == sourceProtocolId) {
          continue;
        }

        try {
          final analysis = await analyzer.analyseProtocol(protocol.protocolId);
          if (analysis.stepCount == 0) {
            protocolsWithoutSteps++;
            continue;
          }

          final filterResult = candidateFilter.evaluate(
            currentProtocol: currentProtocol,
            candidateProtocol: protocol,
            request: debugRequest,
          );

          if (filterResult.isSuitable) {
            suitableAnalyses.add(analysis);
          } else {
            rejectedCandidates[protocol.protocolId] =
                filterResult.rejectionReason ?? 'Unsuitable';
          }
        } catch (error) {
          protocolsFailedAnalysis++;
          debugPrint(
            '[AdaptationSimilarity] skipped ${protocol.protocolId}: $error',
          );
        }
      }

      debugPrint(
        '[AdaptationSimilarity] diagnostics: total protocols loaded: '
        '${protocols.length}',
      );
      debugPrint(
        '[AdaptationSimilarity] diagnostics: suitable candidates: '
        '${suitableAnalyses.length}',
      );
      debugPrint(
        '[AdaptationSimilarity] diagnostics: rejected candidates: '
        '${rejectedCandidates.length}',
      );
      debugPrint(
        '[AdaptationSimilarity] diagnostics: protocols without steps: '
        '$protocolsWithoutSteps',
      );
      debugPrint(
        '[AdaptationSimilarity] diagnostics: protocols failed analysis: '
        '$protocolsFailedAnalysis',
      );

      final rejectionPreview = rejectedCandidates.entries.take(5).toList();
      for (final rejection in rejectionPreview) {
        debugPrint(
          '[AdaptationSimilarity] rejected ${rejection.key}: ${rejection.value}',
        );
      }

      if (suitableAnalyses.any(
        (analysis) => analysis.protocolId == 'FG-009',
      )) {
        debugPrint(
          '[AdaptationSimilarity] warning: FG-009 incorrectly ranked as '
          'suitable for Hotel Room',
        );
      }

      final results = similarityService.rankCandidates(
        source: sourceAnalysis,
        candidates: suitableAnalyses,
      );

      debugPrint(
        '[AdaptationSimilarity] ranked $sourceProtocolId against '
        '${suitableAnalyses.length} suitable alternatives',
      );

      final topMatches = results.take(5).toList();
      if (topMatches.isEmpty) {
        debugPrint('[AdaptationSimilarity] no suitable alternatives found');
        return;
      }

      for (var index = 0; index < topMatches.length; index++) {
        final result = topMatches[index];
        final candidateName =
            protocolById[result.candidateProtocolId]?.name ??
                result.candidateProtocolId;

        debugPrintSimilarityResult(
          result,
          rank: index + 1,
          logPrefix: '[AdaptationSimilarity]',
          candidateName: candidateName,
        );
      }
    } catch (error, stackTrace) {
      debugPrint('[AdaptationSimilarity] failed: $error');
      debugPrint('[AdaptationSimilarity] stackTrace: $stackTrace');
    }
  }

  static void debugPrintHotelRoomDecisionDiagnostics({
    required Protocol currentProtocol,
    required AdaptationRequest request,
    required AdaptationDecision decision,
  }) {
    debugPrint('[AdaptationDecision] request: $request');
    debugPrint(
      '[AdaptationDecision] currentProtocolId: ${currentProtocol.protocolId}',
    );
    debugPrint(
      '[AdaptationDecision] currentProtocolName: ${currentProtocol.name}',
    );
    debugPrint(
      '[AdaptationDecision] environment: ${request.environment?.label}',
    );
    debugPrint(
      '[AdaptationDecision] requiredEquipment: '
      '${currentProtocol.requiredEquipment ?? 'none'}',
    );
    debugPrint(
      '[AdaptationDecision] hotelFriendly: ${currentProtocol.hotelFriendly}',
    );
    debugPrint(
      '[AdaptationDecision] indoorFriendly: ${currentProtocol.indoorFriendly}',
    );
    debugPrint('[AdaptationDecision] decisionType: ${decision.decisionType}');
    debugPrint('[AdaptationDecision] decisionMessage: ${decision.message}');
  }

  static void debugPrintSimilarityDiagnostics({
    required int totalProtocolsLoaded,
    required int protocolsWithSteps,
    required int protocolsWithoutSteps,
    required int protocolsFailedAnalysis,
    required List<String> noStepProtocolIds,
  }) {
    debugPrint(
      '[ProtocolSimilarity] diagnostics: total protocols loaded: '
      '$totalProtocolsLoaded',
    );
    debugPrint(
      '[ProtocolSimilarity] diagnostics: protocols with steps: '
      '$protocolsWithSteps',
    );
    debugPrint(
      '[ProtocolSimilarity] diagnostics: protocols without steps: '
      '$protocolsWithoutSteps',
    );
    debugPrint(
      '[ProtocolSimilarity] diagnostics: protocols failed analysis: '
      '$protocolsFailedAnalysis',
    );

    final previewIds = noStepProtocolIds.take(10).toList();
    if (previewIds.isEmpty) {
      debugPrint(
        '[ProtocolSimilarity] diagnostics: no steps skipped ids: none',
      );
      return;
    }

    debugPrint(
      '[ProtocolSimilarity] diagnostics: no steps skipped ids (first 10): '
      '${previewIds.join(', ')}',
    );

    if (noStepProtocolIds.length > previewIds.length) {
      debugPrint(
        '[ProtocolSimilarity] diagnostics: no steps skipped ids: '
        '${noStepProtocolIds.length - previewIds.length} more not shown',
      );
    }
  }

  static void debugPrintSimilarityResult(
    ProtocolSimilarityResult result, {
    required int rank,
    String logPrefix = '[ProtocolSimilarity]',
    String? candidateName,
  }) {
    final scoreLabel = result.score == result.score.roundToDouble()
        ? result.score.round().toString()
        : result.score.toStringAsFixed(1);
    final candidateLabel = candidateName == null
        ? result.candidateProtocolId
        : '${result.candidateProtocolId} ($candidateName)';

    debugPrint(
      '$logPrefix #$rank $candidateLabel score: $scoreLabel',
    );

    if (result.reasons.isEmpty) {
      debugPrint('$logPrefix #$rank reasons: none');
      return;
    }

    for (final reason in result.reasons) {
      debugPrint('$logPrefix #$rank reason: $reason');
    }
  }
}
