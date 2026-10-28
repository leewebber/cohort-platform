// Read-only local contract probe of genuine draft source. No DB/network/athlete port.
// Run: flutter test tool/programmes/hybrid_10k/admission_probe_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:cohort_platform/core/persistence/session_execution_plan_codec.dart';
import 'package:cohort_platform/domain/exercise_knowledge/exercise_knowledge_domain.dart';
import 'package:cohort_platform/features/private_programme/reviewed_protocol_graph_artifact.dart';
import 'package:cohort_platform/features/session/models/authored_timed_running_execution.dart';
import 'package:cohort_platform/features/session/models/running_target_admission.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/models/structured_running_execution.dart';
import 'package:cohort_platform/features/session/services/structured_running_controller.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/timer_configuration.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_prescription_mapper.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_yaml_parser.dart';

import '../../founder_programme_import/repository_transitional_identity_adapter.dart';

const sourceDir = 'docs/programmes/hybrid_10k/lee_draft_2026_10_28';
const output = 'docs/checkpoints/m11_hybrid10k_consolidation/ADMISSION.json';

dynamic read(String name) =>
    jsonDecode(File('$sourceDir/$name').readAsStringSync());

Map<String, dynamic> graph(Map row) => {
  'protocol_id': '${row['source_session_id']}-DRAFT-R1',
  'revision_number': 1,
  'blocks': [
    {
      'position': 1,
      'block_type': 'conditioning',
      'title': row['workout']['title'],
      'content':
          'GENUINE DRAFT / LOCAL CONTRACT PROBE. Not approved or published.',
      'coach_notes': row['workout']['notes'],
      'workout_format': 'steady_state',
      'performance_capture_mode': 'endurance',
      'timer_config': {
        // For distance sources this is only the known timed subtotal. Validation
        // must refuse; it is never a duration substitute for distance work.
        'durationSeconds': row['fixed_seconds'],
        'running_workout': row['workout'],
      },
      'exercises': <Object>[],
    },
  ],
};

Map<String, dynamic> extractedPackage(Map original, String id, int version) => {
  ...original,
  'package_schema_version': version,
  'programme': {
    ...original['programme'],
    'name': 'Extracted genuine draft contract probe: $id',
    'duration_weeks': 1,
    'sessions_per_week': 1,
  },
  'sessions': [
    (original['sessions'] as List).singleWhere((s) => s['session_key'] == id),
  ],
  // In-memory one-session probe only. Original source calendar is untouched.
  'weeks': [
    {
      'week_number': 1,
      'days': [
        {
          'day_key': 'day_1',
          'day_order': 1,
          'day_type': 'training',
          'slots': [
            {
              'slot_key': id,
              'session_order': 1,
              'session_key': id,
              'progression': {
                'prescription_summary': 'Extracted source contract probe only',
              },
            },
          ],
        },
      ],
    },
  ],
};

SessionExecutionBlock blockFor(Map row) => SessionExecutionBlock(
  blockId: '${row['source_session_id']}-local-probe-block',
  title: row['workout']['title'] as String,
  blockType: SessionBlockType.conditioning,
  content: 'Local genuine draft representation; not canonical started state.',
  workoutFormat: WorkoutFormat.steadyState,
  position: 1,
  timerConfiguration: TimerConfiguration.fromJson({
    'durationSeconds': row['fixed_seconds'],
    'running_workout': row['workout'],
  }),
);

