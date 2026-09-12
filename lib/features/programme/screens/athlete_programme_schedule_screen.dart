import 'package:flutter/material.dart';

import '../../../core/persistence/athlete_local_repository.dart';
import '../../../core/persistence/athlete_persistence.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../../core/widgets/section_title.dart';
import '../../../data/repositories/programme_assignment_store.dart';
import '../../../data/repositories/programme_assignment_supabase_store.dart';
import '../../../domain/programme_scheduling/programme_scheduling_domain.dart';
import '../../../domain/session_occurrence/value_objects/session_occurrence_date.dart';
import '../controllers/athlete_programme_schedule_controller.dart';
import '../models/fixed_programme_occurrence_projection.dart';
import '../presentation/athlete_programme_lifecycle_presentation.dart';
import '../presentation/programme_day_label_formatter.dart';
import '../services/athlete_catalogue_enrolment_services.dart';
import '../services/athlete_programme_session_prepare_service.dart';
import '../services/fixed_programme_occurrence_projection_store.dart';
import '../services/fixed_programme_occurrence_projection_supabase_store.dart';
import '../services/future_programme_session_swap_store.dart';
import '../services/programme_schedule_apply_service.dart';
import '../services/programme_schedule_apply_supabase_store.dart';
import '../services/programme_schedule_operations_supabase_store.dart';
import '../services/programme_schedule_projection_supabase_store.dart';
import '../services/programme_schedule_restore_service.dart';
import '../services/scheduled_programme_session_preview_service.dart';
import '../widgets/fixed_programme_week_view.dart';
import '../../session/services/programme_session_execution_launcher.dart';
import 'scheduled_programme_session_preview_screen.dart';

/// Assignment-scoped athlete schedule calendar (Sprint 1.7F).
///
/// Ownership: exact-preview Move/Swap/Push/Skip/Undo. Not a general calendar product.
class AthleteProgrammeScheduleScreen extends StatefulWidget {
  const AthleteProgrammeScheduleScreen({
    super.key,
    required this.athleteId,
    required this.assignmentId,
    this.controller,
    this.fixedOccurrenceStore,
    this.assignmentStore,
    this.prepareService,
    this.executionLauncher,
    this.previewService,
    this.swapStore,
  });

  final String athleteId;
  final String assignmentId;
  final AthleteProgrammeScheduleController? controller;
  final FixedProgrammeOccurrenceProjectionStore? fixedOccurrenceStore;
  final ProgrammeAssignmentStore? assignmentStore;
  final AthleteProgrammeSessionPrepareService? prepareService;
  final ProgrammeSessionExecutionLauncher? executionLauncher;
  final ScheduledProgrammeSessionPreviewService? previewService;
  final FutureProgrammeSessionSwapStore? swapStore;

  @override
  State<AthleteProgrammeScheduleScreen> createState() =>
      _AthleteProgrammeScheduleScreenState();
}

