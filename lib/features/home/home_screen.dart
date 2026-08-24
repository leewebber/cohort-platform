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
import '../programme/screens/athlete_programme_screen.dart';
import '../programme/services/athlete_catalogue_enrolment_services.dart';
import '../programme/services/athlete_programme_session_prepare_service.dart';
import '../programme/services/fixed_programme_occurrence_projection_store.dart';
import '../programme/services/fixed_programme_occurrence_projection_supabase_store.dart';
import '../programme/widgets/fixed_programme_week_view.dart';
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

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeTodaySessionRefreshController _refreshController =
      widget.refreshController ?? HomeTodaySessionRefreshController();

  /// `null` = loading/unknown; `true`/`false` = resolved materialisation.
  bool? _hasMaterialisedProgramme;
  bool _programmeEvidenceUnavailable = false;
  FixedProgrammeCalendarProjection? _calendar;
  ProgrammeAssignment? _assignment;
  String? _calendarError;

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
    _refreshMaterialisedGate();
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
        if (mounted) setState(() => _calendar = calendar);
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
        const Text("TODAY'S TRAINING", style: CohortTextStyles.sectionLabel),
        const SizedBox(height: CohortSpacing.md),
        CohortCard(
          child: Text(
            _calendarError ?? 'Loading your programme calendar…',
            style: CohortTextStyles.body,
          ),
        ),
      ];
    }

    final todayOccurrence = calendar.todayOccurrence;
    final todayDay = calendar.currentWeek.firstWhere(
      (day) => day.date == calendar.today,
    );
    final widgets = <Widget>[];
    if (calendar.startsInFuture) {
      widgets.addAll([
        const Text("TODAY'S TRAINING", style: CohortTextStyles.sectionLabel),
        const SizedBox(height: CohortSpacing.md),
        CohortCard(
          child: Text(
            '${calendar.programmeName} begins on ${calendar.startDate} '
            'in ${calendar.timezone}.',
            style: CohortTextStyles.body,
          ),
        ),
      ]);
    } else if (todayOccurrence == null ||
        todayDay.state == FixedProgrammeOccurrenceState.rest) {
      widgets.addAll(const [
        Text("TODAY'S TRAINING", style: CohortTextStyles.sectionLabel),
        SizedBox(height: CohortSpacing.md),
        CohortCard(child: Text('Rest day', style: CohortTextStyles.body)),
      ]);
    } else if (todayOccurrence.state ==
        FixedProgrammeOccurrenceState.completed) {
      widgets.addAll([
        const Text("TODAY'S TRAINING", style: CohortTextStyles.sectionLabel),
        const SizedBox(height: CohortSpacing.md),
        CohortCard(
          child: Text(
            '${todayOccurrence.sessionTitle} · Completed',
            style: CohortTextStyles.body,
          ),
        ),
      ]);
    } else {
      widgets.add(
        AthleteProgrammeTodaySection(
          athleteId: _athleteId,
          refreshController: _refreshController,
          prepareService: _prepareService,
          executionLauncher: widget.executionLauncher,
          fixedAssignment: assignment,
          fixedOccurrence: todayOccurrence,
        ),
      );
    }

    for (final overdue in calendar.overdue) {
      widgets.addAll([
        const SizedBox(height: CohortSpacing.md),
        CohortCard(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${overdue.sessionTitle} · ${overdue.scheduledDate}\n'
                  'In Progress Overdue',
                  style: CohortTextStyles.body,
                ),
              ),
              TextButton(
                onPressed: () => _openOccurrenceDetails(overdue),
                child: const Text('Resume'),
              ),
            ],
          ),
        ),
      ]);
    }

    var programmeWeek = todayOccurrence?.weekNumber;
    for (final day in calendar.currentWeek) {
      programmeWeek ??= day.occurrence?.weekNumber;
    }
    programmeWeek ??= 1;
    widgets.addAll([
      const SizedBox(height: CohortSpacing.xl),
      Text('THIS WEEK', style: CohortTextStyles.sectionLabel),
      const SizedBox(height: CohortSpacing.md),
      FixedProgrammeWeekView(
        projection: calendar,
        onOccurrenceTap: _openOccurrenceDetails,
      ),
      const SizedBox(height: CohortSpacing.xl),
      Text('CURRENT PROGRAMME', style: CohortTextStyles.sectionLabel),
      const SizedBox(height: CohortSpacing.md),
      CohortCard(
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${calendar.programmeName}\nWeek $programmeWeek',
                style: CohortTextStyles.body,
              ),
            ),
            TextButton(
              onPressed: _openProgrammeCatalogue,
              child: const Text('View Programme / Calendar'),
            ),
          ],
        ),
      ),
    ]);
    return widgets;
  }

  Future<void> _openOccurrenceDetails(
    FixedProgrammeOccurrenceProjection occurrence,
  ) async {
    final canExecute = occurrence.isToday || occurrence.isResumable;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(occurrence.sessionTitle),
        content: Text(
          '${occurrence.scheduledDate} · ${occurrence.state.displayLabel}\n'
          'Week ${occurrence.weekNumber}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          if (canExecute)
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _executeOccurrence(occurrence);
              },
              child: Text(occurrence.isResumable ? 'Resume' : 'Begin'),
            ),
        ],
      ),
    );
  }

  Future<void> _executeOccurrence(
    FixedProgrammeOccurrenceProjection occurrence,
  ) async {
    final assignment = _assignment;
    if (assignment == null) return;
    final prepared = await _prepareService.prepareFixedOccurrence(
      assignment,
      occurrence,
    );
    if (!mounted) return;
    if (!prepared.isReady) {
      _showExecutionError(
        prepared.message ?? 'This occurrence could not be prepared.',
      );
      return;
    }
    try {
      await (widget.executionLauncher ?? ProgrammeSessionExecutionLauncher())
          .launch(context: context, athleteId: _athleteId, prepared: prepared);
      await _refreshMaterialisedGate();
    } catch (error) {
      if (mounted) _showExecutionError(error.toString());
    }
  }

  void _showExecutionError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
