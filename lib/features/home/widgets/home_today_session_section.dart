import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../../core/widgets/today_session_card.dart';
import '../../../data/repositories/training_session_repository.dart';
import '../../../models/training_session_status.dart';
import '../../../models/training_session.dart';
import '../../programme/models/programme_execution_context.dart';
import '../../programme/models/programme_progress_summary.dart';
import '../../programme/models/resolved_today_session.dart';
import '../../session/screens/session_overview_screen.dart';
import '../../session/services/session_execution_launcher.dart';
import '../controllers/home_today_session_refresh_controller.dart';
import '../models/home_today_session_state.dart';
import '../services/home_today_session_loader.dart';
import '../services/home_today_session_services.dart';

class HomeTodaySessionSection extends StatefulWidget {
  const HomeTodaySessionSection({
    super.key,
    this.refreshController,
    this.loader,
    this.loadOverride,
    required this.athleteId,
  });

  final HomeTodaySessionRefreshController? refreshController;
  final HomeTodaySessionLoader? loader;
  final Future<HomeTodaySessionState> Function(String athleteId)? loadOverride;
  final String athleteId;

  @override
  State<HomeTodaySessionSection> createState() => HomeTodaySessionSectionState();
}

class HomeTodaySessionSectionState extends State<HomeTodaySessionSection> {
  late final HomeTodaySessionLoader _loader =
      widget.loader ?? HomeTodaySessionServices.createLoader();
  final _continuationService =
      HomeTodaySessionServices.createContinuationService();
  final _progressionCoordinator =
      HomeTodaySessionServices.createProgressionCoordinator();
  final _trainingSessionRepository = const TrainingSessionRepository();
  final _sessionLauncher = SessionExecutionLauncher();

  late Future<HomeTodaySessionState> _sessionFuture;
  int _refreshGeneration = 0;
  bool _isContinuing = false;

  @override
  void initState() {
    super.initState();
    widget.refreshController?.attach(refresh);
    _sessionFuture = _loadSession(source: 'initial');
  }

