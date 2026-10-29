import '../../rooms/domain/wishes.dart';
import '../../rooms/domain/room_constants.dart';

import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../rooms/data/home_state_repository.dart';
import '../../rooms/data/room_placement.dart';
import '../../rooms/domain/placement.dart';

import '../../../core/utils/calendar_date.dart';
import '../../../services/storage/local_store_provider.dart';
import '../../cat/data/cat_codec.dart';
import '../../cat/data/cat_repository.dart';
import '../../cat/domain/cat.dart';
import '../../cat/domain/cat_mood.dart';
import '../../cat/domain/cat_status.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../room/data/room_layout_provider.dart';
import '../../steps/presentation/home_controller.dart';
import '../../analytics/analytics_service.dart';
import '../data/arrival_repository.dart';
import '../data/photo_service.dart';
import '../data/route_service.dart';
import '../data/street_cat_repository.dart';
import '../data/inventory_repository.dart';
import '../data/lost_cat_repository.dart';
import '../data/location_service.dart';
import '../data/map_state_repository.dart';
import '../domain/arrival.dart';
import '../domain/pin_snapping.dart';
import '../domain/street_cat.dart';
import '../domain/walking_route.dart';
import '../domain/collect.dart';
import '../domain/toy_perks.dart';
import '../domain/geo.dart';
import '../domain/inventory.dart';
import '../domain/map_pin.dart';
import '../domain/reach_rule.dart';
import '../domain/recovery.dart';

/// Something that just happened on the map, shown once.
sealed class MapNotice {
  const MapNotice();
}

/// A pin was picked up; [result] says what it gave.
class PinCollected extends MapNotice {
  const PinCollected(this.result);

  /// What the pin gave, and the inventory and cat after it.
  final Collected result;
}

/// The runaway cat was found and is home again.
class CatFound extends MapNotice {
  const CatFound(this.catName);

  /// The cat's name, for the message.
  final String catName;
}

/// Everything the map screen needs to draw, in one immutable snapshot.
/// A cat reached the player and joined the room.
class CatJoined extends MapNotice {
  const CatJoined({required this.catName, required this.returning});

  /// The new cat's name.
  final String catName;

  /// True when it is a lost cat that came back.
  final bool returning;
}

/// A cat's walk wish came true.
class WalkWishDone extends MapNotice {
  /// Creates the notice.
  const WalkWishDone({required this.catName, required this.candy});

  /// The cat that wished.
  final String catName;

  /// Candy it paid.
  final int candy;
}

/// A cat's walk wish, with its place on the map.
class WalkWishSpot {
  /// Creates the spot.
  const WalkWishSpot({required this.cat, required this.wish});

  /// The cat that wished.
  final Cat cat;

  /// The wish; it has a place.
  final Wish wish;

  /// Where to walk.
  GeoPoint get point => wish.place!;

  /// What it pays.
  int get candy => walkWishCandy(wish.routeMeters ?? 0);
}

/// A street cat was photographed.
class StreetCatPhotographed extends MapNotice {
  const StreetCatPhotographed({
    required this.catName,
    required this.sightings,
    required this.ready,
    required this.hasFreePlace,
  });

  /// Its name.
  final String catName;

  /// How many photos you have of it now.
  final int sightings;

  /// True when it has seen enough of you to join.
  final bool ready;

  /// True when there is an free place for it right now.
  final bool hasFreePlace;
}

/// What happened when you tried to photograph or invite a street cat.
enum StreetCatOutcome {
  /// It worked.
  done,

  /// You are not within reach of the cat.
  notClose,

  /// You closed the camera without a photo.
  cancelled,

  /// There is no camera, or it may not be used.
  noCamera,

  /// Every place has a cat in it already.
  noPlace,
}

class MapViewState {
  const MapViewState({
    required this.access,
    required this.pins,
    required this.recovery,
    required this.runaway,
    required this.catName,
    required this.recoveryTargetMet,
    required this.recoveryStepsToGo,
    required this.recoveryDaysLeft,
    required this.inventory,
    this.arrival,
    this.fix,
    this.event,
    this.streetCat,
    this.freePlaces = 0,
    this.walkWish,
  });

