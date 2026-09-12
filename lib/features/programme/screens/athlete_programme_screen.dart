import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_brand_lockup.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../../core/widgets/section_title.dart';
import '../../../data/repositories/programme_assignment_store.dart';
import '../../../models/programme_assignment.dart';
import '../../home/controllers/home_today_session_refresh_controller.dart';
import '../../session/services/programme_session_execution_launcher.dart';
import '../controllers/athlete_programme_controllers.dart';
import '../models/athlete_plan_materialisation.dart';
import '../models/fixed_programme_occurrence_projection.dart';
import '../presentation/athlete_programme_lifecycle_presentation.dart';
import '../services/athlete_catalogue_enrolment_services.dart';
import '../services/athlete_plan_materialisation_service.dart';
import '../services/athlete_programme_session_prepare_service.dart';
import '../services/fixed_programme_occurrence_projection_store.dart';
import '../services/fixed_programme_occurrence_projection_supabase_store.dart';
import '../services/future_programme_session_swap_store.dart';
import '../services/scheduled_programme_session_preview_service.dart';
import '../widgets/fixed_programme_week_view.dart';
import 'athlete_programme_schedule_screen.dart';
import 'athlete_programme_selection_screen.dart';
import 'scheduled_programme_session_preview_screen.dart';

/// Athlete-facing programme overview — enrolment, Start Programme, prepare handoff.
class AthleteProgrammeScreen extends StatefulWidget {
  const AthleteProgrammeScreen({
    super.key,
    required this.athleteId,
    this.refreshController,
    this.embeddedInShell = false,
    this.controller,
    this.fixedOccurrenceStore,
    this.previewService,
    this.assignmentStore,
    this.prepareService,
    this.executionLauncher,
    this.swapStore,
    this.onOpenCalendar,
  });

  final String athleteId;
  final HomeTodaySessionRefreshController? refreshController;

  /// When true, successful start/switch must not pop the route (shell owns nav).
  final bool embeddedInShell;

  final AthleteProgrammeScreenController? controller;
  final FixedProgrammeOccurrenceProjectionStore? fixedOccurrenceStore;
  final ScheduledProgrammeSessionPreviewService? previewService;
  final ProgrammeAssignmentStore? assignmentStore;
  final AthleteProgrammeSessionPrepareService? prepareService;
  final ProgrammeSessionExecutionLauncher? executionLauncher;
  final FutureProgrammeSessionSwapStore? swapStore;
  final VoidCallback? onOpenCalendar;

  @override
  State<AthleteProgrammeScreen> createState() => _AthleteProgrammeScreenState();
}

