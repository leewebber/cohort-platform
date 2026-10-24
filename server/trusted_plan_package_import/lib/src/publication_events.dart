import 'dart:async';
import 'dart:convert';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:http/http.dart' as http;

/// Delivery is a hint, never publication proof. Implementations retrieve the
/// approved record from the separately configured trusted producer boundary.
abstract interface class VerifiedPublicationEvents {
  Future<VerifiedPublicationEvent> resolve(String eventId);
}

class PublicationBoundaryException implements Exception {
  const PublicationBoundaryException(this.code, {this.status = 503});
  final String code;
  final int status;
}

class VerifiedPublicationEvent {
  VerifiedPublicationEvent._(this.id, this.kind, this.artifact);
  final String id;
  final String kind;
  final Map<String, Object?> artifact;

  /// Only call on a response obtained from the trusted source, never HTTP input.
  factory VerifiedPublicationEvent.fromTrustedRecord(
    String requestedId,
    Map<String, Object?> record,
  ) {
    try {
      requireKeys(record, {
        'contract',
        'event_id',
        'kind',
        'approval',
        'artifact',
      });
      if (record['contract'] != 'cohort.trusted-publication-event.v1' ||
          record['event_id'] != requestedId ||
          !isEventId(requestedId)) {
        throw const FormatException();
      }
      final approval = Map<String, Object?>.from(record['approval'] as Map);
      requireKeys(approval, {'status', 'reference'});
      if (approval['status'] != 'approved') {
        throw const PublicationBoundaryException(
          'approval_unavailable',
          status: 409,
        );
      }
      final reference = approval['reference'];
      if (reference is! String ||
          reference.trim().isEmpty ||
          reference.length > 1024) {
        throw const FormatException();
      }
      final kind = record['kind'];
      final artifact = Map<String, Object?>.from(record['artifact'] as Map);
      if (kind == 'programme_approved') {
        requireKeys(artifact, {
          'source',
          'canonical_sha256',
          'programme_version_id',
          'owner_id',
        });
        if (artifact['source'] is! String ||
            utf8.encode(artifact['source'] as String).length > 1024 * 1024 ||
            artifact['canonical_sha256'] is! String ||
            !RegExp(
              r'^[0-9a-f]{64}$',
            ).hasMatch(artifact['canonical_sha256'] as String) ||
            !isEventId(artifact['programme_version_id']) ||
            !isEventId(artifact['owner_id'])) {
          throw const FormatException();
        }
      } else if (kind == 'exercise_published' || kind == 'exercise_retired') {
        requireKeys(artifact, {'canonical_text', 'publication', 'retirement'});
        final text = artifact['canonical_text'];
        if (text is! String || utf8.encode(text).length > 262144) {
          throw const FormatException();
        }
        final definition = Map<String, Object?>.from(jsonDecode(text) as Map);
        if (personalisationCanonicalJson(definition) != text ||
            definition['owner'] != 'founder' ||
            definition['lifecycle_status'] != 'published' ||
            definition['version'] is! String ||
            definition['published_at'] is! String) {
          throw const FormatException();
        }
        final publication = Map<String, Object?>.from(
          artifact['publication'] as Map,
        );
        requireKeys(publication, {
          'issuer',
          'event_id',
          'source_reference',
          'published_at',
          'approved_binding_kinds',
        });
        if (publication['issuer'] != 'founder_exercise_publication_v1' ||
            !isEventId(publication['event_id']) ||
            DateTime.parse(publication['published_at'] as String) !=
                DateTime.parse(definition['published_at'] as String)) {
          throw const FormatException();
        }
        final retirement = artifact['retirement'];
        if (retirement != null) {
          final retired = Map<String, Object?>.from(retirement as Map);
          requireKeys(retired, {
            'issuer',
            'event_id',
            'publication_event_id',
            'source_reference',
            'retired_at',
          });
          if (retired['issuer'] != publication['issuer'] ||
              !isEventId(retired['event_id']) ||
              retired['event_id'] == publication['event_id'] ||
              retired['publication_event_id'] != publication['event_id']) {
            throw const FormatException();
          }
        }
        final event = kind == 'exercise_published'
            ? publication
            : retirement as Map?;
        if (event == null ||
            event['event_id'] != requestedId ||
            event['source_reference'] != reference) {
          throw const FormatException();
        }
      } else {
        throw const FormatException();
      }
      // Deep copy freezes the trusted lookup result against later provider mutation.
      return VerifiedPublicationEvent._(
        requestedId,
        kind as String,
        _freeze(artifact) as Map<String, Object?>,
      );
    } on PublicationBoundaryException {
      rethrow;
    } catch (_) {
      throw const PublicationBoundaryException('invalid_trusted_event');
    }
  }
}

