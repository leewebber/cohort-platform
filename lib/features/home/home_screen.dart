import 'package:flutter/material.dart';

import '../../core/theme/spacing.dart';
import '../../core/theme/text_styles.dart';
import '../../core/widgets/adaptation_bottom_sheet.dart';
import '../../core/widgets/adaptation_decision_bottom_sheet.dart';
import '../../core/widgets/cohort_card.dart';
import '../../core/widgets/section_title.dart';
import '../../core/widgets/today_session_card.dart';
import '../../data/repositories/athlete_state_repository.dart';
import '../../data/repositories/programme_repository.dart';
import '../../data/repositories/protocol_repository.dart';
import '../../data/repositories/exercise_repository.dart';
import '../../data/repositories/protocol_step_repository.dart';
import '../../data/repositories/training_session_repository.dart';
import '../../models/adaptation_decision.dart';
import '../../models/adaptation_reason.dart';
import '../../models/adaptation_request.dart';
import '../../models/adaptation_session_environment.dart';
import '../../models/athlete_state.dart';
import '../../models/movement_profile.dart';
import '../../models/programme.dart';
import '../../models/protocol.dart';
import '../../models/protocol_analysis.dart';
import '../../models/protocol_similarity_result.dart';
import '../../models/session_fingerprint.dart';
import '../../models/training_session.dart';
import '../../models/training_session_status.dart';
import '../admin/admin_protocol_editor_screen.dart';
import '../adaptation/services/adaptation_candidate_filter.dart';
import '../adaptation/services/adaptation_decision_service.dart';
import '../exercises/exercise_library/exercise_library_screen.dart';
import '../protocol_analysis/services/protocol_analyzer.dart';
import '../protocol_analysis/services/protocol_similarity_service.dart';
import '../protocols/protocol_library_screen.dart';
import '../session/session_player_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _athleteId = 'lee';

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
        builder: (_) => const ExerciseLibraryScreen(),
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

  void _openSessionPlayer(
    BuildContext context, {
    required String protocolId,
    String? displayTitle,
    int? trainingSessionId,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionPlayerScreen(
          protocolId: protocolId,
          displayTitle: displayTitle,
          trainingSessionId: trainingSessionId,
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

              _TodaySessionSection(
                onBeginSession: ({
                  required protocolId,
                  displayTitle,
                  required trainingSessionId,
                }) =>
                    _openSessionPlayer(
                  context,
                  protocolId: protocolId,
                  displayTitle: displayTitle,
                  trainingSessionId: trainingSessionId,
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
                onTap: _compareBw001SuitableAlternatives,
                child: const _HomeActionRow(
                  title: 'Compare BW-001 Suitable Alternatives',
                  subtitle:
                      'Filter by adaptation constraints, then rank by similarity.',
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

class _TodaySessionData {
  const _TodaySessionData({
    required this.athleteState,
    this.programme,
    this.protocol,
    this.latestTrainingSession,
  });

  final AthleteState athleteState;
  final Programme? programme;
  final Protocol? protocol;
  final TrainingSession? latestTrainingSession;
}

enum _TodaySessionState {
  planned,
  inProgress,
  completed,
}

class _TodaySessionSection extends StatefulWidget {
  const _TodaySessionSection({
    required this.onBeginSession,
  });

  final void Function({
    required String protocolId,
    String? displayTitle,
    required int trainingSessionId,
  }) onBeginSession;

  @override
  State<_TodaySessionSection> createState() => _TodaySessionSectionState();
}

class _TodaySessionSectionState extends State<_TodaySessionSection> {
  static const _athleteId = 'lee';

  final _athleteStateRepository = const AthleteStateRepository();
  final _programmeRepository = ProgrammeRepository();
  final _protocolRepository = ProtocolRepository();
  final _trainingSessionRepository = const TrainingSessionRepository();

  late final Future<_TodaySessionData?> _todaySessionFuture;

  @override
  void initState() {
    super.initState();
    _todaySessionFuture = _loadTodaySession();
  }

  Future<_TodaySessionData?> _loadTodaySession() async {
    final athleteState =
        await _athleteStateRepository.getAthleteState(_athleteId);

    if (athleteState == null) return null;

    final programme = athleteState.programmeId != null
        ? await _programmeRepository.getProgrammeById(
            athleteState.programmeId!,
          )
        : null;

    final protocol = athleteState.currentProtocolId != null
        ? await _protocolRepository.getProtocolById(
            athleteState.currentProtocolId!,
          )
        : null;

    final latestTrainingSession =
        athleteState.currentProtocolId != null
            ? await _trainingSessionRepository
                .getLatestSessionForAthleteAndProtocol(
                athleteId: _athleteId,
                protocolId: athleteState.currentProtocolId!,
              )
            : null;

    return _TodaySessionData(
      athleteState: athleteState,
      programme: programme,
      protocol: protocol,
      latestTrainingSession: latestTrainingSession,
    );
  }

  bool _isToday(TrainingSession session) {
    final reference = session.startedAt ?? session.createdAt;
    if (reference == null) return false;

    final now = DateTime.now().toUtc();
    return reference.year == now.year &&
        reference.month == now.month &&
        reference.day == now.day;
  }

  _TodaySessionState _resolveSessionState(_TodaySessionData data) {
    final session = data.latestTrainingSession;
    if (session == null || !_isToday(session)) {
      return _TodaySessionState.planned;
    }

    switch (session.status) {
      case TrainingSessionStatus.inProgress:
        return _TodaySessionState.inProgress;
      case TrainingSessionStatus.completed:
        return _TodaySessionState.completed;
      default:
        return _TodaySessionState.planned;
    }
  }

  String _statusLabel(_TodaySessionState state) {
    switch (state) {
      case _TodaySessionState.planned:
        return 'Planned Session';
      case _TodaySessionState.inProgress:
        return 'In Progress';
      case _TodaySessionState.completed:
        return 'Completed Today';
    }
  }

  String _buttonLabel(_TodaySessionState state) {
    switch (state) {
      case _TodaySessionState.planned:
        return 'Begin';
      case _TodaySessionState.inProgress:
        return 'Resume';
      case _TodaySessionState.completed:
        return 'View Session';
    }
  }

  void _openExistingSession(_TodaySessionData data) {
    final protocolId = data.athleteState.currentProtocolId;
    final session = data.latestTrainingSession;
    if (protocolId == null || session == null) return;

    widget.onBeginSession(
      protocolId: protocolId,
      displayTitle: data.protocol?.name,
      trainingSessionId: session.id,
    );
  }

  Future<void> _handleSessionAction(
    _TodaySessionData data,
    _TodaySessionState state,
  ) async {
    switch (state) {
      case _TodaySessionState.planned:
        await _beginSession(data);
      case _TodaySessionState.inProgress:
      case _TodaySessionState.completed:
        _openExistingSession(data);
    }
  }

  String _buildSubtitle(_TodaySessionData data) {
    final parts = <String>[];

    final goal = data.athleteState.currentGoal?.trim();
    if (goal != null && goal.isNotEmpty) {
      parts.add(goal);
    }

    final capability = data.protocol?.capability?.trim();
    if (capability != null && capability.isNotEmpty) {
      parts.add(capability);
    }

    return parts.join(' • ');
  }

  String _buildWeekLabel(_TodaySessionData data) {
    final parts = <String>[];

    final programmeName = data.programme?.name.trim();
    if (programmeName != null && programmeName.isNotEmpty) {
      parts.add(programmeName);
    }

    final week = data.athleteState.currentWeek;
    if (week != null) {
      parts.add('Week $week');
    }

    return parts.join(' • ');
  }

  String _buildDuration(Protocol? protocol) {
    final durationMin = protocol?.durationMin;
    if (durationMin == null) return '';

    return '$durationMin minutes';
  }

  Future<void> _beginSession(_TodaySessionData data) async {
    debugPrint('[Begin] pressed');

    final protocolId = data.athleteState.currentProtocolId;
    if (protocolId == null) {
      debugPrint('[Begin] aborted: current_protocol_id is null');
      return;
    }

    final payload = {
      'athlete_id': _athleteId,
      'protocol_id': protocolId,
      'status': TrainingSessionStatus.inProgress.dbValue,
      'programme_id': data.athleteState.programmeId,
      'week_number': data.athleteState.currentWeek,
    };
    debugPrint('[Begin] createSession payload: $payload');

    try {
      final session = await _trainingSessionRepository.createSession(
        athleteId: _athleteId,
        protocolId: protocolId,
        status: TrainingSessionStatus.inProgress,
        programmeId: data.athleteState.programmeId,
        weekNumber: data.athleteState.currentWeek,
      );

      debugPrint('[Begin] createSession success: id=${session.id}');

      widget.onBeginSession(
        protocolId: protocolId,
        displayTitle: data.protocol?.name,
        trainingSessionId: session.id,
      );
    } catch (error, stackTrace) {
      debugPrint('[Begin] createSession failed: $error');
      debugPrint('[Begin] stackTrace: $stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_TodaySessionData?>(
      future: _todaySessionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text(
            'Loading session...',
            style: CohortTextStyles.body,
          );
        }

        final data = snapshot.data;
        if (data == null || data.protocol == null) {
          return const Text(
            'No session scheduled.',
            style: CohortTextStyles.body,
          );
        }

        final protocol = data.protocol!;
        final sessionState = _resolveSessionState(data);

        return TodaySessionCard(
          title: protocol.name,
          subtitle: _buildSubtitle(data),
          weekLabel: _buildWeekLabel(data),
          duration: _buildDuration(protocol),
          status: _statusLabel(sessionState),
          buttonLabel: _buttonLabel(sessionState),
          onPressed: data.athleteState.currentProtocolId == null
              ? null
              : () => _handleSessionAction(data, sessionState),
        );
      },
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
