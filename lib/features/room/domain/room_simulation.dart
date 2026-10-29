import 'dart:math' as math;
import 'dart:ui' show Offset;

import '../../cat/domain/cat_mood.dart';
import '../../cat/domain/cat_status.dart';
import '../../rooms/domain/like.dart';
import 'cat_action.dart';
import 'room_cat.dart';
import 'room_layout.dart';
import 'room_route.dart';

/// Where a cat is, what it is doing, and what it is on its way to do.
class CatState {
  const CatState({
    required this.catId,
    required this.mood,
    required this.status,
    required this.position,
    required this.facing,
    required this.action,
    required this.actionSecondsLeft,
    this.actionElapsed = 0,
    this.spotId,
    this.route,
    this.legIndex = 0,
    this.travelled = 0,
  });

  /// Matches [RoomCat.id].
  final String catId;

  /// Copied from the cat when the room was built. A change in mood builds a
  /// fresh room.
  final CatMood mood;

  /// Copied from the cat when the room was built, like [mood].
  final CatStatus status;

  /// Where the cat's feet are, as fractions of the room.
  final Offset position;

  /// Which way the cat looks.
  final CatFacing facing;

  /// What the cat is doing now. Travel counts as doing: climbing shows as
  /// climbing.
  final CatAction action;

  /// Seconds until the planner picks something new. Infinity in reduced-motion
  /// mode, where nothing ever changes. Not counted down while the cat is
  /// travelling.
  final double actionSecondsLeft;

  /// How long the cat has been doing the current action. This is the clock the
  /// animation reads, so a sprite frame follows the action, not the room.
  final double actionElapsed;

  /// The spot this cat is on or heading for.
  final String? spotId;

  /// The trip in progress, or null when the cat is staying put.
  final RoomRoute? route;

  /// Which leg of [route] the cat is on.
  final int legIndex;

  /// How far along the current leg, in room units.
  final double travelled;

  /// True while a route is being followed.
  bool get isTravelling => route != null;

  /// A copy with some fields changed.
  ///
  /// A null argument keeps the current value, so the two `clear` flags exist to
  /// set [spotId] or [route] back to null: [clearSpot] and [clearRoute] win
  /// over a value passed alongside them. [catId], [mood] and [status] never
  /// change.
  CatState copyWith({
    Offset? position,
    CatFacing? facing,
    CatAction? action,
    double? actionSecondsLeft,
    double? actionElapsed,
    String? spotId,
    bool clearSpot = false,
    RoomRoute? route,
    bool clearRoute = false,
    int? legIndex,
    double? travelled,
  }) {
    return CatState(
      catId: catId,
      mood: mood,
      status: status,
      position: position ?? this.position,
      facing: facing ?? this.facing,
      action: action ?? this.action,
      actionSecondsLeft: actionSecondsLeft ?? this.actionSecondsLeft,
      actionElapsed: actionElapsed ?? this.actionElapsed,
      spotId: clearSpot ? null : (spotId ?? this.spotId),
      route: clearRoute ? null : (route ?? this.route),
      legIndex: legIndex ?? this.legIndex,
      travelled: travelled ?? this.travelled,
    );
  }
}

/// How likely each action is, by mood. Mood colours the room; it never overrides
/// the day's rules.
Map<CatAction, double> moodWeights(CatMood mood) => switch (mood) {
  CatMood.happy => {
    CatAction.walk: 5,
    CatAction.groom: 1,
    CatAction.sit: 1,
    CatAction.sleep: 1,
    CatAction.perch: 2,
    CatAction.play: 4,
    CatAction.idle: 1,
  },
  CatMood.neutral => {
    CatAction.walk: 2,
    CatAction.sit: 3,
    CatAction.sleep: 2,
    CatAction.groom: 2,
    CatAction.perch: 1,
    CatAction.play: 1.5,
    CatAction.idle: 2,
  },
  CatMood.sad => {
    CatAction.walk: 1,
    CatAction.sit: 3,
    CatAction.sleep: 3,
    CatAction.groom: 1,
    CatAction.perch: 0.5,
    CatAction.play: 0.3,
    CatAction.idle: 2,
  },
};

/// The room's mind: who goes where, on a seeded dice roll.
///
/// Deterministic on purpose. Same cats, same seed, same time in means the same
/// room out, so the behaviour can be tested without a screen.
class RoomSimulation {
  /// Builds the room and places every cat that is at home.
  ///
  /// A runaway cat is left out. [seed] fixes the dice rolls. With
  /// [reducedMotion] cats are put on a calm spot and never move. Each action
  /// lasts a random [minActionSeconds] to [maxActionSeconds].
  RoomSimulation({
    required this.layout,
    required List<RoomCat> cats,
    int seed = 1,
    this.reducedMotion = false,
    this.minActionSeconds = 3,
    this.maxActionSeconds = 9,
  }) : _random = math.Random(seed),
       _likes = {for (final cat in cats) cat.id: cat.likes} {
    final home = [
      for (final cat in cats)
        if (cat.isHome) cat,
    ];
    _states = reducedMotion ? _staticPlacement(home) : _spreadOnFloor(home);
  }

