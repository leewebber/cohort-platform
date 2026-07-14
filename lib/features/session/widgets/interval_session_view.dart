import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../../data/repositories/training_session_interval_repository.dart';
import '../../../data/repositories/training_session_repository.dart';
import '../../../models/interval_modality.dart';
import '../../../models/interval_metric_entry_source.dart';
import '../../../models/interval_phase_type.dart';
import '../../../models/interval_rep_entry.dart';
import '../../../models/interval_session_execution_state.dart';
import '../../../models/interval_progress_result.dart';
import '../../../models/interval_session_plan.dart';
import '../../../models/previous_interval_performance.dart';
import '../models/early_session_end_reason.dart';
import '../models/interval_session_finish_summary.dart';
import '../models/strength_rest_timer_state.dart';
import '../services/interval_metric_calculator.dart';
import '../services/interval_performance_mapper.dart';
import '../services/interval_progress_service.dart';
import '../services/interval_session_hydrator.dart';
import '../services/interval_session_leave_coordinator.dart';
import '../services/previous_interval_performance_service.dart';
import '../services/strength_rest_timer_controller.dart';

/// Dedicated execution view for interval sessions (v0.1).
///
/// Orchestrates [IntervalSessionExecutionState] in memory and persists completed
/// phases to `training_session_intervals` when [trainingSessionId] is set.
class IntervalSessionView extends StatefulWidget {
  const IntervalSessionView({
    super.key,
    required this.sessionTitle,
    required this.plan,
    required this.onFinishSession,
    this.previewMode = false,
    this.trainingSessionId,
    this.athleteId,
    this.protocolId,
    TrainingSessionIntervalRepository? intervalRepository,
    IntervalPerformanceMapper? performanceMapper,
    IntervalSessionHydrator? sessionHydrator,
    PreviousIntervalPerformanceService? previousPerformanceService,
    IntervalProgressService? progressService,
    TrainingSessionRepository? trainingSessionRepository,
    this.onLeaveCoordinatorReady,
  })  : intervalRepository =
            intervalRepository ?? const TrainingSessionIntervalRepository(),
        performanceMapper =
            performanceMapper ?? const IntervalPerformanceMapper(),
        sessionHydrator = sessionHydrator ?? const IntervalSessionHydrator(),
        previousPerformanceService = previousPerformanceService ??
            const PreviousIntervalPerformanceService(),
        progressService = progressService ?? const IntervalProgressService(),
        trainingSessionRepository =
            trainingSessionRepository ?? const TrainingSessionRepository();

  final String sessionTitle;
  final IntervalSessionPlan plan;
  final Future<void> Function(IntervalSessionFinishSummary summary)
      onFinishSession;
  final bool previewMode;
  final int? trainingSessionId;
  final String? athleteId;
  final String? protocolId;
  final TrainingSessionIntervalRepository intervalRepository;
  final IntervalPerformanceMapper performanceMapper;
  final IntervalSessionHydrator sessionHydrator;
  final PreviousIntervalPerformanceService previousPerformanceService;
  final IntervalProgressService progressService;
  final TrainingSessionRepository trainingSessionRepository;
  final void Function(IntervalSessionLeaveCoordinator coordinator)?
      onLeaveCoordinatorReady;

  @override
  State<IntervalSessionView> createState() => _IntervalSessionViewState();
}

class _IntervalSessionViewState extends State<IntervalSessionView> {
  static const _metricCalculator = IntervalMetricCalculator();

  late IntervalSessionExecutionState _executionState;
  late final StrengthRestTimerController _recoveryTimerController;
  late final Map<String, TextEditingController> _durationControllers;
  late final Map<String, TextEditingController> _distanceControllers;
  late final Map<String, TextEditingController> _paceControllers;

  StrengthRestTimerState? _recoveryTimerState;
  bool _postSessionEntryMode = false;
  bool _phaseStarted = false;
  bool _ignoreRecoveryFinish = false;
  bool _isHydratingSession = false;
  bool _suppressMetricUpdate = false;
  bool _isLoadingPreviousPerformance = false;
  bool _hasLoadedPreviousPerformance = false;
  PreviousIntervalPerformance? _previousPerformance;
  IntervalProgressResult? _progressResult;
  bool _sessionNoteLocallyEdited = false;
  final Set<String> _preservedLocalIds = {};

  bool get _hasRecordedWorkProgress =>
      _executionState.entries.any(
        (entry) =>
            entry.isWorkPhase && (entry.completed || entry.hasStartedData),
      );

  bool get hasRecordedProgress => _executionState.hasRecordedProgress;

  bool get _shouldLoadPreviousPerformance =>
      !widget.previewMode &&
      widget.athleteId != null &&
      widget.protocolId != null;

  bool get _isRealSession =>
      !widget.previewMode && widget.trainingSessionId != null;

