import '../../core/utils/frozen_json.dart';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:cohort_plan_package/cohort_plan_package.dart';
import '../../domain/exercise_knowledge/models/exercise_definition_lookup.dart';
import '../../domain/exercise_knowledge/ports/exercise_knowledge_repository.dart';
import '../../domain/exercise_knowledge/validation/exercise_knowledge_validator.dart';
import '../../domain/exercise_knowledge/value_objects/exercise_id.dart';
import '../../models/authored_int_range.dart';
import '../../models/block_performance_capture_mode.dart';
import '../../models/session_block.dart';
import '../../models/session_block_exercise_link.dart';
import '../../models/session_block_type.dart';
import '../../models/strength_exercise_prescription.dart';
import '../../models/timer_configuration.dart';
import '../../models/workout_format.dart';
import '../../features/session/models/session_execution_plan.dart';
import '../../features/session_builder/services/session_execution_plan_builder.dart';
import '../exercise_knowledge/published_version_retention.dart';

/// Explicit exact variant binding; neither a label nor a catalogue row supplies it.
class SessionExerciseVersionPin {
  const SessionExerciseVersionPin(this.id, this.version, this.digest);
  final String id, version, digest;
}

class CompiledCanonicalSessionSource {
  CompiledCanonicalSessionSource._(this.source, this.blocks, this.versions);
  final String source;
  final List<SessionBlock> blocks;
  final Map<String, Object?> versions;
  Map<String, dynamic> get document =>
      jsonDecode(source) as Map<String, dynamic>;
  String get sourceId => document['source_id'] as String;
  String get sourceDigest => personalisationTextDigest(source);
  SessionExecutionPlan
  get execution => const SessionExecutionPlanBuilder().build(
    authoredSource: document,
    sessionId: sourceId,
    sessionTitle:
        'HYROX Base · Week ${document['week']} · ${document['mode'].toString().replaceAll('_', ' ')}',
    blocks: blocks,
    coachNotes: (document['shared_policies'] as Map?)?['purpose'] as String?,
  );

  Map<String, dynamic> _exerciseRow(
    SessionBlock block,
    SessionBlockExerciseLink link,
  ) {
    final row = link.toRowMap(blockId: block.localId);
    final authored = link.prescription?.authoredDetails;
    if (authored?['exercise'] == 'back_squat' &&
        authored?['five_rm_basis_points'] != null) {
      row['prescription'] = {
        'sets': authored!['sets'],
        'reps': (authored['reps'] as List).first,
        'five_rm_basis_points': authored['five_rm_basis_points'],
        'rir': authored['rir'],
        'rest_seconds_range': authored['rest_seconds'],
      };
    }
    return row;
  }

  Map<String, Object?> get graph => {
    'source': document,
    'exact_versions': versions,
    'blocks': [
      for (final b in blocks)
        {
          ...b.toRowMap(sessionId: sourceId),
          'local_source_block': b.localId,
          if (b.workoutFormat == WorkoutFormat.intervals &&
              b.blockType == SessionBlockType.conditioning)
            'timer_config': {...b.timerConfiguration!.toJson()}
              ..remove('omitFinalRecovery')
              ..remove('targetRounds'),
          'exercises': [for (final e in b.linkedExercises) _exerciseRow(b, e)],
        },
    ],
  };

  /// Save/reopen transport preserves exact original source bytes and complete graph.
  /// This is a local source receipt, never an approval/event or historical version.
  String exportSource() => personalisationCanonicalJson({
    'format': 'hyrox-canonical-session-source-v1',
    'source_text': source,
    'source_digest': sourceDigest,
    'graph': graph,
  });
}

/// Lossless lowering into the established SessionBlock/runner models. All real
/// exercise bindings must resolve through the existing authoritative lookup and
/// verified producer port; there is no fallback fixture/catalogue/name resolver.
class CanonicalSessionSourceCompiler {
  const CanonicalSessionSourceCompiler({
    required this.lookup,
    required this.publicationAuthority,
    required this.pins,
  });
  final ExerciseKnowledgeRepository lookup;
  final ExerciseVersionPublicationAuthority publicationAuthority;
  final Map<String, SessionExerciseVersionPin> pins;

