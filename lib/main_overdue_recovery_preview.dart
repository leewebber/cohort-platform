import 'package:cohort_platform/app/theme.dart';
import 'package:cohort_platform/core/theme/text_styles.dart';
import 'package:cohort_platform/core/widgets/cohort_athlete_bottom_nav_bar.dart';
import 'package:cohort_platform/core/widgets/cohort_button.dart';
import 'package:cohort_platform/core/widgets/cohort_card.dart';
import 'package:cohort_platform/features/programme/models/fixed_programme_occurrence_projection.dart';
import 'package:cohort_platform/features/programme/presentation/athlete_calendar_agenda_presentation.dart';
import 'package:cohort_platform/features/programme/presentation/athlete_programme_lifecycle_presentation.dart';
import 'package:cohort_platform/features/programme/widgets/athlete_programme_week_agenda.dart';
import 'package:flutter/material.dart';

/// Local in-memory preview for Home command-centre states.
///
/// Launch:
///   flutter run -d web-server --web-port 4174 -t lib/main_overdue_recovery_preview.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(theme: cohortTheme, home: const _HomeCommandPreview()));
}

enum _PreviewDestination { home, calendar, progress }

enum _HomePreviewState {
  notStarted,
  inProgress,
  completeCollapsed,
  completeExpanded,
  firstPerformance,
  restDay,
  twoSessions,
}

class _HomeCommandPreview extends StatefulWidget {
  const _HomeCommandPreview();

  @override
  State<_HomeCommandPreview> createState() => _HomeCommandPreviewState();
}

class _HomeCommandPreviewState extends State<_HomeCommandPreview> {
  _PreviewDestination _destination = _PreviewDestination.home;
  _HomePreviewState _homeState = _HomePreviewState.notStarted;
  String? _expandedRowId = 'occ-incomplete';

