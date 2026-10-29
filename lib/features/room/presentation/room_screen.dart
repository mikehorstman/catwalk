import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../cat/presentation/widgets/cat_art.dart';
import '../../rooms/domain/placement.dart';
import '../../rooms/domain/room_constants.dart';
import '../../rooms/domain/room_type.dart';
import '../../steps/presentation/home_controller.dart';
import '../data/room_cats_provider.dart';
import '../domain/cat_action.dart';
import '../domain/room_cat.dart';
import '../data/room_layout_provider.dart';
import '../../rooms/domain/decoration_catalogue.dart';
import '../../rooms/presentation/slot_sheet.dart';
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
class RoomPage extends ConsumerStatefulWidget {
  const RoomPage({
    this.room = RoomType.living,
    this.layout,
    this.animations,
    super.key,
  });

  /// Which room this page shows. Only its cats are drawn.
  final RoomType room;

  /// Overrides the room, for tests. Normally the room is built from what you
  /// have found.
  final RoomLayout? layout;

  /// Overrides how cats are drawn, for tests. Normally the sprite sheets are
  /// used, with the placeholder until they load.
  final CatAnimationSet? animations;

  @override
  ConsumerState<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends ConsumerState<RoomPage>
    with SingleTickerProviderStateMixin {
  /// Drives the simulation once per frame. Null until the first room is built,
  /// and stopped in reduced-motion mode.
  Ticker? _ticker;

  /// The current room's brain. Replaced whenever the room is rebuilt.
  RoomSimulation? _simulation;

  /// The latest cat states the screen draws.
  List<CatState> _states = const [];

  /// Ticker time of the previous frame, used for the frame delta. Zero means no
  /// frame yet.
  Duration _lastTick = Duration.zero;

  /// Fingerprint of what the current simulation was built from; see
  /// [_signatureOf].
  String _signature = '';

  /// The motion setting the current simulation was built with.
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

  /// Moves the simulation forward by the time since the last frame.
  ///
  /// The step is capped at 0.05 s (20 fps worth) so a pause never makes cats
  /// jump.
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
    final cats = [
      for (final cat in ref.watch(roomCatsProvider))
        if (cat.cat.roomId == widget.room) cat,
    ];
    // Reduce Motion is a device setting, and it can change while the app runs.
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final RoomLayout layout =
        widget.layout ?? ref.watch(roomLayoutForProvider(widget.room));
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
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(color: roomTint(widget.room)),
                ),
              ),
              // One small button per slot, to see what stands there and change it.
              for (final slot in Slot.values)
                Positioned(
                  left: slot.position.dx * size.width - 16,
                  top:
                      (slot.position.dy + (slot.isHigh ? 0.07 : -0.12)) *
                          size.height -
                      16,
                  child: _SlotButton(
                    key: Key('slot-${slot.name}'),
                    filled: ref
                        .watch(roomLayoutForProvider(widget.room))
                        .items
                        .any((i) => i.slot == slot.name),
                    onTap: () => SlotSheet.show(context, widget.room, slot),
                  ),
                ),
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

  /// The cat with this [id], or null if it is no longer in [cats].
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

  /// Where the cat is and what it is doing.
  final CatState state;

  /// The cat being drawn.
  final RoomCat cat;

  /// How to draw the cat.
  final CatAnimationSet animations;

  /// Used to turn a spot id into words for the screen-reader label.
  final RoomLayout layout;

  /// Size of the room in logical pixels; positions are fractions of it.
  final Size room;

  /// Called when the cat is tapped.
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
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              animations.frame(
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
              if (cat.hasGift)
                Positioned(
                  right: size * 0.22,
                  top: size * 0.05,
                  child: _Badge(
                    key: Key('gift-badge-${cat.id}'),
                    icon: Icons.card_giftcard,
                  ),
                )
              else if (cat.wish != null)
                Positioned(
                  right: size * 0.22,
                  top: size * 0.05,
                  child: _Badge(
                    key: Key('wish-bubble-${cat.id}'),
                    icon: Icons.chat_bubble_outline,
                  ),
                ),
              if (cat.comfort.hearts > 0)
                Positioned(
                  left: size * 0.22,
                  top: size * 0.05,
                  child: Row(
                    key: Key('hearts-${cat.id}'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < cat.comfort.hearts; i++)
                        const Icon(
                          Icons.favorite,
                          size: 12,
                          color: CatwalkColors.teal,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// What the cat is doing, in words: "sitting on the rug".
  String _description() {
    final spotId = state.spotId;
    final label = spotId == null ? null : layout.spot(spotId)?.label;
    final doing = actionLabel(state.action);
    return label == null ? doing : '$doing $label';
  }
}

/// Centred "No cats yet." message for an empty room.
class _Badge extends StatelessWidget {
  const _Badge({required this.icon, super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: CatwalkColors.teal),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 16, color: CatwalkColors.teal),
      ),
    );
  }
}

