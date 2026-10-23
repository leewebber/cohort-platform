import 'dart:convert';
import 'package:cohort_platform/application/exercise_knowledge/published_version_retention.dart';
import 'package:cohort_platform/application/hyrox_base/programme_prescription_repository.dart';
import 'package:cohort_platform/domain/exercise_knowledge/in_memory/in_memory_exercise_knowledge_repository.dart';
import 'package:cohort_platform/domain/exercise_knowledge/models/exercise_catalogue_snapshot.dart';
import 'package:cohort_platform/domain/exercise_knowledge/models/exercise_definition.dart';
import 'package:cohort_platform/domain/exercise_knowledge/value_objects/exercise_id.dart';
import 'package:cohort_platform/domain/exercise_knowledge/vocabulary/exercise_lifecycle_status.dart';
import 'package:cohort_platform/domain/exercise_knowledge/vocabulary/exercise_modality.dart';
import 'package:cohort_platform/features/session/services/programme_training_session_start_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'exact published lookup requires independent verified publication provenance',
    () async {
      final definition = ExerciseDefinition(
        id: ExerciseId.parse('EX-900900'),
        canonicalName: 'Synthetic',
        modality: ExerciseModality.locomotion,
        lifecycleStatus: ExerciseLifecycleStatus.published,
        version: 'release-A',
        publishedAt: DateTime.utc(2026, 10, 23),
      );
      final lookup = InMemoryExerciseKnowledgeRepository(
        initial: ExerciseCatalogueSnapshot(
          catalogueVersion: 'synthetic',
          definitions: [definition],
          relationships: [],
          comparisonProtocols: [],
        ),
      );
      final authority = _PublicationAuthority();
      var writes = 0;
      final retention = PublishedExerciseVersionRetention(
        lookup: lookup,
        authority: authority,
        retain: (text, event) async {
          writes++;
          expect((jsonDecode(text) as Map)['version'], 'release-A');
          expect(event['event_id'], 'verified-event');
          return {'status': 'retained'};
        },
      );
      await expectLater(
        retention.retainExact(definition.id, '1'),
        throwsStateError,
      );
      await expectLater(
        retention.retainExact(definition.id, 'release-A'),
        throwsStateError,
      );
      expect(writes, 0);
      authority.event = {'event_id': 'verified-event'};
      expect(
        (await retention.retainExact(definition.id, 'release-A'))['status'],
        'retained',
      );
      expect(writes, 1);
    },
  );
  test(
    'programme review, consent and withdrawal use scoped raw RPC; start delegates canonically',
    () async {
      final calls = <String>[];
      final payloads = <Map>[];
      final starts = _Starts();
      final repository = ProgrammePrescriptionRepository(
        starts: starts,
        rpc: (name, parameters) async {
          calls.add(name);
          payloads.add(parameters['payload']! as Map);
          return {'status': 'review'};
        },
      );
      await repository.review(
        assignmentId: 'assignment',
        programmeVersionId: 'version',
        selectedRevisions: {'run10km': 'revision'},
        incrementGrams: 2500,
      );
      await repository.consent(
        commandId: 'accept',
        assignmentId: 'assignment',
        programmeVersionId: 'version',
        reviewId: 'review',
        expectedConsentId: null,
        withdraw: false,
      );
      await repository.consent(
        commandId: 'withdraw',
        assignmentId: 'assignment',
        programmeVersionId: 'version',
        reviewId: null,
        expectedConsentId: 'consent',
        withdraw: true,
      );
      await repository.start(occurrenceId: 'occurrence', consentId: 'consent');
      expect(calls, [
        'review_hyrox_programme_prescription',
        'consent_hyrox_programme_prescription',
        'consent_hyrox_programme_prescription',
      ]);
      expect(
        payloads.first.keys,
        unorderedEquals([
          'assignment_id',
          'programme_version_id',
          'selected_revisions',
          'increment_grams',
        ]),
      );
      expect(payloads.last['action'], 'withdraw');
      expect(payloads.last['expected_consent_id'], 'consent');
      expect(starts.payload, {
        'occurrence_id': 'occurrence',
        'bound_consent_id': 'consent',
      });
    },
  );
}

class _PublicationAuthority implements ExerciseVersionPublicationAuthority {
  Map<String, Object?>? event;
  @override
  Future<Map<String, Object?>?> verifiedPublicationFor(
    ExerciseDefinition definition,
  ) async => event;
}

class _Starts implements ProgrammeTrainingSessionStartStore {
  Map<String, dynamic>? payload;
  @override
  Future<Map<String, dynamic>> createOrResume(
    Map<String, dynamic> value,
  ) async {
    payload = value;
    return {'status': 'created'};
  }
}
