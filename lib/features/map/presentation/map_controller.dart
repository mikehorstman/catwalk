import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../data/arrival_repository.dart';
import '../data/inventory_repository.dart';
import '../data/lost_cat_repository.dart';
import '../data/location_service.dart';
import '../data/map_state_repository.dart';
import '../domain/arrival.dart';
import '../domain/collect.dart';
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
  );
}

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
      );
      await maps.write(mapState);
    }

    var next = view.copyWith(fix: fix);
    var collectedIds = mapState.collectedOn(today);
    var pins = spawnPins(cell: cell, date: today, collected: collectedIds);
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
    pins = spawnPins(cell: cell, date: today, collected: collectedIds);

    // A cat waiting for a bed: placed once, then walked to.
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

    return next.copyWith(
      arrival: arrival,
      clearArrival: arrival == null,
      pins: pins,
      recovery: recovery,
      runaway: runaway,
      event: event,
    );
  }

  /// Collects [pin]: updates the saved inventory, then refreshes the home
  /// screen so its candy count is right.
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
  /// The waiting cat joins the room and takes its bed. A returning lost cat is
  /// no longer lost.
  Future<CatJoined> _join(Arrival arrival) async {
    await ref.read(catRepositoryProvider).add(arrival.cat);
    if (arrival.kind == ArrivalKind.returning) {
      await ref.read(lostCatRepositoryProvider).remove(arrival.cat.id);
    }
    await ref.read(arrivalRepositoryProvider).write(null);
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
