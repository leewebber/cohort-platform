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
import 'package:founder_importer/features/founder_programme_import/founder_programme_prescription_mapper.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_yaml_parser.dart';
import 'package:founder_importer/models/exercise.dart' as intake;

import 'admission_probe_test.dart' as retained;

const source = 'docs/programmes/hybrid_10k/founder_selected_2026_10_30';
const review = 'docs/programmes/hybrid_10k/founder_selected_2026_10_30';
dynamic read(String file) => jsonDecode(File(file).readAsStringSync());

void main() {
  final report = <String, dynamic>{
    'classification': 'GENUINE_DRAFT_LOCAL_CONTRACT_PROBE_NOT_PUBLICATION',
    'base': '15627ecd7c41ab0f5f593ba6a08075374f7316fe',
    'content_approval': 'D1_D7_AND_WEEK_DOSES_SELECTED_D8_PENDING',
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
      'docs/checkpoints/m11_hybrid10k_dose_reconciliation/ADMISSION.json',
    );
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(report)}\n',
    );
  });

  test(
    'trusted exact-row catalogue intake resolves 47 references and holds all missing exact records without name substitution',
    () {
      final evidence = read('$source/IDENTITY_INTAKE.json') as Map;
      final rows = evidence['repository_rows'] as Map;
      final selectedIds = (evidence['verified_bindings'] as Map).values.toSet();
      final catalogue = [
        for (final id in selectedIds)
          intake.Exercise.fromMap(
            Map<String, dynamic>.from(rows[id]['catalogue_row'] as Map),
          ),
      ];
      final sourceData = read('$source/SOURCE.json') as Map;
      final bindings = evidence['occurrences'] as List;
      final document = const FounderProgrammeYamlParser().parse(
        jsonEncode({
          'schema_version': 1,
          'programme': {
            'import_key': 'hybrid10k-selected-local-intake',
            'title': sourceData['title'],
            'code': sourceData['programme_id'],
            'duration_weeks': 10,
          },
          'weeks': [
            for (var week = 1; week <= 10; week++)
              {
                'week_number': week,
                'days': [
                  for (final s in (sourceData['sessions'] as List).where(
                    (s) => s['week'] == week && s['type'] == 'strength',
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
                                  (() {
                                    final e = s['exercises'][i];
                                    final binding = bindings.singleWhere(
                                      (b) =>
                                          b['source_occurrence_id'] ==
                                          e['exercise_occurrence_id'],
                                    );
                                    return {
                                      'order': i + 1,
                                      // Unresolved references deliberately have no admissible alias.
                                      'exercise_name':
                                          binding['exercise_id'] == null
                                          ? 'UNRESOLVED:${e['variant_key']}'
                                          : e['exercise'],
                                      if (binding['exercise_id'] != null)
                                        'exercise_slug':
                                            rows[binding['exercise_id']]['catalogue_row']['slug'],
                                    };
                                  })(),
                              ],
                            },
                          ],
                        },
                      ],
                    },
                ],
              },
          ],
        }),
      );
      final resolved = FounderProgrammeExerciseResolver.fromCatalogue(
        catalogue,
      ).resolveDocument(document);
      expect(resolved.canonicalIds, hasLength(47));
      expect(resolved.issues, hasLength(58));
      expect(resolved.canonicalIds.values.toSet(), {
        'EX-078',
        'EX-084',
        'EX-114',
        'EX-116',
        'EX-125',
      });
      expect(
        resolved.issues.map((i) => i.code),
        everyElement('legacy_exercise_reference_unresolved'),
      );
      report['trusted_identity_intake'] = {
        'verified_legacy_row_occurrences': 47,
        'selected_template_occurrences_bound': 47,
        'unresolved_identity_occurrences': 58,
        'full_published_row_or_version_event_created': false,
        'current_hosted_catalogue_state': 'NOT_VERIFIED',
      };
    },
  );

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
            'import apply_strength_selections as r; import json; '
            'print(json.dumps(r.admission_preflight(r.build()["STRENGTH_REVIEW_GRAPHS.json"])))',
      ]);
      expect(preflight.exitCode, 0, reason: preflight.stderr.toString());
      final held = jsonDecode(preflight.stdout.toString()) as Map;
      expect(held['admitted'], isFalse);
      expect(held['unresolved_identity_occurrences'], 58);
      expect(held['unique_content_holds'], isEmpty);
      report['source_guard'] = held;
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
          'full_admission': 'exact_identity_records_required',
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
                      'content_holds': e['content_holds'],
                    },
            ],
          },
      ];
    },
  );

  test(
    '47 exact-bound genuine reference prescriptions pass extracted private v1/v2 graph and native plan restore contracts',
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
      expect(acceptedLinks, 47);
      expect(partialGraphs, 19);
      report['extracted_known_link_probes'] = {
        'links': acceptedLinks,
        'partial_graphs': partialGraphs,
        'private_v1_v2_graph_check': 'PASS',
        'native_plan_serialization_restore': 'PASS',
        'complete_sessions_or_canonical_started_state': false,
        'prescription_scope': 'EXACT_SELECTED_DOSES_FULL_PROGRAMME_D8_PENDING',
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
          final native = StrengthExercisePrescription.fromJson(
            Map<String, dynamic>.from(e['prescription'] as Map),
          );
          expect(native.validate(requireComplete: true), isEmpty);
          final restored = StrengthExercisePrescription.fromJson(
            Map<String, dynamic>.from(
              jsonDecode(jsonEncode(native.toJson())) as Map,
            ),
          );
          expect(restored.toJson(), native.toJson());
          if ((e['content_holds'] as List).isNotEmpty) {
            expect(expected['effective_prescription'], isNull);
          }
          expect(e['exercise_id'], expected['exercise_id']);
        }
      }
      expect(total, 105);
      final taper = graphs.singleWhere(
        (g) => g['source_session_id'] == 'LW10K-W10-D04',
      );
      expect(
        (taper['blocks'][0]['content'] as String).toLowerCase(),
        contains('no lower-body lifting'),
      );
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
        'selected_work_set_prescriptions': 238,
        'whole_sessions_withheld': 20,
      };
    },
  );
}
