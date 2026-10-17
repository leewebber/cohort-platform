import 'dart:convert';

import '../workspace_json.dart';
import 'founder_strength_source_guard.dart';
import 'synthetic_strength_lineage.dart';

/// Only existing form fields may be invalid; wrapper/shape/identity stay fixed.
void validateWorkspaceSessionDraft(
  Map<String, dynamic> tree,
  SyntheticStrengthLineage lineage,
  int number,
) {
  final copy = jsonDecode(jsonEncode(tree)) as Map<String, dynamic>;
  final expected = lineage.emptyRootTree();
  (expected['programme'] as Map)['import_key'] = lineage.importKey(number);
  FounderStrengthSourceGuard.session(copy).clear();
  FounderStrengthSourceGuard.session(expected).clear();
  if (encodeWorkspaceJson(copy) != encodeWorkspaceJson(expected)) {
    workspaceInvalid('Session wrapper changed.');
  }
  final s = workspaceFields(
    FounderStrengthSourceGuard.session(tree),
    {
      'title',
      'session_type',
      'estimated_duration_minutes',
      'coach_notes',
      'blocks',
    },
    {'title', 'session_type', 'blocks'},
    'draft session',
  );
  void text(Map map, String key) {
    if (map.containsKey(key)) workspaceString(map[key], key);
  }

  void input(Map map, String key, {bool decimal = false}) {
    if (!map.containsKey(key)) return;
    final v = map[key];
    if (v is! String && v is! int && !(decimal && v is num && v.isFinite)) {
      workspaceInvalid('Invalid form input type: $key.');
    }
  }

  text(s, 'title');
  text(s, 'coach_notes');
  input(s, 'estimated_duration_minutes');
  if (s['session_type'] != 'strength') {
    workspaceInvalid('Unsupported session type.');
  }
  final blocks = workspaceList(s['blocks'], 'blocks', max: 1);
  if (blocks.length != 1) workspaceInvalid('Exactly one block required.');
  final b = workspaceFields(
    blocks.single,
    {'title', 'block_type', 'order', 'coach_notes', 'exercises'},
    {'title', 'block_type', 'order', 'exercises'},
    'draft block',
  );
  if (b['block_type'] != 'strength' || (b['order'] is! int || b['order'] != 1)) {
    workspaceInvalid('Unsupported block.');
  }
  text(b, 'title');
  text(b, 'coach_notes');
  final rows = workspaceList(b['exercises'], 'exercises', max: 2);
  for (var i = 0; i < rows.length; i++) {
    final e = workspaceFields(
      rows[i],
      {'transitional_exercise_id', 'exercise_name', 'order', 'prescription'},
      {'transitional_exercise_id', 'order', 'prescription'},
      'draft exercise',
    );
    if ((e['order'] is! int || e['order'] != i + 1) ||
        !{
          '',
          'cohort.exercise.d2_fixture_a',
          'cohort.exercise.d2_fixture_b',
        }.contains(e['transitional_exercise_id'])) {
      workspaceInvalid('Unsupported exercise identity/order.');
    }
    text(e, 'exercise_name');
    final dose = workspaceFields(
      e['prescription'],
      {'sets', 'reps', 'rest_seconds', 'tempo', 'notes', 'load'},
      {'sets', 'reps'},
      'draft prescription',
    );
    for (final k in ['sets', 'reps', 'rest_seconds']) {
      input(dose, k);
    }
    text(dose, 'tempo');
    text(dose, 'notes');
    if (dose.containsKey('load')) {
      final load = workspaceFields(
        dose['load'],
        {'unit', 'value'},
        {'unit'},
        'draft load',
      );
      if (!{'bodyweight', 'kg', 'rpe'}.contains(load['unit']) ||
          (load['unit'] == 'bodyweight'
              ? load.containsKey('value')
              : !load.containsKey('value'))) {
        workspaceInvalid('Unsupported load mode.');
      }
      input(load, 'value', decimal: true);
    }
  }
}
