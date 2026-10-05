import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:esca_home/main.dart';

void main() {
  testWidgets('dashboard shows its sections and toggles a device',
      (WidgetTester tester) async {
    await tester.pumpWidget(const EscaHomeApp());

    expect(find.text('ESCA Home'), findsOneWidget);
    expect(find.text('Thiết bị'), findsOneWidget);
    expect(find.text('Thông tin runtime'), findsOneWidget);

    // The ceiling light starts on, the air conditioner starts off.
    final acSwitch = find.ancestor(
      of: find.text('Điều hoà'),
      matching: find.byType(Card),
    );
    expect(acSwitch, findsOneWidget);

    final switchFinder = find.descendant(of: acSwitch, matching: find.byType(Switch));
    expect(tester.widget<Switch>(switchFinder).value, isFalse);

    await tester.tap(switchFinder);
    await tester.pump();

    expect(tester.widget<Switch>(switchFinder).value, isTrue);
  });
}
