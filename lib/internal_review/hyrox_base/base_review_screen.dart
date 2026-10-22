import 'package:flutter/material.dart';

import '../../domain/hyrox_base/base_personalisation.dart';
import 'base_review_controller.dart';

class BaseReviewScreen extends StatefulWidget {
  const BaseReviewScreen({super.key});
  @override
  State<BaseReviewScreen> createState() => _BaseReviewScreenState();
}

class _BaseReviewScreenState extends State<BaseReviewScreen> {
  BaseReviewController controller = BaseReviewController('synthetic-a');
  final value = TextEditingController();
  final date = TextEditingController(text: '2026-10-22');
  final source = TextEditingController();
  final increment = TextEditingController();
  BaseMetric metric = BaseMetric.run10km;
  BaseInputUnit unit = BaseInputUnit.seconds;
  BaseSourceType sourceType = BaseSourceType.knownResult;
  int sequence = 0;
  bool disposed = false;
  @override
  void dispose() {
    disposed = true;
    controller.dispose();
    for (final c in [value, date, source, increment]) {
      c.dispose();
    }
    super.dispose();
  }

  void inputChanged(String _) {
    setState(
      () => controller.rejectInput(
        'Input changed. Add a valid benchmark or update configuration before reviewing.',
      ),
    );
  }

  void add() {
    setState(() {
      try {
        controller.enter(
          BaseBenchmark.enter(
            id: 'entry-${++sequence}',
            athleteId: controller.athleteId,
            metric: metric,
            value: value.text,
            unit: unit,
            testDate: date.text,
            sourceType: sourceType,
            sourceReference: source.text,
          ),
        );
      } on FormatException catch (e) {
        controller.rejectInput(e.message);
      }
    });
  }

  Future<void> review() async {
    final active = controller;
    final pending = active.review();
    setState(() {});
    await pending;
    if (!disposed && identical(active, controller)) setState(() {});
  }

