import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production entry does not import same-day Home preview', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, isNot(contains('main_same_day_home_preview')));
    expect(main, isNot(contains('SameDayHomePreviewApp')));
  });
}
