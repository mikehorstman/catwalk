import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/calendar_date.dart';
import '../../../services/storage/local_store.dart';
import '../../../services/storage/local_store_provider.dart';
import '../domain/geo.dart';
import '../domain/pin_snapping.dart';
import '../domain/recovery.dart';

/// The app-wide [MapStateRepository], built on the local store.
final mapStateRepositoryProvider = Provider<MapStateRepository>((ref) {
  return MapStateRepository(ref.watch(localStoreProvider));
});

/// What the map remembers between opens.
///
/// Only a coarse cell is kept, never a track of where you walked.
class MapState {
  /// Everything is optional so a fresh install starts with an empty state.
  const MapState({
    this.cell,
    this.cellDate,
    this.collectedDate,
    this.collected = const {},
    this.recovery = const Recovery(),
    this.snaps = const {},
  });

  /// Reads a saved state. Missing or wrongly typed fields fall back to empty.
  factory MapState.fromJson(Map<String, dynamic> json) {
    final collected = json['collected'];
    return MapState(
      cell: json['cell'] is String
          ? GeoCell.parse(json['cell'] as String)
          : null,
      cellDate: json['cellDate'] is String
          ? CalendarDate.parse(json['cellDate'] as String)
          : null,
      collectedDate: json['collectedDate'] is String
          ? CalendarDate.parse(json['collectedDate'] as String)
          : null,
      collected: {
        if (collected is List)
          for (final id in collected)
            if (id is String) id,
      },
      snaps: {
        if (json['snaps'] is Map<String, dynamic>)
          for (final entry in (json['snaps'] as Map<String, dynamic>).entries)
            if (entry.value is Map<String, dynamic>)
              entry.key: PinSnap.fromJson(entry.value as Map<String, dynamic>),
      },
      recovery: json['recovery'] is Map<String, dynamic>
          ? Recovery.fromJson(json['recovery'] as Map<String, dynamic>)
          : const Recovery(),
    );
  }

  /// The cell the day's pins hang off, and the day it was fixed on.
  /// The cell the day's pins hang off, and the day it was fixed on.
  /// Null until the map has been opened with a position.
  final GeoCell? cell;

  /// The day [cell] was fixed on. Null until [cell] is set.
  final CalendarDate? cellDate;

  /// Pin ids already collected on [collectedDate].
  /// The day [collected] belongs to. A new day starts a new list.
  final CalendarDate? collectedDate;

  /// Ids of pins already picked up on [collectedDate], so they do not come back.
  final Set<String> collected;

  /// Where the runaway cat's search stands (not placed, or placed on the map).
  final Recovery recovery;

  /// What was decided about each of today's candidate pins: snapped onto a
  /// street, or dropped. Cleared with the day's cell.
  final Map<String, PinSnap> snaps;

  /// The pins' cell for [today], or null when it is yesterday's.
  GeoCell? cellFor(CalendarDate today) => cellDate == today ? cell : null;

  /// The collected ids that still count on [today].
  Set<String> collectedOn(CalendarDate today) =>
      collectedDate == today ? collected : const {};

  /// A copy with the given fields replaced. Fields left out keep their value
  /// (so a field cannot be reset to null this way).
  MapState copyWith({
    GeoCell? cell,
    CalendarDate? cellDate,
    CalendarDate? collectedDate,
    Set<String>? collected,
    Recovery? recovery,
    Map<String, PinSnap>? snaps,
  }) => MapState(
    cell: cell ?? this.cell,
    cellDate: cellDate ?? this.cellDate,
    collectedDate: collectedDate ?? this.collectedDate,
    collected: collected ?? this.collected,
    recovery: recovery ?? this.recovery,
    snaps: snaps ?? this.snaps,
  );

  /// The JSON saved to the local store. Null fields are left out.
  Map<String, Object> toJson() => {
    if (cell != null) 'cell': cell!.id,
    if (cellDate != null) 'cellDate': cellDate!.toIsoDate(),
    if (collectedDate != null) 'collectedDate': collectedDate!.toIsoDate(),
    'collected': collected.toList(),
    'recovery': recovery.toJson(),
    'snaps': {for (final e in snaps.entries) e.key: e.value.toJson()},
  };
}

/// Saves and loads the [MapState] as JSON in the local store.
class MapStateRepository {
  MapStateRepository(this._store);

  final LocalStore _store;

  /// Storage key the map state is saved under.
  static const key = 'map_state';

  /// The saved state, or an empty one if nothing is saved or it is unreadable.
  Future<MapState> read() async {
    final raw = await _store.read(key);
    if (raw == null) return const MapState();
    try {
      return MapState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const MapState();
    }
  }

  /// Replaces the saved state with [state].
  Future<void> write(MapState state) =>
      _store.write(key, jsonEncode(state.toJson()));
}
