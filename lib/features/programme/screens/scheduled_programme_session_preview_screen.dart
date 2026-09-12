import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../../core/widgets/section_title.dart';
import '../../../data/repositories/programme_assignment_store.dart';
import '../../../data/repositories/programme_assignment_supabase_store.dart';
import '../../exercises/exercise_detail/exercise_detail_screen.dart';
import '../../performance/models/training_session_record.dart';
import '../../performance/repositories/performance_record_store.dart';
import '../../performance/repositories/supabase_performance_record_store.dart';
import '../../performance/services/performance_result_summary_formatter.dart';
import '../../performance/widgets/completed_session_result_view.dart';
import '../../home/controllers/home_today_session_refresh_controller.dart';
import '../../session/models/session_execution_plan.dart';
import '../../session/services/programme_session_execution_launcher.dart';
import '../../session/widgets/athlete/athlete_block_card.dart';
import '../../session/widgets/athlete/athlete_session_components.dart';
import '../models/fixed_programme_occurrence_projection.dart';
import '../models/future_programme_session_swap.dart';
import '../presentation/athlete_programme_lifecycle_presentation.dart';
import '../presentation/programme_day_label_formatter.dart';
import '../services/athlete_catalogue_enrolment_services.dart';
import '../services/athlete_programme_session_prepare_service.dart';
import '../services/fixed_programme_occurrence_projection_store.dart';
import '../services/fixed_programme_occurrence_projection_supabase_store.dart';
import '../services/future_programme_session_swap_service.dart';
import '../services/future_programme_session_swap_store.dart';
import '../services/future_programme_session_swap_supabase_store.dart';
import '../services/overdue_programme_recovery_service.dart';
import '../services/overdue_programme_recovery_store.dart';
import '../services/overdue_programme_recovery_supabase_store.dart';
import '../models/overdue_programme_recovery.dart';
import '../services/scheduled_programme_session_preview_service.dart';

Future<bool?> openScheduledProgrammeSessionPreview({
  required BuildContext context,
  required String athleteId,
  required FixedProgrammeCalendarProjection calendar,
  required AthleteProgrammeWeekDayPresentation day,
  ScheduledProgrammeSessionPreviewService? previewService,
  ProgrammeAssignmentStore? assignmentStore,
  AthleteProgrammeSessionPrepareService? prepareService,
  ProgrammeSessionExecutionLauncher? executionLauncher,
  PerformanceRecordStore? performanceRecordStore,
  FutureProgrammeSessionSwapStore? swapStore,
  OverdueProgrammeRecoveryStore? recoveryStore,
  FixedProgrammeOccurrenceProjectionStore? fixedOccurrenceStore,
  HomeTodaySessionRefreshController? refreshController,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => ScheduledProgrammeSessionPreviewScreen(
        athleteId: athleteId,
        calendar: calendar,
        day: day,
        previewService: previewService,
        assignmentStore: assignmentStore,
        prepareService: prepareService,
        executionLauncher: executionLauncher,
        performanceRecordStore: performanceRecordStore,
        swapStore: swapStore,
        recoveryStore: recoveryStore,
        fixedOccurrenceStore: fixedOccurrenceStore,
        refreshController: refreshController,
      ),
    ),
  );
}

class ScheduledProgrammeSessionPreviewScreen extends StatefulWidget {
  const ScheduledProgrammeSessionPreviewScreen({
    super.key,
    required this.athleteId,
    required this.calendar,
    required this.day,
    this.previewService,
    this.assignmentStore,
    this.prepareService,
    this.executionLauncher,
    this.performanceRecordStore,
    this.swapStore,
    this.recoveryStore,
    this.fixedOccurrenceStore,
    this.refreshController,
  });

