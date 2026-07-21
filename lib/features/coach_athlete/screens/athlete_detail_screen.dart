import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../../core/widgets/section_title.dart';
import '../../programme/models/programme_catalog_entry.dart';
import '../controllers/coach_athlete_controllers.dart';
import '../models/coach_athlete_roster_entry.dart';
import '../services/coach_athlete_services.dart';

class AthleteDetailScreen extends StatefulWidget {
  const AthleteDetailScreen({
    super.key,
    required this.athlete,
  });

  final CoachAthleteRosterEntry athlete;

  @override
  State<AthleteDetailScreen> createState() => _AthleteDetailScreenState();
}

class _AthleteDetailScreenState extends State<AthleteDetailScreen> {
  late final AthleteDetailController _controller = AthleteDetailController(
    service: CoachAthleteServices.createService(),
    athlete: widget.athlete,
  );

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _controller.load();
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _showAssignSheet() async {
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
                  bottom: MediaQuery.viewInsetsOf(context).bottom + CohortSpacing.lg,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Assign programme', style: CohortTextStyles.h2),
                      const SizedBox(height: CohortSpacing.sm),
                      Text(
                        'Choose a published programme and start date for '
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
                      if (_controller.hasActiveAssignment) ...[
                        const SizedBox(height: CohortSpacing.sm),
                        Text(
                          'This athlete already has an active programme. '
                          'Confirming will replace it.',
                          style: CohortTextStyles.small.copyWith(
                            color: CohortColors.warning,
                          ),
                        ),
                      ],
                      const SizedBox(height: CohortSpacing.lg),
                      CohortButton(
                        label: _controller.isAssigning
                            ? 'Assigning…'
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
                                  replaceExisting: _controller.hasActiveAssignment,
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
              CohortButton(
                label: 'Assign programme',
                onPressed: _controller.status == AthleteDetailStatus.ready
                    ? _showAssignSheet
                    : () {},
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

    return ListView(
      children: [
        const SectionTitle('Current assignment'),
        const SizedBox(height: CohortSpacing.sm),
        CohortCard(
          child: Text(
            _controller.hasActiveAssignment
                ? '${_controller.activeProgrammeName ?? widget.athlete.activeProgrammeName ?? 'Programme'} · '
                    '${_controller.activeProgrammeVersionLabel ?? widget.athlete.activeProgrammeVersionLabel ?? ''}'
                : 'No active programme assigned.',
            style: CohortTextStyles.body,
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
}
