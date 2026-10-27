import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme.dart';
import '../../../core/utils/format.dart';
import '../../cat/presentation/widgets/cat_head_icon.dart';
import '../data/location_service.dart';
import '../data/route_service.dart';
import '../domain/collect.dart';
import '../domain/geo.dart';
import '../domain/reach_rule.dart';
import '../domain/street_cat.dart';
import '../domain/walking_route.dart';
import '../domain/reward.dart';
import 'map_controller.dart';

/// The MapTiler key. A map key, not a secret: it ships inside the app, as
/// every map key does. Override it with `--dart-define=MAPTILER_KEY=...`.
const String mapTilerKey = String.fromEnvironment(
  'MAPTILER_KEY',
  defaultValue: 'RhM9qwrSBQiLZKaLWqLP',
);

/// The map style. `streets-v4` is cream and soft green, which suits the app.
const String mapTilerStyle = String.fromEnvironment(
  'MAPTILER_STYLE',
  defaultValue: 'streets-v4',
);

/// Where tiles come from: MapTiler by default. `{r}` becomes `@2x` on sharp
/// screens. Point `MAP_TILE_URL` at another host to change it, for example
/// OpenStreetMap's own, which is only fine for development.
const String mapTileUrl = String.fromEnvironment(
  'MAP_TILE_URL',
  defaultValue:
      'https://api.maptiler.com/maps/$mapTilerStyle/256/{z}/{x}/{y}{r}.png'
      '?key=$mapTilerKey',
);

/// True when the tiles are OpenStreetMap's own plain ones, which get softened
/// by [mapTint]. MapTiler's style is already cream, so it is left alone.
bool get mapNeedsTint => mapTileUrl.contains('openstreetmap.org');

/// Tests turn the tiles off so no widget test touches the network.
final mapTilesEnabledProvider = Provider<bool>((ref) => true);

/// The route is asked for again once you have walked this far (metres)...
const double routeRefreshMeters = 40;

/// ...but not more often than this, and a failed ask waits this long.
Duration routeRefreshEvery = const Duration(seconds: 8);

