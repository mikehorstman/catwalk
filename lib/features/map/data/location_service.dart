import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/geo.dart';
import '../domain/reach_rule.dart';

enum LocationAccess {
  /// Not asked yet, or can be asked again.
  undecided,
  granted,

  /// Denied this time. Asking again is allowed.
  denied,

  /// Denied for good, or switched off. Only Settings can change it.
  blocked,
}

/// The map's only window onto where you are.
abstract interface class LocationService {
  Future<LocationAccess> access();

  Future<LocationAccess> request();

  /// The last good fix, or null when there is none.
  Future<GeoFix?> current();

  /// Fixes as you walk. Foreground only.
  Stream<GeoFix> fixes();

  Future<void> openSettings();
}

final locationServiceProvider = Provider<LocationService>(
  (ref) => GeolocatorLocationService(),
);

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

  GeoFix _fix(Position position) => GeoFix(
    point: GeoPoint(position.latitude, position.longitude),
    accuracy: position.accuracy,
    isMocked: position.isMocked,
  );

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
  FakeLocationService({
    this.access_ = LocationAccess.granted,
    this.start,
  });

  LocationAccess access_;
  GeoFix? start;
  final _controller = StreamController<GeoFix>.broadcast();
  int settingsOpened = 0;

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

/// Whether a runaway cat can come home through the weekly walk instead of the
/// map: true when location is switched off, denied, or cannot be read.
///
/// When we cannot tell, the weekly walk is allowed, so nobody is left with a
/// cat that can never come home.
final weeklyRecoveryAllowedProvider = FutureProvider<bool>((ref) async {
  try {
    final access = await ref.watch(locationServiceProvider).access();
    return access == LocationAccess.blocked || access == LocationAccess.denied;
  } catch (_) {
    return true;
  }
});
