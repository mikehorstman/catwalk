import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme.dart';
import '../../../core/utils/format.dart';
import '../data/location_service.dart';
import '../domain/collect.dart';
import '../domain/geo.dart';
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

LatLng _ll(GeoPoint p) => LatLng(p.lat, p.lon);

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _map = MapController();
  bool _following = true;
  bool _mapReady = false;
  double _zoom = 16;
  bool _showingEvent = false;

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(mapControllerProvider, (previous, next) {
      final view = next.value;
      if (view == null) return;
      final event = view.event;
      if (event != null && !_showingEvent) _showEvent(event);
      final fix = view.fix;
      // The map only takes commands once it has been drawn.
      if (fix != null &&
          _following &&
          _mapReady &&
          previous?.value?.fix != fix) {
        _map.move(_ll(fix.point), _zoom);
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
            initialZoom: 16,
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
              ),
            MarkerLayer(
              markers: [
                for (final pin in view.pins)
                  Marker(
                    point: _ll(pin.point),
                    width: 44,
                    height: 44,
                    child: const _PinMarker(),
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
                  width: 28,
                  height: 28,
                  child: const _YouMarker(),
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
              setState(() => _following = true);
              if (_mapReady) _map.move(_ll(fix.point), 16);
            },
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }

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

class _YouMarker extends StatelessWidget {
  const _YouMarker();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'You',
    child: Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2F6FED),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
      ),
    ),
  );
}

class _PinMarker extends StatelessWidget {
  const _PinMarker();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Pickup',
    child: Container(
      decoration: BoxDecoration(
        color: CatwalkColors.orange,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
      ),
      child: const Icon(
        Icons.card_giftcard,
        color: CatwalkColors.ink,
        size: 22,
      ),
    ),
  );
}

class _CatMarker extends StatelessWidget {
  const _CatMarker();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Your cat',
    child: Container(
      decoration: BoxDecoration(
        color: CatwalkColors.teal,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
      ),
      child: const Icon(Icons.pets, color: Colors.white, size: 26),
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

  (String, String, IconData) _describe(Collected result) {
    final extra = result.converted
        ? ' You already had ${result.reward is FreezeReward ? 'the most freezes you can hold' : 'this toy'}, so it paid XP instead.'
        : '';
    switch (result.reward) {
      case XpReward(:final amount):
        return ('+$amount XP', 'A bit of XP for your cat.', Icons.star);
      case FreezeReward():
        return result.converted
            ? ('+${result.xpGained} XP', 'A streak freeze.$extra', Icons.star)
            : (
                'Streak freeze',
                'It covers one missed day, then it is gone.',
                Icons.ac_unit,
              );
      case ToyReward(:final toyId):
        return result.converted
            ? ('+${result.xpGained} XP', 'A $toyId.$extra', Icons.star)
            : ('A $toyId', 'It is in the room now.', Icons.toys);
      case CatProgressReward():
        return ('A step towards a new cat', 'Keep going.', Icons.pets);
    }
  }
}