  /// The room the cats live in.
  final RoomLayout layout;

  /// When true the room is static: cats are placed once and never move, for
  /// people who turned on Reduce Motion.
  final bool reducedMotion;

  /// Shortest time, in seconds, a cat keeps doing one thing.
  final double minActionSeconds;

  /// Longest time, in seconds, a cat keeps doing one thing. Each duration is
  /// random between the two.
  final double maxActionSeconds;

  /// The only source of randomness, seeded, which keeps the room repeatable in
  /// tests.
  final math.Random _random;

  /// What each cat likes, by cat id.
  final Map<String, Set<Like>> _likes;

  /// Spot id to the ids of cats on it or heading there. This is what enforces
  /// [RoomSpot.capacity].
  final Map<String, Set<String>> _occupants = {};

  /// One state per cat at home, replaced on every [step].
  late List<CatState> _states;

  /// A read-only snapshot of every cat's current state.
  List<CatState> get states => List.unmodifiable(_states);

  /// Who is on a spot right now, including cats on their way there.
  Set<String> occupantsOf(String spotId) =>
      Set.unmodifiable(_occupants[spotId] ?? const <String>{});

  /// True when [spot] still has space for [catId]; the cat's own claim does not
  /// count against it.
  bool _hasRoomFor(RoomSpot spot, String catId) {
    final taken = _occupants[spot.id] ?? const <String>{};
    return taken.where((id) => id != catId).length < spot.capacity;
  }

  /// Marks [spotId] as taken by [catId], before the cat has even arrived, so
  /// two cats cannot head for the same basket.
  void _claim(String spotId, String catId) {
    (_occupants[spotId] ??= <String>{}).add(catId);
  }

  /// Frees every spot [catId] holds.
  void _release(String catId) {
    for (final taken in _occupants.values) {
      taken.remove(catId);
    }
  }

  /// Starting positions when motion is on: cats stand idle along the walk line,
  /// evenly spaced (a lone cat starts in the middle).
  List<CatState> _spreadOnFloor(List<RoomCat> cats) {
    if (cats.isEmpty) return const [];
    final span = layout.walkRight - layout.walkLeft;
    final states = <CatState>[];
    for (var i = 0; i < cats.length; i++) {
      final x = cats.length == 1
          ? (layout.walkLeft + layout.walkRight) / 2
          : layout.walkLeft + span * (i / (cats.length - 1));
      states.add(
        CatState(
          catId: cats[i].id,
          mood: cats[i].mood,
          status: cats[i].status,
          position: Offset(x, layout.walkY),
          facing: CatFacing.right,
          action: CatAction.idle,
          actionSecondsLeft: _nextDuration(),
        ),
      );
    }
    return states;
  }

  /// Reduced motion: no ticker, no travel. Everyone is put somewhere and stays.
  List<CatState> _staticPlacement(List<RoomCat> cats) {
    final states = <CatState>[];
    for (final cat in cats) {
      final spot = _freeSpotFor(cat.id, const {
        CatAction.sleep,
        CatAction.perch,
        CatAction.sit,
      });
      final action = spot == null ? CatAction.sit : _staticAction(spot);
      if (spot != null) _claim(spot.id, cat.id);
      states.add(
        CatState(
          catId: cat.id,
          mood: cat.mood,
          status: cat.status,
          position:
              spot?.position ?? Offset(_staticX(states.length), layout.walkY),
          facing: CatFacing.right,
          action: action,
          actionSecondsLeft: double.infinity,
          spotId: spot?.id,
        ),
      );
    }
    return states;
  }

  /// Floor position for the [index]th cat without a spot in reduced motion: a
  /// quarter of the room apart, kept on the walk line.
  double _staticX(int index) =>
      (layout.walkLeft + 0.25 * index).clamp(layout.walkLeft, layout.walkRight);

  /// The calmest thing this spot is for: sleep beats perch beats sitting.
  CatAction _staticAction(RoomSpot spot) {
    if (spot.allowsAction(CatAction.sleep)) return CatAction.sleep;
    if (spot.allowsAction(CatAction.perch)) return CatAction.perch;
    if (spot.allowsAction(CatAction.sit)) return CatAction.sit;
    return spot.allows.first;
  }

  /// A random time, in seconds, between [minActionSeconds] and
  /// [maxActionSeconds].
  double _nextDuration() =>
      minActionSeconds +
      _random.nextDouble() * (maxActionSeconds - minActionSeconds);

  /// One tick. [seconds] of room time.
  void step(double seconds) {
    if (reducedMotion || seconds <= 0) return;
    final next = <CatState>[];
    for (final state in _states) {
      next.add(_stepCat(state, seconds));
    }
    _states = next;
  }