void main() {
  final evidence = <String, dynamic>{
    'classification': 'PURE_LOCAL_SOURCE_CONTRACT_PROBE_NOT_SERVER_ADMISSION',
    'base': 'd88acd96b2647e94e70a8ee96d0f5bb18f078a7c',
    'source_sha256': read('AUDIT.json')['source_sha256'],
    'publication': 'NOT_ATTEMPTED_NOT_AUTHORISED',
    'canonical_acquisition_start_completion':
        'NOT_ATTEMPTED_NO_PUBLISHED_GENUINE_VERSION',
    'target_rules': [
      'alpha_5k_8w_riegel_1_06_v1',
      'alpha_manual_threshold_pm2_v1',
      'authored_rpe_v1',
    ],
  };
  tearDownAll(() {
    File(output).writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(evidence)}\n',
    );
  });

  test('genuine full schedule compiles v1/v2; incomplete graphs refuse', () {
    final original = read('SCHEDULE_CANDIDATE.json') as Map;
    final rows = read('RUNNING_BODIES.json') as List;
    final results = <Map<String, dynamic>>[];
    for (final version in [1, 2]) {
      final compiled = const PlanPackageCompiler().compile(
        jsonEncode({...original, 'package_schema_version': version}),
      );
      expect(compiled.isValid, isTrue, reason: compiled.issues.toString());
      expect(compiled.manifest!.sessions, hasLength(59));
      final canonical = compiled.canonicalJson!;
      expect(
        const PlanPackageCompiler().verifyCanonicalArtifact(canonical).isValid,
        isTrue,
      );
      final graphs = jsonEncode(rows.map((r) => graph(r as Map)).toList());
      String? refusal;
      try {
        const ReviewedProtocolGraphArtifact().decode(
          compileResult: compiled,
          source: graphs,
          expectedSha256: sha256.convert(utf8.encode(graphs)).toString(),
        );
      } on ReviewedProtocolGraphArtifactException catch (error) {
        refusal = error.code;
      }
      expect(refusal, 'protocol_graph_scope_mismatch');
      results.add({
        'schema': version,
        'schedule_valid': compiled.isValid,
        'schedule_sha256': compiled.contentHashSha256,
        'scheduled_sessions': compiled.manifest!.sessions.length,
        'full_graph_admission': refusal,
        'reason':
            'Only 40 running bodies exist; 19 strength graphs withheld for unresolved identities.',
      });
    }
    evidence['full_schedule'] = results;
  });

  test(
    'each exact running body exercises real private graph and paused restore contracts',
    () {
      final original = read('SCHEDULE_CANDIDATE.json') as Map;
      final results = <Map<String, dynamic>>[];
      for (final row in read('RUNNING_BODIES.json') as List) {
        final id = row['source_session_id'] as String;
        final codes = <String>[];
        for (final version in [1, 2]) {
          final compiled = const PlanPackageCompiler().compile(
            jsonEncode(extractedPackage(original, id, version)),
          );
          expect(compiled.isValid, isTrue, reason: compiled.issues.toString());
          final raw = jsonEncode([graph(row as Map)]);
          try {
            const ReviewedProtocolGraphArtifact().decode(
              compileResult: compiled,
              source: raw,
              expectedSha256: sha256.convert(utf8.encode(raw)).toString(),
            );
            codes.add('accepted_local_graph');
          } on ReviewedProtocolGraphArtifactException catch (error) {
            codes.add(error.code);
          }
        }
        final distance = row['distance_metres'] as int;
        if (distance > 0) {
          expect(codes, everyElement('unsupported_timed_running_body'));
          results.add({
            'source_session_id': id,
            'v1_v2': codes,
            'distance_metres': distance,
            'restore': 'not_executable_distance_ending_preserved',
          });
          continue;
        }
        expect(codes, everyElement('accepted_local_graph'));
        final plan = SessionExecutionPlan(
          sessionId: id,
          sessionTitle: id,
          blocks: [blockFor(row as Map)],
        );
        const planCodec = SessionExecutionPlanCodec();
        final restoredPlan = planCodec.decodePlan(
          jsonDecode(jsonEncode(planCodec.encodePlan(plan))),
        );
        final execution = AuthoredTimedRunningExecution.fromBlock(
          restoredPlan.blocks.single,
        );
        final controller = StructuredRunningController.fresh(
          execution: execution,
        );
        expect(controller.cursor.isPaused, isTrue);
        controller.start();
        controller.elapse(const Duration(seconds: 11));
        final cursor = StructuredRunningCursor.fromJson(
          jsonDecode(jsonEncode(controller.cursor.toJson())),
        );
        controller.dispose();
        final restored = StructuredRunningController.restore(
          execution: execution,
          cursor: cursor,
        );
        expect(restored.cursor.isPaused, isTrue);
        expect(
          restored.cursor.remainingMilliseconds,
          cursor.remainingMilliseconds,
        );
        expect(restored.cursor.authoredStepId, cursor.authoredStepId);
        restored.start();
        restored.elapse(Duration(seconds: row['fixed_seconds'] as int));
        expect(restored.cursor.isFinished, isTrue);
        restored.dispose();
        results.add({
          'source_session_id': id,
          'v1_v2': codes,
          'running_seconds': row['fixed_seconds'],
          'restore': 'serialized_plan_and_cursor_restore_paused',
          'clock_finished': true,
          'canonical_completion': 'not_attempted',
        });
      }
      expect(results.where((r) => r['clock_finished'] == true), hasLength(35));
      expect(results.where((r) => r['distance_metres'] != null), hasLength(5));
      evidence['running_bodies'] = results;
    },
  );

  test(
    'existing personalised markers refuse unresolved genuine input; no RPE range collapsed',
    () {
      final rows = read('RUNNING_BODIES.json') as List;
      final results = <Map<String, dynamic>>[];
      for (final entry in [
        ('LW10K-W01-D02', 'zone2'),
        ('LW10K-W03-D02', 'quality'),
      ]) {
        final row =
            jsonDecode(
                  jsonEncode(
                    rows.singleWhere((r) => r['source_session_id'] == entry.$1),
                  ),
                )
                as Map;
        for (final step in row['workout']['steps'] as List) {
          if (entry.$2 == 'zone2') {
            step['target'] = {
              'kind': 'heart_rate_zone_ref',
              'zone_ref': confirmedZone2Reference,
            };
          } else if ((step['notes'] as String).startsWith(
            'Source effort: THRESHOLD;',
          )) {
            // Proposed mapping only. Range 7..8 is never changed to a scalar fallback.
            step['target'] = {
              'kind': 'alpha_quality_pace_v1',
              'category': 'threshold',
            };
          }
        }
        final block = blockFor(row);
        expect(
          block.timerConfiguration!.validateForFormat(
            WorkoutFormat.steadyState,
          ),
          isEmpty,
        );
        final plan = SessionExecutionPlan(
          sessionId: entry.$1,
          sessionTitle: entry.$1,
          blocks: [block],
        );
        expect(
          entry.$2 == 'zone2'
              ? requiresZone2Admission(plan)
              : requiresQualityAdmission(plan),
          isTrue,
        );
        expect(
          () => AuthoredTimedRunningExecution.fromBlock(block),
          throwsFormatException,
        );
        results.add({
          'source_session_id': entry.$1,
          'proposed_binding': entry.$2,
          'status': 'marker_valid_missing_frozen_acceptance_refused',
          'coaching_binding':
              'PENDING_SOURCE_RECONCILIATION_NOT_ADDED_TO_SOURCE',
          'authored_scalar_fallback': null,
        });
      }
      evidence['personalised_capability_reuse'] = results;
    },
  );

  test(
    'trusted importer cannot invent source identity or a published catalogue',
    () {
      final source = read('CALENDAR.json') as Map;
      final weeks = [
        for (final week in source['weeks'] as List)
          {
            'week_number': week['week'],
            'days': [
              for (final s in (source['sessions'] as List).where(
                (s) => s['week'] == week['week'] && s['type'] == 'strength',
              ))
                {
                  'day_number': s['day'],
                  'sessions': [
                    {
                      'title': s['title'],
                      'session_type': 'strength',
                      'blocks': [
                        {
                          'order': 1,
                          'block_type': 'strength',
                          'title': s['title'],
                          'exercises': [
                            for (
                              var i = 0;
                              i < (s['exercises'] as List).length;
                              i++
                            )
                              {
                                'order': i + 1,
                                'exercise_name': s['exercises'][i]['exercise'],
                              },
                          ],
                        },
                      ],
                    },
                  ],
                },
            ],
          },
      ];
      final document = const FounderProgrammeYamlParser().parse(
        jsonEncode({
          'schema_version': 1,
          'programme': {
            'import_key': 'lee-10k-draft-identity-probe',
            'title': source['title'],
            'code': source['programme_id'],
            'duration_weeks': 10,
          },
          'weeks': weeks,
        }),
      );
      final resolver = FounderProgrammeExerciseResolver.fromCatalogue(
        const [], // No retained published runtime catalogue supplied; never fill from fixtures.
        transitionalIdentityResolver: RepositoryTransitionalIdentityAdapter(
          InMemoryTransitionalExerciseIdBridge(
            initial: FounderApprovedIdentityMappingsPhase31F.allMappings,
          ),
        ),
      );
      final resolved = resolver.resolveDocument(document);
      expect(resolved.canonicalIds, isEmpty);
      expect(resolved.issues, hasLength(122));
      expect(
        resolved.issues.map((e) => e.code),
        everyElement('legacy_exercise_reference_unresolved'),
      );
      evidence['exercise_identity'] = {
        'catalogue': 'NO_RETAINED_PUBLISHED_RUNTIME_CATALOGUE_SUPPLIED',
        'source_identity':
            'DISPLAY_NAMES_ONLY_NO_EXPLICIT_TRANSITIONAL_OR_VERSION_REFS',
        'resolved_occurrences': 0,
        'unresolved_occurrences': resolved.issues.length,
        'distinct_authored_names':
            (resolved.issues.map((e) => e.rawReference).toSet().toList()
              ..sort()),
        'issues': resolved.issues.map((e) => e.toJson()).toList(),
      };
    },
  );
}
