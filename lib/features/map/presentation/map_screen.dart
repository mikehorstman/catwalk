import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme.dart';
import '../../../core/utils/format.dart';
import '../data/location_service.dart';
import '../domain/collect.dart';
import '../domain/geo.dart';
import '../domain/reach_rule.dart';
import '../domain/reward.dart';
import 'map_controller.dart';

/// Tiles come from OpenStreetMap by default, which is fine for development.
/// A shipped app should point `MAP_TILE_URL` at a host it has an account with.
const String mapTileUrl = String.fromEnvironment(
  'MAP_TILE_URL',
  defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
);

/// Tests turn the tiles off so no widget test touches the network.
final mapTilesEnabledProvider = Provider<bool>((ref) => true);

/// How close the map starts, and returns to when you recentre.
const double mapStartZoom = 17;

/// A pickup this close (metres) glows: one more short walk and it is yours.
const double nearPinMeters = 60;

/// Steps shorter than this (metres) are GPS noise and do not move the trail.
const double trailMinStepMeters = 4;

/// The trail keeps this many points, about a long walk.
const int trailMaxPoints = 120;

/// Softens the map into the app's cream and sage: less colour, a warm tint.
const ColorFilter mapTint = ColorFilter.matrix(<double>[
  0.80,
  0.14,
  0.06,
  0,
  14,
  0.10,
  0.84,
  0.06,
  0,
  12,
  0.08,
  0.14,
  0.72,
  0,
  4,
  0,
  0,
  0,
  1,
  0,
]);

/// The direction from [a] to [b], in radians clockwise from north.
double headingBetween(LatLng a, LatLng b) {
  final lat1 = a.latitudeInRad;
  final lat2 = b.latitudeInRad;
  final dLon = b.longitudeInRad - a.longitudeInRad;
  final y = math.sin(dLon) * math.cos(lat2);
  final x =
      math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
  return math.atan2(y, x);
}

/// Converts our [GeoPoint] to the map package's [LatLng].
LatLng _ll(GeoPoint p) => LatLng(p.lat, p.lon);

