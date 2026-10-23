/// Lossless server values. Only presentation rounds exact pace fractions.
/// No profile read or target calculation is performed by this projection.
class ProgrammePrescription {
  ProgrammePrescription(Map<String, dynamic> packet) : json = _freeze(packet) {
    if (json['schema_version'] != 1 || json['prescriptions'] is! List) {
      throw const FormatException('Unsupported programme targets.');
    }
    targets = List.unmodifiable(
      (json['prescriptions'] as List).map((value) {
        if (value is! Map) throw const FormatException('Invalid target.');
        return ProgrammeTarget(Map<String, dynamic>.from(value));
      }),
    );
  }
  final Map<String, dynamic> json;
  late final List<ProgrammeTarget> targets;
}

class ProgrammeTarget {
  ProgrammeTarget(Map<String, dynamic> value) : json = _freeze(value) {
    if (!{
          'runningIntervals',
          'dedicatedRowIntervals',
          'backSquat',
        }.contains(kind) ||
        binding['identity_namespace'] != 'canonical_exercise' ||
        binding['block_id'] is! String ||
        binding['step_ids'] is! List ||
        json['authored'] is! Map ||
        json['calculated'] is! Map ||
        json['steps'] is! List ||
        json['actual'] != null) {
      throw const FormatException('Unsupported programme target.');
    }
    if (calculated['status'] == 'calculated') {
      if (kind == 'backSquat') {
        if (calculated['unit'] != 'grams_total_external_load' ||
            calculated['grams'] is! int ||
            (calculated['grams'] as int) <= 0) {
          throw const FormatException('Unsupported squat load.');
        }
      } else {
        if (calculated['unit'] !=
            (isRow
                ? 'milliseconds_per_500_metres'
                : 'milliseconds_per_kilometre')) {
          throw const FormatException('Unsupported pace unit.');
        }
        for (final key in ['faster', 'slower']) {
          final fraction = calculated[key];
          if (fraction is! Map ||
              fraction['numerator'] is! num ||
              fraction['denominator'] is! num ||
              fraction['numerator'] <= 0 ||
              fraction['denominator'] <= 0) {
            throw const FormatException('Invalid pace window.');
          }
        }
      }
    } else if (calculated['status'] != 'unavailable' ||
        !{
          'missing_benchmark',
          'missing_or_invalid_increment',
          'rounded_load_not_positive_use_authored_rir',
        }.contains(calculated['code'])) {
      throw const FormatException('Unsupported target capability.');
    }
  }
  final Map<String, dynamic> json;
  Map get binding => json['binding'] as Map;
  Map get authored => json['authored'] as Map;
  Map get calculated => json['calculated'] as Map;
  String get kind => binding['kind'] as String;
  String get blockId => binding['block_id'] as String;
  bool get isRow => kind == 'dedicatedRowIntervals';
  bool get available => calculated['status'] == 'calculated';
  String get label => switch (kind) {
    'runningIntervals' => 'Running',
    'dedicatedRowIntervals' => 'Rowing',
    _ => 'Back squat',
  };
  String get dose => kind == 'backSquat'
      ? '${authored['sets']} × ${authored['reps']} · RIR ${authored['rir']}'
      : '${authored['repetitions']} × ${authored['work_seconds']} s · ${authored['recovery_seconds']} s recovery between repetitions';
  String get targetLabel {
    if (!available) {
      final reason = calculated['code'] == 'missing_benchmark'
          ? 'Benchmark not selected'
          : 'Available barbell increment or rounded load unavailable';
      final effort = json['authored_effort'];
      return 'Numerical target unavailable: $reason.${effort == null ? '' : ' Use authored $effort.'}';
    }
    if (kind == 'backSquat') {
      return '${(calculated['grams'] as int) / 1000} kg total external load';
    }
    return '${_pace(calculated['faster'] as Map)}–${_pace(calculated['slower'] as Map)} ${isRow ? '/500 m' : '/km'}';
  }

  String get benchmarkLabel {
    final b = json['benchmark_revision'];
    if (b == null) return 'No benchmark selected';
    final metric = switch (b['metric']) {
      'run10km' => '10 km run',
      'row2km' => '2 km row',
      _ => 'Back squat 5RM',
    };
    return '$metric: ${b['raw_value']} ${benchmarkUnit(b['input_unit'])} · ${b['test_date']} · ${benchmarkSource(b['source_type'])} · ${b['source_reference']}';
  }

  static String _pace(Map f) {
    final tenths = ((f['numerator'] as num) / (f['denominator'] as num) / 100)
        .round();
    return '${tenths ~/ 600}:${((tenths % 600) / 10).toStringAsFixed(1).padLeft(4, '0')}';
  }
}

String benchmarkUnit(Object? unit) => switch (unit) {
  'seconds' => 's',
  'minutes' => 'min',
  'kilograms' => 'kg',
  'pounds' => 'lb',
  'count' => 'reps',
  _ => unit.toString(),
};
String benchmarkSource(Object? source) => switch (source) {
  'knownResult' => 'Known result',
  'recordedResult' => 'Recorded result',
  _ => 'Declared result',
};
Map<String, dynamic> _freeze(Map value) => Map.unmodifiable({
  for (final e in value.entries) e.key as String: _freezeValue(e.value),
});
Object? _freezeValue(Object? value) => value is Map
    ? _freeze(value)
    : value is List
    ? List.unmodifiable(value.map(_freezeValue))
    : value;
bool samePrescription(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every(
          (key) => b.containsKey(key) && samePrescription(a[key], b[key]),
        );
  }
  if (a is List && b is List) {
    return a.length == b.length &&
        List.generate(
          a.length,
          (i) => i,
        ).every((i) => samePrescription(a[i], b[i]));
  }
  return a == b;
}
