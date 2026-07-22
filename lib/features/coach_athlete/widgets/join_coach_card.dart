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

    final isDualRole = session.isCoach && session.isAthlete;
    final title = isDualRole ? 'Join a coach' : 'Join your coach';
    final body = isDualRole
        ? 'Prefer coach-led training? Link to another coach with an invitation code.'
        : 'Have an invitation code? Link to your coach to receive training.';

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: CohortTextStyles.cardTitle),
            const SizedBox(height: CohortSpacing.xs),
            Text(body, style: CohortTextStyles.body),
          ],
        ),
      ),
    );
  }
}
