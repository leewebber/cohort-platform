import 'package:flutter/material.dart';
import '../../../application/hyrox_base/bound_programme.dart';
import '../../../application/hyrox_base/local_bound_repository.dart';
import '../../../domain/hyrox_base/base_personalisation.dart';

class BoundStudioReviewScreen extends StatefulWidget {
  const BoundStudioReviewScreen({super.key});
  @override
  State<BoundStudioReviewScreen> createState() =>
      _BoundStudioReviewScreenState();
}

class _BoundStudioReviewScreenState extends State<BoundStudioReviewScreen> {
  late final BoundProgramme programme;
  late final LocalBoundRepository repo;
  final value = TextEditingController(),
      source = TextEditingController(),
      increment = TextEditingController();
  final date = TextEditingController(text: '2026-10-22');
  BaseMetric metric = BaseMetric.run10km;
  late String slot;
  String? error;
  BoundConsentProposal? proposal;
  BoundReviewReceipt? receipt;
  int sequence = 0, operation = 0;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    final fixture = SyntheticBoundFixture.build();
    programme = BoundProgramme.compile(fixture.source, sourceRegistry: fixture);
    repo = LocalBoundRepository(athleteId: 'synthetic-a', programme: programme);
    slot = programme.slots.first;
  }

  @override
  void dispose() {
    operation++;
    repo.dispose();
    for (final c in [value, source, increment, date]) {
      c.dispose();
    }
    super.dispose();
  }

  void edited(String _) {
    operation++;
    setState(() {
      busy = false;
      receipt = null;
      proposal = null;
      error =
          'Inputs changed. Apply configuration or add a valid entry before review.';
    });
    repo.cancel();
  }

  Future<void> action(Future<void> Function() work) async {
    final ticket = ++operation;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await work();
    } catch (e) {
      if (mounted && ticket == operation) error = e.toString();
    }
    if (mounted && ticket == operation) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Programme Studio • bound personalisation'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Local synthetic integration. Compiled Plan Package v3 targets; partial source sessions. No production storage or complete programme.',
        ),
        ExpansionTile(
          title: const Text('Compiled source and binding trace'),
          children: [SelectableText(programme.canonicalJson)],
        ),
        DropdownButtonFormField<String>(
          initialValue: slot,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Compiled session slot'),
          items: programme.slots
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (s) {
            if (s != null) {
              operation++;
              setState(() {
                slot = s;
                receipt = null;
                proposal = null;
                error = null;
                busy = false;
              });
              repo.cancel();
            }
          },
        ),
        DropdownButtonFormField<BaseMetric>(
          initialValue: metric,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Benchmark to enter'),
          items: [
            for (final m in [
              BaseMetric.run10km,
              BaseMetric.row2km,
              BaseMetric.backSquat5rm,
            ])
              DropdownMenuItem(value: m, child: Text(m.name)),
          ],
          onChanged: (m) {
            if (m != null) {
              edited('');
              setState(() => metric = m);
            }
          },
        ),
        TextField(
          controller: value,
          onChanged: edited,
          decoration: InputDecoration(
            labelText: metric == BaseMetric.backSquat5rm
                ? '5RM total external load (kg)'
                : 'Completion time (seconds)',
          ),
        ),
        TextField(
          controller: date,
          onChanged: edited,
          decoration: const InputDecoration(labelText: 'Test date YYYY-MM-DD'),
        ),
        TextField(
          controller: source,
          onChanged: edited,
          decoration: const InputDecoration(
            labelText: 'Declared result source/reference',
          ),
        ),
        FilledButton(
          onPressed: busy
              ? null
              : () => action(() async {
                  final b = BaseBenchmark.enter(
                    id: 'local-${++sequence}',
                    athleteId: repo.athleteId,
                    metric: metric,
                    value: value.text,
                    unit: metric == BaseMetric.backSquat5rm
                        ? BaseInputUnit.kilograms
                        : BaseInputUnit.seconds,
                    testDate: date.text,
                    sourceType: BaseSourceType.knownResult,
                    sourceReference: source.text,
                  );
                  await repo.enter(b);
                  receipt = null;
                  proposal = null;
                }),
          child: const Text('Add benchmark entry'),
        ),
        for (final e in repo.evidence.values)
          ListTile(
            title: Text(
              '${e.benchmark.metric.name}: ${e.benchmark.canonicalValue} ${e.benchmark.canonicalUnit}',
            ),
            subtitle: Text(
              '${e.benchmark.testDate} • declared result • ${e.benchmark.sourceReference} • revision ${e.revision}',
            ),
            trailing: TextButton(
              onPressed: busy
                  ? null
                  : () => action(() async {
                      receipt = null;
                      proposal = await repo.propose(
                        'hyrox-${e.benchmark.metric.name}',
                        e.benchmark.id,
                      );
                    }),
              child: const Text('Choose'),
            ),
          ),
        if (proposal case final p?)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(
                    'Use ${p.evidence.benchmark.metric.name} revision ${p.evidence.revision} for this compiled programme’s future unstarted targets? Started/completed sessions retain their prescriptions.',
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => action(() async {
                            await repo.accept(p);
                            proposal = null;
                            receipt = null;
                          }),
                    child: const Text('Accept future target selection'),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => action(() async {
                            await repo.cancel();
                            proposal = null;
                            receipt = null;
                          }),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        TextField(
          controller: increment,
          onChanged: edited,
          decoration: const InputDecoration(
            labelText:
                'Configured total-barbell increment (whole grams); blank = unavailable',
          ),
        ),
        TextButton(
          onPressed: busy
              ? null
              : () => action(() async {
                  final text = increment.text;
                  final grams = text.isEmpty ? null : int.tryParse(text);
                  if (text.isNotEmpty && grams == null) {
                    throw const BoundRefusal('invalid_equipment_increment');
                  }
                  await repo.configureIncrement(grams);
                  receipt = null;
                  proposal = null;
                }),
          child: const Text('Apply equipment configuration'),
        ),
        if (error != null) Text(error!, key: const Key('bound-error')),
        FilledButton(
          onPressed: busy || error != null
              ? null
              : () => action(() async {
                  final reviewed = await repo.review(slot);
                  receipt = reviewed;
                }),
          child: const Text('Review compiled targets'),
        ),
        if (receipt case final r?) ...[
          for (final raw in r.document['targets'] as List)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _target(raw as Map<String, dynamic>),
              ),
            ),
          FilledButton(
            onPressed: busy
                ? null
                : () => action(() async {
                    await repo.start(r);
                  }),
            child: const Text(
              'Start synthetic session and freeze prescription',
            ),
          ),
        ],
        for (final s in repo.started.values)
          ListTile(
            title: Text(
              '${s.slotKey}: ${repo.completedActuals.containsKey(s.slotKey) ? 'completed' : 'started'} synthetic snapshot',
            ),
            subtitle: const Text(
              'Exact source, binding, rule, selected revision and calculated prescription retained; actuals separate.',
            ),
            trailing: repo.completedActuals.containsKey(s.slotKey)
                ? null
                : TextButton(
                    onPressed: busy
                        ? null
                        : () => action(() async {
                            await repo.complete(s.slotKey);
                          }),
                    child: const Text('Complete local example'),
                  ),
          ),
      ],
    ),
  );
  Widget _target(Map<String, dynamic> t) {
    final binding = t['binding'] as Map;
    final p = t['prescription'] as Map;
    final pace = p['calculated'] as Map?;
    String calculated;
    if (pace != null) {
      final f = pace['faster'] as Map, s = pace['slower'] as Map;
      calculated =
          '${f['numerator'] / f['denominator'] / 1000}–${s['numerator'] / s['denominator'] / 1000} seconds ${binding['output_unit'] == 'millisecondsPerKilometre' ? '/km' : '/500 m'}';
    } else {
      calculated = p['calculated_grams_total_external_load'] == null
          ? 'Unavailable: ${t['unavailable_reason']}'
          : '${p['calculated_grams_total_external_load'] / 1000} kg total external load';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${binding['kind']} • ${t['state']}'),
        Text('Authored intent: ${t['authored_intent']}'),
        Text(
          'Selected benchmark evidence: ${t['selected_evidence'] == null ? 'missing' : (t['selected_evidence'] as Map)['evidence_revision']}',
        ),
        Text('Calculated target: $calculated'),
        const Text('Actual: not recorded'),
      ],
    );
  }
}