/// How long a failed ask waits before the next try.
Duration routeRetryEvery = const Duration(seconds: 15);

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

  /// How far the map is turned, in degrees. Two fingers turn it, as in Google
  /// Maps; the compass button turns it back to north.
  double _rotation = 0;

  /// What you tapped on the map, or null. Pins and cats can be tapped; the
  /// card at the bottom then shows how far away it is and how long to walk.
  String? _selected;

  /// The street route to what you tapped, once found.
  WalkingRoute? _route;

  /// Which selection [_route] belongs to.
  String? _routeFor;

  /// Where you stood when the route was asked for.
  GeoPoint? _routeFrom;

  /// When the route was last asked for, and whether that found nothing.
  DateTime? _routeAt;
  bool _routeFailed = false;
  bool _routeBusy = false;

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

  /// Selects [id] and asks for the street route to it.
  void _select(String? id) {
    setState(() {
      _selected = id;
      _route = null;
      _routeFor = null;
      _routeAt = null;
      _routeFailed = false;
    });
    final view = ref.read(mapControllerProvider).value;
    if (id != null && view != null) _refreshRoute(view);
  }

  /// Asks for the street route to the selection when it is missing or stale:
  /// you walked on, or an earlier ask found nothing.
  Future<void> _refreshRoute(MapViewState view) async {
    final id = _selected;
    final target = _selectedTarget(view);
    final fix = view.fix;
    if (id == null || target == null || fix == null || _routeBusy) return;
    final now = DateTime.now();
    final last = _routeAt;
    if (_routeFor == id && last != null) {
      final wait = now.difference(last);
      final from = _routeFrom;
      final moved = from == null ? 0.0 : distanceMeters(from, fix.point);
      final stale = _routeFailed
          ? wait >= routeRetryEvery
          : moved >= routeRefreshMeters && wait >= routeRefreshEvery;
      if (!stale) return;
    }
    _routeBusy = true;
    if (mounted) setState(() {});
    WalkingRoute? route;
    try {
      route = await ref
          .read(routeServiceProvider)
          .walk(fix.point, target.point);
    } on RouteUnavailable {
      route = null;
    }
    _routeBusy = false;
    if (!mounted || _selected != id) return;
    setState(() {
      _route = route ?? (_routeFor == id ? _route : null);
      _routeFor = id;
      _routeFrom = fix.point;
      _routeAt = DateTime.now();
      _routeFailed = route == null;
    });
  }

  /// What is selected right now, or null. A pin that was collected, or a cat
  /// that came home, drops out by itself.
  _Target? _selectedTarget(MapViewState view) {
    final id = _selected;
    if (id == null) return null;
    if (id == 'waiting-cat' && view.arrival?.point != null) {
      return _Target('A cat is waiting', view.arrival!.point!);
    }
    if (id == 'lost-cat' && view.recovery.isLocated) {
      return _Target('${view.catName} is hiding here', view.recovery.catPoint!);
    }
    if (id == 'street-cat' && view.streetCat != null) {
      final spot = view.streetCat!;
      return _Target(
        'Street cat: ${spot.cat.name}',
        spot.point,
        detail: spot.cat.ready
            ? '${spot.cat.name} is ready to join you'
            : 'Photos so far: ${spot.cat.sightings} of $sightingsToJoin',
      );
    }
    for (final pin in view.pins) {
      if (id == 'pin-${pin.id}') return _Target('Pickup', pin.point);
    }
    return null;
  }

  /// What you can do with the street cat: say hi from afar, or photograph it,
  /// or invite it once you are close.
  Widget? _streetAction(MapViewState view) {
    final spot = view.streetCat;
    final fix = view.fix;
    if (spot == null || fix == null) return null;
    final near = reached(
      fix: fix,
      target: spot.point,
      allowMocked: CatMapController.allowMocked,
    );
    if (!near) {
      return Text(
        'Walk within ${reachRadiusMeters.round()} m to meet ${spot.cat.name}.',
        key: const Key('street-far'),
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    if (spot.cat.ready) {
      return view.freeBeds > 0
          ? FilledButton.icon(
              key: const Key('street-invite'),
              onPressed: _invite,
              icon: const Icon(Icons.home_outlined),
              label: const Text('Invite to join'),
            )
          : Text(
              'Every bed is taken. Buy one in the Shop, then invite '
              '${spot.cat.name}.',
              key: const Key('street-no-bed'),
              style: Theme.of(context).textTheme.bodySmall,
            );
    }
    return FilledButton.icon(
      key: const Key('street-photo'),
      onPressed: _photograph,
      icon: const Icon(Icons.photo_camera),
      label: const Text('Take a photo'),
    );
  }

  Future<void> _photograph() => _streetOutcome(
    ref.read(mapControllerProvider.notifier).photographStreetCat(),
  );

  Future<void> _invite() => _streetOutcome(
    ref.read(mapControllerProvider.notifier).inviteStreetCat(),
  );

  Future<void> _streetOutcome(Future<StreetCatOutcome> pending) async {
    final outcome = await pending;
    if (!mounted) return;
    final message = switch (outcome) {
      StreetCatOutcome.done || StreetCatOutcome.cancelled => null,
      StreetCatOutcome.notClose => 'Walk a little closer first.',
      StreetCatOutcome.noCamera =>
        'The camera is not available. Check that Catwalk may use it.',
      StreetCatOutcome.noBed => 'Every bed is taken. Buy one in the Shop.',
    };
    if (message != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
    if (outcome == StreetCatOutcome.done) _select(null);
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
        _refreshRoute(view);
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
            onTap: (_, _) {
              if (_selected != null) _select(null);
            },
            onPositionChanged: (camera, hasGesture) {
              _zoom = camera.zoom;
              if ((camera.rotation - _rotation).abs() > 0.5) {
                setState(() => _rotation = camera.rotation);
              }
              if (hasGesture && _following) setState(() => _following = false);
            },
          ),
          children: [
            if (ref.watch(mapTilesEnabledProvider)) ...[
              TileLayer(
                urlTemplate: mapTileUrl,
                userAgentPackageName: 'app.catwalk.catwalk',
                retinaMode: RetinaMode.isHighDensity(context),
                tileBuilder: mapNeedsTint
                    ? (context, tile, _) =>
                          ColorFiltered(colorFilter: mapTint, child: tile)
                    : null,
              ),
              const _MapCredit(),
            ],
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
            // The way to what you tapped: along the streets once the router
            // answered, a dashed straight line until then.
            if (_selectedTarget(view) case final target?)
              PolylineLayer(
                polylines: [
                  if (_route != null && _routeFor == _selected)
                    Polyline(
                      points: [
                        _ll(fix.point),
                        for (final p in _route!.points) _ll(p),
                        _ll(target.point),
                      ],
                      strokeWidth: 6,
                      color: CatwalkColors.orange,
                      borderStrokeWidth: 2,
                      borderColor: Colors.white,
                      strokeCap: StrokeCap.round,
                      strokeJoin: StrokeJoin.round,
                    )
                  else
                    Polyline(
                      points: [_ll(fix.point), _ll(target.point)],
                      strokeWidth: 4,
                      color: CatwalkColors.orange.withValues(alpha: 0.85),
                      pattern: StrokePattern.dashed(segments: const [10, 8]),
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
                    rotate: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _select('pin-${pin.id}'),
                      child: _PinMarker(
                        key: ValueKey('pin-${pin.id}'),
                        near:
                            distanceMeters(fix.point, pin.point) <=
                            nearPinMeters,
                        selected: _selected == 'pin-${pin.id}',
                      ),
                    ),
                  ),
                if (view.arrival?.point case final spot?)
                  Marker(
                    point: _ll(spot),
                    width: 64,
                    height: 64,
                    rotate: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _select('waiting-cat'),
                      child: const _CatMarker(key: Key('waiting-cat')),
                    ),
                  ),
                if (view.streetCat case final spot?)
                  Marker(
                    point: _ll(spot.point),
                    width: 64,
                    height: 64,
                    rotate: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _select('street-cat'),
                      child: _StreetCatMarker(
                        key: const Key('street-cat'),
                        coat: spot.cat.appearance.color,
                      ),
                    ),
                  ),
                if (view.recovery.isLocated)
                  Marker(
                    point: _ll(view.recovery.catPoint!),
                    width: 64,
                    height: 64,
                    rotate: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _select('lost-cat'),
                      child: const _CatMarker(key: Key('lost-cat')),
                    ),
                  ),
                Marker(
                  point: _ll(fix.point),
                  width: 64,
                  height: 64,
                  rotate: true,
                  child: _YouMarker(
                    heading: _heading + _rotation * math.pi / 180,
                  ),
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
        if (_selectedTarget(view) case final target?)
          Positioned(
            left: 16,
            right: 72,
            bottom: 16,
            child: _TargetCard(
              key: const Key('target-card'),
              title: target.title,
              meters: _route != null && _routeFor == _selected
                  ? _route!.meters
                  : distanceMeters(fix.point, target.point),
              timeText: _route != null && _routeFor == _selected
                  ? _route!.timeText
                  : walkingTimeText(distanceMeters(fix.point, target.point)),
              caption: _route != null && _routeFor == _selected
                  ? 'Walking route'
                  : _routeBusy
                  ? 'Finding the way…'
                  : 'Straight line, a rough guess',
              detail: target.detail,
              action: _selected == 'street-cat' ? _streetAction(view) : null,
              onClose: () => _select(null),
            ),
          ),
        if (_rotation.abs() > 1)
          Positioned(
            right: 16,
            bottom: 68,
            child: FloatingActionButton.small(
              key: const Key('compass'),
              heroTag: 'compass',
              tooltip: 'Face north',
              onPressed: () {
                if (_mapReady) _map.rotate(0);
                setState(() => _rotation = 0);
              },
              child: Transform.rotate(
                angle: -_rotation * math.pi / 180,
                child: const Icon(
                  Icons.navigation,
                  color: CatwalkColors.orange,
                ),
              ),
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
/// The credit the map data and the tile host ask for.
class _MapCredit extends StatelessWidget {
  const _MapCredit();

  @override
  Widget build(BuildContext context) => const SimpleAttributionWidget(
    source: Text('MapTiler · OpenStreetMap contributors'),
    alignment: Alignment.bottomLeft,
  );
}

/// Something on the map you tapped.
class _Target {
  const _Target(this.title, this.point, {this.detail});

  /// A line under the title, for what the player may do here.
  final String? detail;

  /// What it is.
  final String title;

  /// Where it is.
  final GeoPoint point;
}

/// The card at the bottom after tapping a pin or a cat: what it is, how far
/// away, and how long the walk takes at an average pace.
class _TargetCard extends StatelessWidget {
  const _TargetCard({
    super.key,
    required this.title,
    required this.meters,
    required this.timeText,
    required this.caption,
    required this.onClose,
    this.detail,
    this.action,
  });

  /// A line about what you can do here.
  final String? detail;

  /// A button for it, when you are in reach.
  final Widget? action;

  /// How long the walk takes, already worded.
  final String timeText;

  /// Where the numbers come from: the street route or a straight-line guess.
  final String caption;

  /// What was tapped.
  final String title;

  /// Straight-line distance from you, in metres.
  final double meters;

  /// Closes the card.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: CatwalkColors.card,
      elevation: 3,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.directions_walk,
                        size: 18,
                        color: CatwalkColors.teal,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '$timeText · ${distanceText(meters)}',
                          key: const Key('target-distance'),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    caption,
                    key: const Key('target-caption'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: CatwalkColors.inkMuted,
                    ),
                  ),
                  if (detail != null)
                    Text(
                      detail!,
                      key: const Key('target-detail'),
                      style: theme.textTheme.bodySmall,
                    ),
                  if (action != null) ...[const SizedBox(height: 8), action!],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: onClose,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

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
            child: const Center(child: CatHeadIcon(size: 20)),
          ),
        ],
      ),
    ),
  );
}

