import 'dart:convert';
import 'dart:io';

import 'package:cohort_platform/infrastructure/performance_tracking/supabase_programme_history_rpc_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'transport makes one loopback read RPC and forwards the claim',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final calls = <Map<String, Object?>>[];
      server.listen((request) async {
        calls.add({
          'method': request.method,
          'path': request.uri.path,
          'body': jsonDecode(await utf8.decoder.bind(request).join()),
        });
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          '{"status":"failure","code":"programme_authority_unavailable"}',
        );
        await request.response.close();
      });
      final client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'synthetic-only',
      );
      addTearDown(client.dispose);
      final transport = SupabaseProgrammeHistoryRpcClient(client);
      expect(transport.authenticatedAthleteId, isNull);
      final claim = <String, Object?>{
        'synthetic': 'opaque claim forwarded intact',
      };
      final result = await transport.readProgrammeHistory(
        recordId: 'c2000000-0000-4000-8000-000000000010',
        programmeClaim: claim,
      );
      expect(result, {
        'status': 'failure',
        'code': 'programme_authority_unavailable',
      });
      expect(calls, hasLength(1));
      expect(calls.single, {
        'method': 'POST',
        'path': '/rest/v1/rpc/read_performance_tracking_programme_history_v1',
        'body': {
          'p_record_id': 'c2000000-0000-4000-8000-000000000010',
          'p_programme_claim': claim,
        },
      });
    },
  );
}