  @override
  void didUpdateWidget(covariant HomeTodaySessionSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshController != widget.refreshController) {
      oldWidget.refreshController?.detach();
    }
    widget.refreshController?.attach(refresh);
  }

  @override
  void dispose() {
    widget.refreshController?.detach();
    super.dispose();
  }

  /// Reloads today's programme session from [TodaySessionService].
  void refresh({required String source}) {
    debugPrint('[HomeRefresh] refresh entered source=$source mounted=$mounted');
    if (!mounted) return;

    setState(() {
      _sessionFuture = _loadSession(source: source);
    });
  }

  Future<HomeTodaySessionState> _loadSession({required String source}) {
    final generation = ++_refreshGeneration;
    debugPrint('[HomeRefresh] load started source=$source generation=$generation');

    final Future<HomeTodaySessionState> loadFuture;
    if (widget.loadOverride != null) {
      loadFuture = widget.loadOverride!(widget.athleteId);
    } else {
      loadFuture = _loader.load(widget.athleteId);
    }

    return loadFuture.then((state) {
      if (!mounted || generation != _refreshGeneration) {
        debugPrint(
          '[HomeRefresh] ignored stale response source=$source '
          'generation=$generation active=$_refreshGeneration',
        );
        throw _StaleHomeTodaySessionRefresh();
      }

      _logResolvedState(state);
      return state;
    });
  }

  void _logResolvedState(HomeTodaySessionState state) {
    switch (state) {
      case HomeTodaySessionProgrammeExecutable():
        final resolution = state.resolution;
        debugPrint(
          '[HomeRefresh] resolved kind=${resolution.kind.name} '
          'week=${resolution.weekNumber} day=${resolution.dayKey} '
          'protocol=${state.protocol.protocolId}',
        );
      case HomeTodaySessionRestDay():
        debugPrint(
          '[HomeRefresh] resolved kind=restDay '
          'week=${state.resolution.weekNumber} day=${state.resolution.dayKey}',
        );
      case HomeTodaySessionDayComplete():
        debugPrint(
          '[HomeRefresh] resolved kind=dayComplete '
          'week=${state.resolution.weekNumber} day=${state.resolution.dayKey}',
        );
      case HomeTodaySessionProgrammeComplete():
        debugPrint('[HomeRefresh] resolved kind=programmeComplete');
      case HomeTodaySessionPaused():
        debugPrint('[HomeRefresh] resolved kind=paused');
      case HomeTodaySessionManual():
        debugPrint(
          '[HomeRefresh] resolved kind=manual '
          'protocol=${state.protocol.protocolId}',
        );
      case HomeTodaySessionError():
        debugPrint('[HomeRefresh] resolved kind=error');
      case HomeTodaySessionEmpty():
        debugPrint('[HomeRefresh] resolved kind=empty');
      case HomeTodaySessionLoading():
        debugPrint('[HomeRefresh] resolved kind=loading');
    }
  }

  bool _isToday(TrainingSession session) {
    final reference = session.startedAt ?? session.createdAt;
    if (reference == null) return false;

    final now = DateTime.now().toUtc();
    return reference.year == now.year &&
        reference.month == now.month &&
        reference.day == now.day;
  }

  _SessionButtonState _resolveButtonState(TrainingSession? session) {
    if (session == null || !_isToday(session)) {
      return _SessionButtonState.planned;
    }

    switch (session.status) {
      case TrainingSessionStatus.inProgress:
        return _SessionButtonState.inProgress;
      case TrainingSessionStatus.completed:
        return _SessionButtonState.completed;
      default:
        return _SessionButtonState.planned;
    }
  }

  String _statusLabel(_SessionButtonState state) {
    switch (state) {
      case _SessionButtonState.planned:
        return 'Planned Session';
      case _SessionButtonState.inProgress:
        return 'In Progress';
      case _SessionButtonState.completed:
        return 'Completed today';
    }
  }

  String _buttonLabel(_SessionButtonState state) {
    switch (state) {
      case _SessionButtonState.planned:
        return 'START SESSION';
      case _SessionButtonState.inProgress:
        return 'RESUME SESSION';
      case _SessionButtonState.completed:
        return 'VIEW SESSION';
    }
  }

  String _buildDuration(int? durationMin) {
    return HomeTodaySessionLabels.estimatedDuration(durationMin);
  }

  Future<void> _openSessionOverview({
    required String protocolId,
    String? displayTitle,
    required int trainingSessionId,
    ProgrammeExecutionContext? programmeContext,
    String? programmeContextLabel,
    String? sessionGoal,
    String? adaptationNotice,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionOverviewScreen(
          protocolId: protocolId,
          displayTitle: displayTitle,
          trainingSessionId: trainingSessionId,
          programmeContext: programmeContext,
          programmeContextLabel: programmeContextLabel,
          sessionGoal: sessionGoal,
          adaptationNotice: adaptationNotice,
          athleteId: widget.athleteId,
        ),
      ),
    );

    if (mounted) refresh(source: 'session_return');
  }

  Future<void> _launchActiveSession({
    required String protocolId,
    required int trainingSessionId,
    String? displayTitle,
    ProgrammeExecutionContext? programmeContext,
    String? programmeContextLabel,
    ProgrammeProgressSummary? programmeProgress,
  }) async {
    await _sessionLauncher.launchActiveSession(
      context: context,
      protocolId: protocolId,
      trainingSessionId: trainingSessionId,
      athleteId: widget.athleteId,
      displayTitle: displayTitle,
      programmeContext: programmeContext,
      programmeContextLabel: programmeContextLabel,
      programmeProgress: programmeProgress,
    );

    if (mounted) refresh(source: 'session_return');
  }

  Future<void> _beginProgrammeSession(
    HomeTodaySessionProgrammeExecutable state,
    _SessionButtonState buttonState,
  ) async {
    final contextLabel = HomeTodaySessionLabels.executableSubtitle(
      state.resolution,
      state.protocol,
    );

    if (buttonState == _SessionButtonState.completed) {
      final session = state.latestTrainingSession;
      if (session == null) return;

      await _openSessionOverview(
        protocolId: state.executionContext.effectiveProtocolId,
        displayTitle: state.protocol.name,
        trainingSessionId: session.id,
        programmeContext: state.executionContext,
        programmeContextLabel: contextLabel,
        sessionGoal: HomeTodaySessionLabels.sessionGoal(state.resolution),
        adaptationNotice: HomeTodaySessionLabels.adaptationNotice(
          state.resolution,
          state.protocol,
        ),
      );
      return;
    }

    if (buttonState == _SessionButtonState.inProgress) {
      final session = state.latestTrainingSession;
      if (session == null) return;

      await _launchActiveSession(
        protocolId: state.executionContext.effectiveProtocolId,
        displayTitle: state.protocol.name,
        trainingSessionId: session.id,
        programmeContext: state.executionContext,
        programmeContextLabel: contextLabel,
        programmeProgress: state.progressSummary,
      );
      return;
    }

    debugPrint('[Begin] programme session pressed');

    try {
      final session = await _trainingSessionRepository.createSession(
        athleteId: widget.athleteId,
        protocolId: state.executionContext.effectiveProtocolId,
        status: TrainingSessionStatus.inProgress,
        programmeId: state.resolution.lineageCode,
        weekNumber: state.resolution.weekNumber,
      );

      await _progressionCoordinator.markSessionStartedIfProgrammeBacked(
        athleteId: widget.athleteId,
        programmeContext: state.executionContext,
        trainingSessionId: session.id,
      );

      await _launchActiveSession(
        protocolId: state.executionContext.effectiveProtocolId,
        displayTitle: state.protocol.name,
        trainingSessionId: session.id,
        programmeContext: state.executionContext,
        programmeContextLabel: contextLabel,
        programmeProgress: state.progressSummary,
      );
    } catch (error, stackTrace) {
      debugPrint('[Begin] programme session failed: $error');
      debugPrint('[Begin] stackTrace: $stackTrace');
    }
  }

  Future<void> _beginManualSession(
    HomeTodaySessionManual state,
    _SessionButtonState buttonState,
  ) async {
    final protocolId = state.athleteState.currentProtocolId;
    if (protocolId == null) {
      debugPrint('[Begin] aborted: current_protocol_id is null');
      return;
    }

    if (buttonState == _SessionButtonState.completed) {
      final session = state.latestTrainingSession;
      if (session == null) return;

      await _openSessionOverview(
        protocolId: protocolId,
        displayTitle: state.protocol.name,
        trainingSessionId: session.id,
      );
      return;
    }

    if (buttonState == _SessionButtonState.inProgress) {
      final session = state.latestTrainingSession;
      if (session == null) return;

      await _launchActiveSession(
        protocolId: protocolId,
        displayTitle: state.protocol.name,
        trainingSessionId: session.id,
      );
      return;
    }

    debugPrint('[Begin] manual session pressed');

    try {
      final session = await _trainingSessionRepository.createSession(
        athleteId: widget.athleteId,
        protocolId: protocolId,
        status: TrainingSessionStatus.inProgress,
        programmeId: state.athleteState.programmeId,
        weekNumber: state.athleteState.currentWeek,
      );

      await _launchActiveSession(
        protocolId: protocolId,
        displayTitle: state.protocol.name,
        trainingSessionId: session.id,
      );
    } catch (error, stackTrace) {
      debugPrint('[Begin] manual session failed: $error');
      debugPrint('[Begin] stackTrace: $stackTrace');
    }
  }

  Future<void> _continueProgramme(ResolvedTodaySession resolution) async {
    if (_isContinuing) return;

    setState(() => _isContinuing = true);
    try {
      await _continuationService.continueFromSuggestedCursor(
        athleteId: widget.athleteId,
        resolution: resolution,
      );
      refresh(source: 'programme_continue');
    } catch (error, stackTrace) {
      debugPrint('[HomeTodaySession] continue failed: $error');
      debugPrint('[HomeTodaySession] stackTrace: $stackTrace');
    } finally {
      if (mounted) {
        setState(() => _isContinuing = false);
      }
    }
  }

  Widget _buildLoadingCard() {
    return const CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("TODAY'S TRAINING", style: CohortTextStyles.eyebrow),
          SizedBox(height: CohortSpacing.lg),
          Text('Loading today\'s training...', style: CohortTextStyles.body),
        ],
      ),
    );
  }

  Widget _buildEmptyCard() {
    return CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("TODAY'S TRAINING", style: CohortTextStyles.eyebrow),
          const SizedBox(height: CohortSpacing.lg),
          const Text('No programme assigned', style: CohortTextStyles.h2),
          const SizedBox(height: CohortSpacing.sm),
          const Text(
            'When your coach assigns a programme, today\'s session will appear here.',
            style: CohortTextStyles.body,
          ),
        ],
      ),
    );
  }

  Widget _buildError(HomeTodaySessionError state) {
    return CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TODAY', style: CohortTextStyles.eyebrow),
          const SizedBox(height: CohortSpacing.lg),
          const Text(
            'Could not load today\'s training',
            style: CohortTextStyles.h2,
          ),
          const SizedBox(height: CohortSpacing.sm),
          Text(state.message, style: CohortTextStyles.body),
          const SizedBox(height: CohortSpacing.sm),
          const Text(
            'Check your connection and try again.',
            style: CohortTextStyles.small,
          ),
          const SizedBox(height: CohortSpacing.xl),
          CohortButton(
            label: 'Retry',
            onPressed: () => refresh(source: 'retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildProgrammeStatusCard({
    required String title,
    required String subtitle,
    required String weekLabel,
    required String status,
    String? programmeName,
    String? progressLabel,
    String? buttonLabel,
    VoidCallback? onPressed,
  }) {
    return CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("TODAY'S TRAINING", style: CohortTextStyles.eyebrow),
          const SizedBox(height: CohortSpacing.lg),
          Text(title, style: CohortTextStyles.h2),
          if (programmeName != null && programmeName.trim().isNotEmpty) ...[
            const SizedBox(height: CohortSpacing.sm),
            Text(programmeName, style: CohortTextStyles.cardTitle),
          ],
          const SizedBox(height: CohortSpacing.xs),
          Text(subtitle, style: CohortTextStyles.body),
          const SizedBox(height: CohortSpacing.lg),
          Text(weekLabel, style: CohortTextStyles.small),
          if (progressLabel != null && progressLabel.trim().isNotEmpty) ...[
            const SizedBox(height: CohortSpacing.md),
            Text(progressLabel, style: CohortTextStyles.small),
          ],
          const SizedBox(height: CohortSpacing.lg),
          Row(
            children: [
              const Icon(Icons.circle, size: 10, color: Colors.green),
              const SizedBox(width: 8),
              Text(status, style: CohortTextStyles.body),
            ],
          ),
          if (buttonLabel != null) ...[
            const SizedBox(height: CohortSpacing.xl),
            CohortButton(
              label: buttonLabel,
              onPressed: onPressed ?? () {},
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HomeTodaySessionState>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError && snapshot.error is! _StaleHomeTodaySessionRefresh) {
          return _buildError(
            HomeTodaySessionError(
              error: snapshot.error!,
              message: 'Could not resolve today\'s programme session.',
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting ||
            snapshot.hasError) {
          return _buildLoadingCard();
        }

        final state = snapshot.data;
        if (state == null) {
          return _buildEmptyCard();
        }

        return switch (state) {
          HomeTodaySessionLoading() => _buildLoadingCard(),
          HomeTodaySessionError() => _buildError(state),
          HomeTodaySessionEmpty() => _buildEmptyCard(),
          HomeTodaySessionProgrammeExecutable() => () {
              final buttonState =
                  _resolveButtonState(state.latestTrainingSession);
              return TodaySessionCard(
                title: HomeTodaySessionLabels.canonicalSessionTitle(
                  state.protocol,
                ),
                subtitle: HomeTodaySessionLabels.executableSubtitle(
                  state.resolution,
                  state.protocol,
                ),
                programmeName:
                    HomeTodaySessionLabels.programmeName(state.resolution),
                weekLabel: HomeTodaySessionLabels.weekLabel(state.resolution),
                duration: _buildDuration(state.protocol.durationMin),
                sessionGoal:
                    HomeTodaySessionLabels.sessionGoal(state.resolution),
                progressLabel: HomeTodaySessionLabels.progressLabel(
                  state.progressSummary,
                ),
                adaptationNotice: HomeTodaySessionLabels.adaptationNotice(
                  state.resolution,
                  state.protocol,
                ),
                status: _statusLabel(buttonState),
                buttonLabel: _buttonLabel(buttonState),
                onPressed: () => _beginProgrammeSession(state, buttonState),
              );
            }(),
          HomeTodaySessionManual() => () {
              final buttonState =
                  _resolveButtonState(state.latestTrainingSession);
              final parts = <String>[];
              final goal = state.athleteState.currentGoal?.trim();
              if (goal != null && goal.isNotEmpty) parts.add(goal);
              final capability = state.protocol.capability?.trim();
              if (capability != null && capability.isNotEmpty) {
                parts.add(capability);
              }

              final weekParts = <String>[];
              final week = state.athleteState.currentWeek;
              if (week != null) weekParts.add('Week $week');

              return TodaySessionCard(
                title: state.protocol.name,
                subtitle: parts.isEmpty ? "Today's session" : parts.join(' • '),
                programmeName: state.programme?.name,
                weekLabel: weekParts.join(' • '),
                duration: _buildDuration(state.protocol.durationMin),
                status: _statusLabel(buttonState),
                buttonLabel: _buttonLabel(buttonState),
                onPressed: () => _beginManualSession(state, buttonState),
              );
            }(),
          HomeTodaySessionRestDay() => _buildProgrammeStatusCard(
              title: 'Rest Day',
              subtitle: 'Recovery is part of the programme.',
              programmeName:
                  HomeTodaySessionLabels.programmeName(state.resolution),
              weekLabel: HomeTodaySessionLabels.weekLabel(state.resolution),
              progressLabel: HomeTodaySessionLabels.progressLabel(
                state.progressSummary,
              ),
              status: 'Rest Day',
              buttonLabel: _isContinuing
                  ? 'Continuing...'
                  : 'Continue to next programme day',
              onPressed: _isContinuing
                  ? () {}
                  : () => _continueProgramme(state.resolution),
            ),
          HomeTodaySessionDayComplete() => _buildProgrammeStatusCard(
              title: 'Day Complete',
              subtitle: 'Required sessions for this day are finished.',
              programmeName:
                  HomeTodaySessionLabels.programmeName(state.resolution),
              weekLabel: HomeTodaySessionLabels.weekLabel(state.resolution),
              progressLabel: HomeTodaySessionLabels.progressLabel(
                state.progressSummary,
              ),
              status: 'Day Complete',
              buttonLabel:
                  _isContinuing ? 'Continuing...' : 'Continue programme',
              onPressed: _isContinuing
                  ? () {}
                  : () => _continueProgramme(state.resolution),
            ),
          HomeTodaySessionProgrammeComplete() => _buildProgrammeStatusCard(
              title: 'Programme Complete',
              subtitle: 'Congratulations — you finished this programme block.',
              programmeName: state.resolution.programmeName ??
                  state.resolution.lineageCode ??
                  'Your programme',
              weekLabel: HomeTodaySessionLabels.weekLabel(state.resolution),
              progressLabel: HomeTodaySessionLabels.progressLabel(
                state.progressSummary,
              ),
              status: 'Programme Complete',
            ),
          HomeTodaySessionPaused() => _buildProgrammeStatusCard(
              title: 'Programme Paused',
              subtitle: 'Resume your programme to continue training.',
              programmeName: state.resolution.programmeName ??
                  state.resolution.lineageCode ??
                  'Your programme',
              weekLabel: HomeTodaySessionLabels.weekLabel(state.resolution),
              progressLabel: HomeTodaySessionLabels.progressLabel(
                state.progressSummary,
              ),
              status: 'Paused',
            ),
        };
      },
    );
  }
}

enum _SessionButtonState {
  planned,
  inProgress,
  completed,
}

class _StaleHomeTodaySessionRefresh implements Exception {}
