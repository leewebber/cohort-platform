import 'dart:io';

import 'package:cohort_platform/staging_tooling/journey_d/journey_d_rebind.dart';
import 'package:flutter_test/flutter_test.dart';

/// Surgical Auth Admin 422 diagnosis: filter query + redacted error retention.
void main() {
  final root = Directory.current.path;

  test('uniqueness and verifier use GoTrue filter= not ignored email=', () {
    final dartPorts = File(
      '$root/lib/staging_tooling/journey_d/journey_d_hosted_live_ports.dart',
    ).readAsStringSync();
    final executePorts = File(
      '$root/lib/staging_tooling/journey_d/journey_d_hosted_execute_ports.dart',
    ).readAsStringSync();
    final py = File(
      '$root/tool/staging/lib/s17_journey_d_hosted_readonly.py',
    ).readAsStringSync();

    expect(dartPorts, contains('/auth/v1/admin/users?filter='));
    expect(dartPorts, isNot(contains('/auth/v1/admin/users?email=')));
    expect(executePorts, contains('/auth/v1/admin/users?filter='));
    expect(executePorts, isNot(contains('/auth/v1/admin/users?email=')));
    expect(py, contains('/auth/v1/admin/users?filter='));
    expect(py, isNot(contains('/auth/v1/admin/users?email=')));
  });

  test('auth create failure retains redacted GoTrue code/message', () {
    final detail = authCreateFailureDetail(
      422,
      '{"code":422,"error_code":"email_exists",'
      '"msg":"A user with this email address has already been registered"}',
    );
    expect(detail, startsWith('auth_create_http_422:email_exists:'));
    expect(detail.toLowerCase(), contains('already been registered'));
    expect(authCreateFailureIsEmailCollision(detail), isTrue);
  });

  test('auth create failure redacts emails and ids from Auth body', () {
    final detail = authCreateFailureDetail(
      422,
      '{"error_code":"unexpected_failure",'
      '"msg":"hook failed for user@example.invalid id '
      '11111111-1111-4111-8111-111111111111"}',
    );
    expect(detail, contains('***email***'));
    expect(detail, contains('***id***'));
    expect(detail, isNot(contains('user@example.invalid')));
    expect(detail, isNot(contains('11111111-1111-4111-8111-111111111111')));
    expect(authCreateFailureIsEmailCollision(detail), isFalse);
  });

  test('auth create failure without body keeps status-only detail', () {
    expect(authCreateFailureDetail(422, ''), 'auth_create_http_422');
    expect(authCreateFailureDetail(422, 'not-json'), 'auth_create_http_422');
  });
}
