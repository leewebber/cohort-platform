import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../../data/repositories/training_session_set_repository.dart';
import '../../../models/exercise.dart';
import '../../../models/exercise_progress_result.dart';
import '../../../models/previous_exercise_performance.dart';
import '../../../models/session_step.dart';
import '../../exercises/exercise_history/exercise_history_screen.dart';
import '../models/early_session_end_result.dart';
import '../models/session_leave_decision.dart';
import 'shared/early_session_end_dialog.dart';
import 'shared/previous_performance_shell.dart';
import 'shared/progress_result_card.dart';
import 'shared/session_execution_header.dart';
import 'shared/session_finish_actions.dart';
import 'shared/session_note_field.dart';
import 'shared/session_progress_summary.dart';
import '../models/strength_rest_timer_state.dart';
import '../models/strength_session_finish_summary.dart';
import '../models/strength_set_entry.dart';
import '../services/strength_progress_service.dart';
import '../services/strength_rest_timer_controller.dart';
import '../services/strength_session_hydrator.dart';
import '../services/strength_session_leave_coordinator.dart';
import '../services/strength_set_performance_mapper.dart';

/// Dedicated execution view for structured strength sessions (v0.3).
///
/// Tracks prescribed and extra sets in local memory. Completed sets persist to
/// `training_session_sets` when [trainingSessionId] is provided.
///
/// v0.3 exercise notes map to `athlete_note` on the final completed set for
/// that exercise. Session notes persist on `training_sessions.session_note`
/// when the session is completed.
class StrengthSessionView extends StatefulWidget {
  const StrengthSessionView({
    super.key,
    required this.sessionTitle,
    required this.steps,
    required this.onFinishSession,
    this.trainingSessionId,
    this.athleteId,
    this.onLeaveCoordinatorReady,
    TrainingSessionSetRepository? setRepository,
    StrengthSetPerformanceMapper? performanceMapper,
    StrengthProgressService? progressService,
    StrengthSessionHydrator? sessionHydrator,
  })  : setRepository = setRepository ?? const TrainingSessionSetRepository(),
        performanceMapper = performanceMapper ?? const StrengthSetPerformanceMapper(),
        progressService = progressService ?? const StrengthProgressService(),
        sessionHydrator = sessionHydrator ?? const StrengthSessionHydrator();

  final String sessionTitle;
  final List<SessionStep> steps;
  final Future<void> Function(StrengthSessionFinishSummary summary) onFinishSession;
  final int? trainingSessionId;
  final String? athleteId;
  final void Function(StrengthSessionLeaveCoordinator coordinator)?
      onLeaveCoordinatorReady;
  final TrainingSessionSetRepository setRepository;
  final StrengthSetPerformanceMapper performanceMapper;
  final StrengthProgressService progressService;
  final StrengthSessionHydrator sessionHydrator;

  @override
  State<StrengthSessionView> createState() => _StrengthSessionViewState();
}

class _StrengthExerciseLog {
  _StrengthExerciseLog({
    required this.step,
    required List<StrengthSetEntry> sets,
  }) : sets = List<StrengthSetEntry>.from(sets);

  final SessionStep step;
  List<StrengthSetEntry> sets;
  bool isCollapsed = false;
  ExerciseProgressResult? progressResult;
  String? athleteNote;

  List<StrengthSetEntry> get prescribedSets =>
      sets.where((set) => !set.isExtraSet).toList();

  List<StrengthSetEntry> get extraSets =>
      sets.where((set) => set.isExtraSet).toList();

  int get prescribedSetCount => prescribedSets.length;

  int get prescribedCompletedCount =>
      prescribedSets.where((set) => set.completed).length;

  int get totalPerformedCount => sets.where((set) => set.completed).length;

  bool get canCompleteExercise {
    if (prescribedSets.any((set) => !set.completed)) {
      return false;
    }

    for (final extraSet in extraSets) {
      if (extraSet.hasStartedData && !extraSet.completed) {
        return false;
      }
    }

    return true;
  }

  String? get summaryLoad {
    final loads = sets
        .where((set) => set.completed)
        .map((set) => set.load?.trim())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toList();

    if (loads.isEmpty) {
      return null;
    }

    double? heaviest;
    String? heaviestLabel;

    for (final load in loads) {
      final numeric = double.tryParse(load.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (numeric != null) {
        if (heaviest == null || numeric > heaviest) {
          heaviest = numeric;
          heaviestLabel = load;
        }
      }
    }

    return heaviestLabel ?? loads.last;
  }
}

class _StrengthSessionViewState extends State<StrengthSessionView> {
  late final Map<int, _StrengthExerciseLog> _exerciseLogs;
  late final Map<int, Future<PreviousExercisePerformance?>> _previousPerformanceFutures;
  late final StrengthRestTimerController _restTimerController;
  final Set<int> _completedStepNumbers = {};
  StrengthRestTimerState? _restTimerState;
  String? _highlightedSetLocalId;
  String? _sessionNote;
  bool _isHydratingSession = false;
  bool _finishEndedEarly = false;
  String? _earlyEndReasonLabel;
  final Set<String> _preservedSetLocalIds = {};
  final Set<int> _preservedExerciseNotes = {};