  /// Whether location is allowed. Anything but granted shows the access card.
  final LocationAccess access;

  /// The latest position; null until the first reading.
  final GeoFix? fix;

  /// Today's pins you have not collected.
  final List<MapPin> pins;

  /// Where the runaway cat's search stands.
  final Recovery recovery;

  /// True while the cat has run away and is not yet home.
  final bool runaway;

  /// The cat's name, used in banner text.
  final String catName;

  /// The runaway cat's step target is met, so it can be found on the map.
  final bool recoveryTargetMet;

  /// Steps still to walk before the cat can be found. Zero when not runaway.
  final int recoveryStepsToGo;

  /// Days left in the recovery window, today included. Zero when not runaway.
  final int recoveryDaysLeft;

  /// What you hold, for example streak freezes.
  final Inventory inventory;

  /// The cat waiting on the map, once it can be seen. Null when none.
  final Arrival? arrival;

  /// Shown once, then cleared by [CatMapController.dismissEvent].
  final MapNotice? event;

  /// The street cat standing on today's map, if any.
  final StreetCatSpot? streetCat;

  /// Beds with no cat in them.
  final int freePlaces;

  /// The walk wish on the map, if a cat has one with a place.
  final WalkWishSpot? walkWish;

  /// True when location is allowed and a position is known.
  bool get hasLocation => access == LocationAccess.granted && fix != null;

  /// A copy with the given fields replaced. Pass [clearEvent] to drop the
  /// event, since null alone means "keep it".
  MapViewState copyWith({
    LocationAccess? access,
    GeoFix? fix,
    List<MapPin>? pins,
    Recovery? recovery,
    bool? runaway,
    String? catName,
    bool? recoveryTargetMet,
    int? recoveryStepsToGo,
    int? recoveryDaysLeft,
    Inventory? inventory,
    Arrival? arrival,
    bool clearArrival = false,
    MapNotice? event,
    bool clearEvent = false,
    StreetCatSpot? streetCat,
    bool clearStreetCat = false,
    int? freePlaces,
    WalkWishSpot? walkWish,
    bool clearWalkWish = false,
  }) => MapViewState(
    access: access ?? this.access,
    fix: fix ?? this.fix,
    pins: pins ?? this.pins,
    recovery: recovery ?? this.recovery,
    runaway: runaway ?? this.runaway,
    catName: catName ?? this.catName,
    recoveryTargetMet: recoveryTargetMet ?? this.recoveryTargetMet,
    recoveryStepsToGo: recoveryStepsToGo ?? this.recoveryStepsToGo,
    recoveryDaysLeft: recoveryDaysLeft ?? this.recoveryDaysLeft,
    inventory: inventory ?? this.inventory,
    arrival: clearArrival ? null : (arrival ?? this.arrival),
    event: clearEvent ? null : (event ?? this.event),
    streetCat: clearStreetCat ? null : (streetCat ?? this.streetCat),
    freePlaces: freePlaces ?? this.freePlaces,
    walkWish: clearWalkWish ? null : (walkWish ?? this.walkWish),
  );
}

/// Chooses today's street cat. Tests replace it to get one on demand.
final streetCatPickerProvider =
    Provider<
      StreetCat? Function({
        required List<StreetCat> known,
        required GeoCell cell,
        required CalendarDate date,
      })
    >((ref) => todaysStreetCat);

/// The map's state and logic, loaded when the map tab opens.
final mapControllerProvider =
    AsyncNotifierProvider<CatMapController, MapViewState>(CatMapController.new);

/// Runs the map: follows your position, spawns the day's pins, collects what
/// you walk onto, and places and finds a runaway cat.
///
/// All game rules live in the domain files; this class only wires them to
/// storage and the location stream.
class CatMapController extends AsyncNotifier<MapViewState> {
  /// The live subscription to position updates, cancelled on dispose.
  StreamSubscription<GeoFix>? _fixes;

  /// True while a position is being handled, so fixes that arrive meanwhile are
  /// skipped instead of collecting the same pin twice.
  bool _busy = false;

  /// A debug build may accept faked positions, so the simulator works. A
  /// release build never does.
  static bool get allowMocked => !kReleaseMode;

