import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:shelf/shelf.dart';
import 'authoritative_v3_publication.dart';
import 'contracts.dart';
import 'publication_events.dart';

/// These ports are server-owned. Neither an athlete token nor a service key is
/// substituted for the distinct approval-writer and delivery capabilities.
abstract interface class PublicationApprovalStore
    implements VerifiedPublicationEvents {
  Future<Map<String, Object?>> prepare(
    String actor,
    Map<String, Object?> input,
  );
  Future<Map<String, Object?>> review(String actor, String id);
  Future<Map<String, Object?>> approve(String actor, String id, String digest);
  Future<List<Object?>> pending(String actor);
  Future<Map<String, Object?>> retry(String actor, String id, String digest);
  Future<Map<String, Object?>> claim(String actor, String id);
  Future<void> finish(
    String actor,
    String id,
    String lease,
    String outcome,
    Map<String, Object?> receipt,
  );
}

class SupabasePublicationApprovalStore implements PublicationApprovalStore {
  const SupabasePublicationApprovalStore({
    required this.supabaseUrl,
    required this.anonKey,
    required this.deliveryCredential,
    required this.client,
    this.writerCredential,
  });
  final Uri supabaseUrl;
  final String anonKey, deliveryCredential;
  final String? writerCredential;
  final http.Client client;

  Future<Object?> _rpc(
    String name,
    Map<String, Object?> args, {
    bool writer = false,
  }) async {
    final credential = writer ? writerCredential : deliveryCredential;
    if (credential == null || credential.isEmpty) {
      throw const PublicationBoundaryException(
        'approval_configuration_unavailable',
      );
    }
    try {
      final req = http.Request(
        'POST',
        supabaseUrl.resolve('/rest/v1/rpc/$name'),
      )..followRedirects = false;
      req.headers.addAll({
        'apikey': anonKey,
        'authorization': 'Bearer $credential',
        'content-type': 'application/json',
      });
      req.body = jsonEncode(args);
      final response = await client
          .send(req)
          .timeout(const Duration(seconds: 10));
      final body = await readBounded(response.stream, 2 * 1024 * 1024);
      if (response.statusCode != 200) {
        throw PublicationBoundaryException(
          response.statusCode == 409
              ? 'approval_or_lease_conflict'
              : 'approval_store_refused',
          status: response.statusCode == 409
              ? 409
              : response.statusCode == 400
              ? 422
              : 503,
        );
      }
      return jsonDecode(body);
    } on PublicationBoundaryException {
      rethrow;
    } catch (_) {
      throw const PublicationBoundaryException('approval_store_unavailable');
    }
  }

  Future<Map<String, Object?>> _map(
    String name,
    Map<String, Object?> args, {
    bool writer = false,
  }) async =>
      Map<String, Object?>.from(await _rpc(name, args, writer: writer) as Map);
  @override
  Future<Map<String, Object?>> prepare(
    String actor,
    Map<String, Object?> input,
  ) => _map('prepare_publication_approval_v1', {
    'p_actor': actor,
    'p_request_id': input['request_id'],
    'p_kind': input['kind'],
    'p_input': input['input'],
  }, writer: true);
  @override
  Future<Map<String, Object?>> review(String actor, String id) => _map(
    'read_publication_approval_draft_v1',
    {'p_actor': actor, 'p_event_id': id},
    writer: true,
  );
  @override
  Future<Map<String, Object?>> approve(
    String actor,
    String id,
    String digest,
  ) => _map('approve_publication_event_v1', {
    'p_actor': actor,
    'p_event_id': id,
    'p_artifact_sha256': digest,
  }, writer: true);
  @override
  Future<List<Object?>> pending(String actor) async => List<Object?>.from(
    await _rpc('list_publication_deliveries_v1', {'p_actor': actor}) as List,
  );
  @override
  Future<Map<String, Object?>> retry(String actor, String id, String digest) =>
      _map('retry_publication_delivery_v1', {
        'p_actor': actor,
        'p_event_id': id,
        'p_artifact_sha256': digest,
      });
  @override
  Future<Map<String, Object?>> claim(String actor, String id) => _map(
    'claim_publication_delivery_v1',
    {'p_actor': actor, 'p_event_id': id},
  );
  @override
  Future<void> finish(
    String actor,
    String id,
    String lease,
    String outcome,
    Map<String, Object?> receipt,
  ) async {
    await _rpc('finish_publication_delivery_v1', {
      'p_actor': actor,
      'p_event_id': id,
      'p_lease_id': lease,
      'p_outcome': outcome,
      'p_receipt': receipt,
    });
  }