  bool get _isRealSession => widget.trainingSessionId != null;

  bool get hasRecordedProgress {
    if (_completedStepNumbers.isNotEmpty) {
      return true;
    }

    for (final log in _exerciseLogs.values) {
      if (log.sets.any((set) => set.completed || set.hasStartedData)) {
        return true;
      }

      if (log.athleteNote?.trim().isNotEmpty == true) {
        return true;
      }
    }

    return _sessionNote?.trim().isNotEmpty == true;
  }

  bool get _showPreviousPerformance =>
      widget.athleteId != null && widget.athleteId!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _restTimerController = StrengthRestTimerController(
      onStateChanged: (state) {
        if (!mounted) {
          return;
        }
        setState(() => _restTimerState = state);
      },
      onFinished: _handleRestTimerFinished,
    );
    _exerciseLogs = {
      for (final step in widget.steps)
        step.stepNumber: _StrengthExerciseLog(
          step: step,
          sets: StrengthSetEntry.prescribedSetsForStep(
            stepNumber: step.stepNumber,
            prescribedSets: step.prescribedSets,
            targetReps: step.prescribedReps,
            defaultLoad: step.prescribedLoad,
          ),
        ),
    };
    _previousPerformanceFutures = {
      for (final step in widget.steps)
        step.stepNumber: _loadPreviousPerformance(step),
    };