  Future<CompiledCanonicalSessionSource> reopen(String transport) async {
    final envelope = jsonDecode(transport) as Map;
    if (envelope.length != 4 ||
        envelope['format'] != 'hyrox-canonical-session-source-v1') {
      throw const FormatException('Invalid canonical source transport.');
    }
    final result = await compile(envelope['source_text'] as String);
    if (envelope['source_digest'] != result.sourceDigest ||
        personalisationCanonicalJson(envelope['graph']) !=
            personalisationCanonicalJson(result.graph)) {
      throw const FormatException(
        'Source export does not match recompilation.',
      );
    }
    return result;
  }

  Future<CompiledCanonicalSessionSource> compile(String text) async {
    final source = jsonDecode(text) as Map<String, dynamic>;
    if (text != personalisationCanonicalJson(source)) {
      throw const FormatException(
        'Canonical session source must have unambiguous canonical JSON bytes.',
      );
    }
    if (source['source_kind'] != 'review_only_unpublished' ||
        source['source_id'] is! String ||
        source['blocks'] is! List ||
        source['preparation'] is! Map ||
        source['cooldown'] is! Map) {
      throw const FormatException('Invalid session prescription source.');
    }
    final labels = <String>{};
    void scan(Object? value) {
      if (value is Map) {
        if (value['exercise'] is String) {
          labels.add(value['exercise'] as String);
        }
        for (final key in ['movements', 'dynamic_movements']) {
          if (value[key] is List) {
            for (final item in value[key] as List) {
              labels.add((item as List).first as String);
            }
          }
        }
        for (final child in value.values) {
          scan(child);
        }
      } else if (value is List) {
        for (final child in value) {
          scan(child);
        }
      }
    }

    scan(source);
    final pinned = Map<String, SessionExerciseVersionPin>.of(pins);
    final resolved = <String, String>{}, versions = <String, Object?>{};
    final unavailable = <String>[];
    for (final label in labels) {
      final pin = pinned[label];
      if (pin == null) {
        unavailable.add(label);
        continue;
      }
      final found = lookup.getDefinition(
        ExerciseId.parse(pin.id),
        visibility: ExerciseKnowledgeVisibility.operational,
      );
      final d = found.definition;
      if (!found.isOperational ||
          d == null ||
          d.version != pin.version ||
          d.owner != 'founder' ||
          d.publishedAt == null ||
          const ExerciseKnowledgeValidator().validateDefinition(d).isNotEmpty ||
          personalisationDigest(d.toJson()) != pin.digest) {
        unavailable.add(label);
        continue;
      }
      final provenance = await publicationAuthority.verifiedPublicationFor(d);
      if (provenance == null ||
          personalisationDigest(d.toJson()) != pin.digest) {
        unavailable.add(label);
        continue;
      }
      resolved[label] = d.id.value;
      versions[label] = {
        'definition': d.toJson(),
        'digest': pin.digest,
        'verified_publication': provenance,
      };
    }
    if (unavailable.isNotEmpty) {
      throw FormatException(
        'unresolved_authoritative_exercise_versions: ${unavailable.join(', ')}',
      );
    }
    final blocks = <SessionBlock>[];
    final id = source['source_id'] as String;
    // Preparation stays a complete instruction plus its authored circuit links.
    // Approved ramps stay separate from working sets; only the supplied dynamic budget is timed.
    final prep = Map<String, dynamic>.from(source['preparation'] as Map);
    final prepLinks = <SessionBlockExerciseLink>[];
    final movements = prep['movements'] ?? prep['dynamic_movements'];
    if (movements is List) {
      for (final raw in movements) {
        final m = raw as List;
        prepLinks.add(
          SessionBlockExerciseLink(
            localId: 'prep-${prepLinks.length}',
            exerciseId: resolved[m[0]]!,
            position: prepLinks.length + 1,
            displayLabelOverride: m[0] as String,
            prescription: StrengthExercisePrescription(
              sets: (prep['rounds'] as int?) ?? 1,
              reps: StrengthRepPrescription.exact(m[1] as int),
              perSide: m[2] as bool,
            ),
          ),
        );
      }
    }
    void add(
      SessionBlockType type,
      String title,
      Map<String, dynamic> original, {
      WorkoutFormat format = WorkoutFormat.none,
      TimerConfiguration? timer,
      List<SessionBlockExerciseLink> links = const [],
    }) {
      if (timer != null && timer.validateForFormat(format).isNotEmpty) {
        throw const FormatException('Invalid lowered timer.');
      }
      final n = blocks.length + 1;
      blocks.add(
        SessionBlock(
          localId: '$id-block-$n',
          persistedId: null,
          blockType: type,
          title: title,
          content:
              '${_sourceDescription(original)}${_variantDescription(original)}',
          workoutFormat: format,
          position: n,
          timerConfiguration: timer == null
              ? null
              : TimerConfiguration.fromJson(timer.toJson()),
          linkedExercises: List.unmodifiable(links),
          coachNotes: original['kind'] == 'superset'
              ? 'Complete the pair, then take the authored rest.'
              : null,
          performanceCaptureMode:
              type == SessionBlockType.warmUp ||
                  type == SessionBlockType.coolDown ||
                  format == WorkoutFormat.emom ||
                  original['kind'] == 'carry' ||
                  original['kind'] == 'hold' ||
                  original['exercise'] == 'pallof_press'
              ? BlockPerformanceCaptureMode.completion
              : BlockPerformanceCaptureMode.automatic,
        ),
      );
    }

    if (prep['easy'] is Map) {
      final easy = Map<String, dynamic>.from(prep['easy'] as Map);
      add(
        SessionBlockType.warmUp,
        'Easy preparation',
        easy,
        format: WorkoutFormat.steadyState,
        timer: TimerConfiguration(durationSeconds: easy['seconds'] as int),
        links: [
          SessionBlockExerciseLink(
            localId: '$id-preparation-easy',
            exerciseId: resolved[easy['exercise']]!,
            position: 1,
            displayLabelOverride: easy['exercise'] as String,
          ),
        ],
      );
      add(
        SessionBlockType.warmUp,
        'Preparation circuit and ramps',
        {...prep, 'movement_variants': source['exercise_variants']}
          ..remove('easy'),
        links: prepLinks,
      );
    } else if (prep['easy_run_seconds'] is int) {
      add(
        SessionBlockType.warmUp,
        'Easy running preparation',
        {'kind': 'easy_run_preparation', 'seconds': prep['easy_run_seconds']},
        format: WorkoutFormat.steadyState,
        timer: TimerConfiguration(
          durationSeconds: prep['easy_run_seconds'] as int,
        ),
      );
      add(
        SessionBlockType.warmUp,
        'Dynamic preparation',
        {
          'instruction': prep['dynamic_preparation'],
          'movement_variants': source['exercise_variants'],
        },
        format: prep['dynamic_seconds'] == null
            ? WorkoutFormat.none
            : WorkoutFormat.steadyState,
        timer: prep['dynamic_seconds'] == null
            ? null
            : TimerConfiguration(
                durationSeconds: prep['dynamic_seconds'] as int,
              ),
        links: prepLinks,
      );
      final accel = Map<String, dynamic>.from(prep['accelerations'] as Map);
      add(
        SessionBlockType.warmUp,
        'Relaxed accelerations',
        {'kind': 'preparation_accelerations', ...accel},
        format: WorkoutFormat.intervals,
        timer: TimerConfiguration(
          workSeconds: accel['work_seconds'] as int,
          restSeconds: accel['recovery_seconds'] as int,
          rounds: accel['repetitions'] as int,
          targetRounds: accel['repetitions'] as int,
          omitFinalRecovery: true,
        ),
      );
    } else {
      add(SessionBlockType.warmUp, 'Preparation', prep, links: prepLinks);
    }
    for (final raw in source['blocks'] as List) {
      final b = Map<String, dynamic>.from(raw as Map), kind = b['kind'];
      _validateSourceBlock(b);
      final links = <SessionBlockExerciseLink>[];
      SessionBlockExerciseLink link(
        Map<String, dynamic> p, {
        String? group,
        int? rounds,
        AuthoredIntRange? groupRest,
      }) {
        final label = p['exercise'] as String;
        StrengthRepPrescription reps;
        if (p['kind'] == 'carry') {
          reps = StrengthRepPrescription(
            type: StrengthRepType.distance,
            text: '${p['distance_metres']} m',
          );
        } else if (p['kind'] == 'hold') {
          reps = StrengthRepPrescription(
            type: StrengthRepType.duration,
            text: '${p['seconds']} s',
            durationSeconds: p['seconds'] as int,
          );
        } else {
          final values = (p['reps'] as List).cast<int>();
          reps = values[0] == values[1]
              ? StrengthRepPrescription.exact(values[0])
              : StrengthRepPrescription.range(min: values[0], max: values[1]);
        }
        AuthoredIntRange? rir;
        if (p['rir'] is String) {
          final values = (p['rir'] as String)
              .split('–')
              .map(int.parse)
              .toList();
          rir = AuthoredIntRange(values.first, values.last);
        }
        final prescription = StrengthExercisePrescription(
          sets: p['sets'] as int,
          reps: reps,
          rirRange: rir,
          restSecondsRange: p['rest_seconds'] == null
              ? null
              : AuthoredIntRange.fromJson(p['rest_seconds']),
          restAfterGroupSecondsRange: groupRest,
          perSide: p['per_side'] == true,
          groupId: group,
          prescribedDistanceMeters: p['distance_metres'] is num
              ? (p['distance_metres'] as num).toDouble()
              : null,
          holdSeconds: p['extended_hold_seconds'] as int?,
          authoredDetails: freezePrescriptionJson(p) as Map<String, dynamic>,
          coachCue: [
            for (final key in [
              'load_direction',
              'lever_direction',
              'resistance_direction',
            ])
              if (p[key] != null) p[key].toString(),
          ].join('; '),
        );
        if (prescription.validate(requireComplete: true).isNotEmpty) {
          throw const FormatException('Unsupported strength source.');
        }
        return SessionBlockExerciseLink(
          localId: '$id-link-${blocks.length}-${links.length}',
          exerciseId: resolved[label]!,
          position: links.length + 1,
          displayLabelOverride: label,
          prescription: prescription,
          executionGroupKey: group,
          executionGroupLabel: group == null ? null : 'Superset',
          executionGroupRounds: rounds,
        );
      }

      switch (kind) {
        case 'strength':
        case 'carry':
        case 'hold':
          links.add(link(b));
          add(
            SessionBlockType.strength,
            b['exercise'] as String,
            b,
            links: links,
          );
        case 'superset':
          final exercises = (b['exercises'] as List)
              .cast<Map<String, dynamic>>();
          for (final e in exercises) {
            links.add(
              link(
                e,
                group: '$id-pair-${blocks.length}',
                rounds: e['sets'] as int,
                groupRest: AuthoredIntRange.fromJson(
                  b['rest_after_pair_seconds'],
                ),
              ),
            );
          }
          add(SessionBlockType.strength, 'Upper-body pair', b, links: links);
        case 'alternating_emom':
        case 'three_minute_cycle':
          final stations = <TimerStationSpec>[];
          for (final rawStation in b['stations'] as List) {
            final station = Map<String, dynamic>.from(rawStation as Map),
                rest = station['kind'] == 'rest';
            stations.add(
              TimerStationSpec(
                exerciseId: rest ? '' : resolved[station['exercise']]!,
                position: stations.length + 1,
                minute: stations.length + 1,
                isRest: rest,
                workSeconds: station['work_seconds'] as int?,
                reps: station['reps'] as int?,
                authoredDetails:
                    freezePrescriptionJson(station) as Map<String, dynamic>,
              ),
            );
            if (!rest) {
              links.add(
                SessionBlockExerciseLink(
                  localId: '$id-station-${links.length}',
                  exerciseId: resolved[station['exercise']]!,
                  position: links.length + 1,
                  displayLabelOverride: station['exercise'] as String,
                ),
              );
            }
          }
          add(
            SessionBlockType.conditioning,
            'Gym finisher',
            b,
            format: WorkoutFormat.emom,
            timer: TimerConfiguration(
              totalDurationSeconds: (b['minutes'] as int) * 60,
              intervalSeconds: 60,
              stations: List.unmodifiable(stations),
            ),
            links: links,
          );
        case 'intervals':
          links.add(
            SessionBlockExerciseLink(
              localId: '$id-interval',
              exerciseId: resolved[b['exercise']]!,
              position: 1,
              displayLabelOverride: b['exercise'] as String,
            ),
          );
          add(
            SessionBlockType.conditioning,
            'Dedicated intervals',
            b,
            format: WorkoutFormat.intervals,
            timer: TimerConfiguration(
              omitFinalRecovery: true,
              workSeconds: b['work_seconds'] as int,
              restSeconds: b['recovery_seconds'] as int,
              targetRounds: b['repetitions'] as int,
              rounds: b['repetitions'] as int,
            ),
            links: links,
          );
        case 'continuous_duration_window':
          final minutes = (b['minutes'] as List).cast<int>();
          links.add(
            SessionBlockExerciseLink(
              localId: '$id-running',
              exerciseId: resolved[b['exercise']]!,
              position: 1,
              displayLabelOverride: b['exercise'] as String,
            ),
          );
          add(
            SessionBlockType.conditioning,
            'Choose main running duration',
            b,
            format: WorkoutFormat.steadyState,
            timer: TimerConfiguration(
              durationSecondsRange: AuthoredIntRange(
                minutes[0] * 60,
                minutes[1] * 60,
              ),
            ),
            links: links,
          );
        default:
          throw FormatException('Unsupported source construct: $kind');
      }
    }
    add(
      SessionBlockType.coolDown,
      'Cooldown',
      Map<String, dynamic>.from(source['cooldown'] as Map),
    );
    return CompiledCanonicalSessionSource._(
      text,
      List.unmodifiable(blocks),
      freezePrescriptionJson(versions) as Map<String, Object?>,
    );
  }
}

