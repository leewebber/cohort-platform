import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/utils/database_uuid.dart';
import '../composition/workspace/workspace_files.dart';
import '../composition/source_export/source_bundle_download.dart';
import '../presentation/programme_studio_app.dart';
import 'genuine_workspace.dart';
import 'native_form_fields.dart';
import 'native_session_source.dart';
import 'native_source_bundle.dart';

/// Native source-policy presentation inside the existing programme-first entry.
/// Controls write existing package/graph fields, never a second programme tree.
class GenuineWorkspaceScreen extends StatefulWidget {
  const GenuineWorkspaceScreen({
    super.key,
    required this.controller,
    required this.replace,
    this.downloadWorkspace = downloadEditableWorkspace,
    this.chooseWorkspace = chooseEditableWorkspace,
  });
  final GenuineWorkspace controller;
  final void Function(GenuineWorkspace) replace;
  final void Function(String) downloadWorkspace;
  final Future<String?> Function() chooseWorkspace;
  @override
  State<GenuineWorkspaceScreen> createState() => _GenuineWorkspaceScreenState();
}

class _GenuineWorkspaceScreenState extends State<GenuineWorkspaceScreen> {
  GenuineWorkspace get c => widget.controller;
  int page = 0, week = 0;
  String? activeLineage, message;
  bool transferring = false;
  NativeSessionOwner get active =>
      activeLineage == null ? c.owners.values.first : c.owners[activeLineage!];
  List<Map<String, dynamic>> get palette {
    final variants = <String, Map<String, dynamic>>{};
    for (final owner in c.owners.values) {
      for (final block in readWorkspaceJsonForUi(
        owner.revisions.first.source,
      )['blocks']) {
        for (final e in block['exercises']) {
          variants.putIfAbsent(
            e['variant_key'] as String,
            () => nativeCopy(e as Map),
          );
        }
      }
    }
    return variants.values.toList();
  }

