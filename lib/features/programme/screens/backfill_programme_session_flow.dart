import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../performance/controllers/performance_capture_controller.dart';
import '../../performance/mappers/performance_record_mapper.dart';
import '../../performance/models/training_session_record_status.dart';
import '../../performance/services/performance_result_summary_formatter.dart';
import '../../performance/widgets/performance_capture_widgets.dart';
import '../../session/controllers/session_execution_controller.dart';
import '../../session/models/session_execution_plan.dart';
import '../../session/services/session_finish_eligibility.dart';
import '../../session/widgets/athlete/athlete_block_card.dart';
import '../models/backfill_programme_session.dart';
import '../models/fixed_programme_occurrence_projection.dart';
import '../presentation/athlete_programme_lifecycle_presentation.dart';
import '../services/athlete_catalogue_enrolment_services.dart';
import '../services/athlete_programme_session_prepare_service.dart';
import '../services/backfill_programme_session_store.dart';
import '../../../data/repositories/programme_assignment_store.dart';
import '../../../data/repositories/programme_assignment_supabase_store.dart';

Future<bool?> openBackfillProgrammeSessionFlow({
  required BuildContext context,
  required String athleteId,
  required FixedProgrammeCalendarProjection calendar,
  required FixedProgrammeOccurrenceProjection occurrence,
  required BackfillProgrammeSessionStore backfillStore,
  ProgrammeAssignmentStore? assignmentStore,
  AthleteProgrammeSessionPrepareService? prepareService,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => BackfillPerformedDateScreen(
        athleteId: athleteId,
        calendar: calendar,
        occurrence: occurrence,
        backfillStore: backfillStore,
        assignmentStore: assignmentStore,
        prepareService: prepareService,
      ),
    ),
  );
}

class BackfillPerformedDateScreen extends StatefulWidget {
  const BackfillPerformedDateScreen({
    super.key,
    required this.athleteId,
    required this.calendar,
    required this.occurrence,
    required this.backfillStore,
    this.assignmentStore,
    this.prepareService,
  });

  final String athleteId;
  final FixedProgrammeCalendarProjection calendar;
  final FixedProgrammeOccurrenceProjection occurrence;
  final BackfillProgrammeSessionStore backfillStore;
  final ProgrammeAssignmentStore? assignmentStore;
  final AthleteProgrammeSessionPrepareService? prepareService;

  @override
  State<BackfillPerformedDateScreen> createState() =>
      _BackfillPerformedDateScreenState();
}

class _BackfillPerformedDateScreenState
    extends State<BackfillPerformedDateScreen> {
  late String _performedOn = widget.occurrence.scheduledDate;
  String? _error;

  DateTime get _scheduled => DateTime.parse(widget.occurrence.scheduledDate);
  DateTime get _today => DateTime.parse(widget.calendar.today);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backfill results')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(CohortSpacing.lg),
          children: [
            Text(widget.occurrence.sessionTitle, style: CohortTextStyles.h2),
            const SizedBox(height: CohortSpacing.sm),
            Text(
              IncompleteSessionAthleteCopy.scheduledForLine(_scheduled),
              style: CohortTextStyles.body,
            ),
            const SizedBox(height: CohortSpacing.lg),
            Text('When did you perform this session?', style: CohortTextStyles.h2),
            const SizedBox(height: CohortSpacing.sm),
            Text(
              BackfillPerformedDatePolicy.dateHelp,
              style: CohortTextStyles.body,
            ),
            const SizedBox(height: CohortSpacing.lg),
            CohortCard(
              child: ListTile(
                key: const ValueKey('backfill-performed-date'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Performed date'),
                subtitle: Text(
                  AthleteProgrammeDateFormatter.weekdayDayMonth(
                    DateTime.parse(_performedOn),
                  ),
                ),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: _pickDate,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: CohortSpacing.md),
              Text(_error!, style: CohortTextStyles.body),
            ],
            const SizedBox(height: CohortSpacing.xl),
            CohortButton(
              key: const ValueKey('backfill-continue'),
              label: 'Continue',
              onPressed: _continue,
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(_performedOn),
      firstDate: _scheduled,
      lastDate: _today,
    );
    if (selected == null) return;
    setState(() {
      _performedOn = AthleteCalendarIso.date(selected);
      _error = null;
    });
  }

  void _continue() {
    final decision = BackfillPerformedDatePolicy.validate(
      scheduledDate: widget.occurrence.scheduledDate,
      performedOn: _performedOn,
      today: widget.calendar.today,
      assignmentStart: widget.calendar.startDate,
      assignmentEnd: widget.calendar.calendarEndDate,
    );
    if (!decision.accepted) {
      setState(() => _error = decision.message);
      return;
    }
    Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BackfillResultsEntryScreen(
          athleteId: widget.athleteId,
          calendar: widget.calendar,
          occurrence: widget.occurrence,
          performedOn: _performedOn,
          backfillStore: widget.backfillStore,
          assignmentStore: widget.assignmentStore,
          prepareService: widget.prepareService,
        ),
      ),
    ).then((saved) {
      if (saved == true && mounted) Navigator.of(context).pop(true);
    });
  }
}