  static const _homeStateLabels = {
    _HomePreviewState.notStarted: 'Today not started',
    _HomePreviewState.inProgress: 'Today in progress',
    _HomePreviewState.completeCollapsed: 'Complete, collapsed',
    _HomePreviewState.completeExpanded: 'Complete, expanded comparison',
    _HomePreviewState.firstPerformance: 'First performance',
    _HomePreviewState.restDay: 'Rest day',
    _HomePreviewState.twoSessions: 'Two sessions today',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_destination == _PreviewDestination.home
            ? 'Home'
            : _destination == _PreviewDestination.calendar
            ? 'Calendar'
            : 'Progress'),
        actions: [
          if (_destination == _PreviewDestination.home)
            PopupMenuButton<_HomePreviewState>(
              tooltip: 'Home preview state',
              initialValue: _homeState,
              onSelected: (value) => setState(() => _homeState = value),
              itemBuilder: (context) => [
                for (final entry in _homeStateLabels.entries)
                  PopupMenuItem(value: entry.key, child: Text(entry.value)),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: _destination == _PreviewDestination.home
                ? _homeBody()
                : _destination == _PreviewDestination.calendar
                ? _calendarBody()
                : _progressBody(),
          ),
        ),
      ),
      bottomNavigationBar: CohortAthleteBottomNavBar(
        selectedIndex: _destination.index,
        destinations: const [
          CohortAthleteNavDestination(
            label: 'Home',
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
          ),
          CohortAthleteNavDestination(
            label: 'Calendar',
            icon: Icons.calendar_view_week_outlined,
            selectedIcon: Icons.calendar_view_week_rounded,
          ),
          CohortAthleteNavDestination(
            label: 'Progress',
            icon: Icons.insights_outlined,
            selectedIcon: Icons.insights_rounded,
          ),
        ],
        onDestinationSelected: (index) {
          setState(() {
            _destination = _PreviewDestination.values[index];
          });
        },
      ),
    );
  }

  Widget _homeBody() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        switch (_homeState) {
          _HomePreviewState.notStarted => _todayCard(
            status: 'Not started',
            primary: 'Begin',
            showAdapt: true,
          ),
          _HomePreviewState.inProgress => _todayCard(
            status: 'In progress',
            primary: 'Resume',
            showAdapt: true,
          ),
          _HomePreviewState.completeCollapsed => _completedCard(
            expanded: false,
            hasComparison: true,
          ),
          _HomePreviewState.completeExpanded => _completedCard(
            expanded: true,
            hasComparison: true,
          ),
          _HomePreviewState.firstPerformance => _completedCard(
            expanded: true,
            hasComparison: false,
          ),
          _HomePreviewState.restDay => _restCard(),
          _HomePreviewState.twoSessions => Column(
            children: [
              _todayCard(
                status: 'Not started',
                primary: 'Begin',
                showAdapt: true,
              ),
              const SizedBox(height: 20),
              _todayCard(
                title: 'Evening Mobility',
                type: 'Recovery · Home · approximately 20 min',
                focus: 'Authored mobility finisher',
                status: 'Not started',
                primary: 'Begin',
                showAdapt: false,
                lines: const [
                  ('Couch Stretch', '2 × 60s / side'),
                  ('Cat-Camel', '2 × 8'),
                ],
              ),
            ],
          ),
        },
      ],
    );
  }

  Widget _todayCard({
    String title = 'Upper-body strength',
    String type = 'Strength · Gym · approximately 60 min',
    String focus = 'Upper-body strength and posterior-chain accessories',
    required String status,
    required String primary,
    required bool showAdapt,
    List<(String, String)> lines = const [
      ('Weighted Pull-Up', '4 × 5–6'),
      ('Incline DB Press', '4 × 8–10'),
      ('Seated Row', '3 × 10–12'),
    ],
  }) {
    return CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TODAY', style: CohortTextStyles.sectionLabel),
          const SizedBox(height: 4),
          const Text('Thursday 10 September', style: CohortTextStyles.muted),
          const SizedBox(height: 8),
          const Text('Apollo Strength', style: CohortTextStyles.small),
          const Text('Week 1 · Day 4', style: CohortTextStyles.small),
          const SizedBox(height: 12),
          Text(title, style: CohortTextStyles.h2),
          const SizedBox(height: 4),
          Text(type, style: CohortTextStyles.muted),
          const SizedBox(height: 8),
          Text(focus, style: CohortTextStyles.body),
          const SizedBox(height: 8),
          Text(status, style: CohortTextStyles.statusActive),
          const SizedBox(height: 12),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(child: Text(line.$1, style: CohortTextStyles.body)),
                  Text(line.$2, style: CohortTextStyles.muted),
                ],
              ),
            ),
          TextButton(
            onPressed: () {},
            child: const Text('View full session'),
          ),
          CohortButton(label: primary, onPressed: () {}),
          if (showAdapt)
            TextButton(onPressed: () {}, child: const Text('Adapt Session')),
        ],
      ),
    );
  }

  Widget _completedCard({
    required bool expanded,
    required bool hasComparison,
  }) {
    return CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TODAY', style: CohortTextStyles.sectionLabel),
          const SizedBox(height: 4),
          const Text('Thursday 10 September', style: CohortTextStyles.muted),
          const SizedBox(height: 8),
          const Text('Apollo Strength', style: CohortTextStyles.small),
          const SizedBox(height: 12),
          const Text('Upper-body strength', style: CohortTextStyles.h2),
          const SizedBox(height: 4),
          const Text('Complete', style: CohortTextStyles.statusActive),
          const SizedBox(height: 8),
          const Text(
            'Finished 11:42 · Duration 61m 01s · RPE 7',
            style: CohortTextStyles.small,
          ),
          const SizedBox(height: 8),
          const Text(
            'Weighted Pull-Up · 4 sets recorded',
            style: CohortTextStyles.body,
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _homeState = expanded
                    ? _HomePreviewState.completeCollapsed
                    : _HomePreviewState.completeExpanded;
              });
            },
            child: Text(expanded ? 'Hide results' : 'Show results'),
          ),
          if (expanded && hasComparison) ...[
            const Text('Weighted Pull-Up', style: CohortTextStyles.cardTitle),
            const Text('Best set 5 @ 32.5 kg', style: CohortTextStyles.small),
            const Text('Improved', style: CohortTextStyles.small),
            const Text(
              'Previous: 30 kg 5 reps',
              style: CohortTextStyles.muted,
            ),
          ],
          if (expanded && !hasComparison)
            const Text(
              'First recorded performance — no previous comparable result.',
              style: CohortTextStyles.small,
            ),
          CohortButton(
            label: 'View results',
            variant: CohortButtonVariant.secondary,
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _restCard() {
    return const CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TODAY', style: CohortTextStyles.sectionLabel),
          SizedBox(height: 4),
          Text('Sunday 6 September', style: CohortTextStyles.muted),
          SizedBox(height: 8),
          Text('Apollo Strength', style: CohortTextStyles.small),
          SizedBox(height: 12),
          Text('Rest day', style: CohortTextStyles.h2),
          SizedBox(height: 8),
          Text(
            'No training session is scheduled for this programme date.',
            style: CohortTextStyles.body,
          ),
          SizedBox(height: 12),
          Text(
            'Next: Apollo Strength · Tomorrow',
            style: CohortTextStyles.muted,
          ),
        ],
      ),
    );
  }

  Widget _calendarBody() {
    final calendar = _previewCalendar();
    final rows = AthleteCalendarAgendaFormatter.weekRows(
      calendar: calendar,
      weekStart: DateTime(2026, 9, 7),
    );
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('THIS WEEK', style: CohortTextStyles.sectionLabel),
        const SizedBox(height: 4),
        Text(
          AthleteProgrammeDateFormatter.dateRange(
            DateTime(2026, 9, 7),
            DateTime(2026, 9, 13),
          ),
          style: CohortTextStyles.small,
        ),
        const SizedBox(height: 12),
        AthleteProgrammeWeekAgenda(
          rows: rows,
          expandedRowId: _expandedRowId,
          onToggleRow: (row) {
            setState(() {
              _expandedRowId = _expandedRowId == row.rowId ? null : row.rowId;
            });
          },
          onOpenSession: (_) {},
        ),
      ],
    );
  }

  Widget _progressBody() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('PROGRESS', style: CohortTextStyles.sectionLabel),
        const SizedBox(height: 12),
        CohortCard(
          child: const Text(
            'Trends, history and programme development live here. Home does not embed this destination.',
            style: CohortTextStyles.body,
          ),
        ),
      ],
    );
  }
}

