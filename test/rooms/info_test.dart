import 'package:catwalk/features/rooms/presentation/info_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../shop_home_test.dart' show newPlayer, open;

Future<void> frames(WidgetTester tester, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  testWidgets('the guide on the Cats tab explains every part', (tester) async {
    final store = await newPlayer();
    await open(tester, store, 1000);
    await tester.tap(find.text('Cats'));
    await frames(tester);
    await tester.tap(find.byKey(const Key('house-guide-button')));
    await frames(tester);
    expect(find.byKey(const Key('house-guide')), findsOneWidget);
    expect(find.text('How the house works'), findsOneWidget);
    expect(
      HouseGuide.parts.map((p) => p.$1),
      containsAll([
        'Rooms and cats',
        'Editing a room',
        'Likes and hearts',
        'Mood',
        'Gifts',
        'Wishes',
      ]),
    );
  });

  testWidgets('the item sheet says where the nicer items come from', (
    tester,
  ) async {
    final store = await newPlayer();
    await open(tester, store, 1000);
    await tester.tap(find.text('Cats'));
    await frames(tester);
    await tester.tap(find.byKey(const Key('edit-room')));
    await frames(tester);
    await tester.tap(find.byKey(const Key('slot-climb')));
    await frames(tester);
    expect(find.byKey(const Key('slot-help')), findsOneWidget);
  });

  testWidgets('an info button opens its explanation', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InfoButton(title: 'Hello', body: 'World'),
        ),
      ),
    );
    await tester.tap(find.byType(IconButton));
    await frames(tester);
    expect(find.byKey(const Key('info-sheet')), findsOneWidget);
    expect(find.text('World'), findsOneWidget);
  });
}
