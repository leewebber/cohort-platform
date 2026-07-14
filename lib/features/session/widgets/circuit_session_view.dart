import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../../data/repositories/training_session_circuit_repository.dart';
import '../../../data/repositories/training_session_repository.dart';
import '../../../models/circuit_format.dart';
import '../../../models/circuit_movement_prescription.dart';
import '../../../models/circuit_performance.dart';
import '../../../models/circuit_performance_entry.dart';
import '../../../models/circuit_score_type.dart';
import '../../../models/circuit_session_execution_state.dart';
import '../../../models/circuit_session_plan.dart';
import '../../../models/circuit_progress_result.dart';
import '../../../models/previous_circuit_performance.dart';
import '../models/circuit_session_finish_summary.dart';
import '../models/circuit_timer_state.dart';
import '../models/early_session_end_result.dart';
import '../models/session_leave_decision.dart';
import '../services/circuit_finish_validator.dart';
import '../services/circuit_performance_mapper.dart';
import '../services/circuit_progress_service.dart';
import '../services/circuit_session_hydrator.dart';
import '../services/circuit_session_leave_coordinator.dart';
import '../services/circuit_timer_controller.dart';
import '../services/previous_circuit_performance_service.dart';
import 'shared/early_session_end_dialog.dart';
import 'shared/previous_performance_shell.dart';
import 'shared/progress_result_card.dart';
import 'shared/session_execution_header.dart';
import 'shared/session_finish_actions.dart';
import 'shared/session_note_field.dart';
import 'shared/session_progress_summary.dart';

/// Dedicated execution view for circuit / WOD sessions (v0.1).
///
/// Orchestrates [CircuitSessionExecutionState] in memory and persists scores to
/// `training_session_circuits` when [trainingSessionId] is set.
class CircuitSessionView extends StatefulWidget {
  const CircuitSessionView({
    super.key,
    required this.sessionTitle,
    required this.plan,
    required this.onFinishSession,
    this.previewMode = false,
    this.trainingSessionId,
    this.athleteId,
    this.protocolId,
    TrainingSessionCircuitStore? circuitRepository,
    CircuitPerformanceMapper? performanceMapper,
    CircuitSessionHydrator? sessionHydrator,
    TrainingSessionRepository? trainingSessionRepository,
    CircuitFinishValidator? finishValidator,
    PreviousCircuitPerformanceService? previousPerformanceService,
    CircuitProgressService? progressService,
    this.onLeaveCoordinatorReady,
  })  : circuitRepository =
            circuitRepository ?? const TrainingSessionCircuitRepository(),
        performanceMapper =
            performanceMapper ?? const CircuitPerformanceMapper(),
        sessionHydrator = sessionHydrator ?? const CircuitSessionHydrator(),
        trainingSessionRepository =
            trainingSessionRepository ?? const TrainingSessionRepository(),
        finishValidator = finishValidator ?? const CircuitFinishValidator(),
        previousPerformanceService = previousPerformanceService ??
            const PreviousCircuitPerformanceService(),
        progressService = progressService ?? const CircuitProgressService();

  final String sessionTitle;
  final CircuitSessionPlan plan;
  final Future<void> Function(CircuitSessionFinishSummary summary)
      onFinishSession;
  final bool previewMode;
  final int? trainingSessionId;
  final String? athleteId;
  final String? protocolId;
  final TrainingSessionCircuitStore circuitRepository;
  final CircuitPerformanceMapper performanceMapper;
  final CircuitSessionHydrator sessionHydrator;
  final TrainingSessionRepository trainingSessionRepository;
  final CircuitFinishValidator finishValidator;
  final PreviousCircuitPerformanceService previousPerformanceService;
  final CircuitProgressService progressService;
  final void Function(CircuitSessionLeaveCoordinator coordinator)?
      onLeaveCoordinatorReady;

  @override
  State<CircuitSessionView> createState() => _CircuitSessionViewState();
}

class _CircuitSessionViewState extends State<CircuitSessionView> {
  static const _validator = CircuitFinishValidator();

  late CircuitSessionExecutionState _executionState;
  late final CircuitTimerController _timerController;
  CircuitTimerState? _timerState;

  final _completedRoundsController = TextEditingController();
  final _additionalRepsController = TextEditingController();
  final _totalRepsController = TextEditingController();
  final _completedIntervalsController = TextEditingController();
  final _completedMovementsController = TextEditingController();
  final _elapsedMinutesController = TextEditingController();
  final _elapsedSecondsController = TextEditingController();
  final _actualLoadController = TextEditingController();
  final _athleteNoteController = TextEditingController();

  bool _isHydratingSession = false;
  bool _preservePerformance = false;
  bool _sessionNoteLocallyEdited = false;
  bool _isSavingPerformance = false;

  PreviousCircuitPerformance? _previousPerformance;
  CircuitProgressResult? _progressResult;
  bool _isLoadingPreviousPerformance = false;
  bool _hasLoadedPreviousPerformance = false;

  bool get _shouldLoadPreviousPerformance =>
      !widget.previewMode &&
      widget.athleteId != null &&
      widget.protocolId != null;

