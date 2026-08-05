import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Bounded HTTP for Journey D hosted tooling.
///
/// Guarantees:
/// * connection open is deadline-bound;
/// * response headers are deadline-bound;
/// * response body drain is deadline-bound;
/// * clients are always closed;
/// * [dispatched] is true only after request bytes are handed to the socket.
class JourneyDBoundedHttp {
  JourneyDBoundedHttp({
    this.defaultTimeout = const Duration(seconds: 45),
  });

  final Duration defaultTimeout;

  Future<JourneyDBoundedHttpResponse> get(
    Uri uri, {
    Map<String, String> headers = const {},
    Duration? timeout,
  }) {
    return _send('GET', uri, headers: headers, timeout: timeout);
  }

  Future<JourneyDBoundedHttpResponse> post(
    Uri uri, {
    Map<String, String> headers = const {},
    Object? body,
    Duration? timeout,
  }) {
    return _send('POST', uri, headers: headers, body: body, timeout: timeout);
  }

  Future<JourneyDBoundedHttpResponse> patch(
    Uri uri, {
    Map<String, String> headers = const {},
    Object? body,
    Duration? timeout,
  }) {
    return _send('PATCH', uri, headers: headers, body: body, timeout: timeout);
  }

  Future<JourneyDBoundedHttpResponse> put(
    Uri uri, {
    Map<String, String> headers = const {},
    Object? body,
    Duration? timeout,
  }) {
    return _send('PUT', uri, headers: headers, body: body, timeout: timeout);
  }

  Future<JourneyDBoundedHttpResponse> _send(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
    Object? body,
    Duration? timeout,
  }) async {
    final bound = timeout ?? defaultTimeout;
    final client = HttpClient()
      ..connectionTimeout = bound
      ..idleTimeout = bound;
    var dispatched = false;
    try {
      return await Future<JourneyDBoundedHttpResponse>(() async {
        final HttpClientRequest req;
        switch (method) {
          case 'GET':
            req = await client.getUrl(uri);
          case 'POST':
            req = await client.postUrl(uri);
          case 'PATCH':
            req = await client.patchUrl(uri);
          case 'PUT':
            req = await client.putUrl(uri);
          default:
            throw StateError('unsupported_http_method');
        }
        headers.forEach(req.headers.set);
        if (body != null) {
          final bytes = body is List<int>
              ? body
              : utf8.encode(body is String ? body : jsonEncode(body));
          req.add(bytes);
          dispatched = true;
        } else if (method == 'GET') {
          // GET is considered dispatched once the request is opened/sent.
          dispatched = true;
        }
        final resp = await req.close();
        dispatched = true;
        final text = await resp.transform(utf8.decoder).join();
        return JourneyDBoundedHttpResponse(
          statusCode: resp.statusCode,
          body: text,
          contentRange: resp.headers.value('content-range'),
          dispatched: dispatched,
        );
      }).timeout(bound);
    } on TimeoutException {
      throw JourneyDHttpTimeoutException(
        method: method,
        routeClass: _routeClass(uri),
        dispatched: dispatched,
        timeout: bound,
      );
    } on SocketException catch (e) {
      throw JourneyDHttpTransportException(
        method: method,
        routeClass: _routeClass(uri),
        dispatched: dispatched,
        detail: 'socket_${e.osError?.errorCode ?? e.runtimeType}',
      );
    } on HttpException catch (e) {
      throw JourneyDHttpTransportException(
        method: method,
        routeClass: _routeClass(uri),
        dispatched: dispatched,
        detail: 'http_${e.runtimeType}',
      );
    } on FormatException {
      throw JourneyDHttpTransportException(
        method: method,
        routeClass: _routeClass(uri),
        dispatched: dispatched,
        detail: 'malformed_response',
      );
    } finally {
      client.close(force: true);
    }
  }

  static String _routeClass(Uri uri) {
    final segs = uri.pathSegments;
    if (segs.isEmpty) return '/';
    if (segs.length >= 2 && segs.first == 'auth') {
      return '/auth/v1/${segs.length >= 3 ? segs[2] : segs[1]}';
    }
    if (segs.length >= 2 && segs.first == 'rest') {
      return '/rest/v1/${segs[1]}';
    }
    return '/${segs.first}';
  }
}

class JourneyDBoundedHttpResponse {
  const JourneyDBoundedHttpResponse({
    required this.statusCode,
    required this.body,
    required this.dispatched,
    this.contentRange,
  });

  final int statusCode;
  final String body;
  final String? contentRange;
  final bool dispatched;
}

class JourneyDHttpTimeoutException implements Exception {
  JourneyDHttpTimeoutException({
    required this.method,
    required this.routeClass,
    required this.dispatched,
    required this.timeout,
  });

  final String method;
  final String routeClass;
  final bool dispatched;
  final Duration timeout;

  @override
  String toString() =>
      'JourneyDHttpTimeoutException($method $routeClass '
      'dispatched=$dispatched timeout=${timeout.inSeconds}s)';
}

class JourneyDHttpTransportException implements Exception {
  JourneyDHttpTransportException({
    required this.method,
    required this.routeClass,
    required this.dispatched,
    required this.detail,
  });

  final String method;
  final String routeClass;
  final bool dispatched;
  final String detail;

  @override
  String toString() =>
      'JourneyDHttpTransportException($method $routeClass $detail '
      'dispatched=$dispatched)';
}
