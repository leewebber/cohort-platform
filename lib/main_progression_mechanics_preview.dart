import 'package:cohort_platform/app/theme.dart';
import 'package:cohort_platform/features/performance/models/performance_snapshot.dart';
import 'package:cohort_platform/features/performance/models/training_session_record.dart';
import 'package:cohort_platform/features/performance/progression/endurance_progression.dart';
import 'package:cohort_platform/features/performance/progression/progression_comparison.dart';
import 'package:cohort_platform/features/performance/progression/strength_progression.dart';
import 'package:cohort_platform/features/performance/models/performance_result_data.dart';
import 'package:flutter/material.dart';

/// Local preview: Progression Mechanics v1 states. Does not contact Field Manual.
///
///   flutter run -d chrome --web-port 4175 -t lib/main_progression_mechanics_preview.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(theme: cohortTheme, home: const _Preview()));
}

class _Case {
  const _Case(this.title, this.comparison);
  final String title;
  final ProgressionComparison comparison;
}

class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) {
    final cases = _cases();
    return Scaffold(
      appBar: AppBar(title: const Text('Progression Mechanics v1')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: cases.length,
        separatorBuilder: (_, _) => const Divider(),
        itemBuilder: (context, index) {
          final item = cases[index];
          return ListTile(
            title: Text(item.title),
            subtitle: Text(
              '${item.comparison.outcome.label}\n'
              '${item.comparison.summary}\n'
              'confidence: ${item.comparison.confidence.name}\n'
              '${item.comparison.deltas.map((d) => d.label).join(' · ')}',
            ),
            isThreeLine: true,
          );
        },
      ),
    );
  }
}

TrainingSetResult _set(double load, int reps, {int n = 1, int? rpe}) {
  return TrainingSetResult(
    setResultId: '$n',
    exerciseResultId: 'e',
    setNumber: n,
    position: n,
    load: load,
    loadUnit: 'kg',
    reps: reps,
    rpe: rpe,
    completed: true,
  );
}

StrengthProgressionFacts _facts(List<TrainingSetResult> sets, {int? prescribed}) {
  return StrengthProgressionFacts(
    exerciseId: 'EX-095',
    loadKind: StrengthActualLoadKind.external,
    sets: sets,
    prescribedSetCount: prescribed,
  );
}

List<_Case> _cases() {
  const w1 = [
    TrainingSetResult(
      setResultId: '1',
      exerciseResultId: 'e',
      setNumber: 1,
      position: 1,
      load: 10,
      loadUnit: 'kg',
      reps: 5,
      completed: true,
    ),
  ];
  return [
    _Case('1 Strength — first performance', StrengthProgressionComparison.compare(current: _facts(w1))),
    _Case(
      '2 Strength — improved',
      StrengthProgressionComparison.compare(
        current: _facts([_set(15, 5)]),
        previous: _facts([_set(10, 5)]),
      ),
    ),
    _Case(
      '3 Strength — matched',
      StrengthProgressionComparison.compare(
        current: _facts([_set(10, 5)]),
        previous: _facts([_set(10, 5)]),
      ),
    ),
    _Case(
      '4 Strength — mixed',
      StrengthProgressionComparison.compare(
        current: _facts([_set(90, 3)]),
        previous: _facts([_set(80, 5)]),
      ),
    ),
    _Case(
      '5 Strength — below last performance',
      StrengthProgressionComparison.compare(
        current: _facts([_set(8, 5)]),
        previous: _facts([_set(10, 5)]),
      ),
    ),
    _Case(
      '6 Strength — changed prescription',
      StrengthProgressionComparison.compare(
        current: _facts([_set(10, 12), _set(10, 12, n: 2), _set(10, 12, n: 3), _set(10, 12, n: 4)], prescribed: 4),
        previous: _facts([_set(10, 15), _set(10, 15, n: 2), _set(10, 15, n: 3)], prescribed: 3),
      ),
    ),
    _Case(
      '7 Strength — precise PB (heaviest displayed as improved)',
      StrengthProgressionComparison.compare(
        current: _facts([_set(20, 5)]),
        previous: _facts([_set(10, 5)]),
      ),
    ),
    _Case(
      '10 Endurance — factual evidence without false verdict',
      EnduranceProgressionComparison.compare(
        current: const EnduranceResultData(distance: 5, durationSeconds: 1400),
        previous: const EnduranceResultData(distance: 5, durationSeconds: 1500),
      ),
    ),
    const _Case(
      '17 Retrieval failure/retry',
      ProgressionComparison(
        outcome: ProgressionOutcome.insufficientEvidence,
        confidence: EvidenceConfidence.none,
        summary: 'Couldn’t load previous performance',
      ),
    ),
  ];
}
