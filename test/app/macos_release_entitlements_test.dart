import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final debugProfile = File(
    'macos/Runner/DebugProfile.entitlements',
  ).readAsStringSync();
  final release = File('macos/Runner/Release.entitlements').readAsStringSync();

  test(
    'macOS Debug/Profile and Release permit outbound client connections',
    () {
      expect(
        debugProfile,
        contains('<key>com.apple.security.network.client</key>'),
      );
      expect(release, contains('<key>com.apple.security.network.client</key>'));
      expect(release, contains('<key>com.apple.security.app-sandbox</key>'));
    },
  );

  test('macOS Release keeps the narrow sandboxed client entitlement set', () {
    expect(release, isNot(contains('com.apple.security.network.server')));
    expect(release, isNot(contains('com.apple.security.files.')));
    expect(release, isNot(contains('com.apple.security.cs.allow-jit')));
  });
}
