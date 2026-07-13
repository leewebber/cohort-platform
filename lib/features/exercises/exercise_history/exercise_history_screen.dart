import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../models/exercise.dart';
import '../../../models/exercise_history.dart';
import '../services/exercise_history_service.dart';
import 'widgets/exercise_history_session_card.dart';

/// Athlete notebook view of completed performances for one exercise.
class ExerciseHistoryScreen extends StatefulWidget {
  const ExerciseHistoryScreen({
    super.key,
    required this.exercise,
    required this.athleteId,
    this.historyService,
  });

  final Exercise exercise;
  final String athleteId;
  final ExerciseHistoryService? historyService;

  @override
  State<ExerciseHistoryScreen> createState() => _ExerciseHistoryScreenState();
}

class _ExerciseHistoryScreenState extends State<ExerciseHistoryScreen> {
  late final Future<ExerciseHistory> _historyFuture;
  late final ExerciseHistoryService _historyService;

  @override
  void initState() {
    super.initState();
    _historyService = widget.historyService ?? ExerciseHistoryService();
    _historyFuture = _historyService.buildHistory(
      athleteId: widget.athleteId.trim(),
      exerciseId: widget.exercise.exerciseId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<ExerciseHistory>(
          future: _historyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Loading exercise history...',
                  style: CohortTextStyles.body,
                ),
              );
            }

            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('← Back'),
                    ),
                    const SizedBox(height: CohortSpacing.md),
                    Text(
                      'Exercise history could not be loaded.',
                      style: CohortTextStyles.body,
                    ),
                  ],
                ),
              );
            }

            final history = snapshot.data ??
                ExerciseHistory(
                  exerciseId: widget.exercise.exerciseId,
                  sessions: const [],
                );

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('← Back'),
                  ),
                  const SizedBox(height: CohortSpacing.md),
                  Text(
                    'EXERCISE HISTORY',
                    style: CohortTextStyles.eyebrow,
                  ),
                  const SizedBox(height: CohortSpacing.sm),
                  Text(
                    widget.exercise.name,
                    style: CohortTextStyles.h1,
                  ),
                  if (widget.exercise.equipment?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: CohortSpacing.xs),
                    Text(
                      widget.exercise.equipment!.trim(),
                      style: CohortTextStyles.small,
                    ),
                  ],
                  const SizedBox(height: CohortSpacing.sm),
                  Text(
                    history.hasHistory
                        ? '${history.sessionCount} session'
                            '${history.sessionCount == 1 ? '' : 's'} recorded'
                        : 'No sessions recorded yet',
                    style: CohortTextStyles.body,
                  ),
                  const SizedBox(height: CohortSpacing.xl),
                  if (!history.hasHistory)
                    Text(
                      'No recorded performances yet. Your first logged session will appear here.',
                      style: CohortTextStyles.body,
                    )
                  else
                    for (var index = 0; index < history.sessions.length; index++) ...[
                      if (index > 0) const SizedBox(height: CohortSpacing.md),
                      ExerciseHistorySessionCard(
                        session: history.sessions[index],
                      ),
                    ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
