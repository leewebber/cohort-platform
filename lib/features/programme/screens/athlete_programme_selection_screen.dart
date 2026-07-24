import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../home/controllers/home_today_session_refresh_controller.dart';
import '../controllers/athlete_programme_controllers.dart';
import '../models/athlete_programme_switch_result.dart';
import '../models/programme_catalog_entry.dart';
import '../services/athlete_programme_switch_services.dart';

class AthleteProgrammeSelectionScreen extends StatefulWidget {
  const AthleteProgrammeSelectionScreen({
    super.key,
    required this.athleteId,
    this.refreshController,
    AthleteProgrammeSelectionController? controller,
  }) : _controller = controller;

  final String athleteId;
  final HomeTodaySessionRefreshController? refreshController;
  final AthleteProgrammeSelectionController? _controller;

  @override
  State<AthleteProgrammeSelectionScreen> createState() =>
      _AthleteProgrammeSelectionScreenState();
}

class _AthleteProgrammeSelectionScreenState
    extends State<AthleteProgrammeSelectionScreen> {
  late final AthleteProgrammeSelectionController _controller =
      widget._controller ??
      AthleteProgrammeSwitchServices.createSelectionController(
        athleteId: widget.athleteId,
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
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _onProgrammeTap(ProgrammeCatalogEntry entry) async {
    if (_controller.isCurrentProgramme(entry)) return;

    _controller.selectProgramme(entry);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Start ${entry.name}?'),
          content: const Text(
            'Starting this programme will end your current active programme.\n\n'
            'Your completed training history will be preserved.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Start Programme'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final result = await _controller.confirmSwitch(
      startedAt: DateTime.now(),
      timezone: DateTime.now().timeZoneName,
    );

    if (!mounted || result == null) return;

    if (result.status == AthleteProgrammeSwitchStatus.alreadyActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Already active.')),
      );
      return;
    }

    if (result.isSuccess) {
      widget.refreshController?.requestRefresh(
        source: 'athlete_programme_switch',
      );
      Navigator.pop(context, true);
      return;
    }

    if (result.message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose programme')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(CohortSpacing.lg),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_controller.errorMessage != null) {
      return CohortCard(
        child: Text(
          _controller.errorMessage!,
          style: CohortTextStyles.body,
        ),
      );
    }

    if (_controller.programmes.isEmpty) {
      return const CohortCard(
        child: Text(
          'No published programmes are available right now.',
          style: CohortTextStyles.body,
        ),
      );
    }

    return ListView.separated(
      itemCount: _controller.programmes.length,
      separatorBuilder: (_, __) => const SizedBox(height: CohortSpacing.sm),
      itemBuilder: (context, index) {
        final entry = _controller.programmes[index];
        final isCurrent = _controller.isCurrentProgramme(entry);
        return _AthleteProgrammeCatalogCard(
          entry: entry,
          isCurrent: isCurrent,
          onTap: isCurrent ? null : () => _onProgrammeTap(entry),
        );
      },
    );
  }
}

class _AthleteProgrammeCatalogCard extends StatelessWidget {
  const _AthleteProgrammeCatalogCard({
    required this.entry,
    required this.isCurrent,
    this.onTap,
  });

  final ProgrammeCatalogEntry entry;
  final bool isCurrent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isCurrent ? 0.55 : 1,
      child: CohortCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(entry.name, style: CohortTextStyles.cardTitle),
                ),
                if (isCurrent)
                  Text(
                    'Current',
                    style: CohortTextStyles.eyebrow.copyWith(
                      color: CohortColors.textMuted,
                    ),
                  ),
              ],
            ),
            if (entry.primaryGoal != null &&
                entry.primaryGoal!.trim().isNotEmpty) ...[
              const SizedBox(height: CohortSpacing.xs),
              Text(entry.primaryGoal!.trim(), style: CohortTextStyles.small),
            ],
            if (entry.durationWeeks != null) ...[
              const SizedBox(height: CohortSpacing.xs),
              Text(
                '${entry.durationWeeks} weeks',
                style: CohortTextStyles.small,
              ),
            ],
            if (entry.sessionsPerWeek != null) ...[
              const SizedBox(height: CohortSpacing.xs),
              Text(
                '${entry.sessionsPerWeek} sessions per week',
                style: CohortTextStyles.small,
              ),
            ],
            if (entry.equipmentRequirements != null &&
                entry.equipmentRequirements!.trim().isNotEmpty) ...[
              const SizedBox(height: CohortSpacing.xs),
              Text(
                entry.equipmentRequirements!.trim(),
                style: CohortTextStyles.small,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
