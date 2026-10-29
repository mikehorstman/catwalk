import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/room_layout.dart';

/// The room behind the cats: wall, window, floor, and the furniture the spots
/// describe. Furniture is drawn from the layout, so a spot and what you see
/// never drift apart.
class RoomScene extends StatelessWidget {
  const RoomScene({required this.layout, super.key});

  /// Source of every position: walk line, window sill, rug, basket, tree and
  /// toys.
  final RoomLayout layout;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        Offset at(double x, double y) => Offset(x * w, y * h);

        final floorTop = layout.walkY * h - 0.10 * h;
        final living = layout.roomId == 'living';
        final sill = living ? layout.spot('sill') : null;
        final rug = living ? layout.spot('rug') : null;
        final basket = living ? layout.spot('basket') : null;
        final tree = living ? layout.spot('tree') : null;
        final floorColor = switch (layout.roomId) {
          'garden' => const Color(0xFFB7D8A0),
          'attic' => const Color(0xFFD9C3A5),
          'veranda' => const Color(0xFFE6D2B5),
          _ => const Color(0xFFEAC9A3),
        };
        final wallColors = switch (layout.roomId) {
          'garden' => const [Color(0xFFCFE8F2), CatwalkColors.cream],
          'attic' => const [Color(0xFFE4D3EA), CatwalkColors.cream],
          _ => const [CatwalkColors.orangeSoft, CatwalkColors.cream],
        };

        return Stack(
          children: [
            // Wall and floor.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: wallColors,
                    stops: const [0.0, 0.75],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: floorTop,
              bottom: 0,
              child: ColoredBox(color: floorColor),
            ),

            // Window, with the sill the cat perches on.
            if (sill != null) ...[
              Positioned(
                left: (sill.position.dx - 0.20) * w,
                top: 0.06 * h,
                width: 0.40 * w,
                height: sill.position.dy * h - 0.06 * h,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFFDFF1F0),
                    border: Border.fromBorderSide(
                      BorderSide(color: CatwalkColors.line, width: 6),
                    ),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                  ),
                ),
              ),
              _Board(
                center: at(sill.position.dx, sill.position.dy),
                width: 0.44 * w,
                height: 0.018 * h,
              ),
            ],

            // Rug.
            if (rug != null)
              _Board(
                center: at(rug.position.dx, rug.position.dy),
                width: 0.40 * w,
                height: 0.030 * h,
                color: CatwalkColors.teal,
              ),

            // Basket.
            if (basket != null)
              _Basket(
                center: at(basket.position.dx, basket.position.dy),
                w: w,
                h: h,
              ),

            // Toys you have found, lying on the floor.
            for (final spot in layout.toySpotsHere)
              _Toy(
                id: spot.id.substring(toySpotPrefix.length),
                center: at(spot.position.dx, spot.position.dy),
                size: 0.07 * w,
              ),

            // Cat tree: a post with a platform on top.
            if (tree != null) ...[
              Positioned(
                left: tree.position.dx * w - 0.045 * w,
                top: tree.position.dy * h,
                width: 0.09 * w,
                height: (layout.walkY - tree.position.dy) * h,
                child: const ColoredBox(color: Color(0xFFC79A6B)),
              ),
              _Board(
                center: at(tree.position.dx, tree.position.dy),
                width: 0.20 * w,
                height: 0.022 * h,
                color: const Color(0xFFB07C4A),
              ),
            ],

            // Decorations without hand-drawn art yet: a neutral placeholder.
            // The art for each item replaces `_ItemTile` later.
            for (final item in layout.items)
              if (!living || !item.starter)
                _ItemTile(
                  item: item,
                  center: at(item.position.dx, item.position.dy),
                  w: w,
                  h: h,
                  chip: living,
                ),
          ],
        );
      },
    );
  }
}

/// A placeholder for one decoration: a soft tile with its name. In the living
/// room, where the classic furniture is drawn already, it is a small tag.
class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.center,
    required this.w,
    required this.h,
    required this.chip,
  });

  final PlacedItem item;
  final Offset center;
  final double w;
  final double h;
  final bool chip;

  @override
  Widget build(BuildContext context) {
    final width = (chip ? 0.22 : 0.20) * w;
    final height = (chip ? 0.04 : 0.10) * h;
    final tint = [
      const Color(0xFFF3E3C8),
      const Color(0xFFE9D4A8),
      const Color(0xFFDDBF86),
    ][(item.tier - 1).clamp(0, 2)];
    return Positioned(
      left: center.dx - width / 2,
      top: chip ? center.dy + 0.03 * h : center.dy - height * 0.4,
      width: width,
      height: height,
      child: Semantics(
        label: item.name,
        child: DecoratedBox(
          key: Key('item-${item.id}'),
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(chip ? 10 : 14),
            border: Border.all(color: CatwalkColors.line),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  item.name,
                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({
    required this.center,
    required this.width,
    required this.height,
    this.color = const Color(0xFFD9B48C),
  });

  /// Middle of the board, in logical pixels.
  final Offset center;

  /// Width in logical pixels.
  final double width;

  /// Height in logical pixels; the ends are rounded to half of it.
  final double height;

  /// Fill colour; defaults to a light wood.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: center.dx - width / 2,
      top: center.dy - height / 2,
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(height / 2),
        ),
      ),
    );
  }
}

/// A cosy basket: an open-topped oval with a rim.
class _Basket extends StatelessWidget {
  const _Basket({required this.center, required this.w, required this.h});

  /// Where the basket sits, in logical pixels; the cat's feet land inside the
  /// rim.
  final Offset center;

  /// Room width in logical pixels.
  final double w;

  /// Room height in logical pixels.
  final double h;

  @override
  Widget build(BuildContext context) {
    final width = 0.22 * w;
    final height = 0.075 * h;
    return Positioned(
      left: center.dx - width / 2,
      top: center.dy - height * 0.55,
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFE3C7A4),
          border: Border.all(color: const Color(0xFFCEA777), width: 4),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(width * 0.5),
            bottom: Radius.circular(height * 0.35),
          ),
        ),
      ),
    );
  }
}

/// A toy on the floor. Simple shapes: the real art comes later.
class _Toy extends StatelessWidget {
  const _Toy({required this.id, required this.center, required this.size});

  /// The toy's id from the inventory: `ball`, `mouse`; anything else draws as
  /// the feather.
  final String id;

  /// Where the toy rests on the floor, in logical pixels.
  final Offset center;

  /// Base size in logical pixels; the shapes scale from it.
  final double size;

  @override
  Widget build(BuildContext context) {
    final Widget shape = switch (id) {
      'ball' => DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xFFE5574B),
          shape: BoxShape.circle,
        ),
        child: SizedBox(width: size, height: size),
      ),
      'mouse' => DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF9AA5AA),
          borderRadius: BorderRadius.circular(size),
        ),
        child: SizedBox(width: size * 1.3, height: size * 0.7),
      ),
      _ => Transform.rotate(
        angle: -0.5,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: CatwalkColors.teal,
            borderRadius: BorderRadius.circular(size),
          ),
          child: SizedBox(width: size * 1.6, height: size * 0.28),
        ),
      ),
    };
    return Positioned(
      left: center.dx,
      top: center.dy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -1.0),
        child: Semantics(label: 'A $id', child: shape),
      ),
    );
  }
}