  bool get _isRealSession =>
      !widget.previewMode && widget.trainingSessionId != null;

  bool get hasRecordedProgress =>
      _executionState.hasRecordedProgress || _hasWorkStarted;

  bool get _isPostSession =>
      _executionState.entryMode == CircuitEntryMode.postSession;

  bool get _hasValidScore => _validator.hasValidScore(
        performance: _executionState.performance,
        scoreType: widget.plan.scoreType,
      );

  bool get _hasWorkStarted => _validator.hasWorkStarted(
        state: _executionState,
        timerState: _timerState,
      );

  @override
  void initState() {
    super.initState();
    _executionState = CircuitSessionExecutionState(
      plan: widget.plan,
      performance: CircuitPerformanceEntry(
        localId: 'circuit-performance-${widget.plan.protocolId ?? 'local'}',
      ),
      trainingSessionId: widget.trainingSessionId,
    );

    _timerController = CircuitTimerController(
      plan: widget.plan,
      onStateChanged: (state) {
        if (!mounted) {
          return;
        }
        setState(() => _timerState = state);
      },
      onFinished: _handleTimerFinished,
    );

    if (_isRealSession) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadPersistedSessionState();
      });
    }

    if (_shouldLoadPreviousPerformance) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadPreviousCircuitPerformance();
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onLeaveCoordinatorReady?.call(
        CircuitSessionLeaveCoordinator(
          hasRecordedProgress: () => hasRecordedProgress,
          confirmLeave: _confirmLeaveSession,
        ),
      );
    });
  }

  @override
  void dispose() {
    _timerController.dispose();
    _completedRoundsController.dispose();
    _additionalRepsController.dispose();
    _totalRepsController.dispose();
    _completedIntervalsController.dispose();
    _completedMovementsController.dispose();
    _elapsedMinutesController.dispose();
    _elapsedSecondsController.dispose();
    _actualLoadController.dispose();
    _athleteNoteController.dispose();
    super.dispose();
  }

  void _handleTimerFinished(CircuitTimerState state) {
    final performance = _executionState.performance;
    CircuitPerformanceEntry updated = performance;

    if (widget.plan.scoreType == CircuitScoreType.elapsedTime ||
        (widget.plan.scoreType == CircuitScoreType.benchmarkScore &&
            CircuitTimerController.resolveMode(widget.plan) ==
                CircuitTimerMode.countUp)) {
      updated = updated.copyWith(
        elapsedDuration: Duration(seconds: state.elapsedSeconds),
        timeCapped: state.timeCapped,
      );
      _syncElapsedFields(updated.elapsedDuration);
    }

    if (widget.plan.scoreType == CircuitScoreType.roundsCompleted) {
      final completed = state.timeCapped || state.finished
          ? state.currentInterval
          : state.currentInterval - 1;
      updated = updated.copyWith(
        completedRounds: completed.clamp(0, 999),
        timeCapped: state.timeCapped,
      );
      _completedIntervalsController.text = completed.toString();
    }

    if (widget.plan.scoreType == CircuitScoreType.roundsAndReps &&
        state.timeCapped) {
      updated = updated.copyWith(timeCapped: true);
    }

    if (widget.plan.scoreType == CircuitScoreType.totalReps && state.timeCapped) {
      updated = updated.copyWith(timeCapped: true);
    }

    setState(() {
      _executionState = _executionState.updatePerformance(updated);
      _recalculateProgress();
    });
  }

  void _recalculateProgress() {
    if (!_hasValidScore) {
      _progressResult = null;
      return;
    }

    _progressResult = widget.progressService.evaluate(
      previousPerformance: _previousPerformance,
      todayPerformance: _executionState.performance,
      plan: widget.plan,
    );
  }

  void _syncElapsedFields(Duration? duration) {
    if (duration == null) {
      return;
    }

    _elapsedMinutesController.text = (duration.inSeconds ~/ 60).toString();
    _elapsedSecondsController.text =
        (duration.inSeconds % 60).toString().padLeft(2, '0');
  }

  void _preserveLocalPerformance() {
    _preservePerformance = true;
  }

  Future<void> _loadPreviousCircuitPerformance() async {
    final athleteId = widget.athleteId;
    final protocolId = widget.protocolId;
    if (athleteId == null || protocolId == null) {
      return;
    }

    setState(() => _isLoadingPreviousPerformance = true);

    try {
      final previous = await widget.previousPerformanceService.load(
        athleteId: athleteId,
        protocolId: protocolId,
        excludeTrainingSessionId: widget.trainingSessionId,
        prescribedIntervalCount: widget.plan.intervalCount,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _previousPerformance = previous;
        _hasLoadedPreviousPerformance = true;
        _recalculateProgress();
      });
    } catch (error) {
      debugPrint(
        '[CircuitSessionView] previous circuit performance load failed: $error',
      );
      if (mounted) {
        setState(() => _hasLoadedPreviousPerformance = true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingPreviousPerformance = false);
      }
    }
  }

  Future<void> _loadPersistedSessionState() async {
    final trainingSessionId = widget.trainingSessionId;
    if (trainingSessionId == null) {
      return;
    }

    setState(() => _isHydratingSession = true);

    try {
      CircuitPerformance? persisted;
      try {
        persisted =
            await widget.circuitRepository.getPerformanceForTrainingSession(
          trainingSessionId,
        );
      } catch (error) {
        debugPrint(
          '[CircuitSessionView] performance hydrate failed: $error',
        );
      }

      String? sessionNote;
      try {
        final session =
            await widget.trainingSessionRepository.getSessionById(trainingSessionId);
        sessionNote = session?.sessionNote;
      } catch (error) {
        debugPrint(
          '[CircuitSessionView] session note hydrate failed: $error',
        );
      }

      if (!mounted) {
        return;
      }

      final hydrated = widget.sessionHydrator.hydrate(
        plan: widget.plan,
        baseState: _executionState,
        persisted: persisted,
        preservePerformance: _preservePerformance,
        sessionNote: sessionNote,
        preserveSessionNote: _sessionNoteLocallyEdited,
      );

      setState(() {
        _executionState = hydrated;
        if (!_preservePerformance) {
          _syncControllersFromPerformance();
        }
      });
    } catch (error) {
      debugPrint('[CircuitSessionView] session hydrate failed: $error');
    } finally {
      if (mounted) {
        setState(() => _isHydratingSession = false);
      }
    }
  }

  void _syncControllersFromPerformance() {
    final performance = _executionState.performance;

    _completedRoundsController.text =
        performance.completedRounds?.toString() ?? '';
    _additionalRepsController.text =
        performance.additionalReps?.toString() ?? '';
    _totalRepsController.text = performance.totalReps?.toString() ?? '';
    _completedIntervalsController.text =
        performance.completedRounds?.toString() ?? '';
    _completedMovementsController.text =
        performance.completedMovements?.toString() ?? '';
    _actualLoadController.text = performance.actualLoad ?? '';
    _athleteNoteController.text = performance.athleteNote ?? '';
    _syncElapsedFields(performance.elapsedDuration);
  }

  void _updatePerformance(CircuitPerformanceEntry updated) {
    _preserveLocalPerformance();
    setState(() {
      _executionState = _executionState.updatePerformance(updated);
      _recalculateProgress();
    });
  }

  void _updateSessionNote(String value) {
    _sessionNoteLocallyEdited = true;
    setState(() {
      _executionState = _executionState.copyWith(
        sessionNote: value.trim().isEmpty ? null : value,
        clearSessionNote: value.trim().isEmpty,
      );
    });
  }

  Future<void> _persistPerformance({
    required bool completed,
    bool skipped = false,
  }) async {
    final trainingSessionId = widget.trainingSessionId;
    final protocolId = widget.protocolId ?? widget.plan.protocolId;
    if (!_isRealSession || trainingSessionId == null || protocolId == null) {
      return;
    }

    final performance = widget.performanceMapper.fromEntry(
      trainingSessionId: trainingSessionId,
      protocolId: protocolId,
      plan: widget.plan,
      entry: _executionState.performance,
      completed: completed,
      skipped: skipped,
    );

    try {
      await widget.circuitRepository.upsertCircuitPerformance(performance);
      if (mounted) {
        setState(() => _preservePerformance = false);
      }
    } catch (error) {
      debugPrint('[CircuitSessionView] performance save failed: $error');
      _showPersistenceError(
        'Result saved locally, but performance could not be synced right now.',
      );
    }
  }

  Future<void> _saveProgress() async {
    if (!_executionState.performance.hasRecordedScore) {
      return;
    }

    setState(() => _isSavingPerformance = true);
    try {
      await _persistPerformance(completed: false);
    } finally {
      if (mounted) {
        setState(() => _isSavingPerformance = false);
      }
    }
  }

  void _showPersistenceError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: CohortTextStyles.small.copyWith(color: CohortColors.textPrimary),
        ),
        backgroundColor: CohortColors.surfaceRaised,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _setEntryMode(CircuitEntryMode mode) {
    if (mode == CircuitEntryMode.postSession) {
      _timerController.reset();
      _timerState = null;
    }

    setState(() {
      _executionState = _executionState.copyWith(entryMode: mode);
    });
  }

  CircuitSessionFinishSummary _buildFinishSummary({
    bool endedEarly = false,
    String? completionReason,
  }) {
    _recalculateProgress();

    return CircuitSessionFinishSummary(
      sessionTitle: widget.sessionTitle,
      format: widget.plan.format,
      scoreType: widget.plan.scoreType,
      performance: _executionState.performance.copyWith(completed: true),
      endedEarly: endedEarly,
      completionReason: completionReason,
      sessionNote: _executionState.sessionNote,
      progressResult: _progressResult,
    );
  }

  Future<void> _finishSession({
    bool endedEarly = false,
    String? completionReason,
  }) async {
    await _persistPerformance(completed: true);

    final summary = _buildFinishSummary(
      endedEarly: endedEarly,
      completionReason: completionReason,
    );

    await widget.onFinishSession(summary);
  }

  Future<void> _confirmLeaveSession(BuildContext context) async {
    if (!_isRealSession || !hasRecordedProgress) {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    final choice = await showDialog<SessionLeaveDecision>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: CohortColors.surfaceRaised,
          title: Text(
            'Leave this session?',
            style: CohortTextStyles.cardTitle,
          ),
          content: Text(
            'Your saved result is preserved. You can resume this session later from Home.',
            style: CohortTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext)
                  .pop(SessionLeaveDecision.resumeLater),
              child: Text(
                'Resume later',
                style: CohortTextStyles.body.copyWith(color: CohortColors.olive),
              ),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(SessionLeaveDecision.endEarly),
              child: Text(
                'End session early',
                style: CohortTextStyles.body.copyWith(color: CohortColors.warning),
              ),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(SessionLeaveDecision.cancel),
              child: Text(
                'Cancel',
                style: CohortTextStyles.body,
              ),
            ),
          ],
        );
      },
    );

    if (!context.mounted ||
        choice == null ||
        choice == SessionLeaveDecision.cancel) {
      return;
    }

    switch (choice) {
      case SessionLeaveDecision.resumeLater:
        await _persistPerformance(completed: false);
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      case SessionLeaveDecision.endEarly:
        await _confirmEndSessionEarly();
      case SessionLeaveDecision.cancel:
        break;
    }
  }

  Future<void> _confirmEndSessionEarly() async {
    final completedCount = _earlyEndCompletedCount();
    final totalCount = _earlyEndTotalCount();

    final result = await showDialog<EarlySessionEndResult>(
      context: context,
      builder: (dialogContext) {
        return EarlySessionEndDialog(
          completedCount: completedCount,
          totalCount: totalCount,
          unitLabel: _earlyEndUnitLabel(),
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    await _finishSession(
      endedEarly: true,
      completionReason: result.reason?.label,
    );
  }

  int _earlyEndCompletedCount() {
    if (widget.plan.scoreType == CircuitScoreType.roundsCompleted) {
      return _executionState.performance.completedRounds ??
          ((_timerState?.currentInterval ?? 1) - 1).clamp(0, 999);
    }

    return _hasWorkStarted ? 1 : 0;
  }

  int _earlyEndTotalCount() {
    return widget.plan.intervalCount ??
        widget.plan.prescribedRounds ??
        1;
  }

  String _earlyEndUnitLabel() {
    return switch (widget.plan.format) {
      CircuitFormat.emom || CircuitFormat.intervalClock => 'intervals',
      CircuitFormat.roundsForTime => 'rounds',
      _ => 'session goals',
    };
  }

  String _progressSummaryLabel() {
    return _validator.progressSummary(
      state: _executionState,
      timerState: _timerState,
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final showTimer = !_isPostSession;
    final showSessionNote = _isRealSession && _hasWorkStarted;
    final canFinish = _hasValidScore;
    final showEndEarly = _isRealSession && _hasWorkStarted && !canFinish;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SessionExecutionHeader(
          modeLabel: plan.format.displayLabel.toUpperCase(),
          sessionTitle: widget.sessionTitle,
        ),
        if (_shouldLoadPreviousPerformance) ...[
          const SizedBox(height: CohortSpacing.xl),
          _PreviousCircuitPerformanceSection(
            isLoading: _isLoadingPreviousPerformance,
            hasLoaded: _hasLoadedPreviousPerformance,
            performance: _previousPerformance,
          ),
        ],
        const SizedBox(height: CohortSpacing.xl),
        SessionProgressSummary(
          completedCount: _progressCompletedCount(),
          totalCount: _progressTotalCount(),
          summaryLabel: _progressSummaryLabel(),
          summaryTextStyle: CohortTextStyles.body,
        ),
        if (_isHydratingSession) ...[
          const SizedBox(height: CohortSpacing.sm),
          Text(
            'Restoring saved session...',
            style: CohortTextStyles.small.copyWith(color: CohortColors.textMuted),
          ),
        ],
        const SizedBox(height: CohortSpacing.xl),
        CohortCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HOW TODAY IS SCORED',
                style: CohortTextStyles.eyebrow,
              ),
              const SizedBox(height: CohortSpacing.sm),
              Text(
                plan.resolvedScoringLabel,
                style: CohortTextStyles.body,
              ),
            ],
          ),
        ),
        const SizedBox(height: CohortSpacing.xl),
        _EntryModeToggle(
          isPostSession: _isPostSession,
          onChanged: (value) => _setEntryMode(
            value ? CircuitEntryMode.postSession : CircuitEntryMode.live,
          ),
        ),
        if (showTimer) ...[
          const SizedBox(height: CohortSpacing.xl),
          _CircuitTimerPanel(
            timerState: _timerState,
            plan: plan,
            onStart: _timerController.start,
            onPause: _timerController.pause,
            onResume: _timerController.resume,
            onFinishTimer: _timerController.finish,
            onSkipInterval: _timerController.skipInterval,
            onAddFifteen: _timerController.addFifteenSeconds,
          ),
        ],
        const SizedBox(height: CohortSpacing.xl),
        Text(
          'FULL WORKOUT',
          style: CohortTextStyles.eyebrow,
        ),
        const SizedBox(height: CohortSpacing.sm),
        _PlanStructureSummary(plan: plan),
        const SizedBox(height: CohortSpacing.md),
        _MovementList(movements: plan.movements),
        const SizedBox(height: CohortSpacing.xl),
        Text(
          'YOUR RESULT',
          style: CohortTextStyles.eyebrow,
        ),
        const SizedBox(height: CohortSpacing.md),
        _ScoreEntrySection(
          plan: plan,
          performance: _executionState.performance,
          completedRoundsController: _completedRoundsController,
          additionalRepsController: _additionalRepsController,
          totalRepsController: _totalRepsController,
          completedIntervalsController: _completedIntervalsController,
          completedMovementsController: _completedMovementsController,
          elapsedMinutesController: _elapsedMinutesController,
          elapsedSecondsController: _elapsedSecondsController,
          actualLoadController: _actualLoadController,
          athleteNoteController: _athleteNoteController,
          onPerformanceChanged: _updatePerformance,
        ),
        if (_isRealSession && _executionState.performance.hasRecordedScore) ...[
          const SizedBox(height: CohortSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              key: const ValueKey('circuit-save-progress'),
              onPressed: _isSavingPerformance ? null : _saveProgress,
              child: Text(
                _isSavingPerformance ? 'Saving...' : 'Save progress',
              ),
            ),
          ),
        ],
        if (showSessionNote) ...[
          const SizedBox(height: CohortSpacing.xl),
          SessionNoteField(
            value: _executionState.sessionNote,
            onChanged: _updateSessionNote,
            label: 'SESSION NOTE (OPTIONAL)',
            hintText: 'How did today feel?',
            useFilledBackground: true,
          ),
        ],
        if (canFinish && _progressResult != null) ...[
          const SizedBox(height: CohortSpacing.xl),
          ProgressResultCard(
            eyebrow: 'TODAY\'S RESULT',
            title: _progressResult!.headline,
            message: _progressResult!.message,
            reasons: _progressResult!.reasons,
            accentColor: _circuitProgressAccent(_progressResult!.progressType),
            variant: ProgressResultCardVariant.card,
          ),
        ],
        const SizedBox(height: CohortSpacing.xl),
        SessionFinishActions(
          showFinishSession: canFinish,
          onFinishSession: () => _finishSession(),
          showEndSessionEarly: showEndEarly,
          onEndSessionEarly: _confirmEndSessionEarly,
        ),
      ],
    );
  }

  int _progressCompletedCount() {
    if (widget.plan.scoreType == CircuitScoreType.roundsCompleted) {
      final total = widget.plan.intervalCount ?? widget.plan.prescribedRounds;
      final completed = _executionState.performance.completedRounds ??
          ((_timerState?.currentInterval ?? 1) - 1).clamp(0, 999);
      return total == null ? completed : completed;
    }

    if (_executionState.performance.completedRounds != null) {
      return _executionState.performance.completedRounds!;
    }

    return _hasWorkStarted ? 1 : 0;
  }

  int _progressTotalCount() {
    return widget.plan.intervalCount ??
        widget.plan.prescribedRounds ??
        widget.plan.movementCount;
  }
}

