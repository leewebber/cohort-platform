// Genuine source review only: no SQL, accounts, publication or athlete ports.
import 'dart:convert';
import 'dart:io';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:cohort_platform/core/persistence/session_execution_plan_codec.dart';
import 'package:cohort_platform/features/private_programme/reviewed_protocol_graph_artifact.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/strength_exercise_prescription.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admission_probe_test.dart' as retained;

const source = 'docs/programmes/hybrid_10k/general_draft_2026_10_30';
const review = 'docs/programmes/hybrid_10k/movement_review_2026_10_30';
dynamic read(String file) => jsonDecode(File(file).readAsStringSync());

void main() {
  final report = <String, dynamic>{
    'classification': 'GENUINE_DRAFT_LOCAL_CONTRACT_PROBE_NOT_PUBLICATION',
    'base': 'a22249e23a385ebb6064b8f05e3d2fb17af3914e',
    'content_approval': 'NOT_GRANTED_BY_THIS_TASK',
    'canonical_acquisition_start_logging_completion_restore': 'NOT_ATTEMPTED',
    'running_evidence': {
      'reused_immutable_checkpoint':
          'a22249e:docs/checkpoints/m11_hybrid10k_reconciliation/ADMISSION.json',
      'timed_graphs': 39,
      'distance_10000m': 'unsupported_timed_running_body',
      'rerun': false,
    },
  };
  tearDownAll(() {
    final file = File(
      'docs/checkpoints/m11_hybrid10k_movement_review/ADMISSION.json',
    );
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(report)}\n',
    );
  });

  test(
    'complete genuine v1/v2 package refuses before unresolved identities enter the private decoder',
    () {
      final package = read('$source/SCHEDULE_CANDIDATE.json') as Map;
      final strengthReview =
          read('$review/STRENGTH_REVIEW_GRAPHS.json') as List;
      final completeReview = [
        for (final row in read('$source/RUNNING_BODIES.json') as List)
          retained.graph(row as Map),
        ...strengthReview,
      ];
      expect(completeReview, hasLength(60));
      expect(
        completeReview.map((g) => g['protocol_id']).toSet(),
        (package['sessions'] as List).map((s) => s['protocol_id']).toSet(),
      );
      final preflight = Process.runSync('python3', [
        '-c',
        'import sys; sys.path.insert(0,"tool/programmes/hybrid_10k"); '
            'import build_movement_review as r; '
            'r.admissible_strength_graphs(r.build()["STRENGTH_REVIEW_GRAPHS.json"])',
      ]);
      expect(preflight.exitCode, isNot(0));
      expect(
        preflight.stderr.toString(),
        contains('movement_identity_or_selection_required:87'),
      );
      final results = <Map>[];
      for (final version in [1, 2]) {
        final compiled = const PlanPackageCompiler().compile(
          jsonEncode({...package, 'package_schema_version': version}),
        );
        expect(compiled.isValid, isTrue, reason: compiled.issues.toString());
        expect(compiled.manifest!.sessions, hasLength(60));
        expect(
          const PlanPackageCompiler()
              .verifyCanonicalArtifact(compiled.canonicalJson!)
              .isValid,
          isTrue,
        );
        // Never submit the review null-ID bodies or partial strength bodies as a
        // complete session. Stock graph validation does not prove catalogue IDs.
        results.add({
          'schema': version,
          'schedule_sessions': 60,
          'complete_review_graph_scope': 60,
          'schedule_compile': 'PASS',
          'schedule_sha256': compiled.contentHashSha256,
          'full_admission': 'movement_identity_or_selection_required:87',
          'complete_strength_graphs_admitted': 0,
          'private_decoder_called_for_incomplete_graphs': false,
        });
      }
      final graphs = read('$review/STRENGTH_REVIEW_GRAPHS.json') as List;
      report['full_programme'] = results;
      report['strength_holds'] = [
        for (final g in graphs)
          {
            'session_id': g['source_session_id'],
            'unresolved': [
              for (final b in g['blocks'])
                for (final e in b['exercises'])
                  if (e['exercise_id'] == null)
                    {
                      'occurrence': e['source_occurrence_id'],
                      'variant': e['variant_key'],
                      'reference': e['hold_reference'],
                    },
            ],
          },
      ];
    },
  );

  test(
    '37 exact-bound genuine prescriptions pass extracted private v1/v2 graph and native plan restore contracts',
    () {
      final package = read('$source/SCHEDULE_CANDIDATE.json') as Map;
      final graphs = read('$review/STRENGTH_REVIEW_GRAPHS.json') as List;
      var acceptedLinks = 0;
      var partialGraphs = 0;
      for (final raw in graphs) {
        final g = raw as Map;
        final links = [
          for (final b in g['blocks'])
            for (final e in b['exercises'])
              if (e['exercise_id'] != null) Map<String, dynamic>.from(e as Map),
        ];
        if (links.isEmpty) continue;
        partialGraphs++;
        acceptedLinks += links.length;
        // Explicitly extracted partial contract probes, never complete sessions.
        final extracted = {
          'protocol_id': g['protocol_id'],
          'revision_number': g['revision_number'],
          'blocks': [
            {
              'position': 1,
              'block_type': 'strength',
              'title': 'EXTRACTED KNOWN LINKS ONLY — INCOMPLETE SESSION',
              'workout_format': 'none',
              'performance_capture_mode': 'auto',
              'exercises': [
                for (var i = 0; i < links.length; i++)
                  {...links[i], 'position': i + 1},
              ],
            },
          ],
        };
        final encodedGraph = jsonEncode([extracted]);
        for (final version in [1, 2]) {
          final compiled = const PlanPackageCompiler().compile(
            jsonEncode(
              retained.extractedPackage(
                package,
                g['source_session_id'] as String,
                version,
              ),
            ),
          );
          final accepted = const ReviewedProtocolGraphArtifact().decode(
            compileResult: compiled,
            source: encodedGraph,
            expectedSha256: sha256
                .convert(utf8.encode(encodedGraph))
                .toString(),
          );
          expect(accepted, hasLength(1));
        }
        final plan = SessionExecutionPlan(
          sessionId: g['source_session_id'] as String,
          sessionTitle: 'EXTRACTED PARTIAL SOURCE — NOT CANONICAL START',
          blocks: [
            SessionExecutionBlock(
              blockId: '${g['protocol_id']}-partial',
              title: 'Known links only',
              blockType: SessionBlockType.strength,
              content: 'Partial local contract proof',
              workoutFormat: WorkoutFormat.none,
              position: 1,
              linkedExercises: [
                for (final e in links)
                  SessionExecutionExerciseSummary(
                    exerciseId: e['exercise_id'] as String,
                    displayName: e['display_label_override'] as String,
                    position: e['position'] as int,
                    prescription: StrengthExercisePrescription.fromJson(
                      Map<String, dynamic>.from(e['prescription'] as Map),
                    ),
                  ),
              ],
            ),
          ],
        );
        const codec = SessionExecutionPlanCodec();
        final encoded = codec.encodePlan(plan);
        final restored = codec.decodePlan(
          Map<String, dynamic>.from(jsonDecode(jsonEncode(encoded)) as Map),
        );
        expect(codec.encodePlan(restored), encoded);
        for (final e in restored.blocks.single.linkedExercises) {
          expect(e.prescription!.validate(requireComplete: true), isEmpty);
        }
      }
      expect(acceptedLinks, 37);
      expect(partialGraphs, 19);
      report['extracted_known_link_probes'] = {
        'links': acceptedLinks,
        'partial_graphs': partialGraphs,
        'private_v1_v2_graph_check': 'PASS',
        'native_plan_serialization_restore': 'PASS',
        'complete_sessions_or_canonical_started_state': false,
      };
    },
  );

  test(
    'rebuilt review graphs retain source order, preparation, exact minimum-RIR taper and unchanged distance test',
    () {
      final graphs = read('$review/STRENGTH_REVIEW_GRAPHS.json') as List;
      final intake =
          read('$source/IDENTITY_INTAKE.json')['occurrences'] as List;
      expect(graphs, hasLength(20));
      var total = 0;
      for (final g in graphs) {
        expect((g['blocks'] as List).map((b) => b['position']), [1, 2, 3]);
        final links = g['blocks'][1]['exercises'] as List;
        expect(links, isNotEmpty);
        for (final e in links) {
          total++;
          final expected = intake.singleWhere(
            (r) => r['source_occurrence_id'] == e['source_occurrence_id'],
          );
          expect(e['prescription'], expected['prescription']);
          expect(e['exercise_id'], expected['exercise_id']);
        }
      }
      expect(total, 124);
      final taper = graphs.singleWhere(
        (g) => g['source_session_id'] == 'LW10K-W10-D04',
      );
      expect(taper['blocks'][0]['content'], contains('no lower-body lifting'));
      expect(taper['blocks'][1]['exercises'], hasLength(2));
      for (final e in taper['blocks'][1]['exercises']) {
        expect(e['prescription']['sets'], 2);
        expect(e['prescription']['rir_range'], isNull);
        expect(e['prescription']['coach_cue'], contains('At least 3 RIR'));
      }
      final runs = read('$source/RUNNING_BODIES.json') as List;
      final finalTest = runs.singleWhere(
        (r) => r['source_session_id'] == 'LW10K-W10-D07',
      );
      expect(finalTest['distance_metres'], 10000);
      report['review_graphs'] = {
        'sessions': 20,
        'occurrences': total,
        'work_sets': 263,
        'whole_sessions_withheld': 20,
      };
    },
  );
}
