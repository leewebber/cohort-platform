import 'package:founder_importer/features/founder_programme_import/founder_programme_prescription_mapper.dart';

import '../../../models/strength_exercise_prescription.dart';
import '../../../models/strength_prescription_formatter.dart';
import '../domain/programme_review_models.dart';
import '../workspace_json.dart';

/// A read-only display of retained fields, never a canonicalisation, validation
/// receipt, editor input or executable prescription. Unhandled fields stay raw.
class MovementPrescriptionReview {
  MovementPrescriptionReview._(List<String> lines, List<String> limitations)
    : lines = List.unmodifiable(lines),
      limitations = List.unmodifiable(limitations);
  final List<String> lines, limitations;
  bool get complete => limitations.isEmpty;

  static MovementPrescriptionReview fromMovement(
    ProgrammeReviewMovement movement,
  ) {
    final lines = <String>[], limitations = <String>[];
    final raw = movement.rawPrescription;
    if (raw == null) {
      lines.addAll([
        if (movement.sets != null) '${movement.sets} sets',
        if (movement.reps != null) '${movement.reps} reps',
        if (movement.duration != null) movement.duration!,
        if (movement.distance != null) movement.distance!,
        if (movement.recovery != null) 'Rest ${movement.recovery}',
        if (movement.notes != null) movement.notes!,
      ]);
      return MovementPrescriptionReview._(lines, limitations);
    }
    Map<String, dynamic> fields;
    try {
      // Reuse bounded, duplicate-aware JSON reading; this installs no workspace
      // state and does not apply an editable-workspace schema to prescriptions.
      fields = readWorkspaceJson(raw);
    } on FormatException {
      return MovementPrescriptionReview._([], [
        'Prescription is malformed, ambiguous or outside review limits; inspect the retained source.',
      ]);
    }
    final handled = <String>{};
    void scalar(
      String key,
      String label, {
      String suffix = '',
      bool quote = false,
      bool boolean = false,
    }) {
      if (!fields.containsKey(key)) return;
      handled.add(key);
      final value = fields[key];
      if (value is String || value is num || (boolean && value is bool)) {
        final display = quote && value is String ? '“$value”' : '$value';
        lines.add('$label$display$suffix');
      } else {
        limitations.add(
          'Unsupported value for $key; retained without interpretation.',
        );
      }
    }

    scalar('sets', '', suffix: ' sets');
    if (fields.containsKey('reps')) {
      handled.add('reps');
      final value = fields['reps'];
      if (value is String || value is num) {
        lines.add('$value reps');
      } else if (value is Map<String, dynamic>) {
        try {
          final type = value['type'];
          final keys = switch (type) {
            'exact' => {'type', 'exact_reps'},
            'range' when value.containsKey('min') || value.containsKey('max') =>
              {'type', 'min', 'max'},
            'range' => {'type', 'min_reps', 'max_reps'},
            'duration' ||
            'distance' ||
            'freeText' ||
            'maxEffort' ||
            'max_effort' => {'type', 'text'},
            _ => <String>{},
          };
          if (keys.isEmpty || value.keys.any((k) => !keys.contains(k))) {
            throw const FormatException('Unsupported reps fields.');
          }
          var reps = value;
          if (value.containsKey('min') || type == 'max_effort') {
            final mapped = const FounderProgrammePrescriptionMapper()
                .mapPrescription({'reps': value});
            if (mapped == null) {
              throw const FormatException('Incomplete Founder reps.');
            }
            reps = mapped.reps.toJson();
          }
          final typed = StrengthRepPrescription.fromJson(reps);
          if (typed.validate(requireComplete: true).isNotEmpty) {
            throw const FormatException('Incomplete typed reps.');
          }
          final formatted = StrengthPrescriptionFormatter.formatReps(typed);
          lines.add(switch (typed.type) {
            StrengthRepType.duration => 'Duration: $formatted',
            StrengthRepType.distance => 'Distance: $formatted',
            _ => '$formatted reps',
          });
        } on FormatException {
          limitations.add('Unsupported reps; retained without interpretation.');
        }
      } else {
        limitations.add('Unsupported reps; retained without interpretation.');
      }
    }
    if (fields.containsKey('load')) {
      handled.add('load');
      try {
        lines.add(_load(fields['load']));
      } on FormatException {
        limitations.add('Unsupported load; retained without interpretation.');
      }
    } else if (fields.containsKey('sets') || fields.containsKey('reps')) {
      lines.add('Load: Unspecified');
    }
    if (fields.containsKey('load') && fields.containsKey('target_rpe')) {
      limitations.add(
        'Both load and target_rpe are present; neither overrides the other in this review.',
      );
    }
    scalar('target_rpe', 'Target RPE (authored): ');
    scalar('rir', 'RIR (authored): ');
    scalar('rpe', 'RPE (authored): ');
    for (final key in ['rest_seconds', 'recovery_seconds']) {
      if (fields[key] is int && (fields[key] as int) > 0) {
        handled.add(key);
        final formatted = StrengthPrescriptionFormatter.formatRest(
          fields[key] as int,
        )!;
        lines.add(
          key == 'rest_seconds'
              ? formatted
              : 'Recovery: ${fields[key]} seconds',
        );
      } else {
        scalar(
          key,
          key == 'rest_seconds' ? 'Rest: ' : 'Recovery: ',
          suffix: ' seconds (authored)',
        );
      }
    }
    scalar('tempo', 'Tempo ');
    scalar('eccentric_seconds', 'Eccentric: ', suffix: ' seconds (authored)');
    scalar('resistance', 'Resistance: ', quote: true);
    scalar('per_side', 'Per side: ', boolean: true);
    scalar('duration', 'Duration: ');
    scalar('duration_seconds', 'Duration: ', suffix: ' seconds');
    scalar('work_seconds', 'Work: ', suffix: ' seconds');
    scalar('distance', 'Distance (authored): ');
    scalar('distance_m', 'Distance: ', suffix: ' m');
    scalar('coach_cue', 'Cue: ', quote: true);
    scalar('notes', 'Prescription notes: ', quote: true);
    if (movement.notes != null &&
        movement.notes != fields['notes'] &&
        movement.notes != fields['coach_cue']) {
      lines.add(movement.notes!);
    }
    final remaining = fields.keys.where((k) => !handled.contains(k)).toList()
      ..sort();
    if (remaining.isNotEmpty) {
      limitations.add(
        'Additional fields are retained but not interpreted: ${remaining.join(', ')}.',
      );
    }
    return MovementPrescriptionReview._(lines, limitations);
  }