class _EntryModeToggle extends StatelessWidget {
  const _EntryModeToggle({
    required this.isPostSession,
    required this.onChanged,
  });

  final bool isPostSession;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CohortCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter result after training',
                  style: CohortTextStyles.cardTitle,
                ),
                const SizedBox(height: CohortSpacing.xs),
                Text(
                  'Skip the live timer and log your score afterwards.',
                  style: CohortTextStyles.small,
                ),
              ],
            ),
          ),
          Switch(
            value: isPostSession,
            activeThumbColor: CohortColors.olive,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _CircuitTimerPanel extends StatelessWidget {
  const _CircuitTimerPanel({
    required this.timerState,
    required this.plan,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onFinishTimer,
    required this.onSkipInterval,
    required this.onAddFifteen,
  });

  final CircuitTimerState? timerState;
  final CircuitSessionPlan plan;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onFinishTimer;
  final VoidCallback onSkipInterval;
  final VoidCallback onAddFifteen;

  @override
  Widget build(BuildContext context) {
    final state = timerState;
    final mode = CircuitTimerController.resolveMode(plan);

    return CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TIMER',
            style: CohortTextStyles.eyebrow,
          ),
          const SizedBox(height: CohortSpacing.md),
          if (state == null || !state.isStarted) ...[
            Text(
              _timerDescription(mode, plan),
              style: CohortTextStyles.body,
            ),
            const SizedBox(height: CohortSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onStart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: CohortColors.olive,
                  foregroundColor: CohortColors.background,
                ),
                child: const Text('Start'),
              ),
            ),
          ] else ...[
            if (state.mode == CircuitTimerMode.intervalPhase) ...[
              Text(
                'Interval ${state.currentInterval}'
                '${state.totalIntervals != null ? ' of ${state.totalIntervals}' : ''}',
                style: CohortTextStyles.small,
              ),
              const SizedBox(height: CohortSpacing.xs),
            ],
            Text(
              _primaryClockLabel(state),
              style: CohortTextStyles.eyebrow,
            ),
            const SizedBox(height: CohortSpacing.sm),
            Text(
              _formatClock(state),
              style: CohortTextStyles.h2,
            ),
            if (state.mode == CircuitTimerMode.countDown) ...[
              const SizedBox(height: CohortSpacing.xs),
              Text(
                'Elapsed ${_formatSeconds(state.elapsedSeconds)}',
                style: CohortTextStyles.small,
              ),
            ],
            const SizedBox(height: CohortSpacing.md),
            Wrap(
              spacing: CohortSpacing.sm,
              runSpacing: CohortSpacing.sm,
              children: [
                if (state.isRunning)
                  OutlinedButton(
                    onPressed: onPause,
                    child: const Text('Pause'),
                  )
                else if (state.isPaused)
                  OutlinedButton(
                    onPressed: onResume,
                    child: const Text('Resume'),
                  ),
                if (!state.finished)
                  OutlinedButton(
                    onPressed: onFinishTimer,
                    child: const Text('Finish'),
                  ),
                if (state.supportsSkip)
                  OutlinedButton(
                    onPressed: onSkipInterval,
                    child: const Text('Skip interval'),
                  ),
                if (state.supportsAddFifteen)
                  OutlinedButton(
                    onPressed: onAddFifteen,
                    child: const Text('+15 sec'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _timerDescription(
    CircuitTimerMode mode,
    CircuitSessionPlan plan,
  ) {
    return switch (mode) {
      CircuitTimerMode.countDown =>
        'Countdown${plan.timeCap != null ? ' from ${_formatDuration(plan.timeCap)}' : ''}.',
      CircuitTimerMode.countUp =>
        'Count up until you finish${plan.timeCap != null ? ' or hit the cap' : ''}.',
      CircuitTimerMode.intervalPhase =>
        'Complete each round before the interval ends.',
    };
  }

  static String _primaryClockLabel(CircuitTimerState state) {
    return switch (state.mode) {
      CircuitTimerMode.countDown => 'Remaining',
      CircuitTimerMode.countUp => 'Elapsed',
      CircuitTimerMode.intervalPhase => 'Interval clock',
    };
  }

  static String _formatClock(CircuitTimerState state) {
    return switch (state.mode) {
      CircuitTimerMode.countDown => _formatSeconds(state.primarySeconds),
      CircuitTimerMode.countUp => _formatSeconds(state.elapsedSeconds),
      CircuitTimerMode.intervalPhase => _formatSeconds(state.primarySeconds),
    };
  }

  static String _formatSeconds(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  static String _formatDuration(Duration? duration) {
    if (duration == null) {
      return '';
    }

    return _formatSeconds(duration.inSeconds);
  }
}

class _PlanStructureSummary extends StatelessWidget {
  const _PlanStructureSummary({required this.plan});

  final CircuitSessionPlan plan;

  @override
  Widget build(BuildContext context) {
    final items = <String>[];

    if (plan.prescribedRounds != null) {
      items.add('${plan.prescribedRounds} rounds');
    }
    if (plan.timeCap != null) {
      items.add('Cap ${_CircuitTimerPanel._formatDuration(plan.timeCap)}');
    }
    if (plan.workInterval != null) {
      items.add('Work ${_CircuitTimerPanel._formatDuration(plan.workInterval)}');
    }
    if (plan.restInterval != null) {
      items.add('Rest ${_CircuitTimerPanel._formatDuration(plan.restInterval)}');
    }
    if (plan.intervalCount != null) {
      items.add('${plan.intervalCount} intervals');
    }

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Text(
      items.join(' • '),
      style: CohortTextStyles.small,
    );
  }
}

class _MovementList extends StatelessWidget {
  const _MovementList({required this.movements});

  final List<CircuitMovementPrescription> movements;

  @override
  Widget build(BuildContext context) {
    return CohortCard(
      child: Column(
        children: [
          for (var index = 0; index < movements.length; index++) ...[
            if (index > 0) const SizedBox(height: CohortSpacing.md),
            _MovementRow(movement: movements[index]),
          ],
        ],
      ),
    );
  }
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.movement});

  final CircuitMovementPrescription movement;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (movement.reps != null) movement.reps!,
      if (movement.distance != null) movement.distance!,
      if (movement.duration != null) movement.duration!,
      if (movement.load != null) movement.load!,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${movement.orderIndex}. ${movement.title}',
          style: CohortTextStyles.cardTitle,
        ),
        if (details.isNotEmpty) ...[
          const SizedBox(height: CohortSpacing.xs),
          Text(
            details.join(' • '),
            style: CohortTextStyles.body,
          ),
        ],
        if (movement.coachCue != null && movement.coachCue!.trim().isNotEmpty) ...[
          const SizedBox(height: CohortSpacing.xs),
          Text(
            movement.coachCue!,
            style: CohortTextStyles.small,
          ),
        ],
      ],
    );
  }
}

