import 'package:flutter/material.dart';

import '../../core/theme/cohort_lighting.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/text_styles.dart';
import '../../core/widgets/cohort_card.dart';
import '../../data/repositories/programme_assignment_store.dart';
import '../../data/repositories/programme_assignment_supabase_store.dart';
import '../../models/programme_assignment.dart';
import '../auth/controllers/auth_controller.dart';
import '../auth/services/current_user_session.dart';
import '../athlete_profile/services/athlete_profile_session.dart';
import '../athlete_profile/widgets/athlete_generated_today_section.dart';
import '../programme/models/fixed_programme_occurrence_projection.dart';
import '../programme/presentation/athlete_programme_lifecycle_presentation.dart';
import '../programme/screens/athlete_programme_schedule_screen.dart';
import 'presentation/athlete_home_today_presentation.dart';
import 'widgets/athlete_home_completed_today_card.dart';
import '../programme/screens/athlete_programme_screen.dart';
import '../programme/screens/scheduled_programme_session_preview_screen.dart';
import '../programme/services/athlete_catalogue_enrolment_services.dart';
import '../programme/services/athlete_programme_session_prepare_service.dart';
import '../programme/services/fixed_programme_occurrence_projection_store.dart';
import '../programme/services/fixed_programme_occurrence_projection_supabase_store.dart';
import '../programme/services/future_programme_session_swap_store.dart';
import '../programme/services/scheduled_programme_session_preview_service.dart';
import '../performance/models/training_session_record.dart';
import '../performance/repositories/performance_record_store.dart';
import '../performance/repositories/supabase_performance_record_store.dart';
import '../session/services/programme_session_execution_launcher.dart';
import 'controllers/home_today_session_refresh_controller.dart';
import 'services/athlete_home_runtime_authority.dart';
import 'widgets/athlete_programme_today_section.dart';