class _SlotButton extends StatelessWidget {
  const _SlotButton({required this.filled, required this.onTap, super.key});

  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white70,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            filled ? Icons.edit_outlined : Icons.add,
            size: 18,
            color: CatwalkColors.line,
          ),
        ),
      ),
    );
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

/// Debug-only button in the corner that opens the [AnimationLabSheet].
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

/// A soft colour over the room that tells the rooms apart until each has its
/// own art.
Color roomTint(RoomType room) => switch (room) {
  RoomType.living => const Color(0x00000000),
  RoomType.garden => const Color(0x2A8FAE9B),
  RoomType.attic => const Color(0x2AB07A3A),
  RoomType.veranda => const Color(0x2A7FA3B8),
};

/// The Cats tab: the rooms side by side. Swipe to see the next one.
///
/// The living room is first. Rooms you do not own yet are shown dim, with
/// their price and a Buy button.
class RoomScreen extends ConsumerStatefulWidget {
  const RoomScreen({this.layout, this.animations, super.key});

  /// Overrides the room, for tests.
  final RoomLayout? layout;

  /// Overrides how cats are drawn, for tests.
  final CatAnimationSet? animations;

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> {
  final PageController _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeControllerProvider).value;
    final owned = home?.rooms ?? const [RoomType.living];
    final cats = home?.cats ?? const [];
    final room = RoomType.values[_page];
    final theme = Theme.of(context);
    return Stack(
      children: [
        PageView(
          key: const Key('room-pager'),
          controller: _pages,
          onPageChanged: (page) => setState(() => _page = page),
          children: [
            for (final type in RoomType.values)
              if (owned.contains(type))
                RoomPage(
                  room: type,
                  layout: widget.layout,
                  animations: widget.animations,
                )
              else
                _LockedRoom(
                  room: type,
                  price: RoomType.priceForNext(owned.length),
                  candy: home?.inventory.candy ?? 0,
                  layout: widget.layout,
                ),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: SafeArea(
            bottom: false,
            child: IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: CatwalkColors.card.withAlpha(220),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        owned.contains(room)
                            ? '${room.label} · '
                                  '${catsIn(room, cats).length} of '
                                  '${RoomConstants.placesPerRoom} places'
                            : '${room.label} · not yours yet',
                        key: const Key('room-title'),
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final type in RoomType.values)
                          Container(
                            key: Key('room-dot-${type.name}'),
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: type == room
                                  ? CatwalkColors.teal
                                  : owned.contains(type)
                                  ? CatwalkColors.orangeSoft
                                  : CatwalkColors.line,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A room the player does not own yet: dim, with its price and a Buy button.
class _LockedRoom extends ConsumerWidget {
  const _LockedRoom({
    required this.room,
    required this.price,
    required this.candy,
    required this.layout,
  });

  final RoomType room;
  final int? price;
  final int candy;
  final RoomLayout? layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final canBuy = price != null && candy >= price!;
    return Stack(
      fit: StackFit.expand,
      children: [
        RoomScene(layout: layout ?? RoomLayout.standard),
        ColoredBox(color: Colors.black.withAlpha(120)),
        Center(
          child: Container(
            key: Key('locked-${room.name}'),
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: CatwalkColors.card,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 28),
                const SizedBox(height: 8),
                Text(room.label, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'A new room for cats that like '
                  '${room.baseLike.label.toLowerCase()}. A new cat arrives '
                  'the next morning.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                FilledButton(
                  key: Key('buy-room-page-${room.name}'),
                  onPressed: canBuy
                      ? () => ref
                            .read(homeControllerProvider.notifier)
                            .buyRoom(room)
                      : null,
                  child: Text(
                    price == null
                        ? 'Not for sale'
                        : canBuy
                        ? 'Buy for $price candy'
                        : '$price candy (you have $candy)',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