  String _label(Object? value) => switch (value) {
    BaseMetric.run10km => '10 km run completion time',
    BaseMetric.row2km => '2 km row completion time',
    BaseMetric.backSquat5rm => 'Back squat 5RM',
    BaseMetric.strictPress5rm => 'Strict overhead press 5RM',
    BaseMetric.strictPullUps => 'Maximum strict pull-ups',
    BaseInputUnit.seconds => 'seconds',
    BaseInputUnit.minutes => 'minutes',
    BaseInputUnit.milliseconds => 'milliseconds',
    BaseInputUnit.kilograms => 'kg total external load',
    BaseInputUnit.pounds => 'lb total external load',
    BaseInputUnit.count => 'repetitions',
    BaseSourceType.knownResult => 'Known result (declared)',
    BaseSourceType.recordedResult => 'Recorded result reference (declared)',
    BaseSourceType.syntheticExample => 'Synthetic example',
    _ => value.toString(),
  };
  Widget choice<T>(
    String label,
    T value,
    List<T> values,
    ValueChanged<T> changed,
  ) => DropdownButtonFormField<T>(
    key: ValueKey('$label-${controller.athleteId}'),
    isExpanded: true,
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: values
        .map(
          (v) => DropdownMenuItem(
            value: v,
            child: Text(_label(v), overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(),
    onChanged: (v) {
      if (v != null) changed(v);
    },
  );
  @override
  Widget build(BuildContext context) {
    final preview = controller.preview;
    return Scaffold(
      appBar: AppBar(
        title: const Text('HYROX Base • local personalisation review'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Synthetic examples only. Partial session previews; no programme publication or athlete writes. Enter a known result, choose it, then explicitly accept its use for future previews.',
          ),
          choice(
            'Synthetic athlete',
            controller.athleteId,
            ['synthetic-a', 'synthetic-b'],
            (v) => setState(() {
              controller.dispose();
              controller = BaseReviewController(v);
              value.clear();
              source.clear();
              increment.clear();
            }),
          ),
          choice(
            'Benchmark',
            metric,
            BaseMetric.values,
            (v) => setState(() {
              metric = v;
              controller.rejectInput(
                'Choose the matching unit and add the benchmark.',
              );
            }),
          ),
          choice(
            'Input unit',
            unit,
            BaseInputUnit.values,
            (v) => setState(() {
              unit = v;
              controller.rejectInput('Add the benchmark with this unit.');
            }),
          ),
          TextField(
            controller: value,
            decoration: const InputDecoration(
              labelText: 'Result value (load = total external load)',
            ),
            onChanged: inputChanged,
          ),
          TextField(
            controller: date,
            decoration: const InputDecoration(
              labelText: 'Test date YYYY-MM-DD',
            ),
            onChanged: inputChanged,
          ),
          choice(
            'Declared source type',
            sourceType,
            BaseSourceType.values,
            (v) => setState(() {
              sourceType = v;
              controller.rejectInput('Add benchmark with source type.');
            }),
          ),
          TextField(
            controller: source,
            decoration: const InputDecoration(
              labelText: 'Source reference / description',
            ),
            onChanged: inputChanged,
          ),
          FilledButton(
            onPressed: add,
            child: const Text('Add benchmark entry'),
          ),
          if (controller.error != null)
            Text(controller.error!, key: const Key('input-error')),
          for (final b in controller.entries.values)
            ListTile(
              title: Text(
                '${_label(b.metric)}: ${b.canonicalValue / (b.canonicalUnit.startsWith('micrograms')
                        ? 1000000000
                        : b.canonicalUnit == 'milliseconds'
                        ? 1000
                        : 1)} ${b.canonicalUnit.startsWith('micrograms')
                    ? 'kg'
                    : b.canonicalUnit == 'milliseconds'
                    ? 'seconds'
                    : 'repetitions'}',
              ),
              subtitle: Text(
                '${b.testDate} • ${b.sourceType.name} • ${b.sourceReference}\n${controller.selected[b.metric]?.id == b.id ? 'Selected' : 'Available entry'}',
              ),
              trailing: TextButton(
                onPressed: () =>
                    setState(() => controller.proposeSelection(b.id)),
                child: const Text('Choose'),
              ),
            ),
          if (controller.proposal case final proposal?)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Text(
                      'Use ${proposal.benchmark.metric.name} from ${proposal.benchmark.testDate} for future previews? Started and completed snapshots retain their original targets.',
                    ),
                    Wrap(
                      children: [
                        TextButton(
                          onPressed: () => setState(
                            () => controller.acceptSelection(proposal),
                          ),
                          child: const Text('Accept benchmark selection'),
                        ),
                        TextButton(
                          onPressed: () => setState(controller.cancelSelection),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          for (final b in controller.selected.values)
            TextButton(
              onPressed: () => setState(() => controller.deselect(b.metric)),
              child: Text('Clear selected ${b.metric.name}'),
            ),
          choice(
            'Week',
            controller.week,
            List.generate(8, (i) => i + 1),
            (v) => setState(
              () => controller.configure(
                week: v,
                incrementGrams: controller.incrementGrams,
              ),
            ),
          ),
          TextField(
            controller: increment,
            decoration: const InputDecoration(
              labelText:
                  'Configured total-barbell increment (grams); blank = unavailable',
            ),
            onChanged: inputChanged,
          ),
          TextButton(
            onPressed: () => setState(() {
              final text = increment.text;
              final grams = text.isEmpty ? null : int.tryParse(text);
              if (text.isNotEmpty && grams == null) {
                controller.rejectInput(
                  'Enter a whole positive gram increment.',
                );
              } else {
                controller.configure(
                  week: controller.week,
                  incrementGrams: grams,
                );
              }
            }),
            child: const Text('Apply equipment configuration'),
          ),
          FilledButton(
            onPressed: controller.busy ? null : review,
            child: Text(
              controller.busy ? 'Reviewing…' : 'Calculate session preview',
            ),
          ),
          if (preview != null) ...[
            Text(
              'Week ${preview.week} • authored + calculated preview',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            _interval('Thursday running', preview.run),
            _interval('Monday dedicated rowing', preview.row),
            Text(
              'Back squat: ${preview.rule.squatSets} × ${preview.rule.squatReps}, ${preview.rule.rir} RIR. '
              '${preview.squat.grams == null ? preview.squat.unavailableReason : '${preview.squat.grams! / 1000} kg calculated total external load'}. RIR/technique govern adjustments.',
            ),
            Text(
              'Easy run ${preview.rule.easyMin}–${preview.rule.easyMax} min; long run ${preview.rule.longMin}–${preview.rule.longMax} min. Conversational / RPE about 3–4. No manufactured HR zones.',
            ),
            const Text(
              'Warm-up/cooldown additional; aim for about 90 minutes total. Other gym work is not supplied by this preview. Row targets do not apply inside mixed WODs. Bike substitution requires existing verified rules and athlete acceptance; no running pace transfers.',
            ),
            const Text(
              'Actual values: not recorded. Base windows are authored starting guidance, not physiological thresholds.',
            ),
            TextButton(
              onPressed: () => setState(
                () =>
                    controller.start('local-${controller.workouts.length + 1}'),
              ),
              child: const Text('Freeze local started-session example'),
            ),
          ],
          for (final workout in controller.workouts.values)
            Card(
              child: ListTile(
                title: Text(
                  '${workout.id}: ${workout.completed ? 'completed local example' : 'started local example'}',
                ),
                subtitle: Text(
                  'Week ${workout.prescription.week} • prescribed squat ${workout.prescription.squat.grams} g • actual ${workout.actualSquatGrams ?? 'not recorded'}',
                ),
                trailing: workout.completed
                    ? null
                    : TextButton(
                        onPressed: () =>
                            setState(() => controller.complete(workout.id)),
                        child: const Text('Complete local example'),
                      ),
              ),
            ),
          const Text(
            'No Test Week protocols, wall-ball division defaults, automatic progression, persistence or Garmin integration. Rule: hyrox-base-personalisation-v1.',
          ),
        ],
      ),
    );
  }

  Widget _interval(String name, BaseIntervalPreview p) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      '$name: ${p.repetitions} × ${p.workSeconds ~/ 60} min / ${p.recoverySeconds} sec easy between only. '
      '${p.pace?.label ?? 'Numeric target unavailable: ${p.unavailableReason}'}. ${p.effort}.',
    ),
  );
}