/// Athlete Home — entirely focused on today.
///
/// Runtime authority is classified by
/// [AthleteHomeRuntimeAuthorityResolver] (Phase 2.4 / 2.8). Programme Athlete
/// runtime is canonical. Plan Library / Coach Brain Home entry is retired —
/// legacy `hasActivePlan` does not select Home runtime.
/// Navigation lives in [AthleteAppShell].
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.authController,
    this.embeddedInShell = false,
    this.refreshController,
    this.assignmentStore,
    this.prepareService,
    this.athleteIdOverride,
    this.runtimeAuthorityResolver = const AthleteHomeRuntimeAuthorityResolver(),
    this.fixedOccurrenceStore,
    this.executionLauncher,
    this.previewService,
    this.performanceRecordStore,
    this.swapStore,
    this.onOpenCalendar,
  });

  final AuthController? authController;

  /// When true, bottom nav is owned by the shell (do not render here).
  final bool embeddedInShell;

  /// Optional today refresh after catalogue enrolment / Start Programme.
  final HomeTodaySessionRefreshController? refreshController;

  /// Optional assignment store (tests / local wiring). Defaults to Supabase.
  final ProgrammeAssignmentStore? assignmentStore;

  /// Optional prepare service for programme-backed today card.
  final AthleteProgrammeSessionPrepareService? prepareService;

  /// Optional athlete id (staging/tests). Defaults to session profile.
  final String? athleteIdOverride;

  /// Canonical Home runtime-authority decision (injectable for tests).
  final AthleteHomeRuntimeAuthorityResolver runtimeAuthorityResolver;
  final FixedProgrammeOccurrenceProjectionStore? fixedOccurrenceStore;
  final ProgrammeSessionExecutionLauncher? executionLauncher;
  final ScheduledProgrammeSessionPreviewService? previewService;
  final PerformanceRecordStore? performanceRecordStore;
  final FutureProgrammeSessionSwapStore? swapStore;
  final VoidCallback? onOpenCalendar;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final HomeTodaySessionRefreshController _refreshController =
      widget.refreshController ?? HomeTodaySessionRefreshController();

  /// `null` = loading/unknown; `true`/`false` = resolved materialisation.
  bool? _hasMaterialisedProgramme;
  bool _programmeEvidenceUnavailable = false;
  FixedProgrammeCalendarProjection? _calendar;
  ProgrammeAssignment? _assignment;
  String? _calendarError;
  final Map<String, TrainingSessionRecord> _completedTodayRecords = {};
  String? _expandedCompletedOccurrenceId;
  List<TrainingSessionRecord> _completedHistory = const [];
  bool _completedHistoryLoading = false;

  String get _athleteId {
    final override = widget.athleteIdOverride?.trim();
    if (override != null && override.isNotEmpty) return override;
    return AthleteProfileSession.profile?.athleteId ??
        CurrentUserSession.maybeInstance?.athleteId ??
        'athlete.local';
  }

  String get _displayName =>
      AthleteProfileSession.profile?.displayName ??
      CurrentUserSession.maybeInstance?.profile.displayName ??
      'Athlete';

  ProgrammeAssignmentStore get _assignmentStore =>
      widget.assignmentStore ?? const ProgrammeAssignmentSupabaseStore();

  AthleteProgrammeSessionPrepareService get _prepareService =>
      widget.prepareService ??
      AthleteCatalogueEnrolmentServices.createPrepareService();

  AthleteHomeRuntimeAuthority get _runtimeAuthority {
    return widget.runtimeAuthorityResolver.resolve(
      materialisedProgramme: _hasMaterialisedProgramme,
      programmeEvidenceUnavailable: _programmeEvidenceUnavailable,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshController.attachSurface(
      this,
      ({required String source}) => _refreshMaterialisedGate(),
    );
    _refreshMaterialisedGate();
  }

  @override
  void dispose() {
    _refreshController.detachSurface(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshMaterialisedGate();
    }
  }

  Future<void> _refreshMaterialisedGate() async {
    try {
      final assignment = await _assignmentStore.getActiveAssignment(_athleteId);
      if (!mounted) return;
      setState(() {
        _programmeEvidenceUnavailable = false;
        _hasMaterialisedProgramme = assignment?.isMaterialised ?? false;
        _assignment = assignment;
        _calendar = null;
        _calendarError = null;
        _completedTodayRecords.clear();
        _expandedCompletedOccurrenceId = null;
        _completedHistory = const [];
        _completedHistoryLoading = false;
      });
      if (assignment?.isFixedSchedule == true) {
        final calendar =
            await (widget.fixedOccurrenceStore ??
                    const FixedProgrammeOccurrenceProjectionSupabaseStore())
                .resolveActive();
        if (calendar == null || calendar.assignmentId != assignment!.id) {
          throw StateError(
            'Fixed schedule projection is incomplete for this assignment.',
          );
        }
        final homeCalendar = calendar.forHomeToday();
        if (mounted) {
          setState(() => _calendar = homeCalendar);
        }
        await _loadCompletedTodayRecords(homeCalendar);
      }
    } catch (error) {
      if (!mounted) return;
      // Fail closed: do not invent programme runtime from bad evidence.
      setState(() {
        _programmeEvidenceUnavailable = true;
        _hasMaterialisedProgramme = null;
        _calendarError = error.toString();
      });
    }
  }

  /// Sprint 1.3/1.4 programme catalogue + Start Programme entry.
  Future<void> _openProgrammeCatalogue() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AthleteProgrammeScreen(
          athleteId: _athleteId,
          refreshController: _refreshController,
        ),
      ),
    );
    if (!mounted) return;
    await _refreshMaterialisedGate();
    if (changed == true || (_hasMaterialisedProgramme ?? false)) {
      _refreshController.requestRefresh(source: 'athlete_programme_return');
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final authority = _runtimeAuthority;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bottomPad = widget.embeddedInShell ? 24.0 : 24.0 + 72.0 + bottomInset;

    return Scaffold(
      backgroundColor: CohortColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HomeBrandHeader(displayName: _displayName),
              const SizedBox(height: CohortSpacing.lg),
              ..._todayForAuthority(authority),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _todayForAuthority(AthleteHomeRuntimeAuthority authority) {
    switch (authority) {
      case AthleteHomeRuntimeAuthority.programme:
        final assignment = _assignment;
        if (assignment?.isFixedSchedule == true) {
          return _fixedProgrammeHome(assignment!);
        }
        return [
          AthleteProgrammeTodaySection(
            athleteId: _athleteId,
            refreshController: _refreshController,
            prepareService: _prepareService,
          ),
        ];
      case AthleteHomeRuntimeAuthority.loading:
        return const [
          Text('TODAY', style: CohortTextStyles.sectionLabel),
          SizedBox(height: CohortSpacing.md),
          Text('Checking programme…', style: CohortTextStyles.muted),
        ];
      case AthleteHomeRuntimeAuthority.unavailable:
        return [
          const Text('TODAY', style: CohortTextStyles.sectionLabel),
          const SizedBox(height: CohortSpacing.md),
          const Text(
            'Unable to confirm programme.',
            style: CohortTextStyles.muted,
          ),
          const SizedBox(height: CohortSpacing.sm),
          TextButton(
            onPressed: _openProgrammeCatalogue,
            child: const Text('VIEW PROGRAMMES'),
          ),
        ];
      case AthleteHomeRuntimeAuthority.none:
        return [ChoosePlanEntryCard(onChoosePlan: _openProgrammeCatalogue)];
    }
  }

  List<Widget> _fixedProgrammeHome(ProgrammeAssignment assignment) {
    final calendar = _calendar;
    if (calendar == null) {
      return [
        const Text('TODAY', style: CohortTextStyles.sectionLabel),
        const SizedBox(height: CohortSpacing.md),
        CohortCard(
          child: Text(
            _calendarError ?? 'Loading today\'s session…',
            style: CohortTextStyles.body,
          ),
        ),
      ];
    }

    final lifecycle = AthleteProgrammeLifecycleFormatter.fromFixedProjection(
      calendar,
    );
    final todayDate = DateTime.parse(calendar.today);
    final dateLabel = AthleteHomeTodayFormatter.fullDate(todayDate);

    if (lifecycle.isUpcoming) {
      return [
        const Text('TODAY', style: CohortTextStyles.sectionLabel),
        const SizedBox(height: CohortSpacing.xs),
        Text(dateLabel, style: CohortTextStyles.muted),
        const SizedBox(height: CohortSpacing.md),
        CohortCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lifecycle.programmeName, style: CohortTextStyles.h2),
              const SizedBox(height: CohortSpacing.sm),
              Text(
                'Starts ${lifecycle.startDateLabel}',
                style: CohortTextStyles.body,
              ),
              const SizedBox(height: CohortSpacing.xs),
              Text(lifecycle.supportingLine, style: CohortTextStyles.muted),
            ],
          ),
        ),
      ];
    }

    if (calendar.isRestToday) {
      final nextHint = AthleteHomeTodayFormatter.nextSessionHint(calendar);
      return [
        const Text('TODAY', style: CohortTextStyles.sectionLabel),
        const SizedBox(height: CohortSpacing.xs),
        Text(dateLabel, style: CohortTextStyles.muted),
        const SizedBox(height: CohortSpacing.md),
        CohortCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lifecycle.programmeName, style: CohortTextStyles.small),
              const SizedBox(height: CohortSpacing.sm),
              const Text('Rest day', style: CohortTextStyles.h2),
              const SizedBox(height: CohortSpacing.sm),
              const Text(
                'No training session is scheduled for this programme date.',
                style: CohortTextStyles.body,
              ),
              if (nextHint != null) ...[
                const SizedBox(height: CohortSpacing.md),
                TextButton(
                  onPressed: widget.onOpenCalendar ?? _openProgrammeCalendar,
                  child: Text(nextHint),
                ),
              ],
            ],
          ),
        ),
      ];
    }

    final todaySessions = AthleteHomeTodayFormatter.prioritizedTodaySessions(
      calendar,
    );
    final widgets = <Widget>[];
    for (var index = 0; index < todaySessions.length; index++) {
      if (index > 0) {
        widgets.add(const SizedBox(height: CohortSpacing.lg));
      }
      final occurrence = todaySessions[index];
      if (occurrence.state == FixedProgrammeOccurrenceState.completed) {
        widgets.add(_completedTodayCard(calendar, occurrence));
      } else {
        widgets.add(
          AthleteProgrammeTodaySection(
            key: ValueKey(occurrence.occurrenceId),
            athleteId: _athleteId,
            refreshController: index == 0 ? _refreshController : null,
            prepareService: _prepareService,
            executionLauncher: widget.executionLauncher,
            fixedAssignment: assignment,
            fixedOccurrence: occurrence,
            dateLabel: dateLabel,
            onExecutionReturned: _refreshMaterialisedGate,
            onViewFullSession: () => _openOccurrence(occurrence),
          ),
        );
      }
    }
    return widgets;
  }

  Widget _completedTodayCard(
    FixedProgrammeCalendarProjection calendar,
    FixedProgrammeOccurrenceProjection occurrence,
  ) {
    final lifecycle = AthleteProgrammeLifecycleFormatter.fromFixedProjection(
      calendar,
    );
    return AthleteHomeCompletedTodayCard(
      occurrence: occurrence,
      dateLabel: AthleteHomeTodayFormatter.fullDate(DateTime.parse(calendar.today)),
      programmeName: lifecycle.programmeName,
      weekDayLabel: AthleteHomeTodayFormatter.weekDayLabel(
        weekNumber: occurrence.weekNumber,
        dayKey: occurrence.dayKey,
      ),
      record: _completedTodayRecords[occurrence.occurrenceId],
      history: _expandedCompletedOccurrenceId == occurrence.occurrenceId
          ? _completedHistory
          : const [],
      historyLoading:
          _completedHistoryLoading &&
          _expandedCompletedOccurrenceId == occurrence.occurrenceId,
      expanded: _expandedCompletedOccurrenceId == occurrence.occurrenceId,
      onToggleExpanded: () => _toggleCompletedResults(occurrence),
      onViewResults: () => _openOccurrence(occurrence),
    );
  }

  Future<void> _loadCompletedTodayRecords(
    FixedProgrammeCalendarProjection calendar,
  ) async {
    final store =
        widget.performanceRecordStore ?? SupabasePerformanceRecordStore();
    final records = <String, TrainingSessionRecord>{};
    for (final occurrence in calendar.todaySessions) {
      if (occurrence.state != FixedProgrammeOccurrenceState.completed) {
        continue;
      }
      final trainingSessionId = occurrence.trainingSessionId;
      if (trainingSessionId == null) continue;
      try {
        final record = await store.getTerminalForTrainingSession(
          athleteId: _athleteId,
          trainingSessionId: trainingSessionId,
        );
        if (record != null) {
          records[occurrence.occurrenceId] = record;
        }
      } catch (_) {
        // Today's completed occurrence remains visible without its summary.
      }
    }
    if (!mounted) return;
    setState(() {
      _completedTodayRecords
        ..clear()
        ..addAll(records);
    });
  }

  Future<void> _toggleCompletedResults(
    FixedProgrammeOccurrenceProjection occurrence,
  ) async {
    if (_expandedCompletedOccurrenceId == occurrence.occurrenceId) {
      setState(() {
        _expandedCompletedOccurrenceId = null;
        _completedHistory = const [];
        _completedHistoryLoading = false;
      });
      return;
    }
    setState(() {
      _expandedCompletedOccurrenceId = occurrence.occurrenceId;
      _completedHistoryLoading = true;
      _completedHistory = const [];
    });
    try {
      final history =
          await (widget.performanceRecordStore ??
                  SupabasePerformanceRecordStore())
              .listHistory(athleteId: _athleteId, limit: 12);
      if (!mounted) return;
      setState(() {
        _completedHistory = history;
        _completedHistoryLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _completedHistory = const [];
        _completedHistoryLoading = false;
      });
    }
  }

  Future<void> _openOccurrence(FixedProgrammeOccurrenceProjection occurrence) {
    return _openScheduledDay(
      AthleteProgrammeWeekDayPresentation(
        date: DateTime.parse(occurrence.scheduledDate),
        state: occurrence.state,
        occurrence: occurrence,
      ),
    );
  }

  Future<void> _openProgrammeCalendar() async {
    final shellCalendar = widget.onOpenCalendar;
    if (shellCalendar != null) {
      shellCalendar();
      return;
    }
    final assignment = _assignment;
    if (assignment == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AthleteProgrammeScheduleScreen(
          athleteId: _athleteId,
          assignmentId: assignment.id,
          fixedOccurrenceStore: widget.fixedOccurrenceStore,
          assignmentStore: widget.assignmentStore,
          prepareService: widget.prepareService,
          executionLauncher: widget.executionLauncher,
          previewService: widget.previewService,
          swapStore: widget.swapStore,
        ),
      ),
    );
    if (mounted) await _refreshMaterialisedGate();
  }

  Future<void> _openScheduledDay(
    AthleteProgrammeWeekDayPresentation day,
  ) async {
    final calendar = _calendar;
    if (calendar == null || day.occurrence == null) return;
    final changed = await openScheduledProgrammeSessionPreview(
      context: context,
      athleteId: _athleteId,
      calendar: calendar,
      day: day,
      previewService: widget.previewService,
      assignmentStore: widget.assignmentStore,
      prepareService: widget.prepareService,
      executionLauncher: widget.executionLauncher,
      performanceRecordStore: widget.performanceRecordStore,
      swapStore: widget.swapStore,
      fixedOccurrenceStore: widget.fixedOccurrenceStore,
      refreshController: _refreshController,
    );
    if (changed == true && mounted) await _refreshMaterialisedGate();
  }
}

class _HomeBrandHeader extends StatelessWidget {
  const _HomeBrandHeader({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: CohortColors.oliveSoft,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: CohortColors.edgeHighlight.withValues(alpha: 0.28),
            ),
            boxShadow: CohortLighting.emissive(opacity: 0.06, blurRadius: 10),
          ),
          child: Icon(
            Icons.hexagon_outlined,
            color: CohortColors.phosphor,
            size: 22,
            shadows: [
              Shadow(
                color: CohortColors.phosphor.withValues(alpha: 0.4),
                blurRadius: 5,
              ),
            ],
          ),
        ),
        const SizedBox(width: CohortSpacing.md),
        Text(
          'COHORT',
          style: CohortTextStyles.h2.copyWith(letterSpacing: 2, fontSize: 18),
        ),
        const Spacer(),
        Text(
          displayName.split(' ').first,
          style: CohortTextStyles.statusActive.copyWith(
            color: CohortColors.phosphor,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}