  @override
  void initState() {
    super.initState();
    _executionState = IntervalSessionExecutionState(
      plan: widget.plan,
      entries: List<IntervalRepEntry>.from(widget.plan.timelineEntries),
      activeLocalId: widget.plan.timelineEntries.firstOrNull?.localId,
      trainingSessionId: widget.trainingSessionId,
    );

    _recoveryTimerController = StrengthRestTimerController(
      onStateChanged: (state) {
        if (!mounted) {
          return;
        }
        setState(() => _recoveryTimerState = state);
      },
      onFinished: _handleRecoveryTimerFinished,
    );

    _durationControllers = {};
    _distanceControllers = {};
    _paceControllers = {};
    for (final entry in _executionState.entries.where((item) => item.isWorkPhase)) {
      _durationControllers[entry.localId] =
          TextEditingController(text: _formatDuration(entry.actualDuration));
      _distanceControllers[entry.localId] =
          TextEditingController(text: _formatDistance(entry.actualDistance));
      _paceControllers[entry.localId] =
          TextEditingController(text: _formatPace(entry.actualPace));
    }

    if (_isRealSession) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadPersistedSessionState();
      });
    }

    if (_shouldLoadPreviousPerformance) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadPreviousIntervalPerformance();
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onLeaveCoordinatorReady?.call(
        IntervalSessionLeaveCoordinator(
          hasRecordedProgress: () => hasRecordedProgress,
          confirmLeave: _confirmLeaveSession,
        ),
      );
    });
  }

  @override
  void dispose() {
    _recoveryTimerController.dispose();
    for (final controller in _durationControllers.values) {
      controller.dispose();
    }
    for (final controller in _distanceControllers.values) {
      controller.dispose();
    }
    for (final controller in _paceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  IntervalRepEntry? get _currentPhase => _executionState.currentPhase;

  bool get _allWorkComplete =>
      _executionState.completedWorkPhaseCount ==
      _executionState.totalWorkPhaseCount;

  bool get _canFinishSession => _allWorkComplete;

  void _preserveLocalEntry(String localId) {
    _preservedLocalIds.add(localId);
  }

  Future<void> _loadPreviousIntervalPerformance() async {
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
        '[IntervalSessionView] previous interval performance load failed: $error',
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
      final persisted =
          await widget.intervalRepository.getIntervalsForTrainingSession(
        trainingSessionId,
      );
      final session =
          await widget.trainingSessionRepository.getSessionById(trainingSessionId);

      if (!mounted) {
        return;
      }

      final hydrated = widget.sessionHydrator.hydrate(
        plan: widget.plan,
        baseEntries: _executionState.entries,
        persisted: persisted,
        preserveLocalIds: _preservedLocalIds,
        trainingSessionId: trainingSessionId,
      );

      setState(() {
        _executionState = hydrated;
        if (!_sessionNoteLocallyEdited) {
          final restoredNote = session?.sessionNote?.trim();
          if (restoredNote != null && restoredNote.isNotEmpty) {
            _executionState = _executionState.copyWith(
              sessionNote: restoredNote,
            );
          }
        }
        _phaseStarted = false;
        _syncWorkControllersFromState();
        _recalculateProgress();
      });
    } catch (error) {
      debugPrint('[IntervalSessionView] session hydrate failed: $error');
    } finally {
      if (mounted) {
        setState(() => _isHydratingSession = false);
      }
    }
  }

  void _syncWorkControllersFromState() {
    _suppressMetricUpdate = true;
    try {
      for (final entry
          in _executionState.entries.where((item) => item.isWorkPhase)) {
        if (_preservedLocalIds.contains(entry.localId)) {
          continue;
        }

        _durationControllers[entry.localId]?.text =
            _formatDuration(entry.actualDuration) ?? '';
        _distanceControllers[entry.localId]?.text =
            _formatDistance(entry.actualDistance) ?? '';
        _paceControllers[entry.localId]?.text =
            _formatPace(entry.actualPace) ?? '';
      }
    } finally {
      _suppressMetricUpdate = false;
    }
  }

  void _setState(IntervalSessionExecutionState next) {
    setState(() => _executionState = next);
  }

  void _startCurrentPhase() {
    final current = _currentPhase;
    if (current == null) {
      return;
    }

    setState(() {
      _executionState = _executionState.copyWith(activeLocalId: current.localId);
      _phaseStarted = true;
    });

    if (current.isRecoveryPhase) {
      _maybeStartRecoveryTimer(current);
    }
  }

  void _maybeStartRecoveryTimer(IntervalRepEntry entry) {
    final parsed = StrengthRestParser.parse(entry.targetDuration);
    if (parsed == null) {
      return;
    }

    final nextLabel = _nextPhaseLabelAfter(entry.localId);
    _recoveryTimerController.start(
      exerciseLocalId: entry.localId,
      setLocalId: entry.localId,
      totalSeconds: parsed.totalSeconds,
      nextTargetLabel: nextLabel ?? 'Next phase',
      prescribedRestLabel: parsed.displayLabel,
    );
  }

  String? _nextPhaseLabelAfter(String localId) {
    final index = _executionState.indexOf(localId);
    if (index < 0 || index >= _executionState.entries.length - 1) {
      return null;
    }

    final next = _executionState.entries[index + 1];
    return _intervalPhaseSummaryLabel(next);
  }

  void _handleRecoveryTimerFinished(StrengthRestTimerState state) {
    if (_ignoreRecoveryFinish) {
      return;
    }

    final entry = _executionState.entryByLocalId(state.setLocalId);
    if (entry == null || entry.completed) {
      return;
    }

    _completePhase(entry, autoRecovery: true);
  }

  void _skipCurrentPhase() {
    final current = _currentPhase;
    if (current == null) {
      return;
    }

    if (current.isRecoveryPhase &&
        _recoveryTimerState != null &&
        !_recoveryTimerState!.finished) {
      _ignoreRecoveryFinish = true;
      _recoveryTimerController.skip();
      _ignoreRecoveryFinish = false;
    }

    _completePhase(current, skipped: true);
  }

  void _completeCurrentPhase() {
    final current = _currentPhase;
    if (current == null) {
      return;
    }

    if (current.isWorkPhase) {
      final updated = _workEntryFromInputs(current);
      _completePhase(updated);
      return;
    }

    _completePhase(current);
  }

  void _completePhase(
    IntervalRepEntry entry, {
    bool autoRecovery = false,
    bool skipped = false,
  }) {
    final completed = entry.copyWith(completed: true, skipped: skipped);
    var nextState = _executionState.updateEntry(completed);

    final next = _nextIncompletePhaseAfter(entry.localId);
    nextState = nextState.copyWith(
      activeLocalId: next?.localId,
      clearActiveLocalId: next == null,
    );

    final shouldAutoStartRecovery = completed.isWorkPhase &&
        next != null &&
        next.isRecoveryPhase &&
        StrengthRestParser.parse(next.targetDuration) != null;

    setState(() {
      _executionState = nextState;
      _phaseStarted = shouldAutoStartRecovery;
      if (!autoRecovery) {
        _recoveryTimerState = null;
      }
      if (completed.isWorkPhase) {
        _recalculateProgress();
      }
    });

    if (shouldAutoStartRecovery) {
      _maybeStartRecoveryTimer(next);
    }

    _persistPhase(completed, skipped: skipped);
  }

  IntervalRepEntry? _nextIncompletePhaseAfter(String localId) {
    final index = _executionState.indexOf(localId);
    if (index < 0) {
      return null;
    }

    for (var i = index + 1; i < _executionState.entries.length; i++) {
      final entry = _executionState.entries[i];
      if (!entry.completed) {
        return entry;
      }
    }

    return null;
  }

  IntervalRepEntry _workEntryFromInputs(IntervalRepEntry entry) {
    final input = _metricCalculator.buildInputFromTexts(
      current: _metricCalculator.inputFromEntry(entry),
      distanceText: _distanceControllers[entry.localId]?.text,
      durationText: _durationControllers[entry.localId]?.text,
      paceText: _paceControllers[entry.localId]?.text,
    );

    return _metricCalculator.applyToEntry(
      entry: entry,
      input: input,
    );
  }

  void _onWorkMetricFieldChanged(
    String localId,
    IntervalMetricField field,
    String text,
  ) {
    _preserveLocalEntry(localId);
    if (_suppressMetricUpdate) {
      return;
    }

    final entry = _executionState.entryByLocalId(localId);
    if (entry == null || !entry.isWorkPhase) {
      return;
    }

    final input = _metricCalculator.buildInputFromTexts(
      current: _metricCalculator.inputFromEntry(entry),
      distanceText: _distanceControllers[localId]?.text,
      durationText: _durationControllers[localId]?.text,
      paceText: _paceControllers[localId]?.text,
      editedField: field,
    );

    final updated = _metricCalculator.applyToEntry(
      entry: entry,
      input: input,
    );

    _suppressMetricUpdate = true;
    try {
      if (updated.distanceSource == IntervalMetricEntrySource.auto) {
        _distanceControllers[localId]?.text =
            _formatDistance(updated.actualDistance) ?? '';
      }
      if (updated.durationSource == IntervalMetricEntrySource.auto) {
        _durationControllers[localId]?.text =
            _formatDuration(updated.actualDuration) ?? '';
      }
      if (updated.paceSource == IntervalMetricEntrySource.auto) {
        _paceControllers[localId]?.text = _formatPace(updated.actualPace) ?? '';
      }
    } finally {
      _suppressMetricUpdate = false;
    }

    _setState(_executionState.updateEntry(updated));
  }

  void _recalculateProgress() {
    _progressResult = widget.progressService.evaluate(
      previousPerformance: _previousPerformance,
      todayCompletedWorkPhases: _executionState.entries
          .where((entry) => entry.isWorkPhase && entry.completed)
          .toList(),
    );
  }

  IntervalSessionFinishSummary _buildFinishSummary({
    bool endedEarly = false,
    String? endReasonLabel,
  }) {
    return IntervalSessionFinishSummary(
      sessionTitle: widget.sessionTitle,
      endedEarly: endedEarly,
      completedWorkCount: _executionState.completedWorkPhaseCount,
      totalWorkCount: _executionState.totalWorkPhaseCount,
      endReasonLabel: endReasonLabel,
      sessionNote: _executionState.sessionNote,
      progressResult: _progressResult,
    );
  }

  Future<void> _persistAllCompletedPhases() async {
    if (!_isRealSession) {
      return;
    }

    for (final entry in _executionState.entries.where((item) => item.completed)) {
      await _persistPhase(entry, skipped: entry.skipped);
    }
  }

  void _updateSessionNote(String value) {
    _sessionNoteLocallyEdited = true;
    final trimmed = value.trim();
    setState(() {
      _executionState = _executionState.copyWith(
        sessionNote: trimmed.isEmpty ? null : trimmed,
        clearSessionNote: trimmed.isEmpty,
      );
    });
  }

  Future<void> _confirmLeaveSession(BuildContext context) async {
    if (!_isRealSession || !hasRecordedProgress) {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    final choice = await showDialog<_LeaveSessionChoice>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: CohortColors.surfaceRaised,
          title: Text(
            'Leave this session?',
            style: CohortTextStyles.cardTitle,
          ),
          content: Text(
            'Your completed intervals are saved. You can resume this session later from Home.',
            style: CohortTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext)
                  .pop(_LeaveSessionChoice.resumeLater),
              child: Text(
                'Resume later',
                style: CohortTextStyles.body.copyWith(color: CohortColors.olive),
              ),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_LeaveSessionChoice.endEarly),
              child: Text(
                'End session early',
                style: CohortTextStyles.body.copyWith(color: CohortColors.warning),
              ),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_LeaveSessionChoice.cancel),
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
        choice == _LeaveSessionChoice.cancel) {
      return;
    }

    switch (choice) {
      case _LeaveSessionChoice.resumeLater:
        Navigator.of(context).pop();
      case _LeaveSessionChoice.endEarly:
        await _confirmEndSessionEarly();
      case _LeaveSessionChoice.cancel:
        break;
    }
  }

  Future<void> _finishSession({
    bool endedEarly = false,
    String? endReasonLabel,
  }) async {
    await _persistAllCompletedPhases();
    _recalculateProgress();

    await widget.onFinishSession(
      _buildFinishSummary(
        endedEarly: endedEarly,
        endReasonLabel: endReasonLabel,
      ),
    );
  }

  void _updateWorkEntryRpe(IntervalRepEntry entry, int? rpe) {
    _preserveLocalEntry(entry.localId);
    final updated = entry.copyWith(rpe: rpe, clearRpe: rpe == null);
    _setState(_executionState.updateEntry(updated));
  }

  void _completeWorkEntryFromPostSession(IntervalRepEntry entry) {
    final updated = _workEntryFromInputs(entry).copyWith(
      completed: true,
      skipped: false,
    );
    setState(() {
      _executionState = _executionState.updateEntry(updated);
      _recalculateProgress();
    });
    _persistPhase(updated, skipped: false);
  }

  Future<void> _persistPhase(
    IntervalRepEntry entry, {
    required bool skipped,
  }) async {
    final trainingSessionId = widget.trainingSessionId;
    if (!_isRealSession || trainingSessionId == null) {
      return;
    }

    final performance = widget.performanceMapper.fromEntry(
      trainingSessionId: trainingSessionId,
      plan: widget.plan,
      entry: entry,
      skipped: skipped,
    );

    try {
      await widget.intervalRepository.upsertIntervalPerformance(performance);
    } catch (error) {
      debugPrint('[IntervalSessionView] phase save failed: $error');
      _showPersistenceError(
        'Phase saved locally, but performance could not be synced right now.',
      );
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

  Future<void> _confirmEndSessionEarly() async {
    final result = await showDialog<_IntervalEndSessionEarlyResult>(
      context: context,
      builder: (dialogContext) {
        return _IntervalEndSessionEarlyDialog(
          completedWorkCount: _executionState.completedWorkPhaseCount,
          totalWorkCount: _executionState.totalWorkPhaseCount,
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    await _finishSession(
      endedEarly: true,
      endReasonLabel: result.reason?.label,
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentPhase;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.plan.modality.name.toUpperCase(),
          style: CohortTextStyles.eyebrow,
        ),
        const SizedBox(height: CohortSpacing.sm),
        Text(
          '${_executionState.completedWorkPhaseCount} of '
          '${_executionState.totalWorkPhaseCount} work intervals complete',
          style: CohortTextStyles.body,
        ),
        if (_isHydratingSession) ...[
          const SizedBox(height: CohortSpacing.sm),
          Text(
            'Restoring saved session...',
            style: CohortTextStyles.small.copyWith(color: CohortColors.textMuted),
          ),
        ],
        if (_shouldLoadPreviousPerformance) ...[
          const SizedBox(height: CohortSpacing.xl),
          _PreviousIntervalPerformanceSection(
            isLoading: _isLoadingPreviousPerformance,
            hasLoaded: _hasLoadedPreviousPerformance,
            performance: _previousPerformance,
            metricCalculator: _metricCalculator,
            modality: widget.plan.modality,
          ),
        ],
        const SizedBox(height: CohortSpacing.xl),
        Text(
          'FULL SESSION PLAN',
          style: CohortTextStyles.eyebrow,
        ),
        const SizedBox(height: CohortSpacing.md),
        _SessionPlanOverview(
          entries: _executionState.entries,
          currentLocalId: current?.localId,
        ),
        const SizedBox(height: CohortSpacing.xl),
        _PostSessionToggle(
          enabled: _postSessionEntryMode,
          onChanged: (value) => setState(() => _postSessionEntryMode = value),
        ),
        if (_postSessionEntryMode) ...[
          const SizedBox(height: CohortSpacing.lg),
          _PostSessionWorkList(
            entries: _executionState.entries.where((e) => e.isWorkPhase).toList(),
            durationControllers: _durationControllers,
            distanceControllers: _distanceControllers,
            paceControllers: _paceControllers,
            onRpeChanged: _updateWorkEntryRpe,
            onComplete: _completeWorkEntryFromPostSession,
            onMetricFieldChanged: _onWorkMetricFieldChanged,
            executionState: _executionState,
          ),
        ] else ...[
          const SizedBox(height: CohortSpacing.xl),
          Text(
            'CURRENT PHASE',
            style: CohortTextStyles.eyebrow,
          ),
          const SizedBox(height: CohortSpacing.md),
          if (current == null)
            const Text(
              'All phases complete.',
              style: CohortTextStyles.body,
            )
          else
            _CurrentPhaseCard(
              entry: current,
              phaseStarted: _phaseStarted,
              recoveryTimerState: _recoveryTimerState,
              durationController: _durationControllers[current.localId],
              distanceController: _distanceControllers[current.localId],
              paceController: _paceControllers[current.localId],
              onStartPhase: _startCurrentPhase,
              onCompletePhase: _completeCurrentPhase,
              onSkipPhase: _skipCurrentPhase,
              onRpeChanged: (rpe) => _updateWorkEntryRpe(current, rpe),
              onMetricFieldChanged: (field, text) =>
                  _onWorkMetricFieldChanged(current.localId, field, text),
              onPauseRecovery: _recoveryTimerController.pause,
              onResumeRecovery: _recoveryTimerController.resume,
              onSkipRecovery: _recoveryTimerController.skip,
              onAddFifteenRecovery: _recoveryTimerController.addFifteenSeconds,
            ),
        ],
        if (_canFinishSession && _progressResult != null) ...[
          const SizedBox(height: CohortSpacing.xl),
          _IntervalProgressResultCard(result: _progressResult!),
        ],
        if (_isRealSession && _hasRecordedWorkProgress) ...[
          const SizedBox(height: CohortSpacing.xl),
          _IntervalSessionNoteField(
            value: _executionState.sessionNote,
            onChanged: _updateSessionNote,
          ),
        ],
        const SizedBox(height: CohortSpacing.xl),
        if (_canFinishSession)
          CohortButton(
            label: 'Finish Session',
            onPressed: () => _finishSession(),
          ),
        if (_isRealSession &&
            _hasRecordedWorkProgress &&
            !_canFinishSession) ...[
          const SizedBox(height: CohortSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _confirmEndSessionEarly,
              style: OutlinedButton.styleFrom(
                foregroundColor: CohortColors.textSecondary,
                side: const BorderSide(color: CohortColors.border),
              ),
              child: Text(
                'End Session Early',
                style: CohortTextStyles.body,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _IntervalProgressResultCard extends StatelessWidget {
  const _IntervalProgressResultCard({required this.result});

  final IntervalProgressResult result;

  @override
  Widget build(BuildContext context) {
    final accentColor = switch (result.progressType) {
      IntervalProgressType.firstPerformance => CohortColors.olive,
      IntervalProgressType.averagePaceImproved ||
      IntervalProgressType.consistencyImproved ||
      IntervalProgressType.effortImproved ||
      IntervalProgressType.moreWorkCompleted =>
        CohortColors.success,
      IntervalProgressType.matchedPerformance => CohortColors.olive,
      IntervalProgressType.mixedResult => CohortColors.warning,
      IntervalProgressType.insufficientData => CohortColors.textSecondary,
    };

    return CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TODAY\'S RESULT',
            style: CohortTextStyles.eyebrow.copyWith(color: accentColor),
          ),
          const SizedBox(height: CohortSpacing.sm),
          Text(
            result.headline,
            style: CohortTextStyles.cardTitle.copyWith(color: accentColor),
          ),
          if (result.message.trim().isNotEmpty) ...[
            const SizedBox(height: CohortSpacing.xs),
            Text(
              result.message,
              style: CohortTextStyles.small,
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviousIntervalPerformanceSection extends StatelessWidget {
  const _PreviousIntervalPerformanceSection({
    required this.isLoading,
    required this.hasLoaded,
    required this.performance,
    required this.metricCalculator,
    required this.modality,
  });

  final bool isLoading;
  final bool hasLoaded;
  final PreviousIntervalPerformance? performance;
  final IntervalMetricCalculator metricCalculator;
  final IntervalModality modality;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Text(
        'Loading previous performance...',
        style: CohortTextStyles.small.copyWith(color: CohortColors.textMuted),
      );
    }

    if (!hasLoaded) {
      return const SizedBox.shrink();
    }

    if (performance == null || !performance!.hasHistory) {
      return CohortCard(
        child: Text(
          'This is your first recorded interval performance.',
          style: CohortTextStyles.body,
        ),
      );
    }

    final data = performance!;

    return CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LAST PERFORMANCE',
            style: CohortTextStyles.eyebrow.copyWith(color: CohortColors.olive),
          ),
          const SizedBox(height: CohortSpacing.md),
          for (final rep in data.reps) ...[
            Text(
              'Rep ${rep.repNumber} — ${rep.displayLine}',
              style: CohortTextStyles.small,
            ),
            const SizedBox(height: CohortSpacing.xs),
          ],
          if (data.averagePaceSecondsPerKm != null) ...[
            const SizedBox(height: CohortSpacing.sm),
            Text(
              'Average pace: ${metricCalculator.formatPaceSecondsPerKm(data.averagePaceSecondsPerKm, modality: modality) ?? ''}',
              style: CohortTextStyles.body,
            ),
          ],
          if (data.paceDropOffSeconds != null) ...[
            const SizedBox(height: CohortSpacing.xs),
            Text(
              'Pacing spread: ${data.paceDropOffSeconds!.round()} sec',
              style: CohortTextStyles.body,
            ),
          ],
          if (data.averageRpe != null) ...[
            const SizedBox(height: CohortSpacing.xs),
            Text(
              'Average RPE: ${data.averageRpe!.toStringAsFixed(1)}',
              style: CohortTextStyles.body,
            ),
          ],
          const SizedBox(height: CohortSpacing.lg),
          Text(
            "TODAY'S OPPORTUNITY",
            style: CohortTextStyles.eyebrow,
          ),
          const SizedBox(height: CohortSpacing.sm),
          for (final opportunity in PreviousIntervalPerformance.todayOpportunities)
            Padding(
              padding: const EdgeInsets.only(bottom: CohortSpacing.xs),
              child: Text(
                '• $opportunity',
                style: CohortTextStyles.small,
              ),
            ),
        ],
      ),
    );
  }
}

class _SessionPlanOverview extends StatelessWidget {
  const _SessionPlanOverview({
    required this.entries,
    required this.currentLocalId,
  });

  final List<IntervalRepEntry> entries;
  final String? currentLocalId;

  @override
  Widget build(BuildContext context) {
    return CohortCard(
      child: Column(
        children: [
          for (var index = 0; index < entries.length; index++) ...[
            if (index > 0) const SizedBox(height: CohortSpacing.sm),
            _SessionPlanRow(
              entry: entries[index],
              isCurrent: entries[index].localId == currentLocalId,
            ),
          ],
        ],
      ),
    );
  }
}

class _SessionPlanRow extends StatelessWidget {
  const _SessionPlanRow({
    required this.entry,
    required this.isCurrent,
  });

  final IntervalRepEntry entry;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final isCompleted = entry.completed;
    final isUpcoming = !isCompleted && !isCurrent;

    final accentColor = isCurrent
        ? CohortColors.olive
        : isCompleted
            ? CohortColors.success
            : CohortColors.textSecondary;

    final backgroundColor = isCurrent
        ? CohortColors.oliveSoft
        : isCompleted
            ? CohortColors.surface
            : CohortColors.surfaceRaised;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(CohortSpacing.md),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: CohortRadius.smallRadius,
        border: Border.all(
          color: isCurrent
              ? CohortColors.olive
              : isCompleted
                  ? CohortColors.success.withValues(alpha: 0.35)
                  : CohortColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCompleted
                ? Icons.check_circle_outline
                : isCurrent
                    ? Icons.play_circle_outline
                    : Icons.circle_outlined,
            size: 18,
            color: accentColor,
          ),
          const SizedBox(width: CohortSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _phaseTitle(entry),
                  style: CohortTextStyles.cardTitle.copyWith(color: accentColor),
                ),
                if (_targetSummary(entry) != null) ...[
                  const SizedBox(height: CohortSpacing.xs),
                  Text(
                    _targetSummary(entry)!,
                    style: CohortTextStyles.small.copyWith(
                      color: isUpcoming
                          ? CohortColors.textMuted
                          : CohortColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _phaseTitle(IntervalRepEntry entry) {
    final typeLabel = _phaseTypeLabel(entry.phaseType);
    if (entry.isWorkPhase) {
      return '$typeLabel · rep ${entry.repNumber}';
    }

    return typeLabel;
  }

  static String? _targetSummary(IntervalRepEntry entry) {
    final parts = <String>[
      if (entry.targetDistance != null) entry.targetDistance!,
      if (entry.targetDuration != null) entry.targetDuration!,
      if (entry.targetPace != null) entry.targetPace!,
      if (entry.targetIntensity != null) entry.targetIntensity!,
      if (entry.recoveryDuration != null) 'rest ${entry.recoveryDuration}',
    ];

    if (parts.isEmpty) {
      return null;
    }

    return parts.join(' · ');
  }
}

class _CurrentPhaseCard extends StatelessWidget {
  const _CurrentPhaseCard({
    required this.entry,
    required this.phaseStarted,
    required this.onStartPhase,
    required this.onCompletePhase,
    required this.onSkipPhase,
    required this.onRpeChanged,
    this.onMetricFieldChanged,
    this.recoveryTimerState,
    this.durationController,
    this.distanceController,
    this.paceController,
    this.onPauseRecovery,
    this.onResumeRecovery,
    this.onSkipRecovery,
    this.onAddFifteenRecovery,
  });

  final IntervalRepEntry entry;
  final bool phaseStarted;
  final StrengthRestTimerState? recoveryTimerState;
  final TextEditingController? durationController;
  final TextEditingController? distanceController;
  final TextEditingController? paceController;
  final VoidCallback onStartPhase;
  final VoidCallback onCompletePhase;
  final VoidCallback onSkipPhase;
  final void Function(int? rpe) onRpeChanged;
  final void Function(IntervalMetricField field, String text)? onMetricFieldChanged;
  final VoidCallback? onPauseRecovery;
  final VoidCallback? onResumeRecovery;
  final VoidCallback? onSkipRecovery;
  final VoidCallback? onAddFifteenRecovery;

  @override
  Widget build(BuildContext context) {
    return CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _phaseTypeLabel(entry.phaseType),
            style: CohortTextStyles.eyebrow.copyWith(color: CohortColors.olive),
          ),
          const SizedBox(height: CohortSpacing.sm),
          Text(
            _phaseHeadline(entry),
            style: CohortTextStyles.h2,
          ),
          const SizedBox(height: CohortSpacing.md),
          if (entry.targetDistance != null)
            _TargetLine(label: 'Distance', value: entry.targetDistance!),
          if (entry.targetDuration != null)
            _TargetLine(label: 'Duration', value: entry.targetDuration!),
          if (entry.targetPace != null)
            _TargetLine(label: 'Pace', value: entry.targetPace!),
          if (entry.targetIntensity != null)
            _TargetLine(label: 'Intensity', value: entry.targetIntensity!),
          if (entry.recoveryDuration != null)
            _TargetLine(label: 'Recovery', value: entry.recoveryDuration!),
          if (entry.isWorkPhase) ...[
            const SizedBox(height: CohortSpacing.lg),
            Text(
              'ACTUAL PERFORMANCE (OPTIONAL)',
              style: CohortTextStyles.eyebrow,
            ),
            const SizedBox(height: CohortSpacing.md),
            _ManualEntryFields(
              durationController: durationController,
              distanceController: distanceController,
              paceController: paceController,
              selectedRpe: entry.rpe,
              onRpeChanged: onRpeChanged,
              showAutoDuration:
                  entry.durationSource == IntervalMetricEntrySource.auto,
              showAutoDistance:
                  entry.distanceSource == IntervalMetricEntrySource.auto,
              showAutoPace: entry.paceSource == IntervalMetricEntrySource.auto,
              onDurationChanged: (text) => onMetricFieldChanged?.call(
                IntervalMetricField.duration,
                text,
              ),
              onDistanceChanged: (text) => onMetricFieldChanged?.call(
                IntervalMetricField.distance,
                text,
              ),
              onPaceChanged: (text) => onMetricFieldChanged?.call(
                IntervalMetricField.pace,
                text,
              ),
            ),
          ],
          if (entry.isRecoveryPhase && recoveryTimerState != null) ...[
            const SizedBox(height: CohortSpacing.lg),
            _RecoveryTimerBar(
              state: recoveryTimerState!,
              onPause: onPauseRecovery ?? () {},
              onResume: onResumeRecovery ?? () {},
              onSkip: onSkipRecovery ?? () {},
              onAddFifteenSeconds: onAddFifteenRecovery ?? () {},
            ),
          ],
          const SizedBox(height: CohortSpacing.lg),
          ..._phaseActionButtons(),
        ],
      ),
    );
  }

  List<Widget> _phaseActionButtons() {
    if (entry.isWorkPhase) {
      return [
        if (!phaseStarted) ...[
          CohortButton(
            label: 'Start Phase',
            onPressed: onStartPhase,
          ),
          const SizedBox(height: CohortSpacing.md),
        ],
        CohortButton(
          label: 'Complete Phase',
          onPressed: onCompletePhase,
        ),
      ];
    }

    if (entry.isRecoveryPhase) {
      return [
        if (recoveryTimerState == null && !phaseStarted)
          CohortButton(
            label: 'Start Phase',
            onPressed: onStartPhase,
          ),
        if (recoveryTimerState == null && !phaseStarted)
          const SizedBox(height: CohortSpacing.md),
        CohortButton(
          label: recoveryTimerState?.finished == true
              ? 'Complete Phase'
              : 'Skip Phase',
          onPressed:
              recoveryTimerState?.finished == true ? onCompletePhase : onSkipPhase,
        ),
      ];
    }

    if (!phaseStarted) {
      return [
        CohortButton(
          label: 'Start Phase',
          onPressed: onStartPhase,
        ),
      ];
    }

    return [
      CohortButton(
        label: 'Complete Phase',
        onPressed: onCompletePhase,
      ),
      const SizedBox(height: CohortSpacing.sm),
      TextButton(
        onPressed: onSkipPhase,
        child: const Text('Skip Phase'),
      ),
    ];
  }

  static String _phaseHeadline(IntervalRepEntry entry) {
    if (entry.isWorkPhase) {
      return 'Work interval ${entry.repNumber}';
    }

    return _phaseTypeLabel(entry.phaseType);
  }
}

class _TargetLine extends StatelessWidget {
  const _TargetLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.xs),
      child: Text(
        '$label: $value',
        style: CohortTextStyles.body,
      ),
    );
  }
}

class _ManualEntryFields extends StatelessWidget {
  const _ManualEntryFields({
    required this.onRpeChanged,
    this.durationController,
    this.distanceController,
    this.paceController,
    this.selectedRpe,
    this.showAutoDuration = false,
    this.showAutoDistance = false,
    this.showAutoPace = false,
    this.onDurationChanged,
    this.onDistanceChanged,
    this.onPaceChanged,
  });

  final TextEditingController? durationController;
  final TextEditingController? distanceController;
  final TextEditingController? paceController;
  final int? selectedRpe;
  final void Function(int? rpe) onRpeChanged;
  final bool showAutoDuration;
  final bool showAutoDistance;
  final bool showAutoPace;
  final ValueChanged<String>? onDurationChanged;
  final ValueChanged<String>? onDistanceChanged;
  final ValueChanged<String>? onPaceChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _IntervalTextField(
          label: 'Duration',
          hint: 'e.g. 3:12 or 20:00',
          controller: durationController,
          showAutoLabel: showAutoDuration,
          onChanged: onDurationChanged,
        ),
        const SizedBox(height: CohortSpacing.md),
        _IntervalTextField(
          label: 'Distance (m)',
          hint: 'e.g. 4000',
          controller: distanceController,
          keyboardType: TextInputType.number,
          showAutoLabel: showAutoDistance,
          onChanged: onDistanceChanged,
        ),
        const SizedBox(height: CohortSpacing.md),
        _IntervalTextField(
          label: 'Pace (min/km)',
          hint: 'e.g. 4:30',
          controller: paceController,
          showAutoLabel: showAutoPace,
          onChanged: onPaceChanged,
        ),
        const SizedBox(height: CohortSpacing.md),
        Text(
          'RPE (optional)',
          style: CohortTextStyles.muted,
        ),
        const SizedBox(height: CohortSpacing.sm),
        Wrap(
          spacing: CohortSpacing.sm,
          runSpacing: CohortSpacing.sm,
          children: [
            for (var value = 1; value <= 10; value++)
              ChoiceChip(
                label: Text('$value'),
                selected: selectedRpe == value,
                onSelected: (selected) {
                  onRpeChanged(selected ? value : null);
                },
                selectedColor: CohortColors.oliveSoft,
                side: const BorderSide(color: CohortColors.border),
                labelStyle: CohortTextStyles.small,
              ),
          ],
        ),
      ],
    );
  }
}

