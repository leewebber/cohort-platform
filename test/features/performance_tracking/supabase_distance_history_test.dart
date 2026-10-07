import 'dart:convert';
import 'dart:io';

import 'package:cohort_platform/features/auth/models/user_profile.dart';
import 'package:cohort_platform/features/auth/services/current_user_session.dart';
import 'package:cohort_platform/features/performance_tracking/supabase_distance_history.dart';
import 'package:cohort_platform/internal_review/athlete_distance/synthetic_distance_history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  tearDown(CurrentUserSession.clear);
  test(
    'actual athlete composition reads owner-filtered metadata and independent RPC only',
    () async {
      final source = SyntheticDistanceHistory();
      addTearDown(source.changes.close);
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final calls = <String>[];
      server.listen((request) async {
        calls.add(request.uri.path);
        Object response;
        if (request.uri.path == '/rest/v1/training_session_records') {
          expect(request.method, 'GET');
          expect(
            request.uri.queryParameters['athlete_id'],
            'eq.$syntheticDistanceActor',
          );
          expect(
            request.uri.queryParameters['select'],
            'record_id,athlete_id,started_at,performed_on,performed_precision,status,session_name:session_snapshot->>sessionTitle',
          );
          expect(request.uri.queryParameters['limit'], '25');
          response = [
            for (final wire in source.envelopes.values)
              {
                ...wire['record'] as Map,
                'session_name':
                    ((wire['record'] as Map)['session_snapshot']
                        as Map)['sessionTitle'],
              },
          ];
        } else if (request.uri.path ==
            '/rest/v1/rpc/read_performance_tracking_history_v1') {
          expect(request.method, 'POST');
          final body =
              jsonDecode(await utf8.decoder.bind(request).join()) as Map;
          expect(body['p_programme_claim'], isNull);
          response = source.envelopes[body['p_record_id']]!;
        } else {
          throw StateError('Unexpected local read path');
        }
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(response));
        await request.response.close();
      });
      final client = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'synthetic-only',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(client.dispose);
      Future<void> bind(String id, {bool athlete = true}) async {
        CurrentUserSession.bind(
          UserProfile(
            id: id,
            displayName: 'Synthetic',
            isCoach: !athlete,
            isAthlete: athlete,
          ),
        );
        final payload = base64Url
            .encode(utf8.encode(jsonEncode({'exp': 4102444800})))
            .replaceAll('=', '');
        await client.auth.setInitialSession(
          jsonEncode(
            Session(
              accessToken: 'e30.$payload.synthetic',
              tokenType: 'bearer',
              user: User(
                id: id,
                appMetadata: const {},
                userMetadata: const {},
                aud: 'authenticated',
                createdAt: '2026-01-01T00:00:00Z',
              ),
            ).toJson(),
          ),
        );
        await Future<void>.delayed(Duration.zero);
      }

      await bind(syntheticDistanceActor);
      final c = createDistanceHistoryController(client);
      addTearDown(c.dispose);
      await Future<void>.delayed(Duration.zero);
      await c.loadPage();
      expect(c.page.first.date, '2026-09-01');
      expect(c.page.first.displayName, 'Synthetic distance session');
      await c.toggleRecord(c.page[0]);
      await c.toggleRecord(c.page[1]);
      await c.selectBlock(c.views[0].summary.id, c.views[0].candidates[1]);
      await c.selectBlock(c.views[1].summary.id, c.views[1].candidates[0]);
      c.compare();
      expect(c.evaluation!.isFailure, isFalse);
      expect(
        (c.evaluation!.content['comparisons'] as List).single['state'],
        'comparable',
      );
      expect(calls, [
        '/rest/v1/training_session_records',
        '/rest/v1/rpc/read_performance_tracking_history_v1',
        '/rest/v1/rpc/read_performance_tracking_history_v1',
      ]);
      await bind(syntheticDistanceId(2));
      expect(c.evaluation, isNull);
      expect(c.views, isEmpty);
      await bind(syntheticDistanceActor, athlete: false);
      await c.loadPage();
      expect(c.page, isEmpty);
      expect(calls, hasLength(3));
    },
  );
  test('anonymous composition cannot begin metadata or source reads', () async {
    final client = SupabaseClient(
      'http://127.0.0.1:1',
      'synthetic-only',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(client.dispose);
    final c = createDistanceHistoryController(client);
    addTearDown(c.dispose);
    await c.loadPage();
    expect(c.identityValid, isFalse);
    expect(c.page, isEmpty);
  });
}
