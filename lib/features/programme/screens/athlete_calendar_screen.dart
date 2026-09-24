import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_brand_lockup.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../../data/repositories/programme_assignment_store.dart';
import '../services/athlete_programme_context_resolver.dart';
import '../../home/controllers/home_today_session_refresh_controller.dart';
import '../../session/services/programme_session_execution_launcher.dart';
import '../models/fixed_programme_occurrence_projection.dart';
import '../presentation/athlete_calendar_agenda_presentation.dart';
import '../presentation/athlete_calendar_month_presentation.dart';
import '../presentation/athlete_completion_journey_copy.dart';
import '../presentation/athlete_programme_continuity_copy.dart';
import '../presentation/athlete_programme_lifecycle_presentation.dart';
import '../services/athlete_programme_session_prepare_service.dart';
import '../services/fixed_programme_occurrence_projection_store.dart';
import '../services/fixed_programme_occurrence_projection_supabase_store.dart';
import '../models/incomplete_session_recovery.dart';
import '../services/backfill_programme_session_store.dart';
import '../services/future_programme_session_swap_store.dart';
import '../services/incomplete_session_train_today.dart';
import '../services/scheduled_programme_session_preview_service.dart';
import '../widgets/athlete_calendar_month_grid.dart';
import '../widgets/athlete_programme_status_state.dart';
import '../widgets/incomplete_session_recovery_actions.dart';
import 'backfill_programme_session_flow.dart';
import 'scheduled_programme_session_preview_screen.dart';

/// Athlete-wide training calendar. Month grid is the default presentation.
class AthleteCalendarScreen extends StatefulWidget {
  const AthleteCalendarScreen({
    super.key,
    required this.athleteId,
    this.fixedOccurrenceStore,
    this.previewService,
    this.assignmentStore,
    this.prepareService,
    this.executionLauncher,
    this.swapStore,
    this.backfillStore,
    this.refreshController,
    this.onOpenProgrammes,
    this.authRefreshListenable,
  });

  final String athleteId;
  final FixedProgrammeOccurrenceProjectionStore? fixedOccurrenceStore;
  final ScheduledProgrammeSessionPreviewService? previewService;
  final ProgrammeAssignmentStore? assignmentStore;
  final AthleteProgrammeSessionPrepareService? prepareService;
  final ProgrammeSessionExecutionLauncher? executionLauncher;
  final HomeTodaySessionRefreshController? refreshController;
  final FutureProgrammeSessionSwapStore? swapStore;
  final BackfillProgrammeSessionStore? backfillStore;
  final VoidCallback? onOpenProgrammes;
  final Listenable? authRefreshListenable;

  @override
  State<AthleteCalendarScreen> createState() => _AthleteCalendarScreenState();
}

class _AthleteCalendarScreenState extends State<AthleteCalendarScreen> {
  final GlobalKey _selectedDetailKey = GlobalKey();
  FixedProgrammeCalendarProjection? _calendar;
  DateTime? _month;
  DateTime? _selectedDate;
  String? _error;
  _CalendarLoadState _loadState = _CalendarLoadState.loading;

  @override
  void initState() {
    super.initState();
    widget.authRefreshListenable?.addListener(_reloadForAuthentication);
    widget.refreshController?.attachSurface(
      this,
      ({required String source}) => _load(),
    );
    _load();
  }

