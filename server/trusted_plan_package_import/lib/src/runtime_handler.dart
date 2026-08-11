import 'dart:convert';
import 'dart:math';

import 'package:shelf/shelf.dart';

typedef RuntimeLogSink = void Function(String encodedEvent);
typedef RuntimeRequestIdFactory = String Function();

class TrustedRuntimeHandler {
  factory TrustedRuntimeHandler({
    required Handler importHandler,
    required RuntimeLogSink logSink,
    RuntimeRequestIdFactory? requestIdFactory,
  }) {
    return TrustedRuntimeHandler._(
      importHandler,
      logSink,
      requestIdFactory ?? _secureRequestId,
    );
  }

  TrustedRuntimeHandler._(
    this._importHandler,
    this._logSink,
    this._requestIdFactory,
  );

  static const healthPath = 'healthz';
  static const importPath = 'v1/founder/plan-packages/import';

  final Handler _importHandler;
  final RuntimeLogSink _logSink;
  final RuntimeRequestIdFactory _requestIdFactory;

  Future<Response> call(Request request) async {
    final stopwatch = Stopwatch()..start();
    final requestId = _requestId(request.headers['x-request-id']);
    Response response;

    try {
      response = request.url.path == healthPath
          ? _healthResponse(request)
          : await _importHandler(request);
    } catch (_) {
      response = _json(500, {
        'status': 'server_failure',
        'code': 'internal_server_error',
      });
    }

    stopwatch.stop();
    _logSink(
      jsonEncode({
        'severity': response.statusCode >= 500
            ? 'ERROR'
            : response.statusCode >= 400
            ? 'WARNING'
            : 'INFO',
        'event': 'http_request',
        'request_id': requestId,
        'route': _routeLabel(request.url.path),
        'method': request.method,
        'status_code': response.statusCode,
        'status_class': '${response.statusCode ~/ 100}xx',
        'duration_ms': stopwatch.elapsedMilliseconds,
      }),
    );

    return response.change(headers: {'x-request-id': requestId});
  }

  Response _healthResponse(Request request) {
    if (request.method != 'GET') {
      return _json(
        405,
        {'status': 'method_not_allowed', 'code': 'method_not_allowed'},
        headers: {'allow': 'GET'},
      );
    }
    return _json(200, {'status': 'ok'});
  }

  String _requestId(String? candidate) {
    if (candidate != null &&
        RegExp(r'^[A-Za-z0-9_-]{8,64}$').hasMatch(candidate)) {
      return candidate;
    }
    return _requestIdFactory();
  }

  String _routeLabel(String path) {
    return switch (path) {
      healthPath => 'health',
      importPath => 'founder_plan_package_import',
      _ => 'unsupported',
    };
  }

  Response _json(
    int statusCode,
    Map<String, Object?> body, {
    Map<String, String>? headers,
  }) {
    return Response(
      statusCode,
      body: jsonEncode(body),
      headers: {
        'content-type': 'application/json; charset=utf-8',
        'cache-control': 'no-store',
        ...?headers,
      },
    );
  }

  static String _secureRequestId() {
    final random = Random.secure();
    final bytes = List<int>.generate(18, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
