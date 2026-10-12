import 'dart:convert';

import 'package:yaml/yaml.dart';

/// D2-only intake restriction. The shared Founder grammar remains unchanged.
class FounderStrengthSourceGuard {
  const FounderStrengthSourceGuard();

  Map<String, dynamic> read(String source, {required String importKey}) {
    _syntax(source);
    Object? raw;
    try {
      final documents = loadYamlDocuments(source);
      if (documents.length != 1) {
        _fail('source', 'Use exactly one YAML document.');
      }
      raw = documents.single.contents.value;
    } on YamlException catch (error) {
      _fail('source', 'Invalid YAML: ${error.message}');
    }
    final root = _map(raw, 'source', {'schema_version', 'programme', 'weeks'});
    _equal(root, 'schema_version', 1, 'source');
    final p = _map(root['programme'], 'programme', {
      'import_key',
      'code',
      'title',
      'description',
      'objective',
      'duration_weeks',
      'sessions_per_week',
    });
    _equal(p, 'import_key', importKey, 'programme');
    _equal(p, 'code', 'SYN-D2', 'programme');
    _equal(p, 'title', 'Synthetic D2 wrapper', 'programme');
    _equal(p, 'duration_weeks', 1, 'programme');
    _equal(p, 'sessions_per_week', 1, 'programme');
    _optionalStrings(p, ['description', 'objective'], 'programme');
    final w = _map(_one(root['weeks'], 'weeks'), 'weeks[0]', {
      'week_number',
      'title',
      'days',
    });
    _equal(w, 'week_number', 1, 'weeks[0]');
    _optionalStrings(w, ['title'], 'weeks[0]');
    final d = _map(_one(w['days'], 'days'), 'days[0]', {
      'day_number',
      'display_name',
      'is_rest_day',
      'coach_notes',
      'sessions',
    });
    _equal(d, 'day_number', 1, 'days[0]');
    _equal(d, 'is_rest_day', false, 'days[0]');
    _optionalStrings(d, ['display_name', 'coach_notes'], 'days[0]');
    final s = _map(_one(d['sessions'], 'sessions'), 'session', {
      'title',
      'session_type',
      'estimated_duration_minutes',
      'coach_notes',
      'blocks',
    });
    _requiredString(s, 'title', 'session');
    _equal(s, 'session_type', 'strength', 'session');
    _optionalStrings(s, ['coach_notes'], 'session');
    if (s.containsKey('estimated_duration_minutes')) {
      _positive(
        s['estimated_duration_minutes'],
        'session.estimated_duration_minutes',
      );
    }
    final b = _map(_one(s['blocks'], 'blocks'), 'block', {
      'title',
      'block_type',
      'order',
      'coach_notes',
      'exercises',
    });
    _requiredString(b, 'title', 'block');
    _equal(b, 'block_type', 'strength', 'block');
    _equal(b, 'order', 1, 'block');
    _optionalStrings(b, ['coach_notes'], 'block');
    final exercises = b['exercises'];
    if (exercises is! List || exercises.isEmpty || exercises.length > 2) {
      _fail('block.exercises', 'Use one or two distinct fixture exercises.');
    }
    for (var i = 0; i < exercises.length; i++) {
      final path = 'exercises[$i]';
      final e = _map(exercises[i], path, {
        'transitional_exercise_id',
        'exercise_name',
        'order',
        'prescription',
      });
      _requiredString(e, 'transitional_exercise_id', path);
      _optionalStrings(e, ['exercise_name'], path);
      _equal(e, 'order', i + 1, path);
      final dose = _map(e['prescription'], '$path.prescription', {
        'sets',
        'reps',
        'rest_seconds',
        'tempo',
        'notes',
        'load',
        'target_rpe',
      });
      _positive(dose['sets'], '$path.prescription.sets');
      final reps = dose['reps'];
      if (reps is Map) {
        final exact = _map(reps, '$path.prescription.reps', {
          'type',
          'exact_reps',
        });
        _equal(exact, 'type', 'exact', '$path.prescription.reps');
        _positive(exact['exact_reps'], '$path.prescription.reps.exact_reps');
      } else {
        _positive(reps, '$path.prescription.reps');
      }
      if (dose.containsKey('rest_seconds')) {
        _positive(dose['rest_seconds'], '$path.prescription.rest_seconds');
      }
      _optionalStrings(dose, ['tempo', 'notes'], '$path.prescription');
      if (dose.containsKey('load') && dose.containsKey('target_rpe')) {
        _fail('$path.prescription', 'Choose load or target_rpe, never both.');
      }
      if (dose.containsKey('target_rpe')) {
        _rpe(dose['target_rpe'], '$path.target_rpe');
      }
      if (dose.containsKey('load')) {
        final load = _map(dose['load'], '$path.load', {'unit', 'value'});
        switch (load['unit']) {
          case 'bodyweight':
            if (load.containsKey('value')) {
              _fail('$path.load.value', 'Bodyweight has no value.');
            }
          case 'kg':
            final value = load['value'];
            if (value is! num || !value.isFinite || value <= 0) {
              _fail(
                '$path.load.value',
                'Enter positive finite numeric kilograms.',
              );
            }
          case 'rpe':
            _rpe(load['value'], '$path.load.value');
          default:
            _fail('$path.load.unit', 'D2 supports bodyweight, kg or rpe only.');
        }
      }
    }
    // JSON conversion detaches YAML containers; source text remains retained.
    return jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
  }