class _AthleteProgrammeScreenState extends State<AthleteProgrammeScreen> {
  late final AthleteProgrammeScreenController _controller =
      widget.controller ??
      AthleteCatalogueEnrolmentServices.createProgrammeScreenController(
        athleteId: widget.athleteId,
      );
  FixedProgrammeCalendarProjection? _fixedCalendar;
  bool _fixedCalendarLoading = false;
  String? _fixedCalendarError;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    widget.refreshController?.attachSurface(
      this,
      ({required String source}) => _loadProgramme(),
    );
    _loadProgramme();
  }

  @override
  void dispose() {
    widget.refreshController?.detachSurface(this);
    _controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadProgramme() async {
    await _controller.load();
    await _loadFixedCalendar();
  }

  Future<void> _loadFixedCalendar() async {
    final assignment = _controller.activeAssignment;
    if (assignment == null ||
        !assignment.isMaterialised ||
        !assignment.isFixedSchedule) {
      if (mounted) {
        setState(() {
          _fixedCalendar = null;
          _fixedCalendarLoading = false;
          _fixedCalendarError = null;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _fixedCalendarLoading = true;
        _fixedCalendarError = null;
      });
    }
    try {
      final projection =
          await (widget.fixedOccurrenceStore ??
                  const FixedProgrammeOccurrenceProjectionSupabaseStore())
              .resolveActive();
      if (projection == null || projection.assignmentId != assignment.id) {
        throw StateError(
          'The fixed programme calendar is unavailable for this assignment.',
        );
      }
      if (mounted) {
        setState(() {
          _fixedCalendar = projection;
          _fixedCalendarLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _fixedCalendar = null;
          _fixedCalendarLoading = false;
          _fixedCalendarError = error.toString();
        });
      }
    }
  }

  Future<void> _openStartNewProgramme() async {
    final switched = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AthleteProgrammeSelectionScreen(
          athleteId: widget.athleteId,
          refreshController: widget.refreshController,
        ),
      ),
    );

    if (switched == true && mounted) {
      await _loadProgramme();
      if (mounted && !widget.embeddedInShell) {
        Navigator.of(context).pop(true);
      }
    }
  }

  Future<void> _startProgramme() async {
    if (_controller.isStarting) return;
    final assignment = _controller.activeAssignment;
    if (assignment == null) return;
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year, now.month, now.day),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2, now.month, now.day),
      helpText: 'Choose programme start date',
    );
    if (selected == null || !mounted) return;
    final timezone = assignment.timezone?.trim();
    if (timezone == null || timezone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a valid programme timezone before starting.'),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm programme start'),
        content: Text(
          'Your programme will start on ${selected.toIso8601String().substring(0, 10)} in $timezone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Start programme'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await _controller.startProgramme(
      timezone: timezone,
      startDate: selected,
    );
    if (!mounted || result == null) return;

    if (result.isSuccess) {
      await _loadFixedCalendar();
      if (!mounted) return;
      final lifecycle = _fixedCalendar == null
          ? null
          : AthleteProgrammeLifecycleFormatter.fromFixedProjection(
              _fixedCalendar!,
            );
      widget.refreshController?.requestRefresh(source: 'start_programme');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lifecycle?.isUpcoming == true
                ? 'Programme scheduled. ${lifecycle!.statusLabel}.'
                : result.isIdempotentAlreadyMaterialised
                ? 'This programme is already started. Check Home for today\'s session.'
                : 'Programme started. Today\'s session is available on Home.',
          ),
        ),
      );
      if (mounted &&
          !widget.embeddedInShell &&
          Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
      return;
    }

    if (result.status == AthletePlanMaterialisationStatus.legacyPlanConflict) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: CohortColors.surface,
          title: Text('Cannot start programme', style: CohortTextStyles.h2),
          content: Text(
            result.message ??
                'You already have an active plan on this device. '
                    'Switching programmes is not available yet.',
            style: CohortTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            CohortBrandLockup(),
            SizedBox(width: 12),
            Text('Programmes'),
          ],
        ),
        automaticallyImplyLeading: !widget.embeddedInShell,
      ),
      body: SafeArea(
        child: _controller.isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(CohortSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_controller.errorMessage != null) ...[
                      Text(
                        _controller.errorMessage!,
                        style: CohortTextStyles.body.copyWith(
                          color: CohortColors.warning,
                        ),
                      ),
                      const SizedBox(height: CohortSpacing.lg),
                    ],
                    const SectionTitle('Current programme'),
                    const SizedBox(height: CohortSpacing.md),
                    _buildCurrentProgrammeCard(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildCurrentProgrammeCard() {
    final assignment = _controller.activeAssignment;
    final version = _controller.activeVersion;

    if (assignment == null) {
      return CohortCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You are not enrolled in a programme yet.',
              style: CohortTextStyles.body,
            ),
            const SizedBox(height: CohortSpacing.md),
            CohortButton(
              label: 'View programmes',
              variant: CohortButtonVariant.secondary,
              onPressed: _openStartNewProgramme,
            ),
          ],
        ),
      );
    }

    final name = version?.name ?? assignment.lineageCode;
    final goal = version?.primaryGoal ?? version?.description;
    final duration = version?.durationWeeks;
    final sessions = version?.sessionsPerWeek;

    return CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: CohortTextStyles.h2),
          if (goal != null && goal.trim().isNotEmpty) ...[
            const SizedBox(height: CohortSpacing.sm),
            Text(goal.trim(), style: CohortTextStyles.body),
          ],
          if (duration != null) ...[
            const SizedBox(height: CohortSpacing.xs),
            Text('$duration weeks', style: CohortTextStyles.small),
          ],
          if (sessions != null) ...[
            const SizedBox(height: CohortSpacing.xs),
            Text('$sessions sessions per week', style: CohortTextStyles.small),
          ],
          const SizedBox(height: CohortSpacing.md),
          _buildLifecycleStatus(assignment),
          if (assignment.isFixedSchedule && _fixedCalendar != null) ...[
            const SizedBox(height: CohortSpacing.md),
            FixedProgrammeWeekView(
              presentation:
                  AthleteProgrammeLifecycleFormatter.fromFixedProjection(
                    _fixedCalendar!,
                  ).week,
              onDayTap: _openFixedDay,
              onViewCalendar: () => _openCalendar(assignment),
            ),
          ],
          if (assignment.isEnrolledOnly) ...[
            const SizedBox(height: CohortSpacing.md),
            Text(
              'Choose a start date and confirm your programme timezone. '
              'It does not purchase access or open a workout session.',
              style: CohortTextStyles.muted,
            ),
            const SizedBox(height: CohortSpacing.md),
            IgnorePointer(
              ignoring: _controller.isStarting,
              child: Opacity(
                opacity: _controller.isStarting ? 0.6 : 1,
                child: CohortButton(
                  label: _controller.isStarting
                      ? 'Starting…'
                      : 'Start Programme',
                  onPressed: _startProgramme,
                ),
              ),
            ),
          ],
          if (assignment.isMaterialised) ...[
            const SizedBox(height: CohortSpacing.md),
            TextButton(
              onPressed: () => _openCalendar(assignment),
              child: Text(
                assignment.isFixedSchedule
                    ? 'View Programme Calendar'
                    : 'Manage schedule',
              ),
            ),
          ],
          const SizedBox(height: CohortSpacing.md),
          CohortButton(
            label: 'Browse programmes',
            variant: CohortButtonVariant.secondary,
            onPressed: _openStartNewProgramme,
          ),
        ],
      ),
    );
  }

  Widget _buildLifecycleStatus(ProgrammeAssignment assignment) {
    if (!assignment.isFixedSchedule || !assignment.isMaterialised) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AthletePlanMaterialisationLabels.statusLabel(assignment),
            style: CohortTextStyles.small,
          ),
          if (assignment.isMaterialised) ...[
            const SizedBox(height: CohortSpacing.xs),
            Text(
              _controller.lastPrepareResult?.isReady == true
                  ? 'Programme started. Today\'s authored session is ready on Home.'
                  : _controller.isPreparing
                  ? 'Preparing today\'s authored session…'
                  : _controller.lastPrepareResult?.isRecoverableFailure == true
                  ? (_controller.lastPrepareResult?.message ??
                        'Today\'s session could not be prepared yet. Retry from Home.')
                  : 'Programme started. Today\'s authored session appears on Home.',
              style: CohortTextStyles.muted,
            ),
          ],
        ],
      );
    }
    if (_fixedCalendarLoading) {
      return const Text(
        'Loading programme calendar…',
        style: CohortTextStyles.muted,
      );
    }
    if (_fixedCalendarError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Programme calendar unavailable.',
            style: CohortTextStyles.muted,
          ),
          TextButton(onPressed: _loadFixedCalendar, child: const Text('Retry')),
        ],
      );
    }
    final calendar = _fixedCalendar;
    if (calendar == null) {
      return const Text(
        'Programme calendar unavailable.',
        style: CohortTextStyles.muted,
      );
    }
    final lifecycle = AthleteProgrammeLifecycleFormatter.fromFixedProjection(
      calendar,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(lifecycle.statusLabel, style: CohortTextStyles.small),
        const SizedBox(height: CohortSpacing.xs),
        Text(lifecycle.supportingLine, style: CohortTextStyles.muted),
      ],
    );
  }

  Future<void> _openCalendar(ProgrammeAssignment assignment) async {
    final shellCalendar = widget.onOpenCalendar;
    if (shellCalendar != null) {
      shellCalendar();
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AthleteProgrammeScheduleScreen(
          athleteId: widget.athleteId,
          assignmentId: assignment.id,
          fixedOccurrenceStore: widget.fixedOccurrenceStore,
          previewService: widget.previewService,
          assignmentStore: widget.assignmentStore,
          prepareService: widget.prepareService,
          executionLauncher: widget.executionLauncher,
          swapStore: widget.swapStore,
        ),
      ),
    );
    if (mounted) await _loadFixedCalendar();
  }

  Future<void> _openFixedDay(AthleteProgrammeWeekDayPresentation day) async {
    final calendar = _fixedCalendar;
    if (calendar == null || day.occurrence == null) return;
    final changed = await openScheduledProgrammeSessionPreview(
      context: context,
      athleteId: widget.athleteId,
      calendar: calendar,
      day: day,
      previewService: widget.previewService,
      assignmentStore: widget.assignmentStore,
      prepareService: widget.prepareService,
      executionLauncher: widget.executionLauncher,
      swapStore: widget.swapStore,
      fixedOccurrenceStore: widget.fixedOccurrenceStore,
      refreshController: widget.refreshController,
    );
    if (changed == true && mounted) await _loadFixedCalendar();
  }
}
