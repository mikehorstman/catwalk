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
        final sill = layout.spot('sill')!;
        final rug = layout.spot('rug')!;
        final basket = layout.spot('basket')!;
        final tree = layout.spot('tree')!;

        return Stack(
          children: [
            // Wall and floor.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [CatwalkColors.orangeSoft, CatwalkColors.cream],
                    stops: [0.0, 0.75],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: floorTop,
              bottom: 0,
              child: const ColoredBox(color: Color(0xFFEAC9A3)),
            ),

            // Window, with the sill the cat perches on.
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
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                ),
              ),
            ),
            _Board(
              center: at(sill.position.dx, sill.position.dy),
              width: 0.44 * w,
              height: 0.018 * h,
            ),

            // Rug.
            _Board(
              center: at(rug.position.dx, rug.position.dy),
              width: 0.40 * w,
              height: 0.030 * h,
              color: CatwalkColors.teal,
            ),

            // Basket.
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
        );
      },
    );
  }
}

/// A flat board: a rug, a shelf, a platform. Feet land on its middle.
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