    if (_isRealSession) {
      _loadPersistedSessionState();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onLeaveCoordinatorReady?.call(
        StrengthSessionLeaveCoordinator(
          hasRecordedProgress: () => hasRecordedProgress,
          confirmLeave: _confirmLeaveSession,
        ),
      );
    });
  }

  @override
  void dispose() {
    _restTimerController.dispose();
    super.dispose();
  }

  Future<PreviousExercisePerformance?> _loadPreviousPerformance(
    SessionStep step,
  ) {
    if (!_showPreviousPerformance) {
      return Future.value(null);
    }

    final exerciseId = step.exerciseId?.trim();
    if (exerciseId == null || exerciseId.isEmpty) {
      return Future.value(null);
    }

    return widget.setRepository.getLatestCompletedExercisePerformance(
      athleteId: widget.athleteId!.trim(),
      exerciseId: exerciseId,
    );
  }

  bool get _allExercisesComplete =>
      widget.steps.isNotEmpty &&
      _completedStepNumbers.length == widget.steps.length;

  int get _completedCount => _completedStepNumbers.length;

  int get _completedExerciseCountForSummary {
    var count = 0;
    for (final step in widget.steps) {
      if (_logFor(step.stepNumber).canCompleteExercise) {
        count++;
      }
    }
    return count;
  }

  _StrengthExerciseLog _logFor(int stepNumber) {
    return _exerciseLogs[stepNumber]!;
  }

  void _preserveSetLocalId(String localId) {
    _preservedSetLocalIds.add(localId);
  }

  void _preserveExerciseNote(int stepNumber) {
    _preservedExerciseNotes.add(stepNumber);
  }

  Future<void> _loadPersistedSessionState() async {
    final trainingSessionId = widget.trainingSessionId;
    if (trainingSessionId == null) {
      return;
    }

    setState(() => _isHydratingSession = true);

    try {
      final persistedSets = await widget.setRepository.getSetsForTrainingSession(
        trainingSessionId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        for (final step in widget.steps) {
          final log = _logFor(step.stepNumber);
          final hydration = widget.sessionHydrator.hydrateExercise(
            step: step,
            baseSets: log.sets,
            persisted: persistedSets,
            preserveSetLocalIds: _preservedSetLocalIds,
          );

          log.sets = hydration.sets;

          if (!_preservedExerciseNotes.contains(step.stepNumber)) {
            log.athleteNote = hydration.athleteNote;
          }

          if (hydration.isExerciseComplete) {
            log.isCollapsed = true;
            _completedStepNumbers.add(step.stepNumber);
          }
        }
      });

      await _restoreProgressResults();
    } catch (error) {
      debugPrint('[StrengthSessionView] session hydrate failed: $error');
    } finally {
      if (mounted) {
        setState(() => _isHydratingSession = false);
      }
    }
  }

  Future<void> _restoreProgressResults() async {
    if (!_showPreviousPerformance) {
      return;
    }

    for (final stepNumber in _completedStepNumbers.toList()) {
      final log = _logFor(stepNumber);
      if (log.progressResult != null) {
        continue;
      }

      final previous = await _previousPerformanceFutures[stepNumber];
      if (!mounted) {
        return;
      }

      setState(() {
        log.progressResult = widget.progressService.evaluate(
          previousPerformance: previous,
          todayCompletedSets: log.sets.where((set) => set.completed).toList(),
        );
      });
    }
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
            'Your completed sets are saved. You can resume this session later from Home.',
            style: CohortTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(SessionLeaveDecision.resumeLater),
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

    if (!context.mounted || choice == null || choice == SessionLeaveDecision.cancel) {
      return;
    }

    switch (choice) {
      case SessionLeaveDecision.resumeLater:
        Navigator.of(context).pop();
      case SessionLeaveDecision.endEarly:
        await _showEndSessionEarlyDialog(context);
      case SessionLeaveDecision.cancel:
        break;
    }
  }

  Future<void> _showEndSessionEarlyDialog(BuildContext context) async {
    final result = await showDialog<EarlySessionEndResult>(
      context: context,
      builder: (dialogContext) {
        return EarlySessionEndDialog(
          completedCount: _completedExerciseCountForSummary,
          totalCount: widget.steps.length,
          unitLabel: 'exercises',
          emphasizeConfirmButton: true,
        );
      },
    );

    if (result == null || !context.mounted) {
      return;
    }

    await _finishSessionEarly(result.reason?.label);
  }

  Future<void> _finishSessionEarly(String? reasonLabel) async {
    await _persistAllCompletedSets();
    _finishEndedEarly = true;
    _earlyEndReasonLabel = reasonLabel;
    await widget.onFinishSession(_buildFinishSummary());
  }

  Future<void> _persistAllCompletedSets() async {
    if (!_isRealSession) {
      return;
    }

    for (final step in widget.steps) {
      final log = _logFor(step.stepNumber);
      for (final set in log.sets.where((entry) => entry.completed)) {
        await _persistCompletedSet(
          stepNumber: step.stepNumber,
          entry: set,
        );
      }

      await _persistExerciseNote(step.stepNumber);
    }
  }

  void _updateSet({
    required int stepNumber,
    required String localId,
    required StrengthSetEntry Function(StrengthSetEntry current) transform,
  }) {
    setState(() {
      final log = _logFor(stepNumber);
      log.sets = log.sets
          .map(
            (set) => set.localId == localId ? transform(set) : set,
          )
          .toList();
    });
  }

  void _addExtraSet(int stepNumber) {
    setState(() {
      final log = _logFor(stepNumber);
      final nextSetNumber = log.sets.isEmpty
          ? 1
          : log.sets.map((set) => set.setNumber).reduce(
                (left, right) => left > right ? left : right,
              ) +
              1;

      final entry = StrengthSetEntry(
        localId: 'extra-$stepNumber-${DateTime.now().microsecondsSinceEpoch}',
        setNumber: nextSetNumber,
        targetReps: log.step.prescribedReps?.trim(),
        load: log.step.prescribedLoad?.trim(),
        isExtraSet: true,
      );
      _preserveSetLocalId(entry.localId);

      log.sets = [
        ...log.sets,
        entry,
      ];
    });
  }

  void _removeExtraSet({
    required int stepNumber,
    required String localId,
  }) {
    setState(() {
      final log = _logFor(stepNumber);
      log.sets =
          log.sets.where((set) => set.localId != localId).toList(growable: true);
    });
  }

  Future<void> _completeExercise(int stepNumber) async {
    final log = _logFor(stepNumber);
    if (!log.canCompleteExercise) {
      return;
    }

    await _persistExerciseNote(stepNumber);

    ExerciseProgressResult? progressResult;
    if (_showPreviousPerformance) {
      final previous = await _previousPerformanceFutures[stepNumber];
      progressResult = widget.progressService.evaluate(
        previousPerformance: previous,
        todayCompletedSets: log.sets.where((set) => set.completed).toList(),
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      log.isCollapsed = true;
      log.progressResult = progressResult;
      _completedStepNumbers.add(stepNumber);
    });
  }

  Future<void> _handleSetChanged({
    required int stepNumber,
    required String localId,
    String? actualReps,
    String? load,
    bool? completed,
    int? rpe,
    bool clearRpe = false,
  }) async {
    _preserveSetLocalId(localId);

    final previousSet = _logFor(stepNumber).sets.firstWhere(
          (set) => set.localId == localId,
        );
    final wasCompleted = previousSet.completed;

    _updateSet(
      stepNumber: stepNumber,
      localId: localId,
      transform: (set) => set.copyWith(
        actualReps: actualReps ?? set.actualReps,
        load: load ?? set.load,
        completed: completed ?? set.completed,
        rpe: rpe,
        clearRpe: clearRpe,
      ),
    );

    final updated = _logFor(stepNumber).sets.firstWhere(
          (set) => set.localId == localId,
        );

    if (!wasCompleted && updated.completed) {
      _maybeStartRestTimer(
        stepNumber: stepNumber,
        completedSetLocalId: localId,
      );
    }

    if (widget.trainingSessionId != null && updated.completed) {
      await _persistCompletedSet(
        stepNumber: stepNumber,
        entry: updated,
      );
    }
  }

  void _handleExerciseNoteChanged(int stepNumber, String value) {
    _preserveExerciseNote(stepNumber);
    setState(() {
      _logFor(stepNumber).athleteNote = value;
    });

    if (widget.trainingSessionId != null) {
      _persistExerciseNote(stepNumber);
    }
  }

  StrengthSetEntry? _finalCompletedSet(_StrengthExerciseLog log) {
    final completedSets = log.sets.where((set) => set.completed).toList();
    if (completedSets.isEmpty) {
      return null;
    }

    completedSets.sort((a, b) => a.setNumber.compareTo(b.setNumber));
    return completedSets.last;
  }

  bool _isFinalCompletedSet(_StrengthExerciseLog log, StrengthSetEntry entry) {
    final finalSet = _finalCompletedSet(log);
    return finalSet?.localId == entry.localId;
  }

  String? _resolveAthleteNoteForSet(
    _StrengthExerciseLog log,
    StrengthSetEntry entry,
  ) {
    final note = log.athleteNote?.trim();
    if (note == null || note.isEmpty || !_isFinalCompletedSet(log, entry)) {
      return null;
    }

    return note;
  }

  Future<void> _persistExerciseNote(int stepNumber) async {
    final log = _logFor(stepNumber);
    final finalSet = _finalCompletedSet(log);
    if (finalSet == null) {
      return;
    }

    await _persistCompletedSet(
      stepNumber: stepNumber,
      entry: finalSet,
    );
  }

  void _maybeStartRestTimer({
    required int stepNumber,
    required String completedSetLocalId,
  }) {
    final log = _logFor(stepNumber);
    final parsedRest = StrengthRestParser.parse(log.step.prescribedRest);
    if (parsedRest == null) {
      return;
    }

    final nextTargetLabel = _resolveNextTargetLabel(
      stepNumber: stepNumber,
      completedSetLocalId: completedSetLocalId,
    );

    setState(() => _highlightedSetLocalId = null);

    _restTimerController.start(
      exerciseLocalId: StrengthRestTimerState.exerciseLocalIdForStep(stepNumber),
      setLocalId: completedSetLocalId,
      totalSeconds: parsedRest.totalSeconds,
      prescribedRestLabel: parsedRest.displayLabel,
      nextTargetLabel: nextTargetLabel,
    );
  }

  void _handleRestTimerFinished(StrengthRestTimerState state) {
    final stepNumber = int.tryParse(
      state.exerciseLocalId.replaceFirst('exercise-', ''),
    );
    if (stepNumber == null) {
      return;
    }

    setState(() {
      _highlightedSetLocalId = _resolveNextIncompleteSetLocalId(
        stepNumber: stepNumber,
        afterSetLocalId: state.setLocalId,
      );
    });
  }

  String _resolveNextTargetLabel({
    required int stepNumber,
    required String completedSetLocalId,
  }) {
    final nextSetLocalId = _resolveNextIncompleteSetLocalId(
      stepNumber: stepNumber,
      afterSetLocalId: completedSetLocalId,
    );

    if (nextSetLocalId != null) {
      final log = _logFor(stepNumber);
      final set = log.sets.firstWhere((entry) => entry.localId == nextSetLocalId);
      final label = set.isExtraSet
          ? 'Extra set ${set.setNumber}'
          : 'Set ${set.setNumber}';
      return 'Next: $label';
    }

    final log = _logFor(stepNumber);
    if (!log.canCompleteExercise) {
      return 'Next: Complete exercise';
    }

    final currentIndex = widget.steps.indexWhere(
      (step) => step.stepNumber == stepNumber,
    );

    for (var index = currentIndex + 1; index < widget.steps.length; index++) {
      final step = widget.steps[index];
      final nextLog = _logFor(step.stepNumber);
      if (!nextLog.isCollapsed) {
        return 'Next: Exercise ${step.stepNumber} — ${step.title}';
      }
    }

    return 'Next: Finish session';
  }

  String? _resolveNextIncompleteSetLocalId({
    required int stepNumber,
    String? afterSetLocalId,
  }) {
    final log = _logFor(stepNumber);
    final startIndex = afterSetLocalId == null
        ? 0
        : log.sets.indexWhere((set) => set.localId == afterSetLocalId) + 1;

    if (startIndex > 0) {
      for (var index = startIndex; index < log.sets.length; index++) {
        final set = log.sets[index];
        if (!set.completed) {
          return set.localId;
        }
      }
    }

    for (final set in log.sets) {
      if (!set.completed) {
        return set.localId;
      }
    }

    final currentIndex = widget.steps.indexWhere(
      (step) => step.stepNumber == stepNumber,
    );

    for (var index = currentIndex + 1; index < widget.steps.length; index++) {
      final nextLog = _logFor(widget.steps[index].stepNumber);
      if (nextLog.isCollapsed) {
        continue;
      }

      for (final set in nextLog.sets) {
        if (!set.completed) {
          return set.localId;
        }
      }
    }

    return null;
  }

  void _handleRestTimerSkip() {
    _restTimerController.skip();
  }

  StrengthSessionFinishSummary _buildFinishSummary() {
    return StrengthSessionFinishSummary(
      sessionTitle: widget.sessionTitle,
      sessionNote: _sessionNote,
      completedExerciseCount: _completedExerciseCountForSummary,
      totalExerciseCount: widget.steps.length,
      endedEarly: _finishEndedEarly,
      endReasonLabel: _earlyEndReasonLabel,
      exercises: [
        for (final step in widget.steps)
          ExerciseProgressSnapshot(
            exerciseName: step.title,
            progressResult: _logFor(step.stepNumber).progressResult,
          ),
      ],
    );
  }

  Future<void> _handleFinishSession() async {
    _finishEndedEarly = false;
    _earlyEndReasonLabel = null;
    await _persistAllCompletedSets();
    await widget.onFinishSession(_buildFinishSummary());
  }

  void _openExerciseHistory(BuildContext context, SessionStep step) {
    final exerciseId = step.exerciseId?.trim();
    final athleteId = widget.athleteId?.trim();
    if (exerciseId == null ||
        exerciseId.isEmpty ||
        athleteId == null ||
        athleteId.isEmpty) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExerciseHistoryScreen(
          exercise: Exercise(
            exerciseId: exerciseId,
            name: step.title,
            published: true,
          ),
          athleteId: athleteId,
        ),
      ),
    );
  }

  Future<void> _persistCompletedSet({
    required int stepNumber,
    required StrengthSetEntry entry,
  }) async {
    final trainingSessionId = widget.trainingSessionId;
    if (trainingSessionId == null) {
      return;
    }

    final step = _logFor(stepNumber).step;
    final log = _logFor(stepNumber);
    final performance = widget.performanceMapper.fromEntry(
      trainingSessionId: trainingSessionId,
      step: step,
      entry: entry,
      athleteNote: _resolveAthleteNoteForSet(log, entry),
    );

    if (performance == null) {
      _showPersistenceError(
        'This set could not be saved because the exercise link is missing.',
      );
      return;
    }

    try {
      await widget.setRepository.upsertSetPerformance(performance);
    } catch (error) {
      debugPrint('[StrengthSessionView] set save failed: $error');
      _showPersistenceError(
        'Set saved locally, but performance could not be synced right now.',
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
          style: CohortTextStyles.body,
        ),
        backgroundColor: CohortColors.surfaceRaised,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SessionExecutionHeader(
          modeLabel: 'STRUCTURED STRENGTH',
          sessionTitle: widget.sessionTitle,
        ),
        const SizedBox(height: CohortSpacing.xl),
        SessionProgressSummary(
          completedCount: _completedCount,
          totalCount: widget.steps.length,
          summaryLabel:
              '$_completedCount of ${widget.steps.length} exercises complete',
          showProgressBar: true,
        ),
        if (_isHydratingSession) ...[
          const SizedBox(height: CohortSpacing.xs),
          Text(
            'Restoring saved session...',
            style: CohortTextStyles.small,
          ),
        ],
        if (_restTimerState != null) ...[
          const SizedBox(height: CohortSpacing.md),
          _StrengthRestTimerBar(
            state: _restTimerState!,
            onPause: _restTimerController.pause,
            onResume: _restTimerController.resume,
            onSkip: _handleRestTimerSkip,
            onAddFifteenSeconds: _restTimerController.addFifteenSeconds,
          ),
        ],
        const SizedBox(height: CohortSpacing.xl),
        for (var index = 0; index < widget.steps.length; index++) ...[
          if (index > 0) const SizedBox(height: CohortSpacing.md),
          _StrengthExerciseCard(
            log: _logFor(widget.steps[index].stepNumber),
            highlightedSetLocalId: _highlightedSetLocalId,
            showPreviousPerformance: _showPreviousPerformance,
            previousPerformanceFuture:
                _previousPerformanceFutures[widget.steps[index].stepNumber],
            onSetChanged: ({
              required String localId,
              String? actualReps,
              String? load,
              bool? completed,
              int? rpe,
              bool clearRpe = false,
            }) {
              _handleSetChanged(
                stepNumber: widget.steps[index].stepNumber,
                localId: localId,
                actualReps: actualReps,
                load: load,
                completed: completed,
                rpe: rpe,
                clearRpe: clearRpe,
              );
            },
            onExerciseNoteChanged: (value) => _handleExerciseNoteChanged(
              widget.steps[index].stepNumber,
              value,
            ),
            onAddSet: () => _addExtraSet(widget.steps[index].stepNumber),
            onRemoveExtraSet: (localId) => _removeExtraSet(
              stepNumber: widget.steps[index].stepNumber,
              localId: localId,
            ),
            onCompleteExercise: () =>
                _completeExercise(widget.steps[index].stepNumber),
            onSeeFullHistory: () => _openExerciseHistory(
              context,
              widget.steps[index],
            ),
          ),
        ],
        if (_isRealSession && !_allExercisesComplete) ...[
          const SizedBox(height: CohortSpacing.xl),
          SessionFinishActions(
            showEndSessionEarly: true,
            onEndSessionEarly: () => _showEndSessionEarlyDialog(context),
          ),
        ],
        if (_allExercisesComplete) ...[
          const SizedBox(height: CohortSpacing.xl),
          SessionNoteField(
            value: _sessionNote,
            onChanged: (value) => setState(() => _sessionNote = value),
            helperText: 'Saved when you finish the session.',
          ),
          const SizedBox(height: CohortSpacing.md),
          SessionFinishActions(
            showFinishSession: true,
            onFinishSession: _handleFinishSession,
          ),
        ],
      ],
    );
  }
}