/// The map tab: shows you, today's pickups and (for a runaway cat) the cat.
///
/// Pins are collected by walking onto them; there is no tap to collect.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with SingleTickerProviderStateMixin {
  /// Moves and zooms the map from code.
  final MapController _map = MapController();

  /// True while the map keeps centring on you. Dragging the map turns it off; the
  /// recentre button turns it on.
  bool _following = true;

  /// True once the map is drawn and will accept move commands.
  bool _mapReady = false;

  /// Last zoom level, kept so following keeps the user's zoom.
  double _zoom = mapStartZoom;

  /// Where you have walked since the map opened, newest last.
  final List<LatLng> _trail = [];

  /// The way you are facing, in radians clockwise from north.
  double _heading = 0;

  /// Glides the camera to your new position instead of jumping.
  late final AnimationController _glide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  /// True while a pickup sheet is open, so another does not stack on top.
  bool _showingEvent = false;

  @override
  void dispose() {
    _glide.dispose();
    _map.dispose();
    super.dispose();
  }

  /// Adds [point] to the trail and turns the avatar towards where you went.
  void _walked(LatLng point) {
    if (_trail.isEmpty) {
      _trail.add(point);
      return;
    }
    final last = _trail.last;
    final moved = distanceMeters(
      GeoPoint(last.latitude, last.longitude),
      GeoPoint(point.latitude, point.longitude),
    );
    if (moved < trailMinStepMeters) return;
    setState(() {
      _heading = headingBetween(last, point);
      _trail.add(point);
      if (_trail.length > trailMaxPoints) _trail.removeAt(0);
    });
  }

  /// Slides the camera to [target] over a moment, keeping your zoom.
  void _glideTo(LatLng target) {
    final from = _map.camera.center;
    _glide
      ..removeListener(_onGlide)
      ..reset();
    _glideFrom = from;
    _glideTarget = target;
    _glide
      ..addListener(_onGlide)
      ..forward();
  }

  LatLng _glideFrom = const LatLng(0, 0);
  LatLng _glideTarget = const LatLng(0, 0);

  void _onGlide() {
    if (!_mapReady) return;
    final t = Curves.easeOut.transform(_glide.value);
    _map.move(
      LatLng(
        _glideFrom.latitude + (_glideTarget.latitude - _glideFrom.latitude) * t,
        _glideFrom.longitude +
            (_glideTarget.longitude - _glideFrom.longitude) * t,
      ),
      _zoom,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(mapControllerProvider, (previous, next) {
      final view = next.value;
      if (view == null) return;
      final event = view.event;
      if (event != null && !_showingEvent) _showEvent(event);
      final fix = view.fix;
      if (fix != null && previous?.value?.fix != fix) {
        _walked(_ll(fix.point));
        // The map only takes commands once it has been drawn.
        if (_following && _mapReady) _glideTo(_ll(fix.point));
      }
    });

    final state = ref.watch(mapControllerProvider);
    return Scaffold(
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            const Center(child: Text('Could not load the map.')),
        data: (view) => _body(context, view),
      ),
    );
  }

  /// Picks what to show: the access card, a waiting message, or the map.
  Widget _body(BuildContext context, MapViewState view) {
    if (view.access != LocationAccess.granted) {
      return _AccessCard(view: view);
    }
    final fix = view.fix;
    if (fix == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Finding you…', textAlign: TextAlign.center),
        ),
      );
    }
    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: _ll(fix.point),
            initialZoom: mapStartZoom,
            minZoom: 10,
            maxZoom: 19,
            onMapReady: () => _mapReady = true,
            onPositionChanged: (camera, hasGesture) {
              _zoom = camera.zoom;
              if (hasGesture && _following) setState(() => _following = false);
            },
          ),
          children: [
            if (ref.watch(mapTilesEnabledProvider))
              TileLayer(
                urlTemplate: mapTileUrl,
                userAgentPackageName: 'app.catwalk.catwalk',
                // The same streets, softened into the app's cream and sage.
                tileBuilder: (context, tile, _) =>
                    ColorFiltered(colorFilter: mapTint, child: tile),
              ),
            if (_trail.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: List.of(_trail),
                    strokeWidth: 5,
                    color: CatwalkColors.teal.withValues(alpha: 0.45),
                    strokeCap: StrokeCap.round,
                    strokeJoin: StrokeJoin.round,
                  ),
                ],
              ),
            // The circle you have to walk into to pick something up.
            CircleLayer(
              circles: [
                CircleMarker(
                  point: _ll(fix.point),
                  radius: reachRadiusMeters,
                  useRadiusInMeter: true,
                  color: CatwalkColors.teal.withValues(alpha: 0.14),
                  borderColor: CatwalkColors.teal.withValues(alpha: 0.55),
                  borderStrokeWidth: 2,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                for (final pin in view.pins)
                  Marker(
                    point: _ll(pin.point),
                    width: 56,
                    height: 56,
                    child: _PinMarker(
                      key: ValueKey('pin-${pin.id}'),
                      near:
                          distanceMeters(fix.point, pin.point) <= nearPinMeters,
                    ),
                  ),
                if (view.arrival?.point case final spot?)
                  Marker(
                    point: _ll(spot),
                    width: 64,
                    height: 64,
                    child: const _CatMarker(),
                  ),
                if (view.recovery.isLocated)
                  Marker(
                    point: _ll(view.recovery.catPoint!),
                    width: 52,
                    height: 52,
                    child: const _CatMarker(),
                  ),
                Marker(
                  point: _ll(fix.point),
                  width: 64,
                  height: 64,
                  child: _YouMarker(heading: _heading),
                ),
              ],
            ),
          ],
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _Banner(view: view),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.small(
            heroTag: 'recentre',
            tooltip: 'Centre on me',
            onPressed: () {
              _zoom = mapStartZoom;
              setState(() => _following = true);
              if (_mapReady) _glideTo(_ll(fix.point));
            },
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }

  /// Shows [event] in a bottom sheet, then clears it from the controller.
  Future<void> _showEvent(MapNotice event) async {
    _showingEvent = true;
    final controller = ref.read(mapControllerProvider.notifier);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: CatwalkColors.card,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _EventSheet(event: event),
    );
    _showingEvent = false;
    controller.dismissEvent();
  }
}