  static String _load(Object? value) {
    if (value is String) return 'Load (authored text): “$value”';
    if (value is num) {
      final typed = StrengthExercisePrescription.fromJson({
        'load': value,
      }).load!;
      return StrengthPrescriptionFormatter.formatLoad(typed)!;
    }
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Unsupported load.');
    }
    if (value.containsKey('type')) {
      final type = value['type'];
      final keys = switch (type) {
        'bodyweight' => {'type'},
        'fixedKg' => {'type', 'kg'},
        'percent1rm' => {'type', 'percent_1rm'},
        'rpe' => {'type', 'rpe'},
        'rir' => {'type', 'rir'},
        'athleteSelected' => {'type', 'unit'},
        'freeText' => {'type', 'text'},
        _ => <String>{},
      };
      if (keys.isEmpty || value.keys.any((k) => !keys.contains(k))) {
        throw const FormatException('Unsupported load fields.');
      }
      final typed = StrengthLoadPrescription.fromJson(value);
      if (!typed.hasValue || typed.validate().isNotEmpty) {
        throw const FormatException('Incomplete load.');
      }
      if (type == 'athleteSelected') {
        final unit = value['unit'];
        if (unit != null && unit is! String) {
          throw const FormatException('Unsupported load unit.');
        }
        return unit == null || unit == ''
            ? 'Load: athlete selected'
            : 'Load: athlete selected ($unit)';
      }
      return StrengthPrescriptionFormatter.formatLoad(typed)!;
    }
    if (value.keys.any((k) => !{'unit', 'value'}.contains(k)) ||
        (value['unit'] == 'bodyweight' && value.containsKey('value'))) {
      throw const FormatException('Unsupported Founder load fields.');
    }
    final mapped = const FounderProgrammePrescriptionMapper().mapPrescription({
      'load': value,
    });
    if (mapped?.load == null || mapped!.load!.validate().isNotEmpty) {
      throw const FormatException('Unsupported Founder load.');
    }
    return mapped.load!.toLegacyMetadataValue();
  }
}