class _ScoreEntrySection extends StatelessWidget {
  const _ScoreEntrySection({
    required this.plan,
    required this.performance,
    required this.completedRoundsController,
    required this.additionalRepsController,
    required this.totalRepsController,
    required this.completedIntervalsController,
    required this.completedMovementsController,
    required this.elapsedMinutesController,
    required this.elapsedSecondsController,
    required this.actualLoadController,
    required this.athleteNoteController,
    required this.onPerformanceChanged,
  });

  final CircuitSessionPlan plan;
  final CircuitPerformanceEntry performance;
  final TextEditingController completedRoundsController;
  final TextEditingController additionalRepsController;
  final TextEditingController totalRepsController;
  final TextEditingController completedIntervalsController;
  final TextEditingController completedMovementsController;
  final TextEditingController elapsedMinutesController;
  final TextEditingController elapsedSecondsController;
  final TextEditingController actualLoadController;
  final TextEditingController athleteNoteController;
  final ValueChanged<CircuitPerformanceEntry> onPerformanceChanged;

  @override
  Widget build(BuildContext context) {
    return CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._scoreFields(),
          const SizedBox(height: CohortSpacing.md),
          _CircuitField(
            label: 'Actual load (optional)',
            controller: actualLoadController,
            onChanged: (value) => onPerformanceChanged(
              performance.copyWith(
                actualLoad: value.trim().isEmpty ? null : value.trim(),
                clearActualLoad: value.trim().isEmpty,
              ),
            ),
          ),
          const SizedBox(height: CohortSpacing.md),
          _RpeSelector(
            value: performance.rpe,
            onChanged: (rpe) => onPerformanceChanged(
              performance.copyWith(
                rpe: rpe,
                clearRpe: rpe == null,
              ),
            ),
          ),
          const SizedBox(height: CohortSpacing.md),
          _CircuitField(
            label: 'Athlete note (optional)',
            controller: athleteNoteController,
            maxLines: 2,
            onChanged: (value) => onPerformanceChanged(
              performance.copyWith(
                athleteNote: value.trim().isEmpty ? null : value.trim(),
                clearAthleteNote: value.trim().isEmpty,
              ),
            ),
          ),
          if (plan.scoreType == CircuitScoreType.movementsCompleted ||
              plan.timeCap != null) ...[
            const SizedBox(height: CohortSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Stopped by time cap',
                    style: CohortTextStyles.body,
                  ),
                ),
                Switch(
                  value: performance.timeCapped,
                  activeThumbColor: CohortColors.olive,
                  onChanged: (value) => onPerformanceChanged(
                    performance.copyWith(timeCapped: value),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _scoreFields() {
    return switch (plan.scoreType) {
      CircuitScoreType.roundsAndReps => [
          _CircuitField(
            key: const ValueKey('circuit-completed-rounds'),
            label: 'Completed rounds',
            controller: completedRoundsController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (value) => onPerformanceChanged(
              performance.copyWith(
                completedRounds: int.tryParse(value),
                clearCompletedRounds: value.trim().isEmpty,
              ),
            ),
          ),
          const SizedBox(height: CohortSpacing.md),
          _CircuitField(
            key: const ValueKey('circuit-additional-reps'),
            label: 'Additional reps',
            controller: additionalRepsController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (value) => onPerformanceChanged(
              performance.copyWith(
                additionalReps: int.tryParse(value),
                clearAdditionalReps: value.trim().isEmpty,
              ),
            ),
          ),
        ],
      CircuitScoreType.elapsedTime || CircuitScoreType.benchmarkScore => [
          _ElapsedTimeFields(
            key: const ValueKey('circuit-elapsed-time'),
            minutesController: elapsedMinutesController,
            secondsController: elapsedSecondsController,
            onChanged: (duration) => onPerformanceChanged(
              performance.copyWith(
                elapsedDuration: duration,
                clearElapsedDuration: duration == null,
              ),
            ),
          ),
        ],
      CircuitScoreType.totalReps => [
          _CircuitField(
            label: 'Total reps',
            controller: totalRepsController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (value) => onPerformanceChanged(
              performance.copyWith(
                totalReps: int.tryParse(value),
                clearTotalReps: value.trim().isEmpty,
              ),
            ),
          ),
        ],
      CircuitScoreType.roundsCompleted => [
          _CircuitField(
            label: 'Intervals / rounds completed',
            controller: completedIntervalsController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (value) => onPerformanceChanged(
              performance.copyWith(
                completedRounds: int.tryParse(value),
                clearCompletedRounds: value.trim().isEmpty,
              ),
            ),
          ),
        ],
      CircuitScoreType.movementsCompleted => [
          _CircuitField(
            label: 'Movements completed',
            controller: completedMovementsController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (value) => onPerformanceChanged(
              performance.copyWith(
                completedMovements: int.tryParse(value),
                clearCompletedMovements: value.trim().isEmpty,
              ),
            ),
          ),
          const SizedBox(height: CohortSpacing.md),
          _ElapsedTimeFields(
            minutesController: elapsedMinutesController,
            secondsController: elapsedSecondsController,
            onChanged: (duration) => onPerformanceChanged(
              performance.copyWith(
                elapsedDuration: duration,
                clearElapsedDuration: duration == null,
              ),
            ),
          ),
        ],
    };
  }
}

class _ElapsedTimeFields extends StatelessWidget {
  const _ElapsedTimeFields({
    super.key,
    required this.minutesController,
    required this.secondsController,
    required this.onChanged,
  });

  final TextEditingController minutesController;
  final TextEditingController secondsController;
  final ValueChanged<Duration?> onChanged;

  @override
  Widget build(BuildContext context) {
    void sync() {
      final minutes = int.tryParse(minutesController.text) ?? 0;
      final seconds = int.tryParse(secondsController.text) ?? 0;
      if (minutes == 0 && seconds == 0 && minutesController.text.isEmpty) {
        onChanged(null);
        return;
      }

      onChanged(Duration(minutes: minutes, seconds: seconds));
    }

    return Row(
      children: [
        Expanded(
          child: _CircuitField(
            label: 'Minutes',
            controller: minutesController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => sync(),
          ),
        ),
        const SizedBox(width: CohortSpacing.md),
        Expanded(
          child: _CircuitField(
            label: 'Seconds',
            controller: secondsController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => sync(),
          ),
        ),
      ],
    );
  }
}

class _CircuitField extends StatelessWidget {
  const _CircuitField({
    super.key,
    required this.label,
    required this.controller,
    required this.onChanged,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: CohortTextStyles.muted),
        const SizedBox(height: CohortSpacing.xs),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          style: CohortTextStyles.body,
          onChanged: onChanged,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: CohortSpacing.md,
              vertical: CohortSpacing.md,
            ),
            border: OutlineInputBorder(
              borderRadius: CohortRadius.smallRadius,
              borderSide: const BorderSide(color: CohortColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: CohortRadius.smallRadius,
              borderSide: const BorderSide(color: CohortColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: CohortRadius.smallRadius,
              borderSide: const BorderSide(color: CohortColors.borderStrong),
            ),
          ),
        ),
      ],
    );
  }
}

