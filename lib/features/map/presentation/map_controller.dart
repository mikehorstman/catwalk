import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/calendar_date.dart';
import '../../../services/storage/local_store_provider.dart';
import '../../cat/data/cat_codec.dart';
import '../../cat/domain/cat.dart';
import '../../cat/domain/cat_mood.dart';
import '../../cat/domain/cat_status.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../steps/presentation/home_controller.dart';
import '../data/inventory_repository.dart';
import '../data/location_service.dart';
import '../data/map_state_repository.dart';
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

class PinCollected extends MapNotice {
  const PinCollected(this.result);
  final Collected result;
}

class CatFound extends MapNotice {
  const CatFound(this.catName);
  final String catName;
}

class MapViewState {
  const MapViewState({
    required this.access,
    required this.pins,
    required this.recovery,
    required this.runaway,
    required this.catName,
    required this.stepsToday,
    required this.dailyGoal,
    required this.inventory,
    this.fix,
    this.event,
  });

  final LocationAccess access;
  final GeoFix? fix;

  /// Today's pins you have not collected.
  final List<MapPin> pins;

  final Recovery recovery;
  final bool runaway;
  final String catName;
  final int stepsToday;
  final int dailyGoal;
  final Inventory inventory;

  /// Shown once, then cleared by [CatMapController.dismissEvent].
  final MapNotice? event;

  bool get hasLocation => access == LocationAccess.granted && fix != null;

  /// Steps still to walk before the cat shows up on the map.
  int get stepsToCatLocated =>
      (dailyGoal - stepsToday).clamp(0, dailyGoal).toInt();

  MapViewState copyWith({
    LocationAccess? access,
    GeoFix? fix,
    List<MapPin>? pins,
    Recovery? recovery,
    bool? runaway,
    String? catName,
    int? stepsToday,
    int? dailyGoal,
    Inventory? inventory,
    MapNotice? event,
    bool clearEvent = false,
  }) => MapViewState(
    access: access ?? this.access,
    fix: fix ?? this.fix,
    pins: pins ?? this.pins,
    recovery: recovery ?? this.recovery,
    runaway: runaway ?? this.runaway,
    catName: catName ?? this.catName,
    stepsToday: stepsToday ?? this.stepsToday,
    dailyGoal: dailyGoal ?? this.dailyGoal,
    inventory: inventory ?? this.inventory,
    event: clearEvent ? null : (event ?? this.event),
  );
}

final mapControllerProvider =
    AsyncNotifierProvider<CatMapController, MapViewState>(CatMapController.new);

class CatMapController extends AsyncNotifier<MapViewState> {
  StreamSubscription<GeoFix>? _fixes;
  bool _busy = false;

  /// A debug build may accept faked positions, so the simulator works. A
  /// release build never does.
  static bool get allowMocked => !kReleaseMode;

  @override
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
      stepsToday: home.today.steps,
      dailyGoal: home.today.stepGoal,
      inventory: inventory,
    );

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

  Future<void> openSettings() => ref.read(locationServiceProvider).openSettings();

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

    var recovery = mapState.recovery;
    var runaway = next.runaway;

    if (runaway) {
      recovery = placeCat(
        current: recovery,
        runaway: runaway,
        stepsToday: next.stepsToday,
        dailyGoal: next.dailyGoal,
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
      pins: pins,
      recovery: recovery,
      runaway: runaway,
      event: event,
    );
  }

  Future<Collected> _take(MapPin pin, MapViewState view) async {
    final store = ref.read(localStoreProvider);
    final cat = await _readCat();
    final inventories = ref.read(inventoryRepositoryProvider);
    final inventory = await inventories.read();
    final result = collect(reward: pin.reward, inventory: inventory, cat: cat);
    await inventories.write(result.inventory);
    if (result.xpGained > 0) {
      await store.write(
        OnboardingRepository.catKey,
        jsonEncode(catToJson(result.cat)),
      );
      await ref.read(homeControllerProvider.notifier).refreshSilently();
    }
    return result;
  }

  /// The cat is back: happy to see you, and no longer counting missed days.
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

  Future<Cat> _readCat() async {
    final raw = await ref
        .read(localStoreProvider)
        .read(OnboardingRepository.catKey);
    return catFromJson(jsonDecode(raw!) as Map<String, dynamic>);
  }
}
