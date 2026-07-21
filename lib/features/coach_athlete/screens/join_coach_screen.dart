import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/cohort_card.dart';
import '../controllers/coach_athlete_controllers.dart';
import '../services/coach_athlete_services.dart';

class JoinCoachScreen extends StatefulWidget {
  const JoinCoachScreen({
    super.key,
    this.onJoined,
  });

  final VoidCallback? onJoined;

  @override
  State<JoinCoachScreen> createState() => _JoinCoachScreenState();
}

class _JoinCoachScreenState extends State<JoinCoachScreen> {
  final _codeController = TextEditingController();
  late final JoinCoachController _controller = JoinCoachController(
    service: CoachAthleteServices.createService(),
  );

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _controller.checkExistingRelationship();
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _codeController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final success = await _controller.acceptInvite(_codeController.text);
    if (success) {
      widget.onJoined?.call();
    }
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
              const SizedBox(height: CohortSpacing.lg),
              Text('Join your coach', style: CohortTextStyles.h1),
              const SizedBox(height: CohortSpacing.sm),
              Text(
                'Enter the private invitation code your coach shared with you.',
                style: CohortTextStyles.body.copyWith(
                  color: CohortColors.textSecondary,
                ),
              ),
              const SizedBox(height: CohortSpacing.xl),
              Text('INVITATION CODE', style: CohortTextStyles.eyebrow),
              const SizedBox(height: CohortSpacing.xs),
              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: CohortColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (_controller.status == JoinCoachStatus.success) ...[
                const SizedBox(height: CohortSpacing.md),
                CohortCard(
                  child: Text(
                    'You are now linked with '
                    '${_controller.coachDisplayName ?? 'your coach'}.',
                    style: CohortTextStyles.body,
                  ),
                ),
              ],
              if (_controller.errorMessage != null) ...[
                const SizedBox(height: CohortSpacing.sm),
                Text(
                  _controller.errorMessage!,
                  style: CohortTextStyles.small.copyWith(
                    color: CohortColors.warning,
                  ),
                ),
              ],
              const Spacer(),
              CohortButton(
                label: _controller.status == JoinCoachStatus.submitting
                    ? 'Joining…'
                    : 'Join coach',
                onPressed: _controller.status == JoinCoachStatus.submitting
                    ? () {}
                    : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
