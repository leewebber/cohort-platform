import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/exercise_card.dart';
import '../../../core/widgets/search_bar.dart';
import '../../../core/widgets/section_title.dart';
import '../../../data/repositories/exercise_repository.dart';
import '../../../models/exercise.dart';
import '../exercise_detail/exercise_detail_screen.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  final ExerciseRepository _repository = ExerciseRepository();

  late Future<List<Exercise>> _future;

  String _search = '';

  @override
  void initState() {
    super.initState();
    _future = _repository.getExercises();
  }

  void _openExerciseDetail(Exercise exercise) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseDetailScreen(exercise: exercise),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<Exercise>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  snapshot.error.toString(),
                  style: CohortTextStyles.body,
                ),
              );
            }

            var exercises = snapshot.data ?? [];

            if (_search.isNotEmpty) {
              final query = _search.toLowerCase();

              exercises = exercises.where((exercise) {
                return exercise.name.toLowerCase().contains(query) ||
                    (exercise.movementPattern ?? '')
                        .toLowerCase()
                        .contains(query) ||
                    (exercise.primaryMuscles ?? '')
                        .toLowerCase()
                        .contains(query) ||
                    (exercise.equipment ?? '').toLowerCase().contains(query);
              }).toList();
            }

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
                  const SectionTitle('Knowledge Base'),
                  const SizedBox(height: CohortSpacing.sm),
                  const Text(
                    'Exercise Library',
                    style: CohortTextStyles.h1,
                  ),
                  const SizedBox(height: CohortSpacing.md),
                  const Text(
                    'Browse the exercise knowledge base.',
                    style: CohortTextStyles.body,
                  ),
                  const SizedBox(height: CohortSpacing.xl),
                  CohortSearchBar(
                    hintText: 'Search exercises...',
                    onChanged: (value) {
                      setState(() {
                        _search = value;
                      });
                    },
                  ),
                  const SizedBox(height: CohortSpacing.xl),
                  Text(
                    '${exercises.length} Exercises',
                    style: CohortTextStyles.muted,
                  ),
                  const SizedBox(height: CohortSpacing.lg),
                  ...exercises.map(
                    (exercise) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ExerciseCard(
                        exercise: exercise,
                        onTap: () => _openExerciseDetail(exercise),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