  @override
  /// Loads location access, the cat, inventory and saved map state, and takes a
  /// first position if location is allowed.
  Future<MapViewState> build() async {
    ref.onDispose(() => _fixes?.cancel());
    final location = ref.read(locationServiceProvider);
    final access = await location.access();
    final home = await ref.read(homeControllerProvider.future);
    final inventory = await ref.read(inventoryRepositoryProvider).read();
    final mapState = await ref.read(mapStateRepositoryProvider).read();

    var view = MapViewState(
      access: access,
      pins: const [],
      recovery: mapState.recovery,
      runaway: home.cat.status == CatStatus.runaway,
      catName: home.cat.name,
      recoveryTargetMet: home.recovery?.targetMet ?? false,
      recoveryStepsToGo: home.recovery?.stepsToGo ?? 0,
      recoveryDaysLeft: home.recovery?.daysLeft ?? 0,
      inventory: inventory,
    );

    // Without a usable location a waiting cat cannot be walked to, so it comes
    // straight home, as a recovered runaway does.
    final waiting = await ref.read(arrivalRepositoryProvider).read();
    final today = CalendarDate.today();
    if (waiting != null &&
        waiting.isVisibleOn(today) &&
        access != LocationAccess.granted) {
      view = view.copyWith(event: await _join(waiting));
    }

    if (access == LocationAccess.granted) {
      final fix = await location.current();
      if (fix != null) view = await _withFix(view, fix);
      _listen(location);
    }
    return view;
  }

  /// Asks for location, then starts following it.
  Future<void> requestAccess() async {
    final location = ref.read(locationServiceProvider);
    final access = await location.request();
    var view = state.requireValue.copyWith(access: access);
    if (access == LocationAccess.granted) {
      final fix = await location.current();
      if (fix != null) view = await _withFix(view, fix);
      _listen(location);
    }
    state = AsyncData(view);
  }

  /// Opens the phone's Settings page so a blocked user can allow location.
  Future<void> openSettings() =>
      ref.read(locationServiceProvider).openSettings();

  /// Clears the one-time [MapViewState.event] after its sheet was closed.
  void dismissEvent() {
    final view = state.value;
    if (view == null) return;
    state = AsyncData(view.copyWith(clearEvent: true));
  }

  /// Feeds a position in. The location stream calls this, and so do tests.
  Future<void> onFix(GeoFix fix) async {
    if (_busy) return;
    final view = state.value;
    if (view == null) return;
    _busy = true;
    try {
      state = AsyncData(await _withFix(view, fix));
    } finally {
      _busy = false;
    }
  }

  /// Starts following position updates, replacing any earlier subscription.
  void _listen(LocationService location) {
    _fixes?.cancel();
    _fixes = location.fixes().listen(onFix);
  }