class _IntervalTextField extends StatelessWidget {
  const _IntervalTextField({
    required this.label,
    required this.hint,
    this.controller,
    this.keyboardType,
    this.onChanged,
    this.showAutoLabel = false,
  });

  final String label;
  final String hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final bool showAutoLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: CohortTextStyles.muted),
            if (showAutoLabel) ...[
              const SizedBox(width: CohortSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: CohortSpacing.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: CohortColors.oliveSoft,
                  borderRadius: CohortRadius.smallRadius,
                  border: Border.all(
                    color: CohortColors.olive.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  'AUTO',
                  style: CohortTextStyles.eyebrow.copyWith(
                    color: CohortColors.olive,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: CohortSpacing.xs),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: CohortTextStyles.body,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: CohortTextStyles.small.copyWith(
              color: CohortColors.textMuted,
            ),
            filled: true,
            fillColor: CohortColors.surface,
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
              borderSide: const BorderSide(color: CohortColors.olive),
            ),
            contentPadding: const EdgeInsets.all(CohortSpacing.md),
          ),
        ),
      ],
    );
  }
}

class _PostSessionToggle extends StatelessWidget {
  const _PostSessionToggle({
    required this.enabled,
    required this.onChanged,
  });

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CohortColors.surfaceRaised,
      borderRadius: CohortRadius.largeRadius,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: CohortRadius.largeRadius,
          border: Border.all(
            color: CohortColors.border,
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: CohortSpacing.lg),
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          tileColor: Colors.transparent,
          hoverColor: CohortColors.oliveSoft.withValues(alpha: 0.35),
          title: Text(
            'Enter results after training',
            style: CohortTextStyles.cardTitle,
          ),
          subtitle: Text(
            'Fill all work intervals in a compact list after your session.',
            style: CohortTextStyles.small,
          ),
          value: enabled,
          activeThumbColor: CohortColors.olive,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _PostSessionWorkList extends StatelessWidget {
  const _PostSessionWorkList({
    required this.entries,
    required this.durationControllers,
    required this.distanceControllers,
    required this.paceControllers,
    required this.onRpeChanged,
    required this.onComplete,
    required this.onMetricFieldChanged,
    required this.executionState,
  });

  final List<IntervalRepEntry> entries;
  final Map<String, TextEditingController> durationControllers;
  final Map<String, TextEditingController> distanceControllers;
  final Map<String, TextEditingController> paceControllers;
  final void Function(IntervalRepEntry entry, int? rpe) onRpeChanged;
  final void Function(IntervalRepEntry entry) onComplete;
  final void Function(String localId, IntervalMetricField field, String text)
      onMetricFieldChanged;
  final IntervalSessionExecutionState executionState;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WORK INTERVAL RESULTS',
          style: CohortTextStyles.eyebrow,
        ),
        const SizedBox(height: CohortSpacing.md),
        for (var index = 0; index < entries.length; index++) ...[
          if (index > 0) const SizedBox(height: CohortSpacing.md),
          _PostSessionWorkCard(
            entry: executionState.entryByLocalId(entries[index].localId) ??
                entries[index],
            durationController: durationControllers[entries[index].localId],
            distanceController: distanceControllers[entries[index].localId],
            paceController: paceControllers[entries[index].localId],
            onRpeChanged: (rpe) => onRpeChanged(entries[index], rpe),
            onMetricFieldChanged: (field, text) =>
                onMetricFieldChanged(entries[index].localId, field, text),
            onComplete: () => onComplete(entries[index]),
          ),
        ],
      ],
    );
  }
}

