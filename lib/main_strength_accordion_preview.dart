import 'package:cohort_platform/app/theme.dart';
import 'package:cohort_platform/features/performance/models/active_performance_draft.dart';
import 'package:cohort_platform/features/performance/services/performance_snapshot_builder.dart';
import 'package:cohort_platform/features/performance/widgets/performance_capture_widgets.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/workout_player/models/previous_performance_snapshot.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/strength_exercise_prescription.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter/material.dart';

/// Local in-memory iPhone-width preview for strength exercise accordions.
///
/// Does not contact hosted Supabase, mutate production data, or install over
/// Lee's device build.
///
/// Launch:
///   flutter run -d chrome --web-port 4173 -t lib/main_strength_accordion_preview.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  PreviousPerformanceStore.replaceAll([
    PreviousPerformanceSnapshot(
      exerciseId: 'EX-095',
      sessionType: PreviousPerformanceSessionType.strength,
      performedAt: DateTime.utc(2026, 8, 3),
      repSummary: '6, 6, 5, 5',
      loadSummary: '+10 kg',
    ),
  ]);

  runApp(
    MaterialApp(theme: cohortTheme, home: const _StrengthAccordionPreview()),
  );
}

class _StrengthAccordionPreview extends StatefulWidget {
  const _StrengthAccordionPreview();

  @override
  State<_StrengthAccordionPreview> createState() =>
      _StrengthAccordionPreviewState();
}

class _StrengthAccordionPreviewState extends State<_StrengthAccordionPreview> {
  final _block = _apolloWeek1Upper();
  late BlockPerformanceDraft _draft = const PerformanceSnapshotBuilder()
      .buildInitialBlockDrafts(
        SessionExecutionPlan(
          sessionId: 'apollo-w1-mon-preview',
          sessionTitle: 'Apollo W1 · Upper Strength',
          blocks: [_apolloWeek1Upper()],
        ),
      )
      .single;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Strength accordion preview')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                24 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              children: [
                const Text('Apollo W1 Upper · local preview'),
                const SizedBox(height: 16),
                BlockResultEditor(
                  blockDraft: _draft,
                  linkedExercises: _block.linkedExercises,
                  onResultChanged: (_) {},
                  onAddSet: (_) {},
                  onUpdateSet: (exerciseId, setResultId, update) {
                    setState(() {
                      _draft = _draft.copyWith(
                        exerciseResults: [
                          for (final exercise in _draft.exerciseResults)
                            if (exercise.sourceExerciseId != exerciseId)
                              exercise
                            else
                              exercise.copyWith(
                                sets: [
                                  for (final set in exercise.sets)
                                    if (set.setResultId == setResultId)
                                      update(set)
                                    else
                                      set,
                                ],
                              ),
                        ],
                      );
                    });
                  },
                  onDuplicateSet: (_, _) {},
                  onRemoveSet: (_, _) {},
                  onOpenExercise: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

SessionExecutionBlock _apolloWeek1Upper() {
  return const SessionExecutionBlock(
    blockId: 'apollo-w1-upper-preview',
    title: 'Upper Strength',
    blockType: SessionBlockType.strength,
    content: '',
    workoutFormat: WorkoutFormat.none,
    position: 1,
    linkedExercises: [
      SessionExecutionExerciseSummary(
        exerciseId: 'EX-095',
        displayName: 'Weighted Pull-Up',
        prescription: StrengthExercisePrescription(
          sets: 4,
          reps: StrengthRepPrescription(
            type: StrengthRepType.range,
            minReps: 5,
            maxReps: 6,
          ),
          restSeconds: 180,
        ),
      ),
      SessionExecutionExerciseSummary(
        exerciseId: 'EX-136',
        displayName: 'Incline Barbell Bench Press',
        prescription: StrengthExercisePrescription(
          sets: 4,
          reps: StrengthRepPrescription(
            type: StrengthRepType.range,
            minReps: 6,
            maxReps: 8,
          ),
        ),
      ),
      SessionExecutionExerciseSummary(
        exerciseId: 'EX-088',
        displayName: 'Standing Overhead Press',
        prescription: StrengthExercisePrescription(
          sets: 3,
          reps: StrengthRepPrescription(
            type: StrengthRepType.range,
            minReps: 6,
            maxReps: 8,
          ),
        ),
      ),
      SessionExecutionExerciseSummary(
        exerciseId: 'EX-090',
        displayName: 'Chest-Supported Row',
        prescription: StrengthExercisePrescription(
          sets: 3,
          reps: StrengthRepPrescription(
            type: StrengthRepType.range,
            minReps: 8,
            maxReps: 10,
          ),
        ),
      ),
      SessionExecutionExerciseSummary(
        exerciseId: 'EX-138',
        displayName: 'Cable Lateral Raise',
        prescription: StrengthExercisePrescription(
          sets: 3,
          reps: StrengthRepPrescription(
            type: StrengthRepType.range,
            minReps: 12,
            maxReps: 15,
          ),
        ),
      ),
      SessionExecutionExerciseSummary(
        exerciseId: 'EX-087',
        displayName: 'Weighted Dip',
        prescription: StrengthExercisePrescription(
          sets: 3,
          reps: StrengthRepPrescription(
            type: StrengthRepType.range,
            minReps: 6,
            maxReps: 10,
          ),
        ),
      ),
      SessionExecutionExerciseSummary(
        exerciseId: 'EX-139',
        displayName: 'Overhead Cable Triceps Extension',
        prescription: StrengthExercisePrescription(
          sets: 3,
          reps: StrengthRepPrescription(
            type: StrengthRepType.range,
            minReps: 10,
            maxReps: 12,
          ),
        ),
      ),
    ],
  );
}
