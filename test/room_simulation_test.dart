import 'package:catwalk/features/cat/domain/cat.dart';
import 'package:catwalk/features/cat/domain/cat_appearance.dart';
import 'package:catwalk/features/cat/domain/cat_mood.dart';
import 'package:catwalk/features/cat/domain/cat_status.dart';
import 'package:catwalk/features/room/domain/cat_action.dart';
import 'package:catwalk/features/room/domain/room_cat.dart';
import 'package:catwalk/features/room/domain/room_layout.dart';
import 'package:catwalk/features/room/domain/room_simulation.dart';
import 'package:flutter_test/flutter_test.dart';

RoomCat catOf(
  String id, {
  CatMood mood = CatMood.neutral,
  CatStatus status = CatStatus.active,
}) {
  return RoomCat(
    Cat(
      id: id,
      name: 'Cat $id',
      appearance: CatAppearance.ginger,
      level: 1,
      xp: 0,
      mood: mood,
      status: status,
      consecutiveMissedDays: 0,
      createdAt: DateTime(2026, 10, 1),
    ),
  );
}

RoomSimulation simOf(
  List<RoomCat> cats, {
  int seed = 7,
  bool reducedMotion = false,
}) {
  return RoomSimulation(
    layout: RoomLayout.standard,
    cats: cats,
    seed: seed,
    reducedMotion: reducedMotion,
  );
}

String describe(RoomSimulation sim) => [
  for (final state in sim.states)
    '${state.catId}:${state.action.name}:${state.position.dx.toStringAsFixed(4)}'
        ':${state.position.dy.toStringAsFixed(4)}:${state.facing.name}'
        ':${state.spotId}',
].join('|');

void main() {
  test('the same seed and the same time give the same room', () {
    final a = simOf([catOf('1'), catOf('2')], seed: 3);
    final b = simOf([catOf('1'), catOf('2')], seed: 3);

    for (var i = 0; i < 600; i++) {
      a.step(1 / 30);
      b.step(1 / 30);
    }

    expect(describe(a), describe(b));
  });

  test('a different seed gives a different room', () {
    final a = simOf([catOf('1')], seed: 1);
    final b = simOf([catOf('1')], seed: 99);

    for (var i = 0; i < 600; i++) {
      a.step(1 / 30);
      b.step(1 / 30);
    }

    expect(describe(a), isNot(describe(b)));
  });

  test('cats stay inside the room, whatever they do', () {
    final sim = simOf([catOf('1'), catOf('2'), catOf('3')]);

    for (var i = 0; i < 3000; i++) {
      sim.step(1 / 30);
      for (final state in sim.states) {
        expect(state.position.dx, inInclusiveRange(0.0, 1.0));
        expect(state.position.dy, inInclusiveRange(0.0, 1.0));
      }
    }
  });

  test('no spot is ever over capacity', () {
    final sim = simOf(
      [for (var i = 0; i < 6; i++) catOf('$i')],
    );

    for (var i = 0; i < 3000; i++) {
      sim.step(1 / 30);
      for (final spot in RoomLayout.standard.spots) {
        expect(
          sim.occupantsOf(spot.id).length,
          lessThanOrEqualTo(spot.capacity),
          reason: '${spot.id} at step \$i',
        );
      }
    }
  });

  test('a cat eventually arrives somewhere', () {
    final sim = simOf([catOf('1')]);
    var arrived = false;

    for (var i = 0; i < 3000 && !arrived; i++) {
      sim.step(1 / 30);
      arrived = !sim.states.first.isTravelling;
    }

    expect(arrived, isTrue);
  });

  test('mood only changes the odds, and it changes them the right way', () {
    final happy = moodWeights(CatMood.happy);
    final sad = moodWeights(CatMood.sad);

    expect(happy[CatAction.walk]!, greaterThan(sad[CatAction.walk]!));
    expect(sad[CatAction.sleep]!, greaterThan(happy[CatAction.sleep]!));
    // Every mood offers something: a cat is never left with nothing to do.
    for (final mood in CatMood.values) {
      expect(moodWeights(mood).values.where((w) => w > 0), isNotEmpty);
    }
  });

  test('a neglected cat never chooses a walk', () {
    final sim = simOf(
      [catOf('1', mood: CatMood.sad, status: CatStatus.neglected)],
      seed: 5,
    );

    for (var i = 0; i < 4000; i++) {
      sim.step(1 / 30);
      final state = sim.states.single;
      if (state.isTravelling) {
        expect(state.route!.arrivalAction, isNot(CatAction.walk));
      } else {
        expect(state.action, isNot(CatAction.walk));
      }
    }
  });

  test('reduced motion freezes the room', () {
    final sim = simOf([catOf('1'), catOf('2')], reducedMotion: true);
    final before = describe(sim);

    for (var i = 0; i < 100; i++) {
      sim.step(1 / 30);
    }

    expect(describe(sim), before);
    // And everyone is somewhere sensible, doing something calm.
    for (final state in sim.states) {
      expect(state.isTravelling, isFalse);
      expect(
        [
          CatAction.sleep,
          CatAction.perch,
          CatAction.sit,
        ],
        contains(state.action),
      );
    }
  });

  test('reduced motion still respects capacity', () {
    final sim = simOf(
      [for (var i = 0; i < 8; i++) catOf('$i')],
      reducedMotion: true,
    );

    for (final spot in RoomLayout.standard.spots) {
      expect(sim.occupantsOf(spot.id).length, lessThanOrEqualTo(spot.capacity));
    }
  });

  test('a runaway cat is not in the room', () {
    final sim = simOf([
      catOf('1'),
      catOf('2', status: CatStatus.runaway),
    ]);

    expect(sim.states.map((state) => state.catId), ['1']);
  });

  test('with no cats there is no room to run', () {
    final sim = simOf(const []);

    expect(sim.states, isEmpty);
    sim.step(1);
    expect(sim.states, isEmpty);
  });

  test('with no toys nobody ever plays', () {
    final sim = simOf([catOf('1', mood: CatMood.happy)], seed: 4);
    for (var i = 0; i < 4000; i++) {
      sim.step(1 / 30);
      expect(sim.states.single.action, isNot(CatAction.play));
    }
  });

  test('with a toy, a happy cat plays with it', () {
    final sim = RoomSimulation(
      layout: RoomLayout.standard.withToys(['ball']),
      cats: [catOf('1', mood: CatMood.happy)],
      seed: 4,
    );
    var played = false;
    for (var i = 0; i < 9000 && !played; i++) {
      sim.step(1 / 30);
      final state = sim.states.single;
      if (state.action == CatAction.play) {
        played = true;
        expect(state.spotId, 'toy_ball');
      }
    }
    expect(played, isTrue);
  });

  test('a happy cat is likelier to play than a sad one', () {
    expect(
      moodWeights(CatMood.happy)[CatAction.play]!,
      greaterThan(moodWeights(CatMood.sad)[CatAction.play]!),
    );
  });
}