  /// Applies a position: sets the day's cell, collects what you stand on, and
  /// moves the cat's recovery on.
  Future<MapViewState> _withFix(MapViewState view, GeoFix fix) async {
    final today = CalendarDate.today();
    final maps = ref.read(mapStateRepositoryProvider);
    var mapState = await maps.read();

    // The day's pins hang off the cell you first opened the map in today.
    var cell = mapState.cellFor(today);
    if (cell == null) {
      cell = GeoCell.of(fix.point);
      mapState = mapState.copyWith(
        cell: cell,
        cellDate: today,
        collectedDate: today,
        collected: const {},
        snaps: const {},
      );
      await maps.write(mapState);
    }

    var next = view.copyWith(fix: fix);
    var collectedIds = mapState.collectedOn(today);
    final pinCount = ToyPerks.of(view.inventory.toys).pinsPerDay;
    var pins = _pinsFor(cell, today, pinCount, collectedIds, mapState.snaps);
    MapNotice? event;

    // Walking onto a pin picks it up. One at a time, so each gets its sheet.
    for (final pin in pins) {
      if (reached(fix: fix, target: pin.point, allowMocked: allowMocked)) {
        final result = await _take(pin, next);
        next = next.copyWith(inventory: result.inventory);
        collectedIds = {...collectedIds, pin.id};
        mapState = mapState.copyWith(
          collectedDate: today,
          collected: collectedIds,
        );
        await maps.write(mapState);
        event = PinCollected(result);
        break;
      }
    }
    pins = _pinsFor(cell, today, pinCount, collectedIds, mapState.snaps);

    // A cat waiting for a place: placed once, then walked to.
    final arrivals = ref.read(arrivalRepositoryProvider);
    var arrival = await arrivals.read();
    if (arrival != null && arrival.isVisibleOn(today)) {
      arrival = placeArrival(arrival: arrival, from: fix.point, today: today);
      await arrivals.write(arrival);
      if (reached(fix: fix, target: arrival.point!, allowMocked: allowMocked)) {
        event = await _join(arrival);
        arrival = null;
      }
    } else {
      arrival = null;
    }

    var recovery = mapState.recovery;
    var runaway = next.runaway;

    if (runaway) {
      recovery = placeCat(
        current: recovery,
        runaway: runaway,
        targetMet: next.recoveryTargetMet,
        from: fix.point,
        today: today,
      );
      if (recovery.isLocated &&
          reached(
            fix: fix,
            target: recovery.catPoint!,
            allowMocked: allowMocked,
          )) {
        await _bringHome();
        recovery = const Recovery();
        runaway = false;
        event = CatFound(next.catName);
      }
    } else {
      recovery = const Recovery();
    }

    if (recovery.phase != mapState.recovery.phase ||
        recovery.catPoint != mapState.recovery.catPoint) {
      await maps.write(mapState.copyWith(recovery: recovery));
    }

    // A street cat may be standing somewhere today.
    final known = await ref.read(streetCatRepositoryProvider).readAll();
    final streetCat = ref.read(streetCatPickerProvider)(
      known: known,
      cell: cell,
      date: today,
    );
    final spot = streetCat == null
        ? null
        : _streetSpot(streetCat, cell, today, mapState.snaps);
    _snapSoon(cell, today, pinCount, fix, mapState.snaps, streetCat?.id);
    final cats = await ref.read(catRepositoryProvider).readAll();

    // A cat that wishes for a walk: a place on a street, reached on foot.
    final walk = await _walkWish(fix, today, next);
    if (walk.event != null) event = walk.event;
    if (walk.inventory != null) next = next.copyWith(inventory: walk.inventory);

    return next.copyWith(
      walkWish: walk.spot,
      clearWalkWish: walk.spot == null,
      arrival: arrival,
      clearArrival: arrival == null,
      streetCat: spot,
      clearStreetCat: spot == null,
      freePlaces: placesLeft(
        home: await ref.read(homeStateRepositoryProvider).read(),
        cats: cats,
        arriving: arrival != null,
      ),
      pins: pins,
      recovery: recovery,
      runaway: runaway,
      event: event,
    );
  }

  /// Collects [pin]: updates the saved inventory, then refreshes the home
  /// screen so its candy count is right.
  /// Today's pins: the first [count] candidates not dropped, on their streets.
  List<MapPin> _pinsFor(
    GeoCell cell,
    CalendarDate today,
    int count,
    Set<String> collected,
    Map<String, PinSnap> snaps,
  ) => choosePins(
    candidates: spawnPins(
      cell: cell,
      date: today,
      count: count * candidatesPerPin,
    ),
    snaps: snaps,
    count: count,
    collected: collected,
  );

  bool _snapping = false;

  /// Cats whose walk wish place was tried today, so the router is not asked
  /// again on every position update.
  final Set<String> _walkTried = {};