class _PostSessionWorkCard extends StatelessWidget {
  const _PostSessionWorkCard({
    required this.entry,
    required this.onRpeChanged,
    required this.onComplete,
    this.onMetricFieldChanged,
    this.durationController,
    this.distanceController,
    this.paceController,
  });

  final IntervalRepEntry entry;
  final TextEditingController? durationController;
  final TextEditingController? distanceController;
  final TextEditingController? paceController;
  final void Function(int? rpe) onRpeChanged;
  final VoidCallback onComplete;
  final void Function(IntervalMetricField field, String text)?
      onMetricFieldChanged;

  @override
  Widget build(BuildContext context) {
    return CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Work interval ${entry.repNumber}',
                  style: CohortTextStyles.cardTitle,
                ),
              ),
              if (entry.completed)
                Text(
                  'COMPLETE',
                  style: CohortTextStyles.eyebrow.copyWith(
                    color: CohortColors.success,
                  ),
                ),
            ],
          ),
          if (entry.targetDuration != null ||
              entry.targetDistance != null ||
              entry.targetIntensity != null) ...[
            const SizedBox(height: CohortSpacing.xs),
            Text(
              [
                if (entry.targetDuration != null) entry.targetDuration,
                if (entry.targetDistance != null) entry.targetDistance,
                if (entry.targetIntensity != null) entry.targetIntensity,
              ].join(' · '),
              style: CohortTextStyles.small,
            ),
          ],
          const SizedBox(height: CohortSpacing.md),
          _ManualEntryFields(
            durationController: durationController,
            distanceController: distanceController,
            paceController: paceController,
            selectedRpe: entry.rpe,
            onRpeChanged: onRpeChanged,
            showAutoDuration:
                entry.durationSource == IntervalMetricEntrySource.auto,
            showAutoDistance:
                entry.distanceSource == IntervalMetricEntrySource.auto,
            showAutoPace: entry.paceSource == IntervalMetricEntrySource.auto,
            onDurationChanged: (text) => onMetricFieldChanged?.call(
              IntervalMetricField.duration,
              text,
            ),
            onDistanceChanged: (text) => onMetricFieldChanged?.call(
              IntervalMetricField.distance,
              text,
            ),
            onPaceChanged: (text) => onMetricFieldChanged?.call(
              IntervalMetricField.pace,
              text,
            ),
          ),
          const SizedBox(height: CohortSpacing.md),
          CohortButton(
            label: entry.completed ? 'Update result' : 'Mark complete',
            onPressed: onComplete,
          ),
        ],
      ),
    );
  }
}

