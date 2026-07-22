import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../../core/widgets/section_title.dart';
import '../../coach_operations/services/coach_operations_services.dart';
import '../../performance/screens/training_history_screen.dart';
import '../../programme/models/programme_catalog_entry.dart';
import '../controllers/coach_athlete_controllers.dart';
import '../models/coach_athlete_roster_entry.dart';
import '../services/coach_athlete_services.dart';

class AthleteDetailScreen extends StatefulWidget {
  const AthleteDetailScreen({
    super.key,
    required this.athlete,
    this.openAssignOnLoad = false,
    this.controller,
  });

  final CoachAthleteRosterEntry athlete;
  final bool openAssignOnLoad;
  final AthleteDetailController? controller;

  @override
  State<AthleteDetailScreen> createState() => _AthleteDetailScreenState();
}

class _AthleteDetailScreenState extends State<AthleteDetailScreen> {
  late final AthleteDetailController _controller = widget.controller ??
      AthleteDetailController(
        service: CoachAthleteServices.createService(),
        athlete: widget.athlete,
        dailyStatusService: CoachOperationsServices.createDailyStatusService(),
      );

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _controller.load().then((_) {
      if (widget.openAssignOnLoad && mounted) {
        _showAssignSheet(replaceExisting: _controller.hasActiveAssignment);
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _showAssignSheet({bool replaceExisting = false}) async {
    if (_controller.publishedProgrammes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No published programmes are available to assign.'),
        ),
      );
      return;
    }

    ProgrammeCatalogEntry? selected = _controller.publishedProgrammes.first;
    DateTime startDate = DateTime.now();
    final timezone = DateTime.now().timeZoneName;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: CohortSpacing.lg,
                  right: CohortSpacing.lg,
                  top: CohortSpacing.lg,
                  bottom:
                      MediaQuery.viewInsetsOf(context).bottom + CohortSpacing.lg,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        replaceExisting ? 'Replace programme' : 'Assign programme',
                        style: CohortTextStyles.h2,
                      ),
                      const SizedBox(height: CohortSpacing.sm),
                      Text(
                        replaceExisting
                            ? 'Choose a new programme to replace the current assignment for '
                                '${widget.athlete.displayName}.'
                            : 'Choose a published programme and start date for '
                                '${widget.athlete.displayName}.',
                        style: CohortTextStyles.body.copyWith(
                          color: CohortColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: CohortSpacing.lg),
                      DropdownButtonFormField<ProgrammeCatalogEntry>(
                        initialValue: selected,
                        decoration: const InputDecoration(labelText: 'Programme'),
                        items: _controller.publishedProgrammes
                            .map(
                              (entry) => DropdownMenuItem(
                                value: entry,
                                child: Text(
                                  '${entry.name} · Version ${entry.versionNumber}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setSheetState(() => selected = value);
                        },
                      ),
                      const SizedBox(height: CohortSpacing.md),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Start date'),
                        subtitle: Text(
                          '${startDate.day}/${startDate.month}/${startDate.year}',
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: startDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setSheetState(() => startDate = picked);
                          }
                        },
                      ),
                      if (replaceExisting) ...[
                        const SizedBox(height: CohortSpacing.sm),
                        Text(
                          'Confirming will replace the current active programme.',
                          style: CohortTextStyles.small.copyWith(
                            color: CohortColors.warning,
                          ),
                        ),
                      ],
                      const SizedBox(height: CohortSpacing.lg),
                      CohortButton(
                        label: _controller.isAssigning
                            ? 'Assigning…'
                            : replaceExisting
                                ? 'Confirm replacement'
                                : 'Confirm assignment',
                        onPressed: _controller.isAssigning
                            ? () {}
                            : () async {
                                final entry = selected;
                                if (entry == null) return;

                                final success = await _controller.assignProgramme(
                                  entry: entry,
                                  startDate: startDate,
                                  timezone: timezone,
                                  replaceExisting: replaceExisting,
                                );

                                if (!context.mounted) return;
                                if (success) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        _controller.assignmentSuccessMessage ??
                                            'Programme assigned.',
                                      ),
                                    ),
                                  );
                                }
                              },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrainingHistoryScreen(
          athleteId: widget.athlete.athleteId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(CohortSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('← Back'),
              ),
              Text(widget.athlete.displayName, style: CohortTextStyles.h1),
              const SizedBox(height: CohortSpacing.lg),
              Expanded(child: _buildBody()),
              _QuickActions(
                hasActiveAssignment: _controller.hasActiveAssignment,
                onAssign: () => _showAssignSheet(),
                onReplace: () => _showAssignSheet(replaceExisting: true),
                onViewHistory: _openHistory,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.status == AthleteDetailStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_controller.status == AthleteDetailStatus.error) {
      return CohortCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _controller.errorMessage ?? 'Unable to load athlete details.',
              style: CohortTextStyles.body,
            ),
            TextButton(onPressed: _controller.load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final snapshot = _controller.operationalSnapshot;

    return ListView(
      children: [
        const SectionTitle('Current programme'),
        const SizedBox(height: CohortSpacing.sm),
        CohortCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                snapshot?.programmeName ??
                    _controller.activeProgrammeName ??
                    widget.athlete.activeProgrammeName ??
                    'No active programme assigned.',
                style: CohortTextStyles.cardTitle,
              ),
              if (_controller.hasActiveAssignment) ...[
                if (snapshot?.weekDayLabel != null) ...[
                  const SizedBox(height: CohortSpacing.xs),
                  Text(snapshot!.weekDayLabel!, style: CohortTextStyles.body),
                ],
                if (snapshot?.progressLabel != null) ...[
                  const SizedBox(height: CohortSpacing.xs),
                  Text(
                    snapshot!.progressLabel!,
                    style: CohortTextStyles.small.copyWith(
                      color: CohortColors.textSecondary,
                    ),
                  ),
                ],
                if (_controller.activeProgrammeVersionLabel != null) ...[
                  const SizedBox(height: CohortSpacing.xs),
                  Text(
                    _controller.activeProgrammeVersionLabel!,
                    style: CohortTextStyles.small.copyWith(
                      color: CohortColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: CohortSpacing.lg),
        const SectionTitle('Compliance'),
        const SizedBox(height: CohortSpacing.sm),
        CohortCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                snapshot?.complianceLabel ?? 'No programme assigned',
                style: CohortTextStyles.body.copyWith(
                  color: snapshot?.needsAttention == true
                      ? CohortColors.warning
                      : null,
                ),
              ),
              if (snapshot?.todayStatusLabel != null) ...[
                const SizedBox(height: CohortSpacing.xs),
                Text(
                  'Today: ${snapshot!.todayStatusLabel}',
                  style: CohortTextStyles.small.copyWith(
                    color: CohortColors.textSecondary,
                  ),
                ),
              ],
              if (snapshot?.lastActivityLabel != null) ...[
                const SizedBox(height: CohortSpacing.xs),
                Text(
                  'Last activity: ${snapshot!.lastActivityLabel}',
                  style: CohortTextStyles.small.copyWith(
                    color: CohortColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (_controller.latestAdaptation != null) ...[
          const SizedBox(height: CohortSpacing.lg),
          const SectionTitle('Latest adaptation'),
          const SizedBox(height: CohortSpacing.sm),
          CohortCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _controller.latestAdaptation!.explanation,
                  style: CohortTextStyles.body,
                ),
                if (_controller
                    .latestAdaptation!.affectedSlotIds.isNotEmpty) ...[
                  const SizedBox(height: CohortSpacing.sm),
                  Text(
                    'Affected future sessions: '
                    '${_controller.latestAdaptation!.affectedSlotIds.length}',
                    style: CohortTextStyles.small.copyWith(
                      color: CohortColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: CohortSpacing.lg),
        const SectionTitle('Recent sessions'),
        const SizedBox(height: CohortSpacing.sm),
        if (_controller.recentSessions.isEmpty)
          const CohortCard(
            child: Text(
              'No completed sessions recorded yet.',
              style: CohortTextStyles.body,
            ),
          )
        else
          for (final record in _controller.recentSessions)
            Padding(
              padding: const EdgeInsets.only(bottom: CohortSpacing.sm),
              child: CohortCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.sessionSnapshot.sessionTitle.isNotEmpty
                          ? record.sessionSnapshot.sessionTitle
                          : (record.sourceProtocolId ?? 'Session'),
                      style: CohortTextStyles.cardTitle,
                    ),
                    if (record.completedAt != null) ...[
                      const SizedBox(height: CohortSpacing.xs),
                      Text(
                        _formatDate(record.completedAt!.toLocal()),
                        style: CohortTextStyles.small.copyWith(
                          color: CohortColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        if (_controller.errorMessage != null) ...[
          const SizedBox(height: CohortSpacing.sm),
          Text(
            _controller.errorMessage!,
            style: CohortTextStyles.small.copyWith(color: CohortColors.warning),
          ),
        ],
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.hasActiveAssignment,
    required this.onAssign,
    required this.onReplace,
    required this.onViewHistory,
  });

  final bool hasActiveAssignment;
  final VoidCallback onAssign;
  final VoidCallback onReplace;
  final VoidCallback onViewHistory;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CohortButton(
          label: hasActiveAssignment ? 'Replace programme' : 'Assign programme',
          onPressed: hasActiveAssignment ? onReplace : onAssign,
        ),
        const SizedBox(height: CohortSpacing.sm),
        CohortButton(
          label: 'View history',
          onPressed: onViewHistory,
        ),
      ],
    );
  }
}