  /// Finds the open walk wish, gives it a place when it has none, and grants
  /// it when the player stands on it.
  Future<({WalkWishSpot? spot, MapNotice? event, Inventory? inventory})>
  _walkWish(GeoFix fix, CalendarDate today, MapViewState view) async {
    const none = (spot: null, event: null, inventory: null);
    final homes = ref.read(homeStateRepositoryProvider);
    var home = await homes.read();
    final ids = home.wishes.keys.toList()..sort();
    String? catId;
    for (final id in ids) {
      if (home.wishes[id]!.open?.kind == WishKind.walk) {
        catId = id;
        break;
      }
    }
    if (catId == null) return none;
    final cats = await ref.read(catRepositoryProvider).readAll();
    final cat = cats.where((c) => c.id == catId).firstOrNull;
    if (cat == null || cat.status == CatStatus.runaway) return none;
    var record = home.wishes[catId]!;
    var wish = record.open!;

    // Choose, or move, the place.
    if (!wish.hasPlace || walkWishTooFar(wish, fix.point)) {
      final key = '$catId:${today.toIsoDate()}:${wish.hasPlace}';
      if (!_walkTried.add(key)) return none;
      final chosen = await _chooseWalkPlace(cat, record.granted, today, fix);
      if (chosen == null) {
        // No router or no street: the cat wishes for a thing instead.
        final tags = {for (final like in cat.likes) like};
        final item = newItemWish(
          cat: cat,
          home: home,
          unmet: cat.likes.toList(),
          granted: record.granted,
          today: today,
        );
        if (item == null || tags.isEmpty) return none;
        home = home.copyWith(
          wishes: {
            ...home.wishes,
            catId: record.copyWith(open: item),
          },
        );
        await homes.write(home);
        ref.invalidate(homeStateProvider);
        return none;
      }
      wish = wish.withPlace(chosen.$1, chosen.$2);
      record = record.copyWith(open: wish);
      home = home.copyWith(wishes: {...home.wishes, catId: record});
      await homes.write(home);
      ref.invalidate(homeStateProvider);
    }

    final spot = WalkWishSpot(cat: cat, wish: wish);
    final doneToday = home.walkWishDoneOn == today;
    if (!doneToday &&
        reached(fix: fix, target: spot.point, allowMocked: allowMocked)) {
      final inventories = ref.read(inventoryRepositoryProvider);
      final inventory = await inventories.read();
      final paid = inventory.copyWith(candy: inventory.candy + spot.candy);
      await inventories.write(paid);
      await homes.write(
        home.copyWith(
          walkWishDoneOn: today,
          bonusCats: {...home.bonusCats, catId},
          wishes: {
            ...home.wishes,
            catId: record.copyWith(
              clearOpen: true,
              granted: record.granted + 1,
              nextAfter: today.addDays(RoomConstants.wishGapDays),
            ),
          },
        ),
      );
      ref.invalidate(homeStateProvider);
      await ref.read(analyticsProvider).log('wish_granted');
      unawaited(ref.read(homeControllerProvider.notifier).refreshSilently());
      return (
        spot: null,
        event: WalkWishDone(catName: cat.name, candy: spot.candy),
        inventory: paid,
      );
    }
    return (spot: spot, event: null, inventory: null);
  }

  /// Up to 3 places 500 to 1,500 m away; the first the router can walk to in
  /// that distance. Returns its point on the street and the walking metres.
  Future<(GeoPoint, double)?> _chooseWalkPlace(
    Cat cat,
    int granted,
    CalendarDate today,
    GeoFix fix,
  ) async {
    final router = ref.read(routeServiceProvider);
    final random = math.Random(
      stableSeed('walkwish:${cat.id}:$granted:${today.toIsoDate()}'),
    );
    for (var i = 0; i < 3; i++) {
      final candidate = pointInBand(
        fix.point,
        random,
        minMeters: RoomConstants.walkWishMinMeters * 0.7,
        maxMeters: RoomConstants.walkWishMaxMeters * 0.8,
      );
      try {
        final route = await router.walk(fix.point, candidate);
        if (route == null || route.points.isEmpty) continue;
        if (route.meters < RoomConstants.walkWishMinMeters ||
            route.meters > RoomConstants.walkWishMaxMeters) {
          continue;
        }
        return (route.points.last, route.meters);
      } on RouteUnavailable {
        return null;
      }
    }
    return null;
  }

  DateTime? _snapTriedAt;

  /// How long to wait before asking the router again after it was unreachable.
  static const Duration snapRetryEvery = Duration(seconds: 45);

  /// Where today's street cat stands, on its street once the router has said.
  StreetCatSpot? _streetSpot(
    StreetCat cat,
    GeoCell cell,
    CalendarDate today,
    Map<String, PinSnap> snaps,
  ) {
    final chosen = choosePins(
      candidates: streetCatCandidates(cell: cell, date: today, catId: cat.id),
      snaps: snaps,
      count: 1,
    );
    return chosen.isEmpty
        ? null
        : StreetCatSpot(cat: cat, point: chosen.first.point);
  }

