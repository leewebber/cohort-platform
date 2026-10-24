import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'authoritative_v3_publication.dart';
import 'contracts.dart';
import 'exercise_publication_producer.dart';
import 'publication_events.dart';

/// Only event identifiers cross this HTTP boundary. Content, owner/version,
/// approval and capability credentials are resolved by configured trusted ports.
class TrustedV3PublicationEndpoint {
  const TrustedV3PublicationEndpoint({
    required this.founderPublication,
    this.events,
    this.exerciseProducer,
  });
  static const exerciseRoute = 'v1/founder/exercise-publication-events/receive';
  static const programmeRoute = 'v1/founder/plan-packages/publish-v3';
  final TrustedV3FounderPublication founderPublication;
  final VerifiedPublicationEvents? events;
  final SupabaseExercisePublicationProducer? exerciseProducer;

  Future<Response> call(Request request) async {
    if (!{exerciseRoute, programmeRoute}.contains(request.url.path)) {
      return _json(404, 'route_not_found');
    }
    if (request.method != 'POST') {
      return _json(405, 'method_not_allowed', headers: {'allow': 'POST'});
    }
    final token = RegExp(
      r'^Bearer +([^ ]+)$',
      caseSensitive: false,
    ).firstMatch(request.headers['authorization']?.trim() ?? '')?.group(1);
    if (token == null) return _json(401, 'bearer_token_required');
    try {
      // Same Auth/Founder ports as the legacy transport, before any body/source read.
      final principal = await founderPublication.requireFounder(token);
      if (events == null || exerciseProducer == null) {
        return _json(503, 'v3_configuration_unavailable');
      }
      if (request.headers['content-type']?.split(';').first.trim() !=
          'application/json') {
        return _json(415, 'json_content_type_required');
      }
      final input = Map<String, Object?>.from(
        jsonDecode(await readBounded(request.read(), 256)) as Map,
      );
      requireKeys(input, {'event_id'});
      if (!isEventId(input['event_id'])) throw const FormatException();
      final event = await events!.resolve(input['event_id'] as String);
      if (event.id != input['event_id']) {
        throw const PublicationBoundaryException('invalid_trusted_event');
      }
      final Map<String, Object?> result;
      if (request.url.path == exerciseRoute) {
        if (event.kind == 'programme_approved') {
          return _json(422, 'wrong_event_kind');
        }
        result = await exerciseProducer!.retain(event);
      } else {
        if (event.kind != 'programme_approved') {
          return _json(422, 'wrong_event_kind');
        }
        final a = event.artifact;
        result = await founderPublication.publication.publish(
          source: a['source'] as String,
          programmeVersionId: a['programme_version_id'] as String,
          ownerId: a['owner_id'] as String,
          importedBy: principal.userId,
          approvedContentHash: a['canonical_sha256'] as String,
        );
        if (!{'published', 'already_published'}.contains(result['status'])) {
          return _json(422, 'v3_admission_refused');
        }
        if (result['programme_version_id'] != a['programme_version_id'] ||
            result['package_schema_version'] != 3 ||
            result['package_content_hash'] != a['canonical_sha256']) {
          throw const PublicationBoundaryException(
            'invalid_publication_result',
          );
        }
      }
      // Receipt and technical success do not grant new content/global approval.
      return Response.ok(
        jsonEncode({
          'status': result['status'],
          'event_received': true,
          'event_id': event.id,
          'approval_evidence': 'verified_producer_record',
          if (event.kind == 'programme_approved')
            'programme_version_id': result['programme_version_id'],
          if (event.kind == 'programme_approved') 'approved_for_global': false,
          if (event.kind != 'programme_approved') 'retired': result['retired'],
        }),
        headers: _headers,
      );
    } on InvalidFounderCredentials {
      return _json(401, 'invalid_or_expired_token');
    } on FounderPermissionRequired {
      return _json(403, 'founder_authority_required');
    } on TrustedAuthenticationException {
      return _json(503, 'authentication_unavailable');
    } on FounderAuthorityLookupException {
      return _json(503, 'founder_authority_unavailable');
    } on PlanPackageRpcException {
      return _json(503, 'publication_service_unavailable');
    } on PublicationBoundaryException catch (e) {
      return _json(e.status, e.code);
    } on FormatException {
      return _json(422, 'invalid_event_request_or_source');
    } on TypeError {
      return _json(422, 'invalid_event_request_or_source');
    }
  }

  static const _headers = {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
  };
  Response _json(int status, String code, {Map<String, String>? headers}) =>
      Response(
        status,
        body: jsonEncode({'status': 'refused', 'code': code}),
        headers: {..._headers, ...?headers},
      );
}
