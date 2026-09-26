import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/text_styles.dart';
import '../../core/widgets/cohort_card.dart';
import '../app_shell/presentation/athlete_time_aware_greeting.dart';
import '../app_shell/widgets/athlete_shell_header.dart';
import '../../data/repositories/programme_assignment_store.dart';
import '../../data/repositories/programme_assignment_supabase_store.dart';
import '../../models/programme_assignment.dart';
import '../auth/controllers/auth_controller.dart';
import '../auth/services/athlete_surface_identity.dart';
import '../auth/widgets/athlete_identity_access_state.dart';
import '../programme/presentation/athlete_completion_journey_copy.dart';
import '../auth/services/current_user_session.dart';
import '../athlete_profile/services/athlete_profile_session.dart';
import '../../core/services/authenticated_identity.dart';
import '../performance/screens/training_history_screen.dart';
import '../programme/services/athlete_programme_context_resolver.dart';
import 'widgets/athlete_home_completed_programme_card.dart';
import '../athlete_profile/widgets/athlete_generated_today_section.dart';
import '../programme/models/fixed_programme_occurrence_projection.dart';
import '../programme/presentation/athlete_programme_lifecycle_presentation.dart';
import '../programme/screens/athlete_programme_schedule_screen.dart';
import 'presentation/athlete_home_today_presentation.dart';
import 'widgets/athlete_home_completed_today_card.dart';
import 'widgets/athlete_home_same_day_sessions_section.dart';
import '../programme/presentation/athlete_programme_continuity_copy.dart';
import '../programme/widgets/athlete_programme_status_state.dart';
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
import 'widgets/athlete_home_rest_day_card.dart';
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
    this.scrollController,
    this.greetingNowUtc,
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
  final ScrollController? scrollController;

  /// Test seam for time-aware greeting. Defaults to UTC now.
  final DateTime Function()? greetingNowUtc;

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

  String? _resolvedAthleteId;

  String get _athleteId => _resolvedAthleteId ?? '';

  String? _requireAthleteId() {
    try {
      return AthleteSurfaceIdentity.require(
        override: widget.athleteIdOverride,
      );
    } on AuthenticatedIdentityException {
      return null;
    }
  }

  String? get _greetingDisplayName =>
      AthleteProfileSession.profile?.displayName ??
      CurrentUserSession.maybeInstance?.profile.displayName;

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
    final athleteId = _requireAthleteId();
    if (athleteId == null) {
      if (!mounted) return;
      setState(() {
        _resolvedAthleteId = null;
        _programmeEvidenceUnavailable = true;
        _hasMaterialisedProgramme = null;
        _assignment = null;
        _calendar = null;
        _calendarError = AthleteCompletionJourneyCopy.missingAthleteHeadline;
      });
      return;
    }
    try {
      final context = await AthleteProgrammeContextResolver(
        _assignmentStore,
      ).resolve(athleteId);
      if (!mounted) return;
      final assignment = context.assignment;
      setState(() {
        _resolvedAthleteId = athleteId;
        _programmeEvidenceUnavailable = false;
        _hasMaterialisedProgramme = context.isNone
            ? false
            : assignment?.isMaterialised ?? false;
        _assignment = assignment;
        _calendar = null;
        _calendarError = null;
        _completedTodayRecords.clear();
      });
      if (assignment?.isFixedSchedule == true) {
        final store =
            widget.fixedOccurrenceStore ??
            const FixedProgrammeOccurrenceProjectionSupabaseStore();
        final calendar = context.isCompleted
            ? await store.resolveForAssignment(assignment!.id)
            : await store.resolveActive();
        if (calendar == null || calendar.assignmentId != assignment!.id) {
          throw StateError(
            'Fixed schedule projection is incomplete for this assignment.',
          );
        }
        final homeCalendar = context.isCompleted
            ? calendar
            : calendar.forHomeToday();
        if (mounted) {
          setState(() => _calendar = homeCalendar);
        }
        if (context.isActive) {
          await _loadCompletedTodayRecords(homeCalendar);
        }
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _programmeEvidenceUnavailable = true;
        _hasMaterialisedProgramme = null;
        _calendarError = AthleteProgrammeContinuityCopy.failureMessage(error);
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

    final greeting = AthleteTimeAwareGreeting.format(
      localNow: AthleteIanaClock.nowInZone(
        _assignment?.timezone ?? _calendar?.timezone,
        utcNow: widget.greetingNowUtc?.call(),
      ),
      displayName: _greetingDisplayName,
    );

    return Scaffold(
      backgroundColor: CohortColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          controller: widget.scrollController,
          padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AthleteShellHeader(greeting: greeting),
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
        if (_requireAthleteId() == null) {
          return const [AthleteIdentityAccessState.missingProfile()];
        }
        return [
          const Text('TODAY', style: CohortTextStyles.sectionLabel),
          const SizedBox(height: CohortSpacing.md),
          AthleteProgrammeStatusState(
            badge: 'Unavailable',
            headline: AthleteProgrammeContinuityCopy.pinnedUnavailableHeadline,
            explanation: AthleteProgrammeContinuityCopy.pinnedUnavailable,
            action: TextButton(
              onPressed: _openProgrammeCatalogue,
              child: const Text('VIEW PROGRAMMES'),
            ),
          ),
        ];
      case AthleteHomeRuntimeAuthority.none:
        return [ChoosePlanEntryCard(onChoosePlan: _openProgrammeCatalogue)];
    }
  }

  List<Widget> _fixedProgrammeHome(ProgrammeAssignment assignment) {
    if (!assignment.isActive) {
      final title =
          _calendar?.programmeName.trim().isNotEmpty == true
          ? _calendar!.programmeName
          : assignment.lineageCode;
      return [
        AthleteHomeCompletedProgrammeCard(
          programmeTitle: title,
          supportingLine:
              'This programme is complete. Your results stay in History.',
          onViewResults: _openHistory,
          onBrowseProgrammes: _openProgrammeCatalogue,
        ),
      ];
    }
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
        AthleteHomeRestDayCard(
          programmeName: lifecycle.programmeName,
          dateLabel: dateLabel,
          guidance: null,
          nextSessionHint: nextHint,
          onOpenCalendar: widget.onOpenCalendar ?? _openProgrammeCalendar,
        ),
      ];
    }

    final todaySessions = AthleteHomeTodayFormatter.authoredTodaySessions(
      calendar,
    );
    final grouped = todaySessions.length > 1;
    final cards = <Widget>[
      for (final occurrence in todaySessions)
        if (occurrence.state == FixedProgrammeOccurrenceState.completed)
          _completedTodayCard(calendar, occurrence, grouped: grouped)
        else
          AthleteProgrammeTodaySection(
            key: ValueKey(occurrence.occurrenceId),
            athleteId: _athleteId,
            refreshController: _refreshController,
            prepareService: _prepareService,
            executionLauncher: widget.executionLauncher,
            fixedAssignment: assignment,
            fixedOccurrence: occurrence,
            dateLabel: dateLabel,
            grouped: grouped,
            onExecutionReturned: _refreshMaterialisedGate,
            onViewFullSession: () => _openOccurrence(occurrence),
          ),
    ];
    if (!grouped) {
      return [
        ...cards,
        ?_nextDateHint(calendar),
      ];
    }
    return [
      AthleteHomeSameDaySessionsSection(
        dateLabel: dateLabel,
        sessionCount: todaySessions.length,
        children: cards,
      ),
      ?_nextDateHint(calendar),
    ];
  }

  Widget? _nextDateHint(FixedProgrammeCalendarProjection calendar) {
    if (calendar.isRestToday) return null;
    final hint = AthleteHomeTodayFormatter.nextSessionHint(calendar);
    if (hint == null) return null;
    return Padding(
      padding: const EdgeInsets.only(top: CohortSpacing.md),
      child: Text(hint, style: CohortTextStyles.muted),
    );
  }

  Widget _completedTodayCard(
    FixedProgrammeCalendarProjection calendar,
    FixedProgrammeOccurrenceProjection occurrence, {
    bool grouped = false,
  }) {
    final lifecycle = AthleteProgrammeLifecycleFormatter.fromFixedProjection(
      calendar,
    );
    return AthleteHomeCompletedTodayCard(
      occurrence: occurrence,
      grouped: grouped,
      dateLabel: AthleteHomeTodayFormatter.fullDate(DateTime.parse(calendar.today)),
      programmeName: lifecycle.programmeName,
      weekDayLabel: AthleteHomeTodayFormatter.weekDayLabel(
        weekNumber: occurrence.weekNumber,
        dayKey: occurrence.dayKey,
      ),
      record: _completedTodayRecords[occurrence.occurrenceId],
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

  Future<void> _openOccurrence(FixedProgrammeOccurrenceProjection occurrence) {
    return _openScheduledDay(
      AthleteProgrammeWeekDayPresentation(
        date: DateTime.parse(occurrence.scheduledDate),
        state: occurrence.state,
        occurrence: occurrence,
      ),
    );
  }

  Future<void> _openHistory() async {
    if (_athleteId.isEmpty) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TrainingHistoryScreen(athleteId: _athleteId),
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
