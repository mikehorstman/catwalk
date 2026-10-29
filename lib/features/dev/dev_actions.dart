import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/calendar_date.dart';
import '../../services/storage/local_store_provider.dart';
import '../cat/data/cat_repository.dart';
import '../cat/domain/new_cat.dart';
import '../map/data/inventory_repository.dart';
import '../map/presentation/map_controller.dart';
import '../rooms/data/home_state_repository.dart';
import '../rooms/data/room_placement.dart';
import '../rooms/domain/decoration_catalogue.dart';
import '../rooms/domain/home_state.dart';
import '../rooms/domain/room_constants.dart';
import '../rooms/domain/room_type.dart';
import '../rooms/domain/wishes.dart';
import '../room/data/room_layout_provider.dart';
import '../steps/presentation/home_controller.dart';
import 'dev_settings.dart';

final devSettingsProvider = FutureProvider<DevSettings>(
  (ref) => DevSettings.read(ref.watch(localStoreProvider)),
);

/// Everything developer mode can do. Each action changes the saved game and
/// reloads the screens, so the effect shows at once.
class DevActions {
  /// Creates the actions.
  DevActions(this._ref);

  final Ref _ref;

  Future<void> _reload() async {
    _ref.invalidate(devSettingsProvider);
    _ref.invalidate(inventoryProvider);
    _ref.invalidate(homeStateProvider);
    _ref.invalidate(mapControllerProvider);
    await _ref.read(homeControllerProvider.notifier).refresh();
  }

  Future<DevSettings> _settings() =>
      DevSettings.read(_ref.read(localStoreProvider));

  Future<void> _save(DevSettings settings) async {
    await DevSettings.write(_ref.read(localStoreProvider), settings);
    await _reload();
  }

  /// Turns developer mode on or off. Typed-in steps stay saved but do not
  /// apply while it is off.
  Future<void> setEnabled(bool on) async =>
      _save((await _settings()).copyWith(enabled: on));

  /// Makes candy endless, or normal again.
  Future<void> setUnlimitedCandy(bool on) async =>
      _save((await _settings()).copyWith(unlimitedCandy: on));

  /// Types in the steps of the day [daysAgo] days back. Null goes back to the
  /// real count.
  Future<void> setSteps(int daysAgo, int? steps) async {
    final settings = await _settings();
    final date = CalendarDate.today().addDays(-daysAgo).toIsoDate();
    final next = {...settings.steps};
    if (steps == null) {
      next.remove(date);
    } else {
      next[date] = steps.clamp(0, 500000);
    }
    await _save(settings.copyWith(steps: next));
  }

  /// Adds candy to what you hold.
  Future<void> addCandy(int amount) async {
    final repository = _ref.read(inventoryRepositoryProvider);
    final saved = await _readSavedCandy();
    await repository.write(saved.copyWith(candy: saved.candy + amount));
    await _reload();
  }

  // Reads what is saved, without the endless-candy override.
  Future<dynamic> _readSavedCandy() async {
    final settings = await _settings();
    final repository = _ref.read(inventoryRepositoryProvider);
    if (!(settings.enabled && settings.unlimitedCandy)) {
      return repository.read();
    }
    await DevSettings.write(
      _ref.read(localStoreProvider),
      settings.copyWith(unlimitedCandy: false),
    );
    final inventory = await repository.read();
    await DevSettings.write(_ref.read(localStoreProvider), settings);
    return inventory;
  }

  /// Adds streak freezes.
  Future<void> addFreezes(int amount) async {
    final repository = _ref.read(inventoryRepositoryProvider);
    final inventory = await _readSavedCandy();
    await repository.write(
      inventory.copyWith(freezes: inventory.freezes + amount),
    );
    await _reload();
  }

  /// Makes all four rooms yours.
  Future<void> unlockAllRooms() async {
    final repository = _ref.read(homeStateRepositoryProvider);
    final home = await repository.read();
    await repository.write(home.copyWith(rooms: RoomType.values));
    await _reload();
  }

  /// Owns every item and makes every tier buyable.
  Future<void> ownAllItems() async {
    final repository = _ref.read(homeStateRepositoryProvider);
    final home = await repository.read();
    await repository.write(
      home.copyWith(
        rooms: RoomType.values,
        owned: {for (final item in catalogue) item.id},
        unlocked: {for (final item in catalogue) item.id},
      ),
    );
    await _reload();
  }

  /// Adds a new cat in a free place. Returns false when every place is taken.
  Future<bool> addCat() async {
    final cats = _ref.read(catRepositoryProvider);
    final home = await _ref.read(homeStateRepositoryProvider).read();
    final all = await cats.readAll();
    if (all.length >= home.rooms.length * RoomConstants.placesPerRoom) {
      return false;
    }
    final today = CalendarDate.today();
    final cat = newCat(
      seed: 'dev-${DateTime.now().millisecondsSinceEpoch}',
      on: today,
    );
    await cats.add(await placeInBestRoom(_ref, cat));
    await _reload();
    return true;
  }

  /// Gives up to three cats a small gift to open.
  Future<void> giveGifts() async {
    final repository = _ref.read(homeStateRepositoryProvider);
    final home = await repository.read();
    final cats = await _ref.read(catRepositoryProvider).readAll();
    final today = CalendarDate.today();
    await repository.write(
      home.copyWith(
        giftsDay: today,
        extraGifts: [
          for (final cat in cats.take(RoomConstants.maxGiftsPerDay))
            ExtraGift(catId: cat.id, date: today),
        ],
      ),
    );
    await _reload();
  }

  /// Lets every cat without a wish make one now.
  Future<void> wishesNow() async {
    final repository = _ref.read(homeStateRepositoryProvider);
    final home = await repository.read();
    final cats = await _ref.read(catRepositoryProvider).readAll();
    final yesterday = CalendarDate.today().addDays(-1);
    final wishes = {...home.wishes};
    for (final cat in cats) {
      final record = wishes[cat.id] ?? const WishRecord(nextAfter: null);
      if (record.open == null) {
        wishes[cat.id] = record.copyWith(nextAfter: yesterday);
      }
    }
    await repository.write(home.copyWith(wishes: wishes));
    await _reload();
  }

  /// Gives the first cat a walk wish, so the star shows on the map. Returns
  /// false when another walk wish is open.
  Future<bool> walkWishNow() async {
    final repository = _ref.read(homeStateRepositoryProvider);
    final home = await repository.read();
    final cats = await _ref.read(catRepositoryProvider).readAll();
    if (cats.isEmpty ||
        home.wishes.values.any((r) => r.open?.kind == WishKind.walk)) {
      return false;
    }
    final cat = cats.first;
    final record = home.wishes[cat.id] ?? const WishRecord(nextAfter: null);
    final wish = Wish(
      kind: WishKind.walk,
      createdOn: CalendarDate.today(),
      like: cat.likes.isEmpty ? null : cat.likes.first,
    );
    await repository.write(
      home.copyWith(
        wishes: {
          ...home.wishes,
          cat.id: record.copyWith(open: wish),
        },
        walkWishDoneOn: null,
      ),
    );
    await _reload();
    return true;
  }
}

final devActionsProvider = Provider<DevActions>(DevActions.new);