  /// Normalization follows the existing parser/mapper, not a new prescription.
  Map<String, dynamic> canonicalTree(
    String source, {
    required String importKey,
  }) {
    final root = read(source, importKey: importKey);
    void normalize(Object? node) {
      if (node is Map<String, dynamic>) {
        for (final key in node.keys.toList()) {
          final value = node[key];
          if (value is String) {
            final text = value.trim();
            if (text.isEmpty) {
              node.remove(key);
            } else {
              node[key] = text;
            }
          } else {
            normalize(value);
          }
        }
      } else if (node is List) {
        for (final item in node) {
          normalize(item);
        }
      }
    }

    normalize(root);
    for (final e in exerciseRows(root)) {
      final dose = e['prescription'] as Map<String, dynamic>;
      if (dose['reps'] is Map) {
        dose['reps'] = (dose['reps'] as Map)['exact_reps'];
      }
      if (dose.containsKey('target_rpe')) {
        dose['load'] = {'unit': 'rpe', 'value': dose.remove('target_rpe')};
      }
      final load = dose['load'];
      if (load is Map && load['unit'] == 'kg') {
        // Existing mapper always compiles kg as a double.
        load['value'] = (load['value'] as num).toDouble();
      }
    }
    return root;
  }

  static Map<String, dynamic> session(Map<String, dynamic> root) =>
      ((((root['weeks'] as List).single as Map)['days'] as List).single
                  as Map)['sessions']
              .single
          as Map<String, dynamic>;
  static Map<String, dynamic> block(Map<String, dynamic> root) =>
      (session(root)['blocks'] as List).single as Map<String, dynamic>;
  static List<Map<String, dynamic>> exerciseRows(Map<String, dynamic> root) =>
      (block(root)['exercises'] as List).cast<Map<String, dynamic>>();

  Map _map(Object? value, String path, Set<String> allowed) {
    if (value is! Map) _fail(path, 'Expected a mapping.');
    for (final key in value.keys) {
      if (key is! String || !allowed.contains(key)) {
        _fail(
          '$path.$key',
          'Unsupported field; retained source must be corrected explicitly.',
        );
      }
    }
    return value;
  }

  Object? _one(Object? value, String path) {
    if (value is! List || value.length != 1) {
      _fail(path, 'D2 requires exactly one item.');
    }
    return value.single;
  }

  void _equal(Map map, String key, Object value, String path) {
    if (map[key] != value || map[key].runtimeType != value.runtimeType) {
      _fail('$path.$key', 'Required fixed value: $value.');
    }
  }

  void _requiredString(Map map, String key, String path) {
    if (map[key] is! String || (map[key] as String).trim().isEmpty) {
      _fail(
        '$path.$key',
        key == 'transitional_exercise_id'
            ? 'missing_exercise_reference: choose an exact fixture identity.'
            : 'Enter a nonblank string.',
      );
    }
  }

  void _optionalStrings(Map map, List<String> keys, String path) {
    for (final key in keys) {
      if (map.containsKey(key) && map[key] is! String) {
        _fail('$path.$key', 'Use a string or omit the field.');
      }
    }
  }

  void _positive(Object? value, String path) {
    if (value is! int || value <= 0) _fail(path, 'Enter a positive integer.');
  }

  void _rpe(Object? value, String path) {
    _positive(value, path);
    if ((value as int) > 10) _fail(path, 'D2 authoring RPE must be 1–10.');
  }

  Never _fail(String path, String message) =>
      throw FormatException('$path: $message');

  void _syntax(String source) {
    // Inspect only unquoted syntax, skipping literal/folded scalar contents.
    int? scalarIndent;
    String? quote;
    for (final line in source.split('\n')) {
      final indent = line.length - line.trimLeft().length;
      if (scalarIndent != null) {
        if (line.trim().isEmpty || indent > scalarIndent) continue;
        scalarIndent = null;
      }
      var visible = '';
      for (var i = 0; i < line.length; i++) {
        final c = line[i];
        if (quote != null) {
          if (quote == '"' && c == '\\') {
            i++;
            continue;
          }
          if (c == quote) {
            if (quote == "'" && i + 1 < line.length && line[i + 1] == "'") {
              i++;
              continue;
            }
            quote = null;
          }
          continue;
        }
        if (c == '#' && (i == 0 || line[i - 1].trim().isEmpty)) break;
        if ((c == '"' || c == "'") &&
            RegExp(r'(^|[:\[{},\-])\s*$').hasMatch(visible)) {
          quote = c;
          visible += ' ';
          continue;
        }
        visible += c;
      }
      if (RegExp(r'(^|[:\[{},\-])\s*([&*!][^\s]+|<<\s*:)').hasMatch(visible)) {
        _fail(
          'source',
          'YAML anchors, aliases, tags and merges are outside D2 intake.',
        );
      }
      if (RegExp(r':\s*[|>][+\-0-9]*\s*$').hasMatch(visible)) {
        scalarIndent = indent;
      }
    }
  }
}