FixedProgrammeCalendarProjection _previewCalendar() {
  FixedProgrammeOccurrenceProjection session({
    required String id,
    required String date,
    required FixedProgrammeOccurrenceState state,
    required String title,
    required String type,
    int order = 1,
    String? originalDate,
  }) {
    return FixedProgrammeOccurrenceProjection(
      assignmentId: 'preview',
      occurrenceId: id,
      sessionSlotId: 'slot-$id',
      programmeVersionId: 'version',
      protocolId: 'APOLLO',
      programmedSessionKey: 'preview-$id',
      weekNumber: 1,
      dayKey: 'day_$order',
      sessionOrder: order,
      scheduledDate: date,
      originalScheduledDate: originalDate ?? date,
      state: state,
      sessionTitle: title,
      sessionType: type,
    );
  }

  return FixedProgrammeCalendarProjection(
    assignmentId: 'preview',
    programmeName: 'Apollo Build — 12-Week Initial Block',
    timezone: 'Atlantic/Canary',
    scheduleMode: 'fixed_schedule',
    startDate: '2026-09-01',
    today: '2026-09-10',
    weekStart: '2026-09-07',
    weekEnd: '2026-09-13',
    occurrences: [
      session(
        id: 'occ-complete',
        date: '2026-09-07',
        state: FixedProgrammeOccurrenceState.completed,
        title: 'Apollo Strength',
        type: 'Strength · Gym',
      ),
      session(
        id: 'occ-incomplete',
        date: '2026-09-08',
        state: FixedProgrammeOccurrenceState.overdue,
        title: 'Apollo Intervals',
        type: 'Run',
      ),
      session(
        id: 'occ-zone2',
        date: '2026-09-09',
        state: FixedProgrammeOccurrenceState.completed,
        title: 'Zone 2 Run',
        type: 'Endurance',
      ),
      session(
        id: 'occ-today-a',
        date: '2026-09-10',
        state: FixedProgrammeOccurrenceState.today,
        title: 'Apollo Strength',
        type: 'Strength · Gym',
      ),
      session(
        id: 'occ-interval',
        date: '2026-09-11',
        state: FixedProgrammeOccurrenceState.planned,
        title: 'Interval Run',
        type: 'Run',
      ),
    ],
    currentWeek: const [],
  );
}
