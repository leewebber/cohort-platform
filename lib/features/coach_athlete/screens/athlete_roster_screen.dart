import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../../core/widgets/section_title.dart';
import '../controllers/athlete_roster_controller.dart';
import '../models/coach_athlete_invite.dart';
import '../services/coach_athlete_services.dart';
import 'athlete_detail_screen.dart';

class AthleteRosterScreen extends StatefulWidget {
  const AthleteRosterScreen({super.key});

  @override
  State<AthleteRosterScreen> createState() => _AthleteRosterScreenState();
}

class _AthleteRosterScreenState extends State<AthleteRosterScreen> {
  late final AthleteRosterController _controller = AthleteRosterController(
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
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _showInviteSheet() async {
    final invite = await _controller.createInvite();
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
              const SectionTitle('Athletes'),
              const SizedBox(height: CohortSpacing.sm),
              Text('Your roster', style: CohortTextStyles.h1),
              const SizedBox(height: CohortSpacing.sm),
              Text(
                'Invite private athletes and assign their training.',
                style: CohortTextStyles.body,
              ),
              const SizedBox(height: CohortSpacing.lg),
              CohortButton(
                label: _controller.isCreatingInvite
                    ? 'Creating invite…'
                    : 'Invite athlete',
                onPressed: _controller.isCreatingInvite ? () {} : _showInviteSheet,
              ),
              const SizedBox(height: CohortSpacing.lg),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return switch (_controller.status) {
      AthleteRosterStatus.loading => const Center(
          child: CircularProgressIndicator(),
        ),
      AthleteRosterStatus.coachRoleRequired => _MessageCard(
          message: 'A coach profile is required to manage athletes.',
        ),
      AthleteRosterStatus.error => _MessageCard(
          message: _controller.errorMessage ?? 'Unable to load roster.',
          actionLabel: 'Retry',
          onAction: _controller.load,
        ),
      AthleteRosterStatus.empty => _MessageCard(
          message:
              'No athletes linked yet. Create an invitation and share the code.',
        ),
      AthleteRosterStatus.ready => RefreshIndicator(
          onRefresh: _controller.load,
          child: ListView(
            children: [
              if (_controller.pendingInvites.isNotEmpty) ...[
                const SectionTitle('Pending invitations'),
                const SizedBox(height: CohortSpacing.sm),
                for (final invite in _controller.pendingInvites)
                  _PendingInviteCard(
                    invite: invite,
                    onRevoke: () => _controller.revokeInvite(invite.id),
                  ),
                const SizedBox(height: CohortSpacing.lg),
              ],
              const SectionTitle('Linked athletes'),
              const SizedBox(height: CohortSpacing.sm),
              for (final athlete in _controller.athletes)
                Padding(
                  padding: const EdgeInsets.only(bottom: CohortSpacing.md),
                  child: CohortCard(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AthleteDetailScreen(athlete: athlete),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(athlete.displayName, style: CohortTextStyles.cardTitle),
                        const SizedBox(height: CohortSpacing.xs),
                        Text(
                          athlete.hasActiveAssignment
                              ? '${athlete.activeProgrammeName ?? 'Programme'} · ${athlete.activeProgrammeVersionLabel ?? ''}'
                              : 'No active programme',
                          style: CohortTextStyles.body,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
    };
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

class _PendingInviteCard extends StatelessWidget {
  const _PendingInviteCard({
    required this.invite,
    required this.onRevoke,
  });

  final CoachAthleteInvite invite;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.sm),
      child: CohortCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(invite.code, style: CohortTextStyles.cardTitle),
                  const SizedBox(height: CohortSpacing.xs),
                  Text(
                    'Expires ${_formatDate(invite.expiresAt)}',
                    style: CohortTextStyles.small,
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onRevoke, child: const Text('Revoke')),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.toLocal().day}/${date.toLocal().month}/${date.toLocal().year}';
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
