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
import '../../models/athlete_state.dart';
import '../../models/movement_profile.dart';
import '../../models/programme.dart';
import '../../models/protocol.dart';
import '../../models/protocol_analysis.dart';
import '../../models/training_session.dart';
import '../../models/training_session_status.dart';
import '../admin/admin_protocol_editor_screen.dart';
import '../adaptation/services/adaptation_decision_service.dart';
import '../exercises/exercise_library/exercise_library_screen.dart';
import '../protocol_analysis/services/protocol_analyzer.dart';
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
      return;
    }

    _debugPrintMovementProfile(profile);
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
    debugPrint('[ProtocolAnalyzer] movementProfile summary: $profile');
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