  /// Advances one cat by [seconds]: follow its route if it has one, else count
  /// down the current action, else plan the next.
  CatState _stepCat(CatState state, double seconds) {
    final route = state.route;
    if (route != null) {
      final step = advanceRoute(
        route: route,
        legIndex: state.legIndex,
        travelled: state.travelled,
        seconds: seconds,
        facing: state.facing,
      );
      if (!step.arrived) {
        final nextAction = step.action ?? state.action;
        return state.copyWith(
          position: step.position,
          facing: step.facing,
          legIndex: step.legIndex,
          travelled: step.travelled,
          action: nextAction,
          // A new action starts its animation from the beginning.
          actionElapsed: nextAction == state.action
              ? state.actionElapsed + seconds
              : 0,
        );
      }
      return state.copyWith(
        position: step.position,
        facing: step.facing,
        action: route.arrivalAction,
        actionSecondsLeft: _nextDuration(),
        actionElapsed: 0,
        clearRoute: true,
        legIndex: 0,
        travelled: 0,
      );
    }

    final left = state.actionSecondsLeft - seconds;
    if (left > 0) {
      return state.copyWith(
        actionSecondsLeft: left,
        actionElapsed: state.actionElapsed + seconds,
      );
    }
    return _planNext(state);
  }

  /// Chooses what a cat does next and the way to get there.
  CatState _planNext(CatState state) {
    final weights = Map<CatAction, double>.from(moodWeights(state.mood));
    if (state.status == CatStatus.neglected) {
      weights[CatAction.sleep] = (weights[CatAction.sleep] ?? 0) * 1.5;
      weights[CatAction.walk] = 0;
    }

    // Keep only what the room can offer this cat right now.
    final choices = <CatAction, double>{};
    for (final entry in weights.entries) {
      if (entry.value <= 0) continue;
      if (CatAction.onFloor.contains(entry.key)) {
        choices[entry.key] = entry.value;
      } else if (_freeSpotFor(state.catId, {entry.key}) != null) {
        choices[entry.key] = entry.value;
      }
    }
    if (choices.isEmpty) {
      choices[CatAction.sit] = 1;
    }

    final action = _weightedPick(choices);
    _release(state.catId);

    // A spot that suits the action beats doing it on the bare floor, so a cat
    // that sits tends to sit on the rug. Walk and idle have no spot, and stay
    // on the floor.
    final spot = _freeSpotFor(state.catId, {action});
    if (spot != null) _claim(spot.id, state.catId);

    final route = routeTo(
      layout: layout,
      from: state.position,
      arrivalAction: action,
      floorX: _randomWalkX(),
      spotId: spot?.id,
      fromIsHigh: _isOnHighSpot(state),
      facingRight: state.facing == CatFacing.right,
    );

    if (route.isEmpty) {
      return state.copyWith(
        action: action,
        actionSecondsLeft: _nextDuration(),
        spotId: spot?.id,
        clearSpot: spot == null,
        clearRoute: true,
        legIndex: 0,
        travelled: 0,
      );
    }

    return state.copyWith(
      action: route.legs.first.action,
      actionSecondsLeft: _nextDuration(),
      spotId: spot?.id,
      clearSpot: spot == null,
      route: route,
      legIndex: 0,
      travelled: 0,
    );
  }

  /// True when the cat is on, or heading for, a high spot, so its route starts
  /// with a climb down.
  bool _isOnHighSpot(CatState state) {
    final current = state.spotId;
    if (current == null) return false;
    return layout.spot(current)?.isHigh ?? false;
  }

  /// A random spot that allows any of [actions] and has room for [catId], or
  /// null if there is none.
  RoomSpot? _freeSpotFor(String catId, Set<CatAction> actions) {
    final open = [
      for (final spot in layout.spots)
        if (spot.allows.any(actions.contains) && _hasRoomFor(spot, catId)) spot,
    ];
    if (open.isEmpty) return null;
    final likes = _likes[catId] ?? const <Like>{};
    final liked = [
      for (final spot in open)
        if (spot.likes.any(likes.contains)) spot,
    ];
    // Without a liked spot the dice roll as before, so a room stays the same.
    if (liked.isEmpty || liked.length == open.length) {
      return open[_random.nextInt(open.length)];
    }
    // A spot that gives what the cat likes is chosen twice as often.
    final roll = _random.nextInt(open.length + liked.length);
    return roll < open.length ? open[roll] : liked[roll - open.length];
  }

  /// A random point on the walk line, as a fraction of the room's width.
  double _randomWalkX() {
    final span = layout.walkRight - layout.walkLeft;
    return layout.walkLeft + _random.nextDouble() * span;
  }

  /// Picks one action at random, in proportion to its weight. Rolls against the
  /// running total; the last key is the safety net.
  CatAction _weightedPick(Map<CatAction, double> weights) {
    var total = 0.0;
    for (final value in weights.values) {
      total += value;
    }
    var roll = _random.nextDouble() * total;
    for (final entry in weights.entries) {
      roll -= entry.value;
      if (roll <= 0) return entry.key;
    }
    return weights.keys.last;
  }
}