  @override
  void didUpdateWidget(covariant AthleteCalendarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authRefreshListenable != widget.authRefreshListenable) {
      oldWidget.authRefreshListenable?.removeListener(_reloadForAuthentication);
      widget.authRefreshListenable?.addListener(_reloadForAuthentication);
    }
    if (oldWidget.athleteId != widget.athleteId) {
      unawaited(_load());
    }
    if (oldWidget.refreshController != widget.refreshController) {
      oldWidget.refreshController?.detachSurface(this);
      widget.refreshController?.attachSurface(
        this,
        ({required String source}) => _load(),
      );
    }
  }

  @override
  void dispose() {
    widget.refreshController?.detachSurface(this);
    widget.authRefreshListenable?.removeListener(_reloadForAuthentication);
    super.dispose();
  }

  void _reloadForAuthentication() => unawaited(_load());

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loadState = _CalendarLoadState.loading;
        _error = null;
      });
    }
    try {
      final store =
          widget.fixedOccurrenceStore ??
          const FixedProgrammeOccurrenceProjectionSupabaseStore();
      FixedProgrammeCalendarProjection? calendar;
      final assignments = widget.assignmentStore;
      if (assignments != null) {
        final context = await AthleteProgrammeContextResolver(
          assignments,
        ).resolve(widget.athleteId);
        final assignment = context.assignment;
        if (assignment == null) {
          if (!mounted) return;
          setState(() {
            _calendar = null;
            _loadState = _CalendarLoadState.empty;
            _error = null;
          });
          return;
        }
        calendar = await store
            .resolveForAssignment(assignment.id)
            .timeout(const Duration(seconds: 12));
      } else {
        calendar = await store.resolveActive().timeout(
          const Duration(seconds: 12),
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _calendar = calendar;
        _loadState = calendar == null
            ? _CalendarLoadState.empty
            : _CalendarLoadState.loaded;
        if (calendar != null) {
          final today = DateTime.parse(calendar.today);
          _month ??= AthleteCalendarMonthFormatter.monthStart(today);
          _selectedDate ??= today;
        }
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _calendar = null;
          _loadState = _CalendarLoadState.error;
          _error = AthleteProgrammeContinuityCopy.failureMessage(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final calendar = _calendar;
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: SafeArea(
        child: _loadState == _CalendarLoadState.loading
            ? const Center(child: CircularProgressIndicator())
            : _loadState == _CalendarLoadState.empty
            ? _noAssignmentState()
            : _loadState == _CalendarLoadState.error
            ? _errorState()
            : ListView(
                key: const ValueKey('calendar-month-grid-scroll'),
                padding: const EdgeInsets.all(CohortSpacing.lg),
                children: [
                  const CohortBrandLockup(),
                  const SizedBox(height: CohortSpacing.md),
                  Text(
                    calendar!.programmeName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: CohortTextStyles.h2,
                  ),
                  const SizedBox(height: CohortSpacing.xs),
                  Text(
                    calendar.isInspectionOnly
                        ? AthleteCompletionJourneyCopy.complete
                        : 'Training schedule',
                    style: CohortTextStyles.muted,
                  ),
                  if (calendar.isInspectionOnly) ...[
                    const SizedBox(height: CohortSpacing.sm),
                    Text(
                      AthleteCompletionJourneyCopy.calendarSupporting,
                      style: CohortTextStyles.body,
                    ),
                  ],
                  const SizedBox(height: CohortSpacing.md),
                  _monthControls(calendar),
                  const SizedBox(height: CohortSpacing.md),
                  ..._selectedDetail(calendar),
                  const SizedBox(height: CohortSpacing.lg),
                  AthleteCalendarMonthGrid(
                    cells: AthleteCalendarMonthFormatter.monthCells(
                      calendar: calendar,
                      month: _month!,
                      selectedDate: _selectedDate,
                    ),
                    onSelectDate: _selectDate,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _noAssignmentState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(CohortSpacing.lg),
      child: CohortCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('No programme scheduled', style: CohortTextStyles.h2),
            const SizedBox(height: CohortSpacing.sm),
            Text(
              'Choose a programme to see your training schedule here.',
              style: CohortTextStyles.body,
            ),
            if (widget.onOpenProgrammes != null) ...[
              const SizedBox(height: CohortSpacing.md),
              TextButton(
                onPressed: widget.onOpenProgrammes,
                child: const Text('Programmes'),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _errorState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(CohortSpacing.lg),
      child: AthleteProgrammeStatusState(
        badge: 'Unavailable',
        headline: AthleteProgrammeContinuityCopy.pinnedUnavailableHeadline,
        explanation: AthleteProgrammeContinuityCopy.pinnedUnavailable,
        technical: _error,
        action: TextButton(
          onPressed: _load,
          child: const Text(AthleteProgrammeContinuityCopy.retry),
        ),
      ),
    ),
  );

  Widget _monthControls(FixedProgrammeCalendarProjection calendar) {
    final month = _month!;
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              key: const ValueKey('calendar-month-previous'),
              tooltip: 'Previous month',
              onPressed: () => setState(() {
                _month = AthleteCalendarMonthFormatter.addMonths(month, -1);
              }),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                AthleteProgrammeDateFormatter.monthYear(month),
                textAlign: TextAlign.center,
                style: CohortTextStyles.cardTitle,
              ),
            ),
            IconButton(
              key: const ValueKey('calendar-month-next'),
              tooltip: 'Next month',
              onPressed: () => setState(() {
                _month = AthleteCalendarMonthFormatter.addMonths(month, 1);
              }),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: const ValueKey('calendar-month-current'),
            onPressed: () => setState(() {
              _month = AthleteCalendarMonthFormatter.monthStart(
                DateTime.parse(calendar.today),
              );
              _selectedDate = DateTime.parse(calendar.today);
            }),
            child: const Text('This month'),
          ),
        ),
      ],
    );
  }

  void _selectDate(DateTime date) {
    setState(() => _selectedDate = DateTime(date.year, date.month, date.day));
  }

  List<Widget> _selectedDetail(FixedProgrammeCalendarProjection calendar) {
    final selected = _selectedDate;
    if (selected == null) return const [];
    final iso = AthleteCalendarMonthFormatter.isoDate(selected);
    final occurrences = calendar.occurrencesOnDate(iso);
    if (occurrences.isEmpty) {
      return [
        CohortCard(
          key: _selectedDetailKey,
          child: Text(
            '${AthleteProgrammeDateFormatter.weekdayDayMonth(selected)}\n'
            'No session scheduled',
            style: CohortTextStyles.body,
          ),
        ),
      ];
    }
    return [
      for (final occurrence in occurrences) ...[
        CohortCard(
          key: occurrence.occurrenceId == occurrences.first.occurrenceId
              ? _selectedDetailKey
              : null,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            onTap: () => _openOccurrence(occurrence),
            title: Text(
              occurrence.sessionTitle,
              style: CohortTextStyles.cardTitle,
            ),
            subtitle: Text(
              [
                AthleteCalendarStatusCopy.forOccurrence(occurrence),
                if (occurrence.sessionType?.trim().isNotEmpty == true)
                  occurrence.sessionType!,
              ].join(' · '),
              style: CohortTextStyles.small,
            ),
            trailing: TextButton(
              key: ValueKey(
                'calendar-selected-view-session-${occurrence.occurrenceId}',
              ),
              onPressed: () => _openOccurrence(occurrence),
              child: const Text('View session'),
            ),
          ),
        ),
        if (_canRecover(calendar, occurrence)) ...[
          const SizedBox(height: CohortSpacing.sm),
          IncompleteSessionRecoveryActions(
            scheduledDate: selected,
            onTrainToday: () => _trainToday(occurrence),
            onBackfill: widget.backfillStore?.isSupported == true
                ? () => _backfill(occurrence)
                : null,
            onReschedule: () => _openOccurrence(occurrence),
          ),
        ],
        const SizedBox(height: CohortSpacing.sm),
      ],
    ];
  }

  Future<void> _openOccurrence(
    FixedProgrammeOccurrenceProjection occurrence,
  ) async {
    final calendar = _calendar;
    if (calendar == null) return;
    final changed = await openScheduledProgrammeSessionPreview(
      context: context,
      athleteId: widget.athleteId,
      calendar: calendar,
      day: AthleteProgrammeWeekDayPresentation(
        date: AthleteCalendarMonthFormatter.parseIsoDate(
          occurrence.scheduledDate,
        ),
        state: occurrence.state,
        occurrence: occurrence,
      ),
      previewService: widget.previewService,
      assignmentStore: widget.assignmentStore,
      prepareService: widget.prepareService,
      executionLauncher: widget.executionLauncher,
      swapStore: widget.swapStore,
      backfillStore: widget.backfillStore,
      fixedOccurrenceStore: widget.fixedOccurrenceStore,
      refreshController: widget.refreshController,
    );
    if (changed == true && mounted) await _load();
  }

  bool _canRecover(
    FixedProgrammeCalendarProjection calendar,
    FixedProgrammeOccurrenceProjection occurrence,
  ) {
    if (calendar.isInspectionOnly) return false;
    return IncompleteSessionRecovery.canTrainToday(
      occurrence: occurrence,
      calendar: calendar,
      athleteAssignmentId: calendar.assignmentId,
    );
  }

  Future<void> _trainToday(
    FixedProgrammeOccurrenceProjection occurrence,
  ) async {
    final calendar = _calendar;
    if (calendar == null) return;
    try {
      await IncompleteSessionTrainToday.open(
        context: context,
        athleteId: widget.athleteId,
        calendar: calendar,
        occurrence: occurrence,
        assignmentStore: widget.assignmentStore,
        prepareService: widget.prepareService,
        executionLauncher: widget.executionLauncher,
        refreshController: widget.refreshController,
      );
      if (mounted) await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This session could not be opened. Refresh your calendar and try again.',
          ),
        ),
      );
    }
  }

  Future<void> _backfill(
    FixedProgrammeOccurrenceProjection occurrence,
  ) async {
    final calendar = _calendar;
    final store = widget.backfillStore;
    if (calendar == null || store == null || !store.isSupported) return;
    final saved = await openBackfillProgrammeSessionFlow(
      context: context,
      athleteId: widget.athleteId,
      calendar: calendar,
      occurrence: occurrence,
      backfillStore: store,
      assignmentStore: widget.assignmentStore,
      prepareService: widget.prepareService,
    );
    if (saved == true && mounted) {
      await widget.refreshController?.reloadAuthoritativeSurfaces(
        source: 'backfill_saved',
      );
      if (mounted) await _load();
    }
  }
}

enum _CalendarLoadState { loading, loaded, empty, error }