  void attempt(VoidCallback action) {
    try {
      action();
      if (mounted) setState(() => message = null);
    } catch (e) {
      if (mounted) setState(() => message = '$e');
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Programme Studio · founder workspace')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Local genuine draft · D8 content review pending. No autosave or cloud recovery. Keep your editable file.',
                ),
                Text(
                  '${c.status} · ${c.unsaved ? 'Unsaved edits' : 'Editable file saved'}',
                ),
                Wrap(
                  spacing: 10,
                  children: [
                    TextButton(
                      onPressed: transferring
                          ? null
                          : () => attempt(() {
                              final text = c.save();
                              widget.downloadWorkspace(text);
                              c.markSaved(text);
                            }),
                      child: const Text('Save editable draft'),
                    ),
                    TextButton(
                      onPressed: transferring ? null : open,
                      child: const Text('Open editable draft'),
                    ),
                    TextButton(
                      onPressed: transferring ? null : openSources,
                      child: const Text('Open native canonical sources'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await c.refreshReview();
                        if (mounted) setState(() => page = 2);
                      },
                      child: const Text('Review exact prescriptions'),
                    ),
                    for (var i = 0; i < 3; i++)
                      TextButton(
                        onPressed: () => setState(() => page = i),
                        child: Text(['Programme', 'Sessions', 'Review'][i]),
                      ),
                  ],
                ),
                if (message != null)
                  Text(message!, style: const TextStyle(color: Colors.red)),
                if (c.programme.issues.isNotEmpty)
                  Text(c.programme.issues.map((i) => i.message).join('\n')),
                Text(
                  'Programme export inventory: ${c.policy.available.length} exact versions · ${c.occurrences.length} scheduled workouts. Private saved history remains in the editable file.',
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: page == 0
                      ? arrangement()
                      : page == 1
                      ? sessions()
                      : review(),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget field(
    String label,
    Object? value,
    ValueChanged<String> change, {
    String? identity,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: TextFormField(
      key: ValueKey('${activeLineage ?? 'programme'}:${identity ?? label}'),
      initialValue: value?.toString() ?? '',
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      maxLines: lines,
      onChanged: change,
    ),
  );
  Widget choice<T>(
    String label,
    T value,
    List<(T, String)> values,
    ValueChanged<T> change,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      isExpanded: true,
      items: [
        for (final v in values)
          DropdownMenuItem(
            value: v.$1,
            child: Text(v.$2, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) {
        if (v != null) change(v);
      },
    ),
  );
  Widget arrangement() {
    final tree = c.programme.tree!;
    final weeks = tree['weeks'] as List;
    week = week.clamp(0, weeks.length - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        field(
          'Programme name',
          tree['programme']['name'],
          (v) => c.programme.editProgramme('name', v),
        ),
        field(
          'Programme description',
          tree['programme']['description'],
          (v) => c.programme.editProgramme('description', v),
          lines: 3,
        ),
        field(
          'Sessions per week (authored)',
          tree['programme']['sessions_per_week'],
          (v) => c.programme.editProgramme('sessions_per_week', v),
        ),
        choice('Number of weeks', weeks.length, [
          for (var i = 1; i <= 10; i++) (i, '$i'),
        ], (v) => attempt(() => c.setWeeks(v))),
        choice('Week', week, [
          for (var i = 0; i < weeks.length; i++) (i, 'Week ${i + 1}'),
        ], (v) => setState(() => week = v)),
        field(
          'Week notes',
          weeks[week]['coach_note'] ?? weeks[week]['title'],
          (v) => c.programme.editWeek(week, 'coach_note', v),
          identity: 'week-$week',
          lines: 3,
        ),
        if (weeks.length > 1)
          TextButton(
            onPressed: () => duplicateWeek(),
            child: const Text('Copy this week to another week…'),
          ),
        TextButton(
          onPressed: () => confirm(
            'Exclude unused saved sources from this programme export? Keep all private source/history in the editable file.',
            c.excludeUnusedSources,
          ),
          child: const Text('Exclude unused sources from programme export…'),
        ),
        for (var d = 0; d < 7; d++)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [
                      'Monday',
                      'Tuesday',
                      'Wednesday',
                      'Thursday',
                      'Friday',
                      'Saturday',
                      'Sunday',
                    ][d],
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  field(
                    'Day notes',
                    weeks[week]['days'][d]['coach_note'],
                    (v) => c.programme.editDay(week, d, 'coach_note', v),
                    identity: 'day-$week-$d',
                  ),
                  if (weeks[week]['days'][d]['day_type'] == 'rest')
                    const Text('Rest'),
                  for (final slot in weeks[week]['days'][d]['slots']) ...[
                    Builder(
                      builder: (_) {
                        final r = c.selected(slot['slot_key'] as String);
                        return ListTile(
                          title: Text(r.title),
                          subtitle: Text(
                            'Local version ${r.identity.revisionNumber}${c.ownerOf(r).draft != null ? ' · pending session draft, placement still references saved source' : ''}',
                          ),
                          trailing: TextButton(
                            onPressed: () {
                              setState(() {
                                activeLineage = r.identity.sessionLineageId;
                                page = 1;
                              });
                            },
                            child: const Text('Open session'),
                          ),
                        );
                      },
                    ),
                  ],
                  Wrap(
                    children: [
                      TextButton(
                        onPressed: () => place(d),
                        child: const Text('Place saved session…'),
                      ),
                      TextButton(
                        onPressed: () => confirm(
                          'Remove every workout on this day and mark it Rest?',
                          () => c.rest(week, d),
                        ),
                        child: const Text('Mark as rest…'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget sessions() {
    final owner = active;
    final draft = owner.draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        choice('Session', owner.lineage, [
          for (final o in c.owners.values)
            (o.lineage, c.sessionLabel(o.latest)),
        ], (v) => setState(() => activeLineage = v)),
        Wrap(
          children: [
            for (final running in [false, true])
              TextButton(
                onPressed: () => attempt(() {
                  final r = c.createSession(running: running);
                  c.begin(r);
                  activeLineage = r.identity.sessionLineageId;
                }),
                child: Text(
                  running
                      ? 'Create structured-running session'
                      : 'Create strength session',
                ),
              ),
            TextButton(
              onPressed: () => attempt(() {
                final copy = c.duplicateSession(owner.latest);
                c.begin(copy);
                activeLineage = copy.identity.sessionLineageId;
              }),
              child: const Text('Duplicate as independent session'),
            ),
            if (draft == null)
              TextButton(
                onPressed: () => attempt(() => c.begin(owner.latest)),
                child: const Text('Create later draft'),
              ),
          ],
        ),
        if (draft == null) ...[
          const Text(
            'Saved source snapshot. Imported source history/publication is not proved. Editing reserves a fresh local revision.',
          ),
          for (final r in owner.revisions)
            ListTile(
              title: Text('${r.title} · version ${r.identity.revisionNumber}'),
              subtitle: Text(
                'Used in ${c.occurrences.where((s) => s['session_key'] == r.key).map((s) => 'W${s['week']} day ${s['day']}').join(', ')}',
              ),
              trailing: Wrap(
                children: [
                  if (!c.policy.available.contains(r.key))
                    TextButton(
                      onPressed: () => c.addSource(r),
                      child: const Text('Add to programme inventory'),
                    ),
                  TextButton(
                    onPressed: () => chooseUses(r),
                    child: const Text('Use in selected occurrences…'),
                  ),
                ],
              ),
            ),
          SelectableText(c.inspect(owner).readable),
        ] else ...[
          field('Session title', owner.draftTitle, (v) {
            owner.draftTitle = v;
            c.edit(owner, (_) {});
          }),
          const Text(
            'Working draft. Invalid fields and unresolved setups can be saved in the editable file; they cannot become a validated revision.',
          ),
          for (var b = 0; b < (draft['blocks'] as List).length; b++)
            blockEditor(owner, b),
          Wrap(
            children: [
              TextButton(
                onPressed: () => c.edit(
                  owner,
                  (g) => (g['blocks'] as List).add({
                    'position': (g['blocks'] as List).length + 1,
                    'block_id': DatabaseUuid.newV4(),
                    'block_type': 'strength',
                    'title': '',
                    'content': '',
                    'workout_format': 'none',
                    'exercises': [],
                  }),
                ),
                child: const Text('Add strength block'),
              ),
              TextButton(
                onPressed: () => attempt(() {
                  c.freeze(owner);
                }),
                child: const Text('Validate and save local revision'),
              ),
              TextButton(
                onPressed: () => confirm(
                  'Cancel these session edits? The reserved number will remain unavailable.',
                  () => c.cancel(owner),
                ),
                child: const Text('Cancel session edits…'),
              ),
            ],
          ),
          ExpansionTile(
            title: const Text('Draft prescription review'),
            children: [SelectableText(c.inspect(owner).readable)],
          ),
        ],
        if (c.errors.isNotEmpty) Text(c.errors.join('\n')),
        ExpansionTile(
          title: const Text('Optional source and identity inspection'),
          children: [
            SelectableText(
              const JsonEncoder.withIndent('  ').convert(owner.latest.origin),
            ),
            for (final variant in {
              for (final b
                  in (draft ??
                      readWorkspaceJsonForUi(owner.latest.source))['blocks'])
                for (final e in b['exercises']) e['variant_key'] as String,
            })
              SelectableText(
                const JsonEncoder.withIndent('  ').convert(
                  c.catalogue.rowFor(variant) ??
                      {
                        'status':
                            'No retained catalogue record for this intended setup',
                      },
                ),
              ),
            SelectableText(
              owner.draft == null
                  ? owner.latest.source
                  : const JsonEncoder.withIndent('  ').convert(owner.draft),
            ),
          ],
        ),
      ],
    );
  }

  Widget blockEditor(NativeSessionOwner owner, int bi) {
    final b = owner.draft!['blocks'][bi] as Map<String, dynamic>;
    void change(VoidCallback f) => c.edit(owner, (_) => f());
    final key = b['block_id'] ?? 'block-$bi';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            field(
              'Block title',
              b['title'],
              (v) => change(() => b['title'] = v),
              identity: '$key-title',
            ),
            if (b['timer_config'] == null)
              choice(
                'Block role',
                b['block_type'] as String,
                [
                  ('warm_up', 'Preparation'),
                  ('strength', 'Main strength'),
                  ('cool_down', 'Walking finish / cooldown'),
                ],
                (v) => change(() => b['block_type'] = v),
              ),
            field(
              'Preparation / finish / block guidance',
              b['content'],
              (v) => change(() => b['content'] = v),
              identity: '$key-content',
              lines: 4,
            ),
            Wrap(
              children: [
                TextButton(
                  onPressed: bi == 0
                      ? null
                      : () => change(
                          () => moveNativeRow(
                            owner.draft!['blocks'] as List,
                            bi,
                            bi - 1,
                          ),
                        ),
                  child: const Text('Move block up'),
                ),
                TextButton(
                  onPressed: bi + 1 == (owner.draft!['blocks'] as List).length
                      ? null
                      : () => change(
                          () => moveNativeRow(
                            owner.draft!['blocks'] as List,
                            bi,
                            bi + 1,
                          ),
                        ),
                  child: const Text('Move block down'),
                ),
                TextButton(
                  onPressed: () => confirm(
                    'Remove this block and all of its rows?',
                    () => change(() {
                      (owner.draft!['blocks'] as List).removeAt(bi);
                      for (
                        var i = 0;
                        i < (owner.draft!['blocks'] as List).length;
                        i++
                      ) {
                        owner.draft!['blocks'][i]['position'] = i + 1;
                      }
                    }),
                  ),
                  child: const Text('Remove block…'),
                ),
              ],
            ),
            if (b['timer_config'] != null)
              runningEditor(owner, b, '$key')
            else ...[
              for (var ei = 0; ei < (b['exercises'] as List).length; ei++)
                strengthEditor(owner, b, ei, '$key'),
              if (b['block_type'] == 'strength')
                TextButton(
                  onPressed: () => selectExercise(owner, b),
                  child: const Text('Find exercise / setup…'),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget strengthEditor(
    NativeSessionOwner owner,
    Map<String, dynamic> block,
    int index,
    String bk,
  ) {
    final e = block['exercises'][index] as Map<String, dynamic>;
    final p = e['prescription'] as Map<String, dynamic>;
    final reps = p['reps'] as Map;
    final details = p['authored_details'] as Map? ?? {};
    final rirText = details['source_rir']?.toString() ?? 'N/A';
    final rirMode = rirText.startsWith('at least ')
        ? 'at_least'
        : p['rir_range'] != null
        ? (p['rir_range'][0] == p['rir_range'][1] ? 'exact' : 'range')
        : 'absent';
    final rirLow =
        p['rir_range']?[0]?.toString() ??
        (rirMode == 'at_least' ? rirText.substring(9) : '');
    final rirHigh = p['rir_range']?[1]?.toString() ?? rirLow;
    final restLow =
        (p['rest_seconds'] ?? p['rest_seconds_range']?[0])?.toString() ?? '';
    final restHigh =
        (p['rest_seconds'] ?? p['rest_seconds_range']?[1])?.toString() ?? '';
    final both = details.containsKey('rest_location')
        ? details['rest_location'].toString().contains('after both sides')
        : (e['variant_key'] == 'reverse_lunge_db' ||
              e['variant_key'] == 'bench_supported_db_row');
    final capture = p['performance_capture'] as Map?;
    void change(VoidCallback f) => c.edit(owner, (_) => f());
    final k = '$bk-${e['source_occurrence_id'] ?? index}';
    return ExpansionTile(
      key: ValueKey(k),
      initiallyExpanded: false,
      title: Text(e['display_label_override'] as String),
      subtitle: Text(
        e['exercise_id'] == null
            ? 'Unresolved exercise setup — cannot prepare for publication'
            : 'Exact retained legacy row; source coaching remains separate',
      ),
      children: [
        if (e['exercise_id'] == null &&
            c.catalogue.idFor(e['variant_key'] as String) != null)
          TextButton(
            onPressed: () => change(
              () => e['exercise_id'] = c.catalogue.idFor(
                e['variant_key'] as String,
              ),
            ),
            child: const Text(
              'Bind this exact retained setup (keep the prescription)',
            ),
          ),
        field(
          'Sets',
          p['sets'],
          (v) => change(() => p['sets'] = integerInput(v)),
          identity: '$k-sets',
        ),
        choice(
          'Repetitions or timed hold',
          reps['type'] as String,
          [
            ('exact', 'Exact reps'),
            ('range', 'Rep range'),
            ('duration', 'Timed hold range'),
          ],
          (v) => change(
            () => p['reps'] = v == 'exact'
                ? {'type': v, 'exact_reps': 1}
                : v == 'range'
                ? {'type': v, 'min_reps': 1, 'max_reps': 1}
                : {'type': v, 'text': ''},
          ),
        ),
        if (reps['type'] == 'exact')
          field(
            'Repetitions',
            reps['exact_reps'],
            (v) => change(() => reps['exact_reps'] = integerInput(v)),
            identity: '$k-reps',
          ),
        if (reps['type'] == 'range') ...[
          field(
            'Minimum repetitions',
            reps['min_reps'],
            (v) => change(() => reps['min_reps'] = integerInput(v)),
            identity: '$k-reps-min',
          ),
          field(
            'Maximum repetitions',
            reps['max_reps'],
            (v) => change(() => reps['max_reps'] = integerInput(v)),
            identity: '$k-reps-max',
          ),
        ],
        if (reps['type'] == 'duration')
          field(
            'Hold duration (for example 30–45 sec/side)',
            reps['text'],
            (v) => change(() => reps['text'] = v),
            identity: '$k-hold',
          ),
        SwitchListTile(
          title: const Text('Each side; both sides form one set'),
          value: p['per_side'] == true,
          onChanged: (v) => change(() => p['per_side'] = v),
        ),
        choice('RIR meaning', rirMode, [
          ('absent', 'No RIR requirement'),
          ('exact', 'Exact RIR'),
          ('range', 'RIR range'),
          ('at_least', 'At least (no upper bound)'),
        ], (v) => change(() => setRir(p, v, rirLow, rirHigh))),
        if (rirMode != 'absent')
          field(
            'RIR minimum / exact value',
            rirLow,
            (v) => change(
              () => setRir(p, rirMode, v, rirMode == 'exact' ? v : rirHigh),
            ),
            identity: '$k-rir-min',
          ),
        if (rirMode == 'range')
          field(
            'RIR maximum',
            rirHigh,
            (v) => change(() => setRir(p, rirMode, rirLow, v)),
            identity: '$k-rir-max',
          ),
        field(
          'Rest minimum / exact seconds',
          restLow,
          (v) => change(() => setRest(p, v, restHigh, both)),
          identity: '$k-rest-min',
        ),
        field(
          'Rest maximum seconds (same for exact rest)',
          restHigh,
          (v) => change(() => setRest(p, restLow, v, both)),
          identity: '$k-rest-max',
        ),
        SwitchListTile(
          title: const Text('Rest after both sides; no intra-side rest'),
          value: both,
          onChanged: (v) => change(() => setRest(p, restLow, restHigh, v)),
        ),
        field(
          'Tempo',
          p['tempo'],
          (v) => change(() => p['tempo'] = v),
          identity: '$k-tempo',
          lines: 2,
        ),
        field(
          'Coaching and setup notes',
          p['coach_cue'],
          (v) => change(() => p['coach_cue'] = v),
          identity: '$k-notes',
          lines: 4,
        ),
        if (capture != null) ...[
          field(
            'Load logging convention',
            capture['load_label'],
            (v) => change(() => capture['load_label'] = v),
            identity: '$k-load-label',
          ),
          choice(
            'External load unit',
            capture['load_unit'] as String? ?? '',
            [
              ('', 'Record actual displayed unit/setup'),
              ('kg', 'kg'),
              ('lb', 'lb'),
            ],
            (v) => change(() {
              if (v.isEmpty) {
                capture.remove('load_unit');
              } else {
                capture['load_unit'] = v;
              }
            }),
          ),
        ],
        const Text(
          'Load remains athlete-selected or absent as authored; no athlete actuals are entered here. RPE and RIR are separate.',
        ),
        Wrap(
          children: [
            TextButton(
              onPressed: index == 0
                  ? null
                  : () => change(
                      () => moveNativeRow(
                        block['exercises'] as List,
                        index,
                        index - 1,
                      ),
                    ),
              child: const Text('Move exercise up'),
            ),
            TextButton(
              onPressed: index + 1 == (block['exercises'] as List).length
                  ? null
                  : () => change(
                      () => moveNativeRow(
                        block['exercises'] as List,
                        index,
                        index + 1,
                      ),
                    ),
              child: const Text('Move exercise down'),
            ),
            TextButton(
              onPressed: () => change(() {
                (block['exercises'] as List).removeAt(index);
                for (var i = 0; i < (block['exercises'] as List).length; i++) {
                  block['exercises'][i]['position'] = i + 1;
                }
              }),
              child: const Text('Remove exercise'),
            ),
          ],
        ),
      ],
    );
  }

  Widget runningEditor(
    NativeSessionOwner owner,
    Map<String, dynamic> block,
    String key,
  ) {
    final workout = block['timer_config']['running_workout'] as Map;
    final steps = workout['steps'] as List;
    void change(VoidCallback f) => c.edit(owner, (_) {
      f();
      syncTimer(block);
    });
    String total;
    try {
      final t = runningTotals(workout);
      total =
          '${formatRunSeconds(t.seconds)}${t.metres > 0 ? ' + ${t.metres} m' : ''}';
    } catch (_) {
      total = 'Correct invalid phase durations';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Expanded order · total $total'),
        const Text(
          'Targets are symbolic dependencies. Zone 2 and quality work require athlete input, source selection, review and acceptance. M2.3: representative 5K aged 0–56 local days; approved rounding/formulas; manual threshold ±2% only when eligible; started targets immutable. No athlete confirmation occurs in Studio.',
        ),
        field(
          'Workout notes',
          workout['notes'],
          (v) => change(() => workout['notes'] = v),
          identity: '$key-workout-notes',
          lines: 4,
        ),
        for (var i = 0; i < steps.length; i++)
          Builder(
            builder: (_) {
              final s = steps[i] as Map,
                  d = s['duration'] as Map,
                  target = s['target'] as Map;
              final sk = s['step_id'];
              return ExpansionTile(
                key: ValueKey(sk),
                title: Text('${i + 1}. ${s['label']}'),
                subtitle: Text(
                  '${d['kind'] == 'time' && d['milliseconds'] is int
                      ? formatRunSeconds((d['milliseconds'] as int) ~/ 1000)
                      : d['kind'] == 'distance'
                      ? '10,000 m'
                      : 'Invalid time'} · ${targetLabel(target)}',
                ),
                children: [
                  field(
                    'Phase title',
                    s['label'],
                    (v) => change(() => s['label'] = v),
                    identity: '$sk-title',
                  ),
                  choice(
                    'Phase role',
                    s['role'] as String,
                    [
                      ('warm_up', 'Warm-up'),
                      ('work', 'Work'),
                      ('recovery', 'Recovery'),
                      ('cool_down', 'Cooldown'),
                    ],
                    (v) => change(() => s['role'] = v),
                  ),
                  if (d['kind'] == 'time')
                    field(
                      'Duration in seconds',
                      d['milliseconds'] is int
                          ? (d['milliseconds'] as int) ~/ 1000
                          : d['milliseconds'],
                      (v) => change(() {
                        final n = int.tryParse(v);
                        d['milliseconds'] = n == null ? v : n * 1000;
                      }),
                      identity: '$sk-seconds',
                    ),
                  if (d['kind'] == 'distance')
                    const Text(
                      'Selected final 10,000 m body. Athlete confirms external distance; no live distance measurement.',
                    ),
                  choice(
                    'Target dependency',
                    target['kind'] == 'alpha_quality_pace_v1'
                        ? target['category'] as String
                        : target['kind'] as String,
                    [
                      ('none', 'Authored effort; no fixed pace/HR'),
                      ('heart_rate_zone_ref', 'Athlete-confirmed Zone 2'),
                      ('threshold', 'Threshold — approved M2.3 rule'),
                      ('current_10k', 'Current 10K — approved M2.3 rule'),
                      if (target['kind'] == 'rpe_range')
                        ('rpe_range', 'Retained authored RPE range'),
                    ],
                    (v) => change(
                      () => s['target'] = v == 'heart_rate_zone_ref'
                          ? {'kind': v, 'zone_ref': 'athlete_confirmed_zone_2'}
                          : {'threshold', 'current_10k'}.contains(v)
                          ? {'kind': 'alpha_quality_pace_v1', 'category': v}
                          : v == 'rpe_range'
                          ? target
                          : {'kind': 'none'},
                    ),
                  ),
                  field(
                    'Phase cues / effort',
                    s['notes'],
                    (v) => change(() => s['notes'] = v),
                    identity: '$sk-notes',
                    lines: 3,
                  ),
                  Wrap(
                    children: [
                      TextButton(
                        onPressed: i == 0
                            ? null
                            : () => change(
                                () => moveNativeRow(
                                  steps,
                                  i,
                                  i - 1,
                                  positions: false,
                                ),
                              ),
                        child: const Text('Move phase up'),
                      ),
                      TextButton(
                        onPressed: i + 1 == steps.length
                            ? null
                            : () => change(
                                () => moveNativeRow(
                                  steps,
                                  i,
                                  i + 1,
                                  positions: false,
                                ),
                              ),
                        child: const Text('Move phase down'),
                      ),
                      TextButton(
                        onPressed: () => change(() => steps.removeAt(i)),
                        child: const Text('Remove phase'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        Wrap(
          children: [
            TextButton(
              onPressed: () => change(() => steps.add(nativePhase())),
              child: const Text('Add timed phase'),
            ),
            TextButton(
              onPressed: () => repeat(owner, block),
              child: const Text('Add work / recovery repeats…'),
            ),
          ],
        ),
      ],
    );
  }

  Widget review() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Exact authored prescriptions · local review only. D8 pending; no approval or hosted publication.',
      ),
      if (c.errors.isNotEmpty) Text(c.errors.join('\n')),
      if (!c.reviewCurrent)
        const Text('Sources changed. Refresh the exact prescription review.'),
      TextButton(
        onPressed: c.reviewCurrent && c.errors.isEmpty
            ? () => attempt(
                () => downloadSourceBundle(
                  NativeSourceBundle.prepare(c).transport,
                ),
              )
            : null,
        child: const Text('Prepare canonical v2 / native graph export'),
      ),
      for (final slot in c.occurrences)
        ExpansionTile(
          title: Text(
            'Week ${slot['week']} · day ${slot['day']} · ${c.selected(slot['slot_key'] as String).title}',
          ),
          children: [
            SelectableText(
              c
                  .inspectRevision(c.selected(slot['slot_key'] as String))
                  .readable,
            ),
          ],
        ),
      if (c.programme.currentReview != null && c.errors.isEmpty)
        TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  ProgrammeStudioApp(catalog: c.programme.currentReview!),
            ),
          ),
          child: const Text('Open existing athlete prescription review'),
        ),
    ],
  );

  Future<void> confirm(String title, VoidCallback action) async {
    final token = c.generation;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      attempt(() {
        if (token != c.generation) {
          throw StateError('Sources changed. Review this action again.');
        }
        action();
      });
    }
  }

  Future<void> open() async {
    final token = c.generation;
    setState(() => transferring = true);
    PreparedGenuineOpen? prepared;
    try {
      final text = await widget.chooseWorkspace();
      if (!mounted || text == null || token != c.generation) return;
      prepared = c.prepareOpen(text);
      final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Replace this local workspace?'),
          content: const Text(
            'Keep a saved editable file for current edits. The opened draft will be revalidated; no review or approval is restored.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Replace workspace'),
            ),
          ],
        ),
      );
      if (yes == true && mounted && c.isCurrentOpen(prepared)) {
        final candidate = prepared.candidate;
        prepared = null;
        widget.replace(candidate);
      }
    } catch (e) {
      if (mounted) setState(() => message = '$e');
    } finally {
      prepared?.candidate.dispose();
      if (mounted) setState(() => transferring = false);
    }
  }

  Future<void> place(int day) async {
    final token = c.generation;
    final r = await pickRevision();
    if (r != null && mounted) {
      attempt(() {
        if (token != c.generation) {
          throw StateError('Programme changed. Choose the placement again.');
        }
        c.place(week, day, r);
      });
    }
  }

  Future<void> openSources() async {
    final token = c.generation;
    GenuineWorkspace? candidate;
    setState(() => transferring = true);
    try {
      final bytes = await chooseCanonicalSources();
      if (!mounted || bytes == null || token != c.generation) return;
      candidate = NativeSourceBundle.open(bytes, c.catalogue);
      final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Open as a new local draft?'),
          content: const Text(
            'This replaces the current workspace. Canonical sources have unknown historical revisions and no restored approval. Keep your current editable file.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Replace workspace'),
            ),
          ],
        ),
      );
      if (yes == true && mounted && token == c.generation) {
        final next = candidate;
        candidate = null;
        widget.replace(next);
      }
    } catch (e) {
      if (mounted) setState(() => message = '$e');
    } finally {
      candidate?.dispose();
      if (mounted) setState(() => transferring = false);
    }
  }

  Future<NativeRevision?> pickRevision() => showDialog<NativeRevision>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Choose exact saved session version'),
      children: [
        for (final o in c.owners.values)
          for (final r in o.revisions)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, r),
              child: Text(c.sessionLabel(r)),
            ),
      ],
    ),
  );
  Future<void> duplicateWeek() async {
    final target = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Replace which week with this explicit copy?'),
        children: [
          for (var w = 0; w < (c.programme.tree!['weeks'] as List).length; w++)
            if (w != week)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, w),
                child: Text('Week ${w + 1}'),
              ),
        ],
      ),
    );
    if (target != null && mounted) {
      await confirm(
        'Replace week ${target + 1} with a copy of week ${week + 1}? Existing revision choices remain explicit.',
        () => c.duplicateWeek(week, target),
      );
    }
  }

  Future<void> chooseUses(NativeRevision revision) async {
    final token = c.generation;
    final occurrences = c.occurrences;
    final chosen = <String>{};
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Choose exact affected occurrences'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final s in occurrences)
                    CheckboxListTile(
                      title: Text(
                        'Week ${s['week']} · day ${s['day']} · ${c.selected(s['slot_key'] as String).title}',
                      ),
                      value: chosen.contains(s['slot_key']),
                      onChanged: (v) => update(() {
                        if (v == true) {
                          chosen.add(s['slot_key'] as String);
                        } else {
                          chosen.remove(s['slot_key']);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: chosen.isEmpty ? null : () => Navigator.pop(ctx, true),
              child: Text('Use in ${chosen.length} selected occurrences'),
            ),
          ],
        ),
      ),
    );
    if (yes == true && mounted) {
      await confirm(
        'Use ${revision.title} version ${revision.identity.revisionNumber} in exactly ${chosen.map((k) {
          final s = occurrences.singleWhere((s) => s['slot_key'] == k);
          return 'week ${s['week']} day ${s['day']}';
        }).join(', ')}?',
        () => c.useRevision(revision, chosen.toList(), token),
      );
    }
  }

  Future<void> selectExercise(
    NativeSessionOwner owner,
    Map<String, dynamic> block,
  ) async {
    final token = c.generation;
    var query = '', equipment = '', movement = '';
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Find exact exercise and setup'),
          content: SizedBox(
            width: 650,
            height: 550,
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: 'Exercise name'),
                  onChanged: (v) => update(() => query = v.toLowerCase()),
                ),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Equipment / setup filter',
                  ),
                  onChanged: (v) => update(() => equipment = v.toLowerCase()),
                ),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Movement filter (retained catalogue data)',
                  ),
                  onChanged: (v) => update(() => movement = v.toLowerCase()),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final e in palette)
                        if ('${e['display_label_override']}'
                                .toLowerCase()
                                .contains(query) &&
                            '${e['prescription']['coach_cue']} ${c.catalogue.rowFor(e['variant_key'] as String)?['catalogue_row']['equipment']}'
                                .toLowerCase()
                                .contains(equipment) &&
                            '${c.catalogue.rowFor(e['variant_key'] as String)?['catalogue_row']['movement_pattern'] ?? 'unknown'}'
                                .toLowerCase()
                                .contains(movement))
                          Card(
                            child: ListTile(
                              title: Text(
                                e['display_label_override'] as String,
                              ),
                              subtitle: Text(
                                'Source coaching: ${e['prescription']['coach_cue']}\nRetained equipment: ${c.catalogue.rowFor(e['variant_key'] as String)?['catalogue_row']['equipment'] ?? 'unknown'}; setup: ${c.catalogue.rowFor(e['variant_key'] as String)?['catalogue_row']['setup'] ?? 'unknown'}; execution: ${c.catalogue.rowFor(e['variant_key'] as String)?['catalogue_row']['execution'] ?? 'unknown'}\n${c.catalogue.idFor(e['variant_key'] as String) == null ? 'Unresolved setup — awaiting genuine catalogue retention' : 'Exact retained legacy row; source coaching remains separate'}',
                              ),
                              onTap: () => Navigator.pop(ctx, e),
                            ),
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
    if (selected != null && mounted && token == c.generation) {
      c.edit(owner, (_) {
        final e = nativeCopy(selected)
          ..['exercise_id'] = c.catalogue.idFor(
            selected['variant_key'] as String,
          )
          ..['position'] = (block['exercises'] as List).length + 1
          ..['source_occurrence_id'] = DatabaseUuid.newV4();
        (block['exercises'] as List).add(e);
      });
    }
  }

  Future<void> repeat(
    NativeSessionOwner owner,
    Map<String, dynamic> block,
  ) async {
    final token = c.generation;
    var count = '4', work = '300', recovery = '90', last = false;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Add threshold work / very easy recovery'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  initialValue: count,
                  decoration: const InputDecoration(labelText: 'Repetitions'),
                  onChanged: (v) => count = v,
                ),
                TextFormField(
                  initialValue: work,
                  decoration: const InputDecoration(labelText: 'Work seconds'),
                  onChanged: (v) => work = v,
                ),
                TextFormField(
                  initialValue: recovery,
                  decoration: const InputDecoration(
                    labelText: 'Recovery seconds',
                  ),
                  onChanged: (v) => recovery = v,
                ),
                SwitchListTile(
                  title: const Text(
                    'Include recovery after the last repetition',
                  ),
                  value: last,
                  onChanged: (v) => update(() => last = v),
                ),
                const Text(
                  'Creates ordinary ordered phases. Edit titles/targets/cues afterwards. Between-only recoveries and stride cycles have different endings.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add expanded phases'),
            ),
          ],
        ),
      ),
    );
    if (yes == true && mounted && token == c.generation) {
      attempt(() {
        final n = int.parse(count),
            w = int.parse(work),
            r = int.parse(recovery);
        if (w <= 0 || r <= 0) {
          throw const FormatException('Enter positive work/recovery seconds.');
        }
        c.edit(owner, (_) {
          (block['timer_config']['running_workout']['steps'] as List).addAll(
            expandRepeat(
              work: nativePhase(
                seconds: w,
                title: 'Threshold-labelled work',
                target: {
                  'kind': 'alpha_quality_pace_v1',
                  'category': 'threshold',
                },
              ),
              recovery: nativePhase(
                role: 'recovery',
                seconds: r,
                title: 'Very easy recovery',
              ),
              count: n,
              recoveryAfterLast: last,
            ),
          );
          syncTimer(block);
        });
      });
    }
  }
}

Map<String, dynamic> readWorkspaceJsonForUi(String source) =>
    jsonDecode(source) as Map<String, dynamic>;
