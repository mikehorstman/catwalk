import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../cat/presentation/widgets/cat_art.dart';
import '../data/room_cats_provider.dart';
import '../domain/cat_action.dart';
import '../domain/room_cat.dart';
import '../data/room_layout_provider.dart';
import '../domain/room_layout.dart';
import '../domain/room_simulation.dart';
import 'animation_lab.dart';
import 'cat_animations.dart';
import 'cat_details_sheet.dart';
import 'widgets/room_scene.dart';

/// The Cats tab: one full-screen room where the cats live.
///
/// The room shows state; it never decides it. Mood and status come from the day's
/// rules, and the room only picks what a cat does about them.
class RoomScreen extends ConsumerStatefulWidget {
  const RoomScreen({this.layout, this.animations, super.key});

  /// Overrides the room, for tests. Normally the room is built from what you
  /// have found.
  final RoomLayout? layout;

  /// Overrides how cats are drawn, for tests. Normally the sprite sheets are
  /// used, with the placeholder until they load.
  final CatAnimationSet? animations;

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  RoomSimulation? _simulation;
  List<CatState> _states = const [];
  Duration _lastTick = Duration.zero;
  String _signature = '';
  bool _reducedMotion = false;

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  /// The cats the room is built from. A change means a fresh room.
  String _signatureOf(List<RoomCat> cats, RoomLayout layout) => [
    for (final cat in cats) '${cat.id}:${cat.mood.name}:${cat.status.name}',
    for (final spot in layout.spots) spot.id,
  ].join(',');

  /// Creates a fresh room when the cats or the motion setting change.
  void _syncRoom(List<RoomCat> cats, RoomLayout layout, bool reducedMotion) {
    _signature = _signatureOf(cats, layout);
    _reducedMotion = reducedMotion;
    final simulation = RoomSimulation(
      layout: layout,
      cats: cats,
      reducedMotion: reducedMotion,
    );
    _simulation = simulation;
    _states = simulation.states;
    _lastTick = Duration.zero;

    final ticker = _ticker ??= createTicker(_onTick);
    if (reducedMotion) {
      if (ticker.isActive) ticker.stop();
    } else if (!ticker.isActive) {
      ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final simulation = _simulation;
    if (simulation == null) return;
    final previous = _lastTick;
    _lastTick = elapsed;
    if (previous == Duration.zero) return;
    // A long gap means the tab was hidden or the app was suspended. Take a
    // small step instead of teleporting cats across the room.
    final seconds = ((elapsed - previous).inMicroseconds / 1e6).clamp(
      0.0,
      0.05,
    );
    if (seconds <= 0) return;
    simulation.step(seconds);
    setState(() => _states = simulation.states);
  }

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(roomCatsProvider);
    // Reduce Motion is a device setting, and it can change while the app runs.
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final RoomLayout layout = widget.layout ?? ref.watch(roomLayoutProvider);
    if (_signatureOf(cats, layout) != _signature ||
        reducedMotion != _reducedMotion) {
      _syncRoom(cats, layout, reducedMotion);
    }

    final home = [
      for (final cat in cats)
        if (cat.isHome) cat,
    ];
    final runAway = cats.isNotEmpty && home.isEmpty;

    return ColoredBox(
      color: CatwalkColors.cream,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          return Stack(
            fit: StackFit.expand,
            children: [
              RoomScene(layout: layout),
              if (runAway)
                const Center(child: EmptyCushion(size: 200))
              else
                for (final state in _paintOrder())
                  if (_catFor(cats, state.catId) case final cat?)
                    _CatLayer(
                      state: state,
                      cat: cat,
                      animations:
                          widget.animations ?? ref.watch(catAnimationsProvider),
                      layout: layout,
                      room: size,
                      onTap: () => CatDetailsSheet.show(context, cat),
                    ),
              if (cats.isEmpty) const _NoCats(),
              if (kDebugMode)
                const Positioned(
                  left: 4,
                  top: 4,
                  child: SafeArea(child: _LabButton()),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Lower cats are nearer, so they paint last and on top.
  List<CatState> _paintOrder() =>
      [..._states]..sort((a, b) => a.position.dy.compareTo(b.position.dy));

  RoomCat? _catFor(List<RoomCat> cats, String id) {
    for (final cat in cats) {
      if (cat.id == id) return cat;
    }
    return null;
  }
}

/// One cat, standing on her spot at her own depth.
class _CatLayer extends StatelessWidget {
  const _CatLayer({
    required this.state,
    required this.cat,
    required this.animations,
    required this.layout,
    required this.room,
    required this.onTap,
  });

  final CatState state;
  final RoomCat cat;
  final CatAnimationSet animations;
  final RoomLayout layout;
  final Size room;
  final VoidCallback onTap;

  /// A cat is about this wide on a 390pt phone, and grows a little nearer.
  static const _baseSize = 104.0;

  @override
  Widget build(BuildContext context) {
    final scale = (0.82 + 0.32 * state.position.dy) * (room.width / 390);
    final size = _baseSize * scale.clamp(0.7, 2.2);
    return Positioned(
      left: state.position.dx * room.width - size / 2,
      top: state.position.dy * room.height - size,
      width: size,
      height: size,
      child: Semantics(
        label: '${cat.name}, ${_description()}',
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: animations.frame(
            context,
            appearance: cat.cat.appearance,
            action: state.action,
            mood: cat.mood,
            facing: state.facing,
            elapsed: Duration(
              milliseconds: (state.actionElapsed * 1000).round(),
            ),
            size: size,
          ),
        ),
      ),
    );
  }

  String _description() {
    final spotId = state.spotId;
    final label = spotId == null ? null : layout.spot(spotId)?.label;
    final doing = actionLabel(state.action);
    return label == null ? doing : '$doing $label';
  }
}

class _NoCats extends StatelessWidget {
  const _NoCats();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'No cats yet.',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _LabButton extends StatelessWidget {
  const _LabButton();

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: 'Animation lab',
      onPressed: () => AnimationLabSheet.show(context),
      icon: const Icon(Icons.science_outlined),
    );
  }
}