/// The card at the top of the map: what to do next (find the cat, walk more,
/// pick things up) plus how many streak freezes you hold.
class _Banner extends StatelessWidget {
  const _Banner({required this.view});

  final MapViewState view;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String text;
    final IconData icon;
    if (view.runaway && view.recovery.isLocated) {
      final fix = view.fix;
      final away = fix == null
          ? null
          : distanceMeters(fix.point, view.recovery.catPoint!).round();
      text = away == null
          ? '${view.catName} is somewhere nearby. Walk to the paw.'
          : '${view.catName} is ${formatNumber(away)} m away. Walk to the paw.';
      icon = Icons.pets;
    } else if (view.runaway) {
      text =
          '${view.catName} ran away. Walk '
          '${formatNumber(view.recoveryStepsToGo)} more steps within '
          '${view.recoveryDaysLeft} '
          '${view.recoveryDaysLeft == 1 ? 'day' : 'days'}, '
          'then look for them here.';
      icon = Icons.directions_walk;
    } else if (view.arrival?.point != null) {
      final fix = view.fix;
      final away = fix == null
          ? null
          : distanceMeters(fix.point, view.arrival!.point!).round();
      text = away == null
          ? 'A cat is waiting nearby. Walk to the paw.'
          : 'A cat is waiting ${formatNumber(away)} m away. Walk to the paw.';
      icon = Icons.pets;
    } else if (view.pins.isEmpty) {
      text = 'Nothing left nearby today. New pickups tomorrow.';
      icon = Icons.check_circle_outline;
    } else {
      final n = view.pins.length;
      text = n == 1 ? 'One pickup nearby.' : '$n pickups nearby.';
      icon = Icons.card_giftcard;
    }
    final freezes = view.inventory.freezes;
    final freezeNote = freezes == 0
        ? null
        : freezes == 1
        ? 'You hold 1 streak freeze.'
        : 'You hold $freezes streak freezes.';
    return Material(
      color: CatwalkColors.card,
      elevation: 2,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: CatwalkColors.teal),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                // Without min the card grows to the whole screen.
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text, style: theme.textTheme.bodyMedium),
                  if (freezeNote != null)
                    Text(
                      freezeNote,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: CatwalkColors.inkMuted,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown instead of the map when location is not allowed: explains why, and
/// offers to ask again or open Settings.
class _AccessCard extends ConsumerWidget {
  const _AccessCard({required this.view});

  final MapViewState view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = view.access == LocationAccess.blocked;
    final theme = Theme.of(context);
    final controller = ref.read(mapControllerProvider.notifier);
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.map_outlined,
                size: 56,
                color: CatwalkColors.teal,
              ),
              const SizedBox(height: 16),
              Text(
                blocked
                    ? 'Location is switched off'
                    : 'Catwalk needs your location',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                blocked
                    ? 'Turn it on for Catwalk in Settings to see pickups and '
                          'find a cat that ran away. Your steps are not affected.'
                    : 'Only while the app is open, only to show what is near '
                          'you. It stays on this phone.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: blocked
                    ? controller.openSettings
                    : controller.requestAccess,
                child: Text(blocked ? 'Open Settings' : 'Allow location'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The blue dot for your own position.
/// You: a cat face on a sage disc, a soft pulse around it and a pointer that
/// turns the way you are walking.
class _YouMarker extends StatefulWidget {
  const _YouMarker({required this.heading});

  /// Radians clockwise from north.
  final double heading;

  @override
  State<_YouMarker> createState() => _YouMarkerState();
}

class _YouMarkerState extends State<_YouMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'You',
    child: AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) => Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 30 + 34 * _pulse.value,
            height: 30 + 34 * _pulse.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: CatwalkColors.teal.withValues(
                alpha: 0.28 * (1 - _pulse.value),
              ),
            ),
          ),
          Transform.rotate(
            angle: widget.heading,
            child: const Align(
              alignment: Alignment.topCenter,
              child: Icon(
                Icons.navigation,
                key: Key('you-heading'),
                size: 18,
                color: CatwalkColors.teal,
              ),
            ),
          ),
          Container(
            key: const Key('you-marker'),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: CatwalkColors.teal,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(blurRadius: 5, color: Colors.black38),
              ],
            ),
            child: const Icon(Icons.pets, color: Colors.white, size: 18),
          ),
        ],
      ),
    ),
  );
}

