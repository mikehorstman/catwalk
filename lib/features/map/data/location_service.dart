import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/geo.dart';
import '../domain/reach_rule.dart';

/// Where the user stands on sharing location with the app.
///
/// The map only works with [granted]; everything else shows an explanation card.
enum LocationAccess {
  /// Not asked yet, or can be asked again.
  undecided,

  /// Allowed. The map can follow you.
  granted,

  /// Denied this time. Asking again is allowed.
  denied,

  /// Denied for good, or switched off. Only Settings can change it.
  blocked,
}

/// The map's only window onto where you are.
///
/// A seam so tests can fake the position instead of using real GPS.
abstract interface class LocationService {
  /// The current permission state, without showing any prompt.
  Future<LocationAccess> access();

  /// Shows the system permission prompt (if allowed) and returns the outcome.
  Future<LocationAccess> request();

  /// The last good fix, or null when there is none.
  Future<GeoFix?> current();

  /// Fixes as you walk. Foreground only.
  Stream<GeoFix> fixes();

  /// Opens the phone's Settings page for this app, for a [LocationAccess.blocked] user.
  Future<void> openSettings();
}

/// The [LocationService] in use. Tests and the simulator override it with a
/// [FakeLocationService].
final locationServiceProvider = Provider<LocationService>(
  (ref) => GeolocatorLocationService(),
);

/// The real [LocationService], backed by the `geolocator` package.
///
/// The phone's permission answer is folded into the four [LocationAccess] values.
class GeolocatorLocationService implements LocationService {
  @override
  Future<LocationAccess> access() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.blocked;
    }
    return _map(await Geolocator.checkPermission());
  }

  @override
  Future<LocationAccess> request() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.blocked;
    }
    return _map(await Geolocator.requestPermission());
  }

  @override
  Future<GeoFix?> current() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return _fix(position);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<GeoFix> fixes() => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    ),
  ).map(_fix);

  @override
  Future<void> openSettings() async {
    await Geolocator.openAppSettings();
  }

  /// Converts a geolocator [position] into our own [GeoFix].
  GeoFix _fix(Position position) => GeoFix(
    point: GeoPoint(position.latitude, position.longitude),
    accuracy: position.accuracy,
    isMocked: position.isMocked,
  );

  /// Folds geolocator's permission values into [LocationAccess].
  LocationAccess _map(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationAccess.granted;
      case LocationPermission.denied:
        return LocationAccess.denied;
      case LocationPermission.deniedForever:
        return LocationAccess.blocked;
      case LocationPermission.unableToDetermine:
        return LocationAccess.undecided;
    }
  }
}

/// A location you control, for tests and for the simulator.
class FakeLocationService implements LocationService {
  /// Starts with [access_] as the permission answer and [start] as the position.
  FakeLocationService({this.access_ = LocationAccess.granted, this.start});

  /// The permission answer returned by [access]. [request] upgrades undecided or
  /// denied to granted, like a user tapping Allow.
  LocationAccess access_;

  /// The position [current] returns; null means no fix yet.
  GeoFix? start;

  /// Feeds [fixes]; [move] pushes new positions into it.
  final _controller = StreamController<GeoFix>.broadcast();

  /// How many times [openSettings] was called, so tests can check it.
  int settingsOpened = 0;

  /// Pretends the user walked to [fix]: updates [start] and emits it on [fixes].
  void move(GeoFix fix) {
    start = fix;
    _controller.add(fix);
  }

  @override
  Future<LocationAccess> access() async => access_;

  @override
  Future<LocationAccess> request() async {
    if (access_ == LocationAccess.undecided ||
        access_ == LocationAccess.denied) {
      access_ = LocationAccess.granted;
    }
    return access_;
  }

  @override
  Future<GeoFix?> current() async => start;

  @override
  Stream<GeoFix> fixes() => _controller.stream;

  @override
  Future<void> openSettings() async => settingsOpened++;
}

/// Whether a runaway cat comes straight home once its step target is met,
/// because there is no map to find it on: true when location is switched off,
/// denied, or cannot be read.
///
/// When we cannot tell, the cat comes home without the map, so nobody is left
/// with a cat that can never come home.
final recoveryWithoutMapProvider = FutureProvider<bool>((ref) async {
  try {
    final access = await ref.watch(locationServiceProvider).access();
    return access == LocationAccess.blocked || access == LocationAccess.denied;
  } catch (_) {
    return true;
  }
});
