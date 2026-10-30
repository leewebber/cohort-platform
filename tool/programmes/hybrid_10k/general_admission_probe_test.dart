// Genuine reconciled source, pure local contracts. No accounts/DB/publication.
import 'dart:convert';
import 'dart:io';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:cohort_platform/core/persistence/session_execution_plan_codec.dart';
import 'package:cohort_platform/domain/exercise_knowledge/exercise_knowledge_domain.dart';
import 'package:cohort_platform/features/private_programme/reviewed_protocol_graph_artifact.dart';
import 'package:cohort_platform/features/session/models/authored_timed_running_execution.dart';
import 'package:cohort_platform/features/session/models/running_target_admission.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/models/strength_exercise_prescription.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_prescription_mapper.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_yaml_parser.dart';
import 'package:founder_importer/models/exercise.dart' as intake;

import '../../founder_programme_import/repository_transitional_identity_adapter.dart';
import 'admission_probe_test.dart' as retained;

const currentSource = 'docs/programmes/hybrid_10k/general_draft_2026_10_30';
dynamic read(String name) =>
    jsonDecode(File('$currentSource/$name').readAsStringSync());

void main() {
  final report = <String, dynamic>{
    'date': '2026-10-30',
    'base': '0f0c40dae54c87e7b3f739b205c0fe6b8edf847a',
    'classification': 'GENUINE_DRAFT_LOCAL_CONTRACT_PROBES_NOT_PUBLICATION',
    'content_authority':
        'Four replacement runs founder-selected; other detailed content not blanket approved',
    'canonical_acquisition_start_completion': 'NOT_ATTEMPTED_NO_AUTHORISATION',
  };
  tearDownAll(() {
    File(
      'docs/checkpoints/m11_hybrid10k_reconciliation/ADMISSION.json',
    ).writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(report)}\n',
    );
  });

  test(
    'corrected full schedule compiles v1/v2; missing complete strength graphs refuse',
    () {
      final source = read('SCHEDULE_CANDIDATE.json') as Map;
      final runs = read('RUNNING_BODIES.json') as List;
      final results = <Map>[];
      for (final version in [1, 2]) {
        final compiled = const PlanPackageCompiler().compile(
          jsonEncode({...source, 'package_schema_version': version}),
        );
        expect(compiled.isValid, isTrue, reason: compiled.issues.toString());
        expect(compiled.manifest!.sessions, hasLength(60));
        expect(
          const PlanPackageCompiler()
              .verifyCanonicalArtifact(compiled.canonicalJson!)
              .isValid,
          isTrue,
        );
        final raw = jsonEncode(
          runs.map((row) => retained.graph(row as Map)).toList(),
        );
        String? code;
        try {
          const ReviewedProtocolGraphArtifact().decode(
            compileResult: compiled,
            source: raw,
            expectedSha256: sha256.convert(utf8.encode(raw)).toString(),
          );
        } on ReviewedProtocolGraphArtifactException catch (error) {
          code = error.code;
        }
        expect(code, 'protocol_graph_scope_mismatch');
        results.add({
          'schema': version,
          'scheduled_sessions': 60,
          'compile': 'PASS',
          'schedule_sha256': compiled.contentHashSha256,
          'complete_graph_admission': code,
          'reason':
              '20 strength graphs remain incomplete; no null IDs or empty placeholder bodies submitted',
        });
      }
      report['full_schedule'] = results;
    },
  );

  test(
    '39 actual timed bodies admit structurally; final distance 10K refuses; target freeze remains required',
    () {
      final package = read('SCHEDULE_CANDIDATE.json') as Map;
      final results = <Map>[];
      for (final row in read('RUNNING_BODIES.json') as List) {
        final id = row['source_session_id'] as String;
        final codes = <String>[];
        for (final version in [1, 2]) {
          final compiled = const PlanPackageCompiler().compile(
            jsonEncode(retained.extractedPackage(package, id, version)),
          );
          expect(compiled.isValid, isTrue, reason: compiled.issues.toString());
          final raw = jsonEncode([retained.graph(row as Map)]);
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
        if (row['distance_metres'] != 0) {
          expect(id, 'LW10K-W10-D07');
          expect(row['distance_metres'], 10000);
          expect(codes, everyElement('unsupported_timed_running_body'));
        } else {
          expect(codes, everyElement('accepted_local_graph'));
          final block = retained.blockFor(row as Map);
          final plan = SessionExecutionPlan(
            sessionId: id,
            sessionTitle: id,
            blocks: [block],
          );
          const codec = SessionExecutionPlanCodec();
          final restored = codec.decodePlan(
            jsonDecode(jsonEncode(codec.encodePlan(plan))),
          );
          expect(
            restored.blocks.single.timerConfiguration!.toJson(),
            block.timerConfiguration!.toJson(),
          );
          expect(
            requiresZone2Admission(plan) || requiresQualityAdmission(plan),
            isTrue,
          );
          expect(
            () =>
                AuthoredTimedRunningExecution.fromBlock(restored.blocks.single),
            throwsFormatException,
            reason:
                'No invented athlete input or frozen acceptance for genuine source',
          );
        }
        results.add({
          'source_session_id': id,
          'v1_v2': codes,
          'fixed_seconds': row['fixed_seconds'],
          'distance_metres': row['distance_metres'],
          'canonical_start_or_resume': 'NOT_ATTEMPTED',
        });
      }
      expect(
        results.where(
          (r) => (r['v1_v2'] as List).first == 'accepted_local_graph',
        ),
        hasLength(39),
      );
      report['running_bodies'] = results;
    },
  );

  test(
    'founder-selected replacements retain exact phases, recovery counts and no invented pace',
    () {
      final rows = read('RUNNING_BODIES.json') as List;
      final vectors = {
        4: (2550, 4, 300000, 90000),
        8: (2940, 3, 540000, 120000),
        9: (2400, 3, 360000, 120000),
        10: (1680, 3, 120000, 120000),
      };
      for (final item in vectors.entries) {
        final row = rows.singleWhere(
          (r) => r['source_week'] == item.key && r['source_day'] == 2,
        );
        expect(row['fixed_seconds'], item.value.$1);
        final steps = row['workout']['steps'] as List;
        expect(
          steps
              .take(7)
              .fold<int>(
                0,
                (n, s) => n + (s['duration']['milliseconds'] as int),
              ),
          780000,
        );
        expect(
          steps.where((s) => s['label'] == 'Relaxed acceleration'),
          hasLength(3),
        );
        final work = steps
            .where((s) => s['target']['kind'] == 'alpha_quality_pace_v1')
            .toList();
        expect(work, hasLength(item.value.$2));
        expect(
          work.map((s) => s['duration']['milliseconds']),
          everyElement(item.value.$3),
        );
        expect(
          work.map((s) => s['target']['category']),
          everyElement(item.key == 4 ? 'threshold' : '10k_specific'),
        );
        expect(
          work.every((s) => !(s['target'] as Map).containsKey('fallback_rpe')),
          isTrue,
        );
        final between = steps
            .skip(7)
            .take(steps.length - 8)
            .where((s) => s['label'] == 'Recovery')
            .toList();
        expect(between, hasLength(item.value.$2 - 1));
        expect(
          between.map((s) => s['duration']['milliseconds']),
          everyElement(item.value.$4),
        );
        expect(
          steps[steps.length - 2]['target']['kind'],
          'alpha_quality_pace_v1',
        );
        expect(steps.last['duration']['milliseconds'], 300000);
        expect(steps.last['label'], contains('running or walking'));
        expect(
          steps
              .where((s) => s['target']['kind'] != 'alpha_quality_pace_v1')
              .map((s) => s['target']['kind']),
          everyElement('none'),
        );
      }
      report['selected_replacement_vectors'] =
          'PASS_2550_2940_2400_1680_SECONDS_NO_FINAL_WORK_RECOVERY';
    },
  );

  test(
    'pinned exact local row intake resolves 37 occurrences; 87 remain blocked by actual identity gaps',
    () {
      final evidence = read('IDENTITY_INTAKE.json') as Map;
      final rows = evidence['repository_rows'] as Map;
      final sourcePath = rows.values.first['source_path'] as String;
      expect(
        sha256.convert(File(sourcePath).readAsBytesSync()).toString(),
        rows.values.first['source_sha256'],
      );
      final source = read('SOURCE.json') as Map;
      final occurrences = evidence['occurrences'] as List;
      final catalogue = rows.values
          .map(
            (r) => intake.Exercise.fromMap(
              Map<String, dynamic>.from(r['catalogue_row'] as Map),
            ),
          )
          .toList();
      final refs = {
        'EX-073': 'cohort.exercise.back_squat',
        'EX-078': 'cohort.exercise.romanian_deadlift',
        'EX-101': 'cohort.exercise.farmer_carry',
      };
      final document = const FounderProgrammeYamlParser().parse(
        jsonEncode({
          'schema_version': 1,
          'programme': {
            'import_key': 'hybrid10k-general-local-intake',
            'title': source['title'],
            'code': source['programme_id'],
            'duration_weeks': 10,
          },
          'weeks': [
            for (var week = 1; week <= 10; week++)
              {
                'week_number': week,
                'days': [
                  for (final s in (source['sessions'] as List).where(
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
                                  var index = 0;
                                  index < (s['exercises'] as List).length;
                                  index++
                                )
                                  (() {
                                    final e = s['exercises'][index];
                                    final b = occurrences.singleWhere(
                                      (b) =>
                                          b['source_occurrence_id'] ==
                                          e['exercise_occurrence_id'],
                                    );
                                    return {
                                      'order': index + 1,
                                      'exercise_name': e['exercise'],
                                      if (refs.containsKey(b['exercise_id']))
                                        'transitional_exercise_id':
                                            refs[b['exercise_id']],
                                      if (b['exercise_id'] == 'EX-116')
                                        'exercise_slug': 'side-plank',
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
      final resolver = FounderProgrammeExerciseResolver.fromCatalogue(
        catalogue,
        transitionalIdentityResolver: RepositoryTransitionalIdentityAdapter(
          InMemoryTransitionalExerciseIdBridge(
            initial: FounderApprovedIdentityMappingsPhase31F.allMappings,
          ),
        ),
      );
      final result = resolver.resolveDocument(document);
      expect(result.canonicalIds, hasLength(37));
      expect(result.issues, hasLength(87));
      expect(
        result.issues.map((i) => i.code),
        everyElement('legacy_exercise_reference_unresolved'),
      );
      expect(result.canonicalIds.values.toSet(), {
        'EX-073',
        'EX-078',
        'EX-101',
        'EX-116',
      });
      report['strength_identity'] = {
        'verified_local_occurrences': 37,
        'unresolved_occurrences': 87,
        'unique_bound_ids': result.canonicalIds.values.toSet().toList()..sort(),
        'canonical_definition_versions_or_publication_events_created': false,
        'evidence_scope':
            'Pinned existing v1/v2 repository row declarations, not current hosted state or v3 definition publication',
        'unique_unresolved_source_labels':
            result.issues.map((i) => i.rawReference).toSet().toList()..sort(),
      };
    },
  );

  test(
    'all 124 native strength prescriptions preserve ranges, sides, loads and minimum RIR without new intake infrastructure',
    () {
      final occurrences = read('IDENTITY_INTAKE.json')['occurrences'] as List;
      expect(occurrences, hasLength(124));
      for (final b in occurrences) {
        final raw = Map<String, dynamic>.from(b['prescription'] as Map);
        final typed = StrengthExercisePrescription.fromJson(raw);
        expect(typed.validate(requireComplete: true), isEmpty);
        final restored = StrengthExercisePrescription.fromJson(
          jsonDecode(jsonEncode(typed.toJson())),
        );
        expect(restored.toJson(), typed.toJson());
        if (raw.containsKey('rest_seconds_range')) {
          expect(restored.restSeconds, isNull);
          expect(
            restored.restSecondsRange!.toJson(),
            raw['rest_seconds_range'],
          );
        }
        expect(
          restored.authoredDetails!['source_rir'],
          raw['authored_details']['source_rir'],
        );
        if ((b['source_occurrence_id'] as String).startsWith('W10-B-')) {
          expect(restored.sets, 2);
          expect(restored.rirRange, isNull);
          expect(restored.coachCue, contains('At least 3 RIR'));
        }
      }
      report['native_prescription_round_trips'] = 124;
      report['new_runtime_or_schema_intake_fix_required'] = false;
    },
  );
}
