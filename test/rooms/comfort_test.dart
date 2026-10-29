import 'package:catwalk/features/cat/domain/cat.dart';
import 'package:catwalk/features/cat/domain/cat_appearance.dart';
import 'package:catwalk/features/cat/domain/cat_mood.dart';
import 'package:catwalk/features/cat/domain/cat_status.dart';
import 'package:catwalk/features/room/domain/cat_action.dart';
import 'package:catwalk/features/room/domain/room_cat.dart';
import 'package:catwalk/features/room/domain/room_layout.dart';
import 'package:catwalk/features/room/domain/room_simulation.dart';
import 'package:catwalk/features/room/presentation/cat_details_sheet.dart';
import 'package:catwalk/features/rooms/domain/comfort.dart';
import 'package:catwalk/features/rooms/domain/like.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Cat catWith({
  List<Like> likes = const [Like.sun, Like.quiet],
  CatMood mood = CatMood.neutral,
  CatStatus status = CatStatus.active,
  int missed = 0,
}) => Cat(
  id: '1',
  name: 'Cat 1',
  appearance: CatAppearance.ginger,
  mood: mood,
  status: status,
  consecutiveMissedDays: missed,
  createdAt: DateTime(2026, 10, 1),
  likes: likes,
);

void main() {
  sheetTests();
  group('comfort', () {
    test('counts the likes a room gives: 0, 1 or 2 hearts', () {
      final cat = catWith();
      expect(comfortOf(cat, {Like.food}), Comfort.meh);
      expect(comfortOf(cat, {Like.sun, Like.food}), Comfort.comfy);
      expect(comfortOf(cat, {Like.sun, Like.quiet}), Comfort.veryComfy);
      expect(Comfort.veryComfy.hearts, 2);
      expect(likesMet(cat, {Like.quiet}), {Like.quiet});
    });

    test('only a very comfy cat looks milder, and never happy', () {
      final sad = catWith(mood: CatMood.sad, missed: 1);
      final neglected = catWith(
        mood: CatMood.sad,
        status: CatStatus.neglected,
        missed: 2,
      );
      for (final c in [Comfort.meh, Comfort.comfy]) {
        expect(displayMoodOf(sad, c).mood, CatMood.sad);
        expect(displayMoodOf(neglected, c).status, CatStatus.neglected);
      }
      expect(displayMoodOf(sad, Comfort.veryComfy).mood, CatMood.neutral);
      final n = displayMoodOf(neglected, Comfort.veryComfy);
      expect(n.mood, CatMood.sad);
      expect(n.status, CatStatus.active);
      expect(displayMoodOf(catWith(), Comfort.veryComfy).mood, CatMood.neutral);
      expect(
        displayMoodOf(catWith(mood: CatMood.happy), Comfort.veryComfy).mood,
        CatMood.happy,
      );
    });

    test('a runaway cat is untouched, and the saved cat is never changed', () {
      final gone = catWith(
        mood: CatMood.sad,
        status: CatStatus.runaway,
        missed: 3,
      );
      expect(displayMoodOf(gone, Comfort.veryComfy).status, CatStatus.runaway);
      final sad = catWith(mood: CatMood.sad, missed: 1);
      displayMoodOf(sad, Comfort.veryComfy);
      expect(sad.mood, CatMood.sad);
      expect(sad.consecutiveMissedDays, 1);
    });

    test('RoomCat shows the comfort-aware mood but keeps the real cat', () {
      final sad = catWith(mood: CatMood.sad, missed: 1);
      final shown = displayMoodOf(sad, Comfort.veryComfy);
      final room = RoomCat(
        sad,
        comfort: Comfort.veryComfy,
        shownMood: shown.mood,
        shownStatus: shown.status,
      );
      expect(room.mood, CatMood.neutral);
      expect(room.cat.mood, CatMood.sad);
      expect(RoomCat(sad).mood, CatMood.sad);
    });
  });

  group('likes in the room', () {
    const spots = [
      RoomSpot(
        id: 'sun',
        position: Offset(0.2, 0.3),
        allows: {CatAction.perch},
        label: 'sunny',
        isHigh: true,
        likes: {Like.sun},
      ),
      RoomSpot(
        id: 'dull',
        position: Offset(0.8, 0.3),
        allows: {CatAction.perch},
        label: 'dull',
        isHigh: true,
      ),
    ];

    double sunShare(List<Like> likes) {
      var sun = 0;
      var total = 0;
      for (var seed = 1; seed <= 40; seed++) {
        final sim = RoomSimulation(
          layout: const RoomLayout(spots: spots),
          cats: [RoomCat(catWith(likes: likes))],
          seed: seed,
        );
        for (var i = 0; i < 3000; i++) {
          sim.step(0.1);
          final id = sim.states.single.spotId;
          if (sim.states.single.action == CatAction.perch && id != null) {
            total++;
            if (id == 'sun') sun++;
          }
        }
      }
      expect(total, greaterThan(200));
      return sun / total;
    }

    test('a cat that likes the sun perches in the sun more often', () {
      final fond = sunShare([Like.sun, Like.quiet]);
      final plain = sunShare([Like.food, Like.quiet]);
      expect(fond, greaterThan(plain * 1.2));
      expect(plain, closeTo(0.5, 0.12));
    });
  });

  group('the sentence on the sheet', () {
    test('says what the cat likes and what the room has', () {
      final cat = catWith();
      expect(
        likesLine(RoomCat(cat, likesMet: {Like.sun})),
        'Likes sun and quiet. The living room has sun.',
      );
      expect(
        likesLine(RoomCat(cat, likesMet: {Like.sun, Like.quiet})),
        'Likes sun and quiet. The living room has both.',
      );
      expect(
        likesLine(RoomCat(cat)),
        'Likes sun and quiet. The living room has none of it.',
      );
    });
  });
}

class _Opener extends StatelessWidget {
  const _Opener(this.cat);
  final RoomCat cat;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: TextButton(
      onPressed: () => CatDetailsSheet.show(context, cat),
      child: const Text('open'),
    ),
  );
}

void sheetTests() {
  Future<void> openSheet(WidgetTester tester, RoomCat cat) async {
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp(home: _Opener(cat))),
    );
    await tester.tap(find.text('open'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('the cat sheet shows two like chips and the hearts', (
    tester,
  ) async {
    await openSheet(
      tester,
      RoomCat(catWith(), comfort: Comfort.comfy, likesMet: const {Like.sun}),
    );
    expect(find.byKey(const Key('like-sun')), findsOneWidget);
    expect(find.byKey(const Key('like-quiet')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('comfort-hearts')),
        matching: find.byIcon(Icons.favorite),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('comfort-hearts')),
        matching: find.byIcon(Icons.favorite_border),
      ),
      findsOneWidget,
    );
    expect(
      find.text('Likes sun and quiet. The living room has sun.'),
      findsOneWidget,
    );
  });
}
