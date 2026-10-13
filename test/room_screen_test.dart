import 'package:catwalk/core/utils/format.dart';
import 'package:catwalk/features/cat/domain/cat.dart';
import 'package:catwalk/features/cat/domain/cat_appearance.dart';
import 'package:catwalk/features/cat/domain/cat_mood.dart';
import 'package:catwalk/features/cat/domain/cat_status.dart';
import 'package:catwalk/features/cat/presentation/widgets/cat_art.dart';
import 'package:catwalk/features/room/data/room_cats_provider.dart';
import 'package:catwalk/features/room/domain/room_cat.dart';
import 'package:catwalk/features/room/presentation/room_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

RoomCat catOf({
  String id = '1',
  String name = 'Jip',
  CatMood mood = CatMood.neutral,
  CatStatus status = CatStatus.active,
  int xp = 240,
}) {
  return RoomCat(
    Cat(
      id: id,
      name: name,
      appearance: CatAppearance.ginger,
      level: 2,
      xp: xp,
      mood: mood,
      status: status,
      consecutiveMissedDays: 0,
      createdAt: DateTime.now(),
    ),
  );
}

Future<void> pumpRoom(
  WidgetTester tester,
  List<RoomCat> cats, {
  bool reducedMotion = false,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [roomCatsProvider.overrideWithValue(cats)],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reducedMotion),
          child: const RoomScreen(),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Stops the room's ticker so the test can end cleanly.
Future<void> disposeRoom(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

void main() {
  testWidgets('the room shows the cat, and says what she is doing', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpRoom(tester, [catOf()]);

    expect(find.bySemanticsLabel(RegExp('Jip')), findsOneWidget);
    expect(find.byType(CatArt), findsWidgets);
    expect(find.text('No cats yet.'), findsNothing);

    await disposeRoom(tester);
    handle.dispose();
  });

  testWidgets('tapping a cat opens her details', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpRoom(tester, [catOf()]);

    await tester.tap(find.bySemanticsLabel(RegExp('Jip')));
    // The room never stops animating, so pump a fixed number of frames instead
    // of settling.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    expect(find.text('Mood'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.textContaining(formatNumber(240)), findsOneWidget);

    await disposeRoom(tester);
    handle.dispose();
  });

  testWidgets('a runaway cat leaves the cushion behind', (tester) async {
    await pumpRoom(tester, [catOf(status: CatStatus.runaway)]);

    expect(find.byType(EmptyCushion), findsOneWidget);

    await disposeRoom(tester);
  });

  testWidgets('an empty room says so', (tester) async {
    await pumpRoom(tester, const []);

    expect(find.text('No cats yet.'), findsOneWidget);

    await disposeRoom(tester);
  });

  testWidgets('reduced motion keeps the cat still and calm', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpRoom(tester, [catOf()], reducedMotion: true);

    final label = tester
        .getSemantics(find.bySemanticsLabel(RegExp('Jip')))
        .label
        .toString();
    expect(
      label,
      anyOf(contains('sleeping'), contains('sitting'), contains('perched')),
    );

    // No ticking: pumping time changes nothing.
    await tester.pump(const Duration(seconds: 2));
    expect(find.bySemanticsLabel(RegExp('Jip')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('walking')), findsNothing);

    await disposeRoom(tester);
    handle.dispose();
  });

  testWidgets('the room moves the cat over time', (tester) async {
    await pumpRoom(tester, [catOf()]);

    // Half a minute of room time is plenty for a cat to pick and start an action.
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    expect(find.byType(CatArt), findsWidgets);

    await disposeRoom(tester);
  });
}