/// A pickup: bobs gently, and glows and grows once it is close enough to walk
/// onto.
class _PinMarker extends StatefulWidget {
  const _PinMarker({super.key, required this.near, this.selected = false});

  /// True while this pin is the one you tapped.
  final bool selected;

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
        scale: widget.near || widget.selected ? 1.25 : 0.9,
        duration: const Duration(milliseconds: 250),
        child: Container(
          decoration: BoxDecoration(
            color: CatwalkColors.orange,
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.selected ? CatwalkColors.teal : Colors.white,
              width: 3,
            ),
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
  const _CatMarker({super.key});

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
            child: const Center(
              child: CatHeadIcon(
                key: Key('cat-head'),
                size: 30,
                featureColor: CatwalkColors.orange,
              ),
            ),
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
      StreetCatPhotographed(
        :final catName,
        :final sightings,
        :final ready,
        :final hasFreeBed,
      ) =>
        (
          'Photo of $catName',
          !ready
              ? 'Photo $sightings of $sightingsToJoin. $catName may be '
                    'back on another day.'
              : hasFreeBed
              ? '$catName trusts you now. Meet them again and invite them '
                    'to join. There is an empty bed.'
              : '$catName trusts you now, but every bed is taken. Buy a bed '
                    'in the Shop, then invite them.',
          Icons.photo_camera,
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

/// A street cat on the map: its coat colour in a ring, a cat head and a small
/// camera badge to say it wants a photo.
class _StreetCatMarker extends StatelessWidget {
  const _StreetCatMarker({super.key, required this.coat});

  /// The cat's coat.
  final Color coat;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Street cat',
    child: Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: coat,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(color: Color(0x44000000), blurRadius: 6),
            ],
          ),
          child: const Center(
            child: CatHeadIcon(size: 26, color: Colors.white),
          ),
        ),
        const Positioned(
          right: 6,
          bottom: 6,
          child: CircleAvatar(
            radius: 11,
            backgroundColor: CatwalkColors.teal,
            child: Icon(Icons.photo_camera, size: 13, color: Colors.white),
          ),
        ),
      ],
    ),
  );
}
