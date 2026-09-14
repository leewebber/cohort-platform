import 'package:cohort_platform/features/performance/models/training_session_record.dart';
import 'package:cohort_platform/features/performance/progression/personal_bests.dart';
import 'package:cohort_platform/features/performance/progression/progression_comparison.dart';
import 'package:cohort_platform/features/performance/progression/progression_mechanics_fixtures.dart';
import 'package:cohort_platform/features/performance/progression/strength_progression.dart';
import 'package:cohort_platform/features/performance/services/completed_session_result_projection.dart';
import 'package:cohort_platform/features/progress/services/athlete_progress_evidence_projection.dart';
import 'package:cohort_platform/features/progress/services/athlete_progress_summary_builder.dart';
import 'package:cohort_platform/features/progress/services/capability_radar_projection_service.dart';
import 'package:cohort_platform/features/session/models/strength_set_entry.dart';
import 'package:cohort_platform/features/session/services/strength_progress_service.dart';
import 'package:cohort_platform/models/exercise_progress_result.dart';
import 'package:cohort_platform/models/previous_exercise_performance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ({
    ProgressionComparison engine,
    ExerciseProgressResult player,
    CompletedExerciseResultProjection results,
    String progressLabel,
    String? progressPb,
    List<PersonalBest> pbs,
  }) project({
    required TrainingSessionRecord current,
    TrainingSessionRecord? previous,
    List<TrainingSessionRecord> extraHistory = const [],
  }) {
    final history = [
      ?previous,
      ...extraHistory,
      current,
    ];
    final currentEx = current.blockResults.first.exerciseResults.first;
    final previousEx = previous?.blockResults.first.exerciseResults.first;
    final engine = StrengthProgressionComparison.compare(
      current: StrengthProgressionFacts.fromExercise(currentEx),
      previous: previousEx == null
          ? null
          : StrengthProgressionFacts.fromExercise(previousEx),
    );
    final pbs = PersonalBestEvaluator.announcedForCurrent(
      athleteId: current.athleteId,
      exerciseId: currentEx.sourceExerciseId,
      current: current,
      history: history,
    );
    final player = const StrengthProgressService().evaluate(
      previousPerformance: previousEx == null
          ? null
          : PreviousExercisePerformance(
              performedAt: previous!.performanceChronologyAt,
              sets: [
                for (final set in previousEx.setResults)
                  PreviousPerformedSet(
                    loadLabel: '${set.load?.toStringAsFixed(0)}kg',
                    reps: '${set.reps}',
                    displayLine: '${set.load} × ${set.reps}',
                    rpe: set.rpe?.toDouble(),
                  ),
              ],
            ),
      todayCompletedSets: [
        for (final set in currentEx.setResults)
          StrengthSetEntry(
            localId: set.setResultId,
            setNumber: set.setNumber,
            actualReps: '${set.reps}',
            load: set.load == null ? null : '${set.load}kg',
            rpe: set.rpe,
            completed: set.completed,
          ),
      ],
      exerciseId: currentEx.sourceExerciseId,
      personalBests: pbs,
    );
    final results = CompletedSessionResultProjection.fromRecords(
      record: current,
      athleteHistory: history,
    ).blocks.first.exercises.first;
    final progress = AthleteProgressEvidenceProjection.exerciseBests(
      AthleteProgressEvidenceProjection.completedRecords(history),
    ).firstWhere((best) => best.exerciseId == currentEx.sourceExerciseId);
    return (
      engine: engine,
      player: player,
      results: results,
      progressLabel: progress.comparisonLabel,
      progressPb: progress.personalBestLabel,
      pbs: pbs,
    );
  }

  void expectSurfacesAgree(
    dynamic surfaces, {
    required ProgressionOutcome outcome,
    String? summaryContains,
  }) {
    expect(surfaces.engine.outcome, outcome);
    expect(surfaces.player.title, outcome.label);
    expect(surfaces.results.comparisonLabel, outcome.label);
    expect(surfaces.results.comparisonHighlight, surfaces.engine.conciseHighlight);
    expect(surfaces.progressLabel, surfaces.engine.conciseHighlight);
    expect(surfaces.player.message, surfaces.engine.summary);
    if (summaryContains != null) {
      expect(surfaces.engine.summary, contains(summaryContains));
    }
  }

  test('Improved — 1 more rep at the same load is identical on every surface', () {
    final surfaces = project(
      current: ProgressionMechanicsFixtures.improved20x6(),
      previous: ProgressionMechanicsFixtures.previous20x5(),
    );
    expectSurfacesAgree(
      surfaces,
      outcome: ProgressionOutcome.improved,
      summaryContains: '1 more rep at the same load',
    );
    expect(surfaces.engine.conciseHighlight, 'Improved — 1 more rep at the same load');
    expect(
      surfaces.pbs.map((best) => best.kind),
      contains(PersonalBestKind.repsAtLoad),
    );
    expect(surfaces.results.personalBestLabels, isNotEmpty);
    expect(surfaces.progressPb, isNotNull);
  });

  test('Matched is identical on every surface', () {
    expectSurfacesAgree(
      project(
        current: ProgressionMechanicsFixtures.matched20x5(),
        previous: ProgressionMechanicsFixtures.previous20x5(),
      ),
      outcome: ProgressionOutcome.matched,
    );
  });

  test('Mixed is identical on every surface', () {
    expectSurfacesAgree(
      project(
        current: ProgressionMechanicsFixtures.mixed90x3(),
        previous: ProgressionMechanicsFixtures.previous80x5(),
      ),
      outcome: ProgressionOutcome.mixed,
    );
  });

  test('Below last performance is identical on every surface', () {
    expectSurfacesAgree(
      project(
        current: ProgressionMechanicsFixtures.below18x5(),
        previous: ProgressionMechanicsFixtures.previous20x5(),
      ),
      outcome: ProgressionOutcome.belowLastPerformance,
    );
  });

  test('Not comparable is identical on every surface', () {
    expectSurfacesAgree(
      project(
        current: ProgressionMechanicsFixtures.notComparableBodyweight(),
        previous: ProgressionMechanicsFixtures.previous20x5(),
      ),
      outcome: ProgressionOutcome.notComparable,
    );
  });

  test('First performance is identical on every surface', () {
    expectSurfacesAgree(
      project(current: ProgressionMechanicsFixtures.first20x5()),
      outcome: ProgressionOutcome.firstPerformance,
    );
  });

  test('Insufficient evidence when today has no completed sets', () {
    final player = const StrengthProgressService().evaluate(
      previousPerformance: PreviousExercisePerformance(
        performedAt: DateTime.utc(2026, 9, 7),
        sets: const [
          PreviousPerformedSet(
            loadLabel: '20kg',
            reps: '5',
            displayLine: '20kg × 5',
          ),
        ],
      ),
      todayCompletedSets: const [],
      exerciseId: 'EX-095',
    );
    expect(player.title, 'Insufficient evidence');
  });

  test('precise PB is heaviest completed load, not every improved set', () {
    final improved = project(
      current: ProgressionMechanicsFixtures.improved20x6(),
      previous: ProgressionMechanicsFixtures.previous20x5(),
    );
    expect(
      improved.pbs.map((best) => best.kind),
      isNot(contains(PersonalBestKind.heaviestLoad)),
    );
    final pb = project(
      current: ProgressionMechanicsFixtures.precisePb25x5(),
      previous: ProgressionMechanicsFixtures.previous20x5(),
    );
    expect(pb.pbs.first.kind, PersonalBestKind.heaviestLoad);
    expect(pb.pbs.first.detail, contains('25'));
    expect(
      pb.pbs.map((best) => best.kind),
      isNot(contains(PersonalBestKind.repsAtLoad)),
    );
  });

  test('changed prescription is not Improved from extra sets', () {
    expectSurfacesAgree(
      project(
        current: ProgressionMechanicsFixtures.changedPrescription4x10x12(),
        previous: ProgressionMechanicsFixtures.previous3x10x15(),
      ),
      outcome: ProgressionOutcome.mixed,
    );
  });

  test('partially completed session still uses completed actuals', () {
    expectSurfacesAgree(
      project(
        current: ProgressionMechanicsFixtures.partial20x6(),
        previous: ProgressionMechanicsFixtures.previous20x5(),
      ),
      outcome: ProgressionOutcome.improved,
      summaryContains: '1 more rep at the same load',
    );
  });

  test('correction recomputation changes the verdict', () {
    final before = project(
      current: ProgressionMechanicsFixtures.improved20x6(),
      previous: ProgressionMechanicsFixtures.previous20x5(),
    );
    final after = project(
      current: ProgressionMechanicsFixtures.corrected18x5(),
      previous: ProgressionMechanicsFixtures.previous20x5(),
    );
    expect(before.engine.outcome, ProgressionOutcome.improved);
    expect(after.engine.outcome, ProgressionOutcome.belowLastPerformance);
    expect(after.player.title, after.results.comparisonLabel);
  });

  test('older Backfill chronology is the prior', () {
    expectSurfacesAgree(
      project(
        current: ProgressionMechanicsFixtures.improved20x6(),
        previous: ProgressionMechanicsFixtures.olderBackfill20x5(),
      ),
      outcome: ProgressionOutcome.improved,
    );
  });

  test('two completed strength sessions do not raise Strength capability', () {
    final completed = [
      ProgressionMechanicsFixtures.previous20x5(),
      ProgressionMechanicsFixtures.improved20x6(),
    ];
    expect(
      AthleteProgressEvidenceProjection.strengthSessionCount(completed),
      2,
    );
    const radar = CapabilityRadarProjectionService();
    final model = radar.project(
      timeline: AthleteProgressSummaryBuilder.emptySummary().timeline,
      strengthSessionCount: 2,
      enduranceSessionCount: 0,
    );
    for (final dimension in [
      CapabilityRadarDimension.strength,
      CapabilityRadarDimension.endurance,
      CapabilityRadarDimension.threshold,
      CapabilityRadarDimension.power,
      CapabilityRadarDimension.durability,
      CapabilityRadarDimension.mobility,
    ]) {
      final axis = model.axes.firstWhere((item) => item.dimension == dimension);
      expect(axis.available, isFalse, reason: dimension.name);
      expect(axis.normalisedValue, isNull, reason: dimension.name);
    }
  });
}