Object? _freeze(Object? value) {
  if (value is Map) {
    return Map<String, Object?>.unmodifiable({
      for (final e in value.entries) e.key as String: _freeze(e.value),
    });
  }
  if (value is List) return List<Object?>.unmodifiable(value.map(_freeze));
  return value;
}

bool isEventId(Object? value) =>
    value is String &&
    RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    ).hasMatch(value);

void requireKeys(Map<String, Object?> map, Set<String> keys) {
  if (map.length != keys.length || !keys.every(map.containsKey)) {
    throw const FormatException();
  }
}

/// Supported adapter contract, not evidence that such an upstream is provisioned.
/// TLS authenticates the configured origin; the credential authenticates this
/// receiver. Redirects are refused, including redirects to another trusted-looking URL.
class HttpVerifiedPublicationEvents implements VerifiedPublicationEvents {
  const HttpVerifiedPublicationEvents({
    required this.baseUrl,
    required this.credential,
    required this.client,
    this.timeout = const Duration(seconds: 10),
  });
  final Uri baseUrl;
  final String credential;
  final http.Client client;
  final Duration timeout;

  @override
  Future<VerifiedPublicationEvent> resolve(String eventId) async {
    if (!isEventId(eventId) || credential.trim().isEmpty) {
      throw const PublicationBoundaryException(
        'trusted_event_source_unavailable',
      );
    }
    try {
      final request = http.Request('GET', baseUrl.resolve(eventId))
        ..followRedirects = false;
      request.headers.addAll({
        'authorization': 'Bearer $credential',
        'accept': 'application/json',
      });
      final response = await client.send(request).timeout(timeout);
      if (response.statusCode != 200) {
        await response.stream.listen(null).cancel();
      }
      if (response.statusCode == 404) {
        throw const PublicationBoundaryException(
          'event_not_ready',
          status: 409,
        );
      }
      if (response.statusCode != 200 ||
          response.headers['content-type']?.split(';').first.trim() !=
              'application/json') {
        if (response.statusCode == 200) {
          await response.stream.listen(null).cancel();
        }
        throw const PublicationBoundaryException(
          'trusted_event_source_unavailable',
        );
      }
      final data = await readBounded(
        response.stream,
        2 * 1024 * 1024,
        timeout: timeout,
      );
      return VerifiedPublicationEvent.fromTrustedRecord(
        eventId,
        Map<String, Object?>.from(jsonDecode(data) as Map),
      );
    } on PublicationBoundaryException {
      rethrow;
    } catch (_) {
      throw const PublicationBoundaryException(
        'trusted_event_source_unavailable',
      );
    }
  }
}

Future<String> readBounded(
  Stream<List<int>> stream,
  int maximum, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final bytes = <int>[];
  final iterator = StreamIterator(stream);
  final clock = Stopwatch()..start();
  try {
    while (await iterator.moveNext().timeout(timeout - clock.elapsed)) {
      if (bytes.length + iterator.current.length > maximum) {
        throw const PublicationBoundaryException('body_too_large', status: 413);
      }
      bytes.addAll(iterator.current);
    }
    return utf8.decode(bytes, allowMalformed: false);
  } finally {
    await iterator.cancel();
  }
}
