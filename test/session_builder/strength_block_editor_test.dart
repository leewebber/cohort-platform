import 'package:cohort_platform/features/session_builder/widgets/session_block_editor_card.dart';
import 'package:cohort_platform/models/exercise.dart';
import 'package:cohort_platform/models/session_block.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('strength block shows Add exercise control', (tester) async {
    final block = SessionBlock.create(
      blockType: SessionBlockType.strength,
      position: 1,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SessionBlockEditorCard(
              block: block,
              exercises: const [
                Exercise(
                  exerciseId: 'PULL-001',
                  name: 'Weighted Pull-up',
                  published: true,
                  category: 'Strength',
                ),
              ],
              canMoveUp: false,
              canMoveDown: false,
              onChanged: (_) {},
              onMoveUp: () {},
              onMoveDown: () {},
              onDuplicate: () {},
              onDelete: () {},
              onWorkoutFormatChanged: (_) {},
              onTimerConfigurationChanged: (_) {},
              onAddExercise: (_) {},
              onRemoveExercise: (_) {},
              onMoveExerciseUp: (_) {},
              onMoveExerciseDown: (_) {},
              onExerciseLabelChanged: (_, __) {},
              onUpsertStrengthExercise: ({
                required exercise,
                required prescription,
                linkLocalId,
              }) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('+ Add exercise'), findsOneWidget);
    expect(find.text('Block instructions (optional)'), findsOneWidget);
    expect(find.text('Workout content'), findsNothing);
  });

  testWidgets('warm-up block does not show strength exercise editor', (tester) async {
    final block = SessionBlock.create(
      blockType: SessionBlockType.warmUp,
      position: 1,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SessionBlockEditorCard(
              block: block,
              exercises: const [],
              canMoveUp: false,
              canMoveDown: false,
              onChanged: (_) {},
              onMoveUp: () {},
              onMoveDown: () {},
              onDuplicate: () {},
              onDelete: () {},
              onWorkoutFormatChanged: (_) {},
              onTimerConfigurationChanged: (_) {},
              onAddExercise: (_) {},
              onRemoveExercise: (_) {},
              onMoveExerciseUp: (_) {},
              onMoveExerciseDown: (_) {},
              onExerciseLabelChanged: (_, __) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('+ Add exercise'), findsNothing);
    expect(find.text('Workout content'), findsOneWidget);
  });
}