String personalisationTextDigest(String text) =>
    sha256.convert(utf8.encode(text)).toString();

String _sourceDescription(Map<String, dynamic> source) {
  String name(Object? value) => value.toString().replaceAll('_', ' ');
  final kind = source['kind'];
  if (source['instruction'] is String) return source['instruction'] as String;
  if (kind == 'easy_run_preparation') {
    return '${source['seconds']} s easy running';
  }
  if (kind == 'preparation_accelerations') {
    return '${source['repetitions']} × ${source['work_seconds']} s relaxed accelerations; ${source['recovery_seconds']} s easy between only';
  }
  if (source['budget_minutes'] is List) {
    final movements = (source['movements'] as List)
        .map((m) => '${m[1]} ${name(m[0])}${m[2] == true ? ' per side' : ''}')
        .join(', ');
    return '12–15 min total preparation, including the easy warm-up above; ${source['rounds']} rounds: $movements. ${source['ramp_up']}';
  }
  if (source['easy_run_seconds'] != null) {
    return '10 min easy running; dynamic preparation (details not authored); 3 × 20 s relaxed accelerations with 40 s easy between.';
  }
  if (kind == 'superset') {
    return 'Alternate the two prescribed exercises. Rest ${(source['rest_after_pair_seconds'] as List).join('–')} s after the pair.';
  }
  if (kind == 'alternating_emom' || kind == 'three_minute_cycle') {
    final stations = (source['stations'] as List)
        .map((raw) {
          final station = raw as Map;
          if (station['kind'] == 'rest') return '60 s full rest';
          final dose = station['work_seconds'] != null
              ? "${station['work_seconds']} s"
              : "${station['reps']} reps";
          final details = [
            if (station['guidance_semantics'] == 'advisory_only')
              'Guidance: ${station['guidance']}',
            for (final key in ['load_direction', 'load', 'height'])
              if (station[key] != null) station[key].toString(),
            if (station.containsKey('race_mapping') &&
                station['race_mapping'] == null)
              'race-division mapping unresolved',
          ];
          return '${name(station['exercise'])}: $dose${details.isEmpty ? '' : '; ${details.join('; ')}'}';
        })
        .join(' → ');
    final hasApprovedVariant = (source['stations'] as List).any(
      (st) =>
          st is Map &&
          (st['variant'] != null ||
              st['guidance_semantics'] == 'advisory_only'),
    );
    return '${source['minutes']} min, alternating minute stations: $stations. Recover within each work minute. ${kind == 'three_minute_cycle' ? 'Every third minute is a full rest, including the last round.' : ''} ${source['rpe_approximate'] == true ? 'About ' : ''}RPE ${(source['rpe'] as List).join('–')}. ${source['load'] ?? ''} ${hasApprovedVariant ? 'Optionally record actual load/scaling in existing supported logging or the block note.' : 'Record scaling in the existing block note.'}';
  }
  if (kind == 'intervals') {
    return '${source['repetitions']} × ${source['work_seconds']} s; ${source['recovery_seconds']} s ${source['recovery_effort']} between repetitions only.${source['effort'] == null ? '' : ' ${source['effort']}.'}';
  }
  if (kind == 'continuous_duration_window') {
    return '${(source['minutes'] as List).join('–')} min conversational running, RPE about 3–4. Choose by feel/recovery.';
  }
  if (source['exercise'] != null) {
    final percentage = source['five_rm_basis_points'];
    return '${name(source['exercise'])}${percentage == null ? '' : '; ${(percentage as num) / 100}% of authored 5RM, subject to the canonical target snapshot'}';
  }
  if (source['mode'] != null) {
    final m = source['minutes'];
    return '${m is List ? m.toSet().join('–') : m} min ${source['mode']}';
  }
  if (source['walking_minutes'] != null) {
    return source['easy_running_minutes'] == null
        ? '${source['walking_minutes']} min walking'
        : '${(source['easy_running_minutes'] as List).join('–')} min easy running, then ${source['walking_minutes']} min walking';
  }
  return 'About ${source['minutes']} min easy movement';
}

