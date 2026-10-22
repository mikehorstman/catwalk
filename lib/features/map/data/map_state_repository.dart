import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/calendar_date.dart';
import '../../../services/storage/local_store.dart';
import '../../../services/storage/local_store_provider.dart';
import '../domain/geo.dart';
import '../domain/recovery.dart';

final mapStateRepositoryProvider = Provider<MapStateRepository>((ref) {
  return MapStateRepository(ref.watch(localStoreProvider));
});

/// What the map remembers between opens.
///
/// Only a coarse cell is kept, never a track of where you walked.
class MapState {
  const MapState({
    this.cell,
    this.cellDate,
    this.collectedDate,
    this.collected = const {},
    this.recovery = const Recovery(),
  });

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
      recovery: json['recovery'] is Map<String, dynamic>
          ? Recovery.fromJson(json['recovery'] as Map<String, dynamic>)
          : const Recovery(),
    );
  }

  /// The cell the day's pins hang off, and the day it was fixed on.
  final GeoCell? cell;
  final CalendarDate? cellDate;

  /// Pin ids already collected on [collectedDate].
  final CalendarDate? collectedDate;
  final Set<String> collected;

  final Recovery recovery;

  /// The pins' cell for [today], or null when it is yesterday's.
  GeoCell? cellFor(CalendarDate today) => cellDate == today ? cell : null;

  /// The collected ids that still count on [today].
  Set<String> collectedOn(CalendarDate today) =>
      collectedDate == today ? collected : const {};

  MapState copyWith({
    GeoCell? cell,
    CalendarDate? cellDate,
    CalendarDate? collectedDate,
    Set<String>? collected,
    Recovery? recovery,
  }) => MapState(
    cell: cell ?? this.cell,
    cellDate: cellDate ?? this.cellDate,
    collectedDate: collectedDate ?? this.collectedDate,
    collected: collected ?? this.collected,
    recovery: recovery ?? this.recovery,
  );

  Map<String, Object> toJson() => {
    if (cell != null) 'cell': cell!.id,
    if (cellDate != null) 'cellDate': cellDate!.toIsoDate(),
    if (collectedDate != null) 'collectedDate': collectedDate!.toIsoDate(),
    'collected': collected.toList(),
    'recovery': recovery.toJson(),
  };
}

class MapStateRepository {
  MapStateRepository(this._store);

  final LocalStore _store;

  static const key = 'map_state';

  Future<MapState> read() async {
    final raw = await _store.read(key);
    if (raw == null) return const MapState();
    try {
      return MapState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const MapState();
    }
  }

  Future<void> write(MapState state) =>
      _store.write(key, jsonEncode(state.toJson()));
}