/// A pickup: bobs gently, and glows and grows once it is close enough to walk
/// onto.
class _PinMarker extends StatefulWidget {
  const _PinMarker({super.key, required this.near});

  /// True when you are within a few steps of it.
  final bool near;

  @override
  State<_PinMarker> createState() => _PinMarkerState();
}

class _PinMarkerState extends State<_PinMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.near ? 'Pickup, very close' : 'Pickup',
    child: AnimatedBuilder(
      animation: _bob,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -5 * Curves.easeInOut.transform(_bob.value)),
        child: child,
      ),
      child: AnimatedScale(
        scale: widget.near ? 1.25 : 0.9,
        duration: const Duration(milliseconds: 250),
        child: Container(
          decoration: BoxDecoration(
            color: CatwalkColors.orange,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                blurRadius: widget.near ? 16 : 4,
                spreadRadius: widget.near ? 3 : 0,
                color: widget.near
                    ? CatwalkColors.orange.withValues(alpha: 0.7)
                    : Colors.black26,
              ),
            ],
          ),
          child: const Icon(
            Icons.card_giftcard,
            color: CatwalkColors.ink,
            size: 24,
          ),
        ),
      ),
    ),
  );
}

/// A cat waiting on the map, with a ring that breathes so it is easy to spot.
class _CatMarker extends StatefulWidget {
  const _CatMarker();

  @override
  State<_CatMarker> createState() => _CatMarkerState();
}

class _CatMarkerState extends State<_CatMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Your cat',
    child: AnimatedBuilder(
      animation: _ring,
      builder: (context, _) => Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 40 + 24 * _ring.value,
            height: 40 + 24 * _ring.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: CatwalkColors.orange.withValues(
                  alpha: 0.7 * (1 - _ring.value),
                ),
                width: 3,
              ),
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: CatwalkColors.orange,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(blurRadius: 5, color: Colors.black38),
              ],
            ),
            child: const Icon(Icons.pets, color: Colors.white, size: 26),
          ),
        ],
      ),
    ),
  );
}

class _EventSheet extends StatelessWidget {
  const _EventSheet({required this.event});

  final MapNotice event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (String title, String body, IconData icon) = switch (event) {
      CatFound(:final catName) => (
        '$catName is home',
        '$catName is back in the room.',
        Icons.favorite,
      ),
      CatJoined(:final catName, :final returning) => (
        returning ? '$catName is back!' : '$catName joined you',
        returning
            ? '$catName found the way home. The bed is theirs again.'
            : '$catName is in your room now, in the empty bed.',
        Icons.pets,
      ),
      PinCollected(:final result) => _describe(result),
    };
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(icon, size: 48, color: CatwalkColors.teal),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Nice'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Title, body and icon for a collected pin. When the pin was [Collected.converted]
  /// the text says it paid candy instead.
  (String, String, IconData) _describe(Collected result) {
    final extra = result.converted
        ? ' You already had ${result.reward is FreezeReward ? 'the most freezes you can hold' : 'this toy'}, so it paid candy instead.'
        : '';
    switch (result.reward) {
      case CandyReward(:final amount):
        return (
          '+$amount candy',
          'Spend it in the shop on Home.',
          Icons.cookie,
        );
      case FreezeReward():
        return result.converted
            ? (
                '+${result.candyGained} candy',
                'A streak freeze.$extra',
                Icons.cookie,
              )
            : (
                'Streak freeze',
                'It covers one missed day, then it is gone.',
                Icons.ac_unit,
              );
      case ToyReward(:final toyId):
        return result.converted
            ? ('+${result.candyGained} candy', 'A $toyId.$extra', Icons.cookie)
            : ('A $toyId', 'It is in the room now.', Icons.toys);
    }
  }
}