String _variantDescription(Map<String, dynamic> source) {
  String describe(Object? raw) {
    if (raw is! Map) return '';
    final equipment =
        (raw['equipment'] as List?)?.join(', ').replaceAll('_', ' ') ?? '';
    return '${raw['name']}: $equipment. ${raw['position']} ${raw['grip']} ${(raw['execution_sequence'] as List).join(' ')}';
  }

  final variants = <String>[];
  if (source['variant'] != null) variants.add(describe(source['variant']));
  if (source['exercises'] is List) {
    for (final e in source['exercises'] as List) {
      if (e['variant'] != null) variants.add(describe(e['variant']));
    }
  }
  if (source['movement_variants'] is Map) {
    final labels = source['movements'] is List
        ? (source['movements'] as List).map((m) => m[0]).toSet()
        : (source['movement_variants'] as Map).keys.toSet();
    for (final label in labels) {
      variants.add(describe(source['movement_variants'][label]));
    }
  }
  return variants.isEmpty ? '' : '\n${variants.join('\n')}';
}

void _validateSourceBlock(Map<String, dynamic> b) {
  const common = {'kind', 'provenance', 'variant'};
  final fields = switch (b['kind']) {
    'strength' => {
      'exercise',
      'sets',
      'reps',
      'rir',
      'per_side',
      'rest_seconds',
      'five_rm_basis_points',
      'extended_hold_seconds',
      'resistance_direction',
    },
    'carry' => {
      'exercise',
      'sets',
      'distance_metres',
      'per_side',
      'load_direction',
      'rest_seconds',
    },
    'hold' => {
      'exercise',
      'sets',
      'seconds',
      'lever_direction',
      'rest_seconds',
    },
    'superset' => {
      'exercises',
      'rest_after_pair_seconds',
      'transition_rest_seconds',
    },
    'intervals' => {
      'exercise',
      'repetitions',
      'work_seconds',
      'recovery_seconds',
      'recovery_placement',
      'recovery_effort',
      'effort',
      'steps',
    },
    'continuous_duration_window' => {
      'exercise',
      'minutes',
      'effort',
      'selection',
    },
    'alternating_emom' => {
      'minutes',
      'interval_seconds',
      'cycle_minutes',
      'cycles',
      'rpe',
      'rpe_approximate',
      'stations',
      'recovery',
      'load',
    },
    'three_minute_cycle' => {
      'rounds',
      'interval_seconds',
      'minutes',
      'rpe',
      'rpe_approximate',
      'stations',
      'recovery',
      'race_requirement_provenance',
    },
    _ => throw const FormatException('Unsupported source construct.'),
  };
  if (b.keys.any((k) => !common.contains(k) && !fields.contains(k))) {
    throw const FormatException('Unsupported authored source field.');
  }
  if (b['kind'] == 'superset') {
    final exercises = b['exercises'] as List;
    if (exercises.length != 2 || b['transition_rest_seconds'] != null) {
      throw const FormatException('Unsupported pair structure.');
    }
    for (final e in exercises) {
      _validateSourceBlock(Map<String, dynamic>.from(e as Map));
    }
    if (exercises[0]['sets'] != exercises[1]['sets']) {
      throw const FormatException('Pair set counts disagree.');
    }
  }
  if (b['kind'] == 'intervals') {
    final reps = b['repetitions'] as int,
        work = b['work_seconds'] as int,
        rest = b['recovery_seconds'] as int;
    if (reps <= 0 ||
        work <= 0 ||
        rest < 0 ||
        b['recovery_placement'] != 'between_only') {
      throw const FormatException('Invalid interval dose.');
    }
    final expected = [
      for (var i = 1; i <= reps; i++) ...[
        {'id': 'work-$i', 'phase': 'work', 'seconds': work},
        if (i < reps)
          {'id': 'recovery-$i', 'phase': 'recovery', 'seconds': rest},
      ],
    ];
    if (personalisationCanonicalJson(expected) !=
        personalisationCanonicalJson(b['steps'])) {
      throw const FormatException('Contradictory work/recovery steps.');
    }
  }
  if (b['stations'] is List) {
    final stations = b['stations'] as List, minutes = b['minutes'] as int;
    if (stations.isEmpty ||
        b['interval_seconds'] != 60 ||
        minutes <= 0 ||
        minutes % stations.length != 0) {
      throw const FormatException('Invalid minute cycle.');
    }
    for (final raw in stations) {
      final st = raw as Map;
      if (st['kind'] == 'rest') {
        if (st.length != 2 || st['seconds'] != 60) {
          throw const FormatException('Invalid full rest station.');
        }
      } else {
        const allowed = {
          'exercise',
          'work_seconds',
          'reps',
          'load_direction',
          'load',
          'height',
          'race_mapping',
          'variant',
          'guidance',
          'guidance_semantics',
        };
        if (st.keys.any((k) => !allowed.contains(k)) ||
            st['exercise'] is! String ||
            ((st['work_seconds'] != null) == (st['reps'] != null))) {
          throw const FormatException('Unsupported work station.');
        }
        if (st.containsKey('guidance') ||
            st.containsKey('guidance_semantics')) {
          if (st['guidance'] is! String ||
              (st['guidance'] as String).trim().isEmpty ||
              st['guidance_semantics'] != 'advisory_only' ||
              ['load', 'height', 'race_mapping'].any(st.containsKey)) {
            throw const FormatException(
              'Advisory guidance cannot replace or claim an explicit load/standard.',
            );
          }
        }
        if (st['work_seconds'] != null &&
            (st['work_seconds'] is! int ||
                st['work_seconds'] <= 0 ||
                st['work_seconds'] >= 60)) {
          throw const FormatException('Invalid timed station.');
        }
        if (st['reps'] != null && (st['reps'] is! int || st['reps'] <= 0)) {
          throw const FormatException('Invalid rep station.');
        }
      }
    }
  }
}
