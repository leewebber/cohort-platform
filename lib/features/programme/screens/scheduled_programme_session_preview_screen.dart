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
        statusMessage: _statusMessage(preview),
        performanceRecordStore:
            widget.performanceRecordStore ?? SupabasePerformanceRecordStore(),
        onRecordCorrected: (corrected) {
          final trainingSessionId = preview.occurrence?.trainingSessionId;
          setState(() {
            _resultsCorrected = true;
            if (trainingSessionId != null) {
              _completedRecords[trainingSessionId] = Future.value(corrected);
            }
            _history = (widget.performanceRecordStore ??
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
          ..._executionAction(preview),
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
    return CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_statusTitle(preview), style: CohortTextStyles.cardTitle),
          const SizedBox(height: CohortSpacing.xs),
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
    if (occurrence.isToday || occurrence.isResumable) {
      return [
        const SizedBox(height: CohortSpacing.md),
        CohortButton(
          key: ValueKey(
            'scheduled-preview-${occurrence.isResumable ? 'resume' : 'begin'}',
          ),
          label: occurrence.isResumable ? 'Resume' : 'Begin',
          onPressed: _isOpeningSession ? null : () => _execute(preview),
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
      final swapResult =
          await FutureProgrammeSessionSwapService(
            store:
                widget.swapStore ??
                const FutureProgrammeSessionSwapSupabaseStore(),
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
      if (moved == null || (!moved.isToday && !moved.isResumable)) {
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
          : FutureProgrammeSessionSwapResult.athleteVisibleMessageForCode(
              null,
            );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(reason)));
      setState(() => _isOpeningSession = false);
    }
  }

  Future<void> _execute(ScheduledProgrammeSessionPreview preview) async {
    final occurrence = preview.occurrence;
    if (occurrence == null ||
        (!occurrence.isToday && !occurrence.isResumable) ||
        _isOpeningSession) {
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
      FixedProgrammeOccurrenceState.inProgressOverdue =>
        'In progress · overdue',
      FixedProgrammeOccurrenceState.completed => 'Completed',
      FixedProgrammeOccurrenceState.missed => 'Missed',
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
      FixedProgrammeOccurrenceState.inProgressOverdue =>
        'This earlier session remains resumable without changing today’s programme session.',
      FixedProgrammeOccurrenceState.completed =>
        'This assigned session has been completed and cannot be restarted.',
      FixedProgrammeOccurrenceState.missed =>
        'This session was not started on its scheduled date and cannot be started late.',
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

  DateTime _calendarDate(String isoDate) {
    final parts = isoDate.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }
}
