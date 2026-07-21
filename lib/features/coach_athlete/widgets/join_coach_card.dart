import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../auth/services/current_user_session.dart';
import '../screens/join_coach_screen.dart';

class JoinCoachCard extends StatelessWidget {
  const JoinCoachCard({
    super.key,
    required this.onJoined,
  });

  final VoidCallback onJoined;

  @override
  Widget build(BuildContext context) {
    final session = CurrentUserSession.maybeInstance;
    if (session == null || !session.isAthlete) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.md),
      child: CohortCard(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => JoinCoachScreen(onJoined: onJoined),
            ),
          );
        },
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Join your coach', style: CohortTextStyles.cardTitle),
            SizedBox(height: CohortSpacing.xs),
            Text(
              'Have an invitation code? Link to your coach to receive training.',
              style: CohortTextStyles.body,
            ),
          ],
        ),
      ),
    );
  }
}