class _RecoveryTimerBar extends StatelessWidget {
  const _RecoveryTimerBar({
    required this.state,
    required this.onPause,
    required this.onResume,
    required this.onSkip,
    required this.onAddFifteenSeconds,
  });

  final StrengthRestTimerState state;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onSkip;
  final VoidCallback onAddFifteenSeconds;

  @override
  Widget build(BuildContext context) {
    final accentColor =
        state.finished ? CohortColors.success : CohortColors.olive;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(CohortSpacing.md),
      decoration: BoxDecoration(
        color: CohortColors.surfaceRaised,
        borderRadius: CohortRadius.smallRadius,
        border: Border.all(color: accentColor.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.finished ? 'RECOVERY COMPLETE' : 'RECOVERY',
            style: CohortTextStyles.eyebrow.copyWith(color: accentColor),
          ),
          const SizedBox(height: CohortSpacing.sm),
          Text(
            state.finished ? 'Recovery complete' : state.remainingLabel,
            style: CohortTextStyles.h2.copyWith(color: accentColor),
          ),
          if (!state.finished) ...[
            const SizedBox(height: CohortSpacing.xs),
            Text('of ${state.totalLabel}', style: CohortTextStyles.small),
          ],
          const SizedBox(height: CohortSpacing.md),
          Wrap(
            spacing: CohortSpacing.sm,
            runSpacing: CohortSpacing.sm,
            children: [
              if (!state.finished)
                OutlinedButton(
                  onPressed: state.isPaused ? onResume : onPause,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CohortColors.olive,
                    side: const BorderSide(color: CohortColors.borderStrong),
                  ),
                  child: Text(
                    state.isPaused ? 'Resume' : 'Pause',
                    style: CohortTextStyles.small,
                  ),
                ),
              OutlinedButton(
                onPressed: onSkip,
                style: OutlinedButton.styleFrom(
                  foregroundColor: CohortColors.textSecondary,
                  side: const BorderSide(color: CohortColors.border),
                ),
                child: Text('Skip', style: CohortTextStyles.small),
              ),
              if (!state.finished)
                OutlinedButton(
                  onPressed: onAddFifteenSeconds,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CohortColors.olive,
                    side: const BorderSide(color: CohortColors.borderStrong),
                  ),
                  child: Text('+15 sec', style: CohortTextStyles.small),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IntervalEndSessionEarlyResult {
  const _IntervalEndSessionEarlyResult({this.reason});

  final EarlySessionEndReason? reason;
}

class _IntervalEndSessionEarlyDialog extends StatefulWidget {
  const _IntervalEndSessionEarlyDialog({
    required this.completedWorkCount,
    required this.totalWorkCount,
  });

  final int completedWorkCount;
  final int totalWorkCount;

  @override
  State<_IntervalEndSessionEarlyDialog> createState() =>
      _IntervalEndSessionEarlyDialogState();
}

class _IntervalEndSessionEarlyDialogState
    extends State<_IntervalEndSessionEarlyDialog> {
  EarlySessionEndReason? _selectedReason;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: CohortColors.surfaceRaised,
      title: Text(
        'End session early?',
        style: CohortTextStyles.cardTitle,
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You have completed ${widget.completedWorkCount} of '
              '${widget.totalWorkCount} work intervals. End this session now?',
              style: CohortTextStyles.body,
            ),
            const SizedBox(height: CohortSpacing.lg),
            Text('Reason (optional)', style: CohortTextStyles.muted),
            const SizedBox(height: CohortSpacing.sm),
            for (final reason in EarlySessionEndReason.values)
              Padding(
                padding: const EdgeInsets.only(bottom: CohortSpacing.xs),
                child: InkWell(
                  onTap: () => setState(() {
                    _selectedReason =
                        _selectedReason == reason ? null : reason;
                  }),
                  borderRadius: CohortRadius.smallRadius,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: CohortSpacing.md,
                      vertical: CohortSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedReason == reason
                          ? CohortColors.oliveSoft
                          : Colors.transparent,
                      borderRadius: CohortRadius.smallRadius,
                      border: Border.all(
                        color: _selectedReason == reason
                            ? CohortColors.olive
                            : CohortColors.border,
                      ),
                    ),
                    child: Text(reason.label, style: CohortTextStyles.small),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            _IntervalEndSessionEarlyResult(reason: _selectedReason),
          ),
          child: const Text('End session'),
        ),
      ],
    );
  }
}