class BackfillResultsEntryScreen extends StatefulWidget {
  const BackfillResultsEntryScreen({
    super.key,
    required this.athleteId,
    required this.calendar,
    required this.occurrence,
    required this.performedOn,
    required this.backfillStore,
    this.assignmentStore,
    this.prepareService,
  });

  final String athleteId;
  final FixedProgrammeCalendarProjection calendar;
  final FixedProgrammeOccurrenceProjection occurrence;
  final String performedOn;
  final BackfillProgrammeSessionStore backfillStore;
  final ProgrammeAssignmentStore? assignmentStore;
  final AthleteProgrammeSessionPrepareService? prepareService;

  @override
  State<BackfillResultsEntryScreen> createState() =>
      _BackfillResultsEntryScreenState();
}

class _BackfillResultsEntryScreenState extends State<BackfillResultsEntryScreen> {
  SessionExecutionController? _execution;
  PerformanceCaptureController? _performance;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      final assignments =
          widget.assignmentStore ?? const ProgrammeAssignmentSupabaseStore();
      final assignment = await assignments.getById(
        widget.calendar.assignmentId,
      );
      if (assignment == null) {
        throw StateError('Assignment unavailable.');
      }
      final prepare =
          widget.prepareService ??
          AthleteCatalogueEnrolmentServices.createPrepareService();
      final prepared = await prepare.prepareFixedOccurrence(
        assignment,
        widget.occurrence,
      );
      if (!prepared.isReady || prepared.package == null) {
        throw StateError(
          prepared.message ?? 'This session cannot be backfilled.',
        );
      }
      final plan = prepared.package!.plan;
      if (!mounted) return;
      setState(() {
        _execution = SessionExecutionController(
          plan: plan,
          sessionKey: 'backfill:${widget.occurrence.occurrenceId}',
        );
        _performance = PerformanceCaptureController.initializeFromExecutionPlan(
          plan: plan,
          athleteId: widget.athleteId,
          trainingSessionId: 0,
          programmeContext: prepared.executionContext,
        );
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'This session could not be opened for result entry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final execution = _execution;
    final performance = _performance;
    return Scaffold(
      appBar: AppBar(title: const Text('Backfill results')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null || execution == null || performance == null
            ? Center(child: Text(_error ?? 'Unavailable'))
            : _editor(execution, performance),
      ),
    );
  }

  Widget _editor(
    SessionExecutionController execution,
    PerformanceCaptureController performance,
  ) {
    final plan = execution.state.plan;
    final eligibility = const SessionFinishEligibilityEvaluator().evaluate(
      incompleteBlockCount: execution.state.incompleteCount,
      performanceDraft: performance.draft,
    );
    return ListView(
      padding: const EdgeInsets.all(CohortSpacing.lg),
      children: [
        Text('BACKFILL RESULTS', style: CohortTextStyles.sectionLabel),
        const SizedBox(height: CohortSpacing.sm),
        Text(plan.sessionTitle, style: CohortTextStyles.h1),
        const SizedBox(height: CohortSpacing.xs),
        Text(
          'No live workout timer. Review every result before saving.',
          style: CohortTextStyles.body,
        ),
        const SizedBox(height: CohortSpacing.lg),
        for (var index = 0; index < plan.blocks.length; index++) ...[
          if (index > 0) const SizedBox(height: CohortSpacing.md),
          _blockEditor(plan.blocks[index], execution, performance),
        ],
        const SizedBox(height: CohortSpacing.xl),
        CohortButton(
          key: const ValueKey('backfill-review'),
          label: 'Review results',
          onPressed: eligibility.canFinish
              ? () => _openReview(execution, performance)
              : null,
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _blockEditor(
    SessionExecutionBlock block,
    SessionExecutionController execution,
    PerformanceCaptureController performance,
  ) {
    final draft = performance.draft.blockDraftFor(block.blockId);
    return AthleteBlockCard(
      block: block,
      isExpanded: true,
      isActive: true,
      isComplete: execution.state.isBlockComplete(block.blockId),
      onToggleExpanded: () {},
      onMarkComplete: () {
        performance.markBlockComplete(block.blockId);
        execution.markBlockComplete(block.blockId);
        setState(() {});
      },
      onReopen: () {
        performance.reopenBlock(block.blockId);
        execution.reopenBlock(block.blockId);
        setState(() {});
      },
      onLaunchTimer: null,
      onOpenExercise: (_) {},
      showActions: true,
      performanceReplacesExerciseList:
          draft != null && BlockResultEditor.rendersExerciseRows(draft),
      performanceSection: draft == null
          ? null
          : BlockResultEditor(
              blockDraft: draft,
              linkedExercises: block.linkedExercises,
              onResultChanged: (result) {
                performance.updateBlockResultData(block.blockId, result);
                setState(() {});
              },
              onAddSet: (exerciseId) {
                performance.addSet(block.blockId, exerciseId);
                setState(() {});
              },
              onUpdateSet: (exerciseId, setResultId, update) {
                performance.updateSet(
                  block.blockId,
                  exerciseId,
                  setResultId,
                  update,
                );
                setState(() {});
              },
              onDuplicateSet: (exerciseId, setResultId) {
                performance.duplicateSet(
                  block.blockId,
                  exerciseId,
                  setResultId,
                );
                setState(() {});
              },
              onRemoveSet: (exerciseId, setResultId) {
                performance.removeSet(block.blockId, exerciseId, setResultId);
                setState(() {});
              },
            ),
    );
  }

  Future<void> _openReview(
    SessionExecutionController execution,
    PerformanceCaptureController performance,
  ) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BackfillReviewScreen(
          athleteId: widget.athleteId,
          calendar: widget.calendar,
          occurrence: widget.occurrence,
          performedOn: widget.performedOn,
          plan: execution.state.plan,
          performance: performance,
          backfillStore: widget.backfillStore,
        ),
      ),
    );
    if (saved == true && mounted) Navigator.of(context).pop(true);
  }
}

class BackfillReviewScreen extends StatefulWidget {
  const BackfillReviewScreen({
    super.key,
    required this.athleteId,
    required this.calendar,
    required this.occurrence,
    required this.performedOn,
    required this.plan,
    required this.performance,
    required this.backfillStore,
  });

  final String athleteId;
  final FixedProgrammeCalendarProjection calendar;
  final FixedProgrammeOccurrenceProjection occurrence;
  final String performedOn;
  final SessionExecutionPlan plan;
  final PerformanceCaptureController performance;
  final BackfillProgrammeSessionStore backfillStore;

  @override
  State<BackfillReviewScreen> createState() => _BackfillReviewScreenState();
}

class _BackfillReviewScreenState extends State<BackfillReviewScreen> {
  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final scheduled = DateTime.parse(widget.occurrence.scheduledDate);
    final performed = DateTime.parse(widget.performedOn);
    final entered = DateTime.parse(widget.calendar.today);
    final summaries = const PerformanceRecordMapper()
        .fromDraft(widget.performance.draft)
        .blockResults
        .map(PerformanceResultSummaryFormatter.formatBlock)
        .toList(growable: false);
    return Scaffold(
      appBar: AppBar(title: const Text('Review backfill')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(CohortSpacing.lg),
          children: [
            Text(widget.plan.sessionTitle, style: CohortTextStyles.h2),
            const SizedBox(height: CohortSpacing.md),
            Text(
              IncompleteSessionAthleteCopy.backfillHistory(
                scheduled: scheduled,
                performed: performed,
                entered: entered,
              ),
              key: const ValueKey('backfill-review-dates'),
              style: CohortTextStyles.body,
            ),
            const SizedBox(height: CohortSpacing.md),
            Text(
              widget.performance.draft.status ==
                      TrainingSessionRecordStatus.completed
                  ? 'Complete'
                  : 'Results ready to save',
              style: CohortTextStyles.body,
            ),
            if (widget.performance.draft.overallRpe != null)
              Text(
                'Session RPE ${widget.performance.draft.overallRpe}',
                style: CohortTextStyles.body,
              ),
            if (widget.performance.draft.athleteNote != null)
              Text(
                widget.performance.draft.athleteNote!,
                style: CohortTextStyles.body,
              ),
            const SizedBox(height: CohortSpacing.md),
            for (final summary in summaries)
              Padding(
                padding: const EdgeInsets.only(bottom: CohortSpacing.sm),
                child: Text(summary, style: CohortTextStyles.small),
              ),
            const SizedBox(height: CohortSpacing.lg),
            Text(
              "This will mark the original session complete using the performance date you selected. Today's scheduled session will not change.",
              style: CohortTextStyles.body,
            ),
            if (_error != null) ...[
              const SizedBox(height: CohortSpacing.md),
              Text(_error!, style: CohortTextStyles.body),
            ],
            const SizedBox(height: CohortSpacing.xl),
            CohortButton(
              key: const ValueKey('backfill-save'),
              label: _saving ? 'Saving…' : 'Save backfilled results',
              onPressed: _saving ? null : _save,
            ),
            TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await widget.backfillStore.save(
      BackfillProgrammeSessionCommand(
        athleteId: widget.athleteId,
        assignmentId: widget.calendar.assignmentId,
        occurrenceId: widget.occurrence.occurrenceId,
        scheduledDate: widget.occurrence.scheduledDate,
        performedOn: widget.performedOn,
        timezone: widget.calendar.timezone,
        idempotencyKey:
            'backfill:${widget.athleteId}:${widget.calendar.assignmentId}:${widget.occurrence.occurrenceId}',
        draft: widget.performance.draft,
      ),
    );
    if (!mounted) return;
    if (result.isSaved) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      _error = result.message ?? 'Results could not be saved. Try again.';
    });
  }
}

abstract final class AthleteCalendarIso {
  static String date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
