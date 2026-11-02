import '../../../core/utils/database_uuid.dart';

import 'native_session_source.dart';

/// Ordinary training field conversion to existing native prescription JSON.
/// Invalid strings stay strings, are saved, and fail the compiler visibly.
Object integerInput(String text) => int.tryParse(text) ?? text;
List<Object> rangeInput(String low, String high) => [
  integerInput(low),
  integerInput(high),
];

void setRir(
  Map<String, dynamic> prescription,
  String mode,
  String low,
  String high,
) {
  final details =
      prescription.putIfAbsent('authored_details', () => <String, dynamic>{})
          as Map;
  prescription.remove('rir_range');
  details['source_rir'] = switch (mode) {
    'absent' => 'N/A',
    'at_least' => 'at least $low',
    'range' => '$low–$high',
    _ => low,
  };
  if (mode == 'exact' || mode == 'range') {
    prescription['rir_range'] = rangeInput(low, mode == 'range' ? high : low);
  }
}

void setRest(
  Map<String, dynamic> prescription,
  String low,
  String high,
  bool afterBothSides,
) {
  prescription.remove('rest_seconds');
  prescription.remove('rest_seconds_range');
  final details =
      prescription.putIfAbsent('authored_details', () => <String, dynamic>{})
          as Map;
  details['source_rest_seconds'] = low == high ? low : '$low–$high';
  details['rest_location'] = afterBothSides
      ? 'after both sides; no prescribed intra-side rest'
      : 'between working sets';
  if (low == high) {
    prescription['rest_seconds'] = integerInput(low);
  } else {
    prescription['rest_seconds_range'] = rangeInput(low, high);
  }
}

Map<String, dynamic> nativePhase({
  String role = 'work',
  String title = '',
  int seconds = 60,
  Map<String, dynamic> target = const {'kind': 'none'},
  String notes = '',
}) => {
  'kind': 'atomic',
  'step_id': DatabaseUuid.newV4(),
  'role': role,
  'duration': {'kind': 'time', 'milliseconds': seconds * 1000},
  'target': nativeCopy(target),
  'label': title,
  'notes': notes,
};

/// Repeat is a form convenience only. The saved/executable source is ordinary
/// ordered native atomic phases; final recovery is an explicit choice.
List<Map<String, dynamic>> expandRepeat({
  required Map<String, dynamic> work,
  required Map<String, dynamic> recovery,
  required int count,
  required bool recoveryAfterLast,
}) {
  if (count < 1 || count > 50) {
    throw const FormatException('Repeat count must be from 1 to 50.');
  }
  return [
    for (var i = 0; i < count; i++) ...[
      nativeCopy(work)..['step_id'] = DatabaseUuid.newV4(),
      if (i < count - 1 || recoveryAfterLast)
        nativeCopy(recovery)..['step_id'] = DatabaseUuid.newV4(),
    ],
  ];
}

void syncTimer(Map<String, dynamic> block) {
  final timer = block['timer_config'] as Map;
  try {
    timer['durationSeconds'] = runningTotals(
      timer['running_workout'] as Map,
    ).seconds;
  } on FormatException {
    /* invalid fields remain editable; compiler reports them */
  }
}

void moveNativeRow(List rows, int from, int to, {bool positions = true}) {
  if (from < 0 || to < 0 || from >= rows.length || to >= rows.length) return;
  rows.insert(to, rows.removeAt(from));
  if (positions) {
    for (var i = 0; i < rows.length; i++) {
      rows[i]['position'] = i + 1;
    }
  }
}
