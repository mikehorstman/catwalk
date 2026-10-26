import 'package:flutter/material.dart';

/// A small cat head: two ears, a round face, eyes, a nose and whiskers. It is
/// the cat's icon on the map. Real art can replace it later; the size and
/// colours are the whole interface.
class CatHeadIcon extends StatelessWidget {
  const CatHeadIcon({
    super.key,
    this.size = 24,
    this.color = Colors.white,
    this.featureColor = const Color(0xFF1F2A2E),
  });

  /// Width and height in logical pixels.
  final double size;

  /// The head and ears.
  final Color color;

  /// The eyes, nose and whiskers; pick something that contrasts with [color].
  final Color featureColor;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _CatHeadPainter(color, featureColor)),
  );
}

class _CatHeadPainter extends CustomPainter {
  _CatHeadPainter(this.color, this.featureColor);

  final Color color;
  final Color featureColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fill = Paint()..color = color;
    final ink = Paint()..color = featureColor;

    // Ears: two triangles behind the head.
    final ears = Path()
      ..moveTo(w * 0.10, h * 0.50)
      ..lineTo(w * 0.14, h * 0.06)
      ..lineTo(w * 0.42, h * 0.28)
      ..close()
      ..moveTo(w * 0.90, h * 0.50)
      ..lineTo(w * 0.86, h * 0.06)
      ..lineTo(w * 0.58, h * 0.28)
      ..close();
    canvas.drawPath(ears, fill);

    // The face: a wide, slightly squashed circle.
    canvas.drawOval(
      Rect.fromLTWH(w * 0.06, h * 0.22, w * 0.88, h * 0.72),
      fill,
    );

    // Eyes.
    final eye = w * 0.075;
    canvas.drawCircle(Offset(w * 0.34, h * 0.56), eye, ink);
    canvas.drawCircle(Offset(w * 0.66, h * 0.56), eye, ink);

    // Nose: a small downward triangle.
    final nose = Path()
      ..moveTo(w * 0.44, h * 0.68)
      ..lineTo(w * 0.56, h * 0.68)
      ..lineTo(w * 0.50, h * 0.75)
      ..close();
    canvas.drawPath(nose, ink);

    // Whiskers.
    final whisker = Paint()
      ..color = featureColor
      ..strokeWidth = w * 0.035
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(
        Offset(w * 0.08, h * 0.68),
        Offset(w * 0.30, h * 0.72),
        whisker,
      )
      ..drawLine(
        Offset(w * 0.08, h * 0.80),
        Offset(w * 0.30, h * 0.77),
        whisker,
      )
      ..drawLine(
        Offset(w * 0.92, h * 0.68),
        Offset(w * 0.70, h * 0.72),
        whisker,
      )
      ..drawLine(
        Offset(w * 0.92, h * 0.80),
        Offset(w * 0.70, h * 0.77),
        whisker,
      );
  }

  @override
  bool shouldRepaint(_CatHeadPainter old) =>
      old.color != color || old.featureColor != featureColor;
}
