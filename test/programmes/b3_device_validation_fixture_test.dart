import 'dart:convert';
import 'dart:io';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:cohort_platform/features/private_programme/reviewed_protocol_graph_artifact.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../tool/programmes/bin/publish_private_exact_version.dart'
    as publisher;

void main() {
  const packagePath =
      'tool/programmes/b3_device_validation_v1.plan-package.yaml';
  const publicationPath =
      'content/programmes/b3_device_validation/v1/b3_device_validation.publication.json';
  const graphPath =
      'content/programmes/b3_device_validation/v1/protocol_graphs.json';

  late PlanPackageCompileResult compiled;
  late Map<String, dynamic> publication;
  late String graphSource;

  setUpAll(() {
    compiled = const PlanPackageCompiler().compile(
      File(packagePath).readAsStringSync(),
    );
    publication = Map<String, dynamic>.from(
      jsonDecode(File(publicationPath).readAsStringSync()) as Map,
    );
    graphSource = File(graphPath).readAsStringSync();
  });

  test('fixture is canonical private v2 and pins reviewed graph', () {
    expect(compiled.isValid, isTrue, reason: compiled.issues.toString());
    expect(
      compiled.contentHashSha256,
      'fe8d2bb2dfa5479a43062deb2974c9106640d652db6e29fa5b3dd02495e6cb4a',
    );
    expect(publication['source_package_hash'], compiled.contentHashSha256);
    expect(publication['publication_kind'], 'private_exact_version');
    expect(publication['library_scope'], 'coach_private');
    expect(publication['public_catalogue'], isFalse);
    expect(publication['classification'], 'developer_validation_test_only');
    expect(publication['commercial_percentage_bands_approved'], isFalse);
    expect(publication['authorised_timezone'], 'Asia/Makassar');
    expect(publication['authorised_local_start_date'], '2026-10-01');

    final graphs = const ReviewedProtocolGraphArtifact().decode(
      compileResult: compiled,
      source: graphSource,
      expectedSha256: publication['protocol_graph_sha256'] as String,
    );
    expect(graphs, hasLength(1));
    final block = ((graphs.single['blocks'] as List).single as Map);
    expect(block['workout_format'], 'intervals');
    expect(block['timer_config'], containsPair('work_seconds', 20));
    expect(block['timer_config'], containsPair('rest_seconds', 15));
    expect(block['timer_config'], containsPair('rounds', 3));
  });

  test(
    'four same-day occurrences cover calculated and intent-only policies',
    () {
      final slots = compiled.manifest!.weeks.single.days.single.slots;
      expect(slots, hasLength(4));
      expect(slots.map((slot) => slot.sessionOrder), [1, 2, 3, 4]);
      for (final slot in slots) {
        final running = slot.authoredRunningV1!;
        expect(running.workoutId, 'rw1:p:5b3e7ec49df769e8');
        expect(
          running.executableStepBindings!
              .map((item) => item.sessionBlockId)
              .toSet(),
          {'b1ea0297-6f2d-4b5b-8774-6421f01472a9'},
        );
        expect(
          running.advisoryAttachments.single.policy.policyId,
          contains('TEST-ONLY'),
        );
        expect(
          running.advisoryAttachments.single.policy.minimumSpeedBasisPoints,
          9000,
        );
        expect(
          running.advisoryAttachments.single.policy.maximumSpeedBasisPoints,
          10000,
        );
      }
      expect(
        slots
            .take(3)
            .every(
              (slot) => slot
                  .authoredRunningV1!
                  .advisoryAttachments
                  .single
                  .policy
                  .benchmarkEligibility
                  .manualCompletedTestsEligible,
            ),
        isTrue,
      );
      final unavailable = slots
          .last
          .authoredRunningV1!
          .advisoryAttachments
          .single
          .policy
          .benchmarkEligibility;
      expect(unavailable.manualCompletedTestsEligible, isFalse);
      expect(unavailable.cohortCompletedTestsEligible, isTrue);
      expect(unavailable.externalCompletedTestsEligible, isFalse);
    },
  );

  test('reviewed graph fails closed on hash or running timer drift', () {
    expect(
      () => const ReviewedProtocolGraphArtifact().decode(
        compileResult: compiled,
        source: graphSource,
        expectedSha256: List.filled(64, '0').join(),
      ),
      throwsA(
        isA<ReviewedProtocolGraphArtifactException>().having(
          (error) => error.code,
          'code',
          'protocol_graph_hash_mismatch',
        ),
      ),
    );
    final changed = graphSource.replaceFirst(
      '"work_seconds": 20',
      '"work_seconds": 21',
    );
    final changedHash = _sha256(changed);
    expect(
      () => const ReviewedProtocolGraphArtifact().decode(
        compileResult: compiled,
        source: changed,
        expectedSha256: changedHash,
      ),
      throwsA(
        isA<ReviewedProtocolGraphArtifactException>().having(
          (error) => error.code,
          'code',
          'running_projection_mismatch',
        ),
      ),
    );
  });

  test('publisher accepts only the exact attested response identity', () {
    final exact = <String, dynamic>{
      'status': 'published',
      'programme_version_id': publication['programme_version_id'],
      'package_content_hash': compiled.contentHashSha256,
      'package_schema_version': 2,
      'library_scope': 'coach_private',
      'session_count': 4,
    };
    String? validate(Map<String, dynamic> response) =>
        publisher.validatePrivateExactPublicationResponse(
          response,
          expectedProgrammeVersionId:
              publication['programme_version_id'] as String,
          expectedPackageHash: compiled.contentHashSha256!,
          expectedLibraryScope: 'coach_private',
          expectedPackageSchemaVersion: 2,
          expectedSessionCount: 4,
        );

    expect(validate(exact), isNull);
    expect(
      validate({...exact, 'programme_version_id': 'wrong'}),
      'programme_version_id_mismatch',
    );
    expect(
      validate({...exact, 'package_content_hash': List.filled(64, '0').join()}),
      'package_content_hash_mismatch',
    );
    expect(
      validate({...exact, 'package_schema_version': 1}),
      'package_schema_version_mismatch',
    );
    expect(validate({...exact, 'session_count': 3}), 'session_count_mismatch');
  });
}

String _sha256(String source) {
  return sha256.convert(utf8.encode(source)).toString();
}