class _StrengthExerciseCard extends StatelessWidget {
  const _StrengthExerciseCard({
    required this.log,
    required this.highlightedSetLocalId,
    required this.showPreviousPerformance,
    required this.previousPerformanceFuture,
    required this.onSetChanged,
    required this.onExerciseNoteChanged,
    required this.onAddSet,
    required this.onRemoveExtraSet,
    required this.onCompleteExercise,
    this.onSeeFullHistory,
  });

  final _StrengthExerciseLog log;
  final String? highlightedSetLocalId;
  final bool showPreviousPerformance;
  final Future<PreviousExercisePerformance?>? previousPerformanceFuture;
  final void Function({
    required String localId,
    String? actualReps,
    String? load,
    bool? completed,
    int? rpe,
    bool clearRpe,
  }) onSetChanged;
  final ValueChanged<String> onExerciseNoteChanged;
  final VoidCallback onAddSet;
  final void Function(String localId) onRemoveExtraSet;
  final VoidCallback onCompleteExercise;
  final VoidCallback? onSeeFullHistory;

  @override
  Widget build(BuildContext context) {
    if (log.isCollapsed) {
      return CohortCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.check_circle,
              size: 20,
              color: CohortColors.success,
            ),
            const SizedBox(width: CohortSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EXERCISE ${log.step.stepNumber} COMPLETE',
                    style: CohortTextStyles.eyebrow,
                  ),
                  const SizedBox(height: CohortSpacing.xs),
                  Text(
                    log.step.title,
                    style: CohortTextStyles.cardTitle,
                  ),
                  const SizedBox(height: CohortSpacing.sm),
                  Text(
                    '${log.prescribedCompletedCount}/${log.prescribedSetCount} prescribed sets • '
                    '${log.totalPerformedCount} total sets performed',
                    style: CohortTextStyles.small,
                  ),
                  if (log.summaryLoad != null) ...[
                    const SizedBox(height: CohortSpacing.xs),
                    Text(
                      'Top load: ${log.summaryLoad}',
                      style: CohortTextStyles.small,
                    ),
                  ],
                  if (log.progressResult != null) ...[
                    const SizedBox(height: CohortSpacing.md),
                    ProgressResultCard(
                      title: log.progressResult!.title,
                      message: log.progressResult!.message,
                      accentColor: _exerciseProgressAccent(
                        log.progressResult!.progressType,
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

    return CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EXERCISE ${log.step.stepNumber}',
            style: CohortTextStyles.eyebrow,
          ),
          const SizedBox(height: CohortSpacing.lg),
          Text(
            log.step.title,
            style: CohortTextStyles.h2,
          ),
          if (log.step.prescription != null) ...[
            const SizedBox(height: CohortSpacing.sm),
            Text(
              log.step.prescription!,
              style: CohortTextStyles.body,
            ),
          ],
          if (log.step.coachCue != null) ...[
            const SizedBox(height: CohortSpacing.xl),
            Text(
              'Coach Cue',
              style: CohortTextStyles.eyebrow,
            ),
            const SizedBox(height: CohortSpacing.sm),
            Text(
              log.step.coachCue!,
              style: CohortTextStyles.body,
            ),
          ],
          const SizedBox(height: CohortSpacing.xl),
          if (showPreviousPerformance && previousPerformanceFuture != null)
            FutureBuilder<PreviousExercisePerformance?>(
              future: previousPerformanceFuture,
              builder: (context, snapshot) {
                return _PreviousPerformanceSection(
                  performance: snapshot.data,
                  isLoading: snapshot.connectionState == ConnectionState.waiting,
                  canOpenFullHistory: onSeeFullHistory != null &&
                      (snapshot.data?.hasHistory ?? false),
                  onSeeFullHistory: onSeeFullHistory,
                );
              },
            ),
          if (showPreviousPerformance && previousPerformanceFuture != null)
            const SizedBox(height: CohortSpacing.xl),
          for (final set in log.sets) ...[
            _StrengthSetRow(
              set: set,
              highlighted: highlightedSetLocalId == set.localId,
              onChanged: onSetChanged,
              onRemove: set.isExtraSet
                  ? () => onRemoveExtraSet(set.localId)
                  : null,
            ),
            const SizedBox(height: CohortSpacing.md),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onAddSet,
              child: Text(
                'Add Set',
                style: CohortTextStyles.body.copyWith(
                  color: CohortColors.olive,
                ),
              ),
            ),
          ),
          const SizedBox(height: CohortSpacing.md),
          _AthleteNoteField(
            value: log.athleteNote,
            onChanged: onExerciseNoteChanged,
          ),
          const SizedBox(height: CohortSpacing.md),
          CohortButton(
            label: 'Complete Exercise',
            onPressed: log.canCompleteExercise ? onCompleteExercise : () {},
          ),
        ],
      ),
    );
  }
}

