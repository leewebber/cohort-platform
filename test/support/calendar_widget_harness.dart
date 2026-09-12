import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> revealCalendarFinder(WidgetTester tester, Finder finder) async {
  final list = find.byKey(const ValueKey('calendar-month-grid-scroll'));
  for (var attempt = 0; attempt < 12; attempt++) {
    await tester.pump();
    final box = tester.renderObject(finder) as RenderBox;
    final center = box.localToGlobal(box.size.center(Offset.zero));
    if (center.dy >= 24 && center.dy <= 800) {
      return;
    }
    await tester.drag(list, Offset(0, center.dy > 800 ? -240 : 240));
    await tester.pumpAndSettle();
  }
  fail('$finder was not brought into the visible calendar viewport');
}

Future<void> tapCalendarFinder(WidgetTester tester, Finder finder) async {
  await revealCalendarFinder(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
