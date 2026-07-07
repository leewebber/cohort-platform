import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/attribute_grid.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../../core/widgets/metadata_row.dart';
import '../../../core/widgets/section_title.dart';
import '../../../models/exercise.dart';

class ExerciseDetailScreen extends StatelessWidget {
  const ExerciseDetailScreen({
    super.key,
    required this.exercise,
  });

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('← Back'),
              ),

              const SizedBox(height: CohortSpacing.md),

              SectionTitle(exercise.movementPattern ?? 'Exercise'),

              const SizedBox(height: CohortSpacing.sm),

              Text(
                exercise.name,
                style: CohortTextStyles.h1,
              ),

              const SizedBox(height: CohortSpacing.lg),

              MetadataRow(
                icon: Icons.fitness_center_outlined,
                text: exercise.equipment,
              ),
              MetadataRow(
                icon: Icons.accessibility_new_outlined,
                text: exercise.bodyRegion,
              ),
              MetadataRow(
                icon: Icons.speed_outlined,
                text: exercise.technicalComplexity,
              ),

              const SizedBox(height: CohortSpacing.xl),

              if (_hasText(exercise.purpose))
                _SectionCard(
                  title: 'Purpose',
                  child: Text(
                    exercise.purpose!,
                    style: CohortTextStyles.body,
                  ),
                ),

              if (_hasText(exercise.setup))
                _SectionCard(
                  title: 'Setup',
                  child: Text(
                    exercise.setup!,
                    style: CohortTextStyles.body,
                  ),
                ),

              if (_hasText(exercise.execution))
                _SectionCard(
                  title: 'Execution',
                  child: Text(
                    exercise.execution!,
                    style: CohortTextStyles.body,
                  ),
                ),

              if (_hasText(exercise.coachingCues))
                _SectionCard(
                  title: 'Coaching Cues',
                  child: Text(
                    exercise.coachingCues!,
                    style: CohortTextStyles.body,
                  ),
                ),

              if (_hasText(exercise.commonMistakes))
                _SectionCard(
                  title: 'Common Mistakes',
                  child: Text(
                    exercise.commonMistakes!,
                    style: CohortTextStyles.body,
                  ),
                ),

              const SizedBox(height: CohortSpacing.xl),

              const SectionTitle('Attributes'),

              const SizedBox(height: CohortSpacing.md),

              AttributeGrid(
                attributes: {
                  'Category': exercise.category,
                  'Movement Pattern': exercise.movementPattern,
                  'Movement Plane': exercise.movementPlane,
                  'Exercise Type': exercise.exerciseType,
                  'Body Region': exercise.bodyRegion,
                  'Primary Muscles': exercise.primaryMuscles,
                  'Secondary Muscles': exercise.secondaryMuscleGroups,
                  'Equipment': exercise.equipment,
                  'Equipment Category': exercise.equipmentCategory,
                  'Environment': exercise.environment,
                  'Primary Capability': exercise.primaryCapability,
                  'Technical Complexity': exercise.technicalComplexity,
                },
              ),

              const SizedBox(height: CohortSpacing.xl),

              const SectionTitle('Programming'),

              const SizedBox(height: CohortSpacing.md),

              AttributeGrid(
                attributes: {
                  'Best Used For': exercise.bestUsedFor,
                  'Loading Options': exercise.loadingOptions,
                  'Rep Range': exercise.repRangeGuidance,
                  'Tempo': exercise.tempoGuidance,
                  'Rest': exercise.restGuidance,
                },
              ),

              if (_hasText(exercise.regression) ||
                  _hasText(exercise.progression) ||
                  _hasText(exercise.scalingNotes)) ...[
                const SizedBox(height: CohortSpacing.xl),
                const SectionTitle('Scaling'),
                const SizedBox(height: CohortSpacing.md),
                AttributeGrid(
                  attributes: {
                    'Regression': exercise.regression,
                    'Progression': exercise.progression,
                    'Scaling Notes': exercise.scalingNotes,
                  },
                ),
              ],

              const SizedBox(height: CohortSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title),
          const SizedBox(height: CohortSpacing.md),
          CohortCard(child: child),
        ],
      ),
    );
  }
}