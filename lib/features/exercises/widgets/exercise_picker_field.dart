import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/search_bar.dart';
import '../../../models/exercise.dart';
import '../services/exercise_catalogue_service.dart';

class ExercisePickerField extends StatefulWidget {
  const ExercisePickerField({
    super.key,
    required this.catalogueLoader,
    required this.onSelected,
    this.initialExercise,
    this.initialExerciseId,
    this.maxVisibleResults = 6,
  });

  final ExerciseCatalogueLoader catalogueLoader;
  final ValueChanged<Exercise> onSelected;
  final Exercise? initialExercise;
  final String? initialExerciseId;
  final int maxVisibleResults;

  @override
  State<ExercisePickerField> createState() => ExercisePickerFieldState();
}

class ExercisePickerFieldState extends State<ExercisePickerField> {
  late Future<List<Exercise>> _catalogueFuture;
  String _search = '';
  Exercise? _selectedExercise;
  String? _errorMessage;
  List<Exercise>? _loadedCatalogue;

  @override
  void initState() {
    super.initState();
    _selectedExercise = widget.initialExercise;
    _catalogueFuture = widget.catalogueLoader.loadPublishedExercises();
  }

  @override
  void didUpdateWidget(covariant ExercisePickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialExercise?.exerciseId != oldWidget.initialExercise?.exerciseId) {
      _selectedExercise = widget.initialExercise;
    }
  }

  void _select(Exercise exercise) {
    setState(() {
      _selectedExercise = exercise;
      _errorMessage = null;
    });
    widget.onSelected(exercise);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Exercise>>(
      future: _catalogueFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: CohortSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Exercise', style: CohortTextStyles.eyebrow),
              const SizedBox(height: CohortSpacing.sm),
              Text(
                'Exercises could not be loaded right now. Please try again.',
                style: CohortTextStyles.body.copyWith(color: CohortColors.danger),
              ),
            ],
          );
        }

        final catalogue = snapshot.data ?? const <Exercise>[];
        _loadedCatalogue = catalogue;
        final resolvedSelection = selectedExercise;

        if (catalogue.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Exercise', style: CohortTextStyles.eyebrow),
              const SizedBox(height: CohortSpacing.sm),
              Text(
                'No exercises are available in the library yet. Add exercises to the library before prescribing strength work.',
                style: CohortTextStyles.body,
              ),
            ],
          );
        }

        final filtered =
            ExerciseCatalogueService.filter(catalogue, _search).take(widget.maxVisibleResults);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Exercise', style: CohortTextStyles.eyebrow),
            const SizedBox(height: CohortSpacing.sm),
            if (resolvedSelection != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(CohortSpacing.md),
                decoration: BoxDecoration(
                  color: CohortColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CohortColors.olive),
                ),
                child: Text(resolvedSelection.name, style: CohortTextStyles.body),
              ),
              const SizedBox(height: CohortSpacing.sm),
            ],
            CohortSearchBar(
              hintText: 'Search exercises...',
              onChanged: (value) => setState(() => _search = value),
            ),
            const SizedBox(height: CohortSpacing.sm),
            if (_search.trim().isNotEmpty && filtered.isEmpty)
              Text(
                'No exercises match your search.',
                style: CohortTextStyles.small.copyWith(
                  color: CohortColors.textSecondary,
                ),
              ),
            for (final exercise in filtered)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(exercise.name, style: CohortTextStyles.body),
                trailing: resolvedSelection?.exerciseId == exercise.exerciseId
                    ? const Icon(Icons.check, color: CohortColors.olive, size: 18)
                    : null,
                onTap: () => _select(exercise),
              ),
            if (_errorMessage != null) ...[
              const SizedBox(height: CohortSpacing.xs),
              Text(
                _errorMessage!,
                style: CohortTextStyles.small.copyWith(color: CohortColors.danger),
              ),
            ],
          ],
        );
      },
    );
  }

  Exercise? get selectedExercise {
    if (_selectedExercise != null) {
      return _selectedExercise;
    }
    final catalogue = _loadedCatalogue;
    final exerciseId = widget.initialExerciseId?.trim();
    if (catalogue != null && exerciseId != null && exerciseId.isNotEmpty) {
      return ExerciseCatalogueService.findById(catalogue, exerciseId);
    }
    return null;
  }

  void showSelectionRequiredError() {
    setState(() {
      _errorMessage = 'Select an exercise from the library.';
    });
  }
}
