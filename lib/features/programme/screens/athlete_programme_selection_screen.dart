import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../home/controllers/home_today_session_refresh_controller.dart';
import '../controllers/athlete_programme_controllers.dart';
import '../models/athlete_catalogue_enrolment.dart';
import '../models/programme_catalog_entry.dart';
import '../services/athlete_catalogue_enrolment_services.dart';

/// Sprint 1.3 athlete catalogue: browse eligible programmes and enrol.
///
/// Non-commercial test / closed-beta enrolment. No purchase or ownership UI.
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
      AthleteCatalogueEnrolmentServices.createSelectionController(
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
    if (_controller.isCurrentProgramme(entry) || _controller.isSubmitting) {
      return;
    }

    _controller.selectProgramme(entry);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final hasActive = _controller.activeVersionId != null;
        return AlertDialog(
          title: Text('Enrol in ${entry.name}?'),
          content: Text(
            hasActive
                ? 'This will end your current programme enrolment and enrol you '
                      'in this programme version.\n\n'
                      'Your completed training history will be preserved.\n\n'
                      'This is programme access for testing — not a purchase.'
                : 'You will enrol in this exact programme version.\n\n'
                      'This is programme access for testing — not a purchase.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Enrol'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final result = await _controller.confirmEnrol(
      startedAt: DateTime.now(),
      timezone: DateTime.now().timeZoneName,
      replaceActive: _controller.activeVersionId != null,
    );

    if (!mounted || result == null) return;

    if (result.status == AthleteCatalogueEnrolmentStatus.alreadyEnrolled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Already enrolled.')),
      );
      return;
    }

    if (result.isSuccess) {
      widget.refreshController?.requestRefresh(
        source: 'athlete_catalogue_enrolment',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enrolled. Your programme is ready.')),
        );
      }
      Navigator.pop(context, true);
      return;
    }

    if (result.message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message!)));
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_controller.errorMessage!, style: CohortTextStyles.body),
            const SizedBox(height: CohortSpacing.md),
            TextButton(
              onPressed: _controller.isSubmitting ? null : _controller.load,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_controller.programmes.isEmpty) {
      return const CohortCard(
        child: Text(
          'No programmes are available in the catalogue right now.',
          style: CohortTextStyles.body,
        ),
      );
    }

    return Stack(
      children: [
        ListView.separated(
          itemCount: _controller.programmes.length,
          separatorBuilder: (_, __) => const SizedBox(height: CohortSpacing.sm),
          itemBuilder: (context, index) {
            final entry = _controller.programmes[index];
            final isCurrent = _controller.isCurrentProgramme(entry);
            return _AthleteProgrammeCatalogCard(
              entry: entry,
              isCurrent: isCurrent,
              onTap: (isCurrent || _controller.isSubmitting)
                  ? null
                  : () => _onProgrammeTap(entry),
            );
          },
        ),
        if (_controller.isSubmitting)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x66FFFFFF),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
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
                    'Enrolled',
                    style: CohortTextStyles.eyebrow.copyWith(
                      color: CohortColors.textMuted,
                    ),
                  ),
              ],
            ),
            if (entry.primaryGoal != null &&
                entry.primaryGoal!.trim().isNotEmpty) ...[
              const SizedBox(height: CohortSpacing.xs),
              Text(entry.primaryGoal!.trim(), style: CohortTextStyles.body),
            ],
            if (entry.description != null &&
                entry.description!.trim().isNotEmpty) ...[
              const SizedBox(height: CohortSpacing.xs),
              Text(
                entry.description!.trim(),
                style: CohortTextStyles.small,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: CohortSpacing.sm),
            Text(
              [
                if (entry.durationWeeks != null) '${entry.durationWeeks} weeks',
                if (entry.sessionsPerWeek != null)
                  '${entry.sessionsPerWeek}/week',
                if (entry.difficulty != null && entry.difficulty!.isNotEmpty)
                  entry.difficulty!,
                'v${entry.versionNumber}',
              ].where((part) => part.trim().isNotEmpty).join(' · '),
              style: CohortTextStyles.small.copyWith(
                color: CohortColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
