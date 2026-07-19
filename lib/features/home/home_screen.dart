import 'package:flutter/material.dart';

import '../../core/theme/spacing.dart';
import '../../core/theme/text_styles.dart';
import '../../core/widgets/adaptation_bottom_sheet.dart';
import '../../core/widgets/adaptation_decision_bottom_sheet.dart';
import '../../core/widgets/cohort_card.dart';
import '../../core/widgets/section_title.dart';
import '../../performance/screens/training_history_screen.dart';
import 'controllers/home_today_session_refresh_controller.dart';
import 'debug/home_debug_programme_refresh_policy.dart';
import 'widgets/home_today_session_section.dart';
import '../programme/debug/programme_debug_actions.dart';
import '../programme/debug/programme_debug_resolution_cache.dart';
import '../programme/models/programme_assignment_operation_result.dart';
import '../../data/repositories/protocol_repository.dart';
import '../../data/repositories/exercise_repository.dart';
import '../../data/repositories/protocol_step_repository.dart';
import '../../models/adaptation_decision.dart';
import '../../models/adaptation_reason.dart';
import '../../models/adaptation_request.dart';
import '../../models/adaptation_session_environment.dart';
import '../../data/repositories/athlete_state_repository.dart';
import '../../models/movement_profile.dart';
import '../../models/protocol.dart';
import '../../models/protocol_analysis.dart';
import '../../models/protocol_similarity_result.dart';
import '../../models/session_fingerprint.dart';
import '../admin/admin_protocol_editor_screen.dart';
import '../coach_studio/coach_studio_home_screen.dart';
import '../coach_studio/models/coach_studio_navigation_state.dart';
import '../coach_studio/programmes/programme_catalogue_screen.dart';
import '../coach_studio/programmes/services/programme_catalogue_services.dart';
import '../adaptation/services/adaptation_candidate_filter.dart';
import '../adaptation/services/adaptation_decision_service.dart';
import '../exercises/exercise_library/exercise_library_screen.dart';
import '../protocol_analysis/services/protocol_analyzer.dart';
import '../protocol_analysis/services/protocol_similarity_service.dart';
import '../protocols/protocol_library_screen.dart';
import '../session/services/circuit_session_plan_builder.dart';
import '../session/services/interval_session_plan_builder.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _todaySessionSectionKey = GlobalKey<HomeTodaySessionSectionState>();
  final _todaySessionRefreshController = HomeTodaySessionRefreshController();

  static const _athleteId = 'lee';

  void _refreshTodaySessionAfterDebug({
    required String action,
    required String source,
    String? successMessage,
  }) {
    debugPrint('[HomeDebug] action=$action succeeded');
    debugPrint('[HomeDebug] invoking refresh source=$source');

    final sectionState = _todaySessionSectionKey.currentState;
    debugPrint(
      '[HomeDebug] todaySectionCurrentState=${sectionState != null} '
      'callbackAttached=${_todaySessionRefreshController.hasListener}',
    );

    if (sectionState != null) {
      sectionState.refresh(source: source);
    } else {
      _todaySessionRefreshController.requestRefresh(source: source);
    }

    if (successMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    }
  }

  void _openProtocolLibrary(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ProtocolLibraryScreen(),
      ),
    );
  }

  void _openExerciseLibrary(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ExerciseLibraryScreen(
          athleteId: _athleteId,
        ),
      ),
    );
  }

  void _openAdminProtocolEditor(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AdminProtocolEditorScreen(),
      ),
    );
  }

  void _openCoachStudio(BuildContext context) {
    final navigationState = CoachStudioNavigationState.instance;

    if (navigationState.shouldOpenProgrammesDirectly) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProgrammeCatalogueScreen(
            controller: ProgrammeCatalogueServices.createController(),
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CoachStudioHomeScreen(
          openProgrammesDirectly: navigationState.shouldOpenProgrammesDirectly,
        ),
      ),
    );
  }

  Future<void> _openAdaptationSheet(BuildContext context) async {
    final request = await showAdaptationBottomSheet(context);
    if (request == null || !context.mounted) return;

    const athleteStateRepository = AthleteStateRepository();
    final protocolRepository = ProtocolRepository();

    final athleteState =
        await athleteStateRepository.getAthleteState(_athleteId);
    final protocolId = athleteState?.currentProtocolId;
    if (protocolId == null) {
      debugPrint('[Adaptation] aborted: current_protocol_id is null');
      return;
    }

    final currentProtocol = await protocolRepository.getProtocolById(protocolId);
    if (currentProtocol == null) {
      debugPrint('[Adaptation] aborted: protocol not found for $protocolId');
      return;
    }

    const decisionService = AdaptationDecisionService();
    final decision = decisionService.evaluate(
      currentProtocol: currentProtocol,
      request: request,
    );

    debugPrint('[Adaptation] request: $request');
    debugPrint('[Adaptation] decision: ${decision.message}');

    if (!context.mounted) return;

    await showAdaptationDecisionBottomSheet(context, decision);
  }

  // TODO(debug): Remove temporary ProtocolAnalyzer hook once analysis UI exists.
  Future<void> _analyzeCurrentProtocol() async {
    const athleteStateRepository = AthleteStateRepository();
    final analyzer = ProtocolAnalyzer(
      ProtocolRepository(),
      const ProtocolStepRepository(),
      ExerciseRepository(),
    );

    final athleteState =
        await athleteStateRepository.getAthleteState(_athleteId);
    final protocolId = athleteState?.currentProtocolId?.trim();
    if (protocolId == null || protocolId.isEmpty) {
      debugPrint('[ProtocolAnalyzer] aborted: current_protocol_id is null');
      return;
    }

    try {
      final analysis = await analyzer.analyseProtocol(protocolId);
      _debugPrintProtocolAnalysis(analysis);
    } catch (error, stackTrace) {
      debugPrint('[ProtocolAnalyzer] failed: $error');
      debugPrint('[ProtocolAnalyzer] stackTrace: $stackTrace');
    }
  }

  void _debugPrintProtocolAnalysis(ProtocolAnalysis analysis) {
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
      _debugPrintMovementProfile(profile);
    }

    final fingerprint = analysis.fingerprint;
    if (fingerprint == null) {
      debugPrint('[ProtocolAnalyzer] fingerprint: null');
    } else {
      _debugPrintSessionFingerprint(fingerprint);
    }
  }

  void _debugPrintMovementProfile(MovementProfile profile) {
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
      '[ProtocolAnalyzer] movementProfile.pushPercent: ${_formatPercent(profile.pushPercent)}',
    );
    debugPrint(
      '[ProtocolAnalyzer] movementProfile.pullPercent: ${_formatPercent(profile.pullPercent)}',
    );
    debugPrint(
      '[ProtocolAnalyzer] movementProfile.squatPercent: ${_formatPercent(profile.squatPercent)}',
    );
    debugPrint(
      '[ProtocolAnalyzer] movementProfile.hingePercent: ${_formatPercent(profile.hingePercent)}',
    );
    debugPrint(
      '[ProtocolAnalyzer] movementProfile.lungePercent: ${_formatPercent(profile.lungePercent)}',
    );
    debugPrint(
      '[ProtocolAnalyzer] movementProfile.carryPercent: ${_formatPercent(profile.carryPercent)}',
    );
    debugPrint(
      '[ProtocolAnalyzer] movementProfile.corePercent: ${_formatPercent(profile.corePercent)}',
    );
    debugPrint(
      '[ProtocolAnalyzer] movementProfile.runningPercent: ${_formatPercent(profile.runningPercent)}',
    );
    debugPrint(
      '[ProtocolAnalyzer] movementProfile.ergPercent: ${_formatPercent(profile.ergPercent)}',
    );
    debugPrint(
      '[ProtocolAnalyzer] movementProfile.upperBodyPercent: ${_formatPercent(profile.upperBodyPercent)}',
    );
    debugPrint(
      '[ProtocolAnalyzer] movementProfile.lowerBodyPercent: ${_formatPercent(profile.lowerBodyPercent)}',
    );
    debugPrint('[ProtocolAnalyzer] movementProfile summary: $profile');
  }

  String _formatPercent(double value) {
    if (value == value.roundToDouble()) {
      return '${value.round()}%';
    }
    return '$value%';
  }

  void _debugPrintSessionFingerprint(SessionFingerprint fingerprint) {
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

  Future<void> _compileRn006IntervalPlan() async {
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
  Future<void> _compileCircuitDebugPlans() async {
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
  Future<void> _compareBw001Similarity() async {
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

      _debugPrintSimilarityDiagnostics(
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
        _debugPrintSimilarityResult(topMatches[index], rank: index + 1);
      }
    } catch (error, stackTrace) {
      debugPrint('[ProtocolSimilarity] failed: $error');
      debugPrint('[ProtocolSimilarity] stackTrace: $stackTrace');
    }
  }

  // TODO(debug): Remove once programme-driven Home replaces manual projection.
  Future<void> _assignTestProgramme() async {
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
        _refreshTodaySessionAfterDebug(
          action: 'assign',
          source: 'programme_assign',
          successMessage: 'Test programme assigned',
        );
      } else if (result.status == ProgrammeAssignmentOperationStatus.failed) {
        debugPrint('[HomeDebug] action=assign failed');
      }
    } catch (error, stackTrace) {
      debugPrint('[ProgrammeAssign] failed: $error');
      debugPrint('[ProgrammeAssign] stackTrace: $stackTrace');
    }
  }

  // TODO(debug): Remove once programme-driven Home replaces manual projection.
  Future<void> _resolveTestProgramme() async {
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
  Future<void> _syncResolvedSession() async {
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
        athleteId: _athleteId,
        resolution: resolution,
      );

      const athleteStateRepository = AthleteStateRepository();
      final athleteState =
          await athleteStateRepository.getAthleteState(_athleteId);

      debugPrint('[ProgrammeSync] projection updated for $_athleteId');
      debugPrint('[ProgrammeSync] athlete_state: $athleteState');
    } catch (error, stackTrace) {
      debugPrint('[ProgrammeSync] failed: $error');
      debugPrint('[ProgrammeSync] stackTrace: $stackTrace');
    }
  }

  // TODO(debug): Remove once programme progression is production-wired.
  Future<void> _completeCurrentProgrammeSlot({required bool partial}) async {
    try {
      final assignmentService = ProgrammeDebugActions.createAssignmentService();
      final assignment =
          await assignmentService.getCurrentAssignment(athleteId: _athleteId);
      if (assignment == null) {
        debugPrint(
          '[ProgrammeProgress] aborted: no active assignment for $_athleteId '
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
              athleteId: _athleteId,
              resolution: resolution,
            )
          : await progression.completeSession(
              athleteId: _athleteId,
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
        _refreshTodaySessionAfterDebug(
          action: partial ? 'complete_partial' : 'complete',
          source: partial ? 'programme_complete_partial' : 'programme_complete',
          successMessage: 'Current slot completed',
        );
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
  Future<void> _resetTestProgrammeAssignment() async {
    try {
      final result = await ProgrammeDebugActions.resetTestProgrammeAssignment();
      if (HomeDebugProgrammeRefreshPolicy.shouldRefreshAfterReset(result)) {
        _refreshTodaySessionAfterDebug(
          action: 'reset',
          source: 'programme_reset',
          successMessage: 'Test programme reset',
        );
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
  Future<void> _compareBw001SuitableAlternatives() async {
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

      _debugPrintHotelRoomDecisionDiagnostics(
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

        _debugPrintSimilarityResult(
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

  void _debugPrintHotelRoomDecisionDiagnostics({
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

  void _debugPrintSimilarityDiagnostics({
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

  void _debugPrintSimilarityResult(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Cohort'),
              const SizedBox(height: CohortSpacing.md),
              const Text(
                'Today',
                style: CohortTextStyles.h1,
              ),
              const SizedBox(height: CohortSpacing.md),
              const Text(
                'Know the plan. Execute with confidence.',
                style: CohortTextStyles.body,
              ),

              const SizedBox(height: CohortSpacing.xl),

              HomeTodaySessionSection(
                key: _todaySessionSectionKey,
                refreshController: _todaySessionRefreshController,
              ),

              const SizedBox(height: CohortSpacing.md),

              CohortCard(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TrainingHistoryScreen(
                        athleteId: _athleteId,
                      ),
                    ),
                  );
                },
                child: const _HomeActionRow(
                  title: 'Training History',
                  subtitle: 'Review completed sessions and performance records.',
                  status: 'OPEN',
                ),
              ),

              const SizedBox(height: CohortSpacing.xl),

              const SectionTitle('Need to Adapt?'),
              const SizedBox(height: CohortSpacing.md),

              CohortCard(
                onTap: () => _openAdaptationSheet(context),
                child: const _AdaptationPromptRow(),
              ),

              const SizedBox(height: CohortSpacing.xl),

              const SectionTitle('Knowledge'),
              const SizedBox(height: CohortSpacing.md),

              CohortCard(
                onTap: () => _openProtocolLibrary(context),
                child: const _HomeActionRow(
                  title: 'Protocol Library',
                  subtitle: 'Browse structured training sessions.',
                  status: 'OPEN',
                ),
              ),
              const SizedBox(height: CohortSpacing.md),

              CohortCard(
                onTap: () => _openExerciseLibrary(context),
                child: const _HomeActionRow(
                  title: 'Exercise Library',
                  subtitle: 'Browse movements, cues and coaching knowledge.',
                  status: 'OPEN',
                ),
              ),
              const SizedBox(height: CohortSpacing.md),

              CohortCard(
                onTap: () => _openAdminProtocolEditor(context),
                child: const _HomeActionRow(
                  title: 'Admin Protocol Editor',
                  subtitle: 'Edit protocol metadata for adaptation.',
                  status: 'ADMIN',
                ),
              ),
              const SizedBox(height: CohortSpacing.md),

              const SectionTitle('Coach Studio'),
              const SizedBox(height: CohortSpacing.md),

              CohortCard(
                onTap: () => _openCoachStudio(context),
                child: const _HomeActionRow(
                  title: 'Coach Studio',
                  subtitle:
                      'Programmes, protocols, and coach authoring tools.',
                  status: 'COACH',
                ),
              ),
              const SizedBox(height: CohortSpacing.md),

              const SizedBox(height: CohortSpacing.xl),

              const SectionTitle('DEBUG'),
              const SizedBox(height: CohortSpacing.md),

              CohortCard(
                onTap: _analyzeCurrentProtocol,
                child: const _HomeActionRow(
                  title: 'Analyze Current Protocol',
                  subtitle: 'Temporary debug hook for ProtocolAnalyzer output.',
                  status: 'DEBUG',
                ),
              ),
              const SizedBox(height: CohortSpacing.md),

              CohortCard(
                onTap: _compareBw001Similarity,
                child: const _HomeActionRow(
                  title: 'Compare BW-001 Similarity',
                  subtitle:
                      'Temporary debug hook for top protocol similarity matches.',
                  status: 'DEBUG',
                ),
              ),
              const SizedBox(height: CohortSpacing.md),

              CohortCard(
                onTap: _compileRn006IntervalPlan,
                child: const _HomeActionRow(
                  title: 'Compile RN-006 Interval Plan',
                  subtitle:
                      'Temporary debug hook for IntervalSessionPlanBuilder output.',
                  status: 'DEBUG',
                ),
              ),
              const SizedBox(height: CohortSpacing.md),

              CohortCard(
                onTap: _compileCircuitDebugPlans,
                child: const _HomeActionRow(
                  title: 'Compile Circuit Debug Plans',
                  subtitle:
                      'Temporary debug hook for BW-001, BD-001, and FG-009 circuit plans.',
                  status: 'DEBUG',
                ),
              ),
              const SizedBox(height: CohortSpacing.md),

              CohortCard(
                onTap: _compareBw001SuitableAlternatives,
                child: const _HomeActionRow(
                  title: 'Compare BW-001 Suitable Alternatives',
                  subtitle:
                      'Filter by adaptation constraints, then rank by similarity.',
                  status: 'DEBUG',
                ),
              ),
              const SizedBox(height: CohortSpacing.md),

              CohortCard(
                onTap: _assignTestProgramme,
                child: const _HomeActionRow(
                  title: 'Assign Test Programme',
                  subtitle:
                      'Assign COHORT-FOUNDATION-TEST v1 to dev athlete via ProgrammeAssignmentService.',
                  status: 'DEBUG',
                ),
              ),
              const SizedBox(height: CohortSpacing.md),

              CohortCard(
                onTap: _resolveTestProgramme,
                child: const _HomeActionRow(
                  title: 'Resolve Test Programme',
                  subtitle:
                      'Resolve only — never creates or repairs assignments.',
                  status: 'DEBUG',
                ),
              ),
              const SizedBox(height: CohortSpacing.md),

              CohortCard(
                onTap: _syncResolvedSession,
                child: const _HomeActionRow(
                  title: 'Sync Resolved Session',
                  subtitle:
                      'Project last debug resolution into athlete_state.',
                  status: 'DEBUG',
                ),
              ),
              const SizedBox(height: CohortSpacing.md),

              CohortCard(
                onTap: () => _completeCurrentProgrammeSlot(partial: false),
                child: const _HomeActionRow(
                  title: 'Complete Current Programme Slot',
                  subtitle:
                      'Upsert completed outcome and advance test assignment.',
                  status: 'DEBUG',
                ),
              ),
              const SizedBox(height: CohortSpacing.md),

              CohortCard(
                onTap: () => _completeCurrentProgrammeSlot(partial: true),
                child: const _HomeActionRow(
                  title: 'Complete Current Slot Partial',
                  subtitle:
                      'Upsert completed_partial outcome and advance cursor.',
                  status: 'DEBUG',
                ),
              ),
              const SizedBox(height: CohortSpacing.md),

              CohortCard(
                onTap: _resetTestProgrammeAssignment,
                child: const _HomeActionRow(
                  title: 'Reset Test Programme Assignment',
                  subtitle:
                      'Reset cursor to week 1 day_1 slot 1 and clear outcomes.',
                  status: 'DEBUG',
                ),
              ),

              const SizedBox(height: CohortSpacing.xxl),

              const Center(
                child: Text(
                  'Build physical capability.',
                  style: CohortTextStyles.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdaptationPromptRow extends StatelessWidget {
  const _AdaptationPromptRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Adjust Today’s Session',
                style: CohortTextStyles.cardTitle,
              ),
              const SizedBox(height: CohortSpacing.sm),
              Text(
                'Tell us what is affecting today’s session.',
                style: CohortTextStyles.small,
              ),
            ],
          ),
        ),
        const SizedBox(width: CohortSpacing.lg),
        Text('OPEN', style: CohortTextStyles.eyebrow),
      ],
    );
  }
}

class _HomeActionRow extends StatelessWidget {
  const _HomeActionRow({
    required this.title,
    required this.subtitle,
    required this.status,
  });

  final String title;
  final String subtitle;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: CohortTextStyles.cardTitle),
              const SizedBox(height: CohortSpacing.sm),
              Text(subtitle, style: CohortTextStyles.small),
            ],
          ),
        ),
        const SizedBox(width: CohortSpacing.lg),
        Text(status, style: CohortTextStyles.eyebrow),
      ],
    );
  }
}
