import 'dart:convert';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:crypto/crypto.dart';

import '../../../core/persistence/session_execution_plan_codec.dart';
import '../../../models/session_block_type.dart';
import '../../../models/block_performance_capture_mode.dart';
import '../../../models/strength_exercise_prescription.dart';
import '../../../models/strength_prescription_formatter.dart';
import '../../../models/timer_configuration.dart';
import '../../../models/workout_format.dart';
import '../../private_programme/reviewed_protocol_graph_artifact.dart';
import '../../session/models/session_execution_plan.dart';
import '../../session_revision/models/session_revision_usage_models.dart';
import '../workspace_json.dart';

String nativeDigest(String source) =>
    sha256.convert(utf8.encode(source)).toString();
Map<String, dynamic> nativeCopy(Map value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
bool nativeEqual(Object? a, Object? b) =>
    encodeWorkspaceJson(a) == encodeWorkspaceJson(b);

/// Editable files may retain invalid ordinary input strings, never arbitrary
/// executable fields or alternative representations smuggled in as a draft.
void guardNativeDraftShape(String source) {
  final graph = readWorkspaceJson(source);
  for (final b in workspaceList(graph['blocks'], 'native blocks', max: 32)) {
    for (final e in workspaceList(
      b['exercises'],
      'native exercises',
      max: 32,
    )) {
      final p = workspaceFields(e['prescription'], nativePrescriptionFields, {
        'sets',
        'reps',
      }, 'prescription');
      final reps = p['reps'];
      if (reps is! Map<String, dynamic>) {
        workspaceInvalid('Invalid repetitions wrapper.');
      }
      final keys = switch (reps['type']) {
        'exact' => {'type', 'exact_reps'},
        'range' => {'type', 'min_reps', 'max_reps'},
        'duration' => {'type', 'text'},
        _ => throw const FormatException(
          'Unsupported repetitions representation.',
        ),
      };
      workspaceObject(reps, keys, 'repetitions');
      if (p['load'] != null) {
        final load = workspaceObject(p['load'], {'type'}, 'load selection');
        if (load['type'] != 'athleteSelected') {
          workspaceInvalid(
            'Only the selected athlete-load convention is supported.',
          );
        }
      }
      if (p['authored_details'] != null) {
        workspaceFields(
          p['authored_details'],
          nativeAuthoredFields,
          {},
          'authored details',
        );
      }
    }
  }
}

const nativePrescriptionFields = {
  'sets',
  'reps',
  'per_side',
  'tempo',
  'coach_cue',
  'authored_details',
  'load',
  'rest_seconds',
  'rest_seconds_range',
  'rest_after_group_seconds_range',
  'rir_range',
  'performance_capture',
  'hold_seconds',
};
const nativeAuthoredFields = {
  'source_occurrence_id',
  'source_repetitions_or_duration',
  'source_rir',
  'source_tempo_reference',
  'source_rest_seconds',
  'selection',
  'variant_key',
  'source_dose_status',
  'planned_load_increase',
  'rest_location',
};

/// Immutable caller-verified legacy rows. This never synthesises definitions,
/// versions, published states or missing setup evidence from an exercise name.
class LegacyCatalogueEvidence {
  LegacyCatalogueEvidence(Map<String, dynamic> intake)
    : _source = jsonEncode(intake) {
    final bindings = intake['verified_bindings'] as Map;
    final rows = intake['catalogue_rows'] as Map;
    for (final id in bindings.values) {
      final evidence = rows[id] as Map;
      if ((evidence['catalogue_row'] as Map)['published'] != true ||
          evidence['row_sha256'] is! String ||
          evidence['source_sha256'] is! String) {
        throw const FormatException(
          'Retained catalogue evidence is incomplete.',
        );
      }
    }
  }
  final String _source;
  Map<String, dynamic> get source => nativeCopy(jsonDecode(_source) as Map);
  Map<String, dynamic> get bindings =>
      Map<String, dynamic>.from(source['verified_bindings'] as Map);
  Map<String, dynamic>? rowFor(String variant) {
    final id = bindings[variant];
    if (id == null) return null;
    return nativeCopy((source['catalogue_rows'] as Map)[id] as Map);
  }

  String? idFor(String variant) => bindings[variant] as String?;
}

class NativeSessionReceipt {
  NativeSessionReceipt({
    required this.source,
    required this.identity,
    required this.plan,
    required this.readable,
    required this.issues,
  });
  final String source;
  final SessionRevisionIdentity identity;
  final SessionExecutionPlan? plan;
  final String readable;
  final List<String> issues;
  String get digest => nativeDigest(source);
  bool get admitted => issues.isEmpty && plan != null;
}

/// Pure native adapter. Pending null-ID intent can be read and saved, but never
/// returns an admitted plan or enters the canonical private graph decoder.
class NativeSessionCompiler {
  const NativeSessionCompiler();
  NativeSessionReceipt compile({
    required String source,
    required SessionRevisionIdentity identity,
    required LegacyCatalogueEvidence catalogue,
    required String title,
  }) {
    final graph = readWorkspaceJson(source);
    final issues = <String>[];
    final readable = <String>[title];
    final blocks = <SessionExecutionBlock>[];
    workspaceFields(
      graph,
      {
        'protocol_id',
        'revision_number',
        'source_session_id',
        'classification',
        'blocks',
      },
      {'protocol_id', 'revision_number', 'blocks'},
      'native graph',
    );
    if (graph['protocol_id'] != identity.protocolId ||
        graph['revision_number'] != identity.revisionNumber) {
      throw const FormatException('Session source and local revision differ.');
    }
    if ((graph['blocks'] as List).isEmpty) {
      issues.add('Add a complete strength or structured-running block.');
    }
    for (final raw in workspaceList(graph['blocks'], 'blocks', max: 32)) {
      final b = workspaceFields(
        raw,
        {
          'position',
          'block_id',
          'block_type',
          'title',
          'content',
          'coach_notes',
          'workout_format',
          'performance_capture_mode',
          'timer_config',
          'exercises',
        },
        {
          'position',
          'block_type',
          'title',
          'content',
          'workout_format',
          'exercises',
        },
        'block',
      );
      if (!{
            'warm_up',
            'strength',
            'cool_down',
            'conditioning',
          }.contains(b['block_type']) ||
          !{'none', 'steady_state'}.contains(b['workout_format']) ||
          !{
            null,
            'auto',
            'endurance',
          }.contains(b['performance_capture_mode'])) {
        throw const FormatException(
          'Unsupported block type, timer or capture mode in this bounded source.',
        );
      }
      if (b['position'] != blocks.length + 1) {
        issues.add('Keep blocks in consecutive order.');
      }
      readable.add('\n${b['title']}\n${b['content']}');
      if (b['block_type'] == 'strength' && (b['exercises'] as List).isEmpty) {
        issues.add(
          '${b['title']}: add at least one complete working exercise.',
        );
      }
      if (b['coach_notes'] != null) readable.add('${b['coach_notes']}');
      final summaries = <SessionExecutionExerciseSummary>[];
      var exercisePosition = 0;
      for (final rawExercise in workspaceList(
        b['exercises'],
        'exercises',
        max: 32,
      )) {
        final e = workspaceFields(
          rawExercise,
          {
            'position',
            'exercise_id',
            'variant_key',
            'source_occurrence_id',
            'display_label_override',
            'prescription',
            'content_holds',
            'effective_dose_status',
          },
          {
            'position',
            'exercise_id',
            'variant_key',
            'display_label_override',
            'prescription',
          },
          'exercise',
        );
        final label = workspaceString(
          e['display_label_override'],
          'exercise name',
        );
        if (e['position'] != ++exercisePosition) {
          issues.add('$label: keep exercise order consecutive.');
        }
        final variant = workspaceString(e['variant_key'], 'setup selection');
        if ((e['content_holds'] as List? ?? []).isNotEmpty) {
          issues.add(
            '$label: resolve retained content holds before preparation: ${e['content_holds']}',
          );
        }
        final row = catalogue.rowFor(variant);
        final id = catalogue.idFor(variant);
        if (id == null || e['exercise_id'] != id) {
          issues.add(
            '$label: Unresolved exercise setup — cannot prepare for publication.',
          );
        }
        if (row != null) {
          final r = row['catalogue_row'] as Map;
          readable.add(
            '$label\nRetained equipment: ${r['equipment'] ?? 'unknown'}; setup: ${r['setup'] ?? 'unknown'}; execution: ${r['execution'] ?? 'unknown'}',
          );
        } else {
          readable.add(
            '$label\nUnresolved exercise setup — cannot prepare for publication.',
          );
        }
        try {
          final p = workspaceFields(
            e['prescription'],
            {
              'sets',
              'reps',
              'per_side',
              'tempo',
              'coach_cue',
              'authored_details',
              'load',
              'rest_seconds',
              'rest_seconds_range',
              'rest_after_group_seconds_range',
              'rir_range',
              'performance_capture',
              'hold_seconds',
            },
            {'sets', 'reps'},
            '$label prescription',
          );
          if (p['sets'] is! int ||
              (p['sets'] as int) < 1 ||
              (p['sets'] as int) > 100) {
            throw const FormatException(
              'Sets must be a whole number from 1 to 100.',
            );
          }
          final prescription = StrengthExercisePrescription.fromJson(p);
          final errors = prescription.validate(requireComplete: true);
          if (errors.isNotEmpty) throw FormatException(errors.join(' '));
          if (prescription.restSeconds != null &&
              (prescription.restSeconds! < 0 ||
                  prescription.restSeconds! > 3600)) {
            throw const FormatException(
              'Rest must be a whole number from 0 to 3600 seconds.',
            );
          }
          if (prescription.reps.type == StrengthRepType.duration) {
            final hold = RegExp(
              r'^(\d+)(?:[–-](\d+))?\s*(?:sec|seconds|s)(?:/side)?$',
            ).firstMatch(prescription.reps.text ?? '');
            if (hold == null ||
                int.parse(hold.group(1)!) <= 0 ||
                int.parse(hold.group(2) ?? hold.group(1)!) <
                    int.parse(hold.group(1)!)) {
              throw const FormatException(
                'Enter a valid hold duration, for example 30–45 sec/side.',
              );
            }
          }
          // The typed parser must consume every executable field. Explicit
          // per_side=false is the codec's sole optional default normalisation.
          final normalized = nativeCopy(p)
            ..removeWhere((k, v) => k == 'per_side' && v == false);
          if (normalized['performance_capture'] is Map) {
            (normalized['performance_capture'] as Map).putIfAbsent(
              'duration_optional',
              () => false,
            );
          }
          if (!nativeEqual(normalized, prescription.toJson())) {
            throw const FormatException(
              'A prescription field is not losslessly supported. Correct its value.',
            );
          }
          final details = p['authored_details'] as Map? ?? {};
          workspaceFields(
            Map<String, dynamic>.from(details),
            {
              'source_occurrence_id',
              'source_repetitions_or_duration',
              'source_rir',
              'source_tempo_reference',
              'source_rest_seconds',
              'selection',
              'variant_key',
              'source_dose_status',
              'planned_load_increase',
              'rest_location',
            },
            {},
            'authored prescription details',
          );
          final rir = details['source_rir'];
          if (rir != null &&
              (rir is! String ||
                  !RegExp(
                    r'^(N/A|\d+(?:[–-]\d+)?|at least \d+)$',
                  ).hasMatch(rir))) {
            throw const FormatException(
              'Choose absent, exact, range or at-least RIR with whole numbers.',
            );
          }
          if (rir is String &&
              rir.startsWith('at least ') &&
              (p['rir_range'] != null || int.parse(rir.substring(9)) > 10)) {
            throw const FormatException(
              'At-least RIR has no upper bound; enter a whole minimum from 0 to 10.',
            );
          }
          if (prescription.rirRange != null &&
              prescription.rirRange!.max > 10) {
            throw const FormatException('RIR must be from 0 to 10.');
          }
          final capture = p['performance_capture'] as Map?;
          if (capture != null) {
            workspaceFields(
              Map<String, dynamic>.from(capture),
              {'load_unit', 'load_label', 'rpe', 'duration_optional'},
              {},
              'capture',
            );
            if (capture['load_unit'] != null &&
                !{'kg', 'lb'}.contains(capture['load_unit'])) {
              throw const FormatException(
                'Choose a supported external load unit.',
              );
            }
          }
          readable.add(
            [
              StrengthPrescriptionFormatter.summaryLine(prescription),
              StrengthPrescriptionFormatter.detailLine(prescription),
              if (details['source_rir'] != null)
                'Authored RIR: ${details['source_rir']}',
              if (prescription.perSide) 'Each side; both sides form one set.',
              if (details['rest_location'] != null)
                'Rest: ${details['rest_location']}',
              if (capture != null)
                'Load logging: ${capture['load_label'] ?? 'unknown'}; unit ${capture['load_unit'] ?? 'actual displayed unit/setup'}',
              if (details['planned_load_increase'] == false)
                'No planned load increase.',
              if (prescription.coachCue != null) prescription.coachCue!,
            ].where((v) => v.isNotEmpty).join('\n'),
          );
          summaries.add(
            SessionExecutionExerciseSummary(
              exerciseId: id ?? '',
              displayName: label,
              displayLabelOverride: label,
              position: e['position'] as int,
              prescription: prescription,
            ),
          );
        } on FormatException catch (error) {
          issues.add('$label: ${error.message}');
          // Invalid input is visible without claiming a typed prescription.
          readable.add(
            'Invalid prescription — correct the highlighted fields.',
          );
        } on TypeError {
          issues.add('$label: correct the prescription field types.');
        }
      }
      TimerConfiguration? timer;
      if (b['timer_config'] != null) {
        try {
          final rawTimer = Map<String, dynamic>.from(b['timer_config'] as Map);
          timer = TimerConfiguration.fromJson(rawTimer);
          final normalizedTimer = nativeCopy(rawTimer)
            ..putIfAbsent('stopwatchEnabled', () => false);
          normalizedTimer.putIfAbsent(
            'totalDurationSeconds',
            () => rawTimer['durationSeconds'],
          );
          if (!nativeEqual(normalizedTimer, timer.toJson())) {
            throw const FormatException(
              'A timer field is not losslessly supported.',
            );
          }
          final errors = timer.validateForFormat(
            WorkoutFormatDb.fromDb(b['workout_format'] as String),
          );
          if (errors.isNotEmpty) throw FormatException(errors.join(' '));
          final workout = rawTimer['running_workout'] as Map;
          readable.add('${workout['notes'] ?? ''}');
          final total = runningTotals(workout);
          readable.add(
            'Timed total: ${formatRunSeconds(total.seconds)}${total.metres == 0 ? '' : ' plus ${total.metres} m; athlete confirms external distance, no live distance sensor'}',
          );
          for (final step in workout['steps'] as List) {
            final duration = step['duration'] as Map;
            final target = step['target'] as Map;
            readable.add(
              '${step['label']} · ${duration['kind'] == 'time' ? formatRunSeconds((duration['milliseconds'] as int) ~/ 1000) : '${(duration['millimetres'] as int) ~/ 1000} m'} · ${targetLabel(target)}\n${step['notes'] ?? ''}',
            );
          }
        } catch (error) {
          issues.add('${b['title']}: correct the running phases. $error');
        }
      }
      blocks.add(
        SessionExecutionBlock(
          blockId:
              b['block_id'] as String? ??
              '${identity.protocolId}-block-${blocks.length + 1}',
          title: b['title'] as String,
          content: b['content'] as String,
          coachNotes: b['coach_notes'] as String?,
          blockType: SessionBlockTypeDb.fromDb(b['block_type'] as String),
          workoutFormat: WorkoutFormatDb.fromDb(b['workout_format'] as String),
          position: b['position'] as int,
          timerConfiguration: timer,
          linkedExercises: summaries,
          performanceCaptureMode: BlockPerformanceCaptureModeDb.fromDb(
            b['performance_capture_mode'] as String?,
          ),
        ),
      );
    }
    final plan = SessionExecutionPlan(
      sessionId: identity.protocolId,
      sessionTitle: title,
      blocks: blocks,
    );
    if (!blocks.any(
      (b) =>
          b.linkedExercises.isNotEmpty ||
          b.timerConfiguration?.runningWorkout != null,
    )) {
      issues.add(
        'Add a complete working prescription. Preparation and finish alone are not a complete session.',
      );
    }
    const codec = SessionExecutionPlanCodec();
    final encoded = codec.encodePlan(plan);
    if (!nativeEqual(
      encoded,
      codec.encodePlan(codec.decodePlan(nativeCopy(encoded))),
    )) {
      issues.add('Native execution restore changed this prescription.');
    }
    return NativeSessionReceipt(
      source: source,
      identity: identity,
      plan: issues.isEmpty ? plan : null,
      readable: readable.join('\n'),
      issues: List.unmodifiable(issues),
    );
  }

  ReviewedProtocolGraphResult inspect(
    PlanPackageCompileResult package,
    String graphs,
  ) => const ReviewedProtocolGraphArtifact().inspect(
    compileResult: package,
    source: graphs,
    expectedSha256: nativeDigest(graphs),
  );
}

String formatRunSeconds(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
({int seconds, int metres}) runningTotals(Map workout) {
  var seconds = 0, metres = 0;
  for (final step in workout['steps'] as List) {
    if (step['kind'] != 'atomic') {
      throw const FormatException(
        'Expand repetitions into ordered native phases.',
      );
    }
    final d = step['duration'] as Map;
    if (d['kind'] == 'time') {
      final ms = d['milliseconds'];
      if (ms is! int || ms <= 0 || ms % 1000 != 0) {
        throw const FormatException('Enter positive whole seconds.');
      }
      seconds += ms ~/ 1000;
    } else if (d['kind'] == 'distance' &&
        d['millimetres'] == 10000000 &&
        step['role'] == 'work') {
      metres += 10000;
    } else {
      throw const FormatException(
        'Only the selected final 10,000 m distance shape is supported.',
      );
    }
  }
  if (metres > 10000 ||
      metres > 0 &&
          (seconds != 1980 ||
              (workout['steps'] as List).length < 2 ||
              workout['steps'][(workout['steps'] as List).length -
                      2]['duration']['kind'] !=
                  'distance')) {
    throw const FormatException(
      'Retain the exact selected final 10,000 m body and 33 timed minutes; arbitrary distance workouts are outside this form.',
    );
  }
  return (seconds: seconds, metres: metres);
}

String targetLabel(Map target) => switch (target['kind']) {
  'none' => 'Authored effort; no fixed pace/HR',
  'heart_rate_zone_ref' =>
    'Athlete-confirmed Zone 2 — athlete input and review required',
  'alpha_quality_pace_v1' =>
    '${target['category']} · approved M2.3 personalisation rule; explicit athlete source/review/acceptance required; no fallback',
  'rpe_range' => 'Authored RPE ${target['low']}–${target['high']} / 10',
  _ => throw const FormatException('Choose an approved target dependency.'),
};
