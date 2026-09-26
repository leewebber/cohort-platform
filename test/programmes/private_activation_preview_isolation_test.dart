import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production entry does not import the private activation preview', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, isNot(contains('main_private_activation_preview')));
    expect(main, isNot(contains('PrivateActivationPreviewApp')));
  });

  test('Bali approved hash is unchanged', () {
    expect(
      File('content/programmes/bali_hybrid_base/v1/package.sha256').readAsStringSync().trim(),
      'f5da4085c0ea8b4c6eec93859451db624aaa52cd4af79ca702278518ea227b5b',
    );
  });
}