class _StrengthRestTimerBar extends StatelessWidget {
  const _StrengthRestTimerBar({
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
    final accentColor = state.finished ? CohortColors.success : CohortColors.olive;

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
            state.finished ? 'REST COMPLETE' : 'REST',
            style: CohortTextStyles.eyebrow.copyWith(color: accentColor),
          ),
          const SizedBox(height: CohortSpacing.sm),
          Text(
            state.finished ? 'Rest complete' : state.remainingLabel,
            style: CohortTextStyles.h2.copyWith(color: accentColor),
          ),
          if (!state.finished) ...[
            const SizedBox(height: CohortSpacing.xs),
            Text(
              'of ${state.totalLabel}',
              style: CohortTextStyles.small,
            ),
          ],
          if (state.prescribedRestLabel != null) ...[
            const SizedBox(height: CohortSpacing.xs),
            Text(
              'Prescribed: ${state.prescribedRestLabel}',
              style: CohortTextStyles.small,
            ),
          ],
          if (state.nextTargetLabel != null) ...[
            const SizedBox(height: CohortSpacing.xs),
            Text(
              state.nextTargetLabel!,
              style: CohortTextStyles.small,
            ),
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
                child: Text(
                  'Skip',
                  style: CohortTextStyles.small,
                ),
              ),
              if (!state.finished)
                OutlinedButton(
                  onPressed: onAddFifteenSeconds,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CohortColors.olive,
                    side: const BorderSide(color: CohortColors.borderStrong),
                  ),
                  child: Text(
                    '+15 sec',
                    style: CohortTextStyles.small,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviousPerformanceSection extends StatelessWidget {
  const _PreviousPerformanceSection({
    required this.performance,
    required this.isLoading,
    required this.canOpenFullHistory,
    this.onSeeFullHistory,
  });

  final PreviousExercisePerformance? performance;
  final bool isLoading;
  final bool canOpenFullHistory;
  final VoidCallback? onSeeFullHistory;

  static const _opportunityItems = [
    'More weight',
    'More reps',
    'Better execution',
    'Better control',
  ];

  @override
  Widget build(BuildContext context) {
    final hasHistory = performance?.hasHistory ?? false;

    return PreviousPerformanceShell(
      isLoading: isLoading,
      content: hasHistory
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LAST PERFORMANCE',
                  style: CohortTextStyles.eyebrow,
                ),
                const SizedBox(height: CohortSpacing.sm),
                for (final set in performance!.sets)
                  Padding(
                    padding: const EdgeInsets.only(bottom: CohortSpacing.xs),
                    child: Text(
                      set.displayLine,
                      style: CohortTextStyles.body,
                    ),
                  ),
                if (canOpenFullHistory && onSeeFullHistory != null) ...[
                  const SizedBox(height: CohortSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: onSeeFullHistory,
                      child: Text(
                        'See full history',
                        style: CohortTextStyles.body.copyWith(
                          color: CohortColors.olive,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            )
          : null,
      emptyState: hasHistory
          ? null
          : Text(
              'This is your first recorded performance.',
              style: CohortTextStyles.body,
            ),
      opportunitySection: const TodaysOpportunitySection(
        items: _opportunityItems,
      ),
    );
  }
}

Color _exerciseProgressAccent(ExerciseProgressType progressType) {
  return switch (progressType) {
    ExerciseProgressType.firstPerformance => CohortColors.olive,
    ExerciseProgressType.loadProgress ||
    ExerciseProgressType.repProgress ||
    ExerciseProgressType.volumeProgress ||
    ExerciseProgressType.rpeProgress =>
      CohortColors.success,
    ExerciseProgressType.matchedPerformance => CohortColors.olive,
    ExerciseProgressType.mixedResult => CohortColors.warning,
    ExerciseProgressType.insufficientData => CohortColors.textSecondary,
  };
}

class _StrengthSetRow extends StatefulWidget {
  const _StrengthSetRow({
    required this.set,
    required this.onChanged,
    this.highlighted = false,
    this.onRemove,
  });

  final StrengthSetEntry set;
  final bool highlighted;
  final void Function({
    required String localId,
    String? actualReps,
    String? load,
    bool? completed,
    int? rpe,
    bool clearRpe,
  }) onChanged;
  final VoidCallback? onRemove;

  @override
  State<_StrengthSetRow> createState() => _StrengthSetRowState();
}

class _StrengthSetRowState extends State<_StrengthSetRow> {
  late final TextEditingController _loadController;
  late final TextEditingController _actualRepsController;

  @override
  void initState() {
    super.initState();
    _loadController = TextEditingController(text: widget.set.load ?? '');
    _actualRepsController =
        TextEditingController(text: widget.set.actualReps ?? '');
  }

  @override
  void didUpdateWidget(covariant _StrengthSetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.set.load != oldWidget.set.load &&
        widget.set.load != _loadController.text) {
      _loadController.text = widget.set.load ?? '';
    }
    if (widget.set.actualReps != oldWidget.set.actualReps &&
        widget.set.actualReps != _actualRepsController.text) {
      _actualRepsController.text = widget.set.actualReps ?? '';
    }
  }

  @override
  void dispose() {
    _loadController.dispose();
    _actualRepsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final set = widget.set;
    final label = set.isExtraSet
        ? 'EXTRA SET ${set.setNumber}'
        : 'SET ${set.setNumber}';
    final borderColor = widget.highlighted
        ? CohortColors.olive
        : set.completed
            ? CohortColors.success
            : CohortColors.border;

    return Container(
      padding: const EdgeInsets.all(CohortSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(
          color: borderColor,
          width: widget.highlighted ? 2 : 1,
        ),
        borderRadius: CohortRadius.smallRadius,
        color: widget.highlighted
            ? CohortColors.oliveSoft
            : set.completed
                ? CohortColors.oliveSoft
                : Colors.transparent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: CohortTextStyles.eyebrow.copyWith(
                    color: set.isExtraSet
                        ? CohortColors.warning
                        : CohortColors.textSecondary,
                  ),
                ),
              ),
              if (widget.onRemove != null)
                IconButton(
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.close),
                  color: CohortColors.textSecondary,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          if (set.targetReps != null) ...[
            const SizedBox(height: CohortSpacing.xs),
            Text(
              'Target reps: ${set.targetReps}',
              style: CohortTextStyles.small,
            ),
          ],
          const SizedBox(height: CohortSpacing.md),
          Row(
            children: [
              Expanded(
                child: _StrengthInputField(
                  label: 'Load',
                  controller: _loadController,
                  onChanged: (value) => widget.onChanged(
                    localId: set.localId,
                    load: value,
                  ),
                ),
              ),
              const SizedBox(width: CohortSpacing.md),
              Expanded(
                child: _StrengthInputField(
                  label: 'Actual reps',
                  controller: _actualRepsController,
                  keyboardType: TextInputType.number,
                  onChanged: (value) => widget.onChanged(
                    localId: set.localId,
                    actualReps: value,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: CohortSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => widget.onChanged(
                localId: set.localId,
                completed: !set.completed,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    set.completed ? CohortColors.success : CohortColors.olive,
                side: BorderSide(
                  color: set.completed
                      ? CohortColors.success
                      : CohortColors.borderStrong,
                ),
              ),
              child: Text(
                set.completed ? 'Set complete' : 'Complete set',
                style: CohortTextStyles.small,
              ),
            ),
          ),
          if (set.completed) ...[
            const SizedBox(height: CohortSpacing.md),
            _RpeSelector(
              value: set.rpe,
              onChanged: (value) {
                if (value == null) {
                  widget.onChanged(
                    localId: set.localId,
                    clearRpe: true,
                  );
                  return;
                }

                widget.onChanged(
                  localId: set.localId,
                  rpe: value,
                );
              },
            ),
          ],
        ],
      ),
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
        Text(
          'RPE (optional)',
          style: CohortTextStyles.muted,
        ),
        const SizedBox(height: CohortSpacing.xs),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var rpe = 1; rpe <= 10; rpe++)
                Padding(
                  padding: EdgeInsets.only(
                    right: rpe == 10 ? 0 : CohortSpacing.xs,
                  ),
                  child: _RpeChip(
                    value: rpe,
                    selected: value == rpe,
                    onTap: () => onChanged(value == rpe ? null : rpe),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RpeChip extends StatelessWidget {
  const _RpeChip({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: CohortRadius.smallRadius,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? CohortColors.oliveSoft : Colors.transparent,
          borderRadius: CohortRadius.smallRadius,
          border: Border.all(
            color: selected ? CohortColors.olive : CohortColors.border,
          ),
        ),
        child: Text(
          '$value',
          style: CohortTextStyles.small.copyWith(
            color: selected ? CohortColors.olive : CohortColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _AthleteNoteField extends StatefulWidget {
  const _AthleteNoteField({
    required this.value,
    required this.onChanged,
  });

  final String? value;
  final ValueChanged<String> onChanged;

  @override
  State<_AthleteNoteField> createState() => _AthleteNoteFieldState();
}

class _AthleteNoteFieldState extends State<_AthleteNoteField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
  }

  @override
  void didUpdateWidget(covariant _AthleteNoteField oldWidget) {
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
          'Athlete note (optional)',
          style: CohortTextStyles.muted,
        ),
        const SizedBox(height: CohortSpacing.xs),
        TextField(
          controller: _controller,
          style: CohortTextStyles.body,
          maxLines: 2,
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            hintText: 'How did this exercise feel?',
            hintStyle: CohortTextStyles.small,
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


class _StrengthInputField extends StatelessWidget {
  const _StrengthInputField({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;

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
