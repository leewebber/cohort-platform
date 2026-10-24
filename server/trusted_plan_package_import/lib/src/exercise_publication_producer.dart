import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'publication_events.dart';

/// Uses the existing SQL producer capability, never the ordinary service role.
/// The database authenticates/authorises the credential and performs exact full
/// definition validation, immutable conflict detection and retirement atomically.
class SupabaseExercisePublicationProducer {
  const SupabaseExercisePublicationProducer({
    required this.supabaseUrl,
    required this.anonKey,
    required this.producerCredential,
    required this.client,
  });
  final Uri supabaseUrl;
  final String anonKey;
  final String producerCredential;
  final http.Client client;

  Future<Map<String, Object?>> retain(VerifiedPublicationEvent event) async {
    if (!{'exercise_published', 'exercise_retired'}.contains(event.kind) ||
        producerCredential.trim().isEmpty) {
      throw const PublicationBoundaryException(
        'producer_capability_unavailable',
      );
    }
    try {
      final request = http.Request(
        'POST',
        supabaseUrl.resolve('/rest/v1/rpc/retain_published_exercise_event_v1'),
      )..followRedirects = false;
      request.headers.addAll({
        'apikey': anonKey,
        'authorization': 'Bearer $producerCredential',
        'content-type': 'application/json',
        'accept': 'application/json',
      });
      request.body = jsonEncode({
        'p_canonical_text': event.artifact['canonical_text'],
        'p_publication': event.artifact['publication'],
        'p_retirement': event.artifact['retirement'],
      });
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 10));
      final text = await readBounded(response.stream, 65536);
      if (response.statusCode == 409) {
        throw const PublicationBoundaryException(
          'immutable_event_conflict',
          status: 409,
        );
      }
      if (response.statusCode == 400 || response.statusCode == 422) {
        throw const PublicationBoundaryException(
          'event_admission_refused',
          status: 422,
        );
      }
      if (response.statusCode != 200) {
        throw const PublicationBoundaryException(
          'producer_capability_unavailable',
        );
      }
      final result = Map<String, Object?>.from(jsonDecode(text) as Map);
      final definition =
          jsonDecode(event.artifact['canonical_text'] as String) as Map;
      if (result['status'] != 'retained' ||
          result['exercise_id'] != definition['id'] ||
          result['definition_version'] != definition['version'] ||
          result['retired'] is! bool ||
          (event.artifact['retirement'] != null && result['retired'] != true) ||
          result['content_digest'] != personalisationDigest(definition)) {
        throw const PublicationBoundaryException('invalid_producer_result');
      }
      return result;
    } on PublicationBoundaryException {
      rethrow;
    } catch (_) {
      throw const PublicationBoundaryException(
        'producer_capability_unavailable',
      );
    }
  }
}