enum _LeaveSessionChoice {
  resumeLater,
  endEarly,
  cancel,
}

class _IntervalSessionNoteField extends StatefulWidget {
  const _IntervalSessionNoteField({
    required this.value,
    required this.onChanged,
  });

  final String? value;
  final ValueChanged<String> onChanged;

  @override
  State<_IntervalSessionNoteField> createState() =>
      _IntervalSessionNoteFieldState();
}

class _IntervalSessionNoteFieldState extends State<_IntervalSessionNoteField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
  }

  @override
  void didUpdateWidget(covariant _IntervalSessionNoteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.text = widget.value ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SESSION NOTE (OPTIONAL)',
          style: CohortTextStyles.eyebrow,
        ),
        const SizedBox(height: CohortSpacing.sm),
        TextField(
          controller: _controller,
          onChanged: widget.onChanged,
          maxLines: 3,
          style: CohortTextStyles.body,
          decoration: InputDecoration(
            hintText: 'How did today feel?',
            hintStyle: CohortTextStyles.small.copyWith(
              color: CohortColors.textMuted,
            ),
            filled: true,
            fillColor: CohortColors.surface,
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
              borderSide: const BorderSide(color: CohortColors.olive),
            ),
            contentPadding: const EdgeInsets.all(CohortSpacing.md),
          ),
        ),
      ],
    );
  }
}

String _intervalPhaseSummaryLabel(IntervalRepEntry entry) {
  final label = _phaseTypeLabel(entry.phaseType);
  if (entry.isWorkPhase) {
    return '$label · rep ${entry.repNumber}';
  }

  return label;
}

String _phaseTypeLabel(IntervalPhaseType type) {
  return switch (type) {
    IntervalPhaseType.warmUp => 'Warm-up',
    IntervalPhaseType.work => 'Work',
    IntervalPhaseType.recovery => 'Recovery',
    IntervalPhaseType.coolDown => 'Cool-down',
    IntervalPhaseType.instruction => 'Instruction',
  };
}

String? _formatDuration(Duration? duration) {
  return _IntervalSessionViewState._metricCalculator
      .formatDurationSeconds(duration?.inSeconds);
}

String? _formatDistance(double? meters) {
  return _IntervalSessionViewState._metricCalculator.formatDistanceMeters(meters);
}

String? _formatPace(double? secondsPerKm) {
  final formatted = _IntervalSessionViewState._metricCalculator
      .formatPaceSecondsPerKm(secondsPerKm);
  if (formatted == null) {
    return null;
  }

  return formatted.replaceAll('/km', '');
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