  /// The candidates to ask the router about, with how many of each are needed:
  /// the day's pins and today's street cat.
  List<(List<MapPin>, int)> _snapGroups(
    GeoCell cell,
    CalendarDate today,
    int count,
    String? streetCatId,
  ) => [
    (
      spawnPins(cell: cell, date: today, count: count * candidatesPerPin),
      count,
    ),
    if (streetCatId != null)
      (streetCatCandidates(cell: cell, date: today, catId: streetCatId), 1),
  ];

  /// Starts asking the router about today's candidate pins, when some have not
  /// been asked about. It runs in the background: the map shows the pins as
  /// drawn at first and moves them onto streets as the answers come in.
  void _snapSoon(
    GeoCell cell,
    CalendarDate today,
    int count,
    GeoFix fix,
    Map<String, PinSnap> snaps,
    String? streetCatId,
  ) {
    if (_snapping) return;
    final groups = _snapGroups(cell, today, count, streetCatId);
    final pending = groups.any(
      (g) => needsSnapping(candidates: g.$1, snaps: snaps, count: g.$2),
    );
    if (!pending) return;
    final tried = _snapTriedAt;
    if (tried != null && DateTime.now().difference(tried) < snapRetryEvery) {
      return;
    }
    _snapping = true;
    unawaited(_snap(groups, fix, today, count));
  }

  Future<void> _snap(
    List<(List<MapPin>, int)> groups,
    GeoFix fix,
    CalendarDate today,
    int pinCount,
  ) async {
    try {
      final maps = ref.read(mapStateRepositoryProvider);
      final router = ref.read(routeServiceProvider);
      var mapState = await maps.read();
      final snaps = {...mapState.snaps};
      for (final (candidates, count) in groups) {
        var kept = 0;
        for (final candidate in candidates) {
          var snap = snaps[candidate.id];
          if (snap == null) {
            final WalkingRoute? route;
            try {
              route = await router.walk(fix.point, candidate.point);
            } on RouteUnavailable {
              // Ask again later; the pins stay where they were drawn.
              _snapTriedAt = DateTime.now();
              _showSnappedPins(mapState, today, pinCount);
              return;
            }
            snap = route == null
                ? const PinSnap.rejected()
                : judgeSnap(
                    candidate: candidate.point,
                    from: fix.point,
                    route: route,
                  );
            snaps[candidate.id] = snap;
            // The day may have turned while the router was thinking.
            mapState = (await maps.read()).copyWith(snaps: snaps);
            if (CalendarDate.today() != today) return;
            await maps.write(mapState);
          }
          if (snap.verdict == SnapVerdict.accepted) kept++;
          if (kept == count) break;
        }
      }
      _showSnappedPins(mapState, today, pinCount);
    } finally {
      _snapping = false;
    }
  }

  /// Puts the pins and the street cat as they now stand on the map.
  void _showSnappedPins(MapState mapState, CalendarDate today, int count) {
    final view = state.value;
    final cell = mapState.cellFor(today);
    if (view == null || cell == null) return;
    final cat = view.streetCat?.cat;
    state = AsyncData(
      view.copyWith(
        pins: _pinsFor(
          cell,
          today,
          count,
          mapState.collectedOn(today),
          mapState.snaps,
        ),
        streetCat: cat == null
            ? null
            : _streetSpot(cat, cell, today, mapState.snaps),
      ),
    );
  }