  @override
  Future<VerifiedPublicationEvent> resolve(String eventId) async {
    if (!isEventId(eventId)) {
      throw const PublicationBoundaryException('invalid_event_id', status: 422);
    }
    final rec = await _map('resolve_publication_approval_event_v1', {
      'p_event_id': eventId,
    });
    return VerifiedPublicationEvent.fromTrustedRecord(eventId, rec);
  }
}

/// Two explicit Founder actions: prepare/review exact proposed bytes, then approve
/// the returned digest. Delivery is another action; approval never publishes.
/// Pending work survives process/revision/token expiry in SQL, not an in-memory timer.
class DurablePublicationApprovalEndpoint {
  const DurablePublicationApprovalEndpoint({
    required this.founder,
    this.store,
    this.deliveryHandler,
  });
  static const prefix = 'v1/founder/publication-approvals/';
  static const actions = {
    'prepare',
    'review',
    'approve',
    'pending',
    'deliver',
    'retry',
  };
  static bool handles(String path) =>
      path.startsWith(prefix) &&
      actions.contains(path.substring(prefix.length));
  final TrustedV3FounderPublication founder;
  final PublicationApprovalStore? store;
  final Future<Response> Function(Request)? deliveryHandler;

  Future<Response> call(Request request) async {
    if (!handles(request.url.path)) {
      return _json(404, {'code': 'route_not_found'});
    }
    if (request.method != 'POST') {
      return _json(405, {'code': 'method_not_allowed'});
    }
    final token = RegExp(
      r'^Bearer +([^ ]+)$',
      caseSensitive: false,
    ).firstMatch(request.headers['authorization']?.trim() ?? '')?.group(1);
    if (token == null) return _json(401, {'code': 'bearer_token_required'});
    try {
      final principal = await founder.requireFounder(token);
      if (store == null) {
        return _json(503, {'code': 'approval_configuration_unavailable'});
      }
      if (request.headers['content-type']?.split(';').first.trim() !=
          'application/json') {
        return _json(415, {'code': 'json_content_type_required'});
      }
      final action = request.url.path.substring(prefix.length);
      final input = Map<String, Object?>.from(
        jsonDecode(
              await readBounded(
                request.read(),
                action == 'prepare' ? 2 * 1024 * 1024 : 256,
              ),
            )
            as Map,
      );
      final actor = principal.userId;
      switch (action) {
        case 'prepare':
          requireKeys(input, {'request_id', 'kind', 'input'});
          if (!isEventId(input['request_id']) ||
              !{
                'exercise_published',
                'exercise_retired',
                'programme_approved',
              }.contains(input['kind']) ||
              input['input'] is! Map) {
            throw const FormatException();
          }
          if (input['kind'] == 'programme_approved') {
            final a = Map<String, Object?>.from(input['input'] as Map);
            requireKeys(a, {
              'source',
              'canonical_sha256',
              'programme_version_id',
              'owner_id',
            });
            if (a['source'] is! String ||
                !isEventId(a['programme_version_id']) ||
                !isEventId(a['owner_id'])) {
              throw const FormatException();
            }
            final c = const PlanPackageCompiler(
              validator: PlanPackageValidator(
                personalisationResolver: _ApprovalPreviewOnly(),
              ),
            ).compile(a['source'] as String);
            if (!c.isValid ||
                c.manifest?.packageSchemaVersion != 3 ||
                c.contentHashSha256 != a['canonical_sha256']) {
              throw const FormatException();
            }
          }
          return _json(200, await store!.prepare(actor, input));
        case 'review':
          _id(input);
          return _json(
            200,
            await store!.review(actor, input['event_id'] as String),
          );
        case 'approve':
        case 'retry':
          requireKeys(input, {'event_id', 'artifact_sha256'});
          if (!isEventId(input['event_id']) ||
              input['artifact_sha256'] is! String ||
              !RegExp(
                r'^[0-9a-f]{64}$',
              ).hasMatch(input['artifact_sha256'] as String)) {
            throw const FormatException();
          }
          return _json(
            200,
            await (action == 'approve' ? store!.approve : store!.retry)(
              actor,
              input['event_id'] as String,
              input['artifact_sha256'] as String,
            ),
          );
        case 'pending':
          requireKeys(input, {});
          return _json(200, {'pending': await store!.pending(actor)});
        case 'deliver':
          _id(input);
          // No lease or upstream read if publication is disabled in this revision.
          if (deliveryHandler == null) {
            return _json(503, {'code': 'delivery_configuration_unavailable'});
          }
          final id = input['event_id'] as String;
          final claim = await store!.claim(actor, id);
          if (claim['status'] != 'claimed') {
            if (!{'wait', 'delivered', 'blocked'}.contains(claim['status'])) {
              throw const PublicationBoundaryException(
                'invalid_delivery_claim',
              );
            }
            return _json(claim['status'] == 'wait' ? 409 : 200, claim);
          }
          final lease = claim['lease_id'];
          if (!isEventId(lease) || claim['event_id'] != id) {
            throw const PublicationBoundaryException('invalid_delivery_claim');
          }
          // Re-enter the existing verified receiver with the same user session and
          // ID only. It authenticates again; no machine impersonation or raw approval.
          Response response;
          Map<String, Object?> receipt;
          try {
            final event = await store!.resolve(id);
            response = await deliveryHandler!(
              Request(
                'POST',
                Uri.parse(
                  'http://localhost/${event.kind == 'programme_approved' ? 'v1/founder/plan-packages/publish-v3' : 'v1/founder/exercise-publication-events/receive'}',
                ),
                headers: {
                  'authorization': 'Bearer $token',
                  'content-type': 'application/json',
                },
                body: jsonEncode({'event_id': id}),
              ),
            );
            receipt = Map<String, Object?>.from(
              jsonDecode(await readBounded(response.read(), 2048)) as Map,
            );
          } catch (_) {
            await store!.finish(actor, id, lease as String, 'retry', {
              'code': 'delivery_unavailable',
            });
            return _json(503, {
              'code': 'delivery_pending_retry',
              'event_id': id,
            });
          }
          final success =
              response.statusCode == 200 &&
              receipt['event_received'] == true &&
              receipt['event_id'] == id &&
              receipt['approval_evidence'] == 'verified_producer_record' &&
              {
                'retained',
                'published',
                'already_published',
              }.contains(receipt['status']);
          // Only known receipt fields cross the durable status boundary. Never
          // persist arbitrary upstream error details, tokens, source or SQL text.
          final safe = <String, Object?>{
            if (success) ...{
              for (final k in [
                'status',
                'event_id',
                'event_received',
                'approval_evidence',
                'programme_version_id',
                'approved_for_global',
                'retired',
              ])
                if (receipt.containsKey(k)) k: receipt[k],
            },
            if (!success)
              'code': response.statusCode == 409
                  ? 'immutable_conflict'
                  : response.statusCode == 422
                  ? 'admission_refused'
                  : 'delivery_unavailable',
          };
          final outcome = success
              ? 'delivered'
              : {409, 422}.contains(response.statusCode)
              ? 'blocked'
              : 'retry';
          await store!.finish(actor, id, lease as String, outcome, safe);
          return _json(
            success
                ? 200
                : outcome == 'blocked'
                ? 409
                : 503,
            {'event_id': id, 'status': outcome},
          );
      }
      return _json(404, {'code': 'route_not_found'});
    } on InvalidFounderCredentials {
      return _json(401, {'code': 'invalid_or_expired_token'});
    } on FounderPermissionRequired {
      return _json(403, {'code': 'founder_authority_required'});
    } on TrustedAuthenticationException {
      return _json(503, {'code': 'authentication_unavailable'});
    } on FounderAuthorityLookupException {
      return _json(503, {'code': 'founder_authority_unavailable'});
    } on PublicationBoundaryException catch (e) {
      return _json(e.status, {'code': e.code});
    } on FormatException {
      return _json(422, {'code': 'invalid_approval_request'});
    } on TypeError {
      return _json(422, {'code': 'invalid_approval_request'});
    }
  }

  void _id(Map<String, Object?> input) {
    requireKeys(input, {'event_id'});
    if (!isEventId(input['event_id'])) throw const FormatException();
  }

  Response _json(int status, Map<String, Object?> body) => Response(
    status,
    body: jsonEncode(body),
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': 'no-store',
    },
  );
}

// Preview establishes exact compiler bytes only; SQL canonical admission still
// independently resolves every real retained dependency at delivery.
class _ApprovalPreviewOnly implements PersonalisationDependencyResolver {
  const _ApprovalPreviewOnly();
  @override
  String? validateTarget(PlanPackagePersonalisationTarget target) => null;
}