class _AthleteProgrammeScheduleScreenState
    extends State<AthleteProgrammeScheduleScreen> {
  late final AthleteProgrammeScheduleController _controller;
  bool _legacyControllerReady = false;
  FixedProgrammeCalendarProjection? _fixedCalendar;
  bool _fixedLoading = true;
  String? _fixedError;
  String? _moveSlotId;
  String? _swapSlotA;
  String? _swapSlotB;
  DateTime? _moveTarget;
  String? _pushSlotId;
  int _pushDayDelta = 1;
  String? _skipSlotId;

  @override
  void initState() {
    super.initState();
    final suppliedController = widget.controller;
    if (suppliedController != null) {
      _controller = suppliedController;
      _controller.addListener(_onChanged);
      _legacyControllerReady = true;
    }
    if (suppliedController != null && widget.fixedOccurrenceStore == null) {
      _fixedLoading = false;
      _controller.load();
    } else {
      _loadAuthoritativeCalendar();
    }
  }

  Future<void> _loadAuthoritativeCalendar() async {
    try {
      final projection =
          await (widget.fixedOccurrenceStore ??
                  const FixedProgrammeOccurrenceProjectionSupabaseStore())
              .resolveActive();
      if (!mounted) return;
      if (projection != null) {
        if (projection.assignmentId != widget.assignmentId) {
          throw StateError(
            'The active fixed schedule does not match this assignment.',
          );
        }
        setState(() {
          _fixedCalendar = projection;
          _fixedLoading = false;
        });
        return;
      }
      setState(() => _fixedLoading = false);
      if (!_legacyControllerReady) {
        _controller = _buildDefaultController();
        _controller.addListener(_onChanged);
        _legacyControllerReady = true;
      }
      await _controller.load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _fixedError = error.toString();
        _fixedLoading = false;
      });
    }
  }

  AthleteProgrammeScheduleController _buildDefaultController() {
    final AthleteLocalRepository? local = AthletePersistence.isInitialized
        ? AthletePersistence.repository
        : null;
    if (local == null) {
      throw StateError(
        'AthleteProgrammeScheduleScreen requires AthletePersistence.',
      );
    }
    final restore = ProgrammeScheduleRestoreService(
      store: const ProgrammeScheduleProjectionSupabaseStore(),
      localRepository: local,
    );
    final apply = ProgrammeScheduleApplyService(
      applyStore: const ProgrammeScheduleApplySupabaseStore(),
      restoreService: restore,
      localRepository: local,
      prepareService: AthleteCatalogueEnrolmentServices.createPrepareService(
        localRepository: local,
      ),
    );
    return AthleteProgrammeScheduleController(
      athleteId: widget.athleteId,
      assignmentId: widget.assignmentId,
      restoreService: restore,
      applyService: apply,
      assignmentStore: const ProgrammeAssignmentSupabaseStore(),
      operationsStore: const ProgrammeScheduleOperationsSupabaseStore(),
    );
  }

  @override
  void dispose() {
    if (_legacyControllerReady) {
      _controller.removeListener(_onChanged);
      if (widget.controller == null) {
        _controller.dispose();
      }
    }
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _pickMoveDate() async {
    final snap = _controller.snapshot;
    if (snap == null) return;
    final initial = _moveTarget ?? DateTime.now();
    final started = DateTime(
      snap.startedAt.year,
      snap.startedAt.month,
      snap.startedAt.day,
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(started) ? started : initial,
      firstDate: started,
      lastDate: started.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _moveTarget = picked);
    }
  }

  Future<void> _runMovePreview() async {
    final slot = _moveSlotId;
    final target = _moveTarget;
    if (slot == null || target == null) return;
    await _controller.previewMove(
      sessionSlotId: slot,
      targetDate: SessionOccurrenceDate.fromDateTime(target),
    );
  }

  Future<void> _runSwapPreview() async {
    final a = _swapSlotA;
    final b = _swapSlotB;
    if (a == null || b == null) return;
    await _controller.previewSwap(sessionSlotIdA: a, sessionSlotIdB: b);
  }

  Future<void> _confirm() async {
    final result = await _controller.confirmPreview();
    if (!mounted || result == null) return;
    if (result.isSuccess) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Schedule updated.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_fixedLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Programme calendar')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_fixedError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Programme calendar')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(CohortSpacing.lg),
            child: CohortCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Programme calendar unavailable',
                    style: CohortTextStyles.h2,
                  ),
                  const SizedBox(height: CohortSpacing.sm),
                  Text(_fixedError!, style: CohortTextStyles.body),
                  const SizedBox(height: CohortSpacing.md),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _fixedLoading = true;
                        _fixedError = null;
                      });
                      _loadAuthoritativeCalendar();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final fixedCalendar = _fixedCalendar;
    if (fixedCalendar != null) {
      return _buildFixedCalendar(fixedCalendar);
    }
    final snap = _controller.snapshot;
    final today = snap?.today.toString() ?? '—';
    return Scaffold(
      appBar: AppBar(title: const Text('Programme schedule')),
      body: SafeArea(
        child: _controller.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(CohortSpacing.lg),
                children: [
                  if (_controller.errorMessage != null) ...[
                    Text(
                      _controller.errorMessage!,
                      style: CohortTextStyles.body.copyWith(
                        color: CohortColors.warning,
                      ),
                      semanticsLabel: 'Error: ${_controller.errorMessage}',
                    ),
                    const SizedBox(height: CohortSpacing.md),
                    TextButton(
                      onPressed: _controller.load,
                      child: const Text('Retry'),
                    ),
                    const SizedBox(height: CohortSpacing.md),
                  ],
                  Text(
                    'Today ($today) in your programme timezone. '
                    'Preview exact changes before confirming. Prescription and '
                    'completion history stay unchanged.',
                    style: CohortTextStyles.muted,
                  ),
                  const SizedBox(height: CohortSpacing.xl),
                  const SectionTitle('Calendar'),
                  const SizedBox(height: CohortSpacing.sm),
                  ..._calendarSections(),
                  if (_controller.undoableOperation != null) ...[
                    const SizedBox(height: CohortSpacing.xl),
                    const SectionTitle('Undo'),
                    const SizedBox(height: CohortSpacing.sm),
                    Text(
                      'Reverse the latest '
                      '${_controller.undoableOperation!.originalType.name} '
                      '(expires '
                      '${_controller.undoableOperation!.undoExpiresAt?.toLocal().toIso8601String() ?? 'n/a'}). '
                      'Server revalidates eligibility on confirm.',
                      style: CohortTextStyles.muted,
                    ),
                    const SizedBox(height: CohortSpacing.sm),
                    CohortButton(
                      label: 'Preview undo',
                      onPressed: () => _controller.previewUndo(),
                    ),
                  ],
                  const SizedBox(height: CohortSpacing.xl),
                  const SectionTitle('Move'),
                  const SizedBox(height: CohortSpacing.sm),
                  _slotDropdown(
                    label: 'Session',
                    value: _moveSlotId,
                    onChanged: (v) => setState(() => _moveSlotId = v),
                  ),
                  const SizedBox(height: CohortSpacing.sm),
                  TextButton(
                    onPressed: _pickMoveDate,
                    child: Text(
                      _moveTarget == null
                          ? 'Choose date'
                          : 'Date: ${_moveTarget!.toIso8601String().substring(0, 10)}',
                    ),
                  ),
                  const SizedBox(height: CohortSpacing.sm),
                  IgnorePointer(
                    ignoring: _moveSlotId == null || _moveTarget == null,
                    child: Opacity(
                      opacity: _moveSlotId == null || _moveTarget == null
                          ? 0.5
                          : 1,
                      child: CohortButton(
                        label: 'Preview move',
                        onPressed: _runMovePreview,
                      ),
                    ),
                  ),
                  const SizedBox(height: CohortSpacing.xl),
                  const SectionTitle('Swap'),
                  const SizedBox(height: CohortSpacing.sm),
                  _slotDropdown(
                    label: 'Session A',
                    value: _swapSlotA,
                    onChanged: (v) => setState(() => _swapSlotA = v),
                  ),
                  const SizedBox(height: CohortSpacing.sm),
                  _slotDropdown(
                    label: 'Session B',
                    value: _swapSlotB,
                    onChanged: (v) => setState(() => _swapSlotB = v),
                  ),
                  const SizedBox(height: CohortSpacing.sm),
                  IgnorePointer(
                    ignoring: _swapSlotA == null || _swapSlotB == null,
                    child: Opacity(
                      opacity: _swapSlotA == null || _swapSlotB == null
                          ? 0.5
                          : 1,
                      child: CohortButton(
                        label: 'Preview swap',
                        onPressed: _runSwapPreview,
                      ),
                    ),
                  ),
                  const SizedBox(height: CohortSpacing.xl),
                  const SectionTitle('Push'),
                  const SizedBox(height: CohortSpacing.sm),
                  Text(
                    'Shifts the selected session and every later uncompleted '
                    'session by the same number of calendar days.',
                    style: CohortTextStyles.muted,
                  ),
                  const SizedBox(height: CohortSpacing.sm),
                  _slotDropdown(
                    label: 'From session',
                    value: _pushSlotId,
                    onChanged: (v) => setState(() => _pushSlotId = v),
                  ),
                  const SizedBox(height: CohortSpacing.sm),
                  Row(
                    children: [
                      Text(
                        'Days: $_pushDayDelta',
                        style: CohortTextStyles.body,
                      ),
                      Expanded(
                        child: Slider(
                          value: _pushDayDelta.toDouble(),
                          min: 1,
                          max: 14,
                          divisions: 13,
                          onChanged: (v) =>
                              setState(() => _pushDayDelta = v.round()),
                        ),
                      ),
                    ],
                  ),
                  IgnorePointer(
                    ignoring: _pushSlotId == null,
                    child: Opacity(
                      opacity: _pushSlotId == null ? 0.5 : 1,
                      child: CohortButton(
                        label: 'Preview push',
                        onPressed: () async {
                          final slot = _pushSlotId;
                          if (slot == null) return;
                          await _controller.previewPush(
                            fromSessionSlotId: slot,
                            dayDelta: _pushDayDelta,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: CohortSpacing.xl),
                  const SectionTitle('Skip'),
                  const SizedBox(height: CohortSpacing.sm),
                  Text(
                    'Marks the current programme cursor session as skipped. '
                    'This does not record a completed workout.',
                    style: CohortTextStyles.muted,
                  ),
                  const SizedBox(height: CohortSpacing.sm),
                  _slotDropdown(
                    label: 'Current session',
                    value: _skipSlotId,
                    onChanged: (v) => setState(() => _skipSlotId = v),
                  ),
                  const SizedBox(height: CohortSpacing.sm),
                  IgnorePointer(
                    ignoring: _skipSlotId == null,
                    child: Opacity(
                      opacity: _skipSlotId == null ? 0.5 : 1,
                      child: CohortButton(
                        label: 'Preview skip',
                        onPressed: () async {
                          final slot = _skipSlotId;
                          if (slot == null) return;
                          await _controller.previewSkip(sessionSlotId: slot);
                        },
                      ),
                    ),
                  ),
                  if (_controller.preview != null) ...[
                    const SizedBox(height: CohortSpacing.xl),
                    const SectionTitle('Confirm preview'),
                    const SizedBox(height: CohortSpacing.sm),
                    _previewCard(_controller.preview!),
                    const SizedBox(height: CohortSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: _controller.isConfirming
                                ? null
                                : _controller.cancelPreview,
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: CohortSpacing.sm),
                        Expanded(
                          child: IgnorePointer(
                            ignoring: !_controller.hasConfirmablePreview,
                            child: Opacity(
                              opacity: _controller.hasConfirmablePreview
                                  ? 1
                                  : 0.5,
                              child: CohortButton(
                                label: _controller.isConfirming
                                    ? 'Applying…'
                                    : 'Confirm',
                                onPressed: _confirm,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildFixedCalendar(FixedProgrammeCalendarProjection projection) {
    final lifecycle = AthleteProgrammeLifecycleFormatter.fromFixedProjection(
      projection,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Programme calendar')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(CohortSpacing.lg),
          children: [
            Text(projection.programmeName, style: CohortTextStyles.h2),
            const SizedBox(height: CohortSpacing.xs),
            Text(lifecycle.week.dateRangeLabel, style: CohortTextStyles.muted),
            if (lifecycle.isUpcoming) ...[
              const SizedBox(height: CohortSpacing.md),
              CohortCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Starts ${lifecycle.startDateLabel}',
                      style: CohortTextStyles.cardTitle,
                    ),
                    const SizedBox(height: CohortSpacing.xs),
                    Text(
                      'Your assigned sessions are available to view now. They '
                      'unlock on their scheduled programme dates.',
                      style: CohortTextStyles.body,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: CohortSpacing.xl),
            FixedProgrammeWeekView(
              presentation: lifecycle.week,
              onDayTap: _openFixedDay,
            ),
            if (projection.overdue.isNotEmpty) ...[
              const SizedBox(height: CohortSpacing.xl),
              Semantics(
                label: IncompleteSessionAthleteCopy.countPhrase(
                  projection.overdue.length,
                ),
                excludeSemantics: true,
                child: Text(
                  IncompleteSessionAthleteCopy.sectionHeading(
                    projection.overdue.length,
                  ),
                  style: CohortTextStyles.sectionLabel,
                ),
              ),
              const SizedBox(height: CohortSpacing.md),
              for (final occurrence in projection.overdue) ...[
                CohortCard(
                  onTap: () => _openFixedDay(
                    AthleteProgrammeWeekDayPresentation(
                      date: DateTime.parse(occurrence.scheduledDate),
                      state: occurrence.state,
                      occurrence: occurrence,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${occurrence.sessionTitle}\n'
                          '${IncompleteSessionAthleteCopy.scheduledLine(DateTime.parse(occurrence.scheduledDate))}\n'
                          '${IncompleteSessionAthleteCopy.statusLabel}',
                          style: CohortTextStyles.body,
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
                const SizedBox(height: CohortSpacing.sm),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openFixedDay(AthleteProgrammeWeekDayPresentation day) async {
    final projection = _fixedCalendar;
    if (projection == null || day.occurrence == null) return;
    final changed = await openScheduledProgrammeSessionPreview(
      context: context,
      athleteId: widget.athleteId,
      calendar: projection,
      day: day,
      previewService: widget.previewService,
      assignmentStore: widget.assignmentStore,
      prepareService: widget.prepareService,
      executionLauncher: widget.executionLauncher,
      swapStore: widget.swapStore,
      fixedOccurrenceStore: widget.fixedOccurrenceStore,
    );
    if (changed == true && mounted) await _loadAuthoritativeCalendar();
  }

  List<Widget> _calendarSections() {
    final snap = _controller.snapshot;
    if (snap == null || snap.projection.occurrences.isEmpty) {
      return [
        Text('No scheduled sessions yet.', style: CohortTextStyles.muted),
      ];
    }
    final byDate = <String, List<ScheduledProgrammeOccurrence>>{};
    for (final o in snap.projection.occurrences) {
      byDate.putIfAbsent(o.scheduledDate.toString(), () => []).add(o);
    }
    final dates = byDate.keys.toList()..sort();
    final widgets = <Widget>[];
    for (final date in dates) {
      final rows = byDate[date]!;
      final collision = rows.length > 1;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: CohortSpacing.sm),
          child: Text(
            date + (date == snap.today.toString() ? ' · today' : ''),
            style: CohortTextStyles.h2,
          ),
        ),
      );
      if (collision) {
        widgets.add(
          Text(
            'Multiple sessions on this date (allowed).',
            style: CohortTextStyles.small.copyWith(color: CohortColors.warning),
          ),
        );
      }
      for (final o in rows) {
        widgets.add(_occurrenceTile(o, snap));
      }
      widgets.add(const SizedBox(height: CohortSpacing.md));
    }
    return widgets;
  }

  Widget _occurrenceTile(
    ScheduledProgrammeOccurrence occurrence, [
    ProgrammeSchedulingSnapshot? snap,
  ]) {
    final status = _statusLabel(occurrence, snap);
    final isCursor =
        snap?.cursorSessionSlotId == occurrence.identity.sessionSlotId;
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.sm),
      child: Text(
        '${occurrence.identity.protocolId} · $status'
        '${isCursor ? ' · current' : ''} · '
        'W${occurrence.identity.weekNumber} '
        '${ProgrammeDayLabelFormatter.format(dayKey: occurrence.identity.dayKey)}',
        style: CohortTextStyles.body,
      ),
    );
  }

  String _statusLabel(
    ScheduledProgrammeOccurrence occurrence,
    ProgrammeSchedulingSnapshot? snap,
  ) {
    if (occurrence.isCompleted) return 'completed';
    if (occurrence.isSkipped) return 'skipped';
    if (snap != null && occurrence.scheduledDate.isBefore(snap.today)) {
      return 'overdue';
    }
    if (snap != null && occurrence.scheduledDate == snap.today) {
      return 'due today';
    }
    return 'scheduled';
  }

  Widget _slotDropdown({
    required String label,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    final items = _controller.uncompletedOccurrences
        .map(
          (o) => DropdownMenuItem(
            value: o.identity.sessionSlotId,
            child: Text(
              '${o.scheduledDate} · ${o.identity.protocolId}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .toList();
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          items: items,
          onChanged: onChanged,
          hint: const Text('Select'),
        ),
      ),
    );
  }

  Widget _previewCard(ProgrammeSchedulingPreview preview) {
    final clearsPrepared = preview.impacts.any(
      (i) =>
          i.kind == ProgrammeSchedulingImpactKind.preparedOccurrenceAffected ||
          i.kind ==
              ProgrammeSchedulingImpactKind.adaptedPreparedOccurrenceAffected ||
          i.kind ==
              ProgrammeSchedulingImpactKind
                  .pendingAdaptationProposalWouldBeDiscarded,
    );
    final overdue = preview.impacts.any(
      (i) => i.kind == ProgrammeSchedulingImpactKind.becomesOverdue,
    );
    return Container(
      padding: const EdgeInsets.all(CohortSpacing.md),
      color: CohortColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            preview.operationType.name.toUpperCase(),
            style: CohortTextStyles.h2,
          ),
          const SizedBox(height: CohortSpacing.sm),
          ...preview.changes.map(
            (c) => Text(
              '${c.identity.protocolId}: ${c.originalDate} → ${c.proposedDate}',
              style: CohortTextStyles.body,
            ),
          ),
          if (preview.collidingDates.isNotEmpty) ...[
            const SizedBox(height: CohortSpacing.sm),
            Text(
              'Same-date sessions (allowed): '
              '${preview.collidingDates.join(', ')}',
              style: CohortTextStyles.small.copyWith(
                color: CohortColors.warning,
              ),
            ),
          ],
          const SizedBox(height: CohortSpacing.sm),
          Text(
            clearsPrepared
                ? 'Prepared / adapted / pending state for affected sessions will be cleared.'
                : 'No prepared-state clear required for this change.',
            style: CohortTextStyles.muted,
          ),
          if (overdue)
            Text(
              'Past-date placement remains uncompleted and becomes overdue.',
              style: CohortTextStyles.muted,
            ),
          Text(
            preview.operationType == ProgrammeSchedulingOperationType.skip
                ? 'Session remains in programme history as skipped; no '
                      'performance evidence is created.'
                : 'Prescription and completion history are unchanged.',
            style: CohortTextStyles.muted,
          ),
          if (preview.operationType == ProgrammeSchedulingOperationType.skip)
            Text(
              _cursorImpactMessage(preview) ??
                  'Cursor transition is shown in preview impacts.',
              style: CohortTextStyles.muted,
            ),
        ],
      ),
    );
  }

  String? _cursorImpactMessage(ProgrammeSchedulingPreview preview) {
    for (final impact in preview.impacts) {
      if (impact.kind == ProgrammeSchedulingImpactKind.cursorWouldAdvanceTo) {
        return impact.message;
      }
    }
    return null;
  }
}