  final String athleteId;
  final FixedProgrammeCalendarProjection calendar;
  final AthleteProgrammeWeekDayPresentation day;
  final ScheduledProgrammeSessionPreviewService? previewService;
  final ProgrammeAssignmentStore? assignmentStore;
  final AthleteProgrammeSessionPrepareService? prepareService;
  final ProgrammeSessionExecutionLauncher? executionLauncher;
  final PerformanceRecordStore? performanceRecordStore;
  final FutureProgrammeSessionSwapStore? swapStore;
  final OverdueProgrammeRecoveryStore? recoveryStore;
  final FixedProgrammeOccurrenceProjectionStore? fixedOccurrenceStore;
  final HomeTodaySessionRefreshController? refreshController;

  @override
  State<ScheduledProgrammeSessionPreviewScreen> createState() =>
      _ScheduledProgrammeSessionPreviewScreenState();
}

class _ScheduledProgrammeSessionPreviewScreenState
    extends State<ScheduledProgrammeSessionPreviewScreen> {
  late final ScheduledProgrammeSessionPreviewService _previewService =
      widget.previewService ?? ScheduledProgrammeSessionPreviewService();
  late final Future<ScheduledProgrammeSessionPreview> _preview = _previewService
      .load(calendar: widget.calendar, day: widget.day);
  bool _isOpeningSession = false;
  final Map<int, Future<TrainingSessionRecord?>> _completedRecords = {};
  Future<List<TrainingSessionRecord>>? _history;
  bool _resultsCorrected = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_resultsCorrected,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(true);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Session')),
        body: SafeArea(
          child: FutureBuilder<ScheduledProgrammeSessionPreview>(
            future: _preview,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return Padding(
                  padding: const EdgeInsets.all(CohortSpacing.lg),
                  child: AthleteFeedbackState(
                    title: 'Session unavailable',
                    message:
                        'This assigned session could not be loaded safely. Please go back and refresh your calendar.',
                    actionLabel: 'Go back',
                    onAction: () => Navigator.of(context).pop(),
                  ),
                );
              }
              return _buildPreview(snapshot.data!);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(ScheduledProgrammeSessionPreview preview) {
    final trainingSessionId = preview.occurrence?.trainingSessionId;
    if (preview.occurrence?.state == FixedProgrammeOccurrenceState.completed &&
        trainingSessionId != null) {
      final store =
          widget.performanceRecordStore ?? SupabasePerformanceRecordStore();
      _history ??= store.listHistory(athleteId: widget.athleteId);
      return FutureBuilder<List<Object?>>(
        future: Future.wait([
          _completedRecords.putIfAbsent(
            trainingSessionId,
            () => store.getTerminalForTrainingSession(
              athleteId: widget.athleteId,
              trainingSessionId: trainingSessionId,
            ),
          ),
          _history!,
        ]),
        builder: (context, snapshot) {
          final record = snapshot.data?[0] as TrainingSessionRecord?;
          final history =
              (snapshot.data?[1] as List<TrainingSessionRecord>?) ?? const [];
          return _buildSessionContent(
            preview,
            record: record,
            history: history,
          );
        },
      );
    }
    return _buildSessionContent(preview);
  }

  Widget _buildSessionContent(
    ScheduledProgrammeSessionPreview preview, {
    TrainingSessionRecord? record,
    List<TrainingSessionRecord> history = const [],
  }) {
    final occurrence = preview.occurrence;
    if (occurrence?.state == FixedProgrammeOccurrenceState.completed &&
        record != null) {
      return CompletedSessionResultView(
        record: record,
        athleteHistory: history,
        programmePosition: _programmePosition(preview),
        statusMessage: _completedStatusMessage(preview, record: record),
        performanceRecordStore:
            widget.performanceRecordStore ?? SupabasePerformanceRecordStore(),
        onRecordCorrected: (corrected) {
          final trainingSessionId = preview.occurrence?.trainingSessionId;
          setState(() {
            _resultsCorrected = true;
            if (trainingSessionId != null) {
              _completedRecords[trainingSessionId] = Future.value(corrected);
            }
            _history =
                (widget.performanceRecordStore ??
                        SupabasePerformanceRecordStore())
                    .listHistory(athleteId: widget.athleteId);
          });
        },
      );
    }
    final plan = preview.plan;
    return ListView(
      padding: const EdgeInsets.all(CohortSpacing.lg),
      children: [
        Text('SCHEDULED SESSION', style: CohortTextStyles.sectionLabel),
        const SizedBox(height: CohortSpacing.sm),
        Text(preview.calendar.programmeName, style: CohortTextStyles.h2),
        const SizedBox(height: CohortSpacing.xs),
        Text(_programmePosition(preview), style: CohortTextStyles.muted),
        const SizedBox(height: CohortSpacing.lg),
        _statusCard(preview),
        if (!preview.isRest && occurrence != null && plan != null)
          ..._executionAction(preview),
        if (preview.isRest) ...[
          const SizedBox(height: CohortSpacing.xl),
          CohortCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No session scheduled', style: CohortTextStyles.h2),
                const SizedBox(height: CohortSpacing.sm),
                Text(
                  'There is no assigned session for this programme date.',
                  style: CohortTextStyles.body,
                ),
              ],
            ),
          ),
        ] else if (occurrence != null && plan != null) ...[
          const SizedBox(height: CohortSpacing.xl),
          Text(plan.sessionTitle, style: CohortTextStyles.h1),
          if (_sessionFocus(plan) case final focus?) ...[
            const SizedBox(height: CohortSpacing.xs),
            Text(focus, style: CohortTextStyles.body),
          ],
          const SizedBox(height: CohortSpacing.lg),
          _overviewCard(plan),
          const SizedBox(height: CohortSpacing.xl),
          const SectionTitle('Session blocks'),
          const SizedBox(height: CohortSpacing.md),
          for (final block in plan.blocks) ...[
            AthleteBlockCard(
              block: block,
              isExpanded: true,
              isActive: false,
              isComplete: false,
              onToggleExpanded: () {},
              onMarkComplete: () {},
              onReopen: () {},
              onLaunchTimer: null,
              onOpenExercise: _openExercise,
              showActions: false,
              exerciseInfoOpensDetail: true,
              recordedResultSummary: _recordedResultFor(record, block.blockId),
            ),
            const SizedBox(height: CohortSpacing.md),
          ],
        ],
      ],
    );
  }

  String? _recordedResultFor(TrainingSessionRecord? record, String blockId) {
    if (record == null) return null;
    for (final block in record.blockResults) {
      if (block.sourceBlockId == blockId) {
        return PerformanceResultSummaryFormatter.formatBlock(block);
      }
    }
    return null;
  }

  Widget _statusCard(ScheduledProgrammeSessionPreview preview) {
    final occurrence = preview.occurrence;
    final isOverdueContext =
        occurrence != null &&
        (occurrence.isLateStartable ||
            occurrence.state == FixedProgrammeOccurrenceState.missed);
    return CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_statusTitle(preview), style: CohortTextStyles.cardTitle),
          const SizedBox(height: CohortSpacing.xs),
          if (isOverdueContext) ...[
            Text(
              IncompleteSessionAthleteCopy.scheduledForLine(preview.day.date),
              style: CohortTextStyles.body,
            ),
            const SizedBox(height: CohortSpacing.xs),
            Text(
              IncompleteSessionAthleteCopy.stillCompletable,
              style: CohortTextStyles.body,
            ),
          ] else
            Text(_statusMessage(preview), style: CohortTextStyles.body),
        ],
      ),
    );
  }

  Widget _overviewCard(SessionExecutionPlan plan) {
    final protocol = plan.protocol;
    return CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Session overview', style: CohortTextStyles.cardTitle),
          if (_text(protocol?.sessionType) case final type?) ...[
            const SizedBox(height: CohortSpacing.sm),
            Text('Type · $type', style: CohortTextStyles.body),
          ],
          if (_text(protocol?.goal) case final focus?) ...[
            const SizedBox(height: CohortSpacing.xs),
            Text('Focus · $focus', style: CohortTextStyles.body),
          ],
          if (plan.durationMin case final duration?) ...[
            const SizedBox(height: CohortSpacing.xs),
            Text('$duration min estimated', style: CohortTextStyles.body),
          ],
          const SizedBox(height: CohortSpacing.xs),
          Text(
            '${plan.blockCount} block${plan.blockCount == 1 ? '' : 's'}',
            style: CohortTextStyles.small,
          ),
          if (_text(plan.coachNotes) case final notes?) ...[
            const SizedBox(height: CohortSpacing.md),
            Text('Coach notes', style: CohortTextStyles.eyebrow),
            const SizedBox(height: CohortSpacing.xs),
            Text(notes, style: CohortTextStyles.body),
          ],
        ],
      ),
    );
  }

  List<Widget> _executionAction(ScheduledProgrammeSessionPreview preview) {
    final occurrence = preview.occurrence;
    if (occurrence == null) return const [];
    if (occurrence.isResumable) {
      return [
        const SizedBox(height: CohortSpacing.md),
        CohortButton(
          key: const ValueKey('scheduled-preview-resume'),
          label: 'Resume',
          onPressed: _isOpeningSession ? null : () => _execute(preview),
        ),
      ];
    }
    if (occurrence.isToday) {
      return [
        const SizedBox(height: CohortSpacing.md),
        CohortButton(
          key: const ValueKey('scheduled-preview-begin'),
          label: 'Begin',
          onPressed: _isOpeningSession ? null : () => _execute(preview),
        ),
      ];
    }
    if (occurrence.isLateStartable) {
      return [
        const SizedBox(height: CohortSpacing.md),
        CohortButton(
          key: const ValueKey('scheduled-preview-start-late'),
          label: IncompleteSessionAthleteCopy.doThisSession,
          onPressed: _isOpeningSession ? null : () => _execute(preview),
        ),
        const SizedBox(height: CohortSpacing.sm),
        CohortButton(
          key: const ValueKey('scheduled-preview-reschedule'),
          label: 'Reschedule',
          variant: CohortButtonVariant.secondary,
          onPressed: _isOpeningSession ? null : () => _reschedule(preview),
        ),
      ];
    }
    if (occurrence.state == FixedProgrammeOccurrenceState.planned) {
      final canTrainToday = preview.calendar.canOfferFutureTrainTodaySwap(
        occurrence,
      );
      return [
        const SizedBox(height: CohortSpacing.md),
        CohortButton(
          key: const ValueKey('scheduled-preview-available-date'),
          label:
              'Available ${AthleteProgrammeDateFormatter.dayMonth(preview.day.date)}',
          onPressed: null,
        ),
        if (canTrainToday) ...[
          const SizedBox(height: CohortSpacing.sm),
          CohortButton(
            key: const ValueKey('scheduled-preview-train-today'),
            label: 'Train today',
            variant: CohortButtonVariant.secondary,
            onPressed: _isOpeningSession
                ? null
                : () => _confirmTrainToday(preview),
          ),
        ] else if ((preview.calendar.calendarDaysUntil(occurrence) ?? 0) >
            FixedProgrammeCalendarProjection.futureTrainTodayHorizonDays) ...[
          const SizedBox(height: CohortSpacing.sm),
          Text(
            'Train today is available for sessions in the next 7 days.',
            style: CohortTextStyles.muted,
          ),
        ],
      ];
    }
    return const [];
  }

  Future<void> _confirmTrainToday(
    ScheduledProgrammeSessionPreview preview,
  ) async {
    final selected = preview.occurrence;
    final today = preview.calendar.todayOccurrence;
    if (selected == null ||
        today == null ||
        !preview.calendar.canOfferFutureTrainTodaySwap(selected) ||
        _isOpeningSession) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Train this session today?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Changing the authored order may affect training balance and recovery. This is not generally recommended.',
                  style: CohortTextStyles.body,
                ),
                const SizedBox(height: CohortSpacing.md),
                Text(
                  '${selected.sessionTitle} moves from ${AthleteProgrammeDateFormatter.longDate(preview.day.date)} to ${AthleteProgrammeDateFormatter.longDate(_calendarDate(preview.calendar.today))}.',
                  style: CohortTextStyles.body,
                ),
                const SizedBox(height: CohortSpacing.sm),
                Text(
                  '${today.sessionTitle} moves from ${AthleteProgrammeDateFormatter.longDate(_calendarDate(today.scheduledDate))} to ${AthleteProgrammeDateFormatter.longDate(_calendarDate(selected.scheduledDate))}.',
                  style: CohortTextStyles.body,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              key: const ValueKey('swap-and-begin-cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const ValueKey('swap-and-begin'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Swap and begin'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isOpeningSession = true);
    try {
      final assignmentStore =
          widget.assignmentStore ?? const ProgrammeAssignmentSupabaseStore();
      final assignment = await assignmentStore.getById(
        preview.calendar.assignmentId,
      );
      if (assignment == null ||
          !assignment.isActive ||
          !assignment.isFixedSchedule ||
          assignment.athleteId != widget.athleteId ||
          assignment.id != selected.assignmentId) {
        throw StateError('This assigned session is no longer executable.');
      }
      final swapResult = await FutureProgrammeSessionSwapService(
        store:
            widget.swapStore ?? const FutureProgrammeSessionSwapSupabaseStore(),
      ).swapAndBegin(calendar: preview.calendar, selected: selected);
      if (!swapResult.isSuccess) {
        throw StateError(swapResult.athleteVisibleMessage);
      }
      final calendarStore =
          widget.fixedOccurrenceStore ??
          const FixedProgrammeOccurrenceProjectionSupabaseStore();
      final refreshed = await calendarStore.resolveActive();
      FixedProgrammeOccurrenceProjection? moved;
      if (refreshed != null) {
        for (final occurrence in refreshed.occurrences) {
          if (occurrence.occurrenceId == selected.occurrenceId) {
            moved = occurrence;
            break;
          }
        }
      }
      if (moved == null || !moved.isExecutable) {
        throw StateError('swapped_session_not_executable');
      }
      final prepare =
          widget.prepareService ??
          AthleteCatalogueEnrolmentServices.createPrepareService();
      final prepared = await prepare.prepareFixedOccurrence(assignment, moved);
      if (!prepared.isReady) {
        await _reloadAuthoritativeSurfaces(source: 'swap_prepare_failed');
        throw StateError(
          prepared.message ?? 'This session could not be prepared safely.',
        );
      }
      await _reloadAuthoritativeSurfaces(source: 'swap_and_begin');
      if (!mounted) return;
      await (widget.executionLauncher ?? ProgrammeSessionExecutionLauncher())
          .launch(
            context: context,
            athleteId: widget.athleteId,
            prepared: prepared,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      final reason = error is StateError
          ? error.message
          : FutureProgrammeSessionSwapResult.athleteVisibleMessageForCode(null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(reason)));
      setState(() => _isOpeningSession = false);
    }
  }

  Future<void> _execute(ScheduledProgrammeSessionPreview preview) async {
    final occurrence = preview.occurrence;
    if (occurrence == null || !occurrence.isExecutable || _isOpeningSession) {
      return;
    }
    setState(() => _isOpeningSession = true);
    try {
      final assignmentStore =
          widget.assignmentStore ?? const ProgrammeAssignmentSupabaseStore();
      final assignment = await assignmentStore.getById(
        preview.calendar.assignmentId,
      );
      if (assignment == null ||
          !assignment.isActive ||
          !assignment.isFixedSchedule ||
          assignment.athleteId != widget.athleteId ||
          assignment.id != occurrence.assignmentId) {
        throw StateError('This assigned session is no longer executable.');
      }
      final prepare =
          widget.prepareService ??
          AthleteCatalogueEnrolmentServices.createPrepareService();
      final prepared = await prepare.prepareFixedOccurrence(
        assignment,
        occurrence,
      );
      if (!prepared.isReady) {
        throw StateError(
          prepared.message ?? 'This session could not be prepared safely.',
        );
      }
      await _reloadAuthoritativeSurfaces(source: 'preview_begin');
      if (!mounted) return;
      await (widget.executionLauncher ?? ProgrammeSessionExecutionLauncher())
          .launch(
            context: context,
            athleteId: widget.athleteId,
            prepared: prepared,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This session could not be opened. Refresh your calendar and try again.',
          ),
        ),
      );
      setState(() => _isOpeningSession = false);
    }
  }

  HomeTodaySessionRefreshController? get _surfaceRefresh =>
      widget.refreshController ??
      AthleteProgrammeSurfaceRefreshScope.maybeOf(context);

  Future<void> _reloadAuthoritativeSurfaces({required String source}) {
    return _surfaceRefresh?.reloadAuthoritativeSurfaces(source: source) ??
        Future<void>.value();
  }

  Future<void> _openExercise(SessionExecutionExerciseSummary summary) async {
    final exercise = summary.exercise;
    if (exercise == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exercise details are not available.')),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ExerciseDetailScreen(
          exercise: exercise,
          athleteId: widget.athleteId,
        ),
      ),
    );
  }

  String _programmePosition(ScheduledProgrammeSessionPreview preview) {
    final occurrence = preview.occurrence;
    final date = AthleteProgrammeDateFormatter.longDate(preview.day.date);
    if (occurrence == null) return date;
    return 'Week ${occurrence.weekNumber} · '
        '${ProgrammeDayLabelFormatter.format(dayKey: occurrence.dayKey)} · '
        '$date';
  }

  String _statusTitle(ScheduledProgrammeSessionPreview preview) {
    final occurrence = preview.occurrence;
    if (occurrence == null) return 'Rest day';
    final date = AthleteProgrammeDateFormatter.longDate(preview.day.date);
    return switch (occurrence.state) {
      FixedProgrammeOccurrenceState.planned => 'Scheduled for $date',
      FixedProgrammeOccurrenceState.today => 'Today · $date',
      FixedProgrammeOccurrenceState.inProgress => 'In progress',
      FixedProgrammeOccurrenceState.overdue =>
        IncompleteSessionAthleteCopy.statusLabel,
      FixedProgrammeOccurrenceState.inProgressOverdue => 'In progress',
      FixedProgrammeOccurrenceState.completed => 'Completed',
      FixedProgrammeOccurrenceState.skipped => 'Skipped',
      FixedProgrammeOccurrenceState.missed =>
        IncompleteSessionAthleteCopy.statusLabel,
      FixedProgrammeOccurrenceState.rest => 'Rest day',
    };
  }

  String _statusMessage(ScheduledProgrammeSessionPreview preview) {
    final occurrence = preview.occurrence;
    if (occurrence == null) {
      return 'No training session is scheduled for this programme date.';
    }
    return switch (occurrence.state) {
      FixedProgrammeOccurrenceState.planned =>
        'You can preview this session now. Execution unlocks on its scheduled date.',
      FixedProgrammeOccurrenceState.today =>
        'This assigned session is available to begin today.',
      FixedProgrammeOccurrenceState.inProgress =>
        'Resume the training session already linked to this programme date.',
      FixedProgrammeOccurrenceState.overdue => _overdueBanner(preview),
      FixedProgrammeOccurrenceState.inProgressOverdue =>
        IncompleteSessionAthleteCopy.stillCompletable,
      FixedProgrammeOccurrenceState.completed => _completedStatusMessage(
        preview,
      ),
      FixedProgrammeOccurrenceState.skipped =>
        'This session was skipped and is no longer executable.',
      FixedProgrammeOccurrenceState.missed => _overdueBanner(preview),
      FixedProgrammeOccurrenceState.rest =>
        'No training session is scheduled for this programme date.',
    };
  }

  String? _sessionFocus(SessionExecutionPlan plan) {
    final parts = <String>[
      ?_text(plan.protocol?.sessionType),
      ?_text(plan.protocol?.goal),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  String? _text(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String _overdueBanner(ScheduledProgrammeSessionPreview preview) {
    return '${IncompleteSessionAthleteCopy.scheduledForLine(preview.day.date)}\n'
        '${IncompleteSessionAthleteCopy.stillCompletable}';
  }

  String _completedStatusMessage(
    ScheduledProgrammeSessionPreview preview, {
    TrainingSessionRecord? record,
  }) {
    final occurrence = preview.occurrence;
    if (occurrence == null) {
      return 'This assigned session has been completed and cannot be restarted.';
    }
    final original = _calendarDate(occurrence.originalScheduledDate);
    final completedAt = record?.completedAt;
    if (completedAt != null) {
      final completedLocal = DateTime(
        completedAt.year,
        completedAt.month,
        completedAt.day,
      );
      if (original != completedLocal) {
        return IncompleteSessionAthleteCopy.completedLater(
          scheduled: original,
          completed: completedLocal,
        );
      }
    } else if (occurrence.originalScheduledDate.compareTo(
          preview.calendar.today,
        ) <
        0) {
      return IncompleteSessionAthleteCopy.scheduledLine(original);
    }
    return 'This assigned session has been completed and cannot be restarted.';
  }

  Future<void> _reschedule(ScheduledProgrammeSessionPreview preview) async {
    final occurrence = preview.occurrence;
    if (occurrence == null || _isOpeningSession) return;
    final today = _calendarDate(preview.calendar.today);
    final choices = <_RescheduleChoice>[];
    for (var i = 0; i <= 7; i++) {
      final date = today.add(Duration(days: i));
      final iso =
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      if (iso == occurrence.scheduledDate) continue;
      final inHorizon = preview.calendar.isWithinOverdueRescheduleHorizon(iso);
      final inAssignment = preview.calendar.isWithinAssignmentCalendar(iso);
      final occupant = preview.calendar.occurrenceOnDate(iso);
      choices.add(
        _RescheduleChoice(
          date: date,
          isoDate: iso,
          occupant: occupant,
          enabled: inHorizon && inAssignment && occupant?.isResumable != true,
          blockedReason: !inHorizon
              ? 'Outside the next 7 days'
              : !inAssignment
              ? 'Outside this programme'
              : occupant?.state == FixedProgrammeOccurrenceState.completed
              ? 'Completed session already on this date'
              : occupant?.isResumable == true
              ? 'In-progress session already on this date'
              : null,
        ),
      );
    }
    final selected = await showModalBottomSheet<_RescheduleChoice>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(CohortSpacing.lg),
            child: SizedBox(
              height: MediaQuery.sizeOf(sheetContext).height * 0.65,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reschedule', style: CohortTextStyles.h2),
                  const SizedBox(height: CohortSpacing.sm),
                  Text(
                    'Choose a date in the next 7 days.',
                    style: CohortTextStyles.body,
                  ),
                  const SizedBox(height: CohortSpacing.md),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final choice in choices)
                          ListTile(
                            key: ValueKey('reschedule-date-${choice.isoDate}'),
                            enabled:
                                choice.enabled && choice.blockedReason == null,
                            title: Text(
                              choice.isoDate == preview.calendar.today
                                  ? 'Today · ${AthleteProgrammeDateFormatter.weekdayDayMonth(choice.date)}'
                                  : AthleteProgrammeDateFormatter.weekdayDayMonth(
                                      choice.date,
                                    ),
                            ),
                            subtitle: Text(
                              choice.blockedReason ??
                                  (choice.occupant == null
                                      ? 'Empty date'
                                      : choice.occupant!.sessionTitle),
                            ),
                            onTap:
                                choice.enabled && choice.blockedReason == null
                                ? () => Navigator.of(sheetContext).pop(choice)
                                : null,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (selected == null || !mounted) return;
    if (selected.occupant != null &&
        (selected.occupant!.state == FixedProgrammeOccurrenceState.completed ||
            selected.occupant!.isResumable)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            selected.occupant!.isResumable
                ? 'Finish the session already in progress on that date before swapping.'
                : 'A completed session is already on that date and cannot be moved.',
          ),
        ),
      );
      return;
    }
    if (selected.occupant == null) {
      final confirmed = await _confirmMove(preview, selected);
      if (confirmed != true || !mounted) return;
      await _applyRecovery(
        preview,
        OverdueProgrammeRecoveryCommand(
          assignmentId: preview.calendar.assignmentId,
          sourceOccurrenceId: occurrence.occurrenceId,
          operation: OverdueProgrammeRecoveryOperation.move,
          destinationDate: selected.isoDate,
          expectedSourceDate: occurrence.scheduledDate,
          idempotencyKey:
              'move:${occurrence.occurrenceId}:${selected.isoDate}:${DateTime.now().millisecondsSinceEpoch}',
        ),
      );
      return;
    }
    final confirmed = await _confirmSwap(preview, selected);
    if (confirmed != true || !mounted) return;
    await _applyRecovery(
      preview,
      OverdueProgrammeRecoveryCommand(
        assignmentId: preview.calendar.assignmentId,
        sourceOccurrenceId: occurrence.occurrenceId,
        operation: OverdueProgrammeRecoveryOperation.swap,
        destinationDate: selected.isoDate,
        counterpartOccurrenceId: selected.occupant!.occurrenceId,
        expectedSourceDate: occurrence.scheduledDate,
        expectedDestinationDate: selected.isoDate,
        idempotencyKey:
            'swap:${occurrence.occurrenceId}:${selected.occupant!.occurrenceId}:${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
  }

  Future<bool?> _confirmMove(
    ScheduledProgrammeSessionPreview preview,
    _RescheduleChoice destination,
  ) {
    final occurrence = preview.occurrence!;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Move this session?'),
          content: Text(
            'Move ${occurrence.sessionTitle} from '
            '${AthleteProgrammeDateFormatter.shortWeekday(preview.day.date)} '
            '${AthleteProgrammeDateFormatter.shortDayMonth(preview.day.date)} to '
            '${AthleteProgrammeDateFormatter.shortWeekday(destination.date)} '
            '${AthleteProgrammeDateFormatter.shortDayMonth(destination.date)}?',
            style: CohortTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Back'),
            ),
            TextButton(
              key: const ValueKey('move-session-confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                destination.isoDate == preview.calendar.today
                    ? 'Move to today'
                    : 'Move session',
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _confirmSwap(
    ScheduledProgrammeSessionPreview preview,
    _RescheduleChoice destination,
  ) {
    final occurrence = preview.occurrence!;
    final other = destination.occupant!;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Swap these sessions?'),
          content: Text(
            'Swap:\n'
            '${AthleteProgrammeDateFormatter.shortWeekday(preview.day.date)} — ${occurrence.sessionTitle}\n'
            '${AthleteProgrammeDateFormatter.shortWeekday(destination.date)} — ${other.sessionTitle}?',
            style: CohortTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Back'),
            ),
            TextButton(
              key: const ValueKey('swap-session-confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Swap sessions'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _applyRecovery(
    ScheduledProgrammeSessionPreview preview,
    OverdueProgrammeRecoveryCommand command,
  ) async {
    setState(() => _isOpeningSession = true);
    try {
      final result = await OverdueProgrammeRecoveryService(
        store:
            widget.recoveryStore ??
            const OverdueProgrammeRecoverySupabaseStore(),
      ).recover(command);
      if (!result.isSuccess) {
        throw StateError(result.athleteVisibleMessage);
      }
      await _reloadAuthoritativeSurfaces(source: 'overdue_recovery');
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is StateError
                ? error.message
                : OverdueProgrammeRecoveryResult.athleteVisibleMessageForCode(
                    null,
                  ),
          ),
        ),
      );
      setState(() => _isOpeningSession = false);
    }
  }

  DateTime _calendarDate(String isoDate) {
    final parts = isoDate.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }
}

class _RescheduleChoice {
  const _RescheduleChoice({
    required this.date,
    required this.isoDate,
    required this.enabled,
    this.occupant,
    this.blockedReason,
  });

  final DateTime date;
  final String isoDate;
  final FixedProgrammeOccurrenceProjection? occupant;
  final bool enabled;
  final String? blockedReason;
}