class _RpeSelector extends StatelessWidget {
  const _RpeSelector({
    required this.value,
    required this.onChanged,
  });

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('RPE (optional)', style: CohortTextStyles.muted),
        const SizedBox(height: CohortSpacing.sm),
        Wrap(
          spacing: CohortSpacing.sm,
          children: [
            for (var score = 1; score <= 10; score++)
              ChoiceChip(
                label: Text('$score'),
                selected: value == score,
                onSelected: (selected) =>
                    onChanged(selected ? score : null),
              ),
          ],
        ),
      ],
    );
  }
}

class _PreviousCircuitPerformanceSection extends StatelessWidget {
  const _PreviousCircuitPerformanceSection({
    required this.isLoading,
    required this.hasLoaded,
    required this.performance,
  });

  final bool isLoading;
  final bool hasLoaded;
  final PreviousCircuitPerformance? performance;

  @override
  Widget build(BuildContext context) {
    final hasHistory = performance?.hasHistory ?? false;

    return PreviousPerformanceShell(
      isLoading: isLoading,
      visible: hasLoaded,
      loadingTextStyle:
          CohortTextStyles.small.copyWith(color: CohortColors.textMuted),
      emptyState: Text(
        'This is your first recorded circuit performance.',
        style: CohortTextStyles.body,
      ),
      content: hasHistory
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LAST PERFORMANCE',
                  style: CohortTextStyles.eyebrow.copyWith(
                    color: CohortColors.olive,
                  ),
                ),
                const SizedBox(height: CohortSpacing.md),
                Text(
                  performance!.displaySummary,
                  style: CohortTextStyles.body,
                ),
                if (performance!.averageRpe != null) ...[
                  const SizedBox(height: CohortSpacing.sm),
                  Text(
                    'RPE ${performance!.averageRpe}',
                    style: CohortTextStyles.body,
                  ),
                ],
                if (performance!.athleteNote != null &&
                    performance!.athleteNote!.trim().isNotEmpty) ...[
                  const SizedBox(height: CohortSpacing.sm),
                  Text(
                    performance!.athleteNote!,
                    style: CohortTextStyles.small,
                  ),
                ],
                const SizedBox(height: CohortSpacing.lg),
                TodaysOpportunitySection(
                  items: performance!.todayOpportunities,
                  useUppercaseEyebrow: true,
                ),
              ],
            )
          : null,
      wrapInCard: true,
    );
  }
}

Color _circuitProgressAccent(CircuitProgressType progressType) {
  return switch (progressType) {
    CircuitProgressType.firstPerformance => CohortColors.olive,
    CircuitProgressType.moreRoundsOrReps ||
    CircuitProgressType.fasterCompletion ||
    CircuitProgressType.moreWorkCompleted ||
    CircuitProgressType.heavierLoad ||
    CircuitProgressType.effortImproved =>
      CohortColors.success,
    CircuitProgressType.matchedPerformance => CohortColors.olive,
    CircuitProgressType.mixedResult => CohortColors.warning,
    CircuitProgressType.insufficientData => CohortColors.textSecondary,
  };
}
