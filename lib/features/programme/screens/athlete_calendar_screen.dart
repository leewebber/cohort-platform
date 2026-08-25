import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_card.dart';
import '../models/fixed_programme_occurrence_projection.dart';
import '../presentation/athlete_programme_lifecycle_presentation.dart';
import '../services/fixed_programme_occurrence_projection_store.dart';
import '../services/fixed_programme_occurrence_projection_supabase_store.dart';
import '../services/scheduled_programme_session_preview_service.dart';
import '../widgets/fixed_programme_week_view.dart';
import 'scheduled_programme_session_preview_screen.dart';

/// Athlete-wide training calendar. It consumes assignment-scoped occurrences
/// but deliberately does not own a programme or assume a single programme
/// name; future projections can merge non-overlapping assignment schedules.
class AthleteCalendarScreen extends StatefulWidget {
  const AthleteCalendarScreen({
    super.key,
    required this.athleteId,
    this.fixedOccurrenceStore,
    this.previewService,
    this.onOpenProgrammes,
  });

  final String athleteId;
  final FixedProgrammeOccurrenceProjectionStore? fixedOccurrenceStore;
  final ScheduledProgrammeSessionPreviewService? previewService;
  final VoidCallback? onOpenProgrammes;

  @override
  State<AthleteCalendarScreen> createState() => _AthleteCalendarScreenState();
}

class _AthleteCalendarScreenState extends State<AthleteCalendarScreen> {
  FixedProgrammeCalendarProjection? _calendar;
  DateTime? _weekStart;
  FixedProgrammeOccurrenceProjection? _selected;
  String? _error;
  _CalendarLoadState _loadState = _CalendarLoadState.loading;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loadState = _CalendarLoadState.loading;
        _error = null;
      });
    }
    try {
      final calendar =
          await (widget.fixedOccurrenceStore ??
                  const FixedProgrammeOccurrenceProjectionSupabaseStore())
              .resolveActive()
              .timeout(const Duration(seconds: 12));
      if (!mounted) {
        return;
      }
      setState(() {
        _calendar = calendar;
        _loadState = calendar == null
            ? _CalendarLoadState.empty
            : _CalendarLoadState.loaded;
        if (calendar != null) {
          _weekStart ??= _monday(DateTime.parse(calendar.weekStart));
        }
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _calendar = null;
          _loadState = _CalendarLoadState.error;
          _error = 'Your programme schedule could not be loaded.';
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
                padding: const EdgeInsets.all(CohortSpacing.lg),
                children: [
                  Text(calendar!.programmeName, style: CohortTextStyles.h2),
                  const SizedBox(height: CohortSpacing.xs),
                  Text('Training schedule', style: CohortTextStyles.muted),
                  const SizedBox(height: CohortSpacing.md),
                  _weekControls(calendar),
                  const SizedBox(height: CohortSpacing.md),
                  FixedProgrammeWeekView(
                    presentation: _weekPresentation(calendar),
                    onDayTap: _openDay,
                  ),
                  if (_selected != null) ...[
                    const SizedBox(height: CohortSpacing.md),
                    _selectedSummary(_selected!),
                  ],
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
      child: CohortCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Calendar unavailable', style: CohortTextStyles.h2),
            const SizedBox(height: CohortSpacing.sm),
            Text(_error!, style: CohortTextStyles.body),
            const SizedBox(height: CohortSpacing.md),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    ),
  );

  Widget _weekControls(FixedProgrammeCalendarProjection calendar) {
    final week = _weekStart!;
    return Row(
      children: [
        IconButton(
          tooltip: 'Previous week',
          onPressed: () => setState(
            () => _weekStart = week.subtract(const Duration(days: 7)),
          ),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            AthleteProgrammeDateFormatter.dateRange(
              week,
              week.add(const Duration(days: 6)),
            ),
            textAlign: TextAlign.center,
            style: CohortTextStyles.cardTitle,
          ),
        ),
        IconButton(
          tooltip: 'Next week',
          onPressed: () =>
              setState(() => _weekStart = week.add(const Duration(days: 7))),
          icon: const Icon(Icons.chevron_right),
        ),
        TextButton(
          onPressed: () => setState(
            () => _weekStart = _monday(DateTime.parse(calendar.today)),
          ),
          child: const Text('Today'),
        ),
      ],
    );
  }

  AthleteProgrammeWeekPresentation _weekPresentation(
    FixedProgrammeCalendarProjection calendar,
  ) {
    final start = _weekStart!;
    final days = List.generate(7, (index) {
      final date = start.add(Duration(days: index));
      final occurrence = _occurrenceOn(calendar.occurrences, date);
      return AthleteProgrammeWeekDayPresentation(
        date: date,
        state: occurrence?.state ?? FixedProgrammeOccurrenceState.rest,
        occurrence: occurrence,
      );
    }, growable: false);
    return AthleteProgrammeWeekPresentation(
      heading: 'SCHEDULE',
      dateRangeLabel: AthleteProgrammeDateFormatter.dateRange(
        days.first.date,
        days.last.date,
      ),
      days: days,
    );
  }

  Widget _selectedSummary(FixedProgrammeOccurrenceProjection occurrence) =>
      CohortCard(
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Selected session\n${occurrence.sessionTitle}',
                style: CohortTextStyles.body,
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _selected = null),
              child: const Text('Clear'),
            ),
          ],
        ),
      );

  Future<void> _openDay(AthleteProgrammeWeekDayPresentation day) async {
    final calendar = _calendar;
    final occurrence = day.occurrence;
    if (calendar == null || occurrence == null) return;
    setState(() => _selected = occurrence);
    final changed = await openScheduledProgrammeSessionPreview(
      context: context,
      athleteId: widget.athleteId,
      calendar: calendar,
      day: day,
      previewService: widget.previewService,
    );
    if (changed == true && mounted) await _load();
  }

  FixedProgrammeOccurrenceProjection? _occurrenceOn(
    List<FixedProgrammeOccurrenceProjection> occurrences,
    DateTime date,
  ) {
    final iso =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    for (final occurrence in occurrences) {
      if (occurrence.scheduledDate == iso) return occurrence;
    }
    return null;
  }

  DateTime _monday(DateTime date) =>
      date.subtract(Duration(days: date.weekday - 1));
}

enum _CalendarLoadState { loading, loaded, empty, error }
