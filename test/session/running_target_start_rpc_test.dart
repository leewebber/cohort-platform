import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cohort_platform/features/session/services/programme_training_session_start_supabase_store.dart';

class CaptureRpc {
  CaptureRpc(this.server);
  final HttpServer server;
  Map<String, dynamic>? body;
  static Future<CaptureRpc> open() async {
    final capture = CaptureRpc(
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    );
    capture.server.listen((request) async {
      capture.body =
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        '{"status":"refused","code":"running_target_review_required"}',
      );
      await request.response.close();
    });
    return capture;
  }

  SupabaseClient client() =>
      SupabaseClient('http://127.0.0.1:${server.port}', 'local-test-key');
}

void main() {
  for (final input in <Map<String, dynamic>>[
    {'occurrence_id': 'occ', 'target_source': 'five_k'},
    {'occurrence_id': 'occ'},
    {
      'occurrence_id': 'occ',
      'target_source': 'five_k',
      'target_review_hash': 'a' * 64,
    },
  ]) {
    test(
      'fixed-start named arguments remain exact: ${input.keys.join(',')}',
      () async {
        final capture = await CaptureRpc.open();
        addTearDown(() => capture.server.close(force: true));
        final c = capture.client();
        addTearDown(c.dispose);
        final result = await ProgrammeTrainingSessionStartSupabaseStore(
          client: c,
        ).createOrResume(input);
        expect(result['code'], 'running_target_review_required');
        expect(capture.body, {
          'p_occurrence_id': 'occ',
          if (input.containsKey('target_source'))
            'p_running_target_source': input['target_source'],
          if (input.containsKey('target_source') ||
              input.containsKey('target_review_hash'))
            'p_target_review_hash': input['target_review_hash'],
        });
      },
    );
  }
}
