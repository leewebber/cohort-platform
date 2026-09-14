import 'package:cohort_platform/app/theme.dart';
import 'package:cohort_platform/features/performance/models/active_performance_draft.dart';
import 'package:cohort_platform/features/performance/models/previous_strength_performance.dart';
import 'package:cohort_platform/features/performance/services/performance_snapshot_builder.dart';
import 'package:cohort_platform/features/performance/widgets/performance_capture_widgets.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/strength_exercise_prescription.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter/material.dart';

/// Local preview: Apollo Week 2 Strength Day 1 previous-performance states.
/// Does not contact Field Manual.
///
///   flutter run -d chrome --web-port 4174 -t lib/main_week2_previous_strength_preview.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(theme: cohortTheme, home: const _Week2PreviousPreview()),
  );
}

class _Week2PreviousPreview extends StatefulWidget {
  const _Week2PreviousPreview();

  @override
  State<_Week2PreviousPreview> createState() => _Week2PreviousPreviewState();
}

class _Week2PreviousPreviewState extends State<_Week2PreviousPreview> {
  var _mode = PreviousStrengthHistoryStatus.ready;
  final _block = _apolloWeek2Upper();
  late BlockPerformanceDraft _draft = const PerformanceSnapshotBuilder()
      .buildInitialBlockDrafts(
        SessionExecutionPlan(
          sessionId: 'apollo-w2-mon-preview',
          sessionTitle: 'Apollo W2 · Strength Day 1',
          blocks: [_apolloWeek2Upper()],
        ),
      )
      .single;

  PreviousStrengthHistoryState get _history {
    switch (_mode) {
      case PreviousStrengthHistoryStatus.loading:
        return const PreviousStrengthHistoryState.loading();
      case PreviousStrengthHistoryStatus.failed:
        return const PreviousStrengthHistoryState.failed();
      case PreviousStrengthHistoryStatus.idle:
        return const PreviousStrengthHistoryState.idle();
      case PreviousStrengthHistoryStatus.ready:
        return PreviousStrengthHistoryState.ready({
          'EX-095': PreviousStrengthExerciseEvidence(
            exerciseId: 'EX-095',
            recordId: '5981c74a-aa66-42f5-aed4-1a4538a6d616',
            performedAt: DateTime.utc(2026, 9, 7, 15, 37),
            sets: const [
              PreviousStrengthSetEvidence(
                setNumber: 1,
                reps: 5,
                load: 10,
                loadUnit: 'kg',
              ),
              PreviousStrengthSetEvidence(
                setNumber: 2,
                reps: 5,
                load: 15,
                loadUnit: 'kg',
              ),
              PreviousStrengthSetEvidence(
                setNumber: 3,
                reps: 5,
                load: 20,
                loadUnit: 'kg',
              ),
              PreviousStrengthSetEvidence(
                setNumber: 4,
                reps: 8,
                load: 15,
                loadUnit: 'kg',
              ),
            ],
          ),
          'EX-138': PreviousStrengthExerciseEvidence(
            exerciseId: 'EX-138',
            recordId: '5981c74a-aa66-42f5-aed4-1a4538a6d616',
            performedAt: DateTime.utc(2026, 9, 7, 15, 37),
            sets: const [
              PreviousStrengthSetEvidence(
                setNumber: 1,
                reps: 15,
                load: 10,
                loadUnit: 'kg',
              ),
              PreviousStrengthSetEvidence(
                setNumber: 2,
                reps: 15,
                load: 10,
                loadUnit: 'kg',
              ),
              PreviousStrengthSetEvidence(
                setNumber: 3,
                reps: 5,
                load: 10,
                loadUnit: 'kg',
              ),
            ],
          ),
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Week 2 previous strength')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text('Fixtures only. Pull-Up has Week 1 evidence. Press is first recorded. Lateral raise maps 3 prior sets onto 4 current sets.'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final status in PreviousStrengthHistoryStatus.values)
                      ChoiceChip(
                        label: Text(status.name),
                        selected: _mode == status,
                        onSelected: (_) => setState(() => _mode = status),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                BlockResultEditor(
                  blockDraft: _draft,
                  linkedExercises: _block.linkedExercises,
                  previousStrengthHistory: _history,
                  onRetryPreviousStrength: () => setState(
                    () => _mode = PreviousStrengthHistoryStatus.ready,
                  ),
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

SessionExecutionBlock _apolloWeek2Upper() {
  return const SessionExecutionBlock(
    blockId: 'apollo-w2-upper-preview',
    title: 'Main strength',
    blockType: SessionBlockType.strength,
    content: '',
    workoutFormat: WorkoutFormat.none,
    position: 2,
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
        exerciseId: 'EX-138',
        displayName: 'Cable Lateral Raise',
        prescription: StrengthExercisePrescription(
          sets: 4,
          reps: StrengthRepPrescription(
            type: StrengthRepType.range,
            minReps: 12,
            maxReps: 15,
          ),
        ),
      ),
    ],
  );
}
