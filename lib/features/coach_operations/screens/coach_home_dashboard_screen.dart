import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../../core/widgets/section_title.dart';
import '../../coach_athlete/controllers/athlete_roster_controller.dart';
import '../services/coach_athlete_daily_status_service.dart';
import '../../coach_athlete/screens/athlete_detail_screen.dart';
import '../../coach_athlete/services/coach_athlete_services.dart';
import '../controllers/coach_home_dashboard_controller.dart';
import '../models/coach_athlete_daily_snapshot.dart';
import '../services/coach_operations_services.dart';
import '../widgets/coach_athlete_operational_card.dart';

class CoachHomeDashboardScreen extends StatefulWidget {
  const CoachHomeDashboardScreen({
    super.key,
    this.controller,
    this.dailyStatusService,
  });

  final CoachHomeDashboardController? controller;
  final CoachAthleteDailyStatusService? dailyStatusService;

  @override
  State<CoachHomeDashboardScreen> createState() =>
      _CoachHomeDashboardScreenState();
}

class _CoachHomeDashboardScreenState extends State<CoachHomeDashboardScreen> {
  late final CoachHomeDashboardController _controller =
      widget.controller ??
          CoachHomeDashboardController(
            dailyStatusService:
                widget.dailyStatusService ??
                    CoachOperationsServices.createDailyStatusService(),
          );

  late final AthleteRosterController _rosterController = AthleteRosterController(
    service: CoachAthleteServices.createService(),
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
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _showInviteSheet() async {
    final invite = await _rosterController.createInvite();
    if (!mounted || invite == null) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(CohortSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invitation created', style: CohortTextStyles.h2),
                const SizedBox(height: CohortSpacing.sm),
                Text(
                  'Share this code with your athlete. It expires in 7 days.',
                  style: CohortTextStyles.body.copyWith(
                    color: CohortColors.textSecondary,
                  ),
                ),
                const SizedBox(height: CohortSpacing.lg),
                _InviteCodeDisplay(code: invite.code),
                const SizedBox(height: CohortSpacing.lg),
                CohortButton(
                  label: 'Copy code',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: invite.code));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invitation code copied')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openAthlete(CoachAthleteDailySnapshot snapshot) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AthleteDetailScreen(athlete: snapshot.rosterEntry),
      ),
    ).then((_) {
      if (mounted) _controller.load();
    });
  }

  void _openAssign(CoachAthleteDailySnapshot snapshot) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AthleteDetailScreen(
          athlete: snapshot.rosterEntry,
          openAssignOnLoad: true,
        ),
      ),
    ).then((_) {
      if (mounted) _controller.load();
    });
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
              const SectionTitle('Coach Home'),
              const SizedBox(height: CohortSpacing.sm),
              Text('My Athletes', style: CohortTextStyles.h1),
              const SizedBox(height: CohortSpacing.sm),
              Text(
                'See who trained, who is due today, and who needs attention.',
                style: CohortTextStyles.body,
              ),
              const SizedBox(height: CohortSpacing.lg),
              CohortButton(
                label: _rosterController.isCreatingInvite
                    ? 'Creating invite…'
                    : 'Invite athlete',
                onPressed:
                    _rosterController.isCreatingInvite ? () {} : _showInviteSheet,
              ),
              const SizedBox(height: CohortSpacing.lg),
              _FilterBar(
                activeFilter: _controller.activeFilter,
                onFilterSelected: _controller.setFilter,
              ),
              const SizedBox(height: CohortSpacing.md),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return switch (_controller.status) {
      CoachHomeDashboardStatus.loading => const Center(
          child: CircularProgressIndicator(),
        ),
      CoachHomeDashboardStatus.coachRoleRequired => _MessageCard(
          message: 'A coach profile is required to view athlete operations.',
        ),
      CoachHomeDashboardStatus.error => _MessageCard(
          message: _controller.errorMessage ?? 'Unable to load coach dashboard.',
          actionLabel: 'Retry',
          onAction: _controller.load,
        ),
      CoachHomeDashboardStatus.empty => _MessageCard(
          message:
              'No athletes linked yet. Invite an athlete to start coaching.',
        ),
      CoachHomeDashboardStatus.ready => RefreshIndicator(
          onRefresh: _controller.load,
          child: _buildSnapshotList(),
        ),
    };
  }

  Widget _buildSnapshotList() {
    final snapshots = _controller.filteredSnapshots;

    if (snapshots.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _MessageCard(
            message:
                'No athletes match "${_controller.activeFilter.label}".',
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: snapshots.length,
      separatorBuilder: (_, _) => const SizedBox(height: CohortSpacing.md),
      itemBuilder: (context, index) {
        final snapshot = snapshots[index];
        return CoachAthleteOperationalCard(
          snapshot: snapshot,
          onOpenAthlete: () => _openAthlete(snapshot),
          onAssignProgramme: () => _openAssign(snapshot),
        );
      },
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.activeFilter,
    required this.onFilterSelected,
  });

  final CoachDashboardFilter activeFilter;
  final ValueChanged<CoachDashboardFilter> onFilterSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in CoachDashboardFilter.values) ...[
            Padding(
              padding: const EdgeInsets.only(right: CohortSpacing.sm),
              child: FilterChip(
                label: Text(filter.label),
                selected: activeFilter == filter,
                onSelected: (_) => onFilterSelected(filter),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InviteCodeDisplay extends StatelessWidget {
  const _InviteCodeDisplay({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(CohortSpacing.lg),
      decoration: BoxDecoration(
        color: CohortColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CohortColors.border),
      ),
      child: Text(
        code,
        textAlign: TextAlign.center,
        style: CohortTextStyles.h1.copyWith(letterSpacing: 4),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: CohortTextStyles.body),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: CohortSpacing.sm),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
