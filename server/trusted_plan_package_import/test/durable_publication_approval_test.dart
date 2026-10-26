import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:trusted_plan_package_import/trusted_plan_package_import.dart';

class NoPublication implements V3PublicationAuthority {
  @override
  Future<Map<String, Object?>> resolveCanonicalSource(String _) async =>
      throw StateError('must not publish');
  @override
  Future<Map<String, Object?>> publishPrivateVersion(
    Map<String, Object?> _,
  ) async => throw StateError('must not publish');
}

void main() {
  final base = {
    'SUPABASE_URL': 'http://127.0.0.1:9',
    'SUPABASE_ANON_KEY': 'anon',
    'SUPABASE_SERVICE_ROLE_KEY': 'service',
    'FOUNDER_EMAIL_ALLOWLIST': 'founder@example.invalid',
  };
  test(
    'approval/store default disabled without external service prerequisite',
    () {
      final off = TrustedImportServerConfig.fromEnvironment(base);
      expect(off.approvalsEnabled, false);
      expect(off.eventDeliveryCredential, isNull);
      final on = TrustedImportServerConfig.fromEnvironment({
        ...base,
        'PUBLICATION_EVENT_SOURCE_MODE': 'internal_store',
        'PUBLICATION_APPROVAL_ENABLED': 'true',
        'PUBLICATION_APPROVAL_WRITER_TOKEN': 'writer',
        'PUBLICATION_EVENT_DELIVERY_TOKEN': 'delivery',
      });
      expect(on.approvalsEnabled, true);
      expect(on.publicationEventsUrl, isNull);
      expect(on.exerciseProducerCredential, isNull);
    },
  );
  test('internal delivery can opt in without external URL or source token', () {
    final c = TrustedImportServerConfig.fromEnvironment({
      ...base,
      'TRUSTED_V3_PUBLICATION_ENABLED': 'true',
      'PUBLICATION_EVENT_SOURCE_MODE': 'internal_store',
      'PUBLICATION_EVENT_DELIVERY_TOKEN': 'delivery',
      'EXERCISE_VERSION_PRODUCER_TOKEN': 'retention',
    });
    expect(c.publicationEventsUrl, isNull);
    expect(c.approvalWriterCredential, isNull);
    expect(c.eventDeliveryCredential, 'delivery');
  });
  test(
    'approval/delivery/retention credentials must be distinct narrow capabilities',
    () {
      for (final key in ['service', 'anon', 'delivery', 'retention']) {
        expect(
          () => TrustedImportServerConfig.fromEnvironment({
            ...base,
            'TRUSTED_V3_PUBLICATION_ENABLED': 'true',
            'PUBLICATION_EVENT_SOURCE_MODE': 'internal_store',
            'PUBLICATION_APPROVAL_ENABLED': 'true',
            'PUBLICATION_EVENT_DELIVERY_TOKEN': 'delivery',
            'PUBLICATION_APPROVAL_WRITER_TOKEN': key,
            'EXERCISE_VERSION_PRODUCER_TOKEN': 'retention',
          }),
          throwsStateError,
        );
      }
    },
  );
  test('partial approval opt-in and unknown modes fail startup', () {
    for (final extra in [
      {'PUBLICATION_APPROVAL_ENABLED': 'true'},
      {'PUBLICATION_EVENT_SOURCE_MODE': 'invented'},
      {'PUBLICATION_APPROVAL_ENABLED': 'yes'},
    ]) {
      expect(
        () => TrustedImportServerConfig.fromEnvironment({...base, ...extra}),
        throwsStateError,
      );
    }
  });
  test(
    'store uses writer only for approvals and delivery only for claims',
    () async {
      final calls = <String>[];
      final c = MockClient((r) async {
        calls.add('${r.url.path}:${r.headers['authorization']}');
        expect(r.followRedirects, false);
        return http.Response('{}', 200);
      });
      final s = SupabasePublicationApprovalStore(
        supabaseUrl: Uri.parse('http://127.0.0.1:9'),
        anonKey: 'anon',
        writerCredential: 'writer',
        deliveryCredential: 'delivery',
        client: c,
      );
      await s.approve('actor', 'event', 'digest');
      await s.claim('actor', 'event');
      expect(
        calls,
        contains('/rest/v1/rpc/approve_publication_event_v1:Bearer writer'),
      );
      expect(
        calls,
        contains('/rest/v1/rpc/claim_publication_delivery_v1:Bearer delivery'),
      );
      c.close();
    },
  );
  test('store never exposes SQL errors or follows redirects', () async {
    for (final code in [302, 400, 403, 409, 500]) {
      final c = MockClient(
        (r) async => http.Response('PRIVATE_SQL_AND_CREDENTIAL_DETAILS', code),
      );
      final s = SupabasePublicationApprovalStore(
        supabaseUrl: Uri.parse('http://127.0.0.1:9'),
        anonKey: 'anon',
        writerCredential: 'writer',
        deliveryCredential: 'delivery',
        client: c,
      );
      await expectLater(
        s.claim('a', 'e'),
        throwsA(
          isA<PublicationBoundaryException>().having(
            (e) => e.code,
            'safe code',
            isNot(contains('PRIVATE')),
          ),
        ),
      );
      c.close();
    }
  });
  test('unknown approval routes never become v3 receiver routes', () {
    expect(
      DurablePublicationApprovalEndpoint.handles(
        'v1/founder/publication-approvals/approve',
      ),
      true,
    );
    expect(
      DurablePublicationApprovalEndpoint.handles(
        'v1/founder/publication-approvals/invented',
      ),
      false,
    );
    expect(
      DurablePublicationApprovalEndpoint.handles(
        TrustedV3PublicationEndpoint.exerciseRoute,
      ),
      false,
    );
  });
  test(
    'Founder verification happens before body read on approval route',
    () async {
      var read = false;
      final client = MockClient((_) async => http.Response('{}', 401));
      final founder = TrustedV3FounderPublication(
        auth: SupabaseAuthTokenVerifier(
          supabaseUrl: Uri.parse('http://127.0.0.1:9'),
          anonKey: 'anon',
          client: client,
        ),
        founder: AllowlistedFounderAuthority({'founder@example.invalid'}),
        publication: AuthoritativeV3Publication(NoPublication()),
      );
      final e = DurablePublicationApprovalEndpoint(founder: founder);
      final r = await e.call(
        Request(
          'POST',
          Uri.parse(
            'http://localhost/${DurablePublicationApprovalEndpoint.prefix}approve',
          ),
          headers: {'authorization': 'Bearer invalid'},
          body: Stream<List<int>>.fromIterable([utf8.encode('secret')]).map((
            v,
          ) {
            read = true;
            return v;
          }),
        ),
      );
      expect(r.statusCode, 401);
      expect(read, false);
      client.close();
    },
  );
}