  /// Takes a photo of today's street cat. You must be within reach of it.
  Future<StreetCatOutcome> photographStreetCat() async {
    final view = state.value;
    final spot = view?.streetCat;
    final fix = view?.fix;
    if (view == null || spot == null || fix == null || spot.cat.ready) {
      return StreetCatOutcome.notClose;
    }
    if (!reached(fix: fix, target: spot.point, allowMocked: allowMocked)) {
      return StreetCatOutcome.notClose;
    }
    final String? path;
    try {
      path = await ref
          .read(photoServiceProvider)
          .takeStreetCatPhoto(spot.cat.id);
    } on CameraUnavailable {
      return StreetCatOutcome.noCamera;
    }
    if (path == null) return StreetCatOutcome.cancelled;
    final today = CalendarDate.today();
    final saved = spot.cat.copyWith(
      photos: [...spot.cat.photos, path],
      lastSeen: today,
    );
    await ref.read(streetCatRepositoryProvider).upsert(saved);
    ref.invalidate(streetCatsProvider);
    final latest = state.value ?? view;
    state = AsyncData(
      latest.copyWith(
        clearStreetCat: true,
        event: StreetCatPhotographed(
          catName: saved.name,
          sightings: saved.sightings,
          ready: saved.ready,
          hasFreePlace: latest.freePlaces > 0,
        ),
      ),
    );
    return StreetCatOutcome.done;
  }

  /// Invites today's street cat to join, when it is ready, you are within
  /// reach and a place is free.
  Future<StreetCatOutcome> inviteStreetCat() async {
    final view = state.value;
    final spot = view?.streetCat;
    final fix = view?.fix;
    if (view == null || spot == null || fix == null || !spot.cat.ready) {
      return StreetCatOutcome.notClose;
    }
    if (!reached(fix: fix, target: spot.point, allowMocked: allowMocked)) {
      return StreetCatOutcome.notClose;
    }
    if (view.freePlaces <= 0) return StreetCatOutcome.noPlace;
    final today = CalendarDate.today();
    await ref
        .read(catRepositoryProvider)
        .add(await placeInBestRoom(ref, spot.cat.toCat(today)));
    await ref
        .read(streetCatRepositoryProvider)
        .upsert(spot.cat.copyWith(joined: true, lastSeen: today));
    ref.invalidate(streetCatsProvider);
    await ref.read(analyticsProvider).log('cat_joined');
    await ref.read(homeControllerProvider.notifier).refreshSilently();
    final latest = state.value ?? view;
    state = AsyncData(
      latest.copyWith(
        clearStreetCat: true,
        freePlaces: latest.freePlaces - 1,
        event: CatJoined(catName: spot.cat.name, returning: false),
      ),
    );
    return StreetCatOutcome.done;
  }

  Future<Collected> _take(MapPin pin, MapViewState view) async {
    final inventories = ref.read(inventoryRepositoryProvider);
    final inventory = await inventories.read();
    final result = collect(reward: pin.reward, inventory: inventory);
    await inventories.write(result.inventory);
    ref.invalidate(inventoryProvider);
    await ref.read(homeControllerProvider.notifier).refreshSilently();
    return result;
  }

  /// The cat is back: active again, neutral mood, and no longer counting missed
  /// days. Saved, then the home screen is refreshed.
  /// The waiting cat joins the room and takes a place. A returning lost cat is
  /// no longer lost.
  Future<CatJoined> _join(Arrival arrival) async {
    await ref
        .read(catRepositoryProvider)
        .add(await placeInBestRoom(ref, arrival.cat));
    if (arrival.kind == ArrivalKind.returning) {
      await ref.read(lostCatRepositoryProvider).remove(arrival.cat.id);
    }
    await ref.read(arrivalRepositoryProvider).write(null);
    await ref.read(analyticsProvider).log('cat_joined');
    await ref.read(homeControllerProvider.notifier).refreshSilently();
    return CatJoined(
      catName: arrival.cat.name,
      returning: arrival.kind == ArrivalKind.returning,
    );
  }

  Future<void> _bringHome() async {
    final cat = await _readCat();
    final home = cat.copyWith(
      status: CatStatus.active,
      mood: CatMood.neutral,
      consecutiveMissedDays: 0,
    );
    await ref
        .read(localStoreProvider)
        .write(OnboardingRepository.catKey, jsonEncode(catToJson(home)));
    await ref.read(homeControllerProvider.notifier).refreshSilently();
  }

  /// Reads the current cat straight from the store.
  Future<Cat> _readCat() async {
    final raw = await ref
        .read(localStoreProvider)
        .read(OnboardingRepository.catKey);
    return catFromJson(jsonDecode(raw!) as Map<String, dynamic>);
  }
}
